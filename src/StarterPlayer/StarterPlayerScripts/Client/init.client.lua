local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local Weapons = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons)
local Game = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game)
local Shop = require(game.StarterPlayer.StarterPlayerScripts.Client.features.shop)
local Inventory = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.inventory)
local LogViewer = require(game.StarterPlayer.StarterPlayerScripts.Client.LogViewer)
local Spectator = require(game.StarterPlayer.StarterPlayerScripts.Client.features.spectator)
local MapVoting = require(game.StarterPlayer.StarterPlayerScripts.Client.features.mapvoting)
local Loadout = require(game.StarterPlayer.StarterPlayerScripts.Client.features.loadout)
local camera = workspace.Camera

local initial = false

local player = Players.LocalPlayer

player.CameraMode = Enum.CameraMode.Classic
camera.CameraType = Enum.CameraType.Scriptable

Shop.init()
Game.init()
Inventory.init()
Spectator.init()
MapVoting.init()
Weapons.init()
Loadout.init()

_G.Analytics.sendEvent(player.UserId, "game_started", nil)