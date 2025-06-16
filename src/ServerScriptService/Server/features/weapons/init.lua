local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TimeSync = require(game.ReplicatedStorage.shared.TimeSync)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

-- Import constants
local WeaponsConstants = require(ReplicatedStorage.features.weapons.constants)
local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local BossAttackConstants = require(ReplicatedStorage.features.weapons.bossattack.constants)

debugLog = require(game.ServerScriptService.Server.shared.DebugLog)
-- Import server-side weapon modules
local BossAttackModule = require(script.bossattack)
local ShotgunModule = require(script.shotgun)
-- Get weapon constants based on weapon type
local function getWeaponConstants(weaponType)
    if weaponType == "shotgun" then
        return ShotgunConstants
    elseif weaponType == "bossattack" then
        return BossAttackConstants
    else
        return WeaponsConstants -- fallback to default constants
    end
end

-- Get server-side weapon module based on weapon type
local function getWeaponModule(weaponType)
    if weaponType == "bossattack" then
        return BossAttackModule
    elseif weaponType == "shotgun" then
        return ShotgunModule
    else
        return nil -- No server-side logic needed
    end
end

-- Remote events
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local WeaponSelectionEvent = ReplicatedStorage:WaitForChild("WeaponSelectionEvent")

local DummySystem = require(script.DummySystem)
local weapons = {}

-- Store player weapons
local playerWeapons = {}
local playerWeaponModels = {}

-- Bullet tracking system
local activeBullets = {}
local maxBulletLifetime = 5 -- seconds

-- Lag compensation system
local playerPositionHistory = {} -- Now keyed by reference part position: [referencePos] = {userId1 = position1, userId2 = position2, ...}
local MAX_HISTORY_ENTRIES = 60 -- Keep 2 seconds of history (60 FPS * 2 seconds) - enough for network latency

-- Lag compensation parts cache
local lagCompensationCache = {}
local HOLDING_POSITION = Vector3.new(0, -1000, 0) -- Far away holding area

-- R15 body part names
local R15_BODY_PARTS = {
    "Head",
    "UpperTorso", "LowerTorso",
    "LeftUpperArm", "LeftLowerArm", "LeftHand",
    "RightUpperArm", "RightLowerArm", "RightHand", 
    "LeftUpperLeg", "LeftLowerLeg", "LeftFoot",
    "RightUpperLeg", "RightLowerLeg", "RightFoot"
}

-- Create bullet data structure
local function createBulletData(bulletId, shooter, weaponType, startPosition, spreadDirections)
    local weaponConstants = getWeaponConstants(weaponType)
    
    return {
        id = bulletId,
        shooterId = shooter.UserId,
        shooterName = shooter.Name,
        weaponType = weaponType,
        currentPosition = startPosition,
        spreadDirections = spreadDirections,
        speed = weaponConstants.BULLET_SPEED or WeaponsConstants.DEFAULT_BULLET_SPEED,
        timestamp = TimeSync.getServerTimeMillis(),
        lastUpdateTime = TimeSync.getServerTimeMillis(),
        startPosition = startPosition,
        maxDistance = weaponConstants.MAX_BULLET_DISTANCE or WeaponsConstants.DEFAULT_MAX_BULLET_DISTANCE
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
        })
    end
end

-- Create explosion effect for boss attacks
local function createExplosionEffect(position, weaponType)
    if weaponType == "bossattack" then
        local effect = Instance.new("Explosion")
        effect.Position = position
        effect.BlastRadius = BossAttackConstants.EXPLOSION_BLAST_RADIUS
        effect.BlastPressure = BossAttackConstants.EXPLOSION_BLAST_PRESSURE
        effect.Visible = true
        effect.Parent = workspace
    end
end

