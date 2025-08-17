local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Import weapon constants for shop data
local WeaponConstants = require(ReplicatedStorage.features.weapons)

-- Import inventory system
local Inventory = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.inventory)

local Util = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.util)

local Shop = {}
local shopGui = nil
local shopIconGui = nil -- For the persistent shop icon
local currentPage = "grid" -- "grid" or "details"
local backButton = nil

-- Store original GUI states for restoration
local originalChatEnabled = true
local originalLeaderboardEnabled = true

-- Callback cleanup functions
local coinUpdateCallback = nil
local inventoryUpdateCallback = nil
local purchaseResponseCallback = nil

-- Store size change connections
local sizeConnections = {}

-- Create the main shop GUI
local function createShopGui()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Remove existing shop GUI if it exists
    local existingGui = playerGui:FindFirstChild("ShopGui")
    if existingGui then
        existingGui:Destroy()
    end

    HEADER_HEIGHT = 45

    if Workspace.CurrentCamera.ViewportSize.X >= 1200 then
        HEADER_HEIGHT = 60
    end
    
    -- Create main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "ShopGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100 -- Much higher value to ensure it's above chat
    gui.IgnoreGuiInset = true -- Ignore top bar inset to appear above everything
    gui.Parent = playerGui
    
    -- Create main frame with dark background
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0.8, 0, 0.8, 0)
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui

    local constraint = Instance.new("UISizeConstraint")
    constraint.Parent = mainFrame
    constraint.Name = "MainFrameSizeConstraint"
    constraint.MaxSize = Vector2.new(809, 500)
    
    local constraint = Instance.new("UIAspectRatioConstraint")
    constraint.Parent = mainFrame
    constraint.AspectRatio = 1.618
    constraint.Name = "MainFrameUIAspectRatioConstraint"
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Create header
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, HEADER_HEIGHT)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    header.BorderSizePixel = 0
    header.Parent = mainFrame
    
    local headerCorner = Instance.new("UICorner")
    headerCorner.CornerRadius = UDim.new(0, 12)
    headerCorner.Parent = header
    
    -- Back button (initially hidden) - styled like close button
    local backButton = Instance.new("TextButton")
    backButton.Name = "BackButton"
    backButton.Size = UDim2.new(0, HEADER_HEIGHT == 60 and 40 or 30, 0, HEADER_HEIGHT == 60 and 40 or 30)
    backButton.Position = UDim2.new(0, HEADER_HEIGHT == 60 and 15 or 10, 0.5, HEADER_HEIGHT == 60 and -20 or -15)
    backButton.BackgroundColor3 = Color3.fromRGB(100, 100, 105)
    backButton.Text = "←"
    backButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    backButton.TextScaled = true
    backButton.Font = Enum.Font.GothamBold
    backButton.BorderSizePixel = 0
    backButton.Visible = false
    backButton.ZIndex = 2
    backButton.Parent = header
    
    local backCorner = Instance.new("UICorner")
    backCorner.CornerRadius = UDim.new(0, 6)
    backCorner.Parent = backButton
    
    -- Coin display (centered in header)
    local coinFrame = Instance.new("Frame")
    coinFrame.Name = "CoinFrame"
    coinFrame.Size = UDim2.new(0, 120, 0, HEADER_HEIGHT == 60 and 30 or 25)
    coinFrame.Position = UDim2.new(0.5, -60, 0.5, HEADER_HEIGHT == 60 and -15 or -12.5)
    coinFrame.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
    coinFrame.BorderSizePixel = 0
    coinFrame.Parent = header
    
    local coinCorner = Instance.new("UICorner")
    coinCorner.CornerRadius = UDim.new(0, 15)
    coinCorner.Parent = coinFrame
    
    local coinLabel = Instance.new("TextLabel")
    coinLabel.Name = "CoinLabel"
    coinLabel.Size = UDim2.new(1, -10, 1, 0)
    coinLabel.Position = UDim2.new(0, 5, 0, 0)
    coinLabel.BackgroundTransparency = 1
    coinLabel.Text = "💰 " .. Inventory.getCoins()
    coinLabel.TextColor3 = Color3.fromRGB(0, 0, 0)
    coinLabel.TextScaled = true
    coinLabel.Font = Enum.Font.GothamBold
    coinLabel.Parent = coinFrame
    
    -- Close button (repositioned to avoid overlap)
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Size = UDim2.new(0, HEADER_HEIGHT == 60 and 40 or 30, 0, HEADER_HEIGHT == 60 and 40 or 30)
    closeButton.Position = UDim2.new(1, HEADER_HEIGHT == 60 and -50 or -37.5, 0.5, HEADER_HEIGHT == 60 and -20 or -15)
    closeButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeButton.Text = "×"
    closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeButton.TextScaled = true
    closeButton.Font = Enum.Font.GothamBold
    closeButton.BorderSizePixel = 0
    closeButton.Parent = header
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeButton
    
    -- Connect close button
    closeButton.MouseButton1Click:Connect(function()
        Shop.hide()
    end)
    
    -- Connect back button
    backButton.MouseButton1Click:Connect(function()
        Shop.showWeaponGrid()
    end)
    
    -- Set up coin update callback
    coinUpdateCallback = Inventory.onCoinsUpdated(function(coins)
        coinLabel.Text = "💰 " .. coins
    end)
    
    return gui, mainFrame, backButton
