local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local Shotgun = {}

-- Create identical spread pattern to client (deterministic)
function Shotgun.createSpreadPattern(startPosition, direction, seed)
	-- Set random seed for deterministic pattern
	if seed then
		math.randomseed(seed)
	end
	
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

-- Server-side hit validation
function Shotgun.handleFireFromServer(shooterLagPart, direction, startPosition, seed, collisionGroup)
	local bullets = Shotgun.createSpreadPattern(startPosition, direction, seed)
	local validatedHits = {}
	
	-- Assign bullet IDs (server-side)
	for i, bullet in ipairs(bullets) do
		bullet.id = shooterLagPart.Name .. "_" .. tick() .. "_" .. i
	end
	
	-- Perform server-side raycasts for each bullet
	for _, bullet in ipairs(bullets) do
		local raycastParams = RaycastParams.new()
		raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
		raycastParams.FilterDescendantsInstances = {shooterLagPart}
		raycastParams.CollisionGroup = collisionGroup
		
		local bulletHit = false
		local hitPart = nil
		local hitPosition = nil
		local hitRaycastData = nil
		local hitCharacter = nil
		
		-- Try each raycast for this bullet until we get a hit
		for _, raycastData in ipairs(bullet.raycastData) do
			if bulletHit then break end
			
			-- Raycast in the direction we're shooting
			local raycastDistance = 1000 -- Max shooting distance
			local raycastResult = workspace:Raycast(raycastData.startPosition, raycastData.direction * raycastDistance, raycastParams)
			
			if raycastResult then
				local hitInstance = raycastResult.Instance
				local character = hitInstance.Parent
				local humanoid = character:FindFirstChildOfClass("Humanoid")
				
				hitPart = hitInstance
				hitPosition = raycastResult.Position
				hitRaycastData = raycastData
				hitCharacter = character -- This will be nil for lag parts, but that's ok
				bulletHit = true
			end
		end
		
		-- Calculate max distance for animation
		local maxDistance = ShotgunConstants.RANGE
		local hitVector = hitPosition and hitPosition - bullet.animationStartPosition
		if hitVector then
			maxDistance = hitVector.Magnitude
		end
		
		-- Add validated hit data
		if bulletHit then
			table.insert(validatedHits, {
				id = bullet.id,
				direction = hitRaycastData.direction,
				startPosition = hitRaycastData.startPosition,
				animationStartPosition = bullet.animationStartPosition,
				animationDirection = bullet.animationDirection,
				hitPart = hitPart,
				hitPosition = hitPosition,
				hitCharacter = hitCharacter,
				maxDistance = maxDistance,
			})
		else
			table.insert(validatedHits, {
				id = bullet.id,
				animationStartPosition = bullet.animationStartPosition,
				animationDirection = bullet.animationDirection,
				hitPosition = hitPosition,
				maxDistance = maxDistance,
			})
		end
	end
	
	return validatedHits
end

return Shotgun
