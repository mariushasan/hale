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

-- Reference part no longer needed with new hit-verification approach