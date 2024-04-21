local Shoot = require(game.StarterPlayer.StarterPlayerScripts.Client.PlayerActions.Shoot)
local GameUI = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Game)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TimerRemoteEvent = ReplicatedStorage:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = ReplicatedStorage:WaitForChild("OutcomeRemoteEvent")
local ClassUI = require(game.StarterPlayer.StarterPlayerScripts.Client.UI.Class)

TimerRemoteEvent.OnClientEvent:Connect(function(timeSeconds)
    GameUI.setTimer(timeSeconds)
end)

OutcomeRemoteEvent.OnClientEvent:Connect(function(outcome)
    GameUI.showGameEnd(outcome)
end)

Shoot.initialize()
ClassUI.initialize()