end

-- Create weapon grid page
local function createWeaponGrid(parent)
    local screenWidth = parent.AbsoluteSize.X
    -- Clear existing content (but preserve header)
    for _, child in pairs(parent:GetChildren()) do
        if child.Name ~= "Header" and child.Name ~= "MainFrameSizeConstraint" and child.Name ~= "MainFrameUIAspectRatioConstraint" then
            child:Destroy()
        end
    end
    
    -- Create scroll frame for weapons (directly in MainFrame)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "WeaponGrid"
    scrollFrame.Size = UDim2.new(1, 0, 1, -60) -- Account for MainFrame padding and header
    scrollFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT == 60 and 60 or 45) -- Position below header with padding
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.Parent = parent
    
    -- Container frame for centering
    local containerFrame = Instance.new("Frame")
    containerFrame.Name = "Container"
    containerFrame.Size = UDim2.new(1, 0, 1, 0)
    containerFrame.Position = UDim2.new(0, 0, 0, 0)
    containerFrame.BackgroundTransparency = 1
    containerFrame.Parent = scrollFrame
    
    -- Function to calculate responsive card layout
    local function updateCardLayout()
        local cardSpacing = 20
        local containerPadding = HEADER_HEIGHT == 60 and 40 or 30 -- Total left + right padding
        local availableWidth = screenWidth - containerPadding
        
        -- Determine columns based on screen size
        local columns
        if screenWidth >= 1200 then -- Big screens
            columns = 6
        else  -- Medium screens
            columns = 4
        end
        
        -- Calculate card width based on available space and columns
        local totalSpacing = (columns - 1) * cardSpacing
        local cardWidth = (availableWidth - totalSpacing) / columns
        local cardHeight = cardWidth
        
        -- Create responsive grid layout
        local gridLayout = Instance.new("UIGridLayout")
        gridLayout.CellSize = UDim2.new(0, cardWidth, 0, cardHeight)
        gridLayout.CellPadding = UDim2.new(0, cardSpacing, 0, cardSpacing)
        gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
        gridLayout.VerticalAlignment = Enum.VerticalAlignment.Top
        gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
        gridLayout.Parent = containerFrame
        
        -- Add padding for centering
        local padding = Instance.new("UIPadding")
        padding.PaddingLeft = UDim.new(0, containerPadding / 2)
        padding.PaddingRight = UDim.new(0, containerPadding / 2)
        padding.PaddingTop = UDim.new(0, containerPadding / 2)
        padding.PaddingBottom = UDim.new(0, containerPadding / 2)
        padding.Parent = containerFrame
        
        -- Update scroll canvas size
        local weaponCount = 0
        for _, constants in pairs(WeaponConstants) do
            if constants.SHOP then
                weaponCount = weaponCount + 1
            end
        end
        
        local totalRows = math.ceil(weaponCount / columns)
        local totalHeight = totalRows * cardHeight + (totalRows - 1) * cardSpacing + 40 -- Cards + spacing + padding
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    -- Create weapon cards
    local layoutOrder = 1
    for i, constants in pairs(WeaponConstants) do
        if not constants.SHOP then
            continue
        end

        local isOwned = Inventory.ownsItem(constants.ID)
        
        -- Weapon card frame with color coding for ownership
        local card = Instance.new("Frame")
        card.Name = constants.ID .. "Card"
        card.BackgroundColor3 = isOwned and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
        card.BorderSizePixel = 0
        card.LayoutOrder = layoutOrder
        card.Parent = containerFrame
        
        layoutOrder = layoutOrder + 1
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card
        
        -- Weapon name (responsive sizing)
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "WeaponName"
        nameLabel.Size = UDim2.new(1, -12, 0, 26)
        nameLabel.Position = UDim2.new(0, 6, 0, 6)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = constants.DISPLAY_NAME or constants.ID
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = card
        
        -- Weapon image (responsive sizing)
        local imageFrame = Instance.new("Frame")
        imageFrame.Name = "ImageFrame"
        imageFrame.Size = UDim2.new(1, -12, 1, -45) -- Fill remaining space after name
        imageFrame.Position = UDim2.new(0, 6, 0, 38)
        imageFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
        imageFrame.BorderSizePixel = 0
        imageFrame.Parent = card
        
        local imageCorner = Instance.new("UICorner")
        imageCorner.CornerRadius = UDim.new(0, 6)
        imageCorner.Parent = imageFrame
        
        -- Placeholder image (you can replace with actual weapon images)
        local image = Instance.new("ImageLabel")
        image.Name = "WeaponImage"
        image.Size = UDim2.new(0.8, 0, 0.8, 0)
        image.Position = UDim2.new(0.1, 0, 0.1, 0)
        image.BackgroundTransparency = 1
        image.Image = constants.IMAGE_ID or ""
        image.ScaleType = Enum.ScaleType.Fit
        image.Parent = imageFrame
        
        -- If no image, show text placeholder
        if not constants.IMAGE_ID or constants.IMAGE_ID == "rbxassetid://0" then
            local placeholder = Instance.new("TextLabel")
            placeholder.Size = UDim2.new(1, 0, 1, 0)
            placeholder.BackgroundTransparency = 1
            placeholder.Text = "🔫"
            placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
            placeholder.TextScaled = true
            placeholder.Font = Enum.Font.Gotham
            placeholder.Parent = imageFrame
        end
        
        -- Make card clickable
        local clickButton = Instance.new("TextButton")
        clickButton.Name = "ClickButton"
        clickButton.Size = UDim2.new(1, 0, 1, 0)
        clickButton.BackgroundTransparency = 1
        clickButton.Text = ""
        clickButton.Parent = card
        
        -- Hover effects with new color scheme
        clickButton.MouseEnter:Connect(function()
            local targetColor = isOwned and Color3.fromRGB(50, 90, 50) or Color3.fromRGB(90, 50, 50)
            local tween = TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = targetColor
            })
            tween:Play()
        end)
        
        clickButton.MouseLeave:Connect(function()
            local targetColor = isOwned and Color3.fromRGB(40, 80, 40) or Color3.fromRGB(80, 40, 40)
            local tween = TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = targetColor
            })
            tween:Play()
        end)
        
        -- Click to view details
        clickButton.MouseButton1Click:Connect(function()
            Shop.showWeaponDetails(constants)
        end)
    end
    
    -- Initial layout setup
    updateCardLayout()
    
    -- Listen for size changes to update layout
    local gridConnection = Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        updateCardLayout()
    end)
    
    -- Store connection for cleanup
    sizeConnections[containerFrame] = gridConnection
