local GameUI = {}

local localPlayer = game.Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local gameGui = nil
local timerLabel = nil
local middleLabel = nil

function GameUI.create()
    if gameGui and gameGui.Parent then
        return
    end

    gameGui = Instance.new("ScreenGui")
    gameGui.Name = "GameGui"
    gameGui.ResetOnSpawn = false
    gameGui.Parent = playerGui
    gameGui.Enabled = true

    timerLabel = Instance.new("TextLabel")
    timerLabel.Name = "TimerLabel"
    timerLabel.Parent = gameGui
    timerLabel.Position = UDim2.new(1, -110, 1, -60)
    timerLabel.Size = UDim2.new(0, 100, 0, 50)
    timerLabel.Text = "00:00"
    timerLabel.TextSize = 24
    timerLabel.TextColor3 = Color3.new(1, 1, 1)
    timerLabel.BackgroundTransparency = 0
    timerLabel.BackgroundColor3 = Color3.new(0.501960, 0.733333, 1)
    timerLabel.BorderSizePixel = 5
    timerLabel.BorderColor3 = Color3.new(1, 1, 1)

    middleLabel = Instance.new("TextLabel")
    middleLabel.Name = "MiddleLabel"
    middleLabel.Parent = gameGui
    middleLabel.Visible = false
    middleLabel.TextSize = 120
    middleLabel.TextColor3 = Color3.new(1, 1, 1)
    middleLabel.BackgroundTransparency = 1
    middleLabel.BorderSizePixel = 0
    middleLabel.ZIndex = 2 
    middleLabel.Size = UDim2.new(0, 280, 0, 140)
    middleLabel.AnchorPoint = Vector2.new(0.5, 0.5)
    middleLabel.Position = UDim2.new(0.5, 0, 0.5, 0)
    middleLabel.Font = Enum.Font.SourceSansBold
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
        middleLabel.Text = "Victory!"
        middleLabel.TextColor3 = Color3.fromRGB(0, 128, 0)
    elseif outcome == "Draw" then
        middleLabel.Text = "Draw"
        middleLabel.TextColor3 = Color3.fromRGB(49, 49, 49)
    else
        middleLabel.Text = "Defeat"
        middleLabel.TextColor3 = Color3.fromRGB(128, 0, 0)
    end
    middleLabel.Visible = true

    task.delay(5, function()
        middleLabel.Visible = false
    end)
end

function GameUI.setTimer(seconds)
    middleLabel.Visible = false

    if currentTimerTask then
        task.cancel(currentTimerTask)
    end

    local localseconds = seconds
    if timerLabel then
        timerLabel.Text = formatTime(seconds)
    end

    currentTimerTask = task.spawn(function()
        while localseconds > 0 do
            localseconds = localseconds - 1

            if timerLabel then
                timerLabel.Text = formatTime(localseconds)
            end

            if localPlayer.Team.Name == "Waiting" then
                if localseconds <= 10 then
                    middleLabel.Text = localseconds
                end

                if localseconds == 10 then
                    middleLabel.Visible = true
                end
            end
            task.wait(1)
        end
        middleLabel.Visible = false
    end)
end

function GameUI.init()
    gameGui = GameUI.create()
end

return GameUI
