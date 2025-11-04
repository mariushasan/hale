local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)
local Game = require(game.ServerScriptService.Server.features.game) -- Initialize the game
local Weapons = require(game.ServerScriptService.Server.features.weapons)
local Inventory = require(game.ServerScriptService.Server.features.inventory)
local MapVoting = require(game.ServerScriptService.Server.features.mapvoting)
local Players = game:GetService("Players")

Inventory.init()
MapVoting.init()

-- Function to set player walk speed
local function setPlayerSpeed(character)
	local speed = 40 -- Adjust this value to change the run speed
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function setPlayerJumpHeight(character)
	local jumpHeight = 80 -- Adjust this value to change the jump height
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpHeight
	end
end

local function setPlayerData(player)
	Leaderboard.setStat(player, "Damage", 0)
end

-- Handle player joining and respawning
Players.PlayerAdded:Connect(function(player)
	-- Set up character spawning (both initial and respawns)
	player.CharacterAdded:Connect(function(character)
		setPlayerSpeed(character)
		setPlayerJumpHeight(character)
	end)
	
	-- Set leaderboard data (only needs to be done once per player)
	setPlayerData(player)
end)

Game.init()
Weapons.init()