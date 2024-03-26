local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local player = game.Players.LocalPlayer

-- Force first-person mode by setting the camera min and max distances to 0
player.CameraMode = Enum.CameraMode.LockFirstPerson

-- Optional: Continuously enforce first-person in case of attempts to switch camera mode

local function onFire()
    local Camera = game.Workspace.CurrentCamera
    local direction = Camera.CFrame.LookVector
    local startPosition = Camera.CFrame.Position + direction * 2 -- Adjust the start distance from the camera/player

    shootEvent:FireServer(startPosition, direction)
end

-- Input handling
if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
    UserInputService.TouchTap:Connect(function(touchPositions, processedByUI)
        if not processedByUI then
            onFire()
        end
    end)
else
    UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
        if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.MouseButton1 then
            onFire()
        end
    end)
end
