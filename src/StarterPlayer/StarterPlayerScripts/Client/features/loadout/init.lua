local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Import required modules
local WeaponConstants = require(ReplicatedStorage.features.weapons)
local Inventory = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.inventory)
local Weapons = require(game.StarterPlayer.StarterPlayerScripts.Client.features.weapons)

local Util = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.util)
local Grid = require(game.StarterPlayer.StarterPlayerScripts.Client.shared.components.grid)

local Loadout = {}
local loadoutGui = nil
local liveUpdateConnection = nil
local currentView = "main" -- "main" or "weapons"
local currentWeapon = "AssaultRifle" -- Default weapon
local characterAddedConnection = nil
local gui = nil
local weaponNameLabel = nil

-- Function to show main loadout view
local function showMainView()
    local mainFrame = gui.MainFrame
    local header = mainFrame.Header
    local weaponFrame = mainFrame.ContentFrame.WeaponFrame
    local titleLabel = header.TitleLabel
    local backButton = header.BackButton
    local scrollFrame = mainFrame.ScrollFrame
    local contentFrame = mainFrame.ContentFrame
    
    currentView = "main"
    
    backButton.Visible = false
    scrollFrame.Visible = false
    -- Show main content
    weaponFrame.Visible = true
    contentFrame.Visible = true
    
    -- Update title
    titleLabel.Text = "🔫 LOADOUT"
end
        
-- Function to update current weapon display
local function updateCurrentWeaponDisplay()
    local weaponData = WeaponConstants[currentWeapon]
    if weaponData then
        weaponNameLabel.Text = weaponData.DISPLAY_NAME or currentWeapon
    end
end

