local Players = game:GetService("Players")


local BulletsGui = {}
local bulletsGui = nil
local bulletsLabel = nil
local clipsLabel = nil

function BulletsGui.createBulletsGui()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")

    local bulletsGui = Instance.new("ScreenGui")
    bulletsGui.Name = "BulletsGui"
    bulletsGui.ResetOnSpawn = false
    bulletsGui.Parent = playerGui

    local bulletsFrame = Instance.new("Frame")
    bulletsFrame.Name = "BulletsFrame"
    bulletsFrame.Size = UDim2.new(0, 110, 0, 60)
    bulletsFrame.Position = UDim2.new(1, -110, 1, -60) -- Bottom right corner
    bulletsFrame.AnchorPoint = Vector2.new(0, 0)
    bulletsFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35) -- Plain black
    bulletsFrame.BorderSizePixel = 0
    bulletsFrame.Parent = bulletsGui

    -- Bullets label
    bulletsLabel = Instance.new("TextLabel")
    bulletsLabel.Name = "BulletsLabel"
    bulletsLabel.Size = UDim2.new(1, -10, 0.4, 0)
    bulletsLabel.Position = UDim2.new(0, 5, 0, 5)
    bulletsLabel.BackgroundTransparency = 1
    bulletsLabel.Text = "0/0"
    bulletsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    bulletsLabel.TextScaled = true
    bulletsLabel.Font = Enum.Font.Gotham
    bulletsLabel.Parent = bulletsFrame

    -- Clips label
    clipsLabel = Instance.new("TextLabel")
    clipsLabel.Name = "ClipsLabel"
    clipsLabel.Size = UDim2.new(1, -10, 0.4, 0)
    clipsLabel.Position = UDim2.new(0, 5, 0.45, 5)
    clipsLabel.BackgroundTransparency = 1
    clipsLabel.Text = "0/0"
    clipsLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    clipsLabel.TextScaled = true
    clipsLabel.Font = Enum.Font.Gotham
    clipsLabel.Parent = bulletsFrame

    return bulletsGui
end

function BulletsGui.updateBulletsGui(currentBullets, totalBullets, currentClips, totalClips)
    if currentClips == math.huge then
        currentClips = "∞"
    end
    if totalClips == math.huge then
        totalClips = "∞"
    end
    if currentBullets == math.huge then
        currentBullets = "∞"
    end
    if totalBullets == math.huge then
        totalBullets = "∞"
    end
    if bulletsLabel and clipsLabel then
        bulletsLabel.Text = currentBullets .. "/" .. totalBullets
        clipsLabel.Text = currentClips .. "/" .. totalClips
    end
end

function BulletsGui.hide()
    if bulletsGui then
        bulletsGui.Enabled = false
    end
end

function BulletsGui.show()
    if bulletsGui then
        bulletsGui.Enabled = true
    end
end

function BulletsGui.init()
    bulletsGui = BulletsGui.createBulletsGui()
end

return BulletsGui