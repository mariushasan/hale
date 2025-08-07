local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local AssaultRifleConstants = require(ReplicatedStorage.features.weapons.assaultrifle.constants)
local BulletTemplate = require(script.Parent.shotgun.BulletTemplate)
local HitGui = require(script.Parent.ui.HitGui)
local Workspace = game:GetService("Workspace")

local AssaultRifle = {}

local currentHoldAnimationTrack = nil
local currentFireAnimationTrack = nil
local transparencyConnections = {}
local bulletCounter = 0

-- Visual rig system for camera tracking
local visualRig = nil

-- First-person camera sync
local cameraArmSyncConnection = nil

-- Per-weapon fire rate tracking
local lastFireTime = 0

local currentAccuracy = 1.0 -- Start with perfect accuracy

local lastMovementTime = 0 -- Track when player last moved

-- Accuracy tracking
local currentMovementAccuracyPenalty = 0.0

local MAX_MOVEMENT_ACCURACY_PENALTY = 0.4
local MOVEMENT_ACCURACY_RECOVERY_SPEED = 0.15 -- Faster recovery than shotgun
local MOVEMENT_ACCURACY_RECOVERY_DELAY = 0.02 -- Shorter delay than shotgun
local MOVEMENT_ACCURACY_REMOVE_SPEED = 0.3

-- Kickback system
local currentKickbackAccuracyPenalty = 0.0 -- Current kickback accuracy penalty
local lastShotTime = 0 -- Track when player last shot

local MAX_KICKBACK_ACCURACY_PENALTY = 0.4
local KICKBACK_ACCURACY_RECOVERY_SPEED = 0.15 -- How fast kickback recovers
local KICKBACK_ACCURACY_PENALTY_PER_SHOT = 0.05 -- How much kickback each shot adds
local KICKBACK_ACCURACY_RECOVERY_DELAY = 0.15 -- Delay before kickback starts recovering
local KICKBACK_ACCURACY_REMOVE_SPEED = 0.3

-- Animation IDs (using shotgun animations for now)
local ASSAULT_RIFLE_HOLD_ANIM_ID = "rbxassetid://124292358269579"
local ASSAULT_RIFLE_FIRE_ANIM_ID = "rbxassetid://86022384403109"

-- Generate unique bullet ID
local function generateBulletId()
    local player = Players.LocalPlayer
    bulletCounter = bulletCounter + 1
    return player.Name .. "_" .. tick() .. "_" .. bulletCounter
end


