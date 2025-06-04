local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- Import constants
local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)

-- Remote events
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local WeaponSelectionEvent = ReplicatedStorage:WaitForChild("WeaponSelectionEvent")

local ModelLoader = require(game.ServerScriptService.Server.features.weapons.shotgun.ModelLoader)
local weapons = {}

-- Store player weapons
local playerWeapons = {}
local playerWeaponModels = {}

-- Bullet tracking system
local activeBullets = {}
local bulletIdCounter = 0
local maxBulletLifetime = 5 -- seconds

-- Lag compensation system
local playerPositionHistory = {}
local maxHistoryTime = 1 -- Keep 1 second of history
local positionSampleRate = 1/60 -- Sample 60 times per second

-- Valid weapon types
local VALID_WEAPONS = {
    ["shotgun"] = true
}

-- Generate unique bullet ID
local function generateBulletId()
    bulletIdCounter = bulletIdCounter + 1
    return "bullet_" .. bulletIdCounter .. "_" .. tick()
end

-- Create bullet data structure
local function createBulletData(bulletId, shooter, weaponType, startPosition, direction)
    return {
        id = bulletId,
        shooterId = shooter.UserId,
        shooterName = shooter.Name,
        weaponType = weaponType,
        currentPosition = startPosition,
        direction = direction.Unit,
        speed = ShotgunConstants.BULLET_SPEED,
        timestamp = tick(),
        lastUpdateTime = tick()
    }
end

-- Add bullet to tracking system
local function trackBullet(bulletData)
    activeBullets[bulletData.id] = bulletData
    
    -- Send to all clients except the shooter
    for _, player in ipairs(Players:GetPlayers()) do
        if player.UserId ~= bulletData.shooterId then
            ShootEvent:FireClient(player, {
                action = "create",
                bulletData = bulletData
            })
        end
    end
end

-- Remove bullet from tracking system
local function removeBullet(bulletId, reason)
    if activeBullets[bulletId] then
        activeBullets[bulletId] = nil
        
        -- Notify all clients to remove bullet
        ShootEvent:FireAllClients({
            action = "destroy",
            bulletId = bulletId,
            reason = reason or "timeout"
        })
    end
end

-- Apply damage to a player
local function applyDamage(player, damage)
    if not player or not player.Character then return end
    
    local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
    if humanoid and humanoid.Health > 0 then
        print("Applying", damage, "damage to", player.Name, "- Health before:", humanoid.Health)
        humanoid:TakeDamage(damage)
        print("Health after:", humanoid.Health)
    end
end

-- Update bullet positions and check for collisions
local function updateBullets(deltaTime)
    local bulletsToRemove = {}
    
    for bulletId, bulletData in pairs(activeBullets) do
        local currentTime = tick()
        local timeSinceLastUpdate = currentTime - bulletData.lastUpdateTime
        
        -- Calculate new position
        local moveDistance = bulletData.speed * timeSinceLastUpdate
        local newPosition = bulletData.currentPosition + (bulletData.direction * moveDistance)
        
        -- Create raycast parameters
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {Players:GetPlayerByUserId(bulletData.shooterId).Character}
        
        -- Perform raycast from current position to new position
        local raycastResult = workspace:Raycast(bulletData.currentPosition, newPosition - bulletData.currentPosition, raycastParams)
        
        if raycastResult then
            -- Bullet hit something
            local hitPart = raycastResult.Instance
            local hitCharacter = hitPart.Parent
            
            print("Bullet hit:", hitPart.Name, "in character:", hitCharacter.Name)
            
            -- Check if we hit a player
            if hitCharacter:FindFirstChildOfClass("Humanoid") then
                print("Found humanoid in:", hitCharacter.Name)
                local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
                if hitPlayer then
                    print("Hit player:", hitPlayer.Name)
                    -- Apply damage based on weapon type
                    local damage = ShotgunConstants.DAMAGE_PER_PELLET
                    applyDamage(hitPlayer, damage)
                else
                    print("Hit character with humanoid but no associated player:", hitCharacter.Name)
                    -- Handle non-player characters (dummies, NPCs, etc.)
                    local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        print("Applying damage to NPC/dummy:", hitCharacter.Name, "- Health before:", humanoid.Health)
                        humanoid:TakeDamage(ShotgunConstants.DAMAGE_PER_PELLET)
                        print("Health after:", humanoid.Health)
                    end
                end
            else
                print("No humanoid found in hit character:", hitCharacter.Name)
            end
            
            table.insert(bulletsToRemove, {id = bulletId, reason = "collision"})
        else
            -- Update bullet position
            bulletData.currentPosition = newPosition
            bulletData.lastUpdateTime = currentTime
            
            -- Check if bullet has traveled too far
            local totalDistance = (bulletData.currentPosition - bulletData.currentPosition).Magnitude
            if totalDistance > ShotgunConstants.MAX_BULLET_DISTANCE then
                table.insert(bulletsToRemove, {id = bulletId, reason = "max_distance"})
            end
            
            -- Check if bullet is too old
            if currentTime - bulletData.timestamp > maxBulletLifetime then
                table.insert(bulletsToRemove, {id = bulletId, reason = "timeout"})
            end
        end
    end
    
    -- Remove bullets that should be destroyed
    for _, bulletInfo in ipairs(bulletsToRemove) do
        removeBullet(bulletInfo.id, bulletInfo.reason)
    end
