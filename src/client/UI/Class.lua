local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local skillsGui = localPlayer.PlayerGui:WaitForChild("ClassGui")
local container = skillsGui:FindFirstChild("Container")

local ClassUI = {}

local classButtonConnections = {}

local function onClassSelected(button)
    localPlayer:SetAttribute("class", button.Name)
	Players.LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
	container.Visible = false
	cleanup()
end

function ClassUI.initialize()
    for _, child in ipairs(container:GetChildren()) do
        if child:IsA("TextButton") then
            local connection = child.MouseButton1Click:Connect(function()
                onClassSelected(child)
            end)
            table.insert(classButtonConnections, connection)
        end
    end
end

function cleanup()
    for _, connection in ipairs(classButtonConnections) do
        connection:Disconnect()
    end
    classButtonConnections = {}
end

return ClassUI