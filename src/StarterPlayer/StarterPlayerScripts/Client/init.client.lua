local Weapons = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons)
local Game = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game)
local UserInputService = game:GetService("UserInputService")
local WeaponSelector = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons.ui.WeaponSelector)

Weapons.initialize()
Game.initialize()

-- Toggle weapon selector with 'B' key
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not gameProcessed and input.KeyCode == Enum.KeyCode.B then
        WeaponSelector.toggle()
    end
end)