local Teleport = require(game.ServerScriptService.Server.shared.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

local Teams = require(game.ServerScriptService.Server.features.game.Teams)
local Weapons = require(game.ServerScriptService.Server.features.weapons)
local MapVoting = require(game.ServerScriptService.Server.features.mapvoting)
local Spectator = require(game.ServerScriptService.Server.features.spectator)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local TimerRemoteEvent = events:WaitForChild("TimerRemoteEvent")
local GameUIReadyEvent = events:WaitForChild("GameUIReadyEvent")
local OutcomeRemoteEvent = events:WaitForChild("OutcomeRemoteEvent")
local Players = game:GetService("Players")

-- Enable character auto-loads but we'll control where they spawn
Players.CharacterAutoLoads = true

-- Create spectator status remote event

-- Constants
local TESTING = false
local MINUTE = 60
local GAME_TIME = 200
local VOTING_TIME = 5
local DEBOUNCE = 3
local PLAYER_THRESHOLD = 1
local states = {
	PLAYING = "PLAYING",
	END = "END",
	VOTING = "VOTING",
}

-- Hidden waiting room location (far away from the game area but safe)
local WAITING_ROOM_POSITION = Vector3.new(0, 1000, 0)

-- Local properties
local playersWaiting = {}
local playersInArena = {}
local gameTimerTask = nil
local waitingMonitorTask = nil
local state = states.END
local currentWaitingTime = 0

-- Define the Game object
local Game = {}

local function teleportPlayerToSpawn(player)
	local character = player.Character
	if not character then 
		print("No character found for player:", player.Name)
		return 
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		print("No humanoid found for player:", player.Name)
		return
	end
	
	print("Player", player.Name, "has character and humanoid, health:", humanoid.Health)
	
	local spawnLocation = workspace:FindFirstChild("SpawnLocation", true)
	print("Teleporting player to spawn location", spawnLocation)
	if spawnLocation then
		local spawnCFrame = spawnLocation.CFrame + Vector3.new(0, 5, 0)
		print("Teleporting player to spawn location", spawnCFrame)
		character:PivotTo(spawnCFrame)
		print("Player", player.Name, "teleported to spawn, health after teleport:", humanoid.Health)
	end
end

local function teleportPlayerToWaitingRoom(player)
	local character = player.Character
	if not character then 
		print("No character found for player in waiting room:", player.Name)
		return 
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		print("No humanoid found for player in waiting room:", player.Name)
		return
	end
	
	print("Player", player.Name, "going to waiting room, health:", humanoid.Health)

	local WaitingLocation = workspace:FindFirstChild("WaitingLocation", true)
	if WaitingLocation then
		print("Using WaitingLocation at:", WaitingLocation.Position)
		character:PivotTo(WaitingLocation.CFrame + Vector3.new(0, 5, 0))
		print("Player", player.Name, "teleported to waiting room, health after teleport:", humanoid.Health)
	else
		print("No WaitingLocation found, using fallback position at:", WAITING_ROOM_POSITION)
		-- Use a safer position that's definitely above the world
		local safeWaitingPosition = Vector3.new(0, 2000, 0) -- Much higher to ensure safety
		character:PivotTo(CFrame.new(safeWaitingPosition))
		print("Player", player.Name, "teleported to fallback waiting room at", safeWaitingPosition, "health after teleport:", humanoid.Health)
	end
	
	-- Check position after teleport
	task.wait(0.1)
	print("Player", player.Name, "final position after teleport:", character:GetPivot().Position)
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
					state = states.VOTING
					TimerRemoteEvent:FireAllClients(VOTING_TIME)

					currentWaitingTime = VOTING_TIME

					task.spawn(function()
						while currentWaitingTime < VOTING_TIME do
							task.wait(1)
							currentWaitingTime = currentWaitingTime - 1
						end
					end)

					-- Start map voting and get the winning map
					local winningMap = MapVoting.startVoting(VOTING_TIME)
					
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

	-- Teleport all waiting players to spawn location
	for userId, player in pairs(playersWaiting) do
		if player and player.Parent then
			teleportPlayerToSpawn(player)
			Spectator.updateSpectatorStatus(player, false)
		end
	end

	-- Wait a moment for teleportation to complete
	task.wait(0.5)

	-- Equip boss attack weapon (handles both server transformation and client notification)
	Weapons.equipPlayerWeapon(bossPlayer, "bossattack")

	for _, player in pairs(playersWaiting) do
		table.insert(playersInArena, player)
		playersWaiting[player.UserId] = nil
	end

	-- Start the game timer
	TimerRemoteEvent:FireAllClients(GAME_TIME)
	
	-- Update spectator status for all players

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

	TimerRemoteEvent:FireAllClients(VOTING_TIME)
					
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
	GameUIReadyEvent.OnServerEvent:Connect(function(player)
		if state == states.VOTING then
			TimerRemoteEvent:FireClient(player, currentWaitingTime)
		end
	end)

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
		Spectator.updateSpectatorStatus(player, true)

		player.CharacterAdded:Connect(function(character)
			print("Character added for player:", player.Name)
			
			-- Wait for humanoid to be available
			local humanoid = character:WaitForChild("Humanoid", 5)
			if not humanoid then
				print("Failed to get humanoid for player:", player.Name)
				return
			end
			
			print("Humanoid found for player:", player.Name, "Health:", humanoid.Health, "MaxHealth:", humanoid.MaxHealth)
			
			-- Teleport new character to waiting room immediately
			task.wait(0.1) -- Small delay to ensure character is fully loaded
			local playerInArena = false
			for _, arenaPlayer in pairs(playersInArena) do
				if arenaPlayer.UserId == player.UserId then
					playerInArena = true
					break
				end
			end
			if not playerInArena then
				teleportPlayerToWaitingRoom(player)
			end
			
			local humanoid = character:WaitForChild("Humanoid")

			-- Update spectator status when player spawn
			
			humanoid.Died:Connect(function()
				print("Player", player.Name, "died! Health:", humanoid.Health, "MaxHealth:", humanoid.MaxHealth)
				print("Character position:", character:GetPivot().Position)
				print("Game state:", state)
				
				playersWaiting[player.UserId] = player
				playersInArena[player.UserId] = nil
				player.Team = Teams.waitingTeam
				
				-- Update spectator status when player dies
				Spectator.updateSpectatorStatus(player, true)
				
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
