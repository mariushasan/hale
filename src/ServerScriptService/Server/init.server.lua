local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)
local Game = require(game.ServerScriptService.Server.features.game) -- Initialize the game
local Weapons = require(game.ServerScriptService.Server.features.weapons)
local Players = game:GetService("Players")
local TimeSync = require(game.ReplicatedStorage.shared.TimeSync)

-- Initialize TimeSync on server
TimeSync.init()

-- Create or get TimeSyncEvent for high-precision time synchronization
local timeSyncEvent = ReplicatedStorage:FindFirstChild("TimeSyncEvent")
if not timeSyncEvent then
	timeSyncEvent = Instance.new("RemoteEvent")
	timeSyncEvent.Name = "TimeSyncEvent"
	timeSyncEvent.Parent = ReplicatedStorage
end

-- Handle time sync requests from clients
timeSyncEvent.OnServerEvent:Connect(function(player, requestType, data)
	if requestType == "sync" then
		-- Original clock sync request
		local clientSendTime = data
		local serverTime = DateTime.now().UnixTimestampMillis
		
		-- Send back to client with both client send time and server time
		timeSyncEvent:FireClient(player, "sync_response", {
			clientSendTime = clientSendTime,
			serverTime = serverTime
		})
		
	elseif requestType == "create_test_part" then
		-- Create invisible test part for replication delay measurement
		local partName = "TimeSyncPart_" .. player.UserId
		
		-- Remove existing part if it exists
		local existingPart = workspace:FindFirstChild(partName)
		if existingPart then
			existingPart:Destroy()
		end
		
		-- Create new test part
		local testPart = Instance.new("Part")
		testPart.Name = partName
		testPart.Size = Vector3.new(1, 1, 1)
		testPart.Position = Vector3.new(0, -1000, 0) -- Far away position
		testPart.Anchored = true
		testPart.CanCollide = false
		testPart.Transparency = 1 -- Invisible
		testPart.Parent = workspace
		
		-- Notify client that part is created
		timeSyncEvent:FireClient(player, "test_part_created", {
			partName = partName
		})
		
	elseif requestType == "move_test_part" then
		-- Move the test part to measure replication delay
		local partName = "TimeSyncPart_" .. player.UserId
		local serverMoveTime = data.serverMoveTime
		
		local testPart = workspace:FindFirstChild(partName)
		if testPart then
			-- Move the part to a new position
			local newPosition = Vector3.new(math.random(-100, 100), -1000, math.random(-100, 100))
			testPart.Position = newPosition
			
			-- Send confirmation back to client with move time
			timeSyncEvent:FireClient(player, "part_moved", {
				serverMoveTime = serverMoveTime,
				newPosition = newPosition
			})
		else
			warn("TimeSync: Test part not found for player", player.Name)
		end
	end
end)

-- Function to set player walk speed
local function setPlayerSpeed(player)
	local speed = 40 -- Adjust this value to change the run speed

	-- Wait for the character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function setPlayerJumpHeight(player)
	local jumpHeight = 40 -- Adjust this value to change the jump height

	-- Wait for the character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpHeight
	end
end

local function setPlayerData(player)
	Leaderboard.setStat(player, "Damage", 0)
end

Players.PlayerAdded:Connect(setPlayerSpeed)
Players.PlayerAdded:Connect(setPlayerJumpHeight)
Players.PlayerAdded:Connect(setPlayerData)

Game.init()
Weapons.init()

-- Create moving reference part for lag compensation
local function createLagCompensationReference()
	-- Remove existing reference part if it exists
	local existingPart = workspace:FindFirstChild("LagCompensationReference")
	if existingPart then
		existingPart:Destroy()
	end
	
	-- Create the reference part
	local referencePart = Instance.new("Part")
	referencePart.Name = "LagCompensationReference"
	referencePart.Size = Vector3.new(4, 4, 4) -- Make it bigger for visibility
	referencePart.Position = Vector3.new(0, 50, 0) -- Move to visible height for debugging
	referencePart.Anchored = true
	referencePart.CanCollide = false
	referencePart.Transparency = 0.5 -- Make it semi-transparent for debugging
	referencePart.BrickColor = BrickColor.new("Bright red")
	referencePart.Material = Enum.Material.Neon
	referencePart.Parent = workspace
	
	-- Start the movement pattern
	local startPos = Vector3.new(0, 0, 0) -- Visible height for debugging
	local endPos = Vector3.new(0, 100, 0) -- 1000 studs distance at visible height
	local speed = 50 -- studs per second
	local direction = 1 -- 1 for forward, -1 for backward
	
	-- Use Heartbeat for accurate movement timing
	local heartbeatConnection
	heartbeatConnection = game:GetService("RunService").Heartbeat:Connect(function(deltaTime)
		if not referencePart.Parent then
			heartbeatConnection:Disconnect()
			return
		end
		
		local currentPos = referencePart.Position
		local targetPos = direction == 1 and endPos or startPos
		
		-- Calculate movement
		local distance = (targetPos - currentPos).Magnitude
		local moveVector = (targetPos - currentPos).Unit * speed * deltaTime
		
		-- Move the part
		if distance > speed * deltaTime then
			referencePart.Position = currentPos + moveVector
		else
			-- Reached target, reverse direction
			referencePart.Position = targetPos
			direction = direction * -1
		end
	end)
	
	print("Lag compensation reference part created and moving")
	return referencePart
end

-- Initialize the reference part
createLagCompensationReference()