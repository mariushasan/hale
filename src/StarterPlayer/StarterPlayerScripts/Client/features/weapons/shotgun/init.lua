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
    print("animateBullet", startPosition, hitPosition, hitPart, direction)
    
    -- Calculate spread pattern for shotgun pellets
    local forwardVector = direction.Unit
    
    -- Calculate right and up vectors for spread plane
    local rightVector = forwardVector:Cross(Vector3.new(0, 1, 0))
    if rightVector.Magnitude < 0.1 then
        -- If looking straight up/down, use world right vector
        rightVector = Vector3.new(1, 0, 0)
    else
        rightVector = rightVector.Unit
    end
    local upVector = rightVector:Cross(forwardVector).Unit
    
    -- Shotgun spread angle (in radians) - wider spread for close range effectiveness
    local spreadAngle = math.rad(8) -- ~8 degree cone spread
    
    -- Create BULLETS_PER_SHOT number of beams with spread pattern
    local bulletsPerShot = ShotgunConstants.BULLETS_PER_SHOT
    
    for i = 1, bulletsPerShot do
        -- Random angle within spread cone (circular pattern)
        local azimuthAngle = math.random() * 2 * math.pi -- Random angle around circle (0 to 2π)
        local elevationAngle = math.sqrt(math.random()) * spreadAngle -- Random elevation within spread (sqrt for uniform distribution)
        
        -- Calculate spread offset in the plane perpendicular to direction
        -- Using small angle approximation: sin(θ) ≈ θ for small angles
        local spreadX = math.cos(azimuthAngle) * elevationAngle
        local spreadY = math.sin(azimuthAngle) * elevationAngle
        
        -- Apply spread to direction by rotating forward vector
        -- For small angles, we can approximate rotation by adding perpendicular components
        local spreadOffset = (rightVector * spreadX) + (upVector * spreadY)
        local spreadDirection = (forwardVector + spreadOffset).Unit
        
        -- Calculate end position with spread
        local endPosition = startPosition + (spreadDirection * ShotgunConstants.RANGE)
        
        -- If original hit position exists, use it as reference for spread distance
        if hitPosition then
            local distanceToHit = (hitPosition - startPosition).Magnitude
            -- Project spread direction to the same distance as the hit
            endPosition = startPosition + (spreadDirection * distanceToHit)
        end
        
        -- Create beam for this pellet
        local beam = createBeam(startPosition, endPosition)
        Debris:AddItem(beam, 0.05)
    end

    return nil
end

return Shotgun