local GameUI = {}

local LocalPlayer = game.Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local HUDGui = nil
local TimerLabel = nil
local MiddleLabel = nil

function GameUI.init()
    if HUDGui and HUDGui.Parent then
        return
    end

    HUDGui = Instance.new("ScreenGui")
    HUDGui.Name = "HUDGui"
    HUDGui.Parent = PlayerGui
    HUDGui.Enabled = true

    TimerLabel = Instance.new("TextLabel")
    TimerLabel.Name = "TimerLabel"
    TimerLabel.Parent = HUDGui
    TimerLabel.Position = UDim2.new(1, -110, 1, -60)
    TimerLabel.Size = UDim2.new(0, 100, 0, 50)
    TimerLabel.Text = "00:00"
    TimerLabel.TextSize = 24
    TimerLabel.TextColor3 = Color3.new(1, 1, 1)
    TimerLabel.BackgroundTransparency = 0
    TimerLabel.BackgroundColor3 = Color3.new(0.501960, 0.733333, 1)
    TimerLabel.BorderSizePixel = 5
    TimerLabel.BorderColor3 = Color3.new(1, 1, 1)

    MiddleLabel = Instance.new("TextLabel")
    MiddleLabel.Name = "MiddleLabel"
    MiddleLabel.Parent = HUDGui
    print("Creating MiddleLabel")
    MiddleLabel.Visible = false
    MiddleLabel.TextSize = 120
    MiddleLabel.TextColor3 = Color3.new(1, 1, 1)
    MiddleLabel.BackgroundTransparency = 1
    MiddleLabel.BorderSizePixel = 0
    MiddleLabel.ZIndex = 2 
    MiddleLabel.Size = UDim2.new(0, 280, 0, 140)
    MiddleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    MiddleLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    MiddleLabel.Font = Enum.Font.SourceSansBold
end

local function formatTime(seconds)
    local minutes = math.floor(seconds / 60)
    local remainingSeconds = seconds % 60
    return string.format("%02d:%02d", minutes, remainingSeconds)
end

local currentTimerTask = nil

function GameUI.showGameEnd(outcome)
    if currentTimerTask then
        task.cancel(currentTimerTask)
    end

    if outcome == "Victory" then
        MiddleLabel.Text = "Victory!"
        MiddleLabel.TextColor3 = Color3.fromRGB(0, 128, 0)
    elseif outcome == "Draw" then
        MiddleLabel.Text = "Draw"
        MiddleLabel.TextColor3 = Color3.fromRGB(49, 49, 49)
    else
        MiddleLabel.Text = "Defeat"
        MiddleLabel.TextColor3 = Color3.fromRGB(128, 0, 0)
    end
    print("Showing game end")
    MiddleLabel.Visible = true

    task.delay(6, function()
        print("Hiding game end")
        MiddleLabel.Visible = false
    end)
end

function GameUI.setTimer(seconds)
    MiddleLabel.Visible = false

    if currentTimerTask then
        task.cancel(currentTimerTask)
    end

    local localseconds = seconds
    if TimerLabel then
        TimerLabel.Text = formatTime(seconds)
    end

    currentTimerTask = task.spawn(function()
        while localseconds > 0 do
            localseconds = localseconds - 1

            if TimerLabel then
                TimerLabel.Text = formatTime(localseconds)
            end

            if LocalPlayer.Team.Name == "Waiting" then
                if localseconds <= 10 then
                    MiddleLabel.Text = localseconds
                end

                if localseconds == 10 then
                    MiddleLabel.Visible = true
                end
            end
            task.wait(1)
        end
        MiddleLabel.Visible = false
    end)
end

return GameUI
