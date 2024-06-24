local TeamAssignment = {}

local Teams = game:GetService("Teams")

-- Create teams if they do not exist
if not Teams:FindFirstChild("Boss") then
	local bossTeam = Instance.new("Team")
	bossTeam.TeamColor = BrickColor.new("Bright red")
	bossTeam.AutoAssignable = false
	bossTeam.Name = "Boss"
	bossTeam.Parent = Teams
end

if not Teams:FindFirstChild("Other") then
	local otherTeam = Instance.new("Team")
	otherTeam.TeamColor = BrickColor.new("Bright blue")
	otherTeam.AutoAssignable = false
	otherTeam.Name = "Other"
	otherTeam.Parent = Teams
end

if not Teams:FindFirstChild("Waiting") then
	local waitingTeam = Instance.new("Team")
	waitingTeam.TeamColor = BrickColor.new("Grey")
	waitingTeam.AutoAssignable = true
	waitingTeam.Name = "Waiting"
	waitingTeam.Parent = Teams
end

local bossTeam = Teams:FindFirstChild("Boss")
local otherTeam = Teams:FindFirstChild("Other")
local waitingTeam = Teams:FindFirstChild("Waiting")

function TeamAssignment.assignTeams(players)
	local userIds = {}
	for userId, player in pairs(players) do
		table.insert(userIds, userId)
		player.Team = otherTeam
	end

	local bossPlayer = players[userIds[math.random(#userIds)]]
	bossPlayer.Team = bossTeam

	return bossPlayer
end

function TeamAssignment.assignWaitingTeams(players)
	for userId, player in pairs(players) do
		player.Team = waitingTeam
	end
end

function TeamAssignment.getBossPlayer()
	local bossPlayers = bossTeam:GetPlayers()
	if #bossPlayers > 0 then
		return bossPlayers[1]
	end
	return nil
end

return TeamAssignment
