local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local shootEvent = events:WaitForChild("ShootEvent")
local weaponSelectionEvent = events:WaitForChild("WeaponSelectionEvent")
local RandomSeedEvent = events:WaitForChild("RandomSeedEvent")

local Shotgun = require(script.shotgun)
local BossAttack = require(script.bossattack)
local AssaultRifle = require(script.assaultrifle)

-- Seed management for deterministic spread patterns
local currentSeed = tick()

-- Get current seed and increment it
local function getAndIncrementSeed()
    local seed = currentSeed
    currentSeed = currentSeed + 1
    return seed
end

local Weapons = {
	currentWeapon = nil,
	availableWeapons = {
		shotgun = Shotgun,
		bossattack = BossAttack,
		assaultrifle = AssaultRifle
	},
	activeBullets = {}, -- Table to store active bullet animations
	crosshair = nil, -- Store crosshair UI
}

-- Create dynamic crosshair that adjusts based on accuracy
local function createDynamicCrosshair()	
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui for crosshair
	local crosshairGui = Instance.new("ScreenGui")
	crosshairGui.Name = "CrosshairGui"
	crosshairGui.ResetOnSpawn = true
	crosshairGui.IgnoreGuiInset = true
	crosshairGui.Parent = playerGui
	
	-- Create main crosshair frame
	local crosshairFrame = Instance.new("Frame")
	crosshairFrame.Name = "DynamicCrosshair"
	crosshairFrame.Size = UDim2.new(0, 80, 0, 80) -- Larger frame to accommodate more spreading
	crosshairFrame.Position = UDim2.new(0.5, -40, 0.5, -40)
	crosshairFrame.BackgroundTransparency = 1
	crosshairFrame.Visible = true
	crosshairFrame.Parent = crosshairGui
	
	-- Create top vertical line
	local topLine = Instance.new("Frame")
	topLine.Name = "TopLine"
	topLine.Size = UDim2.new(0, 2, 0, 10)
	topLine.Position = UDim2.new(0.5, -1, 0.5, -12) -- Above center
	topLine.BackgroundColor3 = Color3.new(1, 1, 1)
	topLine.BackgroundTransparency = 0
	topLine.BorderSizePixel = 0
	topLine.Parent = crosshairFrame
	
	-- Create bottom vertical line
	local bottomLine = Instance.new("Frame")
	bottomLine.Name = "BottomLine"
	bottomLine.Size = UDim2.new(0, 2, 0, 10)
	bottomLine.Position = UDim2.new(0.5, -1, 0.5, 2) -- Below center
	bottomLine.BackgroundColor3 = Color3.new(1, 1, 1)
	bottomLine.BackgroundTransparency = 0
	bottomLine.BorderSizePixel = 0
	bottomLine.Parent = crosshairFrame
	
	-- Create left horizontal line
	local leftLine = Instance.new("Frame")
	leftLine.Name = "LeftLine"
	leftLine.Size = UDim2.new(0, 10, 0, 2)
	leftLine.Position = UDim2.new(0.5, -12, 0.5, -1) -- Left of center
	leftLine.BackgroundColor3 = Color3.new(1, 1, 1)
	leftLine.BackgroundTransparency = 0
	leftLine.BorderSizePixel = 0
	leftLine.Parent = crosshairFrame
	
	-- Create right horizontal line
	local rightLine = Instance.new("Frame")
	rightLine.Name = "RightLine"
	rightLine.Size = UDim2.new(0, 10, 0, 2)
	rightLine.Position = UDim2.new(0.5, 2, 0.5, -1) -- Right of center
	rightLine.BackgroundColor3 = Color3.new(1, 1, 1)
	rightLine.BackgroundTransparency = 0
	rightLine.BorderSizePixel = 0
	rightLine.Parent = crosshairFrame
	
	return crosshairGui
end

-- Update crosshair spread based on accuracy
local function updateCrosshairSpread(crosshairGui, accuracy)
	if not crosshairGui then
		return
	end
	
	local crosshairFrame = crosshairGui:FindFirstChild("DynamicCrosshair")
	if not crosshairFrame then
		return
	end
	
	local topLine = crosshairFrame:FindFirstChild("TopLine")
	local bottomLine = crosshairFrame:FindFirstChild("BottomLine")
	local leftLine = crosshairFrame:FindFirstChild("LeftLine")
	local rightLine = crosshairFrame:FindFirstChild("RightLine")
	
	if not topLine or not bottomLine or not leftLine or not rightLine then
		return
	end
	
	-- Calculate spread distance based on accuracy (0 = max spread, 1 = no spread)
	local maxSpread = 25 -- Increased maximum pixels the crosshair lines can spread apart
	local spreadDistance = maxSpread * (1 - accuracy)
	
	-- Update top line position (move up from center)
	topLine.Position = UDim2.new(0.5, -1, 0.5, -12 - spreadDistance/2)
	
	-- Update bottom line position (move down from center)
	bottomLine.Position = UDim2.new(0.5, -1, 0.5, 2 + spreadDistance/2)
	
	-- Update left line position (move left from center)
	leftLine.Position = UDim2.new(0.5, -12 - spreadDistance/2, 0.5, -1)
	
	-- Update right line position (move right from center)
	rightLine.Position = UDim2.new(0.5, 2 + spreadDistance/2, 0.5, -1)
