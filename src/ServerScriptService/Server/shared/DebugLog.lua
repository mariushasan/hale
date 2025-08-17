local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")

local debugLogEvent = events:FindFirstChild("DebugLogEvent")
if not debugLogEvent then
    debugLogEvent = Instance.new("RemoteEvent")
    debugLogEvent.Name = "DebugLogEvent"
    debugLogEvent.Parent = ReplicatedStorage
end

-- Debug logging function that sends to clients
local function debugLog(message, player)
    print(message) -- Still print to server console
    
    -- Send to specific player or all players
    if player then
        debugLogEvent:FireClient(player, message)
    else
        debugLogEvent:FireAllClients(message)
    end
end

return debugLog