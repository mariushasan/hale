local Players = game:GetService("Players")

local Weapons = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons)
local Game = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game)
local Shop = require(game.StarterPlayer.StarterPlayerScripts.Client.features.shop)
local Inventory = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.inventory)
local LogViewer = require(game.StarterPlayer.StarterPlayerScripts.Client.LogViewer)
local Spectator = require(game.StarterPlayer.StarterPlayerScripts.Client.features.spectator)
local MapVoting = require(game.StarterPlayer.StarterPlayerScripts.Client.features.mapvoting)
local Loadout = require(game.StarterPlayer.StarterPlayerScripts.Client.features.loadout)

local initial = false

local player = Players.LocalPlayer
player.CharacterAdded:Connect(function(character)
    if initial then return end
    initial = true
    player.CameraMode = Enum.CameraMode.LockFirstPerson
    Shop.init()
    Game.init()
    Inventory.init()
    LogViewer.init()
    Spectator.init()
    MapVoting.init()
    Weapons.init()
    Loadout.init()
end)