end

-- Calculate player velocity
local function calculatePlayerVelocity()
	local player = Players.LocalPlayer
	local character = player.Character
	if not character or not character.PrimaryPart then
		return Vector3.new(0, 0, 0)
	end
	
	-- Use HumanoidRootPart velocity for accurate movement speed
	local velocity = character.PrimaryPart.Velocity
	
	return velocity
end

-- Centralized bullet animation system and accuracy tracking
local function updateBullets(deltaTime)
	for bulletId, bulletData in pairs(Weapons.activeBullets) do
		if bulletData.update then
			bulletData.update(deltaTime)
		end
	end
end

-- Start the central heartbeat for bullet animations
RunService.Heartbeat:Connect(updateBullets)

-- Handle weapon selection events from server or local UI
weaponSelectionEvent.OnClientEvent:Connect(function(weaponType)
	Weapons.equip(weaponType)
end)

function Weapons.handleFireFromClient()
	if not Weapons.currentWeapon then
		return
	end
	
	-- Calculate firing direction from camera
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	
	local direction = camera.CFrame.LookVector
	local startPosition = camera.CFrame.Position + direction * 2
	
	local weapon = Weapons.availableWeapons[Weapons.currentWeapon]

	local seed = getAndIncrementSeed()
	
	-- Delegate complete firing logic to the individual weapon with seed and direction
	local hits, bulletAnimations = weapon.handleFireFromClient(direction, startPosition, seed)

	print(#hits)
	
	-- Handle bullet animations returned from weapon
	for bulletId, bulletData in pairs(bulletAnimations) do
		Weapons.activeBullets[bulletId] = bulletData
	end
	
	-- Send hits and direction to server if any
	if #hits > 0 then
		shootEvent:FireServer(hits, direction, startPosition, seed)
	end
end

function Weapons.handleFireFromServer(weaponType, bullets)
	local weapon = Weapons.availableWeapons[weaponType]
	
	-- Delegate server bullet handling to the individual weapon
	local bulletAnimations = weapon.handleFireFromServer(bullets)
	
	-- Handle bullet animations returned from weapon
	for bulletId, bulletData in pairs(bulletAnimations) do
		Weapons.activeBullets[bulletId] = bulletData
	end
end

function Weapons.init()
	
	-- Equip default weapon
	local currentWeaponType = Weapons.currentWeapon or "shotgun"
	Weapons.equip(currentWeaponType, true)
	
	-- Handle character respawning - cleanup crosshair
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(function()
		if Weapons.crosshair then
			Weapons.crosshair:Destroy()
			Weapons.crosshair = nil
		end
	end)

	player.CharacterAdded:Connect(function(character)
		if Weapons.crosshair then
			Weapons.crosshair:Destroy()
		end
		Weapons.crosshair = createDynamicCrosshair()

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if Weapons.crosshair then
				Weapons.crosshair:Destroy()
			end
		end)
	end)
	-- Handle shooting input with continuous firing support
	local isMouseDown = false
	local isTouchDown = false
	
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		-- Touch input handling
		UserInputService.TouchTap:Connect(function(touchPositions, processedByUI)
			if not processedByUI then
				Weapons.handleFireFromClient()
			end
		end)
		
		UserInputService.TouchStarted:Connect(function(touch, processedByUI)
			if not processedByUI then
				isTouchDown = true
				-- Start continuous firing
				task.spawn(function()
					while isTouchDown do
						Weapons.handleFireFromClient()
						task.wait() -- Wait one frame
					end
				end)
			end
		end)
		
		UserInputService.TouchEnded:Connect(function(touch, processedByUI)
			isTouchDown = false
		end)
	else
		-- Mouse input handling
		UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.MouseButton1 then
				isMouseDown = true
				-- Start continuous firing
				task.spawn(function()
					while isMouseDown do
						Weapons.handleFireFromClient()
						task.wait() -- Wait one frame
					end
				end)
			end
		end)
		
		UserInputService.InputEnded:Connect(function(input, gameProcessedEvent)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				isMouseDown = false
			end
		end)
	end

	-- Handle incoming bullet events from server
	shootEvent.OnClientEvent:Connect(function(data)
		if data.action == "create" then
			Weapons.handleFireFromServer(
				data.weaponType,
				data.bullets
			)
		elseif data.action == "destroy" then
			Weapons.activeBullets[bulletId] = nil
		end
	end)
end

function Weapons.equip(weaponType, notifyServer)
	print("Equipping weapon:", weaponType)
	-- Unequip current weapon if any
	if Weapons.currentWeapon then
		print("Unequipping current weapon:", Weapons.currentWeapon)
		Weapons.availableWeapons[Weapons.currentWeapon].unequip()
	end

	-- Equip new weapon
	local weapon = Weapons.availableWeapons[weaponType]
	print("Weapon:", weapon)

	if not weapon then
		return
	end

	Weapons.currentWeapon = weaponType
	
	if not Weapons.crosshair then
		Weapons.crosshair = createDynamicCrosshair()
	end
	
	if notifyServer then
		weaponSelectionEvent:FireServer(weaponType)
	end

	weapon.equip()
end

return Weapons