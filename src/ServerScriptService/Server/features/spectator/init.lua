local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local Players = game:GetService("Players")

local spectatorStatusEvent = events:WaitForChild("SpectatorStatusEvent")

local Spectator = {}

function Spectator.updateSpectatorStatus()
	for _, player in pairs(Players:GetPlayers()) do
		local isSpectator = false
		
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			if player.Character.Humanoid.Health <= 0 then
				isSpectator = true
			end
		end
		
		spectatorStatusEvent:FireClient(player, isSpectator)
	end
end

return Spectator