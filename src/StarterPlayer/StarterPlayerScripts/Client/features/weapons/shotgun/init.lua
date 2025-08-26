local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local HitGui = require(script.Parent.ui.HitGui)
local Workspace = game:GetService("Workspace")

local Shotgun = {}

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

-- Animation IDs (using shotgun animations for now)
local ASSAULT_RIFLE_HOLD_ANIM_ID = "rbxassetid://124292358269579"
local ASSAULT_RIFLE_FIRE_ANIM_ID = "rbxassetid://86022384403109"

-- Generate unique bullet ID
local function generateBulletId()
    local player = Players.LocalPlayer
    bulletCounter = bulletCounter + 1
    return player.Name .. "_" .. tick() .. "_" .. bulletCounter
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
    visualRig.Name = "VisualRig"

    -- Make the visual rig non-collideable and completely independent
    local visualHumanoid = visualRig:FindFirstChildOfClass("Humanoid")
    local visualRootPart = visualRig:FindFirstChild("HumanoidRootPart")
    
    if not (visualHumanoid or visualRootPart) then
        visualRig:Destroy()
        visualRig = nil
        return
    end

    -- Scale the visual rig to 0.7 of original size
    visualRig:ScaleTo(0.7)
    
    for _, part in pairs(visualRig:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CollisionGroup = "VisualOnly"
        end
    end

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
            currentHoldAnimationTrack.Looped = true
            currentHoldAnimationTrack.Priority = Enum.AnimationPriority.Action
            currentHoldAnimationTrack:Play()
        end


        local animation = Instance.new("Animation")
        animation.AnimationId = ASSAULT_RIFLE_FIRE_ANIM_ID
        
        currentFireAnimationTrack = animator:LoadAnimation(animation)

        if currentFireAnimationTrack then
            currentFireAnimationTrack.Looped = false
        end
    end

    local cameraOffset = Vector3.new(0.7, -1, 0.5)

    cameraArmSyncConnection = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if not camera or not visualRootPart then return end
        
        local visualRigCFrame = camera.CFrame * CFrame.new(cameraOffset)
        visualRootPart.CFrame = visualRigCFrame
    end)
end

local function setupFirstPerson(character)
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

        local visualWeapon = visualRig:FindFirstChild("Shotgun")
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
    endPart.Position = endPosition
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
function Shotgun.createSpreadPattern(startPosition, direction)
    local bullets = {}
    
    local bullet = {
        raycastData = {{
            direction = direction,
            startPosition = startPosition
        }},

        animationDirection = direction,
        animationStartOffset = Vector3.new(0, 0, 0),
    }
    table.insert(bullets, bullet)
    
    return bullets
end

function Shotgun.animateBullet(startPosition, hitPosition, hitPart, direction)    
    local endPosition = startPosition + (direction.Unit * ShotgunConstants.RANGE)

    if hitPosition then
        endPosition = hitPosition
    end

    local maxDistance = (endPosition - startPosition).Magnitude
    
    local beam = createBeam(startPosition, endPosition)

    Debris:AddItem(beam, 0.05)

    return nil
end

function Shotgun.equip()
    if not Players.LocalPlayer.Character then
        return
    end

    local shotgunModel = ReplicatedStorage:FindFirstChild("models"):FindFirstChild("weapons"):FindFirstChild("Shotgun")
    if not shotgunModel then
        return
    end

    local originalCharacter = Players.LocalPlayer.Character
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Ensure the original character has a Humanoid
    if not originalHumanoid then
        return
    end
    
    -- Clone the SMG character model
    local newCharacterModel = shotgunModel:Clone()
    
    -- Get the Humanoid from the new SMG character
    local weaponHumanoid = newCharacterModel:FindFirstChildOfClass("Humanoid")
    
    if not weaponHumanoid then
        newCharacterModel:Destroy() -- Clean up the cloned character
        return
    end

    -- Preserve original character's clothing
    local clothingItems = {"Shirt", "Pants", "ShirtGraphic"}
    for _, clothingType in ipairs(clothingItems) do
        local originalClothing = originalCharacter:FindFirstChildOfClass(clothingType)
        if originalClothing then
            local existingClothing = newCharacterModel:FindFirstChildOfClass(clothingType)
            if existingClothing then
                existingClothing:Destroy()
            end
            local newClothing = originalClothing:Clone()
            newClothing.Parent = newCharacterModel
        end
    end

    setupFirstPerson(newCharacterModel)
