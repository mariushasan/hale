local GameUI = {}

local localPlayer = game.Players.LocalPlayer

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "ScreenGui"
ScreenGui.Parent = localPlayer:WaitForChild("PlayerGui")
ScreenGui.Enabled = true

local TextLabel = Instance.new("TextLabel")
TextLabel.Name = "TextLabel"
TextLabel.Parent = ScreenGui
TextLabel.Position = UDim2.new(1, -110, 1, -60)
TextLabel.Size = UDim2.new(0, 100, 0, 50)
TextLabel.Text = "00:00"
TextLabel.TextSize = 24
TextLabel.TextColor3 = Color3.new(1, 1, 1)
TextLabel.BackgroundTransparency = 0
TextLabel.BackgroundColor3 = Color3.new(0.501960, 0.733333, 1)
TextLabel.BorderSizePixel = 5
TextLabel.BorderColor3 = Color3.new(1, 1, 1)

local outcomeLabel = Instance.new("TextLabel")
outcomeLabel.Name = "OutcomeLabel"
outcomeLabel.Parent = ScreenGui
outcomeLabel.Visible = false
outcomeLabel.TextSize = 120
outcomeLabel.TextColor3 = Color3.new(1, 1, 1)
outcomeLabel.BackgroundTransparency = 1
outcomeLabel.BorderSizePixel = 0
outcomeLabel.ZIndex = 2 
outcomeLabel.Size = UDim2.new(0, 280, 0, 140)
outcomeLabel.AnchorPoint = Vector2.new(0.5, 0.5)
outcomeLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
outcomeLabel.Font = Enum.Font.SourceSansBold

local countdownLabel = Instance.new("TextLabel")
countdownLabel.Name = "OutcomeLabel"
countdownLabel.Parent = ScreenGui
countdownLabel.Visible = false
countdownLabel.TextSize = 120
countdownLabel.TextColor3 = Color3.new(1, 1, 1)
countdownLabel.BackgroundTransparency = 1
countdownLabel.BorderSizePixel = 0
countdownLabel.ZIndex = 2
countdownLabel.Size = UDim2.new(0, 280, 0, 140)
countdownLabel.AnchorPoint = Vector2.new(0.5, 0.5)
countdownLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
countdownLabel.Font = Enum.Font.SourceSansBold

local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

local currentTimerTask = nil

function GameUI.showGameEnd(outcome)
    if outcome == "Victory" then
        outcomeLabel.Text = "Victory!"
        outcomeLabel.TextColor3 = Color3.fromRGB(0, 128, 0)
    elseif outcome == "Draw" then
        outcomeLabel.Text = "Draw"
        outcomeLabel.TextColor3 = Color3.fromRGB(49, 49, 49)
    else
        outcomeLabel.Text = "Defeat"
        outcomeLabel.TextColor3 = Color3.fromRGB(128, 0, 0)
    end
    outcomeLabel.Visible = true

    task.delay(6, function()
        outcomeLabel.Visible = false
    end)
end

function GameUI.setTimer(seconds)
    countdownLabel.Visible = false

    if currentTimerTask then
        task.cancel(currentTimerTask)
    end

    local localseconds = seconds
    if TextLabel then
        TextLabel.Text = formatTime(seconds)
    end

    currentTimerTask = task.spawn(function()
        while localseconds > 0 do
            localseconds = localseconds - 1

            if TextLabel then
                TextLabel.Text = formatTime(localseconds)
            end

            if localPlayer.Team.Name == "Waiting" then
                if localseconds <= 10 then
                    countdownLabel.Text = localseconds
                end

                if localseconds == 10 then
                    countdownLabel.Visible = true
                end
            end
            task.wait(1)
        end
        countdownLabel.Visible = false
    end)
end

return GameUI
