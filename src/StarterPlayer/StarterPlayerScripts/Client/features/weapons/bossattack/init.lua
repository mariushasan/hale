local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")

local BossAttackConstants = require(ReplicatedStorage.features.weapons.bossattack.constants)
local HitGui = require(script.Parent.ui.HitGui)

local BossAttack = {}

-- Per-weapon fire rate tracking
local lastFireTime = 0
local bulletCounter = 0

-- Generate unique bullet ID
local function generateBulletId()
    local player = Players.LocalPlayer
    bulletCounter = bulletCounter + 1
    return player.Name .. "_" .. tick() .. "_" .. bulletCounter
end

-- Create explosion effect
local function createExplosionEffect(position)
    local effect = Instance.new("Explosion")
    effect.Position = position
    effect.BlastRadius = BossAttackConstants.EXPLOSION_BLAST_RADIUS
    effect.BlastPressure = BossAttackConstants.EXPLOSION_BLAST_PRESSURE
    effect.Visible = true
    effect.Parent = workspace
end

-- Create spread pattern for boss attack (melee raycasts)
function BossAttack.createSpreadPattern(startPosition, direction)
    local forwardVector = direction.Unit
    local rightVector, upVector
    
    -- Calculate right/up vectors from the provided direction
    -- Cross product with world up vector (0,1,0) to get right vector
    rightVector = forwardVector:Cross(Vector3.new(0, 1, 0))
    if rightVector.Magnitude < 0.1 then
        -- If looking straight up/down, use world right vector
        rightVector = Vector3.new(1, 0, 0)
    else
        rightVector = rightVector.Unit
    end
    -- Cross product of right and forward to get up vector
    upVector = rightVector:Cross(forwardVector).Unit
    
    local bullets = {}
    
    -- Create square pattern for melee attack (based on constants RAYCAST_START_OFFSETS)
    local offsets = {
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
    }
    
    -- Create raycast data for all offsets
    local raycastData = {}
    for i, offset in ipairs(offsets) do
        -- Apply offset in local space (right/up vectors)
        local localOffset = rightVector * offset.X + upVector * offset.Y
        -- Scale down the offset for melee range
        localOffset = localOffset * 0.05 -- Smaller spread for melee
        
        -- Create bullet direction (forward + slight offset)
        local bulletDirection = (forwardVector + localOffset).Unit
        
        -- Create bullet start position (slightly offset from center)
        local bulletStartPosition = startPosition + localOffset
        
        table.insert(raycastData, {
            direction = bulletDirection,
            startPosition = bulletStartPosition
        })
    end
    
    -- Boss attack has one bullet with multiple raycasts
    local bullet = {
        -- Multiple raycast positions/directions
        raycastData = raycastData,
        -- Single animation direction (center/main direction)
        animationDirection = forwardVector,
        animationStartPosition = startPosition
    }
    table.insert(bullets, bullet)
    
    return bullets
end

function BossAttack.equip()
    -- Boss attack doesn't need visual weapon model
end

function BossAttack.unequip()
end

function BossAttack.fire(startPosition, direction)
    -- Create immediate explosion effect at player position
    createExplosionEffect(startPosition)
end

-- Boss attack is instantaneous, so no bullet animation needed
function BossAttack.animateBullet(startPosition, direction, maxDistance)
    -- Return a no-op function since boss attack is instant
    return function(deltaTime)
        -- No animation needed for instant melee attack
    end
end

