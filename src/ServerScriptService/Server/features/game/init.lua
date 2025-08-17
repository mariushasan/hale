local Teleport = require(game.ServerScriptService.Server.shared.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

local Teams = require(game.ServerScriptService.Server.features.game.Teams)
local Weapons = require(game.ServerScriptService.Server.features.weapons)
local MapVoting = require(game.ServerScriptService.Server.features.mapvoting)
local Spectator = require(game.ServerScriptService.Server.features.spectator)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local TimerRemoteEvent = events:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = events:WaitForChild("OutcomeRemoteEvent")
local Players = game:GetService("Players")


Players.CharacterAutoLoads = false

-- Create spectator status remote event
local spectatorStatusEvent = events:WaitForChild("SpectatorStatusEvent")

-- Constants
local TESTING = false
local MINUTE = 60
local GAME_TIME = 60
local WAITING_TIME = 3
local DEBOUNCE = 3
local PLAYER_THRESHOLD = 1
local states = {
	PLAYING = "PLAYING",
	END = "END",
}

-- Local properties
local playersWaiting = {}
local playersInArena = {}
local gameTimerTask = nil
local waitingMonitorTask = nil
local state = states.END

-- Define the Game object
local Game = {}

local function startPlayerMonitoring()
	if not waitingMonitorTask then
		waitingMonitorTask = task.spawn(function()
			while true do
				task.wait(1) -- Check every second
				
				-- Count alive players
				local waitingPlayerCount = 0
				for _, player in pairs(playersWaiting) do
					waitingPlayerCount = waitingPlayerCount + 1
				end
				
				-- Start game if we have enough players
				if waitingPlayerCount >= PLAYER_THRESHOLD and state == states.END then
					waitingMonitorTask = nil
					TimerRemoteEvent:FireAllClients(WAITING_TIME)
					-- Start map voting and get the winning map
					local winningMap = MapVoting.startVoting(WAITING_TIME)
					
					-- Load the winning map before starting the game
					print("winningMap", winningMap)
					if winningMap then
						local mapLoaded = MapVoting.loadMap(winningMap)
						if mapLoaded then
							print("Map loaded successfully, starting game with:", winningMap)
						else
							warn("Failed to load map:", winningMap, "- starting game anyway")
						end
					else
						warn("No winning map returned from voting!")
					end
					
					startGame()
					break
				end
			end
		end)
	end
end

function startGame()
	state = states.PLAYING

	if TESTING then
		return nil
	end

	-- Manually spawn all waiting players
	for userId, player in pairs(playersWaiting) do
		if player and player.Parent then -- Check if player is still in game
			player:LoadCharacter()
		end
	end
	
	-- Wait a moment for characters to load
	task.wait(1)

	-- Team assignment logic
	Teams.assignTeams(playersWaiting)

	-- Make Boss
	local bossPlayer = Teams.getBossPlayer()

	-- Count players in waiting table
	local waitingPlayerCount = 0
	for _ in pairs(playersWaiting) do
		waitingPlayerCount = waitingPlayerCount + 1
	end

	if waitingPlayerCount < PLAYER_THRESHOLD then
		endGame()
		return
	end

	if not bossPlayer then
		state = states.END
		return
	end

	-- Equip boss attack weapon (handles both server transformation and client notification)
	Weapons.equipPlayerWeapon(bossPlayer, "bossattack")

	for _, player in pairs(playersWaiting) do
		table.insert(playersInArena, player)
		playersWaiting[player.UserId] = nil
	end

	-- Synchronize random seed with all clients for deterministic spread patterns
	local RandomSeedEvent = events:WaitForChild("RandomSeedEvent")

	-- Start the game timer
	TimerRemoteEvent:FireAllClients(GAME_TIME)
	
	-- Update spectator status for all players
	Spectator.updateSpectatorStatus()

	-- End the game after done
	gameTimerTask = task.delay(GAME_TIME, function()
		gameTimerTask = nil -- Clear the reference since task is completing
		-- Game ended due to time - it's a draw
		OutcomeRemoteEvent:FireAllClients("Draw")
		endGame()
	end)
end

function endGame()
	state = states.END

	-- Cancel the game timer task if it's still running
	if gameTimerTask then
		task.cancel(gameTimerTask)
		gameTimerTask = nil
	end

	-- Reset boss player size and health
	local bossPlayer = Teams.getBossPlayer()
	-- Reset boss to normal weapon (handles both server de-transformation and client notification)
	if bossPlayer then
		Weapons.equipPlayerWeapon(bossPlayer, "shotgun")
	end

	-- Teleport players back to the waiting room

	TimerRemoteEvent:FireAllClients(WAITING_TIME)
					
	-- Start monitoring for enough players instead of auto-starting
	startPlayerMonitoring()

	Teams.assignWaitingTeams(playersInArena)

	for _, player in pairs(playersInArena) do
		table.insert(playersWaiting, player)
		playersInArena[player.UserId] = nil
	end

	local allPlayers = game.Players:GetPlayers()
	for _, player in pairs(allPlayers) do
		Leaderboard.setStat(player, "Damage", 0)
	end
end

-- Event listeners
function Game.init()
	Teams.init()

	local allPlayers = Players:GetPlayers()
	Teams.assignWaitingTeams(allPlayers)

	-- Start initial player monitoring
	startPlayerMonitoring()

	Players.PlayerAdded:Connect(function(player)
		player.Team = Teams.waitingTeam
		table.insert(playersWaiting, player)

		-- Add player to waiting list immediately (they'll be spectators until game starts)
		
		-- Update spectator status for the new player
		Spectator.updateSpectatorStatus()

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")

			-- Update spectator status when player spawn
			Spectator.updateSpectatorStatus()
			
			humanoid.Died:Connect(function()
				playersWaiting[player.UserId] = player
				playersInArena[player.UserId] = nil
				player.Team = Teams.waitingTeam
				
				-- Update spectator status when player dies
				Spectator.updateSpectatorStatus()
				
				-- Only check team elimination if game is currently playing
				if state == states.PLAYING then
					-- Check if entire team is eliminated
					local bossTeamAlive = false
					local survivorTeamAlive = false
					
					for _, arenaPlayer in pairs(playersInArena) do
						if arenaPlayer and arenaPlayer.Character and arenaPlayer.Character:FindFirstChild("Humanoid") then
							if arenaPlayer.Team == Teams.bossTeam then
								bossTeamAlive = true
							elseif arenaPlayer.Team == Teams.survivorTeam then
								survivorTeamAlive = true
							end
						end
					end
					
					-- End game if either team is completely eliminated
					if not bossTeamAlive then
						-- Boss team eliminated - survivors win
						for _, player in pairs(Players:GetPlayers()) do
							if player.Team == Teams.survivorTeam then
								OutcomeRemoteEvent:FireClient(player, "Victory")
							else
								OutcomeRemoteEvent:FireClient(player, "Defeat")
							end
						end
						TimerRemoteEvent:FireAllClients(0) -- Stop the timer
						endGame()
					elseif not survivorTeamAlive then
						-- Survivors eliminated - boss wins
						for _, player in pairs(Players:GetPlayers()) do
							if player.Team == Teams.bossTeam then
								OutcomeRemoteEvent:FireClient(player, "Victory")
							else
								OutcomeRemoteEvent:FireClient(player, "Defeat")
							end
						end
						TimerRemoteEvent:FireAllClients(0) -- Stop the timer
						endGame()
					end
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersWaiting[player.UserId] = nil
		playersInArena[player.UserId] = nil

		-- Only check team elimination if game is currently playing
		if state == states.PLAYING then
			-- Check if entire team is eliminated
			local bossTeamAlive = false
			local survivorTeamAlive = false
			
			for _, arenaPlayer in pairs(playersInArena) do
				if arenaPlayer and arenaPlayer.Character and arenaPlayer.Character:FindFirstChild("Humanoid") then
					if arenaPlayer.Team == Teams.bossTeam then
						bossTeamAlive = true
					elseif arenaPlayer.Team == Teams.survivorTeam then
						survivorTeamAlive = true
					end
				end
			end
			
			-- End game if either team is completely eliminated
			if not bossTeamAlive then
				-- Boss team eliminated - survivors win
				for _, player in pairs(Players:GetPlayers()) do
					if player.Team == Teams.survivorTeam then
						OutcomeRemoteEvent:FireClient(player, "Victory")
					else
						OutcomeRemoteEvent:FireClient(player, "Defeat")
					end
				end
				TimerRemoteEvent:FireAllClients(0) -- Stop the timer
				endGame()
			elseif not survivorTeamAlive then
				-- Survivors eliminated - boss wins
				for _, player in pairs(Players:GetPlayers()) do
					if player.Team == Teams.bossTeam then
						OutcomeRemoteEvent:FireClient(player, "Victory")
					else
						OutcomeRemoteEvent:FireClient(player, "Defeat")
					end
				end
				TimerRemoteEvent:FireAllClients(0) -- Stop the timer
				endGame()
			end
		end
	end)
end

return Game
