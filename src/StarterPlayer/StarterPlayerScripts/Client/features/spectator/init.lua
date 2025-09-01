local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Spectator = {}

-- Spectator state
local isSpectating = false
local spectatingPlayers = {}
local currentSpectatedIndex = 1
local spectatorConnection = nil
local cameraFollowConnection = nil
local firstSpawn = true

-- Get spectator status from server
local spectatorStatusEvent = events:WaitForChild("SpectatorStatusEvent")

-- Function to get all alive players to spectate
local function getAlivePlayersToSpectate()
    local alivePlayers = {}
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Team ~= "Waiting" and otherPlayer.Character and otherPlayer.Character:FindFirstChild("Humanoid") then
            if otherPlayer.Character.Humanoid.Health > 0 then
                table.insert(alivePlayers, otherPlayer)
            end
        end
    end
    
    return alivePlayers
end

-- Function to update camera position to follow target player
local function updateCameraPosition()
    if not isSpectating then
        return
    end
    
    -- If no players to spectate, set fixed camera position
    if #spectatingPlayers == 0 or not spectatingPlayers[currentSpectatedIndex] then
        local cameraPosition = Vector3.new(0, 100, 0)
        local lookAtPosition = Vector3.new(0, 0, 0)
        local cameraCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
        
        camera.CFrame = cameraCFrame
        return
    end
    
    local targetPlayer = spectatingPlayers[currentSpectatedIndex]
    if not targetPlayer or not targetPlayer.Character or not targetPlayer.Character:FindFirstChild("Head") then
        return
    end
    
    local targetHead = targetPlayer.Character.Head
    local targetPosition = targetHead.Position
    
    -- Set camera position behind and above the target player
    local offset = Vector3.new(0, 5, 10) -- Behind and above
    local cameraPosition = targetPosition + offset
    
    -- Look at the target player
    local lookAt = targetPosition
    local cameraCFrame = CFrame.lookAt(cameraPosition, lookAt)
    
    camera.CFrame = cameraCFrame
end

-- Function to switch to next player
local function switchToNextPlayer()
    spectatingPlayers = getAlivePlayersToSpectate()

    print("spectatingPlayers", spectatingPlayers)

    currentSpectatedIndex = currentSpectatedIndex + 1

    print("currentSpectatedIndex", currentSpectatedIndex)

    if currentSpectatedIndex > #spectatingPlayers then
        currentSpectatedIndex = 1
    end
    
    local targetPlayer = spectatingPlayers[currentSpectatedIndex]

    print("targetPlayer", targetPlayer)

    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
        updateCameraPosition()
    else
        print("targetPlayer not found, setting camera to down from above")
        print("Camera type before setting:", camera.CameraType)
        print("Player camera mode before setting:", player.CameraMode)
        
        -- Force camera to scriptable mode and set position
        camera.CameraType = Enum.CameraType.Scriptable
        player.CameraMode = Enum.CameraMode.Classic
        
        print("Camera type after setting:", camera.CameraType)
        print("Player camera mode after setting:", player.CameraMode)
        
        -- Set camera to a high position looking down
        local cameraPosition = Vector3.new(0, 100, 0)
        local lookAtPosition = Vector3.new(0, 0, 0)
        local cameraCFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
        
        camera.CFrame = cameraCFrame
        print("Camera CFrame set to:", camera.CFrame)
    end
end

-- Function to start spectating
function Spectator.startSpectating()
    print("startSpectating")
    if isSpectating then return end

    print("Starting spectating...")
    
    spectatingPlayers = getAlivePlayersToSpectate()

    -- Set up scriptable camera
    camera.CameraType = Enum.CameraType.Scriptable
    player.CameraMode = Enum.CameraMode.Classic
    player.CameraMaxZoomDistance = 10
    player.CameraMinZoomDistance = 10
    
    isSpectating = true
    
    -- Get initial list of players to spectate
    currentSpectatedIndex = 0
    
    -- Switch to first player (or set fixed camera if no players)
    switchToNextPlayer()
    
    -- Start camera following loop
    cameraFollowConnection = RunService.RenderStepped:Connect(function()
        if isSpectating then
            updateCameraPosition()
        end
    end)
    
    -- Set up input handling for switching players
    spectatorConnection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        -- Left click or touch to switch players
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            switchToNextPlayer()
        end
    end)
    
    -- Update spectated player list periodically and handle disconnections
    local updateConnection
    updateConnection = RunService.Heartbeat:Connect(function()
        if not isSpectating then
            updateConnection:Disconnect()
            return
        end
        
        -- Check if current spectated player is still valid
        if #spectatingPlayers > 0 and spectatingPlayers[currentSpectatedIndex] then
            local currentTarget = spectatingPlayers[currentSpectatedIndex]
            if not currentTarget.Character or not currentTarget.Character:FindFirstChild("Humanoid") or currentTarget.Character.Humanoid.Health <= 0 then
                -- Current target died or left, switch to next
                switchToNextPlayer()
            end
        end
    end)
end

-- Function to stop spectating
function Spectator.stopSpectating()
    print("stopSpectating")
    if not isSpectating then return end

    print("camera", camera.CameraType)
    print("camera", camera.CameraSubject)

    local character = player.Character

    print("character", character)

    if not character then
        return
    end

    local humanoid = character:FindFirstChild("Humanoid")

    print("humanoid", humanoid)

    if not humanoid then
        return
    end

    camera.CameraSubject = humanoid
    camera.CameraType = Enum.CameraType.Custom

    player.CameraMode = Enum.CameraMode.LockFirstPerson
    player.CameraMaxZoomDistance = 1
    player.CameraMinZoomDistance = 1
    
    isSpectating = false
    
    -- Disconnect camera following connection
    if cameraFollowConnection then
        cameraFollowConnection:Disconnect()
        cameraFollowConnection = nil
    end
    
    -- Disconnect input connection
    if spectatorConnection then
        spectatorConnection:Disconnect()
        spectatorConnection = nil
    end
end

-- Handle spectator status from server
function Spectator.init()
    player.CharacterAdded:Connect(function()
        if firstSpawn then
            firstSpawn = false
            Spectator.startSpectating()
        end

        print("player.Character", player.Character)

        wait(1)

        local humanoid = player.Character:FindFirstChild("Humanoid")

        if humanoid then
            humanoid.Died:Connect(function()
                print("humanoid died")
                Spectator.startSpectating()
            end)
        end
    end)

    spectatorStatusEvent.OnClientEvent:Connect(function(shouldSpectate)
        if shouldSpectate then
            Spectator.startSpectating()
        else
            Spectator.stopSpectating()
        end
    end)
end

return Spectator 