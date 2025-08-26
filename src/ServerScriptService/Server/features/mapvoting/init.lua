local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local events = ReplicatedStorage:WaitForChild("events")

-- Import map constants
local MapConstants = require(ReplicatedStorage.features.maps)

-- Remote Events
local MapVotingEvent = events:WaitForChild("MapVotingEvent")
local MapVoteUpdateEvent = events:WaitForChild("MapVoteUpdateEvent")
local MapVotingUIReadyEvent = events:WaitForChild("MapVotingUIReadyEvent")

local MapVoting = {}

-- Voting state
local votingActive = false
local playerVotes = {} -- [player] = mapId
local mapVotes = {} -- [mapId] = count
local votingEndTime = 0
local currentVotingTime = 0

-- Initialize vote counts
local function initializeVoteCounts()
    mapVotes = {}
    for mapId, _ in pairs(MapConstants) do
        mapVotes[mapId] = 0
    end
end

-- Update all clients with current vote counts
local function broadcastVoteUpdate()
    MapVoteUpdateEvent:FireAllClients(mapVotes)
end

-- Handle player vote
local function handlePlayerVote(player, mapId)
    if not votingActive then
        return
    end
    
    if not MapConstants[mapId] then
        warn("Invalid map ID:", mapId)
        return
    end
    
    -- Remove previous vote if exists
    if playerVotes[player] then
        local previousMapId = playerVotes[player]
        mapVotes[previousMapId] = math.max(0, mapVotes[previousMapId] - 1)
    end
    
    -- Add new vote
    playerVotes[player] = mapId
    mapVotes[mapId] = mapVotes[mapId] + 1
    
    print(player.Name .. " voted for " .. mapId)
    broadcastVoteUpdate()
end

-- Get winning map
local function getWinningMap()
    local maxVotes = 0
    local winningMaps = {}
    
    for mapId, votes in pairs(mapVotes) do
        if votes > maxVotes then
            maxVotes = votes
            winningMaps = {mapId}
        elseif votes == maxVotes then
            table.insert(winningMaps, mapId)
        end
    end
    
    -- If tie, pick random from tied maps
    if #winningMaps > 0 then
        return winningMaps[math.random(1, #winningMaps)]
    else
        -- Fallback to first map if no votes
        for mapId, _ in pairs(MapConstants) do
            return mapId
        end
    end
end

-- Start voting session
function MapVoting.startVoting(duration)
    duration = duration or 30 -- Default 30 seconds
    
    if votingActive then
        warn("Voting already active!")
        return
    end
    
    print("Starting map voting for " .. duration .. " seconds")
    
    playerVotes = {}
    initializeVoteCounts()
    votingEndTime = tick() + duration
    
    -- Notify all clients that voting has started
    currentVotingTime = duration

    task.spawn(function()
        while currentVotingTime < duration do
            task.wait(1)
            currentVotingTime = currentVotingTime - 1
        end
    end)
    
    votingActive = true
    MapVotingEvent:FireAllClients("start", duration)
    broadcastVoteUpdate()
    
    -- End voting after duration
    wait(duration)
    return MapVoting.endVoting()
end

-- End voting session
function MapVoting.endVoting()
    if not votingActive then
        return
    end
    
    votingActive = false
    local winningMap = getWinningMap()
    
    print("Voting ended. Winning map: " .. winningMap .. " with " .. mapVotes[winningMap] .. " votes")
    
    -- Notify all clients that voting has ended
    MapVotingEvent:FireAllClients("end", winningMap)
    
    return winningMap
end

-- Get current voting status
function MapVoting.isVotingActive()
    return votingActive
end

-- Get current vote counts
function MapVoting.getVoteCounts()
    return mapVotes
end

-- Load a map into the workspace
function MapVoting.loadMap(mapId)
    if not MapConstants[mapId] then
        warn("Invalid map ID:", mapId)
        return false
    end
    
    local mapData = MapConstants[mapId]
    local mapFileName = mapData.FILE_NAME
    
    print("Loading map:", mapData.DISPLAY_NAME, "(" .. mapFileName .. ")")
    
    -- Clear existing map if any
    local existingMap = workspace:FindFirstChild("CurrentMap")
    if existingMap then
        existingMap:Destroy()
        print("Cleared existing map")
    end
    
    -- Try to load the map from ServerStorage
    local mapFolder = ServerStorage:FindFirstChild("Maps")
    if not mapFolder then
        warn("Game folder not found in ServerStorage!")
        return false
    end
    
    -- Find the map model in ServerStorage/Game
    local mapModel = mapFolder:FindFirstChild(mapFileName)
    if not mapModel then
        warn("Map model not found:", mapFileName)
        return false
    end
    
    -- Clone the map model to workspace
    local loadedMap = mapModel:Clone()
    loadedMap.Name = "CurrentMap"
    loadedMap.Parent = workspace
    
    print("Map loaded successfully:", mapData.DISPLAY_NAME)
    return true
end

-- Initialize the system
function MapVoting.init()
    initializeVoteCounts()

    MapVotingUIReadyEvent.OnServerEvent:Connect(function(player)
        if votingActive then
            MapVotingEvent:FireClient(player, "start", currentVotingTime)
            MapVoteUpdateEvent:FireClient(player, mapVotes)
        end
    end)
    
    -- Handle player votes
    MapVotingEvent.OnServerEvent:Connect(function(player, action, data)
        if action == "vote" then
            handlePlayerVote(player, data)
        elseif action == "requestUpdate" then
            -- Send current state to requesting player
            MapVoteUpdateEvent:FireClient(player, mapVotes)
        end
    end)
    
    -- Clean up when player leaves
    Players.PlayerRemoving:Connect(function(player)
        if playerVotes[player] then
            local mapId = playerVotes[player]
            mapVotes[mapId] = math.max(0, mapVotes[mapId] - 1)
            playerVotes[player] = nil
            broadcastVoteUpdate()
        end
    end)
end

return MapVoting 