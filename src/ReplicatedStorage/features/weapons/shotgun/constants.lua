local ShotgunConstants = {
    -- Bullet Properties
    BULLET_SPEED = 100, -- studs per second
    BULLET_SIZE = Vector3.new(0.3, 0.3, 0.3),
    BULLET_COLOR = Color3.fromRGB(200, 200, 200),
    MAX_BULLET_DISTANCE = 1000, -- Maximum distance a bullet can travel before being removed
    
    -- Shot Properties
    PELLETS_PER_SHOT = 8,
    SPREAD_ANGLE = math.rad(15), -- 15 degrees in radians
    DAMAGE_PER_PELLET = 10,
    
    -- Visual Effects
    MUZZLE_FLASH_DURATION = 0.1,
    TRAIL_LIFETIME = 0.2,
    TRAIL_COLOR = Color3.fromRGB(255, 200, 100),
    TRAIL_TRANSPARENCY = 0.5,
    
    -- Animation
    FIRE_ANIMATION_DURATION = 0.3,
    RECOIL_AMOUNT = 0.5, -- studs
    RECOIL_RECOVERY_SPEED = 5, -- studs per second

    FIRE_COOLDOWN = 0.5, -- seconds
}

return ShotgunConstants 