-- Update bullet positions and check for collisions
local function updateBullets(deltaTime)
    local bulletsToRemove = {}
    
    for bulletId, bulletData in pairs(activeBullets) do
        local currentTime = TimeSync.getServerTimeMillis()
        local timeSinceLastUpdate = currentTime - bulletData.lastUpdateTime
        local weaponConstants = getWeaponConstants(bulletData.weaponType)
        
        -- Calculate new position
        local moveDistance = bulletData.speed * timeSinceLastUpdate
        local newPosition = bulletData.currentPosition + (bulletData.direction * moveDistance)
        
        -- Create raycast parameters
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        
        -- Create blacklist of all characters (players and dummies) so raycast only hits lag compensation parts
        local blacklist = {bulletData.shooter.Character} -- Always exclude the shooter
        
        -- Add all other players to blacklist
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer ~= bulletData.shooter and otherPlayer.Character then
                table.insert(blacklist, otherPlayer.Character)
            end
        end
        
        -- Add all dummies to blacklist
        local allDummies = DummySystem.getAllDummies()
        for _, dummy in ipairs(allDummies) do
            if dummy then
                table.insert(blacklist, dummy)
            end
        end
        
        raycastParams.FilterDescendantsInstances = blacklist
        
        -- Perform raycast from current position to new position
        local raycastResult = workspace:Raycast(bulletData.currentPosition, newPosition - bulletData.currentPosition, raycastParams)

        if raycastResult then
            -- Bullet hit something
            local hitPart = raycastResult.Instance
            local hitCharacter = hitPart.Parent
            -- Handle regular projectile damage
            if hitCharacter:FindFirstChildOfClass("Humanoid") then
                local damage = weaponConstants.DAMAGE_PER_PELLET or weaponConstants.DAMAGE
                hitCharacter:FindFirstChildOfClass("Humanoid"):TakeDamage(damage)
                local player = Players:GetPlayerByUserId(bulletData.shooterId)
                if player.Team.Name == "Other" then
                    Leaderboard.addToStat(player, "Damage", 1)
                end
            end
            
            table.insert(bulletsToRemove, {id = bulletId, reason = "collision"})
        else
            -- Update bullet position
            bulletData.currentPosition = newPosition
            bulletData.lastUpdateTime = currentTime
            
            -- Check if bullet has traveled too far
            local totalDistance = (bulletData.currentPosition - bulletData.startPosition).Magnitude
            
            if totalDistance > bulletData.maxDistance then
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

-- Record all player positions using reference part position as key
local function recordAllPlayerPositions()
    local referencePart = workspace:FindFirstChild("LagCompensationReference")
    if not referencePart then return end
    
    local referencePosition = referencePart.Position
    local currentTime = TimeSync.getServerTimeMillis()
    
    -- Create entry for this reference position
    local positionEntry = {
        time = currentTime,
        players = {},
        dummies = {}
    }
    
    -- Record all player positions
    for _, player in ipairs(Players:GetPlayers()) do
        if player.Character and player.Character.PrimaryPart then
            positionEntry.players[player.UserId] = {
                position = player.Character.PrimaryPart.Position,
                character = player.Character
            }
        end
    end
    
    -- Record all dummy positions
    local allDummies = DummySystem.getAllDummies()
    for _, dummy in ipairs(allDummies) do
        if dummy and dummy.PrimaryPart then
            positionEntry.dummies[dummy.Name] = {
                position = dummy.PrimaryPart.Position,
                dummy = dummy
            }
        end
    end
    
    -- Store using reference position as key (convert to string for table key)
    local positionKey = string.format("%.2f,%.2f,%.2f", referencePosition.X, referencePosition.Y, referencePosition.Z)
    playerPositionHistory[positionKey] = positionEntry
    
    -- Clean up old entries (keep only recent ones)
    local historyKeys = {}
    for key, _ in pairs(playerPositionHistory) do
        table.insert(historyKeys, key)
    end
    
    -- Sort by time and remove oldest entries
    table.sort(historyKeys, function(a, b)
        return playerPositionHistory[a].time > playerPositionHistory[b].time
    end)
    
    -- Keep only the most recent entries
    for i = MAX_HISTORY_ENTRIES + 1, #historyKeys do
        playerPositionHistory[historyKeys[i]] = nil
    end
