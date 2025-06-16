local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TimeSync = {}

-- Add debugging to track module instances
local instanceId = math.random(1000, 9999)

-- Private variables
local serverTimeOffset = 0  -- Difference between server time and client time (in milliseconds)
local replicationDelayOffset = 0 -- Additional offset for replication delay
local lastSyncTime = 0      -- When we last synced with server
local estimatedOneWayRTT = 0 -- Estimated one-way RTT (in milliseconds)
local isInitialized = false
local SYNC_INTERVAL = 30    -- Sync every 30 seconds
local timeSyncEvent = nil
local testPartName = nil
local testPart = nil
local replicationMeasurementInProgress = false
local replicationTestStartTime = nil

-- Initialize the time sync system
function TimeSync.init()    
    if RunService:IsServer() then
        -- On server, we don't need to sync - we ARE the server
        isInitialized = true
        return
    end
    
    -- Client-side initialization
    if isInitialized then
        warn("TimeSync already initialized - Instance ID:", instanceId)
        return
    end
    
    -- Get the TimeSyncEvent
    timeSyncEvent = ReplicatedStorage:WaitForChild("TimeSyncEvent")
    
    -- Set up response handler
    timeSyncEvent.OnClientEvent:Connect(function(responseType, response)
        if responseType == "sync_response" then
            TimeSync._handleSyncResponse(response)
        elseif responseType == "test_part_created" then
            TimeSync._handleTestPartCreated(response)
        elseif responseType == "part_moved" then
            TimeSync._handlePartMoved(response)
        end
    end)
    
    isInitialized = true    
    -- Initial sync
    TimeSync._syncWithServer()
    
    -- Periodic sync every 30 seconds
    spawn(function()
        while true do
            wait(SYNC_INTERVAL)
            TimeSync._syncWithServer()
        end
    end)
end

-- Private function to sync with server (client-only)
function TimeSync._syncWithServer()    
    if not timeSyncEvent then return end

    wait(2)
    
    local success, result = pcall(function()
        -- Record when we send the request
        local clientSendTime = DateTime.now().UnixTimestampMillis
        
        -- Send sync request to server
        timeSyncEvent:FireServer("sync", clientSendTime)
        
        return true
    end)
    
    if not success then
        warn("TimeSync: Failed to sync with server:", result)
    end
end

-- Handle sync response from server
function TimeSync._handleSyncResponse(response)
    local clientReceiveTime = DateTime.now().UnixTimestampMillis
    local clientSendTime = response.clientSendTime
    local serverTime = response.serverTime
    
    -- Calculate RTT (Round Trip Time)
    local RTT = clientReceiveTime - clientSendTime
    
    -- Estimate one-way latency
    estimatedOneWayRTT = RTT / 2
    
    -- Adjust server time by adding estimated latency
    local adjustedServerTime = serverTime + estimatedOneWayRTT
    
    -- Calculate offset: adjusted_server_time - current_client_time
    serverTimeOffset = adjustedServerTime - clientReceiveTime
    lastSyncTime = clientReceiveTime -- Keep in milliseconds for precision
        
    -- After clock sync, start replication delay measurement
    TimeSync._startReplicationDelayMeasurement()
end

-- Start replication delay measurement
function TimeSync._startReplicationDelayMeasurement()
    if replicationMeasurementInProgress then return end
    replicationMeasurementInProgress = true
        
    -- Request server to create test part
    timeSyncEvent:FireServer("create_test_part", {})
end

-- Handle test part creation
function TimeSync._handleTestPartCreated(response)
    testPartName = response.partName
    
    -- Wait for the part to appear in workspace
    spawn(function()
        local attempts = 0
        while attempts < 50 do -- Wait up to 5 seconds
            testPart = workspace:FindFirstChild(testPartName)
            if testPart then
                TimeSync._setupReplicationMeasurement()
                break
            end
            wait(0.1)
            attempts = attempts + 1
        end
        
        if not testPart then
            warn("TimeSync: Test part not found after 5 seconds")
            replicationMeasurementInProgress = false
        end
    end)
end

