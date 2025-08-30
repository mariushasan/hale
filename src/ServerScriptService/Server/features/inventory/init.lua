local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local events = ReplicatedStorage:WaitForChild("events")

-- DataStore for player inventories
local InventoryDataStore = DataStoreService:GetDataStore("PlayerInventory")

-- Utility function to get table keys
local function getTableKeys(tbl)
    local keys = {}
    for key, _ in pairs(tbl) do
        table.insert(keys, tostring(key))
    end
    return keys
end

-- Check if DataStores are available (for Studio development)
local dataStoresEnabled = true
if RunService:IsStudio() then
    -- Test DataStore availability
    local success = pcall(function()
        DataStoreService:GetDataStore("TestStore"):GetAsync("test")
    end)
    dataStoresEnabled = success
end

-- Remote Events
local InventoryEvent = events:WaitForChild("InventoryEvent")
local PurchaseEvent = events:WaitForChild("PurchaseEvent")

-- Import weapon constants for pricing
local WeaponConstants = require(ReplicatedStorage.features.weapons)

local Inventory = {}

-- Player data cache
local playerData = {}

-- Default player data structure
local function createDefaultPlayerData()
    return {
        coins = 1000, -- Starting coins
        ownedItems = {
            -- Default items that players start with (if any)
        },
        purchaseHistory = {}
    }
end

-- Get player data
local function getPlayerData(player)
    return playerData[player.UserId]
end

-- Load player data from DataStore
local function loadPlayerData(player)    
    if not dataStoresEnabled then
        -- Use default data in Studio without DataStore access
        playerData[player.UserId] = createDefaultPlayerData()
        
        -- Send initial inventory to client
        InventoryEvent:FireClient(player, {
            action = "sync",
            data = playerData[player.UserId]
        })
        return
    end
    
    local success, data = pcall(function()
        return InventoryDataStore:GetAsync(player.UserId)
    end)
    
    if success and data then
        playerData[player.UserId] = data
        local itemCount = 0
        for _ in pairs(data.ownedItems or {}) do
            itemCount = itemCount + 1
        end
    else
        -- Create new player data
        playerData[player.UserId] = createDefaultPlayerData()
    end
    
    -- Send initial inventory to client
    InventoryEvent:FireClient(player, {
        action = "sync",
        data = playerData[player.UserId]
    })
end

-- Save player data to DataStore
local function savePlayerData(player)
    if not playerData[player.UserId] then return end
    
    if not dataStoresEnabled then
        return
    end
    
    local success, error = pcall(function()
        InventoryDataStore:SetAsync(player.UserId, playerData[player.UserId])
    end)
end

-- Add coins to player
local function addCoins(player, amount)
    local data = getPlayerData(player)
    if data then
        data.coins = data.coins + amount
        
        -- Notify client of coin update
        InventoryEvent:FireClient(player, {
            action = "coinsUpdated",
            coins = data.coins
        })
        
        return true
    end
    return false
end

-- Remove coins from player
local function removeCoins(player, amount)
    local data = getPlayerData(player)
    if data and data.coins >= amount then
        data.coins = data.coins - amount
        
        -- Notify client of coin update
        InventoryEvent:FireClient(player, {
            action = "coinsUpdated",
            coins = data.coins
        })
        
        return true
    end
    return false
end

-- Check if player owns an item
local function playerOwnsItem(player, itemId)
    local data = getPlayerData(player)
    if data then
        return data.ownedItems[itemId] ~= nil
    end
    return false
end

-- Add item to player inventory
local function addItemToInventory(player, itemId)
    local data = getPlayerData(player)
    if data then
        data.ownedItems[itemId] = {
            purchaseTime = os.time(),
            itemId = itemId
        }
        
        -- Notify client of inventory update
        InventoryEvent:FireClient(player, {
            action = "itemAdded",
            itemId = itemId,
            ownedItems = data.ownedItems
        })
        
        return true
    end
    return false
end

-- Remove item from player inventory
local function removeItemFromInventory(player, itemId)
    local data = getPlayerData(player)
    if data and data.ownedItems[itemId] then
        data.ownedItems[itemId] = nil
        
        -- Notify client of inventory update
        InventoryEvent:FireClient(player, {
            action = "itemRemoved",
            itemId = itemId,
            ownedItems = data.ownedItems
        })
        
        return true
    end
    return false
end

