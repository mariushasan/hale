local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local Spectator = {}

-- Spectator state
local isSpectating = false
local spectatingPlayers = {}
local currentSpectatedIndex = 1
local spectatorConnection = nil

-- Get spectator status from server
local spectatorStatusEvent = ReplicatedStorage:WaitForChild("SpectatorStatusEvent")

-- Function to get all alive players to spectate
local function getAlivePlayersToSpectate()
    local alivePlayers = {}
    
    for _, otherPlayer in pairs(Players:GetPlayers()) do
        if otherPlayer ~= player and otherPlayer.Character and otherPlayer.Character:FindFirstChild("Humanoid") then
            if otherPlayer.Character.Humanoid.Health > 0 then
                table.insert(alivePlayers, otherPlayer)
            end
        end
    end
    
    return alivePlayers
end

-- Function to switch to next player
local function switchToNextPlayer()
    spectatingPlayers = getAlivePlayersToSpectate()
    
    if #spectatingPlayers == 0 then
        -- No one to spectate, set camera to fixed position
        camera.CameraType = Enum.CameraType.Fixed
        camera.CFrame = CFrame.new(0, 50, 0, 0, -1, 0, 0, 0, 1, 1, 0, 0) -- Looking down from above
        return
    end
    
    currentSpectatedIndex = currentSpectatedIndex + 1
    if currentSpectatedIndex > #spectatingPlayers then
        currentSpectatedIndex = 1
    end
    
    local targetPlayer = spectatingPlayers[currentSpectatedIndex]
    if targetPlayer and targetPlayer.Character and targetPlayer.Character:FindFirstChild("Head") then
        camera.CameraSubject = targetPlayer.Character.Head
        camera.CameraType = Enum.CameraType.Attach
    end
end

-- Function to start spectating
function Spectator.startSpectating()
    if isSpectating then return end
    
    isSpectating = true
    
    -- Get initial list of players to spectate
    spectatingPlayers = getAlivePlayersToSpectate()
    currentSpectatedIndex = 0
    
    -- Switch to first player
    switchToNextPlayer()
    
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
    
    print("Spectator mode started")
end

-- Function to stop spectating
function Spectator.stopSpectating()
    if not isSpectating then return end
    
    isSpectating = false
    
    -- Disconnect input connection
    if spectatorConnection then
        spectatorConnection:Disconnect()
        spectatorConnection = nil
    end
    
    -- Reset camera to player
    if player.Character and player.Character:FindFirstChild("Head") then
        camera.CameraSubject = player.Character.Head
        camera.CameraType = Enum.CameraType.Custom
    end
    
    print("Spectator mode stopped")
end

-- Handle spectator status from server
function Spectator.init()
    spectatorStatusEvent.OnClientEvent:Connect(function(shouldSpectate)
        if shouldSpectate then
            print("Spectator mode started")
            Spectator.startSpectating()
        else
            print("Spectator mode stopped")
            Spectator.stopSpectating()
        end
    end)
end

return Spectator 