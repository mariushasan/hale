local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)
local Game = require(game.ServerScriptService.Server.features.game) -- Initialize the game
local Weapons = require(game.ServerScriptService.Server.features.weapons)
local Players = game:GetService("Players")

-- Function to set player walk speed
local function setPlayerSpeed(player)
	local speed = 70 -- Adjust this value to change the run speed

	-- Wait for the character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function setPlayerJumpHeight(player)
	local jumpHeight = 50 -- Adjust this value to change the jump height

	-- Wait for the character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpHeight
	end
end

local function setPlayerData(player)
	Leaderboard.setStat(player, "Goals", 0)
end

Players.PlayerAdded:Connect(setPlayerSpeed)
Players.PlayerAdded:Connect(setPlayerJumpHeight)
Players.PlayerAdded:Connect(setPlayerData)

Game.initialize()
Weapons.init()