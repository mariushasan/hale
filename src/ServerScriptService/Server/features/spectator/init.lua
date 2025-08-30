local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")

local spectatorStatusEvent = events:WaitForChild("SpectatorStatusEvent")

local Spectator = {}

function Spectator.updateSpectatorStatus(player, isSpectator)
	spectatorStatusEvent:FireClient(player, isSpectator)
end

return Spectator