local function cleanupConnectionsAndAnimation()
    for _, connection in pairs(transparencyConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    transparencyConnections = {}

    if currentHoldAnimationTrack then
        currentHoldAnimationTrack:Stop()
        currentHoldAnimationTrack:Destroy()
        currentHoldAnimationTrack = nil
    end

    if currentFireAnimationTrack then
        currentFireAnimationTrack:Stop()
        currentFireAnimationTrack:Destroy()
        currentFireAnimationTrack = nil
    end
    
    -- Cleanup camera sync connection
    if cameraArmSyncConnection then
        cameraArmSyncConnection:Disconnect()
        cameraArmSyncConnection = nil
    end
    
    -- Cleanup visual rig
    if visualRig then
        visualRig:Destroy()
        visualRig = nil
    end
end

-- Function to sync arms with camera rotation in first-person
local function setupCameraArmSync(character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")
        
    if not (humanoid and rootPart) then
        return
    end
    
    -- Clean up any existing visual rig
    if visualRig then
        visualRig:Destroy()
        visualRig = nil
    end
    
    -- Clone the character for visual rig
    visualRig = character:Clone()
    visualRig.Name = character.Name .. "_VisualRig"
    
    -- Make the visual rig non-collideable and completely independent
    local visualHumanoid = visualRig:FindFirstChildOfClass("Humanoid")
    local visualRootPart = visualRig:FindFirstChild("HumanoidRootPart")
    local visualTorso = visualRig:FindFirstChild("Torso")

    visualTorso.CanCollide = false
    visualTorso.CollisionGroup = "VisualOnly"
    if not (visualHumanoid and visualRootPart) then
        visualRig:Destroy()
        visualRig = nil
        return
    end
    
    -- Make visual rig completely independent and non-interfering
    visualHumanoid.PlatformStand = true
    visualHumanoid.JumpPower = 0
    visualHumanoid.AutoRotate = false
    visualHumanoid.Sit = true
    visualHumanoid.WalkSpeed = 0
    visualRootPart.CanCollide = false
    visualRootPart.CollisionGroup = "VisualOnly"
    visualHumanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
    
    -- Scale the visual rig to 0.7 of original size
    print(visualRig:IsA("Model"))
    visualRig:ScaleTo(0.7)
    
    for _, part in pairs(visualRig:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CollisionGroup = "VisualOnly"
        end
    end
    
    visualRig.Parent = workspace.CurrentCamera
    
    local visualAnimator = visualHumanoid:FindFirstChildOfClass("Animator")
    if not visualAnimator then
        visualAnimator = Instance.new("Animator")
        visualAnimator.Parent = visualHumanoid
    end
    
    local animationId = "rbxassetid://124292358269579"
    local animation = Instance.new("Animation")
    animation.AnimationId = animationId
    
    cameraArmSyncConnection = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if not camera or not visualRig or not visualRootPart then return end
        
        local cameraOffset = Vector3.new(0.7, -1, 0.5)
        local visualRigCFrame = camera.CFrame * CFrame.new(cameraOffset)
        
        local oldCFrame = visualRootPart.CFrame
        visualRootPart.CFrame = visualRigCFrame
        visualTorso.CanCollide = false
        visualTorso.CollisionGroup = "VisualOnly"
    end)
    
    print("DEBUG: Camera-attached visual rig system established")
end

local function setupFirstPerson(character)
    local player = Players.LocalPlayer
    player.CameraMode = Enum.CameraMode.LockFirstPerson

    local whitelistedParts = {
        "Left Arm", "Right Arm"
    }

    if visualRig then
        for _, partName in ipairs(whitelistedParts) do
            local part = visualRig:FindFirstChild(partName)
            if part and part:IsA("BasePart") then
                part.LocalTransparencyModifier = part.Transparency
                transparencyConnections[partName] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                    part.LocalTransparencyModifier = part.Transparency
                end)
            end
        end

        local visualWeapon = visualRig:FindFirstChild("SMG")
        if visualWeapon then
            for _, part in pairs(visualWeapon:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.LocalTransparencyModifier = part.Transparency
                    transparencyConnections[part.Name] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                        part.LocalTransparencyModifier = part.Transparency
                    end)
                end
            end
        end
    end

    setupCameraArmSync(character)
end

local function cleanupFirstPerson(character)
    local player = Players:GetPlayerFromCharacter(character)

    if not player then return end

    for _, connection in pairs(transparencyConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    transparencyConnections = {}

    if cameraArmSyncConnection then
        cameraArmSyncConnection:Disconnect()
        cameraArmSyncConnection = nil
    end
end

-- Create a bullet with trail effect
local function createBullet(startPosition, direction)
    local bullet = BulletTemplate:Clone()
    
    -- Simple positioning first - no orientation
    bullet.CFrame = CFrame.new(startPosition, startPosition + direction)
    bullet.Parent = workspace
            
    -- Add attachment points for trail with simple positions
    local attachment1 = Instance.new("Attachment")
    attachment1.Name = "TrailAttachment1"
    attachment1.Position = Vector3.new(0.02, 0, 0)  -- Center of bullet
    attachment1.Parent = bullet
    
    local attachment2 = Instance.new("Attachment")
    attachment2.Name = "TrailAttachment2"
    attachment2.Position = Vector3.new(-0.02, 0, 0)
    attachment2.Parent = bullet
    
    -- Create trail effect with basic settings
    local trail = Instance.new("Trail")
    trail.Name = "BulletTrail"
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 165, 0)) -- Orange color for assault rifle
    trail.Transparency = NumberSequence.new(0) -- Fully opaque
    trail.Lifetime = 0.15 -- Slightly longer trail
    trail.MinLength = 0
    trail.Enabled = true
    trail.Attachment0 = attachment1
    trail.Attachment1 = attachment2
    trail.Parent = bullet
    
    return bullet
end

-- Create spread pattern for assault rifle (single bullet, no spread - accuracy handled by camera shift)
function AssaultRifle.createSpreadPattern(startPosition, direction)
    local bullets = {}
    
    -- Single bullet for assault rifle - always shoots straight from the given direction
    local bullet = {
        -- Single raycast per bullet
        raycastData = {{
            direction = direction,
            startPosition = startPosition
        }},
        -- Animation direction is same as raycast direction
        animationDirection = direction,
        animationStartPosition = startPosition
    }
    table.insert(bullets, bullet)
    
    return bullets