end

local function equipWeaponModel(player, weaponType)
    local character = player.Character
    if not character then return end

    -- Clean up existing weapon model
    if playerWeaponModels[player.UserId] then
        playerWeaponModels[player.UserId]:Destroy()
        playerWeaponModels[player.UserId] = nil
    end

    -- Create new weapon model using shared handler
    if weaponType == "shotgun" then
        local model = nil
        if model then
            playerWeaponModels[player.UserId] = model
        end
    end
end

local function unequipWeaponModel(player)
    local character = player.Character
    if not character then return end

    -- Use shared handler to unequip
    local weaponType = playerWeapons[player.UserId]

    -- Clean up reference
    if playerWeaponModels[player.UserId] then
        playerWeaponModels[player.UserId] = nil
    end
end

-- Store player position for lag compensation
local function recordPlayerPosition(player)
    if not player.Character or not player.Character.PrimaryPart then return end
    
    local userId = player.UserId
    local currentTime = tick()
    local position = player.Character.PrimaryPart.Position
    
    if not playerPositionHistory[userId] then
        playerPositionHistory[userId] = {}
    end
    
    -- Add current position to history
    table.insert(playerPositionHistory[userId], {
        time = currentTime,
        position = position,
        character = player.Character
    })
    
    -- Clean up old history
    local cutoffTime = currentTime - maxHistoryTime
    local history = playerPositionHistory[userId]
    for i = #history, 1, -1 do
        if history[i].time < cutoffTime then
            table.remove(history, i)
        end
    end
end

-- Get player position at a specific time in the past
local function getPlayerPositionAtTime(player, targetTime)
    local userId = player.UserId
    local history = playerPositionHistory[userId]
    
    if not history or #history == 0 then
        -- No history available, use current position
        if player.Character and player.Character.PrimaryPart then
            return player.Character.PrimaryPart.Position, player.Character
        end
        return nil, nil
    end
    
    -- Find the closest recorded position to the target time
    local closestEntry = history[1]
    local closestTimeDiff = math.abs(history[1].time - targetTime)
    
    for _, entry in ipairs(history) do
        local timeDiff = math.abs(entry.time - targetTime)
        if timeDiff < closestTimeDiff then
            closestTimeDiff = timeDiff
            closestEntry = entry
        end
    end
    
    return closestEntry.position, closestEntry.character
end

-- Temporarily move players to their positions at fire time
local function setupLagCompensation(fireTime, shooter)
    local originalPositions = {}
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= shooter and player.Character and player.Character.PrimaryPart then
            -- Store original position
            originalPositions[player.UserId] = player.Character.PrimaryPart.Position
            
            -- Get position at fire time
            local pastPosition, pastCharacter = getPlayerPositionAtTime(player, fireTime)
            if pastPosition then
                -- Move player to past position
                player.Character.PrimaryPart.Position = pastPosition
            end
        end
    end
    
    return originalPositions
end

-- Restore players to their current positions
local function restoreLagCompensation(originalPositions)
    for userId, originalPosition in pairs(originalPositions) do
        local player = Players:GetPlayerByUserId(userId)
        if player and player.Character and player.Character.PrimaryPart then
            player.Character.PrimaryPart.Position = originalPosition
        end
    end
end

