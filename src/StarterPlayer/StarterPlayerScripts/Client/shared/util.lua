-- Function to hide chat and leaderboard
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Players = game:GetService("Players")

local originalChatEnabled = true
local originalLeaderboardEnabled = true

local Util = {}

function Util.hideDefaultGuis()
    local player = Players.LocalPlayer
    player.CameraMode = Enum.CameraMode.Classic
    
    -- Store original states
    originalChatEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.Chat)
    originalLeaderboardEnabled = StarterGui:GetCoreGuiEnabled(Enum.CoreGuiType.PlayerList)
    
    -- Zoom camera away from player
    player.CameraMaxZoomDistance = 1
    player.CameraMinZoomDistance = 1
    
    -- Hide chat and leaderboard
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    
    -- Ensure mouse cursor is visible
    UserInputService.MouseIconEnabled = true
end

function Util.showDefaultGuis()
    local player = Players.LocalPlayer
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, originalChatEnabled)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, originalLeaderboardEnabled)
    
    -- Restore mouse cursor (keep it enabled for normal gameplay)
    UserInputService.MouseIconEnabled = false
end

return Util