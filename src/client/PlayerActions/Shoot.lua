local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

local Shoot = {}

local function onFire()
    local Camera = game.Workspace.CurrentCamera
    local direction = Camera.CFrame.LookVector
    local startPosition = Camera.CFrame.Position + direction * 2
    shootEvent:FireServer(startPosition, direction)
end


function Shoot.initialize()
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
end

return Shoot