end

-- Get player position at reference part position
local function getPlayerPositionAtReferencePosition(player, referencePosition)
    local positionKey = string.format("%.2f,%.2f,%.2f", referencePosition.X, referencePosition.Y, referencePosition.Z)
    local entry = playerPositionHistory[positionKey]

    print("entry", entry)
    
    if not entry or not entry.players[player.UserId] then
        -- No history available, use current position
        if player.Character and player.Character.PrimaryPart then
            return player.Character.PrimaryPart.Position, player.Character
        end
        return nil, nil
    end
    
    local playerData = entry.players[player.UserId]
    return playerData.position, playerData.character
end

-- Get dummy position at reference part position
local function getDummyPositionAtReferencePosition(dummy, referencePosition)
    local positionKey = string.format("%.2f,%.2f,%.2f", referencePosition.X, referencePosition.Y, referencePosition.Z)
    local entry = playerPositionHistory[positionKey]

    print("entry", entry)
    
    if not entry or not entry.dummies[dummy.Name] then
        -- No history available, use current position
        if dummy.PrimaryPart then
            return dummy.PrimaryPart.Position, dummy
        end
        return nil, nil
    end
    
    local dummyData = entry.dummies[dummy.Name]
    return dummyData.position, dummyData.dummy
end

-- Create lag compensation parts for a player/dummy and store in cache
local function createLagCompensationPartsForCharacter(character, characterKey, isPlayer)
    if not character or not character.PrimaryPart then
        return
    end
    
    local parts = {}
    
    -- Create lag compensation part for each body part found
    for _, partName in ipairs(R15_BODY_PARTS) do
        local bodyPart = character:FindFirstChild(partName)
        if bodyPart and bodyPart:IsA("BasePart") then
            
            -- Create lag compensation part matching this body part
            local lagPart = Instance.new("Part")
            lagPart.Name = "LagCompensation_" .. characterKey .. "_" .. partName
            lagPart.Size = bodyPart.Size
            lagPart.Position = HOLDING_POSITION -- Store in holding area
            lagPart.Rotation = Vector3.new(0, 0, 0) -- Reset rotation
            lagPart.Anchored = true
            lagPart.CanCollide = false -- Disabled when in holding area
            lagPart.Transparency = 1 -- Invisible when in holding area
            
            -- Different colors for players vs dummies
            if isPlayer then
                lagPart.BrickColor = BrickColor.new("Bright blue")
            else
                lagPart.BrickColor = BrickColor.new("Bright red")
            end
            
            lagPart.Material = Enum.Material.Neon
            lagPart.Parent = workspace
            
            -- Add character reference
            if isPlayer then
                local playerValue = Instance.new("ObjectValue")
                playerValue.Name = "PlayerRef"
                playerValue.Value = Players:GetPlayerFromCharacter(character)
                playerValue.Parent = lagPart
            else
                local dummyValue = Instance.new("ObjectValue")
                dummyValue.Name = "DummyRef"
                dummyValue.Value = character
                dummyValue.Parent = lagPart
            end
            
            parts[partName] = lagPart
        end
    end
    
    lagCompensationCache[characterKey] = parts
end

-- Remove lag compensation parts from cache
local function removeLagCompensationPartsFromCache(characterKey)
    local parts = lagCompensationCache[characterKey]
    if parts then
        for partName, lagPart in pairs(parts) do
            if lagPart and lagPart.Parent then
                lagPart:Destroy()
            end
        end
        lagCompensationCache[characterKey] = nil
    end
end

