local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local TimerRemoteEvent = events:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = events:WaitForChild("OutcomeRemoteEvent")
local GameUIReadyEvent = events:WaitForChild("GameUIReadyEvent")
local GameUI = require(game.StarterPlayer.StarterPlayerScripts.Client.features.game.ui.GameUI)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

-- Import other modules
local Shop = require(game.StarterPlayer.StarterPlayerScripts.Client.features.shop)
local Loadout = require(game.StarterPlayer.StarterPlayerScripts.Client.features.loadout)

local Game = {}

-- Menu system variables
local menuIconGui = nil
local menuOpen = false

-- Create the main menu icon and submenu
local function createMenuSystem()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Remove existing menu if it exists
    local existingMenu = playerGui:FindFirstChild("GameMenuGui")
    if existingMenu then
        existingMenu:Destroy()
    end
    
    -- Create ScreenGui for the menu
    local menuGui = Instance.new("ScreenGui")
    menuGui.Name = "GameMenuGui"
    menuGui.ResetOnSpawn = false
    menuGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    menuGui.DisplayOrder = 50
    menuGui.Parent = playerGui
    menuGui.IgnoreGuiInset = true
    
    -- Determine if mobile
    local isMobile = UserInputService.TouchEnabled

    local mainIcon = nil
    
    if isMobile then
        -- Mobile: Create the main menu icon with clickable buttons
        mainIcon = Instance.new("TextButton")
        mainIcon.Name = "MainMenuIcon"
        mainIcon.Size = UDim2.new(0, 60, 0, 60)
        mainIcon.Position = UDim2.new(1, -50, 0, 20)
        mainIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
        mainIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        mainIcon.BorderSizePixel = 0
        mainIcon.Text = "⚙️" -- Settings/menu icon
        mainIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
        mainIcon.TextScaled = true
        mainIcon.Font = Enum.Font.GothamBold
        mainIcon.Parent = menuGui
    else
        -- Desktop: Create keybind info block
        local keybindBlock = Instance.new("Frame")
        keybindBlock.Name = "KeybindBlock"
        keybindBlock.Size = UDim2.new(0, 110, 0, 60)
        keybindBlock.Position = UDim2.new(0, 0, 1, -60) -- Top right corner like mobile
        keybindBlock.AnchorPoint = Vector2.new(0, 0)
        keybindBlock.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        keybindBlock.BorderSizePixel = 0
        keybindBlock.Parent = menuGui
        
        -- Shop keybind text
        local shopKeybind = Instance.new("TextLabel")
        shopKeybind.Name = "ShopKeybind"
        shopKeybind.Size = UDim2.new(1, -10, 0.4, 0)
        shopKeybind.Position = UDim2.new(0, 5, 0, 5)
        shopKeybind.BackgroundTransparency = 1
        shopKeybind.Text = "Shop: P"
        shopKeybind.TextColor3 = Color3.fromRGB(255, 255, 255)
        shopKeybind.TextScaled = true
        shopKeybind.Font = Enum.Font.Gotham
        shopKeybind.TextXAlignment = Enum.TextXAlignment.Left
        shopKeybind.Parent = keybindBlock
        
        -- Loadout keybind text
        local loadoutKeybind = Instance.new("TextLabel")
        loadoutKeybind.Name = "LoadoutKeybind"
        loadoutKeybind.Size = UDim2.new(1, -10, 0.4, 0)
        loadoutKeybind.Position = UDim2.new(0, 5, 0.5, 0)
        loadoutKeybind.BackgroundTransparency = 1
        loadoutKeybind.Text = "Loadout: L"
        loadoutKeybind.TextColor3 = Color3.fromRGB(255, 255, 255)
        loadoutKeybind.TextScaled = true
        loadoutKeybind.Font = Enum.Font.Gotham
        loadoutKeybind.TextXAlignment = Enum.TextXAlignment.Left
        loadoutKeybind.Parent = keybindBlock
        
        -- Return early for desktop - no need for menu system
        return menuGui
    end
    
         -- Make main icon round (mobile only)
     local mainCorner = Instance.new("UICorner")
     mainCorner.CornerRadius = UDim.new(0.5, 0)
     mainCorner.Parent = mainIcon
     
     -- Add border to main icon (mobile only)
     local mainStroke = Instance.new("UIStroke")
     mainStroke.Color = Color3.fromRGB(255, 215, 0)
     mainStroke.Thickness = 2
     mainStroke.Parent = mainIcon
     
     -- Create shop and loadout icons using their respective modules (mobile only)
     local shopIconGui = Shop.createShopIcon()
     local loadoutIconGui = Loadout.createLoadoutIcon()
     
     -- Get the actual icon buttons from the GUIs
     local shopIcon = shopIconGui.ShopIcon
     local loadoutIcon = loadoutIconGui.LoadoutIcon
     
     -- Reparent them to our menu GUI and position them appropriately
     shopIcon.Parent = menuGui
     loadoutIcon.Parent = menuGui
     
     -- Hide the original GUIs since we're using the icons in our menu
     shopIconGui:Destroy()
     loadoutIconGui:Destroy()
     
     -- Position icons for mobile - all centered on same vertical line
     shopIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
     loadoutIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
     shopIcon.Position = UDim2.new(1, -50, 0, 90) -- Below main icon, centered
     loadoutIcon.Position = UDim2.new(1, -50, 0, 150) -- Below shop icon, centered
     
     -- Initially hide the submenu icons
     shopIcon.Visible = false
     loadoutIcon.Visible = false
     
     -- Menu toggle functionality (mobile only)
     local function toggleMenu()
         menuOpen = not menuOpen
         
         if menuOpen then
             -- Show submenu icons with animation
             shopIcon.Visible = true
             loadoutIcon.Visible = true
             
             -- Mobile: Animate icons sliding down
             shopIcon:TweenPosition(UDim2.new(1, -50, 0, 90), "Out", "Quad", 0.2, true)
             loadoutIcon:TweenPosition(UDim2.new(1, -50, 0, 150), "Out", "Quad", 0.2, true)
         else
             -- Hide submenu icons with animation
             -- Mobile: Hide by sliding back to main icon position
             shopIcon:TweenPosition(UDim2.new(1, -50, 0, 20), "In", "Quad", 0.2, true, function()
                 shopIcon.Visible = false
             end)
             loadoutIcon:TweenPosition(UDim2.new(1, -50, 0, 20), "In", "Quad", 0.2, true, function()
                 loadoutIcon.Visible = false
             end)
         end
     end
     
     if mainIcon then
        -- Connect main icon click (mobile only)
        mainIcon.MouseButton1Click:Connect(toggleMenu)
        
        -- Add hover effect to main icon (mobile only)
        mainIcon.MouseEnter:Connect(function()
            local tween = TweenService:Create(mainIcon, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 65, 0, 65),
                BackgroundColor3 = Color3.fromRGB(55, 55, 60)
            })
            tween:Play()
            
            local strokeTween = TweenService:Create(mainStroke, TweenInfo.new(0.2), {
                Thickness = 3
            })
            strokeTween:Play()
        end)
        
        mainIcon.MouseLeave:Connect(function()
            local tween = TweenService:Create(mainIcon, TweenInfo.new(0.2), {
                Size = UDim2.new(0, 60, 0, 60),
                BackgroundColor3 = Color3.fromRGB(45, 45, 50)
            })
            tween:Play()
            
            local strokeTween = TweenService:Create(mainStroke, TweenInfo.new(0.2), {
                Thickness = 2
            })
            strokeTween:Play()
        end)
    end
     
    return menuGui
end

function Game.init()
    TimerRemoteEvent.OnClientEvent:Connect(function(timeSeconds)
        GameUI.setTimer(timeSeconds)
    end)
	
    OutcomeRemoteEvent.OnClientEvent:Connect(function(outcome, timeSeconds)
        GameUI.showGameEnd(outcome, timeSeconds)
    end)

    GameUI.init()

    GameUIReadyEvent:FireServer()
    
    -- Create the menu system
    menuIconGui = createMenuSystem()
end

return Game