-- Setup replication delay measurement
function TimeSync._setupReplicationMeasurement()
    -- Store initial position
    local initialPosition = testPart.Position
    
    -- Set up position change listener
    local connection
    connection = testPart:GetPropertyChangedSignal("Position"):Connect(function()
        local clientReceiveTime = DateTime.now().UnixTimestampMillis
        
        -- Disconnect after first measurement
        connection:Disconnect()
        
        -- Calculate replication delay (this will be set when we request the move)
        if replicationTestStartTime then
            local replicationDelay = clientReceiveTime - replicationTestStartTime
            
            -- The replication delay offset is the additional delay beyond network RTT
            replicationDelayOffset = replicationDelay - estimatedOneWayRTT
            
            replicationMeasurementInProgress = false
            
            -- Clean up test part
            spawn(function()
                wait(1)
                if testPart and testPart.Parent then
                    testPart:Destroy()
                end
            end)
        end
    end)
    
    -- Request server to move the part
    local moveRequestTime = DateTime.now().UnixTimestampMillis
    replicationTestStartTime = moveRequestTime
    
    timeSyncEvent:FireServer("move_test_part", {
        serverMoveTime = moveRequestTime
    })
end

-- Handle part moved confirmation (optional, for additional verification)
function TimeSync._handlePartMoved(response)
    -- This is just for verification - the actual measurement happens in the position change listener
end

-- Get the current server time in milliseconds (high precision)
function TimeSync.getServerTimeMillis()    
    if RunService:IsServer() then
        -- On server, return the authoritative server time directly
        return DateTime.now().UnixTimestampMillis
    end
    
    -- Client-side synchronized time
    if not isInitialized then
        warn("TimeSync not initialized! Call TimeSync.init() first - Instance ID:", instanceId)
        return DateTime.now().UnixTimestampMillis -- Fallback to local time
    end
    print("TimeSync")
    print(serverTimeOffset, replicationDelayOffset)
    -- Calculate current server time using both offsets
    local currentClientTime = DateTime.now().UnixTimestampMillis
    local serverTime = currentClientTime + serverTimeOffset - replicationDelayOffset
    return serverTime
end

-- Get the current server time in seconds (for compatibility)
function TimeSync.getServerTime()    
    return TimeSync.getServerTimeMillis() / 1000
end

-- Get time since last sync (for debugging)
function TimeSync.getTimeSinceLastSync()
    if RunService:IsServer() then
        return 0 -- Server is always "synced"
    end
    
    if not isInitialized then
        return -1
    end
    
    return (DateTime.now().UnixTimestampMillis - lastSyncTime) / 1000 -- Convert to seconds for readability
end

-- Check if we're properly synced
function TimeSync.isSynced()
    if RunService:IsServer() then
        return true -- Server is always synced
    end
    
    return isInitialized and serverTimeOffset ~= 0
end

-- Get sync status info (for debugging)
function TimeSync.getDebugInfo()
    return {
        isServer = RunService:IsServer(),
        initialized = isInitialized,
        serverTimeOffset = serverTimeOffset,
        replicationDelayOffset = replicationDelayOffset,
        totalOffset = serverTimeOffset + replicationDelayOffset,
        lastSyncTime = lastSyncTime,
        timeSinceLastSync = TimeSync.getTimeSinceLastSync(),
        currentServerTime = TimeSync.getServerTime(),
        currentServerTimeMillis = TimeSync.getServerTimeMillis()
    }
end

function TimeSync.debug()
    local debugInfo = TimeSync.getDebugInfo()
    print("=== TimeSync Debug Info ===")
    print("Is Server:", debugInfo.isServer)
    print("Initialized:", debugInfo.initialized)
    print("Server Time Offset (ms):", debugInfo.serverTimeOffset)
    print("Replication Delay Offset (ms):", debugInfo.replicationDelayOffset)
    print("Total Offset (ms):", debugInfo.totalOffset)
    print("Time Since Last Sync:", debugInfo.timeSinceLastSync)
    print("Current Server Time (ms):", debugInfo.currentServerTimeMillis)
    print("========================")
end

return TimeSync 