local Teleport = require(game.ServerScriptService.Server.shared.Teleport)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

local Teams = require(game.ServerScriptService.Server.features.game.Teams)
local Weapons = require(game.ServerScriptService.Server.features.weapons)
local MapVoting = require(game.ServerScriptService.Server.features.mapvoting)
local Spectator = require(game.ServerScriptService.Server.features.spectator)
local Inventory = require(game.ServerScriptService.Server.features.inventory)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local TimerRemoteEvent = events:WaitForChild("TimerRemoteEvent")
local GameUIReadyEvent = events:WaitForChild("GameUIReadyEvent")
local OutcomeRemoteEvent = events:WaitForChild("OutcomeRemoteEvent")
local Players = game:GetService("Players")

local TeamTypes = require(ReplicatedStorage.features.teams)

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
local gameTimerTask = nil
local waitingMonitorTask = nil
local state = states.END
local currentWaitingTime = 0

-- Define the Game object
local Game = {}

local function teleportPlayerToSpawn(player)
	local character = player.Character
	if not character then 
		return 
	end
	
	local humanoid = character:FindFirstChild("Humanoid")
	if not humanoid then
		return
	end
		
	local gameStart = workspace:FindFirstChild("GameStart", true)
	if gameStart then
		local spawnCFrame = gameStart.CFrame + Vector3.new(0, 5, 0)
		character:PivotTo(spawnCFrame)
	end
end

