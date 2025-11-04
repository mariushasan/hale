local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ENABLE_ANALYTICS = true

local analyticsQueue = {}
local MAX_QUEUE_SIZE = 20
local BATCH_DELAY = 3

local function processAnalyticsQueue()
    if #analyticsQueue > 0 then
        local remote = ReplicatedStorage:FindFirstChild("ClientAnalyticsRemote")
        if remote then
            remote:FireServer(analyticsQueue)
        end
        analyticsQueue = {}
    end
end

spawn(function()
    while true do
        wait(BATCH_DELAY)
        processAnalyticsQueue()
    end
end)

local function sendEvent(playerUserId, eventName, parameters)
    if not ENABLE_ANALYTICS then return end
    
    local eventData = {
        player_id = tostring(playerUserId),
        event_name = eventName,
        parameters = parameters or {},
        timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        auto_captured = false
    }
    
    table.insert(analyticsQueue, eventData)
    
    if #analyticsQueue >= MAX_QUEUE_SIZE then
        processAnalyticsQueue()
    end
end

_G.Analytics = {
    sendEvent = sendEvent,
}