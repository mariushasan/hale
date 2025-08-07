local Teleport = require(game.ServerScriptService.Server.shared.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

local Teams = require(game.ServerScriptService.Server.features.game.Teams)
local Weapons = require(game.ServerScriptService.Server.features.weapons)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")
local Players = game:GetService("Players")

-- Parts
local TeleportWaiting = game.Workspace.WaitingRoom.TeleportWaiting
local TeleportArena = game.Workspace.TeleportArena
local WaitingRoomFloor = game.Workspace.WaitingRoom.Floor

-- Constants
local TESTING = false
local MINUTE = 60
local GAME_TIME = 60
local WAITING_TIME = 2
local DEBOUNCE = 3
local PLAYER_THRESHOLD = 1
local states = {
	WAITING = "WAITING",
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
function startGame()
	state = states.PLAYING

	if TESTING then
		return nil
	end

	-- Teleport players to the arena

	-- Team assignment logic
	Teams.assignTeams(playersWaiting)

	-- Make Boss
	local bossPlayer = Teams.getBossPlayer()

	-- Count players in waiting table
	local playerCount = 0
	for _ in pairs(playersWaiting) do
		playerCount = playerCount + 1
	end

	if not bossPlayer or playerCount < PLAYER_THRESHOLD then
		state = states.END
		return
	end

	-- Equip boss attack weapon (handles both server transformation and client notification)
	Weapons.equipPlayerWeapon(bossPlayer, "bossattack")

	teleportToArena:teleportPlayers(playersWaiting)
	-- Synchronize random seed with all clients for deterministic spread patterns
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local RandomSeedEvent = ReplicatedStorage:WaitForChild("RandomSeedEvent")

	-- Start the game timer
	TimerRemoteEvent:FireAllClients(GAME_TIME)

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
	teleportToWait:teleportPlayers(playersInArena)

	-- Back to waiting team
	Teams.assignWaitingTeams(playersInArena)

	-- Reset player stats
	local allPlayers = game.Players:GetPlayers()
	for _, player in pairs(allPlayers) do
		Leaderboard.setStat(player, "Damage", 0)
	end
end

-- Event listeners
function Game.init()
	Teams.init()

	for _, player in pairs(Players:GetPlayers()) do
		player.Team = Teams.waitingTeam
	end

	Players.PlayerAdded:Connect(function(player)
		player.Team = Teams.waitingTeam

		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid")
			
			humanoid.Died:Connect(function()
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
						print("6")
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
						print("5")
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
				print("4")
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
				print("3")
				TimerRemoteEvent:FireAllClients(0) -- Stop the timer
				endGame()
			end
		end
	end)

	TeleportWaiting.Touched:Connect(function(hit)
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player and not playersWaiting[player.UserId] then
			playersWaiting[player.UserId] = player
			playersInArena[player.UserId] = nil
		end

		-- Count players in waiting table
		local playerCount = 0
		for _ in pairs(playersWaiting) do
			playerCount = playerCount + 1
		end

		if state == states.END then
			if playerCount >= PLAYER_THRESHOLD then
				state = states.WAITING
				
				waitingMonitorTask = task.spawn(function()
					for i = WAITING_TIME, 1, -1 do
						task.wait(1)
						
						-- Count players in waiting table
						local currentPlayerCount = 0
						for _ in pairs(playersWaiting) do
							currentPlayerCount = currentPlayerCount + 1
						end
						
						if currentPlayerCount < PLAYER_THRESHOLD then
							state = states.END
							print("2")
							TimerRemoteEvent:FireAllClients(0)
							waitingMonitorTask = nil
							return
						end
					end
					
					waitingMonitorTask = nil
					startGame()
				end)
				print("1")
				TimerRemoteEvent:FireAllClients(WAITING_TIME)
			end
		end
	end)

	TeleportArena.Touched:Connect(function(hit)
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player and not playersInArena[player.UserId] then
			playersInArena[player.UserId] = player
			playersWaiting[player.UserId] = nil
		end
	end)

	WaitingRoomFloor.Touched:Connect(function(hit)
		local player = game.Players:GetPlayerFromCharacter(hit.Parent)
		if player and playersWaiting[player.UserId] then
			playersWaiting[player.UserId] = nil
		end
	end)
end

return Game
