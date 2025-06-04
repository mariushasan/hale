local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local BulletTemplate = require(script.BulletTemplate)

local Shotgun = {}

local currentHoldAnimationTrack = nil
local currentFireAnimationTrack = nil
local transparencyConnections = {}
local bulletCounter = 0

-- First person settings
local FPS_HANDS_ENABLED = true
local AUTO_FIRST_PERSON = false

-- Animation IDs
local SHOTGUN_HOLD_ANIM_ID = "rbxassetid://77926930697734"
local SHOTGUN_FIRE_ANIM_ID = "rbxassetid://137169236696451"

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
end

local function setupFirstPerson(character)
    if not FPS_HANDS_ENABLED then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    if AUTO_FIRST_PERSON then
        player.CameraMode = Enum.CameraMode.LockFirstPerson
    end

    -- Handle R15 rig
    local whitelistedParts = {
        "LeftHand", "LeftLowerArm", "LeftUpperArm",
        "RightHand", "RightLowerArm", "RightUpperArm"
    }

    for _, partName in ipairs(whitelistedParts) do
        local part = character:FindFirstChild(partName)
        if part and part:IsA("BasePart") then
            part.LocalTransparencyModifier = part.Transparency
            transparencyConnections[partName] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                part.LocalTransparencyModifier = part.Transparency
            end)
        end
    end

    -- Handle weapon visibility in first person immediately
    local shotgunModel = character:FindFirstChild("shotgun")
    if shotgunModel then
        for _, part in pairs(shotgunModel:GetDescendants()) do
            if part:IsA("BasePart") then
                part.LocalTransparencyModifier = part.Transparency
                transparencyConnections[part.Name] = part:GetPropertyChangedSignal("LocalTransparencyModifier"):Connect(function()
                    part.LocalTransparencyModifier = part.Transparency
                end)
            end
        end
    end
end

local function cleanupFirstPerson(character)
    if not FPS_HANDS_ENABLED then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    if AUTO_FIRST_PERSON then
        player.CameraMode = Enum.CameraMode.Classic
        player.CameraMinZoomDistance = 9.6
        task.wait(0.02)
        player.CameraMinZoomDistance = game:GetService("StarterPlayer").CameraMinZoomDistance
    end

    for _, connection in pairs(transparencyConnections) do
        if connection then
            connection:Disconnect()
        end
    end
    transparencyConnections = {}
end

-- Create a bullet with trail effect
local function createBullet(startPosition, direction)
    local bullet = BulletTemplate:Clone()
    bullet.Position = startPosition
    bullet.Parent = workspace
        
    -- Create trail effect
    local trail = Instance.new("Trail")
    trail.Color = ColorSequence.new(ShotgunConstants.TRAIL_COLOR)
    trail.Transparency = NumberSequence.new(ShotgunConstants.TRAIL_TRANSPARENCY)
    trail.Lifetime = ShotgunConstants.TRAIL_LIFETIME
    trail.Parent = bullet
    
    -- Add attachment points for trail
    local attachment1 = Instance.new("Attachment")
    attachment1.Position = Vector3.new(0, 0, -0.5)
    attachment1.Parent = bullet
    
    local attachment2 = Instance.new("Attachment")
    attachment2.Position = Vector3.new(0, 0, 0.5)
    attachment2.Parent = bullet
    
    trail.Attachment0 = attachment1
    trail.Attachment1 = attachment2
    
    return bullet
end

-- Create spread pattern for shotgun
local function createSpreadPattern(direction, count)
    local directions = {}
    local baseDirection = direction.Unit
    
    for i = 1, count do
        -- Create random spread within the cone
        local spreadX = (math.random() - 0.5) * 2 * ShotgunConstants.SPREAD_ANGLE
        local spreadY = (math.random() - 0.5) * 2 * ShotgunConstants.SPREAD_ANGLE
        
        -- Apply spread to direction
        local spreadDirection = CFrame.fromOrientation(spreadX, spreadY, 0) * baseDirection
        table.insert(directions, spreadDirection)
    end
    
    return directions
end

function Shotgun.animateBullet()
    local camera = workspace.CurrentCamera
    if not camera then return function() return false end end

    -- Get shooting direction and start position
    local direction = camera.CFrame.LookVector
    local startPosition = camera.CFrame.Position + direction * 2
    local startTime = tick()
    
    -- Create bullets and get their update functions
    local spreadDirections = createSpreadPattern(direction, ShotgunConstants.PELLETS_PER_SHOT)
    local bulletUpdates = {}
    
    for _, spreadDir in ipairs(spreadDirections) do
        local bullet = createBullet(startPosition, spreadDir)
        
        -- Create update function for this bullet
        local function updateBullet(deltaTime)
            -- Move bullet based on speed and deltaTime
            local moveDistance = ShotgunConstants.BULLET_SPEED * deltaTime
            local newPosition = bullet.Position + (spreadDir * moveDistance)
            bullet.Position = newPosition
            
            -- Check if bullet should be removed
            local distanceTraveled = (newPosition - startPosition).Magnitude
            if distanceTraveled > ShotgunConstants.MAX_BULLET_DISTANCE then
                bullet:Destroy()
                return true -- Signal to remove from active bullets
            end
            
            return false -- Keep bullet active
        end
        
        -- Do initial update immediately for this bullet
        updateBullet(0.016)
        
        table.insert(bulletUpdates, updateBullet)
    end
    
    -- Return a function that updates all bullets
    return function(deltaTime)
        local allRemoved = true
        for _, updateFn in ipairs(bulletUpdates) do
            local removed = updateFn(deltaTime)
            if not removed then
                allRemoved = false
            end
        end
        return allRemoved -- Return true if all bullets should be removed
    end
end

function Shotgun.equip()
    cleanupConnectionsAndAnimation()
    
    local character = Players.LocalPlayer.Character
    if not character then return end

    -- Use shared handler for instant model equipping

    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
    if not (humanoid and animator) then
        return
    end

    -- Load both animations
    local holdAnimation = Instance.new("Animation")
    holdAnimation.AnimationId = SHOTGUN_HOLD_ANIM_ID
    currentHoldAnimationTrack = animator:LoadAnimation(holdAnimation)
    holdAnimation:Destroy()

    local fireAnimation = Instance.new("Animation")
    fireAnimation.AnimationId = SHOTGUN_FIRE_ANIM_ID
    currentFireAnimationTrack = animator:LoadAnimation(fireAnimation)
    fireAnimation:Destroy()

    if currentHoldAnimationTrack then
        currentHoldAnimationTrack.Priority = Enum.AnimationPriority.Action
        currentHoldAnimationTrack.Looped = true
        currentHoldAnimationTrack:Play()
    end

    -- Setup first person view
    setupFirstPerson(character)
end

function Shotgun.unequip()
    cleanupConnectionsAndAnimation()
    
    local character = Players.LocalPlayer.Character
    if character then
        -- Use shared handler for instant model unequipping
        ShotgunHandler.unequipModel(character)
        cleanupFirstPerson(character)
    end
end

function Shotgun.fire(startPosition, direction)    
    -- Play the fire animation
    currentFireAnimationTrack:Play()
    
    local startTime = tick()
    
    -- Wait for the animation to finish
    currentFireAnimationTrack.Stopped:Wait()
    
    -- Resume the hold animation
    if currentHoldAnimationTrack then
        currentHoldAnimationTrack:Play()
    end
end

return Shotgun 