local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local BulletTemplate = require(script.BulletTemplate)
local HitGui = require(script.Parent.ui.HitGui)

local Shotgun = {}

local currentHoldAnimationTrack = nil
local currentFireAnimationTrack = nil
local transparencyConnections = {}
local bulletCounter = 0

-- Per-weapon fire rate tracking
local lastFireTime = 0
local lastMovementTime = 0 -- Track when player last moved

-- First person settings
local FPS_HANDS_ENABLED = true
local AUTO_FIRST_PERSON = false

-- Animation IDs
local SHOTGUN_HOLD_ANIM_ID = "rbxassetid://77926930697734"
local SHOTGUN_FIRE_ANIM_ID = "rbxassetid://137169236696451"

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
end

local function setupFirstPerson(character)
    if not FPS_HANDS_ENABLED then return end

    local player = Players:GetPlayerFromCharacter(character)
    if not player then return end

    if AUTO_FIRST_PERSON then
        player.CameraMode = Enum.CameraMode.LockFirstPerson
    end

    -- Handle R15 rig
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
    trail.Lifetime = 0.1 -- Longer lifetime
    trail.MinLength = 0
    trail.Enabled = true
    trail.Attachment0 = attachment1
    trail.Attachment1 = attachment2
    trail.Parent = bullet
    
    return bullet
end

-- Create spread pattern for shotgun
function Shotgun.createSpreadPattern(startPosition, direction, seed)
	-- Set random seed for deterministic pattern
	math.randomseed(seed)
	
	local forwardVector = direction.Unit
	local rightVector, upVector
	
    -- For bullets from other players, calculate right/up vectors from the provided direction
    -- Cross product with world up vector (0,1,0) to get right vector
    rightVector = forwardVector:Cross(Vector3.new(0, 1, 0))		
    -- Cross product of right and forward to get up vector
    upVector = rightVector:Cross(forwardVector).Unit
	
	local bullets = {}
	
	-- Create evenly distributed spread pattern with random variation
	local baseDirections = {
		{x = 0, y = 0},        -- Center
		{x = 0.08, y = 0},     -- Right
		{x = -0.08, y = 0},    -- Left  
		{x = 0, y = 0.08},     -- Up
		{x = 0, y = -0.08},    -- Down
		{x = 0.06, y = 0.06},  -- Top-right
		{x = -0.06, y = 0.06}, -- Top-left
		{x = 0.06, y = -0.06}, -- Bottom-right
		{x = -0.06, y = -0.06} -- Bottom-left
	}
	
	local randomVariation = 0.03 -- Small random offset to add variety
	
	for i, baseDir in ipairs(baseDirections) do
		-- Add small random variation to the base direction
		local horizontalOffset = baseDir.x + (math.random() - 0.5) * randomVariation
		local verticalOffset = baseDir.y + (math.random() - 0.5) * randomVariation
		
		-- Apply the offset to create bullet direction
		local bulletDirection = (forwardVector + rightVector * horizontalOffset + upVector * verticalOffset).Unit
		-- Create slightly spread start positions (simulate pellets from different parts of barrel)
		local startPositionOffset = rightVector * (baseDir.x) + upVector * (baseDir.y)
		local pelletStartPosition = startPosition + startPositionOffset
		
		-- Each shotgun pellet is a separate bullet with one raycast each
		local bullet = {
			-- Single raycast per bullet (shotgun pellets)
			raycastData = {{
				direction = bulletDirection,
				startPosition = pelletStartPosition
			}},
			-- Animation direction is same as raycast direction
			animationDirection = bulletDirection,
			animationStartPosition = pelletStartPosition
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
        local distance = 300 * elapsedTime
        
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

function Shotgun.handleFireFromClient(direction, startPosition, seed)
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    -- Check fire rate
    local currentTime = tick()
    local fireRate = ShotgunConstants.FIRE_COOLDOWN or 0.5
    if not (currentTime - lastFireTime >= fireRate) then
        return {}, {} -- Return empty hits and bullets
    end
    
    lastFireTime = currentTime
    
    -- Use provided direction and startPosition
    local bullets = Shotgun.createSpreadPattern(startPosition, direction, seed)
    
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
            local maxDistance = ShotgunConstants.MAX_BULLET_DISTANCE
            local hitVector = hitPosition and hitPosition - bullet.animationStartPosition
            if hitVector then
                maxDistance = hitVector.Magnitude
            end
            
            -- Create bullet animation
            local updateBullet = Shotgun.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
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
                local humanoid = hitPart.Parent:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    humanoid:TakeDamage(ShotgunConstants.DAMAGE_PER_BULLET)
                end
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
    
    -- Handle damage display for shotgun
    if #hits > 0 then
        local avgHitPosition, validHits = HitGui.calculateAverageHitPosition(hits)
        if avgHitPosition and validHits > 0 then
            local totalDamage = validHits * ShotgunConstants.DAMAGE_PER_BULLET
            HitGui.showDamageNumber(totalDamage, avgHitPosition)
        end
    end
    
    return hits, bulletAnimations
end

function Shotgun.handleFireFromServer(bullets)
    local bulletAnimations = {}
    
    for _, bullet in ipairs(bullets) do
        local maxDistance = ShotgunConstants.MAX_BULLET_DISTANCE
        local hitVector = bullet.hitPosition and bullet.hitPosition - bullet.animationStartPosition
        if hitVector then
            maxDistance = hitVector.Magnitude
        end

        local updateBullet = Shotgun.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
        if updateBullet then
            bulletAnimations[bullet.id] = {
                update = updateBullet
            }
        end
    end
    
    return bulletAnimations
end

return Shotgun 