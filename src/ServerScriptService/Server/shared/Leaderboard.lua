local Leaderboard = {}

-- Creating a new leaderboard
local function setupLeaderboard(player)
  local leaderstats = Instance.new("Folder")
  -- 'leaderstats' is a reserved name Roblox recognizes for creating a leaderboard
  leaderstats.Name = "leaderstats"
  leaderstats.Parent = player
  return leaderstats
end

-- Creating a new leaderboard stat value
local function setupStat(leaderstats, statName)
  local stat = Instance.new("IntValue")
  stat.Name = statName
  stat.Value = 0
  stat.Parent = leaderstats
  return stat
end

-- Updating a player's stat value
function Leaderboard.setStat(player, statName, value)
  local leaderstats = player:FindFirstChild("leaderstats")
  if not leaderstats then
    leaderstats = setupLeaderboard(player)
  end

  local stat = leaderstats:FindFirstChild(statName)
  if not stat then
    stat = setupStat(leaderstats, statName)
  end

  stat.Value = value
end

function Leaderboard.getStat(player, statName)
  local leaderstats = player:FindFirstChild("leaderstats")
  if not leaderstats then
    return nil
  end

  local stat = leaderstats:FindFirstChild(statName)
  if not stat then
    return nil
  end

  return stat.Value
end

function Leaderboard.addToStat(player, statName, value)
  local currentValue = Leaderboard.getStat(player, statName)
  if not currentValue then
    Leaderboard.setStat(player, statName, value)
  end

  Leaderboard.setStat(player, statName, currentValue + value)
end

return Leaderboard