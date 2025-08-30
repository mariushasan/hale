local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local Players = game:GetService("Players")

-- Remote Events
local InventoryEvent = events:WaitForChild("InventoryEvent")
local PurchaseEvent = events:WaitForChild("PurchaseEvent")

local Inventory = {}

-- Local inventory data cache
local inventoryData = {
    coins = 0,
    ownedItems = {},
    purchaseHistory = {}
}

-- Event connections for UI updates
local coinUpdateCallbacks = {}
local inventoryUpdateCallbacks = {}
local purchaseCallbacks = {}

-- Handle inventory updates from server
local function handleInventoryUpdate(data)
    local action = data.action
    
    if action == "sync" then
        -- Full inventory sync
        inventoryData = data.data
        
        -- Notify UI of updates
        for _, callback in pairs(coinUpdateCallbacks) do
            callback(inventoryData.coins)
        end
        for _, callback in pairs(inventoryUpdateCallbacks) do
            callback(inventoryData.ownedItems)
        end
        
    elseif action == "coinsUpdated" then
        -- Coins updated
        inventoryData.coins = data.coins
        
        -- Notify UI
        for _, callback in pairs(coinUpdateCallbacks) do
            callback(inventoryData.coins)
        end
        
    elseif action == "itemAdded" then
        -- Item added to inventory
        inventoryData.ownedItems[data.itemId] = data.ownedItems[data.itemId]
        
        -- Notify UI
        for _, callback in pairs(inventoryUpdateCallbacks) do
            callback(inventoryData.ownedItems)
        end
        
    elseif action == "itemRemoved" then
        -- Item removed from inventory
        inventoryData.ownedItems = data.ownedItems
        
        -- Notify UI
        for _, callback in pairs(inventoryUpdateCallbacks) do
            callback(inventoryData.ownedItems)
        end
        
    elseif action == "itemRemovalSuccess" then
        print("✅ Item removal successful:", data.itemId)
        
    elseif action == "itemRemovalFailed" then
        warn("❌ Item removal failed:", data.itemId, "-", data.error)
    end
end

-- Handle purchase responses from server
local function handlePurchaseResponse(response)
    
    -- Notify purchase callbacks
    for _, callback in pairs(purchaseCallbacks) do
        callback(response)
    end
end

-- Public functions
function Inventory.init()    
    -- Connect to server events
    InventoryEvent.OnClientEvent:Connect(handleInventoryUpdate)
    PurchaseEvent.OnClientEvent:Connect(handlePurchaseResponse)
    
    -- Request initial inventory sync
    InventoryEvent:FireServer({
        action = "getInventory"
    })
end

-- Get current coin balance
function Inventory.getCoins()
    return inventoryData.coins
end

-- Get owned items
function Inventory.getOwnedItems()
    return inventoryData.ownedItems
end

-- Check if player owns an item
function Inventory.ownsItem(itemId)
    return inventoryData.ownedItems[itemId] ~= nil
end

-- Get full inventory data
function Inventory.getInventoryData()
    return inventoryData
end

-- Purchase an item
function Inventory.purchaseItem(itemId)
    if not inventoryData then
        warn("Inventory not initialized")
        return
    end
    
    PurchaseEvent:FireServer(itemId)
end

-- Request coin balance update
function Inventory.requestCoinUpdate()
    InventoryEvent:FireServer({
        action = "getCoins"
    })
end

-- Register callback for coin updates
function Inventory.onCoinsUpdated(callback)
    table.insert(coinUpdateCallbacks, callback)
    
    -- Call immediately with current value
    callback(inventoryData.coins)
    
    -- Return function to unregister callback
    return function()
        for i, cb in ipairs(coinUpdateCallbacks) do
            if cb == callback then
                table.remove(coinUpdateCallbacks, i)
                break
            end
        end
    end
end

-- Register callback for inventory updates
function Inventory.onInventoryUpdated(callback)
    table.insert(inventoryUpdateCallbacks, callback)
    
    -- Call immediately with current value
    callback(inventoryData.ownedItems)
    
    -- Return function to unregister callback
    return function()
        for i, cb in ipairs(inventoryUpdateCallbacks) do
            if cb == callback then
                table.remove(inventoryUpdateCallbacks, i)
                break
            end
        end
    end
end

-- Register callback for purchase responses
function Inventory.onPurchaseResponse(callback)
    table.insert(purchaseCallbacks, callback)
    
    -- Return function to unregister callback
    return function()
        for i, cb in ipairs(purchaseCallbacks) do
            if cb == callback then
                table.remove(purchaseCallbacks, i)
                break
            end
        end
    end
end

function Inventory.removeItem(itemId)
    if not inventoryData then
        warn("Inventory not initialized")
        return
    end
    
    InventoryEvent:FireServer({
        action = "removeItem",
        itemId = itemId
    })
end

return Inventory 