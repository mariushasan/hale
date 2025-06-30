local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TimeSync = require(game.ReplicatedStorage.shared.TimeSync)
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)

-- Import constants
local WeaponConstants = require(ReplicatedStorage.features.weapons)

debugLog = require(game.ServerScriptService.Server.shared.DebugLog)
-- Import server-side weapon modules
local BossAttackModule = require(script.bossattack)
local ShotgunModule = require(script.shotgun)

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
local playerPositionHistory = {} -- [userId] = {{time = timestamp, position = Vector3}, ...}
local dummyPositionHistory = {} -- [dummyName] = {{time = timestamp, position = Vector3}, ...}
local MAX_HISTORY_TIME_MS = 2000 -- Keep 2 seconds of history - enough for network latency

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

-- Update bullet positions and check for collisions
local function updateBullets(deltaTime)
    local bulletsToRemove = {}
    
    for bulletId, bulletData in pairs(activeBullets) do
        local currentTime = TimeSync.getServerTimeMillis()
        local timeSinceLastUpdate = currentTime - bulletData.lastUpdateTime
        local weaponConstants = WeaponConstants[bulletData.weaponType]
        
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
                local damage = weaponConstants.DAMAGE_PER_BULLET or weaponConstants.DAMAGE
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

-- Record player position for lag compensation
local function recordPlayerPosition(player)
    if not player.Character or not player.Character.PrimaryPart then return end
    
    local userId = player.UserId
    local currentTime = TimeSync.getServerTimeMillis()
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
    local cutoffTime = currentTime - MAX_HISTORY_TIME_MS
    local history = playerPositionHistory[userId]
    for i = #history, 1, -1 do
        if history[i].time < cutoffTime then
            table.remove(history, i)
        end
    end
end

-- Record dummy position for lag compensation
local function recordDummyPosition(dummy)
    if not dummy or not dummy.PrimaryPart then return end
    
    local dummyName = dummy.Name
    local currentTime = TimeSync.getServerTimeMillis()
    local position = dummy.PrimaryPart.Position
    
    if not dummyPositionHistory[dummyName] then
        dummyPositionHistory[dummyName] = {}
    end
    
    -- Add current position to history
    table.insert(dummyPositionHistory[dummyName], {
        time = currentTime,
        position = position,
        dummy = dummy
    })
    
    -- Clean up old history
    local cutoffTime = currentTime - MAX_HISTORY_TIME_MS
    local history = dummyPositionHistory[dummyName]
    for i = #history, 1, -1 do
        if history[i].time < cutoffTime then
            table.remove(history, i)
        end
    end
end

-- Get player position closest to a target position (for hit verification)
local function getPlayerPositionClosestTo(player, targetPosition)
    local userId = player.UserId
    local history = playerPositionHistory[userId]
    
    if not history or #history == 0 then
        -- No history available, use current position
        if player.Character and player.Character.PrimaryPart then
            return player.Character.PrimaryPart.Position, player.Character
        end
        return nil, nil
    end
    
    -- Find the closest recorded position to the target position
    local closestEntry = history[1]
    local closestDistance = (history[1].position - targetPosition).Magnitude
    
    for _, entry in ipairs(history) do
        local distance = (entry.position - targetPosition).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestEntry = entry
        end
    end
    
    return closestEntry.position, closestEntry.character
end

-- Get dummy position closest to a target position (for hit verification)
local function getDummyPositionClosestTo(dummy, targetPosition)
    local dummyName = dummy.Name
    local history = dummyPositionHistory[dummyName]
    
    if not history or #history == 0 then
        -- No history available, use current position
        if dummy.PrimaryPart then
            return dummy.PrimaryPart.Position, dummy
        end
        return nil, nil
    end
    
    -- Find the closest recorded position to the target position
    local closestEntry = history[1]
    local closestDistance = (history[1].position - targetPosition).Magnitude
    
    for _, entry in ipairs(history) do
        local distance = (entry.position - targetPosition).Magnitude
        if distance < closestDistance then
            closestDistance = distance
            closestEntry = entry
        end
    end
    
    return closestEntry.position, closestEntry.dummy
end

