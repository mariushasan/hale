local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local WeaponSelectionEvent = ReplicatedStorage:WaitForChild("WeaponSelectionEvent")
local WeaponSelector = {}

-- Constants
local WEAPONS = {
    {
        name = "Rocket Launcher",
        description = "Powerful explosive weapon with long range",
        icon = "rbxassetid://4483345998", -- Default rocket icon
        weaponType = "rocket-launcher"
    },
    {
        name = "Shotgun",
        description = "Devastating close-range weapon with spread",
        icon = "rbxassetid://4483345998", -- Default shotgun icon
        weaponType = "shotgun"
    }
}

local camera = workspace.CurrentCamera
local originalCameraType = nil
local weaponsModule = nil

-- UI Creation
local function createWeaponSelector()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "WeaponSelector"
    screenGui.ResetOnSpawn = false
    
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 400, 0, 300)
    mainFrame.Position = UDim2.new(0.5, -200, 0.5, -150)
    mainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    mainFrame.BorderSizePixel = 0
    mainFrame.Visible = false
    mainFrame.Parent = screenGui
    
    local title = Instance.new("TextLabel")
    title.Name = "Title"
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "Select Weapon"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextSize = 24
    title.Font = Enum.Font.GothamBold
    title.Parent = mainFrame
    
    local weaponList = Instance.new("ScrollingFrame")
    weaponList.Name = "WeaponList"
    weaponList.Size = UDim2.new(1, -20, 1, -60)
    weaponList.Position = UDim2.new(0, 10, 0, 50)
    weaponList.BackgroundTransparency = 1
    weaponList.BorderSizePixel = 0
    weaponList.ScrollBarThickness = 6
    weaponList.Parent = mainFrame
    
    local listLayout = Instance.new("UIListLayout")
    listLayout.Padding = UDim.new(0, 10)
    listLayout.Parent = weaponList
    
    -- Create weapon buttons
    for _, weapon in ipairs(WEAPONS) do
        local weaponButton = Instance.new("Frame")
        weaponButton.Name = weapon.name
        weaponButton.Size = UDim2.new(1, 0, 0, 100)
        weaponButton.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        weaponButton.BorderSizePixel = 0
        
        local icon = Instance.new("ImageLabel")
        icon.Name = "Icon"
        icon.Size = UDim2.new(0, 80, 0, 80)
        icon.Position = UDim2.new(0, 10, 0.5, -40)
        icon.BackgroundTransparency = 1
        icon.Image = weapon.icon
        icon.Parent = weaponButton
        
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "Name"
        nameLabel.Size = UDim2.new(1, -100, 0, 30)
        nameLabel.Position = UDim2.new(0, 100, 0, 10)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = weapon.name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextSize = 18
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = weaponButton
        
        local descLabel = Instance.new("TextLabel")
        descLabel.Name = "Description"
        descLabel.Size = UDim2.new(1, -100, 0, 40)
        descLabel.Position = UDim2.new(0, 100, 0, 40)
        descLabel.BackgroundTransparency = 1
        descLabel.Text = weapon.description
        descLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        descLabel.TextSize = 14
        descLabel.Font = Enum.Font.Gotham
        descLabel.TextXAlignment = Enum.TextXAlignment.Left
        descLabel.TextWrapped = true
        descLabel.Parent = weaponButton
        
        local selectButton = Instance.new("TextButton")
        selectButton.Name = "SelectButton"
        selectButton.Size = UDim2.new(0, 100, 0, 30)
        selectButton.Position = UDim2.new(1, -110, 0.5, -15)
        selectButton.BackgroundColor3 = Color3.fromRGB(0, 120, 215)
        selectButton.BorderSizePixel = 0
        selectButton.Text = "Select"
        selectButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        selectButton.TextSize = 14
        selectButton.Font = Enum.Font.GothamBold
        selectButton.Parent = weaponButton
        
        -- Button hover effect
        selectButton.MouseEnter:Connect(function()
            TweenService:Create(selectButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(0, 140, 255)
            }):Play()
        end)
        
        selectButton.MouseLeave:Connect(function()
            TweenService:Create(selectButton, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(0, 120, 215)
            }):Play()
        end)
        
        -- Selection handler
        selectButton.MouseButton1Click:Connect(function()
            -- Hide UI immediately for instant feedback
            WeaponSelector.hide()
            
            -- Equip weapon locally and notify server
            weaponsModule.equipLocal(weapon.weaponType)
        end)
        
        weaponButton.Parent = weaponList
    end
    
    screenGui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
    return screenGui
end

-- Public Functions
function WeaponSelector.init(weapons)
    weaponsModule = weapons
end

function WeaponSelector.show()
    if not WeaponSelector.gui then
        WeaponSelector.gui = createWeaponSelector()
    end
    WeaponSelector.gui.MainFrame.Visible = true
    
    -- Store original camera type and switch to fixed camera
    originalCameraType = camera.CameraType
    camera.CameraType = Enum.CameraType.Fixed
    
    -- Enable mouse cursor and unlock mouse
    UserInputService.MouseIconEnabled = true
    UserInputService.MouseBehavior = Enum.MouseBehavior.Default
    
    -- Disable camera controls
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, true)
    end)
end

function WeaponSelector.hide()
    if WeaponSelector.gui then
        WeaponSelector.gui.MainFrame.Visible = false
        
        -- Restore original camera type
        if originalCameraType then
            camera.CameraType = originalCameraType
        end
        
        -- Hide mouse cursor but allow normal camera movement
        UserInputService.MouseIconEnabled = false
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
        -- Re-enable camera controls
        pcall(function()
            StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true)
        end)
    end
end

function WeaponSelector.toggle()
    if WeaponSelector.gui and WeaponSelector.gui.MainFrame.Visible then
        WeaponSelector.hide()
    else
        WeaponSelector.show()
    end
end

-- Handle escape key to close UI (with proper event handling)
local function onInputBegan(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.Escape and WeaponSelector.gui and WeaponSelector.gui.MainFrame.Visible then
        WeaponSelector.hide()
    end
end

UserInputService.InputBegan:Connect(onInputBegan)

return WeaponSelector 