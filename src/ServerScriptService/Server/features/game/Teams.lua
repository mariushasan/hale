local Teams = {}

local bossTeam
local otherTeam
local waitingTeam

function Teams.assignTeams(players)
	local userIds = {}
	for userId, player in pairs(players) do
		table.insert(userIds, userId)
		player.Team = otherTeam
	end

	-- Check if we have any players before assigning boss
	if #userIds == 0 then
		warn("No players to assign teams to")
		return nil
	end

	local bossPlayer = players[userIds[math.random(#userIds)]]
	bossPlayer.Team = bossTeam

	return bossPlayer
end

function Teams.assignWaitingTeams(players)
	for userId, player in pairs(players) do
		player.Team = waitingTeam
	end
end

function Teams.getBossPlayer()
	local bossPlayers = bossTeam:GetPlayers()
	if #bossPlayers > 0 then
		return bossPlayers[1]
	end
	return nil
end

function Teams.initialize()
	local Teams = game:GetService("Teams")
	
	if not Teams:FindFirstChild("Boss") then
		bossTeam = Instance.new("Team")
		bossTeam.TeamColor = BrickColor.new("Bright red")
		bossTeam.AutoAssignable = false
		bossTeam.Name = "Boss"
		bossTeam.Parent = Teams
	end

	if not Teams:FindFirstChild("Other") then
		otherTeam = Instance.new("Team")
		otherTeam.TeamColor = BrickColor.new("Bright blue")
		otherTeam.AutoAssignable = false
		otherTeam.Name = "Other"
		otherTeam.Parent = Teams
	end

	if not Teams:FindFirstChild("Waiting") then
		waitingTeam = Instance.new("Team")
		waitingTeam.TeamColor = BrickColor.new("Grey")
		waitingTeam.AutoAssignable = true
		waitingTeam.Name = "Waiting"
		waitingTeam.Parent = Teams
	end
end

return Teams