-- Public function to equip a weapon for a player (handles both server logic and client notification)
function weapons.equipPlayerWeapon(player, weaponType)
    -- Validate weapon type
    if not WeaponConstants[weaponType] then
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
    
    -- Start bullet update loop
    RunService.Heartbeat:Connect(updateBullets)
    
    -- Start position recording for lag compensation
    RunService.Heartbeat:Connect(function()
        for _, player in ipairs(Players:GetPlayers()) do
            recordPlayerPosition(player)
        end
        
        -- Record dummy positions
        local allDummies = DummySystem.getAllDummies()
        for _, dummy in ipairs(allDummies) do
            recordDummyPosition(dummy)
        end
    end)
    
    -- Handle players joining
    Players.PlayerAdded:Connect(function(player)
        player.CharacterAdded:Connect(function(character)
            -- Character loaded - position recording will happen automatically in heartbeat
        end)
    end)
    
    -- Handle players leaving - clean up position history
    Players.PlayerRemoving:Connect(function(player)
        -- Clean up position history
        playerPositionHistory[player.UserId] = nil
        
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
    ShootEvent.OnServerEvent:Connect(function(shooter, hits)
        -- Get the player's selected weapon
        local weaponType = playerWeapons[shooter.UserId]
        local weaponConstants = WeaponConstants[weaponType]
        local weaponModule = getWeaponModule(weaponType)

        -- Use hit information for lag compensation verification
        local serverTime = TimeSync.getServerTimeMillis()
        
        for _, hit in ipairs(hits) do
            local hitPart = hit.hitPart
            local hitPosition = hit.hitPosition

            if not hitPart then
                print("SERVER: Hit part is nil")
                continue
            end
            
            print("SERVER: Client claims to have hit:", hitPart.Name, "at:", hitPosition)
            
            -- Check if the hit part belongs to a character (player or dummy)
            local hitCharacter = hitPart.Parent
            if hitCharacter and hitCharacter:FindFirstChildOfClass("Humanoid") then
                print("SERVER: Hit character:", hitCharacter.Name)
                
                -- Verify the hit by checking historical positions
                local isValidHit = false
                local damage = weaponConstants.DAMAGE_PER_BULLET or weaponConstants.DAMAGE
                
                -- Check if it's a player
                local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
                if hitPlayer then
                    print("SERVER: Verifying hit on player:", hitPlayer.Name)
                    local historicalPosition, historicalCharacter = getPlayerPositionClosestTo(hitPlayer, hitPosition)
                    
                    if historicalPosition then
                        local distance = (historicalPosition - hitPosition).Magnitude
                        print("SERVER: Historical position distance:", distance)
                        
                        -- Allow some tolerance for network/movement differences
                        if distance < 10 then -- 10 studs tolerance
                            isValidHit = true
                            print("SERVER: Valid hit on player confirmed")
                        else
                            print("SERVER: Hit rejected - too far from historical position")
                        end
                    end
                -- Check if it's a dummy
                elseif hitCharacter.Name:find("TestDummy") then
                    print("SERVER: Verifying hit on dummy:", hitCharacter.Name)
                    local historicalPosition, historicalDummy = getDummyPositionClosestTo(hitCharacter, hitPosition)
                    
                    if historicalPosition then
                        local distance = (historicalPosition - hitPosition).Magnitude
                        print("SERVER: Historical position distance:", distance)
                        
                        -- Allow some tolerance for network/movement differences
                        if distance < 10 then -- 10 studs tolerance
                            isValidHit = true
                            print("SERVER: Valid hit on dummy confirmed")
                        else
                            print("SERVER: Hit rejected - too far from historical position")
                        end
                    end
                end
                
                -- Apply damage if hit is valid
                if isValidHit then
                    local humanoid = hitCharacter:FindFirstChildOfClass("Humanoid")
                    if humanoid then
                        humanoid:TakeDamage(damage)
                        if shooter.Team.Name ~= "Waiting" then
                            Leaderboard.addToStat(shooter, "Damage", 1)
                        end
                        print("SERVER: Damage applied to", hitCharacter.Name)
                    end
                else
                    print("SERVER: Hit rejected - failed verification")
                end
            else
                print("SERVER: Hit part is not a character")
            end
        end

        local createBulletData = {}

        for _, hit in ipairs(hits) do
            local bullet = {
                id = hit.id,
                startPosition = hit.startPosition,
                direction = hit.direction,
                hitPosition = hit.hitPosition,
            }
            table.insert(createBulletData, bullet)
        end

        print("createBulletData", createBulletData)

        for _, player in ipairs(Players:GetPlayers()) do
            if player.UserId ~= shooter.UserId then
                print("player", player.UserId)
                ShootEvent:FireClient(player, {
                    action = "create",
                    weaponType = weaponType,
                    bullets = createBulletData
                })
            end
        end
    end)
end

return weapons