-- Import individual weapon constants
local ShotgunConstants = require(script.shotgun.constants)
local BossAttackConstants = require(script.bossattack.constants)
local AssaultRifleConstants = require(script.assaultrifle.constants)
-- Centralized weapon constants table
local WeaponConstants = {
    shotgun = ShotgunConstants,
    bossattack = BossAttackConstants,
    AssaultRifle = AssaultRifleConstants,
}

return WeaponConstants 