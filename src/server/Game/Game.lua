local Teleport = require(game.ServerScriptService.Server.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.Leaderboard)

local TeamAssignment = require(game.ServerScriptService.Server.Game.teams)
local BossFunctions = require(game.ServerScriptService.Server.Game.boss)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
-- local OutComeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")

-- Parts
local WaitingPlatform = game.Workspace.WaitingRoom.WaitingPlatform
local TeleportPlatform = game.Workspace.WaitingRoom.TeleportPlatform
local Baseplate = game.Workspace.Baseplate

-- Constants
local MINUTE = 60
local GAME_TIME = 3 * MINUTE
local WAITING_TIME = 15
local DEBOUNCE = 3
local PLAYER_THRESHOLD = 1
local gameStates = {
	WAITING = "WAITING",
	PLAYING = "PLAYING",
	END = "END",
}

local playerStates = {
	WAITING = "WAITING",
	PLAYING = "PLAYING",
	SPECTATING = "SPECTATING",
}

-- Local properties
local teleportToArena = Teleport:new(TeleportPlatform, Baseplate)
local teleportToWait = Teleport:new(Baseplate, TeleportPlatform)

local playersWaiting = {}
local playersSpecating = {}
local playersInArena = {}

local deboucedWaitingPlayers = {}
local debouncedArenaPlayers = {}

local state = gameStates.END

-- Define the Game object
local Game = {}

-- Exported functions
function Game.isPlayerInArena(player)
	return playersInArena[player.UserId] ~= nil
end

-- Internal functions
function startGame()
	-- Debounce players to prevent teleporting back and forth
	for userId in pairs(playersWaiting) do
		if not deboucedWaitingPlayers[userId] then
			deboucedWaitingPlayers[userId] = true
			task.delay(DEBOUNCE, function()
				deboucedWaitingPlayers[userId] = false
			end)
		end
	end

	-- Set the game state to playing
	state = gameStates.PLAYING

	-- Teleport players to the arena
	teleportToArena:teleportPlayers(playersWaiting)

	-- Team assignment logic
	TeamAssignment.assignTeams(playersWaiting)

	-- Make Boss
	local bossPlayer = TeamAssignment.getBossPlayer()
	BossFunctions.makeBoss(bossPlayer)

	-- Clear players waiting queue
	for userId in pairs(playersWaiting) do
		playersWaiting[userId] = nil
	end

	-- Start the game timer
	TimerRemoteEvent:FireAllClients(GAME_TIME)

	-- End the game after done
	task.delay(GAME_TIME, function()
		endGame()
	end)
end

function endGame()
	-- Debounce players to prevent teleporting back and forth
	for userId, player in pairs(playersInArena) do
		if not debouncedArenaPlayers[userId] then
			debouncedArenaPlayers[userId] = true
			task.delay(DEBOUNCE, function()
				debouncedArenaPlayers[userId] = false
			end)
		end
	end

	-- Set the game state to end
	state = gameStates.END

	-- Reset boss player size and health
	local bossPlayer = TeamAssignment.getBossPlayer()
	BossFunctions.removeBoss(bossPlayer)

	-- Teleport players back to the waiting room
	teleportToWait:teleportPlayers(playersInArena)

	-- Back to waiting team
	TeamAssignment.assignWaitingTeams(playersInArena)
	TeamAssignment.assignWaitingTeams(playersSpecating)

	-- Reset player stats
	local allPlayers = game.Players:GetPlayers()
	for _, player in pairs(allPlayers) do
		Leaderboard.setStat(player, "Goals", 0)
	end

	-- Clear players in arena queue
	for userId, _ in pairs(playersInArena) do
		playersInArena[userId] = nil
	end
end

-- Event listeners
TeleportPlatform.Touched:Connect(function(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and not playersWaiting[player.UserId] and not deboucedWaitingPlayers[player.UserId] then
		playersWaiting[player.UserId] = player
	end

	if state == gameStates.END then
		local playerAmount = {}
		for k in pairs(playersWaiting) do
			table.insert(playerAmount, k)
		end

		if #playerAmount >= PLAYER_THRESHOLD then
			state = gameStates.WAITING
			task.delay(WAITING_TIME, function()
				startGame()
			end)
			TimerRemoteEvent:FireAllClients(WAITING_TIME)
		end
	end
end)

Baseplate.Touched:Connect(function(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and not playersInArena[player.UserId] and not debouncedArenaPlayers[player.UserId] then
		playersInArena[player.UserId] = player
	end
end)

WaitingPlatform.Touched:Connect(function(hit)
	local player = game.Players:GetPlayerFromCharacter(hit.Parent)
	if player and playersWaiting[player.UserId] then
		playersWaiting[player.UserId] = nil
	end
end)

game.Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		character.Humanoid.Died:Connect(function()
			if playersInArena[player.UserId] then
				playersInArena[player.UserId] = nil
				playersSpecating[player.UserId] = player
				teleportToWait:teleportPlayer(player)
			end
		end)
	end)
end)

return Game
