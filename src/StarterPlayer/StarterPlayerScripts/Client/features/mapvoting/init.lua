local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

-- Import map constants
local MapConstants = require(ReplicatedStorage.features.maps)

-- Remote Events
local MapVotingEvent = events:WaitForChild("MapVotingEvent")
local MapVoteUpdateEvent = events:WaitForChild("MapVoteUpdateEvent")

local MapVoting = {}
local votingGui = nil
local currentVote = nil -- Track player's current vote
local voteCounts = {} -- Track vote counts for display
local votingActive = false

-- Store size change connections
local sizeConnections = {}

-- Function to scale UI elements based on screen width
local function dpx(scale)
    local screenWidth = Workspace.CurrentCamera.ViewportSize.X
    return screenWidth * scale
end

-- Create the main voting GUI
local function createVotingGui()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Remove existing voting GUI if it exists
    local existingGui = playerGui:FindFirstChild("MapVotingGui")
    if existingGui then
        existingGui:Destroy()
    end
    
    -- Create main ScreenGui
    local gui = Instance.new("ScreenGui")
    gui.Name = "MapVotingGui"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.DisplayOrder = 100 -- High value to ensure it's above other UI
    gui.IgnoreGuiInset = true
    gui.Parent = playerGui
    
    -- Create main frame (no header, just the voting area)
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
    
    local aspectRatio = Instance.new("UIAspectRatioConstraint")
    aspectRatio.Parent = mainFrame
    aspectRatio.AspectRatio = 1.618 -- Wider aspect ratio
    aspectRatio.Name = "MainFrameUIAspectRatioConstraint"
    
    -- Add corner rounding
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = mainFrame
    
    -- Title at the top
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(0.8, 0, 0, 40)
    titleLabel.Position = UDim2.new(0.1, 0, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🗺️ VOTE FOR NEXT MAP"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = mainFrame
    
    return gui, mainFrame
end

-- Create map voting grid
local function createMapGrid(parent)
    local screenWidth = parent.AbsoluteSize.X
    
    -- Clear existing content (but preserve title and constraints)
    for _, child in pairs(parent:GetChildren()) do
        if child.Name ~= "TitleLabel" and child.Name ~= "MainFrameSizeConstraint" and child.Name ~= "MainFrameUIAspectRatioConstraint" and not child:IsA("UICorner") then
            child:Destroy()
        end
    end
    
    -- Create scroll frame for maps
    local scrollFrame = Instance.new("ScrollingFrame")
    scrollFrame.Name = "MapGrid"
    scrollFrame.Size = UDim2.new(1, 0, 1, -60) -- Account for title space
    scrollFrame.Position = UDim2.new(0, 0, 0, 60) -- Position below title
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
        local containerPadding = 40 -- Total left + right padding
        local availableWidth = screenWidth - containerPadding
        
        -- Determine columns based on screen size (same as shop)
        local columns
        if screenWidth >= 1200 then -- Big screens
            columns = 3
        else  -- Medium screens
            columns = 3
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
        local mapCount = 0
        for _, constants in pairs(MapConstants) do
            mapCount = mapCount + 1
        end
        
        local totalRows = math.ceil(mapCount / columns)
        local totalHeight = totalRows * cardHeight + (totalRows - 1) * cardSpacing + 40 -- Cards + spacing + padding
        scrollFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end
    
    -- Create map cards
    local layoutOrder = 1
    for mapId, constants in pairs(MapConstants) do
        local voteCount = voteCounts[mapId] or 0
        local isPlayerVote = (currentVote == mapId)
        
        -- Map card frame with color coding for votes
        local card = Instance.new("Frame")
        card.Name = mapId .. "Card"
        card.BackgroundColor3 = isPlayerVote and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(50, 50, 60)
        card.BorderSizePixel = 0
        card.LayoutOrder = layoutOrder
        card.Parent = containerFrame
        
        layoutOrder = layoutOrder + 1
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card
        
        -- Map image
        local imageFrame = Instance.new("Frame")
        imageFrame.Name = "ImageFrame"
        imageFrame.Size = UDim2.new(1, -12, 1, -38) -- Space for name and vote count
        imageFrame.Position = UDim2.new(0, 6, 0, 6)
        imageFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
        imageFrame.BorderSizePixel = 0
        imageFrame.Parent = card
        
        local imageCorner = Instance.new("UICorner")
        imageCorner.CornerRadius = UDim.new(0, 6)
        imageCorner.Parent = imageFrame
        
        -- Placeholder image (map icon)
        local image = Instance.new("ImageLabel")
        image.Name = "MapImage"
        image.Size = UDim2.new(0.8, 0, 0.8, 0)
        image.Position = UDim2.new(0.1, 0, 0.1, 0)
        image.BackgroundTransparency = 1
        image.Image = constants.IMAGE_ID or ""
        image.ScaleType = Enum.ScaleType.Fit
        image.Parent = imageFrame
        
        -- If no image, show text placeholder
        if not constants.IMAGE_ID or constants.IMAGE_ID == "" then
            local placeholder = Instance.new("TextLabel")
            placeholder.Size = UDim2.new(1, 0, 1, 0)
            placeholder.BackgroundTransparency = 1
            placeholder.Text = "🗺️"
            placeholder.TextColor3 = Color3.fromRGB(150, 150, 150)
            placeholder.TextScaled = true
            placeholder.Font = Enum.Font.Gotham
            placeholder.Parent = imageFrame
        end
        
        -- Vote count display
        local voteLabel = Instance.new("TextLabel")
        voteLabel.Name = "VoteCount"
        voteLabel.Size = UDim2.new(1, -12, 0, 20)
        voteLabel.Position = UDim2.new(0, 6, 1, -26)
        voteLabel.BackgroundTransparency = 1
        voteLabel.Text = "🗳️ " .. voteCount .. " votes"
        voteLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        voteLabel.TextScaled = true
        voteLabel.Font = Enum.Font.Gotham
        voteLabel.Parent = card
        
        -- Make card clickable
        local clickButton = Instance.new("TextButton")
        clickButton.Name = "ClickButton"
        clickButton.Size = UDim2.new(1, 0, 1, 0)
        clickButton.BackgroundTransparency = 1
        clickButton.Text = ""
        clickButton.Parent = card
        
        -- Hover effects
        clickButton.MouseEnter:Connect(function()
            local targetColor = isPlayerVote and Color3.fromRGB(60, 110, 60) or Color3.fromRGB(60, 60, 70)
            local tween = TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = targetColor
            })
            tween:Play()
        end)
        
        clickButton.MouseLeave:Connect(function()
            local targetColor = isPlayerVote and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(50, 50, 60)
            local tween = TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = targetColor
            })
            tween:Play()
        end)
        
        -- Click to vote
        clickButton.MouseButton1Click:Connect(function()
            if votingActive then
                MapVoting.vote(mapId)
            end
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

-- Update vote counts display
local function updateVoteDisplay()
    if not votingGui then return end
    
    local containerFrame = votingGui.MainFrame.MapGrid:FindFirstChild("Container")
    if not containerFrame then return end
    
    for mapId, voteCount in pairs(voteCounts) do
        local card = containerFrame:FindFirstChild(mapId .. "Card")
        if card then
            local voteLabel = card:FindFirstChild("VoteCount")
            if voteLabel then
                voteLabel.Text = "🗳️ " .. voteCount .. " votes"
            end
            
            -- Update card color based on player vote
            local isPlayerVote = (currentVote == mapId)
            card.BackgroundColor3 = isPlayerVote and Color3.fromRGB(50, 100, 50) or Color3.fromRGB(50, 50, 60)
        end
    end
end

-- Public functions
function MapVoting.show()
    if not votingGui then
        local gui, mainFrame = createVotingGui()
        votingGui = gui
        createMapGrid(mainFrame)
    end
    
    votingGui.Enabled = true
end

function MapVoting.hide()
    if votingGui then
        votingGui.Enabled = false
        
        -- Clean up size change connections
        for frame, connection in pairs(sizeConnections) do
            if connection then
                connection:Disconnect()
            end
        end
        sizeConnections = {}
    end
end

function MapVoting.vote(mapId)
    if not votingActive then
        return
    end
    
    currentVote = mapId
    MapVotingEvent:FireServer("vote", mapId)
    updateVoteDisplay()
end

function MapVoting.toggle()
    if votingGui and votingGui.Enabled then
        MapVoting.hide()
    else
        MapVoting.show()
    end
end

-- Initialize the system
function MapVoting.init()
    -- Initialize vote counts
    for mapId, _ in pairs(MapConstants) do
        voteCounts[mapId] = 0
    end
    
    -- Handle voting events from server
    MapVotingEvent.OnClientEvent:Connect(function(action, data)
        if action == "start" then
            votingActive = true
            currentVote = nil
            print("Map voting started! Duration: " .. (data or "unknown") .. " seconds")
            MapVoting.show()
        elseif action == "end" then
            votingActive = false
            print("Map voting ended! Winning map: " .. (data or "unknown"))
            MapVoting.hide()
        end
    end)
    
    -- Handle vote count updates
    MapVoteUpdateEvent.OnClientEvent:Connect(function(newVoteCounts)
        voteCounts = newVoteCounts or {}
        updateVoteDisplay()
    end)
    
    -- Keyboard shortcut for testing (V key)
    if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == Enum.KeyCode.V then
                MapVoting.toggle()
            end
        end)
    end
    
    print("MapVoting client initialized")
end

return MapVoting 