end

-- Create weapon details page
local function createWeaponDetails(parent, constants)
    -- Clear existing content (but preserve header)
    for _, child in pairs(parent:GetChildren()) do
        if child.Name ~= "Header" and child.Name ~= "MainFrameSizeConstraint" and child.Name ~= "MainFrameUIAspectRatioConstraint" then
            child:Destroy()
        end
    end

    local screenWidth = Workspace.CurrentCamera.ViewportSize.X
    
    local LARGE_FONT_SIZE = 24
    local MEDIUM_FONT_SIZE = 18

    if screenWidth >= 1200 then
        LARGE_FONT_SIZE = 26
        MEDIUM_FONT_SIZE = 22
    end
    
    local isOwned = Inventory.ownsItem(constants.ID)
    
    -- Create scrollable container (directly in MainFrame)
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "DetailsScroll"
    scrollFrame.Size = UDim2.new(1, 0, 1, HEADER_HEIGHT == 60 and -60 or -45) -- Account for MainFrame padding and header
    scrollFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT == 60 and 60 or 45) -- Position below header with padding
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.Parent = parent
    
    -- Container frame inside scrollFrame to handle padding (keeps scrollbar at edge)
    local containerFrame = Instance.new("Frame")
    containerFrame.Name = "Container"
    containerFrame.Size = UDim2.new(1, -8, 0, 0) -- Width fills, height auto-sizes
    containerFrame.AutomaticSize = Enum.AutomaticSize.Y -- Auto-size vertically to content
    containerFrame.Position = UDim2.new(0, 0, 0, 0)
    containerFrame.BackgroundTransparency = 1
    containerFrame.Parent = scrollFrame
    
    -- Main UIListLayout for ALL elements with equal spacing (in container)
    local mainListLayout = Instance.new("UIListLayout")
    mainListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    mainListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    mainListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    mainListLayout.FillDirection = Enum.FillDirection.Vertical
    mainListLayout.Padding = UDim.new(0, 15) -- No padding, we'll use space-evenly effect
    mainListLayout.Parent = containerFrame
    
    -- Add padding to container frame (not scrollFrame)
    local mainPadding = Instance.new("UIPadding")
    mainPadding.PaddingLeft = UDim.new(0, HEADER_HEIGHT == 60 and 20 or 15)
    mainPadding.PaddingRight = UDim.new(0, HEADER_HEIGHT == 60 and 20 or 15)
    mainPadding.PaddingTop = UDim.new(0, HEADER_HEIGHT == 60 and 20 or 15)
    mainPadding.PaddingBottom = UDim.new(0, HEADER_HEIGHT == 60 and 20 or 15)
    mainPadding.Parent = containerFrame
    
    -- Weapon image (in container)
    local imageFrame = Instance.new("Frame")
    imageFrame.Name = "ImageFrame"
    imageFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
    imageFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
    imageFrame.BorderSizePixel = 0
    imageFrame.LayoutOrder = 2
    imageFrame.Parent = containerFrame

    local imageFrameAspectRatioConstraint = Instance.new("UIAspectRatioConstraint")
    imageFrameAspectRatioConstraint.AspectRatio = 1.5
    imageFrameAspectRatioConstraint.Parent = imageFrame
    
    local imageCorner = Instance.new("UICorner")
    imageCorner.CornerRadius = UDim.new(0, 8)
    imageCorner.Parent = imageFrame
    
    -- Image placeholder
    local placeholder = Instance.new("TextLabel")
    placeholder.Size = UDim2.new(1, 0, 1, 0)
    placeholder.BackgroundTransparency = 1
    placeholder.Text = "🔫"
    placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
    placeholder.TextScaled = true
    placeholder.Font = Enum.Font.Gotham
    placeholder.Parent = imageFrame
    
    -- Weapon name (positioned absolutely on top of image frame)
    local nameLabel = Instance.new("TextLabel")
    nameLabel.Name = "WeaponName"
    nameLabel.Size = UDim2.new(1, 0, 0, 0) -- Full width, fixed height
    nameLabel.AutomaticSize = Enum.AutomaticSize.Y
    nameLabel.Position = UDim2.new(0, 0, 0, 0) -- Top of the image frame
    nameLabel.TextSize = LARGE_FONT_SIZE
    nameLabel.BackgroundColor3 = Color3.fromRGB(0, 0, 0) -- Semi-transparent background
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = constants.DISPLAY_NAME or constants.ID
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextXAlignment = Enum.TextXAlignment.Center
    nameLabel.TextYAlignment = Enum.TextYAlignment.Center
    nameLabel.LayoutOrder = 1
    nameLabel.Parent = containerFrame -- Parent to imageFrame instead of containerFrame
    
    -- Add corner rounding to name label
    local nameLabelCorner = Instance.new("UICorner")
    nameLabelCorner.CornerRadius = UDim.new(0, 8)
    nameLabelCorner.Parent = nameLabel
    
    -- Description (in container)
    local descLabel = Instance.new("TextLabel")
    descLabel.Name = "Description"
    descLabel.BackgroundTransparency = 1
    descLabel.Text = constants.DESCRIPTION or "No description available."
    descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    descLabel.Font = Enum.Font.Gotham
    descLabel.TextXAlignment = Enum.TextXAlignment.Center
    descLabel.TextWrapped = true
    descLabel.LayoutOrder = 3
    descLabel.Parent = containerFrame
    descLabel.TextSize = MEDIUM_FONT_SIZE
    descLabel.AutomaticSize = Enum.AutomaticSize.XY
    
    -- Weapon Stats (in container, with internal list layout)
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "StatsFrame"
    statsFrame.BackgroundTransparency = 1
    statsFrame.LayoutOrder = 4
    statsFrame.Parent = containerFrame
    statsFrame.AutomaticSize = Enum.AutomaticSize.XY
    
    -- Internal UIListLayout for stats with smaller spacing
    local statsLayout = Instance.new("UIListLayout")
    statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    statsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    statsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    statsLayout.FillDirection = Enum.FillDirection.Vertical
    statsLayout.Padding = UDim.new(0, 5) -- Smaller spacing within stats
    statsLayout.Parent = statsFrame
    
    -- Bullets per shot
    local bulletsLabel = Instance.new("TextLabel")
    bulletsLabel.Name = "BulletsLabel"
    bulletsLabel.BackgroundTransparency = 1
    bulletsLabel.Text = "🔫 Pellets: " .. (constants.BULLETS_PER_SHOT or "N/A")
    bulletsLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    bulletsLabel.Font = Enum.Font.Gotham
    bulletsLabel.TextXAlignment = Enum.TextXAlignment.Center
    bulletsLabel.LayoutOrder = 1
    bulletsLabel.Parent = statsFrame
    bulletsLabel.TextSize = MEDIUM_FONT_SIZE
    bulletsLabel.AutomaticSize = Enum.AutomaticSize.XY
    
    -- Damage per bullet
    local damageLabel = Instance.new("TextLabel")
    damageLabel.Name = "DamageLabel"
    damageLabel.BackgroundTransparency = 1
    damageLabel.Text = "💥 Damage: " .. (constants.DAMAGE_PER_BULLET or "N/A") .. " per pellet"
    damageLabel.TextColor3 = Color3.fromRGB(255, 150, 150)
    damageLabel.Font = Enum.Font.Gotham
    damageLabel.TextXAlignment = Enum.TextXAlignment.Center
    damageLabel.LayoutOrder = 2
    damageLabel.Parent = statsFrame
    damageLabel.TextSize = MEDIUM_FONT_SIZE
    damageLabel.AutomaticSize = Enum.AutomaticSize.XY
    
    -- Fire cooldown
    local cooldownLabel = Instance.new("TextLabel")
    cooldownLabel.Name = "CooldownLabel"
    cooldownLabel.BackgroundTransparency = 1
    cooldownLabel.Text = "⏱️ Fire Rate: " .. (constants.FIRE_COOLDOWN or "N/A") .. "s cooldown"
    cooldownLabel.TextColor3 = Color3.fromRGB(255, 255, 150)
    cooldownLabel.TextSize = MEDIUM_FONT_SIZE
    cooldownLabel.AutomaticSize = Enum.AutomaticSize.XY
    cooldownLabel.Font = Enum.Font.Gotham
    cooldownLabel.TextXAlignment = Enum.TextXAlignment.Center
    cooldownLabel.LayoutOrder = 3
    cooldownLabel.Parent = statsFrame
    
    -- Price (in container)
    local priceLabel = Instance.new("TextLabel")
    priceLabel.Name = "Price"
    priceLabel.BackgroundTransparency = 1
    priceLabel.Text = "💰 " .. (constants.PRICE or 0) .. " Coins"
    priceLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    priceLabel.TextSize = LARGE_FONT_SIZE
    priceLabel.AutomaticSize = Enum.AutomaticSize.XY
    priceLabel.Font = Enum.Font.GothamBold
    priceLabel.TextXAlignment = Enum.TextXAlignment.Center
    priceLabel.LayoutOrder = 5
    priceLabel.Parent = containerFrame
    
    -- Purchase button (in container)
    local purchaseButton = Instance.new("TextButton")
    purchaseButton.Name = "PurchaseButton"
    purchaseButton.Size = UDim2.new(0, 140, 0, 40)
    purchaseButton.BackgroundColor3 = isOwned and Color3.fromRGB(100, 100, 100) or Color3.fromRGB(50, 150, 50)
    purchaseButton.Text = isOwned and "OWNED" or "PURCHASE"
    purchaseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    purchaseButton.TextScaled = true
    purchaseButton.Font = Enum.Font.GothamBold
    purchaseButton.BorderSizePixel = 0
    purchaseButton.Active = not isOwned
    purchaseButton.LayoutOrder = 6
    purchaseButton.Parent = containerFrame
    
    -- Add corner styling to purchase button
    local purchaseCorner = Instance.new("UICorner")
    purchaseCorner.CornerRadius = UDim.new(0, 8)
    purchaseCorner.Parent = purchaseButton
    
    -- Add padding to purchase button
    local purchasePadding = Instance.new("UIPadding")
    purchasePadding.PaddingLeft = UDim.new(0, 12)
    purchasePadding.PaddingRight = UDim.new(0, 12)
    purchasePadding.PaddingTop = UDim.new(0, 8)
    purchasePadding.PaddingBottom = UDim.new(0, 8)
    purchasePadding.Parent = purchaseButton
    
    -- Connect purchase button
    if not isOwned then
        purchaseButton.MouseButton1Click:Connect(function()
            purchaseButton.Text = "PURCHASING..."
            purchaseButton.Active = false
            Inventory.purchaseItem(constants.ID)
        end)
    end
    
    -- Update canvas size when container size changes
    local function updateCanvasSize()
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, containerFrame.AbsoluteSize.Y)
    end
    
    -- Initial canvas size update
    updateCanvasSize()
    
    -- Listen for container size changes
    Workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateCanvasSize)
    
    -- Set up purchase response callback (only once, outside the rebuild function)
    if not isOwned then
        purchaseResponseCallback = Inventory.onPurchaseResponse(function(response)
            if response.success then
                -- Find the current purchase button and update it
                local containerFrame = scrollFrame:FindFirstChild("Container")
                local currentButton = containerFrame and containerFrame:FindFirstChild("PurchaseButton")
                if currentButton then
                    currentButton.Text = "PURCHASED!"
                    currentButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                end
                
                -- Update coin display immediately
                if shopGui and shopGui.MainFrame and shopGui.MainFrame.Header then
                    local coinLabel = shopGui.MainFrame.Header.CoinFrame.CoinLabel
                    coinLabel.Text = "💰 " .. Inventory.getCoins()
                end
                
                -- Update the grid view as well
                wait(1)
                Shop.showWeaponGrid()
            else
                -- Find the current purchase button and update it
                local containerFrame = scrollFrame:FindFirstChild("Container")
                local currentButton = containerFrame and containerFrame:FindFirstChild("PurchaseButton")
                if currentButton then
                    currentButton.Text = response.error or "PURCHASE FAILED"
                    currentButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
                    wait(2)
                    currentButton.Text = "PURCHASE"
                    currentButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
                    currentButton.Active = true
                end
            end
        end)
    end