-- Handle weapon selection
function weapons.init()
    ModelLoader()
    
    -- Start bullet update loop
    RunService.Heartbeat:Connect(updateBullets)
    
    -- Start position recording for lag compensation
    RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            recordPlayerPosition(player)
        end
    end)
    
    WeaponSelectionEvent.OnServerEvent:Connect(function(player, weaponType)
        -- Validate weapon type
        if not VALID_WEAPONS[weaponType] then
            warn("Invalid weapon type selected:", weaponType)
            return
        end
        
        -- Unequip current weapon model
        unequipWeaponModel(player)
        
        -- Store the selected weapon for this player
        playerWeapons[player.UserId] = weaponType
        
        -- Equip the weapon model visually
        equipWeaponModel(player, weaponType)
        
        -- Also store it in the player's character for persistence
        if player.Character then
            local weaponValue = player.Character:FindFirstChild("SelectedWeapon")
            if not weaponValue then
                weaponValue = Instance.new("StringValue")
                weaponValue.Name = "SelectedWeapon"
                weaponValue.Parent = player.Character
            end
            weaponValue.Value = weaponType
        end
    end)

    -- Handle shooting with bullet tracking
    ShootEvent.OnServerEvent:Connect(function(player, startPosition, direction, clientTimestamp)
        -- Get the player's selected weapon
        local weaponType = playerWeapons[player.UserId]
        
        -- Validate weapon type before using
        if not VALID_WEAPONS[weaponType] then
            warn("Invalid weapon type detected:", weaponType)
            return
        end
        
        -- Calculate when the client actually fired
        local serverTime = tick()
        local clientFireTime = clientTimestamp or serverTime
        
        -- Setup lag compensation - rewind other players to fire time
        local originalPositions = setupLagCompensation(clientFireTime, player)
        
        -- For shotgun, create multiple bullets with spread
        if weaponType == "shotgun" then
            for i = 1, ShotgunConstants.PELLETS_PER_SHOT do
                -- Create spread for each pellet
                local spreadX = (math.random() - 0.5) * 2 * ShotgunConstants.SPREAD_ANGLE
                local spreadY = (math.random() - 0.5) * 2 * ShotgunConstants.SPREAD_ANGLE
                local spreadDirection = CFrame.fromOrientation(spreadX, spreadY, 0) * direction.Unit
                
                -- Generate unique bullet ID
                local bulletId = generateBulletId()
                
                -- Calculate fast-forward distance
                local networkDelay = serverTime - clientFireTime
                local fastForwardDistance = ShotgunConstants.BULLET_SPEED * networkDelay
                local fastForwardedStartPosition = startPosition + (spreadDirection * fastForwardDistance)
                
                -- Check for immediate collision during fast-forward period (with lag compensation)
                local raycastParams = RaycastParams.new()
                raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
                raycastParams.FilterDescendantsInstances = {player.Character}
                
                local fastForwardRaycast = workspace:Raycast(startPosition, spreadDirection * fastForwardDistance, raycastParams)
                
                if fastForwardRaycast then
                    -- Hit something during fast-forward, handle damage immediately
                    local hitPart = fastForwardRaycast.Instance
                    local hitCharacter = hitPart.Parent
                    
                    print("Lag-compensated raycast hit:", hitPart.Name, "in character:", hitCharacter.Name)
                    
                    if hitCharacter:FindFirstChildOfClass("Humanoid") then
                        local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
                        if hitPlayer then
                            -- Apply damage to player
                            local damage = ShotgunConstants.DAMAGE_PER_PELLET
                            applyDamage(hitPlayer, damage)
                        else
                            -- Apply damage to NPC/dummy
                            local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                print("Applying lag-compensated damage to NPC/dummy:", hitCharacter.Name, "- Health before:", humanoid.Health)
                                humanoid:TakeDamage(ShotgunConstants.DAMAGE_PER_PELLET)
                                print("Health after:", humanoid.Health)
                            end
                        end
                    end
                    
                    -- Don't create a bullet since it hit something immediately
                    removeBullet(bulletId, "immediate_collision")
                else
                    -- No immediate hit, create bullet at fast-forwarded position
                    local bulletData = createBulletData(
                        bulletId, 
                        player, 
                        weaponType, 
                        fastForwardedStartPosition, 
                        spreadDirection
                    )
                    
                    -- Adjust timestamp to account for the fast-forward
                    bulletData.timestamp = clientFireTime
                    bulletData.lastUpdateTime = serverTime
                    
                    -- Track bullet on server and replicate to other clients
                    trackBullet(bulletData)
                end
            end
        end
        
        -- Restore lag compensation - move players back to current positions
        restoreLagCompensation(originalPositions)
    end)

    -- Clean up when players leave
    Players.PlayerRemoving:Connect(function(player)
        unequipWeaponModel(player)
        playerWeapons[player.UserId] = nil
        playerWeaponModels[player.UserId] = nil
        
        -- Remove any bullets from this player
        local bulletsToRemove = {}
        for bulletId, bulletData in pairs(activeBullets) do
            if bulletData.shooterId == player.UserId then
                table.insert(bulletsToRemove, bulletId)
            end
        end
        
        for _, bulletId in ipairs(bulletsToRemove) do
            removeBullet(bulletId)
        end
    end)

    -- Handle character respawning
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            -- Clean up old weapon model reference
            playerWeaponModels[player.UserId] = nil
            
            -- Restore the player's weapon selection when they respawn
            local weaponType = playerWeapons[player.UserId]
            if weaponType then
                local weaponValue = character:FindFirstChild("SelectedWeapon")
                if not weaponValue then
                    weaponValue = Instance.new("StringValue")
                    weaponValue.Name = "SelectedWeapon"
                    weaponValue.Parent = character
                end
                weaponValue.Value = weaponType
                
                -- Re-equip the weapon model after a short delay to ensure character is fully loaded
                task.wait(1)
                equipWeaponModel(player, weaponType)
            end
        end)
    end)

    -- Handle existing players
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character then
            player.CharacterAdded:Connect(function(character)
                -- Clean up old weapon model reference
                playerWeaponModels[player.UserId] = nil
                
                -- Restore the player's weapon selection when they respawn
                local weaponType = playerWeapons[player.UserId]
                if weaponType then
                    local weaponValue = character:FindFirstChild("SelectedWeapon")
                    if not weaponValue then
                        weaponValue = Instance.new("StringValue")
                        weaponValue.Name = "SelectedWeapon"
                        weaponValue.Parent = character
                    end
                    weaponValue.Value = weaponType
                    
                    -- Re-equip the weapon model after a short delay
                    task.wait(1)
                    equipWeaponModel(player, weaponType)
                end
            end)
        end
    end
end

return weapons