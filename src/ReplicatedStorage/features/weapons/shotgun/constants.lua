local ShotgunConstants = {
    -- Shop Properties
    SHOP = false,
    ID = "shotgun",
    PRICE = 500,
    DISPLAY_NAME = "Combat Shotgun",
    DESCRIPTION = "A powerful close-range weapon that fires multiple pellets in a spread pattern. Devastating at short range.",
    IMAGE_ID = "rbxassetid://0", -- Placeholder image ID
    
    -- Bullet Properties
    BULLET_SPEED = 100, -- studs per second
    BULLET_SIZE = Vector3.new(0.3, 0.3, 0.3),
    BULLET_COLOR = Color3.fromRGB(200, 200, 200),
    RANGE = 1000, -- Maximum distance a bullet can travel before being removed
    
    -- Shot Properties
    BULLETS_PER_SHOT = 8,
    SPREAD_ANGLE = math.rad(10), -- 15 degrees in radians
    DAMAGE_PER_BULLET = 5,
    
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

    RAYCAST_START_OFFSETS = {
        Vector3.new(0, 0, 0),     -- Centers
    },

    SPREAD_DIRECTIONS = {
        Vector3.new(0, 0, 0),                    -- Center pellet
        Vector3.new(0.1, 0, 0),                  -- Right
        Vector3.new(-0.1, 0, 0),                 -- Left
        Vector3.new(0, 0.1, 0),                  -- Up
        Vector3.new(0, -0.1, 0),                 -- Down
        Vector3.new(0.07, 0.07, 0),              -- Top-right diagonal
        Vector3.new(-0.07, 0.07, 0),             -- Top-left diagonal
        Vector3.new(0.07, -0.07, 0),             -- Bottom-right diagonal
    },
}

return ShotgunConstants 