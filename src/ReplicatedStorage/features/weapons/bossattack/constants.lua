local BossAttackConstants = {
    -- Attack Properties
    DAMAGE = 75,
    RANGE = 15, -- This will be the MAX_BULLET_DISTANCE for boss attack
    COOLDOWN = 2, -- seconds
    
    -- "Bullet" Properties (for simulation)
    BULLET_SPEED = 1000, -- Very fast so it hits almost immediately
    MAX_BULLET_DISTANCE = 15, -- Same as range
    
    -- Raycast Offsets (square pattern for larger hitbox)
    RAYCAST_START_OFFSETS = {
        Vector3.new(0, 0, 0),     -- Center
        Vector3.new(-2, 0, 0),    -- Left
        Vector3.new(2, 0, 0),     -- Right
        Vector3.new(0, 2, 0),     -- Up
        Vector3.new(0, -2, 0),    -- Down
        Vector3.new(-2, 2, 0),    -- Top-left
        Vector3.new(2, 2, 0),     -- Top-right
        Vector3.new(-2, -2, 0),   -- Bottom-left
        Vector3.new(2, -2, 0),    -- Bottom-right
        Vector3.new(-1, 1, 0),    -- Inner top-left
        Vector3.new(1, 1, 0),     -- Inner top-right
        Vector3.new(-1, -1, 0),   -- Inner bottom-left
        Vector3.new(1, -1, 0),    -- Inner bottom-right
    },

    SPREAD_DIRECTIONS = {
        Vector3.new(0, 0, 0),     -- Center
    },
    
    -- Visual Effects
    EXPLOSION_BLAST_RADIUS = 15,
    EXPLOSION_BLAST_PRESSURE = 0, -- No physics blast, just visual
    
    -- Area of Effect
    AOE_DAMAGE = 75, -- Same as main damage since it's area effect
}

return BossAttackConstants 