end

function AssaultRifle.animateBullet(startPosition, direction, maxDistance)
    -- Create bullet
    local bulletPart = createBullet(startPosition, direction)

    local bullet = {
        part = bulletPart,
        direction = direction.Unit,
        startTime = tick(),
        startPosition = startPosition,
    }
    
    -- Store the initial CFrame rotation to avoid precision issues
    local initialCFrame = CFrame.new(bullet.startPosition, bullet.startPosition + bullet.direction)
    
    -- Return update function
    return function(deltaTime)
        local currentTime = tick()
        
        -- Check if bullet still exists
        local elapsedTime = currentTime - bullet.startTime
        local distance = 400 * elapsedTime -- Faster bullet speed than shotgun
        
        -- Move bullet
        local newPosition = bullet.startPosition + (bullet.direction * distance)
        bullet.part.Position = newPosition
        -- Remove bullet if it has traveled too far
        if distance > maxDistance then
            bullet.part:Destroy()
            return false
        end

        return true
    end
end

function AssaultRifle.equip()
    if not Players.LocalPlayer.Character then
        return
    end

    local smgModel = Workspace:FindFirstChild("SMG")
    if not smgModel then
        return
    end

    local originalCharacter = Players.LocalPlayer.Character
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Ensure the original character has a Humanoid
    if not originalHumanoid then
        return
    end
    
    -- Clone the SMG character model
    local newCharacterModel = smgModel:Clone()
    
    -- Get the Humanoid from the new SMG character
    local smgHumanoid = newCharacterModel:FindFirstChildOfClass("Humanoid")
    if not smgHumanoid then
        newCharacterModel:Destroy() -- Clean up the cloned character
        return
    end

    -- Get the HumanoidRootPart from both characters for positioning
    local originalRootPart = originalCharacter:FindFirstChild("HumanoidRootPart")
    local smgRootPart = newCharacterModel:FindFirstChild("HumanoidRootPart")
    
    if not originalRootPart then
        newCharacterModel:Destroy()
        return
    end

    if not smgRootPart then
        newCharacterModel:Destroy()
        return
    end

    -- Preserve original character's clothing
    local clothingItems = {"Shirt", "Pants", "ShirtGraphic"}
    for _, clothingType in ipairs(clothingItems) do
        local originalClothing = originalCharacter:FindFirstChildOfClass(clothingType)
        if originalClothing then
            print("DEBUG: Found", clothingType, "- copying to SMG character")
            -- Remove existing clothing of this type from SMG character
            local existingClothing = newCharacterModel:FindFirstChildOfClass(clothingType)
            if existingClothing then
                existingClothing:Destroy()
            end
            -- Copy the original clothing
            local newClothing = originalClothing:Clone()
            newClothing.Parent = newCharacterModel
        end
    end

    -- Animation handling for custom UMPIdle animation
    if smgHumanoid then
        local animator = smgHumanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = smgHumanoid
        end
        
        -- Try to get animation from SMG model's AnimSaves first
        local animation = Instance.new("Animation")
        animation.AnimationId = ASSAULT_RIFLE_HOLD_ANIM_ID
        
        currentHoldAnimationTrack = animator:LoadAnimation(animation)
        
        if currentHoldAnimationTrack then
            
            -- Set properties before playing
            currentHoldAnimationTrack.Looped = true
            currentHoldAnimationTrack.Priority = Enum.AnimationPriority.Action
            
            currentHoldAnimationTrack:Play()
        end
    end
    
    setupFirstPerson(newCharacterModel)
end

function AssaultRifle.unequip()
    -- Clean up old animation system
    cleanupConnectionsAndAnimation()
    
    local character = Players.LocalPlayer.Character
    if character then
        -- Remove assault rifle model if it exists
        local assaultRifleModel = character:FindFirstChild("assaultrifle")
        if assaultRifleModel then
            assaultRifleModel:Destroy()
        end
        cleanupFirstPerson(character)
    end
end

