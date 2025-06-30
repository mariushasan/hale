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
    trail.Color = ColorSequence.new(Color3.fromRGB(255, 255, 0)) -- Bright yellow for visibility
    trail.Transparency = NumberSequence.new(0) -- Fully opaque
    trail.Lifetime = 0.2 -- Longer lifetime
    trail.MinLength = 0
    trail.Enabled = true
    trail.Attachment0 = attachment1
    trail.Attachment1 = attachment2
    trail.Parent = bullet
    
    return bullet
end

-- Create spread pattern for shotgun
function Shotgun.createSpreadPattern(startPosition, direction)
	local forwardVector = direction.Unit
	local rightVector, upVector
	
    -- For bullets from other players, calculate right/up vectors from the provided direction
    -- Cross product with world up vector (0,1,0) to get right vector
    rightVector = forwardVector:Cross(Vector3.new(0, 1, 0))		
    -- Cross product of right and forward to get up vector
    upVector = rightVector:Cross(forwardVector).Unit
	
	local bullets = {}
	
	-- Create spread pattern using calculated orientation
	local directions = {
		forwardVector,                                           -- Center
		forwardVector + rightVector * 0.1,                      -- Right
		forwardVector - rightVector * 0.1,                      -- Left  
		forwardVector + upVector * 0.1,                         -- Up
		forwardVector - upVector * 0.1,                         -- Down
		forwardVector + rightVector * 0.07 + upVector * 0.07,   -- Top-right
		forwardVector - rightVector * 0.07 + upVector * 0.07,   -- Top-left
		forwardVector + rightVector * 0.07 - upVector * 0.07,   -- Bottom-right
        forwardVector - rightVector * 0.07 - upVector * 0.07,   -- Bottom-left
	}

    for i, direction in ipairs(directions) do
        local bullet = {
            direction = direction,
            startPosition = startPosition,
        }
        table.insert(bullets, bullet)
    end
    
    return bullets
end

function Shotgun.animateBullet(startPosition, direction, maxDistance)
	-- Create bullets for each direction
    local bulletPart = createBullet(startPosition, direction)

    local bullet = {
        part = bulletPart,
        direction = direction.Unit,
        startTime = tick(),
        startPosition = startPosition,
    }
    
    -- Store the initial CFrame rotation to avoid precision issues
    local initialCFrame = CFrame.new(bullet.startPosition, bullet.startPosition + bullet.direction)
	
	-- Return update function for all bullets
	return function(deltaTime)
		local currentTime = tick()
        
        -- Check if bullet still exists
        local elapsedTime = currentTime - bullet.startTime
        local distance = ShotgunConstants.BULLET_SPEED * elapsedTime
        
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
        -- Remove shotgun model if it exists
        local shotgunModel = character:FindFirstChild("shotgun")
        if shotgunModel then
            shotgunModel:Destroy()
        end
        cleanupFirstPerson(character)
    end
end

function Shotgun.animateFire()    
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
        warn("Shotgun fire animation track not loaded")
    end
end

return Shotgun 