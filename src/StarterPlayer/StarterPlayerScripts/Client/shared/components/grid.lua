local Players = game:GetService("Players")
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
local Util = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.util)

local Grid = {}

local HEADER_HEIGHT = 60

function Grid.create(guiName, cards)
    local gui = Instance.new("ScreenGui")
    gui.Name = guiName
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
    
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "ScrollFrame"
    scrollFrame.Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT) -- Account for MainFrame padding and header
    scrollFrame.Position = UDim2.new(0, 0, 0, HEADER_HEIGHT) -- Position below header with padding
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.BorderSizePixel = 0
    scrollFrame.ScrollBarThickness = 8
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
    scrollFrame.Parent = mainFrame
    
    -- Container frame for centering
    local containerFrame = Instance.new("Frame")
    containerFrame.Name = "Container"
    containerFrame.Size = UDim2.new(1, 0, 1, 0)
    containerFrame.Position = UDim2.new(0, 0, 0, 0)
    containerFrame.BackgroundTransparency = 1
    containerFrame.Parent = scrollFrame

    local screenWidth = mainFrame.AbsoluteSize.X

    if screenWidth < 1200 then
        HEADER_HEIGHT = 45
    end
    
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

        local cardCount = 0
        for _, card in pairs(cards) do
            card.Size = UDim2.new(0, cardWidth, 0, cardHeight)
            print(card.Size)
            card.Parent = containerFrame
            card.LayoutOrder = cardCount
            cardCount = cardCount + 1
        end
        
        local totalRows = math.ceil(#cards / columns)
        local totalHeight = totalRows * cardHeight + (totalRows - 1) * cardSpacing + 40 -- Cards + spacing + padding
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end

    updateCardLayout()

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

    return gui
end

return Grid