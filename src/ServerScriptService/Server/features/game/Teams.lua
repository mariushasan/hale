local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeamTypes = require(ReplicatedStorage.features.teams)

local Teams = {}

Teams.bossTeam = nil
Teams.survivorTeam = nil
Teams.waitingTeam = nil

function Teams.assignTeams(players)
	local userIds = {}
	for userId, player in pairs(players) do
		table.insert(userIds, userId)
		player.Team = Teams.survivorTeam
	end

	-- Check if we have any players before assigning boss
	if #userIds == 0 then
		warn("No players to assign teams to")
		return nil
	end

	local bossPlayer = players[userIds[math.random(#userIds)]]
	bossPlayer.Team = Teams.bossTeam

	print("Boss player:", bossPlayer.Name)

	return bossPlayer
end

function Teams.assignWaitingTeams(players)
	for userId, player in pairs(players) do
		player.Team = Teams.waitingTeam
	end
end

function Teams.assignWaitingTeam(player)
	player.Team = Teams.waitingTeam
end

function Teams.getBossPlayer()
	local bossPlayers = Teams.bossTeam:GetPlayers()
	if #bossPlayers > 0 then
		return bossPlayers[1]
	end
	return nil
end

function Teams.init()
	local TeamsService = game:GetService("Teams")
	
	if not TeamsService:FindFirstChild(TeamTypes.BOSS) then
		Teams.bossTeam = Instance.new("Team")
		Teams.bossTeam.TeamColor = BrickColor.new("Bright red")
		Teams.bossTeam.AutoAssignable = false
		Teams.bossTeam.Name = TeamTypes.BOSS
		Teams.bossTeam.Parent = TeamsService
	else
		Teams.bossTeam = TeamsService:FindFirstChild(TeamTypes.BOSS)
	end

	if not TeamsService:FindFirstChild(TeamTypes.SURVIVOR) then
		Teams.survivorTeam = Instance.new("Team")
		Teams.survivorTeam.TeamColor = BrickColor.new("Bright blue")
		Teams.survivorTeam.AutoAssignable = false
		Teams.survivorTeam.Name = TeamTypes.SURVIVOR
		Teams.survivorTeam.Parent = TeamsService
	else
		Teams.survivorTeam = TeamsService:FindFirstChild(TeamTypes.SURVIVOR)
	end

	if not TeamsService:FindFirstChild(TeamTypes.WAITING) then
		Teams.waitingTeam = Instance.new("Team")
		Teams.waitingTeam.TeamColor = BrickColor.new("Grey")
		Teams.waitingTeam.AutoAssignable = true
		Teams.waitingTeam.Name = TeamTypes.WAITING
		Teams.waitingTeam.Parent = TeamsService
	else
		Teams.waitingTeam = TeamsService:FindFirstChild(TeamTypes.WAITING)
	end
end

return Teams
