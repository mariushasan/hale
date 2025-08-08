local Teleport = require(game.ServerScriptService.Server.shared.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

local Teams = require(game.ServerScriptService.Server.features.game.Teams)
local Weapons = require(game.ServerScriptService.Server.features.weapons)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")
local Players = game:GetService("Players")
Players.CharacterAutoLoads = false

-- Create spectator status remote event
local spectatorStatusEvent = ReplicatedStorage:WaitForChild("SpectatorStatusEvent")

-- Parts
local TeleportWaiting = game.Workspace.WaitingRoom.TeleportWaiting
local TeleportArena = game.Workspace.TeleportArena
local WaitingRoomFloor = game.Workspace.WaitingRoom.Floor

-- Constants
local TESTING = false
local MINUTE = 60
local GAME_TIME = 120
local WAITING_TIME = 5
local DEBOUNCE = 3
local PLAYER_THRESHOLD = 1
local states = {
	PLAYING = "PLAYING",
	END = "END",
}

-- Local properties
local teleportToArena = Teleport:new(TeleportWaiting, TeleportArena)
local teleportToWait = Teleport:new(TeleportArena, TeleportWaiting)

local playersWaiting = {}
local playersInArena = {}
local gameTimerTask = nil
local waitingMonitorTask = nil
local state = states.END

-- Define the Game object
local Game = {}

-- Internal functions
local function updateSpectatorStatus()
	for _, player in pairs(Players:GetPlayers()) do
		local isSpectator = false
		
		-- Player is spectator if they're in playersWaiting (dead/waiting)
		if playersWaiting[player.UserId] then
			isSpectator = true
		end
		
		-- Player is also spectator if they're dead during a game
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			if player.Character.Humanoid.Health <= 0 and state == states.PLAYING then
				isSpectator = true
			end
		end
		
		spectatorStatusEvent:FireClient(player, isSpectator)
	end
end

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
					task.wait(WAITING_TIME)
					startGame()
					break
				end
			end
		end)
	end
end

function startGame()
	state = states.PLAYING
	print(playersWaiting)
	if TESTING then
		return nil
	end

	-- Manually spawn all waiting players
	for userId, player in pairs(playersWaiting) do
		print(player)
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
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RandomSeedEvent = ReplicatedStorage:WaitForChild("RandomSeedEvent")

	-- Start the game timer
	TimerRemoteEvent:FireAllClients(GAME_TIME)
	
	-- Update spectator status for all players
	print("1")
	updateSpectatorStatus()

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
	
	-- Update spectator status after game ends
	print("2")
	updateSpectatorStatus()
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
		print(playersWaiting)

		-- Add player to waiting list immediately (they'll be spectators until game starts)
		
		-- Update spectator status for the new player
		updateSpectatorStatus()

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")

			-- Update spectator status when player spawn
			print("3")
			updateSpectatorStatus()
			
			humanoid.Died:Connect(function()
				playersWaiting[player.UserId] = player
				playersInArena[player.UserId] = nil
				player.Team = Teams.waitingTeam
				
				-- Update spectator status when player dies
				print("4")
				updateSpectatorStatus()
				
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
		
		-- Update spectator status when player leaves
		print("5")
		updateSpectatorStatus()
		
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
