local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local API_URL = "https://dataoverlord.com/api/events/batch_create/"
local API_KEY = "YOUR_API_KEY"
local ENABLE_ANALYTICS = true

local analyticsQueue = {}
local MAX_QUEUE_SIZE = 50
local BATCH_DELAY = 5

local livePlayersDelta = 0
local LIVE_PLAYERS_FLUSH_INTERVAL = 5

local function sendAnalyticsData(events)
    if not ENABLE_ANALYTICS or #events == 0 then
        return
    end
    
    pcall(function()
        HttpService:RequestAsync({
            Url = API_URL,
            Method = "POST",
            Headers = {
                ["Content-Type"] = "application/json",
                ["X-API-Key"] = API_KEY,
            },
            Body = HttpService:JSONEncode(events)
        })
    end)
end

local function processAnalyticsQueue()
    if #analyticsQueue > 0 then
        sendAnalyticsData(analyticsQueue)
        analyticsQueue = {}
    end
end

spawn(function()
    while true do
        wait(BATCH_DELAY)
        processAnalyticsQueue()
    end
end)

function flushLivePlayersDelta()
    if livePlayersDelta ~= 0 then
        local deltaToSend = livePlayersDelta
        livePlayersDelta = 0
        pcall(function()
            HttpService:RequestAsync({
                Url = string.gsub(API_URL, "/events/batch_create/", "/events/live_players_delta/"),
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["X-API-Key"] = API_KEY,
                },
                Body = HttpService:JSONEncode({ delta = deltaToSend })
            })
        end)
    end
end

spawn(function()
    while true do
        wait(LIVE_PLAYERS_FLUSH_INTERVAL)
        flushLivePlayersDelta()
    end
end)

local function addToAnalyticsQueue(eventData)
    if not ENABLE_ANALYTICS then return end
    
    table.insert(analyticsQueue, eventData)
    
    if #analyticsQueue >= MAX_QUEUE_SIZE then
        processAnalyticsQueue()
    end
end

local function sendEvent(playerUserId, eventName, parameters)
    if not ENABLE_ANALYTICS then return end
    
    local eventData = {
        player_id = tostring(playerUserId),
        event_name = eventName,
        parameters = parameters or {},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        auto_captured = false
    }
    
    addToAnalyticsQueue(eventData)
end

local function sendEventInternal(playerUserId, eventName, parameters)
    if not ENABLE_ANALYTICS then return end
    
    local eventData = {
        player_id = tostring(playerUserId),
        event_name = eventName,
        parameters = parameters or {},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        auto_captured = true
    }
    
    addToAnalyticsQueue(eventData)
end

local function onPlayerAdded(player)
    livePlayersDelta = livePlayersDelta + 1
    sendEventInternal(player.UserId, "player_joined", nil)
end

local function onPlayerRemoving(player)
    livePlayersDelta = livePlayersDelta - 1
    sendEventInternal(player.UserId, "player_left", nil)
    processAnalyticsQueue()
    flushLivePlayersDelta()
end

local ClientAnalyticsRemote = Instance.new("RemoteEvent")
ClientAnalyticsRemote.Name = "ClientAnalyticsRemote"
ClientAnalyticsRemote.Parent = ReplicatedStorage

ClientAnalyticsRemote.OnServerEvent:Connect(function(player, clientEvents)
    if not ENABLE_ANALYTICS or not clientEvents or #clientEvents == 0 then
        return
    end
    
    for _, eventData in ipairs(clientEvents) do
        addToAnalyticsQueue(eventData)
    end
end)

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

_G.Analytics = {
    sendEvent = sendEvent
}