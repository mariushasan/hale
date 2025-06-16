local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local BossAttackConstants = require(ReplicatedStorage.features.weapons.bossattack.constants)

local BossAttack = {}

-- Create explosion effect
local function createExplosionEffect(position)
    local effect = Instance.new("Explosion")
    effect.Position = position
    effect.BlastRadius = BossAttackConstants.EXPLOSION_BLAST_RADIUS
    effect.BlastPressure = BossAttackConstants.EXPLOSION_BLAST_PRESSURE
    effect.Visible = true
    effect.Parent = workspace
end

function BossAttack.equip()
    -- Boss attack doesn't need visual weapon model
    print("Boss attack equipped - ready for melee combat!")
end

function BossAttack.unequip()
    -- Nothing to cleanup for boss attack
    print("Boss attack unequipped")
end

function BossAttack.fire(startPosition, direction)
    -- Create immediate explosion effect at player position
    createExplosionEffect(startPosition)
    
    -- Add screen shake or other effects here if desired
    print("Boss attack fired!")
end

-- Boss attack is instantaneous, so no bullet animation needed
function BossAttack.animateBullet(startPosition, direction, spreadDirections)
    -- Return a no-op function since boss attack is instant
    return function(deltaTime)
        -- No animation needed for instant melee attack
    end
end

return BossAttack 