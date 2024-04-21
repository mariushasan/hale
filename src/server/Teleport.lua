local Teleport = {}

function Teleport:new(platform: Part, destination: Part)
    local teleport = {}
    setmetatable(teleport, self)
    self.__index = self

    teleport.destination = destination
    teleport.platform = platform

    return teleport
end

type PlayerTable = {[number]: Player}
function Teleport:teleportPlayers(players: PlayerTable)
    local halfSize = self.destination.Size * 0.45 -- little less than half the size to avoid walls
    for _, player in pairs(players) do
        if player then
            local character = player.Character
            local humanoid = character:FindFirstChildOfClass("Humanoid")

            if humanoid then
                -- Random offsets within the bounds of the destination part to avoid overlapping
                local randomX = math.random(-halfSize.X, halfSize.X)
                local randomZ = math.random(-halfSize.Z, halfSize.Z)

                -- Calculate the random end position within the destination part - slightly above the part
                local endPosition = self.destination.Position + Vector3.new(randomX, 10, randomZ)
                character:PivotTo(CFrame.new(endPosition))
            end
        end
    end
end


return Teleport