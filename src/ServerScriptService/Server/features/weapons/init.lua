local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local Leaderboard = require(game.ServerScriptService.Server.shared.Leaderboard)
local Teams = require(game.ServerScriptService.Server.features.game.Teams)
local events = ReplicatedStorage:WaitForChild("events")

-- Import constants
local WeaponConstants = require(ReplicatedStorage.features.weapons)

debugLog = require(game.ServerScriptService.Server.shared.DebugLog)
-- Import server-side weapon modules
local BossAttackModule = require(script.bossattack)
local ShotgunModule = require(script.shotgun)
local AssaultRifleModule = require(script.assaultrifle)

-- Collision groups for lag compensation
local LAG_PARTS_GROUP = "LagParts"
local PLAYER_CHARACTERS_GROUP = "PlayerCharacters"
local VISUAL_ONLY_GROUP = "VisualOnly"

-- Initialize collision groups
local function initializeCollisionGroups()
    -- Create collision groups
    PhysicsService:RegisterCollisionGroup(LAG_PARTS_GROUP)
    PhysicsService:RegisterCollisionGroup(PLAYER_CHARACTERS_GROUP)
    PhysicsService:RegisterCollisionGroup(VISUAL_ONLY_GROUP)
    PhysicsService:CollisionGroupSetCollidable(LAG_PARTS_GROUP, PLAYER_CHARACTERS_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(VISUAL_ONLY_GROUP, PLAYER_CHARACTERS_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(VISUAL_ONLY_GROUP, LAG_PARTS_GROUP, false)
    PhysicsService:CollisionGroupSetCollidable(VISUAL_ONLY_GROUP, "Default", false)
    PhysicsService:CollisionGroupSetCollidable(VISUAL_ONLY_GROUP, "StudioSelectable", false)
    PhysicsService:CollisionGroupSetCollidable(VISUAL_ONLY_GROUP, VISUAL_ONLY_GROUP, false)
end

-- Set collision group for player character
local function setPlayerCharacterCollisionGroup(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = PLAYER_CHARACTERS_GROUP
        end
    end
end

-- Get server-side weapon module based on weapon type
local function getWeaponModule(weaponType)
    if weaponType == "bossattack" then
        return BossAttackModule
    elseif weaponType == "shotgun" then
        return ShotgunModule
    elseif weaponType == "assaultrifle" then
        return AssaultRifleModule
    else
        return nil -- No server-side logic needed
    end
end

-- Remote events
local ShootEvent = events:WaitForChild("ShootEvent")
local WeaponSelectionEvent = events:WaitForChild("WeaponSelectionEvent")

local DummySystem = require(script.DummySystem)
local weapons = {}

-- Store player weapons
local playerWeapons = {}

-- Lag compensation system
local playerPositionHistory = {} -- [timestamp] = {[userId] = {position = Vector3, character = Character}, ...}
local dummyPositionHistory = {} -- [timestamp] = {[dummyName] = {position = Vector3, dummy = Dummy}, ...}
local MAX_HISTORY_TIME_MS = 2000 -- Keep 2 seconds of history - enough for network latency

-- Lag parts caching system for world state rewind
local lagParts = {} -- [userId] = lagPart
local dummyLagParts = {} -- [dummyName] = lagPart

-- Cache the loaded R6 model to avoid repeated InsertService calls
local cachedR6Model = nil

-- Load and cache the R6 model
local function getCachedR6Model()
    if cachedR6Model then
        return cachedR6Model
    end
    
    local InsertService = game:GetService("InsertService")
    
    local success, lagModel = pcall(function()
        return InsertService:LoadAsset(140642768696536)
    end)
    
    if not success or not lagModel then
        warn("Failed to load R6 model for lag compensation")
        return nil
    end
    
    -- Get the actual model from the loaded asset
    local r6Model = lagModel:GetChildren()[1]
    if not r6Model or not r6Model:IsA("Model") then
        warn("Invalid R6 model structure")
        lagModel:Destroy()
        return nil
    end
    
    -- Cache the model for reuse
    cachedR6Model = r6Model
    
    return cachedR6Model
end

-- Create a lag model for a dummy by cloning its parts
local function createDummyLagPart(dummy)
    local lagModel = Instance.new("Model")
    lagModel.Name = "DummyLagCharacter"
    lagModel.Parent = workspace

    -- Clone each basepart from dummy
    for _, part in ipairs(dummy:GetDescendants()) do
        if part:IsA("BasePart") then
            local clone = part:Clone()
            clone:ClearAllChildren() -- remove joints/attachments to detach from original
            clone.Anchored = true
            clone.CanCollide = false
            clone.Material = Enum.Material.Neon
            clone.Color = Color3.fromRGB(255, 0, 0)
            clone.Transparency = 1
            clone.Parent = lagModel
            clone.CollisionGroup = LAG_PARTS_GROUP
            -- Set primary part to HumanoidRootPart/Torso clone for positioning
            if (part.Name == "HumanoidRootPart" or part.Name == "Torso" or part.Name == "LowerTorso") and not lagModel.PrimaryPart then
                lagModel.PrimaryPart = clone
            end
        end
    end

    return lagModel
end

-- Create a lag part for a player using pre-made R6 model
local function createLagPart(player)
    -- Get the cached R6 model
    local r6Model = getCachedR6Model()

    if not r6Model then
        return nil
    end
    
    -- Clone the model and set it up for lag compensation
    local lagCharacter = r6Model:Clone()
    lagCharacter.Name = "LagCharacter"
    lagCharacter.Parent = workspace
    
    -- Configure all parts for lag compensation
    for _, part in ipairs(lagCharacter:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = true
            part.CanCollide = false
            part.Material = Enum.Material.Neon
            part.Color = Color3.fromRGB(255, 0, 0) -- Red for debugging
            part.Transparency = 1
            part.CollisionGroup = LAG_PARTS_GROUP
        end
    end
    
    -- Set primary part (use Head first to match real characters, then fallbacks)
    local rootPart = lagCharacter:FindFirstChild("Head")
    
    if rootPart then
        lagCharacter.PrimaryPart = rootPart
    end
    
    return lagCharacter
end

-- Get lag part for a player (should already exist)
local function getLagPart(player)
    local userId = player.UserId
    return lagParts[userId]
end

-- Create lag part for a player when they connect
local function createLagPartForPlayer(player)
    local userId = player.UserId
    
    if not lagParts[userId] then
        lagParts[userId] = createLagPart(player)

        if lagParts[userId] then
            -- Set the name with proper userId for the model
            lagParts[userId].Name = "LagPart_" .. tostring(userId)
            -- Keep it out of workspace until needed
            lagParts[userId].Parent = nil
        end
    end
end

-- Clean up lag part for a player
local function cleanupLagPart(userId)
    local lagModel = lagParts[userId]
    if lagModel then
        lagModel:Destroy()
        lagParts[userId] = nil
    end
end

-- Clean up dummy lag part
local function cleanupDummyLagPart(dummyName)
    local lagModel = dummyLagParts[dummyName]
    if lagModel then
        lagModel:Destroy()
        dummyLagParts[dummyName] = nil
    end
end

-- Record player position for lag compensation
local function recordPlayerPosition(player)
    if not player.Character or not player.Character.PrimaryPart then return end

    local userId = player.UserId
    local currentTime = DateTime.now().UnixTimestampMillis
    local primaryPart = player.Character.PrimaryPart
    local cframe = primaryPart.CFrame

    -- Initialize timestamp entry if it doesn't exist
    if not playerPositionHistory[currentTime] then
        playerPositionHistory[currentTime] = {}
    end

    -- Store player position at this timestamp
    playerPositionHistory[currentTime][userId] = {
        cframe = cframe,
        character = player.Character
    }

    -- Clean up old history
    local cutoffTime = currentTime - MAX_HISTORY_TIME_MS
    for timestamp, _ in pairs(playerPositionHistory) do
        if timestamp < cutoffTime then
            playerPositionHistory[timestamp] = nil
        end
    end
end

-- Record dummy position for lag compensation
local function recordDummyPosition(dummy)
    if not dummy or not dummy.PrimaryPart then return end
    
    local dummyName = dummy.Name
    local currentTime = DateTime.now().UnixTimestampMillis
    local primaryPart = dummy.PrimaryPart
    local cframe = primaryPart.CFrame
    
    -- Initialize timestamp entry if it doesn't exist
    if not dummyPositionHistory[currentTime] then
        dummyPositionHistory[currentTime] = {}
    end
    
    -- Store dummy position at this timestamp
    dummyPositionHistory[currentTime][dummyName] = {
        cframe = cframe,
        dummy = dummy
    }
    
    -- Clean up old history
    local cutoffTime = currentTime - MAX_HISTORY_TIME_MS
    for timestamp, _ in pairs(dummyPositionHistory) do
        if timestamp < cutoffTime then
            dummyPositionHistory[timestamp] = nil
        end
    end
end

-- Get or create a dummy lag part
local function getDummyLagPart(dummy)
    local dummyName = dummy.Name
    
    if not dummyLagParts[dummyName] then
        -- Create new dummy lag part using the dummy's actual part sizes
        dummyLagParts[dummyName] = createDummyLagPart(dummy)
        
        -- Set the name with proper dummy name
        dummyLagParts[dummyName].Name = "DummyLagPart_" .. dummyName
    end
    
    return dummyLagParts[dummyName]
end

-- Position lag parts at historical positions
local function rewindWorldState(targetTime)    
    -- Get player positions at the target timestamp
    local targetSnapshot = playerPositionHistory[targetTime]
    if targetSnapshot then
        for userId, playerData in pairs(targetSnapshot) do
            local player = Players:GetPlayerByUserId(userId)
            if player and player.Character then
                -- Position the lag character at historical position
                local lagModel = getLagPart(player)
                local storedCFrame = playerData.cframe
                
                -- Position the entire lag character based on the primary part
                if lagModel.PrimaryPart then
                    lagModel:SetPrimaryPartCFrame(storedCFrame)
                end
                
                lagModel.Parent = workspace
            end
        end
    end
    
    -- Get dummy positions at the target timestamp
    local dummySnapshot = dummyPositionHistory[targetTime]
    if dummySnapshot then
        for dummyName, dummyData in pairs(dummySnapshot) do
            local dummy = dummyData.dummy
            if dummy and dummy.Parent then
                -- Position the dummy lag character at historical position
                local lagModel = getDummyLagPart(dummy)
                local storedCFrame = dummyData.cframe
                
                -- Position the entire lag character based on the primary part
                if lagModel.PrimaryPart then
                    -- Directly set the primary part to the historical CFrame
                    lagModel:SetPrimaryPartCFrame(storedCFrame)
                end
                
                lagModel.Parent = workspace
            end
        end
    end
end

-- Public function to equip a weapon for a player (handles both server logic and client notification)
function weapons.equipPlayerWeapon(player, weaponType)
    -- Validate weapon type
    if not WeaponConstants[weaponType] then
        return
    end

    local previousWeapon = playerWeapons[player.UserId]

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

    -- Notify client about the weapon change
    WeaponSelectionEvent:FireClient(player, weaponType)
end

-- Handle weapon selection
function weapons.init()    
    -- Initialize collision groups
    initializeCollisionGroups()
    -- Initialize dummy system
    DummySystem.init()
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

    -- Handle players already in the game
    for _, player in ipairs(Players:GetPlayers()) do
        -- Set up collision groups for existing characters
        if player.Character then
            setPlayerCharacterCollisionGroup(player.Character)
        end
        
        player.CharacterAdded:Connect(function(character)
            setPlayerCharacterCollisionGroup(character)
        end)
        
        -- Create lag part for existing players
        createLagPartForPlayer(player)
    end

    -- Handle players joining
    Players.PlayerAdded:Connect(function(player)
        -- Set up collision groups for new characters
        player.CharacterAdded:Connect(function(character)
            setPlayerCharacterCollisionGroup(character)
        end)
        -- Create lag part for new players
        createLagPartForPlayer(player)
    end)

    -- Handle players leaving - clean up position history
    Players.PlayerRemoving:Connect(function(player)
        -- Clean up position history
        playerPositionHistory[player.UserId] = nil

        -- Clean up lag parts
        cleanupLagPart(player.UserId)

        -- Unequip weapon's server-side logic before cleanup
        local currentWeapon = playerWeapons[player.UserId]
        if currentWeapon then
            local serverModule = getWeaponModule(currentWeapon)
            if serverModule and serverModule.unequip then
                serverModule.unequip(player)
            end
        end

        -- Clean up other player data
        playerWeapons[player.UserId] = nil
    end)

    -- Handle weapon selection
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

        -- Store the selected weapon for this player
        playerWeapons[player.UserId] = weaponType

        -- Equip new weapon's server-side logic
        local newServerModule = getWeaponModule(weaponType)
        if newServerModule and newServerModule.equip then
            newServerModule.equip(player)
        end
    end)

    -- Handle shooting with bullet tracking
    ShootEvent.OnServerEvent:Connect(function(shooter, hits, direction, startPosition, seed)
        -- Get the player's selected weapon
        print("hits")
        print(hits)
        local weaponType = playerWeapons[shooter.UserId]
        local weaponConstants = WeaponConstants[weaponType]
        local weaponModule = getWeaponModule(weaponType)

        -- Find the historical time closest to the hit position
        local firstHitPart = nil
        for _, hit in ipairs(hits) do
            if hit.hitPart then
                firstHitPart = hit.hitPart
                break
            end
        end

        print("firstHitPart")
        print(firstHitPart)

        local targetTime = nil

        if firstHitPart then
            local bestMetric = math.huge
            -- Determine whether we hit a player or a dummy
            local hitCharacter = firstHitPart.Parent
            local firstHitCFrame = (hitCharacter.PrimaryPart and hitCharacter.PrimaryPart.CFrame) or firstHitPart.CFrame

            local hitPlayer = Players:GetPlayerFromCharacter(hitCharacter)
            local targetUserId = nil
            local targetDummyName = nil

            if hitPlayer then
                targetUserId = hitPlayer.UserId
            else
                targetDummyName = hitCharacter and hitCharacter.Name or nil
            end

            -- Search through player positions (only the specific player if identified)
            if targetUserId then
                for timestamp, snapshot in pairs(playerPositionHistory) do
                    local playerData = snapshot[targetUserId]
                    if playerData then
                        local metric = ((playerData.cframe.Position - firstHitCFrame.Position).Magnitude) + math.acos(math.clamp(playerData.cframe.LookVector:Dot(firstHitCFrame.LookVector), -1, 1))
                        if metric < bestMetric then
                            bestMetric = metric
                            targetTime = timestamp
                        end
                    end
                end
            end

            if targetDummyName then
                for timestamp, snapshot in pairs(dummyPositionHistory) do
                    local dummyData = snapshot[targetDummyName]
                    if dummyData then
                        local metric = ((dummyData.cframe.Position - firstHitCFrame.Position).Magnitude) + math.acos(math.clamp(dummyData.cframe.LookVector:Dot(firstHitCFrame.LookVector), -1, 1))
                        if metric < bestMetric then
                            bestMetric = metric
                            targetTime = timestamp
                        end
                    end
                end
            end
        end

        print("targetTime")
        print(targetTime)

        -- Rewind world state if we found a target time
        local createBulletData = {}

        if targetTime then
            rewindWorldState(targetTime)

            -- Perform server-side validation with rewinded world state
            local shooterLagPart = getLagPart(shooter)
            local hits = weaponModule.handleFireFromServer(shooterLagPart, direction, startPosition, seed, LAG_PARTS_GROUP)

            local damage = weaponConstants.DAMAGE_PER_BULLET or weaponConstants.DAMAGE

            for _, hit in ipairs(hits) do
                local hitPart = hit.hitPart
                local hitPosition = hit.hitPosition

                if not hitPart or not hitPosition then
                    continue
                end

                local hitPartParent = hitPart.Parent

                if hitPartParent.Name:match("LagPart_") then
                    local userId = tonumber(hitPartParent.Name:match("LagPart_(-?%d+)"))
                    
                    if userId then
                        local hitPlayer = Players:GetPlayerByUserId(userId)
                        if hitPlayer and hitPlayer.Character and hitPlayer.Character:FindFirstChildOfClass("Humanoid") then
                            local humanoid = hitPlayer.Character:FindFirstChildOfClass("Humanoid")
                            
                            humanoid.Health = humanoid.Health - damage
                            Leaderboard.addToStat(shooter, "Damage", damage)
                        end
                    end
                end

                table.insert(createBulletData,
                {
                    id = hit.id,
                    animationStartPosition = hit.animationStartPosition,
                    animationDirection = hit.animationDirection,
                    hitPosition = hit.hitPosition,
                })
            end
        end

        -- Send bullet to all players except the shooter
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= shooter then
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