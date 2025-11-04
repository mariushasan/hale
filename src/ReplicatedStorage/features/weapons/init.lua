-- Import individual weapon constants
local ShotgunConstants = require(script.shotgun.constants)
local BossAttackConstants = require(script.bossattack.constants)
local AssaultRifleConstants = require(script.assaultrifle.constants)
local RevolverConstants = require(script.revolver.constants)
local UMPConstants = require(script.ump.constants)
-- Centralized weapon constants table
local WeaponConstants = {
    Shotgun = ShotgunConstants,
    BossAttack = BossAttackConstants,
    AssaultRifle = AssaultRifleConstants,
    Revolver = RevolverConstants,
    UMP = UMPConstants,
}

return WeaponConstants 