-- Temporarily move players to their positions at fire time
local function setupLagCompensation(referencePosition, shooter)    
    local lagCompensationParts = {}
    
    -- Handle players
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= shooter and player.Character and player.Character.PrimaryPart then
            -- Get position at reference position
            local pastPosition, pastCharacter = getPlayerPositionAtReferencePosition(player, referencePosition)

            if pastPosition and player.Character:FindFirstChildOfClass("Humanoid") then
                -- Get cached lag compensation parts for this player
                local cachedParts = lagCompensationCache[tostring(player.UserId)]
                if cachedParts then
                    -- Calculate position offset from character's PrimaryPart to past position
                    local positionOffset = pastPosition - player.Character.PrimaryPart.Position
                    
                    -- Move cached parts to correct positions
                    for partName, lagPart in pairs(cachedParts) do
                        local bodyPart = player.Character:FindFirstChild(partName)
                        if bodyPart and lagPart and lagPart.Parent then
                            lagPart.Position = bodyPart.Position + positionOffset
                            lagPart.Rotation = bodyPart.Rotation
                            lagPart.CanCollide = false -- Keep collision disabled to prevent characters getting stuck
                            lagPart.Transparency = 0.3 -- Make visible
                            
                            table.insert(lagCompensationParts, lagPart)
                        end
                    end
                end
            end
        end
    end
    
    -- Handle dummies
    local allDummies = DummySystem.getAllDummies()
    
    for i, dummy in ipairs(allDummies) do
        if dummy and dummy.PrimaryPart and dummy:FindFirstChildOfClass("Humanoid") then
            -- Get dummy's position at reference position
            local pastPosition, pastDummy = getDummyPositionAtReferencePosition(dummy, referencePosition)
            print("SERVER (PAST) - " .. pastDummy.Name .. " position:", pastPosition)

            if pastPosition then
                -- Get cached lag compensation parts for this dummy
                local cachedParts = lagCompensationCache[dummy.Name]
                if cachedParts then
                    -- Calculate position offset from dummy's PrimaryPart to past position
                    local positionOffset = pastPosition - dummy.PrimaryPart.Position
                    
                    -- Move cached parts to correct positions
                    for partName, lagPart in pairs(cachedParts) do
                        local bodyPart = dummy:FindFirstChild(partName)
                        if bodyPart and lagPart and lagPart.Parent then
                            lagPart.Position = bodyPart.Position + positionOffset
                            lagPart.Rotation = bodyPart.Rotation
                            lagPart.CanCollide = false -- Keep collision disabled to prevent characters getting stuck
                            lagPart.Transparency = 0.3 -- Make visible
                            
                            table.insert(lagCompensationParts, lagPart)
                        end
                    end
                end
            end
        end
    end
    
    return lagCompensationParts
end

-- Restore players to their current positions
local function restoreLagCompensation(lagCompensationParts)
    for i, part in ipairs(lagCompensationParts) do
        if part and part.Parent then
            -- Move back to holding area instead of destroying
            part.Position = HOLDING_POSITION
            part.Transparency = 1 -- Make invisible
            part.Rotation = Vector3.new(0, 0, 0) -- Reset rotation
        end
    end
end

-- Public function to equip a weapon for a player (handles both server logic and client notification)
function weapons.equipPlayerWeapon(player, weaponType)
    -- Validate weapon type
    if not WeaponsConstants.VALID_WEAPONS[weaponType] then
        warn("Invalid weapon type for equipPlayerWeapon:", weaponType)
        return
    end
    
    -- Get previous weapon for unequipping
    local previousWeapon = playerWeapons[player.UserId]
    
    -- Unequip previous weapon's server-side logic
    if previousWeapon then
        local previousServerModule = getWeaponModule(previousWeapon)
        if previousServerModule and previousServerModule.unequip then
            previousServerModule.unequip(player)
        end
    end
    
    -- Store the selected weapon for this player
    playerWeapons[player.UserId] = weaponType
    
    -- Equip new weapon's server-side logic
    local newServerModule = getWeaponModule(weaponType)
    if newServerModule and newServerModule.equip then
        newServerModule.equip(player)
    end
    
    -- Equip the weapon model visually
    equipWeaponModel(player, weaponType)
    
    -- Store it in the player's character for persistence
    if player.Character then
        local weaponValue = player.Character:FindFirstChild("SelectedWeapon")
        if not weaponValue then
            weaponValue = Instance.new("StringValue")
            weaponValue.Name = "SelectedWeapon"
            weaponValue.Parent = player.Character
        end
        weaponValue.Value = weaponType
    end
    
    -- Notify client about the weapon change
    WeaponSelectionEvent:FireClient(player, weaponType)
