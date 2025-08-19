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
local cameraModeConnection = nil
local currentCharacter = nil

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
    print("14")
    print("Setting up camera arm sync")
    print("Character:", character)
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    print("Humanoid:", humanoid)
    print("RootPart:", rootPart)
        
    if not (humanoid and rootPart) then
        return
    end

    print("15")
    
    -- Clean up any existing visual rig
    if visualRig then
        visualRig:Destroy()
        visualRig = nil
    end

    print("16")
    
    -- Clone the character for visual rig
    visualRig = character:Clone()
    visualRig.Name = "VisualRig"

    print("VisualRig:", visualRig)

    print("17")
    
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

    print("18")
    
    -- Make visual rig completely independent and non-interfering
    visualHumanoid.PlatformStand = true
    visualHumanoid.JumpPower = 0
    visualHumanoid.AutoRotate = false
    visualHumanoid.Sit = true
    visualHumanoid.WalkSpeed = 0
    visualRootPart.CanCollide = false
    visualRootPart.CollisionGroup = "VisualOnly"
    visualHumanoid:SetStateEnabled(Enum.HumanoidStateType.Physics, false)

    print("19")
    
    -- Scale the visual rig to 0.7 of original size
    visualRig:ScaleTo(0.7)
    
    for _, part in pairs(visualRig:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CollisionGroup = "VisualOnly"
        end
    end

    print("20")
    
    visualRig.Parent = workspace.CurrentCamera

    -- Animation handling for custom UMPIdle animation
    if visualHumanoid then
        local animator = visualHumanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = visualHumanoid
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
    
    local visualAnimator = visualHumanoid:FindFirstChildOfClass("Animator")
    if not visualAnimator then
        visualAnimator = Instance.new("Animator")
        visualAnimator.Parent = visualHumanoid
    end

    print("21")
    
    local animationId = "rbxassetid://124292358269579"
    local animation = Instance.new("Animation")
    animation.AnimationId = animationId

    print("22")
    
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
end

local function setupFirstPerson(character)
    print("8")

    print("9")

    local whitelistedParts = {
        "Left Arm", "Right Arm"
    }

    print("10")

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

        print("11")

            local visualWeapon = visualRig:FindFirstChild("SMG")
        if visualWeapon then
            print("12")
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

    print("13")

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

-- Create a moving beam effect that travels from start to end
local function createBeam(startPosition, endPosition)
    local direction = (endPosition - startPosition).Unit
    
    -- Create small beam that will move forward
    local beamLength = 3 -- Length of the beam in studs
    
    -- Create invisible parts to hold the attachments
    local startPart = Instance.new("Part")
    startPart.Name = "BeamStart"
    startPart.Size = Vector3.new(0.1, 0.1, 0.1)
    startPart.Position = startPosition
    startPart.Anchored = true
    startPart.CanCollide = false
    startPart.Transparency = 1
    startPart.Parent = workspace
    
    local endPart = Instance.new("Part")
    endPart.Name = "BeamEnd"
    endPart.Size = Vector3.new(0.1, 0.1, 0.1)
    endPart.Position = startPosition + (direction * beamLength)
    endPart.Anchored = true
    endPart.CanCollide = false
    endPart.Transparency = 1
    endPart.Parent = workspace
    
    -- Create attachments
    local startAttachment = Instance.new("Attachment")
    startAttachment.Name = "BeamStart"
    startAttachment.Parent = startPart
    
    local endAttachment = Instance.new("Attachment")
    endAttachment.Name = "BeamEnd"
    endAttachment.Parent = endPart
    
    -- Create the beam
    local beam = Instance.new("Beam")
    beam.Name = "BulletBeam"
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 165, 0)) -- Orange color for assault rifle
    beam.Transparency = NumberSequence.new(0.1) -- Slightly transparent
    beam.Width0 = 0.03 -- Small beam
    beam.Width1 = 0.03 -- Consistent width
    beam.FaceCamera = true
    beam.LightEmission = 0.8 -- High glow for visibility
    beam.LightInfluence = 0 -- Not affected by lighting
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Parent = startPart
    
    -- Animate the beam moving forward
    return beam
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
    -- Calculate end position based on max distance
    local endPosition = startPosition + (direction.Unit * maxDistance)
    
    -- Create beam from start to end position (automatically cleans up after 0.15s)
    local bulletStart = visualRig:FindFirstChild("BulletStart", true)
    local bulletStartPosition = bulletStart and bulletStart.WorldPosition or startPosition
    
    print("Firing bullet from:", bulletStartPosition)
    print("Camera position:", startPosition)
    print("Target position:", endPosition)

    local beam = createBeam(bulletStartPosition, endPosition)
    local direction = (endPosition - bulletStartPosition).Unit
    local startTime = tick()
    local bulletSpeed = 800
    local beamLength = 3

    return function()
        local elapsed = tick() - startTime
        local distance = bulletSpeed * elapsed

        -- Bullet should travel from the original firing position in a straight line
        local newPosition = bulletStartPosition + (direction * distance)

        beam.Attachment0.WorldPosition = newPosition
        beam.Attachment1.WorldPosition = newPosition + (direction * beamLength)

        if distance > maxDistance then
            beam:Destroy()
            return false
        end

        return true
    end
end

function AssaultRifle.equip()
    print("0")

    if not Players.LocalPlayer.Character then
        return
    end

    print("1")

    local smgModel = ReplicatedStorage:FindFirstChild("models"):FindFirstChild("weapons"):FindFirstChild("SMG")
    if not smgModel then
        return
    end

    print("2")

    local originalCharacter = Players.LocalPlayer.Character
    print("Original Character:", originalCharacter)
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Ensure the original character has a Humanoid
    if not originalHumanoid then
        return
    end
    
    -- Clone the SMG character model
    local newCharacterModel = smgModel:Clone()
    
    -- Get the Humanoid from the new SMG character
    local smgHumanoid = newCharacterModel:FindFirstChildOfClass("Humanoid")
    
    print("3")

    if not smgHumanoid then
        newCharacterModel:Destroy() -- Clean up the cloned character
        return
    end

    print("4")

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

    print("5")

    -- Preserve original character's clothing
    local clothingItems = {"Shirt", "Pants", "ShirtGraphic"}
    for _, clothingType in ipairs(clothingItems) do
        local originalClothing = originalCharacter:FindFirstChildOfClass(clothingType)
        if originalClothing then
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

    print("6")

    print("7")

    setupFirstPerson(newCharacterModel)
end

function AssaultRifle.unequip()
    -- Clean up old animation system
    cleanupConnectionsAndAnimation()
    
    -- Clean up camera mode connection
    if cameraModeConnection then
        cameraModeConnection:Disconnect()
        cameraModeConnection = nil
    end
    
    -- Clean up camera arm sync connection
    if cameraArmSyncConnection then
        cameraArmSyncConnection:Disconnect()
        cameraArmSyncConnection = nil
    end
    
    -- Clear current character reference
    currentCharacter = nil
    
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
            
            -- Create bullet animation (beam automatically cleans up)
            local updateFunction = AssaultRifle.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
            bulletAnimations[bullet.id] = {
                update = updateFunction,
            }
            
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

    print("Fire animation track:", currentFireAnimationTrack)
    
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

        -- Create bullet animation (beam automatically cleans up)
        local updateFunction = AssaultRifle.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
        bulletAnimations[bullet.id] = {
            update = updateFunction,
        }
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