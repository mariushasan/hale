local TimeSync = require(game.ReplicatedStorage.shared.TimeSync)
local Weapons = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons)
local Game = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game)
local Shop = require(game.StarterPlayer.StarterPlayerScripts.Client.features.shop)
local Inventory = require(game.StarterPlayer.StarterPlayerScripts.Client.features.inventory)
local UserInputService = game:GetService("UserInputService")
local WeaponSelector = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons.ui.WeaponSelector)
local LogViewer = require(game.StarterPlayer.StarterPlayerScripts.Client.LogViewer)
-- Initialize time synchronization first
Shop.init()
TimeSync.init()
Weapons.init()
Game.init()
Inventory.init()
LogViewer.init()

-- Toggle weapon selector with 'B' key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.B then
        WeaponSelector.toggle()
    elseif not gameProcessed and input.KeyCode == Enum.KeyCode.P then
        Shop.toggle()
    end
end)