end

-- Handle weapon selection
function weapons.init()    
    -- Initialize dummy system
    DummySystem.init()
    
    -- Cache lag compensation parts for existing dummies
    local allDummies = DummySystem.getAllDummies()
    for _, dummy in ipairs(allDummies) do
        if dummy and dummy.PrimaryPart and dummy:FindFirstChildOfClass("Humanoid") then
            createLagCompensationPartsForCharacter(dummy, dummy.Name, false)
        end
    end
    
    -- Start bullet update loop
    RunService.Heartbeat:Connect(updateBullets)
    
    -- Start position recording for lag compensation
    RunService.Heartbeat:Connect(function()
        recordAllPlayerPositions()
    end)
    
    -- Handle players joining - create lag compensation cache
    Players.PlayerAdded:Connect(function(player)
        
        player.CharacterAdded:Connect(function(character)
            -- Wait for character to fully load
            if character:FindFirstChild("Humanoid") and character.PrimaryPart then
                -- Create lag compensation parts cache for this player
                createLagCompensationPartsForCharacter(character, tostring(player.UserId), true)
            else
                -- Wait for character to fully load then create cache
                local humanoid = character:WaitForChild("Humanoid", 10)
                local primaryPart = character:WaitForChild("HumanoidRootPart", 10)
                if humanoid and primaryPart then
                    createLagCompensationPartsForCharacter(character, tostring(player.UserId), true)
                else
                    warn("Failed to create lag compensation cache for player " .. player.Name)
                end
            end
        end)
    end)
    
    -- Handle players leaving - clean up cache
    Players.PlayerRemoving:Connect(function(player)
        removeLagCompensationPartsFromCache(tostring(player.UserId))
        
        -- Unequip weapon's server-side logic before cleanup
        local currentWeapon = playerWeapons[player.UserId]
        if currentWeapon then
            local serverModule = getWeaponModule(currentWeapon)
            if serverModule and serverModule.unequip then
                serverModule.unequip(player)
            end
        end
        
        -- Clean up other player data
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
    
    WeaponSelectionEvent.OnServerEvent:Connect(function(player, weaponType)        
        -- Get previous weapon for unequipping
        local previousWeapon = playerWeapons[player.UserId]
        
        -- Unequip previous weapon's server-side logic
        if previousWeapon then
            local previousServerModule = getWeaponModule(previousWeapon)
            if previousServerModule and previousServerModule.unequip then
                previousServerModule.unequip(player)
            end
        end
        
        -- Unequip current weapon model
        unequipWeaponModel(player)
        
        -- Store the selected weapon for this player
        playerWeapons[player.UserId] = weaponType
        
        -- Equip new weapon's server-side logic
        local newServerModule = getWeaponModule(weaponType)
        if newServerModule and newServerModule.equip then
            newServerModule.equip(player)
        end
        
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
    ShootEvent.OnServerEvent:Connect(function(player, bulletId, startPosition, referencePartPosition, direction)
        -- Get the player's selected weapon
        local weaponType = playerWeapons[player.UserId]
        local weaponConstants = getWeaponConstants(weaponType)
        local weaponModule = getWeaponModule(weaponType)

        for _, child in pairs(workspace:GetChildren()) do
            if child:IsA("Model") and child.Name:find("TestDummy") and child.PrimaryPart then
                local dummyPosition = child.PrimaryPart.Position
            end
        end
        
        -- Use reference position directly for lag compensation
        local serverTime = TimeSync.getServerTimeMillis()
        
        -- Setup lag compensation using reference position directly
        local lagCompensationParts = setupLagCompensation(referencePartPosition, player)
        
        -- Calculate camera-relative spread directions (same as client)
        local forwardVector = direction.Unit
        local rightVector = forwardVector:Cross(Vector3.new(0, 1, 0)).Unit
        local upVector = rightVector:Cross(forwardVector).Unit
        
        local spreadDirections = {
            forwardVector,                                           -- Center 
        }
        
        for i, spreadDirection in ipairs(spreadDirections) do
            -- Add error handling for pellet processing
            local pelletBulletId = bulletId .. "_pellet_" .. i
            
            -- Check for immediate collision during fast-forward period (with lag compensation)
            local raycastParams = RaycastParams.new()
            raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
            
            -- Create blacklist of all characters (players and dummies) so raycast only hits lag compensation parts
            local blacklist = {player.Character} -- Always exclude the shooter
            
            -- Add all other players to blacklist
            for _, otherPlayer in ipairs(Players:GetPlayers()) do
                if otherPlayer ~= player and otherPlayer.Character then
                    table.insert(blacklist, otherPlayer.Character)
                end
            end
            
            -- Add all dummies to blacklist
            local allDummies = DummySystem.getAllDummies()
            for _, dummy in ipairs(allDummies) do
                if dummy then
                    table.insert(blacklist, dummy)
                end
            end
            
            raycastParams.FilterDescendantsInstances = blacklist

            for j, raycastStartOffset in ipairs(weaponConstants.RAYCAST_START_OFFSETS) do
                -- Use the spread direction directly (it's already calculated relative to aim direction)
                local raycastDirection = spreadDirection.Unit * weaponConstants.MAX_BULLET_DISTANCE
                local fastForwardRaycast = workspace:Raycast(startPosition + raycastStartOffset, raycastDirection, raycastParams)
                print("fastForwardRaycast", fastForwardRaycast)
                if fastForwardRaycast then
                    local hitPart = fastForwardRaycast.Instance
                    local hitCharacter = hitPart.Parent
                    
                    -- Check if we hit a lag compensation part
                    if hitPart.Name:find("LagCompensation_") then
                        local playerRef = hitPart:FindFirstChild("PlayerRef")
                        local dummyRef = hitPart:FindFirstChild("DummyRef")
                        
                        if playerRef and playerRef.Value then
                            local hitPlayer = playerRef.Value
                            local damage = weaponConstants.DAMAGE_PER_PELLET or weaponConstants.DAMAGE
                            local humanoid = hitPlayer.Character:FindFirstChildOfClass("Humanoid")
                            if humanoid then
                                humanoid:TakeDamage(damage)
                                if player.Team.Name == "Other" then
                                    Leaderboard.addToStat(player, "Damage", 1)
                                end
                            end
                        elseif dummyRef and dummyRef.Value then
                            local hitDummy = dummyRef.Value
                            local damage = weaponConstants.DAMAGE_PER_PELLET or weaponConstants.DAMAGE
                            local humanoid = hitDummy:FindFirstChildOfClass("Humanoid")
                            print("SERVER (HIT DUMMY) - " .. hitDummy.Name)
                            print(humanoid)
                            if humanoid then
                                humanoid:TakeDamage(damage)
                                if player.Team.Name == "Other" then
                                    Leaderboard.addToStat(player, "Damage", 1)
                                end
                            end
                        else
                            warn("Lag compensation part missing reference: " .. hitPart.Name)
                        end
                    end
                    break
                end
            end
        end

        -- Send single event to other clients with all spread directions
        local bulletData = createBulletData(
            bulletId, 
            player, 
            weaponType, 
            startPosition, 
            spreadDirections
        )
        
        -- Adjust timestamp to account for any processing
        bulletData.timestamp = serverTime
        bulletData.lastUpdateTime = serverTime
        
        -- Send to all clients except the shooter
        for _, otherPlayer in ipairs(Players:GetPlayers()) do
            if otherPlayer.UserId ~= player.UserId then
                ShootEvent:FireClient(otherPlayer, {
                    action = "create",
                    bulletData = bulletData
                })
            end
        end
        
        -- Restore lag compensation - move players back to current positions
        wait(2)
        restoreLagCompensation(lagCompensationParts)
    end)
end

return weapons