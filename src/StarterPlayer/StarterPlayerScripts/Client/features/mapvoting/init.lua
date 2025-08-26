local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local Grid = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.components.grid)

-- Import map constants
local MapConstants = require(ReplicatedStorage.features.maps)

-- Remote Events
local MapVotingEvent = events:WaitForChild("MapVotingEvent")
local MapVoteUpdateEvent = events:WaitForChild("MapVoteUpdateEvent")
local MapVotingUIReadyEvent = events:WaitForChild("MapVotingUIReadyEvent")

local MapVoting = {}
local votingGui = nil
local currentVote = nil -- Track player's current vote
local voteCounts = {} -- Track vote counts for display

-- Create the main voting GUI
local function createVotingGui()
    local player = Players.LocalPlayer

    local layoutOrder = 1
    local cards = {}

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
            MapVoting.vote(mapId)
        end)

        table.insert(cards, card)
    end

    local gui = Grid.create("MapVotingGui", cards)
    
    -- Create main ScreenGui
    local mainFrame = gui.MainFrame
    local header = mainFrame.Header
    local closeButton = header.CloseButton
    closeButton.Visible = false
    
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
    titleLabel.Parent = header
    
    return gui
end

-- Update vote counts display
local function updateVoteDisplay()
    if not votingGui then return end
    
    local containerFrame = votingGui.MainFrame.ScrollFrame:FindFirstChild("Container")
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
    for mapId, _ in pairs(MapConstants) do
        voteCounts[mapId] = 0
    end

    if not votingGui then
        local gui = createVotingGui()
        votingGui = gui
    end
    
    votingGui.Enabled = true
end

function MapVoting.hide()
    if votingGui then
        votingGui:Destroy()
        votingGui = nil
    end
end

function MapVoting.vote(mapId)
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
    MapVotingEvent.OnClientEvent:Connect(function(action, data)
        if action == "start" then
            currentVote = nil
            MapVoting.show()
        elseif action == "end" then
            MapVoting.hide()
        end
    end)
    
    -- Handle vote count updates
    MapVoteUpdateEvent.OnClientEvent:Connect(function(newVoteCounts)
        voteCounts = newVoteCounts or {}
        updateVoteDisplay()
    end)

    MapVotingUIReadyEvent:FireServer()
end

return MapVoting 