function BossAttack.handleFireFromClient()
    local Players = game:GetService("Players")
    local player = Players.LocalPlayer
    
    -- Check fire rate
    local currentTime = tick()
    local fireRate = BossAttackConstants.COOLDOWN or 2
    if not (currentTime - lastFireTime >= fireRate) then
        return {}, {} -- Return empty hits and bullets
    end
    
    lastFireTime = currentTime
    
    -- Calculate local firing parameters
    local camera = workspace.CurrentCamera
    if not camera then
        return {}, {} -- Return empty hits and bullets
    end
    
    local direction = camera.CFrame.LookVector
    local startPosition = camera.CFrame.Position + direction * 2
    local bullets = BossAttack.createSpreadPattern(startPosition, direction)
    
    -- Assign bullet IDs
    for _, bullet in ipairs(bullets) do
        bullet.id = generateBulletId()
    end
    
    local hits = {}
    local bulletAnimations = {}
    
    for _, bullet in ipairs(bullets) do
        -- Check if this is a local firing (bullet ID starts with local player's name)
        if bullet.id and bullet.id:find("^" .. player.Name .. "_") then
            -- Perform client-side raycasts for this bullet
            local camera = workspace.CurrentCamera
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            raycastParams.FilterDescendantsInstances = {player.Character}
            
            local bulletHit = false
            local hitPart = nil
            local hitPosition = nil
            local hitRaycastData = nil -- Store which raycast actually hit
            
            -- Try each raycast for this bullet until we get a hit (boss attack has multiple raycasts per bullet)
            for _, raycastData in ipairs(bullet.raycastData) do
                if bulletHit then break end -- Stop if we already hit something (only one hit per bullet)
                
                -- Raycast in the direction we're shooting (shorter range for melee)
                local raycastDistance = BossAttackConstants.MAX_BULLET_DISTANCE or 10 -- Short range for melee
                local raycastResult = workspace:Raycast(raycastData.startPosition, raycastData.direction * raycastDistance, raycastParams)
                
                if raycastResult and raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid") then
                    hitPart = raycastResult.Instance
                    hitPosition = raycastResult.Position
                    hitRaycastData = raycastData -- Store the raycast data that hit
                    bulletHit = true -- Mark that this bullet hit something
                end
            end
            
            -- Calculate max distance for animation
            local maxDistance = BossAttackConstants.MAX_BULLET_DISTANCE
            local hitVector = hitPosition and hitPosition - bullet.animationStartPosition
            if hitVector then
                maxDistance = hitVector.Magnitude
            end
            
            -- Create bullet animation
            local updateBullet = BossAttack.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
            if updateBullet then
                bulletAnimations[bullet.id] = {
                    update = updateBullet
                }
            end
            
            -- Only add hit data if we actually hit something
            if bulletHit then
                table.insert(hits, {
                    id = bullet.id,
                    direction = hitRaycastData.direction, -- Use the actual raycast direction that hit
                    startPosition = hitRaycastData.startPosition, -- Use the actual raycast start position that hit
                    animationStartPosition = bullet.animationStartPosition,
                    animationDirection = bullet.animationDirection,
                    hitPart = hitPart,
                    hitPosition = hitPosition,
                    maxDistance = maxDistance,
                })
            else
                table.insert(hits, {
                    id = bullet.id,
                    animationStartPosition = bullet.animationStartPosition,
                    animationDirection = bullet.animationDirection,
                    hitPosition = hitPosition,
                    maxDistance = maxDistance,
                })
            end
        end
    end
    
    -- Handle damage display for boss attack
    if #hits > 0 then
        local avgHitPosition, validHits = HitGui.calculateAverageHitPosition(hits)
        if avgHitPosition and validHits > 0 then
            local totalDamage = validHits * BossAttackConstants.DAMAGE
            HitGui.showDamageNumber(totalDamage, avgHitPosition)
        end
    end
    
    return hits, bulletAnimations
end

function BossAttack.handleFireFromServer(bullets)
    local bulletAnimations = {}
    
    for _, bullet in ipairs(bullets) do
        local maxDistance = BossAttackConstants.MAX_BULLET_DISTANCE
        local hitVector = bullet.hitPosition and bullet.hitPosition - bullet.animationStartPosition
        if hitVector then
            maxDistance = hitVector.Magnitude
        end

        local updateBullet = BossAttack.animateBullet(bullet.animationStartPosition, bullet.animationDirection, maxDistance)
        if updateBullet then
            bulletAnimations[bullet.id] = {
                update = updateBullet
            }
        end
    end
    
    return bulletAnimations
end

return BossAttack 