-- Create the main loadout GUI
local function createLoadoutGui()
    local player = Players.LocalPlayer

    local HEADER_HEIGHT = 45
    if workspace.CurrentCamera.ViewportSize.X >= 1200 then
        HEADER_HEIGHT = 60
    end

    local cards = {}
    local layoutOrder = 0
    local weaponCount = 0

    for _, constants in pairs(WeaponConstants) do
        if not constants.SHOP then
            continue
        end
        
        local isOwned = Inventory.ownsItem(constants.ID)
        if not isOwned then
            continue
        end
        
        weaponCount = weaponCount + 1
        
        -- Create weapon card (similar to shop style)
        local card = Instance.new("TextButton")
        card.Name = constants.ID .. "Card"
        card.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
        card.BorderSizePixel = 0
        card.LayoutOrder = layoutOrder
        card.Text = ""
        card.Parent = containerFrame
        
        local cardCorner = Instance.new("UICorner")
        cardCorner.CornerRadius = UDim.new(0, 8)
        cardCorner.Parent = card
        
        -- Weapon name
        local nameLabel = Instance.new("TextLabel")
        nameLabel.Name = "WeaponName"
        nameLabel.Size = UDim2.new(1, -12, 0, 26)
        nameLabel.Position = UDim2.new(0, 6, 0, 6)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = constants.DISPLAY_NAME or constants.ID
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.TextScaled = true
        nameLabel.Font = Enum.Font.GothamBold
        nameLabel.Parent = card
        
        -- Weapon image area
        local imageFrame = Instance.new("Frame")
        imageFrame.Name = "ImageFrame"
        imageFrame.Size = UDim2.new(1, -12, 1, -45)
        imageFrame.Position = UDim2.new(0, 6, 0, 38)
        imageFrame.BackgroundColor3 = Color3.fromRGB(70, 70, 75)
        imageFrame.BorderSizePixel = 0
        imageFrame.Parent = card
        
        local imageCorner = Instance.new("UICorner")
        imageCorner.CornerRadius = UDim.new(0, 6)
        imageCorner.Parent = imageFrame
        
        -- Weapon icon placeholder
        local image = Instance.new("TextLabel")
        image.Name = "WeaponImage"
        image.Size = UDim2.new(1, 0, 1, 0)
        image.BackgroundTransparency = 1
        image.Text = "🔫"
        image.TextColor3 = Color3.fromRGB(255, 215, 0)
        image.TextScaled = true
        image.Font = Enum.Font.GothamBold
        image.Parent = imageFrame
        
        -- Hover effects
        card.MouseEnter:Connect(function()
            local tween = TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(60, 60, 65)
            })
            tween:Play()
        end)
        
        card.MouseLeave:Connect(function()
            local tween = TweenService:Create(card, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(50, 50, 55)
            })
            tween:Play()
        end)
        
        -- Click to equip weapon
        card.MouseButton1Click:Connect(function()
            Weapons.equip(constants.ID, true) -- true = notify server
            currentWeapon = constants.ID
            updateCurrentWeaponDisplay()
            showMainView() -- Return to main view
        end)
        
        layoutOrder = layoutOrder + 1
        table.insert(cards, card)
    end
    
    -- Create main ScreenGui
    gui = Grid.create("LoadoutGui", cards)
    local mainFrame = gui.MainFrame
    local scrollFrame = mainFrame.ScrollFrame
    scrollFrame.Visible = false
    local header = mainFrame.Header
    local backButton = header.BackButton
    local closeButton = header.CloseButton
            
    backButton.MouseButton1Click:Connect(function()
        showMainView()
    end)

    closeButton.MouseButton1Click:Connect(function()
        Loadout.hide()
    end)
    
    -- Header title
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -100, 1, 0)
    titleLabel.Position = UDim2.new(0, 50, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🔫 LOADOUT"
    titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
    titleLabel.TextScaled = true
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Center
    titleLabel.Parent = header
    
    -- Create content area (below header)
    local contentFrame = Instance.new("Frame")
    contentFrame.Name = "ContentFrame"
    contentFrame.Size = UDim2.new(1, -20, 1, -HEADER_HEIGHT - 20)
    contentFrame.Position = UDim2.new(0, 10, 0, HEADER_HEIGHT + 10)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = mainFrame
    
    -- Create weapon selection frame (left side)
    local weaponFrame = Instance.new("Frame")
    weaponFrame.Name = "WeaponFrame"
    weaponFrame.Size = UDim2.new(0.25, 0, 0.8, 0)
    weaponFrame.Position = UDim2.new(0.02, 0, 0.1, 0)
    weaponFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    weaponFrame.BorderSizePixel = 0
    weaponFrame.Parent = contentFrame
    
    local weaponFrameCorner = Instance.new("UICorner")
    weaponFrameCorner.CornerRadius = UDim.new(0, 8)
    weaponFrameCorner.Parent = weaponFrame
    
    -- Weapon frame title
    local weaponTitle = Instance.new("TextLabel")
    weaponTitle.Name = "WeaponTitle"
    weaponTitle.Size = UDim2.new(1, -10, 0, 30)
    weaponTitle.Position = UDim2.new(0, 5, 0, 5)
    weaponTitle.BackgroundTransparency = 1
    weaponTitle.Text = "PRIMARY"
    weaponTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    weaponTitle.TextScaled = true
    weaponTitle.Font = Enum.Font.GothamBold
    weaponTitle.TextXAlignment = Enum.TextXAlignment.Center
    weaponTitle.Parent = weaponFrame
    
    -- Create current weapon display (clickable to open weapon selection)
     local currentWeaponButton = Instance.new("TextButton")
     currentWeaponButton.Name = "CurrentWeaponButton"
     currentWeaponButton.Size = UDim2.new(1, -10, 1, -40) -- Account for title and padding
     currentWeaponButton.Position = UDim2.new(0, 5, 0, 35) -- Below title
     currentWeaponButton.BackgroundColor3 = Color3.fromRGB(50, 50, 55)
     currentWeaponButton.BorderSizePixel = 0
     currentWeaponButton.Text = ""
     currentWeaponButton.Parent = weaponFrame
     
     local currentWeaponCorner = Instance.new("UICorner")
     currentWeaponCorner.CornerRadius = UDim.new(0, 6)
     currentWeaponCorner.Parent = currentWeaponButton
     
     -- Current weapon display content
     local weaponDisplayFrame = Instance.new("Frame")
     weaponDisplayFrame.Name = "WeaponDisplay"
     weaponDisplayFrame.Size = UDim2.new(1, 0, 1, 0)
     weaponDisplayFrame.BackgroundTransparency = 1
     weaponDisplayFrame.Parent = currentWeaponButton
     
     -- Weapon icon (large)
     local weaponIcon = Instance.new("TextLabel")
     weaponIcon.Name = "WeaponIcon"
     weaponIcon.Size = UDim2.new(0, 60, 0, 60)
     weaponIcon.Position = UDim2.new(0.5, -30, 0, 20)
     weaponIcon.BackgroundTransparency = 1
     weaponIcon.Text = "🔫"
     weaponIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
     weaponIcon.TextScaled = true
     weaponIcon.Font = Enum.Font.GothamBold
     weaponIcon.Parent = weaponDisplayFrame
     
     -- Weapon name
     weaponNameLabel = Instance.new("TextLabel")
     weaponNameLabel.Name = "WeaponName"
     weaponNameLabel.Size = UDim2.new(1, -10, 0, 30)
     weaponNameLabel.Position = UDim2.new(0, 5, 1, -40)
     weaponNameLabel.BackgroundTransparency = 1
     weaponNameLabel.Text = "Assault Rifle"
     weaponNameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
     weaponNameLabel.TextScaled = true
     weaponNameLabel.Font = Enum.Font.Gotham
     weaponNameLabel.TextXAlignment = Enum.TextXAlignment.Center
     weaponNameLabel.Parent = weaponDisplayFrame
     
     -- Change weapon text
     local changeText = Instance.new("TextLabel")
     changeText.Name = "ChangeText"
     changeText.Size = UDim2.new(1, -10, 0, 20)
     changeText.Position = UDim2.new(0, 5, 1, -60)
     changeText.BackgroundTransparency = 1
     changeText.Text = "Click to change"
     changeText.TextColor3 = Color3.fromRGB(150, 150, 150)
     changeText.TextScaled = true
     changeText.Font = Enum.Font.Gotham
     changeText.TextXAlignment = Enum.TextXAlignment.Center
     changeText.Parent = weaponDisplayFrame
     
     -- Hover effect for weapon button
     currentWeaponButton.MouseEnter:Connect(function()
         local tween = TweenService:Create(currentWeaponButton, TweenInfo.new(0.2), {
             BackgroundColor3 = Color3.fromRGB(60, 60, 65)
         })
         tween:Play()
     end)
     
     currentWeaponButton.MouseLeave:Connect(function()
         local tween = TweenService:Create(currentWeaponButton, TweenInfo.new(0.2), {
             BackgroundColor3 = Color3.fromRGB(50, 50, 55)
         })
         tween:Play()
     end)

    -- Function to show weapon selection view
    local function showWeaponSelectionView()
        currentView = "weapons"
        
        -- Update title
        titleLabel.Text = "🔫 SELECT WEAPON"
        local mainFrame = gui.MainFrame
        local header = mainFrame.Header
        local scrollFrame = mainFrame.ScrollFrame
        local contentFrame = mainFrame.ContentFrame
        local backButton = header.BackButton
        backButton.Visible = true
        scrollFrame.Visible = true
        contentFrame.Visible = false
    end
     
     -- Connect current weapon button click
     currentWeaponButton.MouseButton1Click:Connect(function()
         showWeaponSelectionView()
     end)
     
     -- Initialize current weapon display
     updateCurrentWeaponDisplay()
     
     -- Create character display frame (center area, adjusted position)
     local characterFrame = Instance.new("Frame")
     characterFrame.Name = "CharacterFrame"
     characterFrame.Size = UDim2.new(0.4, 0, 0.8, 0)
     characterFrame.Position = UDim2.new(0.3, 0, 0.1, 0)
     characterFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
     characterFrame.BorderSizePixel = 0
     characterFrame.Parent = contentFrame
     
     local charFrameCorner = Instance.new("UICorner")
     charFrameCorner.CornerRadius = UDim.new(0, 8)
     charFrameCorner.Parent = characterFrame
    
    -- Create ViewportFrame for character rendering
    local viewportFrame = Instance.new("ViewportFrame")
    viewportFrame.Name = "CharacterViewport"
    viewportFrame.Size = UDim2.new(1, -10, 1, -10)
    viewportFrame.Position = UDim2.new(0, 5, 0, 5)
    viewportFrame.BackgroundTransparency = 1
    viewportFrame.Parent = characterFrame
    
         -- Setup character in viewport
     local function setupCharacterInViewport()
         local character = player.Character
         if not character then
             return
         end
         
         -- Wait for character to be fully loaded
         local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 5)
         if not humanoidRootPart then
             return
         end
         
         -- Set character as archivable so it can be cloned
         character.Archivable = true
         
         -- Clone the character for the viewport
         local characterClone = character:Clone()
         if not characterClone then
             return
         end
         
         character.Archivable = false
         
         characterClone.Name = "LoadoutCharacter"
        
         for _, child in pairs(characterClone:GetDescendants()) do
             if child:IsA("Script") or child:IsA("LocalScript") or child:IsA("ModuleScript") then
                 if child.Name ~= "Animate" then
                     child:Destroy()
                 end
             end
         end
         
         -- Keep humanoid active but prevent movement
         local humanoid = characterClone:FindFirstChild("Humanoid")
         if humanoid then
             humanoid.PlatformStand = false -- Allow animations
             humanoid.Sit = false
             humanoid.WalkSpeed = 0 -- Prevent walking
             humanoid.JumpPower = 0 -- Prevent jumping
         end
        
        characterClone.Parent = viewportFrame
        
        -- Create camera for viewport
        local camera = Instance.new("Camera")
        camera.Parent = viewportFrame
        viewportFrame.CurrentCamera = camera
        
                 -- Position camera to show full character from front
         local clonedHumanoidRootPart = characterClone:FindFirstChild("HumanoidRootPart")
        if clonedHumanoidRootPart then
             -- Center the character at origin and face forward (towards camera)
             -- Rotate 180 degrees to face the camera
             clonedHumanoidRootPart.CFrame = CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(180), 0)
             
             -- Position camera in front of character to show full body
             local cameraPosition = Vector3.new(0, 0, 8) -- 8 studs in front
             local lookAtPosition = Vector3.new(0, 0, 0) -- Look at character center
             
             camera.CFrame = CFrame.lookAt(cameraPosition, lookAtPosition)
             camera.FieldOfView = 50 -- Wider field of view to show full character             
             -- Setup live character sync
             local function syncCharacterPose()
                 local realCharacter = player.Character
                 if not realCharacter then return end
                 
                 local realRoot = realCharacter:FindFirstChild("HumanoidRootPart")
                 if not realRoot then return end
                 
                 for _, part in pairs(characterClone:GetDescendants()) do
                     if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
                         local realPart = realCharacter:FindFirstChild(part.Name, true)
                         if realPart and realPart:IsA("BasePart") then
                             local relativeCFrame = realRoot.CFrame:Inverse() * realPart.CFrame
                             part.CFrame = clonedHumanoidRootPart.CFrame * relativeCFrame
                         end
                     end
                 end
                 
                 for _, accessory in pairs(realCharacter:GetChildren()) do
                     if accessory:IsA("Accessory") then
                         local clonedAccessory = characterClone:FindFirstChild(accessory.Name)
                         if clonedAccessory and clonedAccessory:IsA("Accessory") then
                             local realHandle = accessory:FindFirstChild("Handle")
                             local clonedHandle = clonedAccessory:FindFirstChild("Handle")
                             if realHandle and clonedHandle then
                                 local relativeCFrame = realRoot.CFrame:Inverse() * realHandle.CFrame
                                 clonedHandle.CFrame = clonedHumanoidRootPart.CFrame * relativeCFrame
                             end
                         end
                     end
                 end
             end
             
             if liveUpdateConnection then
                 liveUpdateConnection:Disconnect()
             end
             liveUpdateConnection = RunService.Heartbeat:Connect(syncCharacterPose)
             
        end
     end
    
         -- Setup character when GUI is created
     if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
         setupCharacterInViewport()
     else
         -- Wait for character to load if not ready
         local connection
         connection = player.CharacterAdded:Connect(function()
             if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                 setupCharacterInViewport()
                 connection:Disconnect()
             end
         end)
     end
     
          -- Update character when it respawns (disconnect previous connection if exists)
     if characterAddedConnection then
         characterAddedConnection:Disconnect()
     end
     characterAddedConnection = player.CharacterAdded:Connect(function()
         -- Small delay to ensure character is fully loaded
         task.wait(1)
         setupCharacterInViewport()
     end)
     
     -- Function to update current weapon display
     local function updateCurrentWeaponDisplay()
         local weaponData = WeaponConstants[currentWeapon]
         if weaponData then
             weaponNameLabel.Text = weaponData.DISPLAY_NAME or currentWeapon
             -- You can update the icon here when weapon-specific icons are available
         end
     end
     
          -- Initialize current weapon display
     updateCurrentWeaponDisplay()
     
     return gui
 end
 
 function Loadout.show()
    Util.hideDefaultGuis()
    if loadoutGui then
        loadoutGui.Enabled = true
        return
    end
    
    loadoutGui = createLoadoutGui()
    print("loadoutGui", loadoutGui)
    
    -- Hide other core GUIs for immersion
    pcall(function()
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, false)
        StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    end)
