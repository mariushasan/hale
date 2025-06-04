local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")
local GameUI = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game.ui.GameUI)

local Game = {}

function Game.initialize()
    TimerRemoteEvent.OnClientEvent:Connect(function(timeSeconds)
        GameUI.setTimer(timeSeconds)
    end)
	
    OutcomeRemoteEvent.OnClientEvent:Connect(function(outcome)
        GameUI.showGameEnd(outcome)
    end)
end

return Game