end

-- Public functions
function Shop.show()
    if not shopGui then
        local gui, mainFrame, backBtn = createShopGui()
        shopGui = gui
        backButton = backBtn
        Shop.showWeaponGrid()
    end
    
    shopGui.Enabled = true
    Util.hideDefaultGuis() -- Hide chat and leaderboard when shop opens
end

function Shop.hide()
    if shopGui then
        shopGui.Enabled = false
        Util.showDefaultGuis() -- Restore chat and leaderboard when shop closes
        
        -- Clean up size change connections
        for scrollFrame, connection in pairs(sizeConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        sizeConnections = {} -- Clear the table
        
        -- Clean up callbacks
        if coinUpdateCallback then
            coinUpdateCallback()
            coinUpdateCallback = nil
        end
        if inventoryUpdateCallback then
            inventoryUpdateCallback()
            inventoryUpdateCallback = nil
        end
        if purchaseResponseCallback then
            purchaseResponseCallback()
            purchaseResponseCallback = nil
        end
    end
end

function Shop.showWeaponGrid()
    if shopGui then
        currentPage = "grid"
        local mainFrame = shopGui.MainFrame
        local backBtn = mainFrame.Header.BackButton
        backBtn.Visible = false
        
        -- Update coin display before showing grid
        local coinLabel = mainFrame.Header.CoinFrame.CoinLabel
        coinLabel.Text = "💰 " .. Inventory.getCoins()
        
        createWeaponGrid(mainFrame)
    end
end

function Shop.showWeaponDetails(constants)
    if shopGui then
        currentPage = "details"
        local mainFrame = shopGui.MainFrame
        local backBtn = mainFrame.Header.BackButton
        backBtn.Visible = true
        
        -- Update coin display before showing details
        local coinLabel = mainFrame.Header.CoinFrame.CoinLabel
        coinLabel.Text = "💰 " .. Inventory.getCoins()
        
        createWeaponDetails(mainFrame, constants)
    end
end

function Shop.toggle()
    if shopGui and shopGui.Enabled then
        Shop.hide()
    else
        Shop.show()
    end
end

-- Create persistent shop icon
local function createShopIcon()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Remove existing shop icon if it exists
    local existingIcon = playerGui:FindFirstChild("ShopIconGui")
    if existingIcon then
        existingIcon:Destroy()
    end
    
    -- Create ScreenGui for the shop icon
    local iconGui = Instance.new("ScreenGui")
    iconGui.Name = "ShopIconGui"
    iconGui.ResetOnSpawn = false
    iconGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    iconGui.DisplayOrder = 50 -- Lower than shop GUI but above default UI
    iconGui.Parent = playerGui
    iconGui.IgnoreGuiInset = true
    
    -- Create the shop icon button (positioned by parent menu system)
    local shopIcon = Instance.new("TextButton")
    shopIcon.Name = "ShopIcon"
    shopIcon.Size = UDim2.new(0, 50, 0, 50) -- Standard submenu icon size
    
    shopIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 50) -- Dark theme to match shop
    shopIcon.BorderSizePixel = 0
    shopIcon.Text = "⚔️" -- Crossed swords emoji for weapon shop
    shopIcon.TextColor3 = Color3.fromRGB(255, 215, 0) -- Gold text
    shopIcon.TextScaled = true
    shopIcon.Font = Enum.Font.GothamBold
    shopIcon.Parent = iconGui
    
    -- Make it perfectly round
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0.5, 0) -- 50% radius makes it circular
    iconCorner.Parent = shopIcon
    
    -- Add subtle shadow/border effect
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = Color3.fromRGB(255, 215, 0) -- Gold border
    iconStroke.Thickness = 2
    iconStroke.Parent = shopIcon
    
    -- Add hover effects
    shopIcon.MouseEnter:Connect(function()
        local tween = TweenService:Create(shopIcon, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 55, 0, 55),
            BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        })
        tween:Play()
        
        -- Animate the border
        local strokeTween = TweenService:Create(iconStroke, TweenInfo.new(0.2), {
            Thickness = 3
        })
        strokeTween:Play()
    end)
    
    shopIcon.MouseLeave:Connect(function()
        local tween = TweenService:Create(shopIcon, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 50, 0, 50),
            BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        })
        tween:Play()
        
        -- Animate the border back
        local strokeTween = TweenService:Create(iconStroke, TweenInfo.new(0.2), {
            Thickness = 2
        })
        strokeTween:Play()
    end)
    
    -- Connect click to toggle shop (open/close)
    shopIcon.MouseButton1Click:Connect(function()
        Shop.toggle()
    end)
    
    return iconGui
end

-- Create shop icon (called from game module)
function Shop.createShopIcon()
    return createShopIcon()
end

-- Initialize the shop (no longer creates icon automatically)
function Shop.init()
    if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == Enum.KeyCode.P then
                Shop.toggle()
            end
        end)
    end
end

return Shop 