function AssaultRifle.animateFire()    
    -- Play the fire animation if it exists
    if currentFireAnimationTrack then
        currentFireAnimationTrack:Play()
        
        local startTime = tick()
        
        -- Wait for the animation to finish
        currentFireAnimationTrack.Stopped:Wait()
        
        -- Resume the hold animation
        if currentHoldAnimationTrack then
            currentHoldAnimationTrack:Play()
        end
    else
        warn("Assault rifle fire animation track not loaded")
    end
end

function AssaultRifle.handleFireFromClient()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    -- Check fire rate
    local currentTime = tick()
    local fireRate = AssaultRifleConstants.FIRE_COOLDOWN or 0.1
    if not (currentTime - lastFireTime >= fireRate) then
        return {}, {} -- Return empty hits and bullets
    end
    
    lastFireTime = currentTime
    lastShotTime = currentTime -- Update last shot time for kickback
    
    -- Calculate local firing parameters
    local camera = workspace.CurrentCamera
    if not camera then
        return {}, {} -- Return empty hits and bullets
    end
    
    -- Apply camera recoil using exponential function (before adding new kickback)
    local maxRecoilStrength = 0.05 -- Maximum recoil when kickback is at max (0.4)
    local normalizedKickback = currentKickbackAccuracyPenalty / 0.4 -- Normalize to 0-1 range
    local exponentialFactor = math.pow(normalizedKickback, 2) -- Exponential curve (starts easy, gets strong)
    local recoilStrength = exponentialFactor * maxRecoilStrength
    local horizontalRecoil = (math.random() - 0.5) * recoilStrength * 0.5 -- Random left/right
    
    -- Apply recoil to camera
    local currentCFrame = camera.CFrame
    local recoilCFrame = CFrame.Angles(recoilStrength, horizontalRecoil, 0) -- Vertical up, horizontal random
    camera.CFrame = currentCFrame * recoilCFrame
    
    -- Add kickback after applying recoil
    currentKickbackAccuracyPenalty = math.min(MAX_KICKBACK_ACCURACY_PENALTY, currentKickbackAccuracyPenalty + KICKBACK_ACCURACY_PENALTY_PER_SHOT)
    
    local bullets = AssaultRifle.createSpreadPattern(camera.CFrame.Position, camera.CFrame.LookVector)
    
    -- Assign bullet IDs
    for _, bullet in ipairs(bullets) do
        bullet.id = generateBulletId()
    end
    
    local hits = {}
    local bulletAnimations = {}
    
    for _, bullet in ipairs(bullets) do
        -- Check if this is a local firing (bullet ID starts with local player's name)
        if bullet.id and bullet.id:find("^" .. player.Name .. "_") then
            -- Perform client-side raycasts for this bullet
            local camera = workspace.CurrentCamera
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.CollisionGroup = "PlayerCharacters"
            
            local bulletHit = false
            local hitPart = nil
            local hitPosition = nil
            local hitRaycastData = nil -- Store which raycast actually hit
            
            -- Try each raycast for this bullet until we get a hit
            for _, raycastData in ipairs(bullet.raycastData) do
                if bulletHit then break end -- Stop if we already hit something
                
                -- Raycast in the direction we're shooting
                local raycastDistance = 1000 -- Max shooting distance
                local raycastResult = workspace:Raycast(raycastData.startPosition, raycastData.direction * raycastDistance, raycastParams)
                
                if raycastResult and raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid") then
                    print("HIT PART")
                    hitPart = raycastResult.Instance
                    hitPosition = raycastResult.Position
                    hitRaycastData = raycastData -- Store the raycast data that hit
                    bulletHit = true -- Mark that this bullet hit something
                end
            end
            
            -- Calculate max distance for animation
            local maxDistance = AssaultRifleConstants.MAX_BULLET_DISTANCE
            local hitVector = hitPosition and hitPosition - bullet.animationStartPosition
            if hitVector then
                maxDistance = hitVector.Magnitude
            end
            
            -- Create bullet animation
            local updateBullet = AssaultRifle.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
            if updateBullet then
                bulletAnimations[bullet.id] = {
                    update = updateBullet
                }
            end
            
            -- Only add hit data if we actually hit something
            if bulletHit then
                table.insert(hits, {
                    id = bullet.id,
                    direction = hitRaycastData.direction, -- Use the actual raycast direction that hit
                    startPosition = hitRaycastData.startPosition, -- Use the actual raycast start position that hit
                    animationStartPosition = bullet.animationStartPosition,
                    animationDirection = bullet.animationDirection,
                    hitPart = hitPart,
                    hitPosition = hitPosition,
                    maxDistance = maxDistance,
                })
            else
                table.insert(hits, {
                    id = bullet.id,
                    animationStartPosition = bullet.animationStartPosition,
                    animationDirection = bullet.animationDirection,
                    hitPosition = hitPosition,
                    maxDistance = maxDistance,
                })
            end
        end
    end
    
    -- Handle damage display for assault rifle
    if #hits > 0 then
        local avgHitPosition, validHits = HitGui.calculateAverageHitPosition(hits)
        if avgHitPosition and validHits > 0 then
            local totalDamage = validHits * AssaultRifleConstants.DAMAGE_PER_BULLET
            HitGui.showDamageNumber(totalDamage, avgHitPosition)
        end
    end

    local animator = visualRig:FindFirstChildOfClass("Humanoid"):FindFirstChildOfClass("Animator")
    
    -- Try to get animation from SMG model's AnimSaves first
    local animation = Instance.new("Animation")
    animation.AnimationId = ASSAULT_RIFLE_FIRE_ANIM_ID
    
    currentFireAnimationTrack = animator:LoadAnimation(animation)
    currentFireAnimationTrack.Looped = false
    currentFireAnimationTrack:Play()
    
    return hits, bulletAnimations
end

function AssaultRifle.handleFireFromServer(bullets)
    local bulletAnimations = {}
    
    for _, bullet in ipairs(bullets) do
        local maxDistance = AssaultRifleConstants.MAX_BULLET_DISTANCE
        local hitVector = bullet.hitPosition and bullet.hitPosition - bullet.animationStartPosition
        if hitVector then
            maxDistance = hitVector.Magnitude
        end

        local updateBullet = AssaultRifle.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
        if updateBullet then
            bulletAnimations[bullet.id] = {
                update = updateBullet
            }
        end
    end
    
    return bulletAnimations
end

function AssaultRifle.calculateCrosshairAccuracy(velocity)
    -- Calculate movement speed (magnitude of velocity)
    local movementSpeed = velocity.Magnitude
    
    -- Round to nearest 0.5 to reduce twitching
    movementSpeed = math.floor(movementSpeed * 2 + 0.5) / 2
    
    -- Define movement thresholds (more forgiving than shotgun)
    local maxMovementSpeed = 40 -- Lower threshold for assault rifle
    local minMovementSpeed = 2 -- Below this, no movement penalty
    
    local currentTime = tick()
    
    -- Update kickback recovery
    local timeSinceLastShot = currentTime - lastShotTime
    if timeSinceLastShot >= KICKBACK_ACCURACY_RECOVERY_DELAY then
        currentKickbackAccuracyPenalty = math.max(0, currentKickbackAccuracyPenalty - (MAX_KICKBACK_ACCURACY_PENALTY / (60 * KICKBACK_ACCURACY_RECOVERY_SPEED)))
    else
        currentKickbackAccuracyPenalty = math.min(MAX_KICKBACK_ACCURACY_PENALTY, currentKickbackAccuracyPenalty + (MAX_KICKBACK_ACCURACY_PENALTY / (60 * KICKBACK_ACCURACY_REMOVE_SPEED)))
    end

    if currentTime - lastMovementTime > MOVEMENT_ACCURACY_RECOVERY_DELAY then
        currentMovementAccuracyPenalty = math.max(0, currentMovementAccuracyPenalty - (MAX_MOVEMENT_ACCURACY_PENALTY / (60 * MOVEMENT_ACCURACY_RECOVERY_SPEED)))
    else
        local movementFactor = math.min(movementSpeed / maxMovementSpeed, 1.0)
        currentMovementAccuracyPenalty = math.min(MAX_MOVEMENT_ACCURACY_PENALTY, currentMovementAccuracyPenalty + (movementFactor * (MAX_MOVEMENT_ACCURACY_PENALTY / (60 * MOVEMENT_ACCURACY_REMOVE_SPEED))))
    end
    
    -- Track when player last moved
    if movementSpeed > minMovementSpeed then
        lastMovementTime = currentTime
    end
    
    currentAccuracy = math.max(0.2, 1.0 - currentMovementAccuracyPenalty - currentKickbackAccuracyPenalty)
    
    return currentAccuracy
end

return AssaultRifle 