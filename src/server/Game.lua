local Teleport = require(game.ServerScriptService.Server.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.Leaderboard)

local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
local OutComeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")

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
local states = {
	WAITING = "WAITING",
	PLAYING = "PLAYING",
	END = "END",
}

-- create two teams
local bossTeam = Instance.new("Team")
bossTeam.TeamColor = BrickColor.new("Bright red")
bossTeam.AutoAssignable = false
bossTeam.Name = "Boss"
bossTeam.Parent = Teams

local otherTeam = Instance.new("Team")
otherTeam.TeamColor = BrickColor.new("Bright blue")
otherTeam.AutoAssignable = false
otherTeam.Name = "Other"
otherTeam.Parent = Teams

local waitingTeam = Instance.new("Team")
waitingTeam.TeamColor = BrickColor.new("Grey")
waitingTeam.AutoAssignable = true
waitingTeam.Name = "Waiting"
waitingTeam.Parent = Teams

-- Local properties
local teleportToArena = Teleport:new(TeleportPlatform, Baseplate)
local teleportToWait = Teleport:new(Baseplate, TeleportPlatform)

local playersWaiting = {}
local playersInArena = {}

local deboucedWaitingPlayers = {}
local debouncedArenaPlayers = {}

local state = states.END

-- Define the Game object
local Game = {}

function Game.startGame()
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
	state = states.PLAYING

	-- Teleport players to the arena
	teleportToArena:teleportPlayers(playersWaiting)

	-- Team assignment logic
	local userIds = {}

	for userId, player in pairs(playersWaiting) do
		table.insert(userIds, userId)
		player.Team = otherTeam
	end

	local bossPlayer = playersWaiting[userIds[math.random(#userIds)]]
	bossPlayer.Team = bossTeam

	-- Clear players waiting queue
	for userId in pairs(playersWaiting) do
		playersWaiting[userId] = nil
	end

	-- Start the game timer
	TimerRemoteEvent:FireAllClients(GAME_TIME)

	-- End the game after done
	task.delay(GAME_TIME, function()
		Game.endGame()
	end)
end

function Game.endGame()
	-- Determine outcome and inform clients
	local redTeamScore = 0
	local blueTeamScore = 0
	local outcome = ""
	for _, player in bossTeam:GetPlayers() do
		redTeamScore += Leaderboard.getStat(player, "Goals")
	end
	for _, player in otherTeam:GetPlayers() do
		blueTeamScore += Leaderboard.getStat(player, "Goals")
	end
	if redTeamScore > blueTeamScore then
		outcome = "Red Team"
	elseif blueTeamScore > redTeamScore then
		outcome = "Blue Team"
	else
		outcome = "Draw"
	end

	-- Debounce players to prevent teleporting back and forth
	for userId, player in pairs(playersInArena) do
		local playerOutcome = ""
		if outcome == player.Team.Name then
			playerOutcome = "Victory"
		elseif outcome == "Draw" then
			playerOutcome = "Draw"
		else
			playerOutcome = "Defeat"
		end

		OutComeRemoteEvent:FireClient(player, playerOutcome)
		player.Team = waitingTeam
		if not debouncedArenaPlayers[userId] then
			debouncedArenaPlayers[userId] = true
			task.delay(DEBOUNCE, function()
				debouncedArenaPlayers[userId] = false
			end)
		end
	end

	-- Set the game state to end
	state = states.END

	-- Teleport players back to the waiting room
	teleportToWait:teleportPlayers(playersInArena)

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

	if state == states.END then
		local playerAmount = {}
		for k in pairs(playersWaiting) do
			table.insert(playerAmount, k)
		end

		if #playerAmount >= PLAYER_THRESHOLD then
			state = states.WAITING
			task.delay(WAITING_TIME, function()
				Game.startGame()
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

return Game
