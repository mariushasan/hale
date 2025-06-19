local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local Shotgun = {}

function Shotgun.generateBullets(startPosition, direction)
    local bullets = {}
    for i = 1, ShotgunConstants.BULLETS_PER_SHOT do
        local bullet = {}
        local spreadX = (math.random() - 0.5) * 2 * ShotgunConstants.SPREAD_ANGLE
        local spreadY = (math.random() - 0.5) * 2 * ShotgunConstants.SPREAD_ANGLE
        local spreadDirection = CFrame.fromOrientation(spreadX, spreadY, 0) * direction.Unit
        bullet.direction = spreadDirection
        bullet.startPosition = startPosition
        table.insert(bullets, bullet)
    end
    return bullets
end
return Shotgun
