local LogService = game:GetService("LogService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Get or wait for debug log event
local debugLogEvent = events:WaitForChild("DebugLogEvent")

-- Create GUI
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "LogViewer"
screenGui.Parent = playerGui

LogViewer = {}

local frame = Instance.new("Frame")
frame.Name = "LogFrame"
frame.Size = UDim2.new(0.8, 0, 0.6, 0)
frame.Position = UDim2.new(0.1, 0, 0.2, 0)
frame.BackgroundColor3 = Color3.new(0, 0, 0)
frame.BackgroundTransparency = 0.2
frame.BorderSizePixel = 2
frame.BorderColor3 = Color3.new(1, 1, 1)
frame.Visible = false
frame.Parent = screenGui

-- Title
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, 0, 0.1, 0)
title.Position = UDim2.new(0, 0, 0, 0)
title.BackgroundColor3 = Color3.new(0.2, 0.2, 0.2)
title.Text = "Server Logs (Press P to toggle, O to clear) - Select text to copy"
title.TextColor3 = Color3.new(1, 1, 1)
title.TextScaled = true
title.Font = Enum.Font.SourceSansBold
title.Parent = frame

-- Close button
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0.1, 0, 0.1, 0)
closeButton.Position = UDim2.new(0.9, 0, 0, 0)
closeButton.BackgroundColor3 = Color3.new(0.8, 0.2, 0.2)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.SourceSansBold
closeButton.Parent = frame

-- Scroll frame for logs
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Name = "LogScroll"
scrollFrame.Size = UDim2.new(1, 0, 0.9, 0)
scrollFrame.Position = UDim2.new(0, 0, 0.1, 0)
scrollFrame.BackgroundColor3 = Color3.new(0.1, 0.1, 0.1)
scrollFrame.BorderSizePixel = 0
scrollFrame.ScrollBarThickness = 10
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.Parent = frame

-- Text box for logs (changed from TextLabel to allow copying)
local logText = Instance.new("TextBox")
logText.Name = "LogText"
logText.Size = UDim2.new(1, -10, 1, 0)
logText.Position = UDim2.new(0, 5, 0, 0)
logText.BackgroundTransparency = 1
logText.Text = "Waiting for logs...\n"
logText.TextColor3 = Color3.new(1, 1, 1)
logText.TextXAlignment = Enum.TextXAlignment.Left
logText.TextYAlignment = Enum.TextYAlignment.Top
logText.TextWrapped = true
logText.Font = Enum.Font.SourceSans
logText.TextSize = 14
logText.MultiLine = true
logText.ClearTextOnFocus = false
logText.TextEditable = false
logText.Parent = scrollFrame

-- Store logs
local logs = {}
local maxLogs = 200

-- Function to add log
function LogViewer.addLog(message, messageType)
    -- Add nil checks and convert to strings
    message = message and tostring(message) or "(nil message)"
    messageType = messageType and tostring(messageType) or "MessageOutput"
    
    local timestamp = os.date("%H:%M:%S", tick())
    local typeStr = messageType:gsub("Enum.MessageType.", "")
    local logEntry = string.format("[%s] %s: %s", timestamp, typeStr, message)
    
    table.insert(logs, logEntry)
    
    -- Keep only recent logs
    if #logs > maxLogs then
        table.remove(logs, 1)
    end
    
    -- Update display
    logText.Text = table.concat(logs, "\n")
    
    -- Auto-scroll to bottom
    local textBounds = logText.TextBounds
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, textBounds.Y + 20)
    scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.CanvasSize.Y.Offset)
end

-- Function to clear logs
function LogViewer.clearLogs()
    logs = {}
    logText.Text = "Logs cleared...\n"
    scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
end

-- Get existing log history
function LogViewer.loadExistingLogs()
    local history = LogService:GetLogHistory()
    for _, entry in ipairs(history) do
        if entry.message:find("DEBUG:") or entry.message:find("Server") then
            LogViewer.addLog(entry.message, entry.messageType)
        end
    end
end

function LogViewer.init()    -- Connect to LogService
    LogService.MessageOut:Connect(function(message, messageType)
        -- Filter for server messages and DEBUG messages
        if message:find("Server") or message:find("DEBUG:") or 
           messageType == Enum.MessageType.MessageWarning or 
           messageType == Enum.MessageType.MessageError then
            LogViewer.addLog(message, messageType)
        end
    end)

    debugLogEvent.OnClientEvent:Connect(function(message)
        -- Add nil check to prevent concatenation errors
        if message then
            LogViewer.addLog("[SERVER] " .. tostring(message))
        else
            LogViewer.addLog("[SERVER] (nil message received)")
        end
    end)

    LogViewer.addLog("Log Viewer initialized - Waiting for debug messages...")

    -- Load existing log history
    for _, log in ipairs(LogService:GetLogHistory()) do
        local timestamp = log.timestamp
        local message = log.message
        
        -- Add nil check for message and ensure it's a string
        if message then
            message = tostring(message)
            
            -- Filter for server messages and DEBUG messages
            if message:find("Server") or message:find("DEBUG:") or 
               log.messageType == Enum.MessageType.MessageWarning or 
               log.messageType == Enum.MessageType.MessageError then
                LogViewer.addLog(message, log.messageType)
            end
        end
    end

    -- Input handling
    UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == Enum.KeyCode.L then
            frame.Visible = not frame.Visible
        elseif input.KeyCode == Enum.KeyCode.C then
            LogViewer.clearLogs()
        end
    end)

    -- Close button functionality
    closeButton.MouseButton1Click:Connect(function()
        frame.Visible = false
    end)
end

return LogViewer