local function startPlayerMonitoring()
	if not waitingMonitorTask then
		waitingMonitorTask = task.spawn(function()
			while true do
				task.wait(1) -- Check every second
				
				-- Count alive players
				local waitingPlayerCount = 0
				for _, player in pairs(Players:GetPlayers()) do
					if player.Team.Name == TeamTypes.WAITING then
						waitingPlayerCount = waitingPlayerCount + 1
					end
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
	-- Team assignment logic
	local allPlayers = Players:GetPlayers()
	-- Count players in waiting table
	local waitingPlayerCount = 0

	for _, player in pairs(allPlayers) do
		if player.Team.Name == TeamTypes.WAITING then
			waitingPlayerCount = waitingPlayerCount + 1
		end
	end

	if waitingPlayerCount < PLAYER_THRESHOLD then
		endGame()
		return
	end

	Teams.assignTeams(allPlayers)

	-- Make Boss
	local bossPlayer = Teams.getBossPlayer()

	if not bossPlayer then
		endGame()
		return
	end

	state = states.PLAYING

	for _, player in pairs(allPlayers) do
		local character = player.Character

		if character then
			local HumanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

			if HumanoidRootPart then
				HumanoidRootPart.Anchored = false
			end
		end

		teleportPlayerToSpawn(player)
		Spectator.updateSpectatorStatus(player, false)
		if player == bossPlayer then
			Weapons.equipPlayerWeapon(player, "BossAttack")
		else
			Weapons.equipCurrentWeapon(player)
		end
	end

	task.wait(0.5)

	TimerRemoteEvent:FireAllClients(GAME_TIME)

	gameTimerTask = task.delay(GAME_TIME, function()
		gameTimerTask = nil
		OutcomeRemoteEvent:FireAllClients("Draw", 5)
		
		-- Award coins for draw (same as loss)
		local allPlayers = Players:GetPlayers()
		local bossPlayer = Teams.getBossPlayer()
		
		for _, player in pairs(allPlayers) do
			if player.Team.Name == TeamTypes.SURVIVOR then
				-- Survivors get loss reward (50 coins)
				Inventory.addCoins(player, 50)
				Inventory.savePlayerData(player)
			elseif player == bossPlayer then
				-- Boss gets loss reward (75 coins)
				Inventory.addCoins(player, 75)
				Inventory.savePlayerData(player)
			end
		end

		task.wait(5)
		endGame()
	end)
end

function endGame()
	state = states.END

	if gameTimerTask then
		task.cancel(gameTimerTask)
		gameTimerTask = nil
	end

	local bossPlayer = Teams.getBossPlayer()

	if bossPlayer then
		Weapons.equipPreviousWeapon(bossPlayer)
	end
					
	startPlayerMonitoring()

	local allPlayers = Players:GetPlayers()

	Teams.assignWaitingTeams(allPlayers)

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
		Teams.assignWaitingTeam(player)

		-- Add player to waiting list immediately (they'll be spectators until game starts)
		
		-- Update spectator status for the new player

		player.CharacterAdded:Connect(function(character)
			local HumanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)

			if HumanoidRootPart and player.Team.Name == TeamTypes.WAITING then
				HumanoidRootPart.Anchored = true
			end
			
			-- Wait for humanoid to be available
			local humanoid = character:WaitForChild("Humanoid", 5)
			if not humanoid then
				return
			end			
			-- Teleport new character to waiting room immediately
			task.wait(0.5) -- Small delay to ensure character is fully loaded
			
			local humanoid = character:WaitForChild("Humanoid")

			-- Update spectator status when player spawn
			
			humanoid.Died:Connect(function()
				-- Store team before reassigning (needed for coin rewards)
				local wasSurvivor = player.Team.Name == TeamTypes.SURVIVOR
				
				Teams.assignWaitingTeam(player)
				
				-- Update spectator status when player dies
				
				-- Only check team elimination if game is currently playing
				if state == states.PLAYING then
					-- Give boss instant kill reward if survivor dies
					if wasSurvivor then
						local bossPlayer = Teams.getBossPlayer()
						if bossPlayer then
							Inventory.addCoins(bossPlayer, 15)
							Inventory.savePlayerData(bossPlayer)
						end
					end
					-- Check if entire team is eliminated
					local bossTeamAlive = false
					local survivorTeamAlive = false
					
					for _, player in pairs(Players:GetPlayers()) do
						if player and player.Character and player.Character:FindFirstChild("Humanoid") then
							if player.Team.Name == TeamTypes.BOSS then
								bossTeamAlive = true
							elseif player.Team.Name == TeamTypes.SURVIVOR then
								survivorTeamAlive = true
							end
						end
					end
					
					-- End game if either team is completely eliminated
					if not bossTeamAlive then
						-- Boss team eliminated - survivors win
						local allPlayers = Players:GetPlayers()
						
						for _, player in pairs(allPlayers) do
							if player.Team.Name == TeamTypes.SURVIVOR then
								OutcomeRemoteEvent:FireClient(player, "Victory", 5)
								-- Survivors win: 150 coins
								Inventory.addCoins(player, 150)
								Inventory.savePlayerData(player)
							elseif player.Team.Name == TeamTypes.BOSS then
								OutcomeRemoteEvent:FireClient(player, "Defeat", 5)
								-- Boss loss: 75 coins
								Inventory.addCoins(player, 75)
								Inventory.savePlayerData(player)
							end
						end
					elseif not survivorTeamAlive then
						-- Survivors eliminated - boss wins
						local allPlayers = Players:GetPlayers()
						
						for _, player in pairs(allPlayers) do
							if player.Team.Name == TeamTypes.BOSS then
								OutcomeRemoteEvent:FireClient(player, "Victory", 5)
								-- Boss win: 100 base coins (per-kill bonuses already given)
								Inventory.addCoins(player, 100)
								Inventory.savePlayerData(player)
							elseif player.Team.Name == TeamTypes.SURVIVOR then
								OutcomeRemoteEvent:FireClient(player, "Defeat", 5)
								-- Survivors loss: 50 coins
								Inventory.addCoins(player, 50)
								Inventory.savePlayerData(player)
							end
						end
					end
					task.wait(5)
					endGame()
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		-- Only check team elimination if game is currently playing
		if state == states.PLAYING then
			-- Check if entire team is eliminated
			local bossTeamAlive = false
			local survivorTeamAlive = false
			
			for _, arenaPlayer in pairs(Players:GetPlayers()) do
				if player and player.Character and player.Character:FindFirstChild("Humanoid") then
					if player.Team.Name == TeamTypes.BOSS then
						bossTeamAlive = true
					elseif player.Team.Name == TeamTypes.SURVIVOR then
						survivorTeamAlive = true
					end
				end
			end
			
			-- End game if either team is completely eliminated
			if not bossTeamAlive then
				-- Boss team eliminated - survivors win
				local allPlayers = Players:GetPlayers()
				
				for _, player in pairs(allPlayers) do
					if player.Team.Name == TeamTypes.SURVIVOR then
						OutcomeRemoteEvent:FireClient(player, "Victory", 5, 5)
						-- Survivors win: 150 coins
						Inventory.addCoins(player, 150)
						Inventory.savePlayerData(player)
					elseif player.Team.Name == TeamTypes.BOSS then
						OutcomeRemoteEvent:FireClient(player, "Defeat", 5, 5)
						-- Boss loss: 75 coins
						Inventory.addCoins(player, 75)
						Inventory.savePlayerData(player)
					end
				end
			elseif not survivorTeamAlive then
				-- Survivors eliminated - boss wins
				local allPlayers = Players:GetPlayers()
				
				for _, player in pairs(allPlayers) do
					if player.Team.Name == TeamTypes.BOSS then
						OutcomeRemoteEvent:FireClient(player, "Victory", 5)
						-- Boss win: 100 base coins (per-kill bonuses already given)
						Inventory.addCoins(player, 100)
						Inventory.savePlayerData(player)
					elseif player.Team.Name == TeamTypes.SURVIVOR then
						OutcomeRemoteEvent:FireClient(player, "Defeat", 5)
						-- Survivors loss: 50 coins
						Inventory.addCoins(player, 50)
						Inventory.savePlayerData(player)
					end
				end
			end
			task.wait(5)
			endGame()
		end
	end)
end

return Game
