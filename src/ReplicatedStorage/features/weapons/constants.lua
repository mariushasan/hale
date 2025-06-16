-- Main weapons constants file
local WeaponsConstants = {
    -- Valid weapon types
    VALID_WEAPONS = {
        ["shotgun"] = true,
        ["bossattack"] = true
    },
    
    -- Default values that can be overridden by specific weapons
    DEFAULT_BULLET_SPEED = 100,
    DEFAULT_MAX_BULLET_DISTANCE = 1000,
    DEFAULT_DAMAGE = 10,
}

return WeaponsConstants