end

function Shotgun.unequip()
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

function Shotgun.handleFireFromClient()
    local player = Players.LocalPlayer
    
    -- Check fire rate
    local currentTime = tick()
    local fireRate = ShotgunConstants.FIRE_COOLDOWN
    if not (currentTime - lastFireTime >= fireRate) then
        return {}, {}
    end
    
    lastFireTime = currentTime
    
    -- Calculate local firing parameters
    local camera = workspace.CurrentCamera
    if not camera then
        return {}, {}
    end
    
    local bullets = Shotgun.createSpreadPattern(camera.CFrame.Position, camera.CFrame.LookVector)
    
    -- Assign bullet IDs
    for _, bullet in ipairs(bullets) do
        bullet.id = generateBulletId()
    end
    
    local hits = {}
    local bulletAnimations = {}

    local bulletStart = visualRig:FindFirstChild("BulletStart", true)
    local bulletStartPosition = bulletStart and bulletStart.WorldPosition
    
    for _, bullet in ipairs(bullets) do
        -- Check if this is a local firing (bullet ID starts with local player's name)
        if bullet.id and bullet.id:find("^" .. player.Name .. "_") then
            -- Perform client-side raycasts for this bullet
            local camera = workspace.CurrentCamera
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {player.Character}
            raycastParams.CollisionGroup = "PlayerCharacters"

            local hitPosition = nil
            
            -- Try each raycast for this bullet until we get a hit
            for _, raycastData in ipairs(bullet.raycastData) do                
                -- Raycast in the direction we're shooting
                local raycastDistance = ShotgunConstants.RANGE -- Max shooting distance
                local raycastResult = workspace:Raycast(raycastData.startPosition, raycastData.direction * raycastDistance, raycastParams)
                
                if raycastResult then
                    hitPosition = raycastResult.Position
                    table.insert(hits, {
                        hitPart = raycastResult.Instance,
                        hitPosition = raycastResult.Position,
                    })
                    break
                end
            end
            
            -- Create bullet animation (beam automatically cleans up)
            local updateFunction = Shotgun.animateBullet(bulletStartPosition + bullet.animationStartOffset, hitPosition, hitPart, bullet.animationDirection)
            bulletAnimations[bullet.id] = {
                update = updateFunction,
            }
        end
    end
    
    if #hits > 0 then
        local avgHitPosition, validHits = HitGui.calculateAverageHitPosition(hits)
        if avgHitPosition and validHits > 0 then
            local totalDamage = validHits * ShotgunConstants.DAMAGE_PER_HIT
            HitGui.showDamageNumber(totalDamage, avgHitPosition)
        end
    end

    if currentFireAnimationTrack then
        currentFireAnimationTrack:Play()
    end

    return hits, bulletAnimations
end

function Shotgun.handleFireFromServer(shooter, bullets)
    local bulletAnimations = {}

    local shooterCharacter = shooter.Character

    if not shooterCharacter then
        return bulletAnimations
    end

    local bulletStart = shooterCharacter:FindFirstChild("BulletStart", true)
    local bulletStartPosition = bulletStart and bulletStart.WorldPosition
    
    for _, bullet in ipairs(bullets) do
        local updateFunction = Shotgun.animateBullet(bulletStartPosition + bullet.animationStartOffset, bullet.hitPosition, bullet.hitPart, bullet.animationDirection)
        bulletAnimations[bullet.id] = {
            update = updateFunction,
        }
    end
    
    return bulletAnimations
end

return Shotgun