end

function Loadout.hide()
    Util.showDefaultGuis()
    
    if loadoutGui then
        loadoutGui:Destroy()
        loadoutGui = nil
    end
    
    -- Stop live character updates
    if liveUpdateConnection then
        liveUpdateConnection:Disconnect()
        liveUpdateConnection = nil
    end
    
    -- Disconnect character added connection
    if characterAddedConnection then
        characterAddedConnection:Disconnect()
        characterAddedConnection = nil
    end
end

function Loadout.toggle()
    if loadoutGui and loadoutGui.Enabled then
        Loadout.hide()
    else
        Loadout.show()
    end
end

-- Create loadout icon (called from game module)
function Loadout.createLoadoutIcon()
    local player = Players.LocalPlayer
    local playerGui = player:WaitForChild("PlayerGui")
    
    -- Create ScreenGui for the loadout icon
    local iconGui = Instance.new("ScreenGui")
    iconGui.Name = "LoadoutIconGui"
    iconGui.ResetOnSpawn = false
    iconGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    iconGui.DisplayOrder = 50
    iconGui.Parent = playerGui
    iconGui.IgnoreGuiInset = true
    
    -- Create the loadout icon button
    local loadoutIcon = Instance.new("TextButton")
    loadoutIcon.Name = "LoadoutIcon"
    loadoutIcon.Size = UDim2.new(0, 50, 0, 50)
    loadoutIcon.BackgroundColor3 = Color3.fromRGB(45, 45, 50)
    loadoutIcon.BorderSizePixel = 0
    loadoutIcon.Text = "🔫" -- Loadout icon
    loadoutIcon.TextColor3 = Color3.fromRGB(255, 215, 0)
    loadoutIcon.TextScaled = true
    loadoutIcon.Font = Enum.Font.GothamBold
    loadoutIcon.Parent = iconGui
    
    -- Make it round
    local iconCorner = Instance.new("UICorner")
    iconCorner.CornerRadius = UDim.new(0.5, 0)
    iconCorner.Parent = loadoutIcon
    
    -- Add border
    local iconStroke = Instance.new("UIStroke")
    iconStroke.Color = Color3.fromRGB(255, 215, 0)
    iconStroke.Thickness = 2
    iconStroke.Parent = loadoutIcon
    
    -- Add hover effects
    loadoutIcon.MouseEnter:Connect(function()
        local tween = TweenService:Create(loadoutIcon, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 55, 0, 55),
            BackgroundColor3 = Color3.fromRGB(55, 55, 60)
        })
        tween:Play()
        
        local strokeTween = TweenService:Create(iconStroke, TweenInfo.new(0.2), {
            Thickness = 3
        })
        strokeTween:Play()
    end)
    
    loadoutIcon.MouseLeave:Connect(function()
        local tween = TweenService:Create(loadoutIcon, TweenInfo.new(0.2), {
            Size = UDim2.new(0, 50, 0, 50),
            BackgroundColor3 = Color3.fromRGB(45, 45, 50)
        })
        tween:Play()
        
        local strokeTween = TweenService:Create(iconStroke, TweenInfo.new(0.2), {
            Thickness = 2
        })
        strokeTween:Play()
    end)
    
    -- Connect click to toggle loadout
    loadoutIcon.MouseButton1Click:Connect(function()
        Loadout.toggle()
    end)
    
    return iconGui
end

-- Initialize the shop (no longer creates icon automatically)
function Loadout.init()
    if not UserInputService.TouchEnabled or UserInputService.MouseEnabled then
        UserInputService.InputBegan:Connect(function(input, gameProcessed)
            if not gameProcessed and input.KeyCode == Enum.KeyCode.L then
                Loadout.toggle()
            end
        end)
    end
end

return Loadout 