-- Handle purchase requests
local function handlePurchase(player, itemId)
    
    local item = WeaponConstants[itemId]
    if not item then
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "Item not found"
        })
        return
    end
    
    local data = getPlayerData(player)
    if not data then
        
        -- Try to reload player data
        loadPlayerData(player)
        
        -- Try again after reload
        data = getPlayerData(player)
        if not data then
            PurchaseEvent:FireClient(player, {
                success = false,
                error = "Player data not loaded"
            })
            return
        end
    end
        
    -- Check if player already owns the item
    if playerOwnsItem(player, itemId) then
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "You already own this item"
        })
        return
    end
    
    -- Check if player has enough coins
    if data.coins < item.PRICE then
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "Not enough coins"
        })
        return
    end
    
    -- Process purchase
    if removeCoins(player, item.PRICE) and addItemToInventory(player, itemId) then
        -- Add to purchase history
        table.insert(data.purchaseHistory, {
            itemId = itemId,
            price = item.PRICE,
            purchaseTime = os.time()
        })
                
        PurchaseEvent:FireClient(player, {
            success = true,
            itemId = itemId,
            itemName = item.DISPLAY_NAME,
            coinsRemaining = data.coins
        })
        
        -- Save data after purchase
        savePlayerData(player)
    else
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "Purchase failed"
        })
    end
end

-- Handle inventory requests
local function handleInventoryRequest(player, requestData)
    local action = requestData.action
    
    if action == "getInventory" then
        local data = getPlayerData(player)
        if data then
            InventoryEvent:FireClient(player, {
                action = "sync",
                data = data
            })
        end
    elseif action == "getCoins" then
        local data = getPlayerData(player)
        if data then
            InventoryEvent:FireClient(player, {
                action = "coinsUpdated",
                coins = data.coins
            })
        end
    elseif action == "removeItem" then
        local itemId = requestData.itemId
        if itemId then
            if removeItemFromInventory(player, itemId) then
                -- Save data after removal
                savePlayerData(player)
                
                InventoryEvent:FireClient(player, {
                    action = "itemRemovalSuccess",
                    itemId = itemId
                })
            else
                InventoryEvent:FireClient(player, {
                    action = "itemRemovalFailed",
                    itemId = itemId,
                    error = "Item not found or not owned"
                })
            end
        end
    end
end

-- Public functions
function Inventory.init()
    
    -- Handle players who are already in the game
    for _, player in pairs(Players:GetPlayers()) do
        loadPlayerData(player)
    end
    
    -- Handle player joining
    Players.PlayerAdded:Connect(function(player)
        loadPlayerData(player)
        
        -- Add debug chat commands for development
        player.Chatted:Connect(function(message)
            local args = string.split(message, " ")
            local command = args[1]:lower()
            
            if command == "/removeitem" and args[2] then
                local itemId = args[2]
                if removeItemFromInventory(player, itemId) then
                    savePlayerData(player)
                end
            elseif command == "/addcoins" and args[2] then
                local amount = tonumber(args[2])
                if amount and amount > 0 then
                    addCoins(player, amount)
                    savePlayerData(player)
                end
            elseif command == "/inventory" then
                local data = getPlayerData(player)
            end
        end)
    end)
    
    -- Handle player leaving (save data)
    Players.PlayerRemoving:Connect(function(player)
        savePlayerData(player)
        playerData[player.UserId] = nil
    end)
    
    -- Handle purchase requests
    PurchaseEvent.OnServerEvent:Connect(function(player, itemId)
        handlePurchase(player, itemId)
    end)
    
    -- Handle inventory requests
    InventoryEvent.OnServerEvent:Connect(function(player, requestData)
        handleInventoryRequest(player, requestData)
    end)
    
    -- Save all player data periodically (every 5 minutes)
    spawn(function()
        while true do
            wait(300) -- 5 minutes
            for userId, data in pairs(playerData) do
                local player = Players:GetPlayerByUserId(userId)
                if player then
                    savePlayerData(player)
                end
            end
        end
    end)
end

function Inventory.playerOwnsItem(player, itemId)
    return playerOwnsItem(player, itemId)
end

function Inventory.addCoins(player, amount)
    return addCoins(player, amount)
end

function Inventory.removeCoins(player, amount)
    return removeCoins(player, amount)
end

function Inventory.removeItem(player, itemId)
    if removeItemFromInventory(player, itemId) then
        savePlayerData(player)
        return true
    end
    return false
end

return Inventory 