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
    
    if not dataStoresEnabled then
        warn("⚠️  DataStores not available in Studio! Enable API access in Game Settings > Security > Allow Studio Access to API Services")
        warn("⚠️  Player data will not persist between sessions in Studio")
    else
        print("✅ DataStores are available in Studio")
    end
end

-- Remote Events
local InventoryEvent = events:WaitForChild("InventoryEvent")
local PurchaseEvent = events:WaitForChild("PurchaseEvent")

-- Import weapon constants for pricing
local WeaponConstants = require(ReplicatedStorage.features.weapons)

local Inventory = {}

-- Player data cache
local playerData = {}

-- Available items for purchase
local SHOP_ITEMS = {
    shotgun = {
        id = "shotgun",
        price = WeaponConstants.shotgun.PRICE,
        name = WeaponConstants.shotgun.DISPLAY_NAME,
        category = "weapon"
    },
    assaultrifle = {
        id = "assaultrifle",
        price = WeaponConstants.assaultrifle.PRICE,
        name = WeaponConstants.assaultrifle.DISPLAY_NAME,
        category = "weapon"
    },
    -- Add more items here as they become available
}

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
    print("🔄 Loading inventory data for", player.Name, "UserId:", player.UserId)
    
    if not dataStoresEnabled then
        -- Use default data in Studio without DataStore access
        playerData[player.UserId] = createDefaultPlayerData()
        print("📝 Created temporary inventory data for", player.Name, "(DataStores disabled)")
        print("💰 Starting coins:", playerData[player.UserId].coins)
        
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
        print("📦 Loaded existing inventory data for", player.Name)
        local itemCount = 0
        for _ in pairs(data.ownedItems or {}) do
            itemCount = itemCount + 1
        end
        print("💰 Loaded coins:", data.coins, "Items:", itemCount)
    else
        -- Create new player data
        playerData[player.UserId] = createDefaultPlayerData()
        print("🆕 Created new inventory data for", player.Name)
        print("💰 Starting coins:", playerData[player.UserId].coins)
    end
    
    -- Verify data was set
    local verifyData = getPlayerData(player)
    if verifyData then
        print("✅ Player data successfully loaded for", player.Name, "- Coins:", verifyData.coins)
    else
        warn("❌ Failed to set player data for", player.Name)
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
        print("💾 Skipping save for", player.Name, "(DataStores disabled)")
        return
    end
    
    local success, error = pcall(function()
        InventoryDataStore:SetAsync(player.UserId, playerData[player.UserId])
    end)
    
    if success then
        print("💾 Saved inventory data for", player.Name)
    else
        warn("❌ Failed to save inventory data for", player.Name, ":", error)
    end
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
        
        print("🗑️ Removed item", itemId, "from", player.Name, "'s inventory")
        return true
    end
    return false
end

-- Debug function to check player data status
local function debugPlayerData(player)
    print("🔍 Debug - Player data for", player.Name, ":")
    print("   UserId:", player.UserId)
    print("   Data exists:", playerData[player.UserId] ~= nil)
    if playerData[player.UserId] then
        print("   Coins:", playerData[player.UserId].coins)
        local itemCount = 0
        for _ in pairs(playerData[player.UserId].ownedItems or {}) do
            itemCount = itemCount + 1
        end
        print("   Items count:", itemCount)
    end
end

-- Handle purchase requests
local function handlePurchase(player, itemId)
    print("🛒 Purchase request from", player.Name, "for item:", itemId)
    
    -- Debug player data status
    debugPlayerData(player)
    
    local item = SHOP_ITEMS[itemId]
    if not item then
        print("❌ Item not found:", itemId)
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "Item not found"
        })
        return
    end
    
    local data = getPlayerData(player)
    if not data then
        print("❌ Player data not loaded for", player.Name)
        print("🔍 Available player data keys:", table.concat(getTableKeys(playerData), ", "))
        
        -- Try to reload player data
        print("🔄 Attempting to reload player data...")
        loadPlayerData(player)
        
        -- Try again after reload
        data = getPlayerData(player)
        if not data then
            print("❌ Still no player data after reload attempt")
            PurchaseEvent:FireClient(player, {
                success = false,
                error = "Player data not loaded"
            })
            return
        else
            print("✅ Player data loaded after retry")
        end
    end
    
    print("💰 Player", player.Name, "has", data.coins, "coins, item costs", item.price)
    
    -- Check if player already owns the item
    if playerOwnsItem(player, itemId) then
        print("❌ Player", player.Name, "already owns", itemId)
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "You already own this item"
        })
        return
    end
    
    -- Check if player has enough coins
    if data.coins < item.price then
        print("❌ Player", player.Name, "has insufficient coins:", data.coins, "< required:", item.price)
        PurchaseEvent:FireClient(player, {
            success = false,
            error = "Not enough coins"
        })
        return
    end
    
    -- Process purchase
    if removeCoins(player, item.price) and addItemToInventory(player, itemId) then
        -- Add to purchase history
        table.insert(data.purchaseHistory, {
            itemId = itemId,
            price = item.price,
            purchaseTime = os.time()
        })
        
        print("✅ Purchase successful!", player.Name, "bought", item.name, "for", item.price, "coins. Remaining:", data.coins)
        
        PurchaseEvent:FireClient(player, {
            success = true,
            itemId = itemId,
            itemName = item.name,
            coinsRemaining = data.coins
        })
        
        -- Save data after purchase
        savePlayerData(player)
    else
        print("❌ Purchase processing failed for", player.Name)
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
    print("Inventory system initialized")
    
    -- Handle players who are already in the game
    for _, player in pairs(Players:GetPlayers()) do
        print("🔄 Loading data for existing player:", player.Name)
        loadPlayerData(player)
    end
    
    -- Handle player joining
    Players.PlayerAdded:Connect(function(player)
        print("👋 New player joined:", player.Name)
        loadPlayerData(player)
        
        -- Add debug chat commands for development
        player.Chatted:Connect(function(message)
            local args = string.split(message, " ")
            local command = args[1]:lower()
            
            if command == "/removeitem" and args[2] then
                local itemId = args[2]
                if removeItemFromInventory(player, itemId) then
                    savePlayerData(player)
                    print("🗑️ Debug: Removed", itemId, "from", player.Name)
                else
                    print("❌ Debug: Failed to remove", itemId, "from", player.Name)
                end
            elseif command == "/addcoins" and args[2] then
                local amount = tonumber(args[2])
                if amount and amount > 0 then
                    addCoins(player, amount)
                    savePlayerData(player)
                    print("💰 Debug: Added", amount, "coins to", player.Name)
                end
            elseif command == "/inventory" then
                local data = getPlayerData(player)
                if data then
                    print("📦 Debug inventory for", player.Name, ":")
                    print("   Coins:", data.coins)
                    print("   Items:", table.concat(getTableKeys(data.ownedItems), ", "))
                end
            end
        end)
    end)
    
    -- Handle player leaving (save data)
    Players.PlayerRemoving:Connect(function(player)
        print("👋 Player leaving:", player.Name)
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
            print("💾 Periodic save - saving data for", #Players:GetPlayers(), "players")
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