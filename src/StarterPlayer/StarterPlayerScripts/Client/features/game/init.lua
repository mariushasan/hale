local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")
local GameUI = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game.ui.GameUI)
local Players = game:GetService("Players")
local Game = {}

function Game.init()
    TimerRemoteEvent.OnClientEvent:Connect(function(timeSeconds)
        GameUI.setTimer(timeSeconds)
    end)
	
    OutcomeRemoteEvent.OnClientEvent:Connect(function(outcome)
        GameUI.showGameEnd(outcome)
    end)

    local player = Players.LocalPlayer

    player.CharacterAdded:Connect(function(character)
        GameUI.init()
    end)
end

return Game
