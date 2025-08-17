local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local TimerRemoteEvent = events:WaitForChild("TimerRemoteEvent")
local OutcomeRemoteEvent = events:WaitForChild("OutcomeRemoteEvent")
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
    print("isMobile", UserInputService.TouchEnabled, UserInputService.MouseEnabled)
    
    -- Create the main menu icon with device-specific positioning
    local mainIcon = Instance.new("TextButton")
    mainIcon.Name = "MainMenuIcon"
    mainIcon.Size = UDim2.new(0, 60, 0, 60)
    
    if isMobile then
        -- Mobile: Top right corner
        mainIcon.Position = UDim2.new(1, -50, 0, 20)
        mainIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
    else
        -- Desktop: Bottom left corner
        mainIcon.Position = UDim2.new(0, 50, 1, -80)
        mainIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
    end
    
    mainIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    mainIcon.BorderSizePixel = 0
    mainIcon.Text = "⚙️" -- Settings/menu icon
    mainIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
    mainIcon.TextScaled = true
    mainIcon.Font = Enum.Font.GothamBold
    mainIcon.Parent = menuGui
    
    -- Make main icon round
    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0.5, 0)
    mainCorner.Parent = mainIcon
    
    -- Add border to main icon
    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 215, 0)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainIcon
    
    -- Create shop and loadout icons using their respective modules
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
    
    -- Position icons based on device type - all centered on same vertical line
    shopIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
    loadoutIcon.AnchorPoint = Vector2.new(0.5, 0) -- Center horizontally
    
    if isMobile then
        -- Mobile: Icons appear below main icon (downwards) - centered on same line
        shopIcon.Position = UDim2.new(1, -50, 0, 90) -- Below main icon, centered
        loadoutIcon.Position = UDim2.new(1, -50, 0, 150) -- Below shop icon, centered
    else
        -- Desktop: Icons appear above main icon (upwards) - centered on same line
        shopIcon.Position = UDim2.new(0, 50, 1, -150) -- Above main icon, centered
        loadoutIcon.Position = UDim2.new(0, 50, 1, -210) -- Above shop icon, centered
    end
    
    -- Initially hide the submenu icons
    shopIcon.Visible = false
    loadoutIcon.Visible = false
    
    -- Menu toggle functionality
    local function toggleMenu()
        menuOpen = not menuOpen
        
        if menuOpen then
            -- Show submenu icons with animation
            shopIcon.Visible = true
            loadoutIcon.Visible = true
            
            if isMobile then
                -- Mobile: Animate icons sliding down
                shopIcon:TweenPosition(UDim2.new(1, -50, 0, 90), "Out", "Quad", 0.2, true)
                loadoutIcon:TweenPosition(UDim2.new(1, -50, 0, 150), "Out", "Quad", 0.2, true)
            else
                -- Desktop: Animate icons sliding up
                shopIcon:TweenPosition(UDim2.new(0, 50, 1, -150), "Out", "Quad", 0.2, true)
                loadoutIcon:TweenPosition(UDim2.new(0, 50, 1, -210), "Out", "Quad", 0.2, true)
            end
        else
            -- Hide submenu icons with animation
            if isMobile then
                -- Mobile: Hide by sliding back to main icon position
                shopIcon:TweenPosition(UDim2.new(1, -50, 0, 20), "In", "Quad", 0.2, true, function()
                    shopIcon.Visible = false
                end)
                loadoutIcon:TweenPosition(UDim2.new(1, -50, 0, 20), "In", "Quad", 0.2, true, function()
                    loadoutIcon.Visible = false
                end)
            else
                -- Desktop: Hide by sliding back to main icon position
                shopIcon:TweenPosition(UDim2.new(0, 50, 1, -80), "In", "Quad", 0.2, true, function()
                    shopIcon.Visible = false
                end)
                loadoutIcon:TweenPosition(UDim2.new(0, 50, 1, -80), "In", "Quad", 0.2, true, function()
                    loadoutIcon.Visible = false
                end)
            end
        end
    end
    
    -- Connect main icon click
    mainIcon.MouseButton1Click:Connect(toggleMenu)
    
    -- Add hover effect to main icon (shop and loadout icons already have their own hover effects)
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
    
    return menuGui
end

function Game.init()
    TimerRemoteEvent.OnClientEvent:Connect(function(timeSeconds)
        print("TimerRemoteEvent received")
        GameUI.setTimer(timeSeconds)
    end)
	
    OutcomeRemoteEvent.OnClientEvent:Connect(function(outcome)
        GameUI.showGameEnd(outcome)
    end)

    GameUI.init()
    
    -- Create the menu system
    menuIconGui = createMenuSystem()
    
    print("Game menu system initialized")
end

return Game
