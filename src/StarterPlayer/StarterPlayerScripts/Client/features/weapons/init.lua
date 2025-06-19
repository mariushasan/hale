local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local TimeSync = require(game.ReplicatedStorage.shared.TimeSync)
local shootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local weaponSelectionEvent = ReplicatedStorage:WaitForChild("WeaponSelectionEvent")

local Shotgun = require(script.shotgun)
local BossAttack = require(script.bossattack)
local WeaponSelector = require(script.ui.WeaponSelector)
local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)
local BossAttackConstants = require(ReplicatedStorage.features.weapons.bossattack.constants)
local WeaponsConstants = require(ReplicatedStorage.features.weapons.constants)

local Weapons = {
	currentWeapon = nil,
	currentWeaponType = nil,
	availableWeapons = {
		shotgun = Shotgun,
		bossattack = BossAttack
	},
	activeBullets = {}, -- Table to store active bullet animations
	lastFireTime = 0,
	bulletCounter = 0,
	isBoss = false, -- Track boss status
	crosshair = nil -- Store crosshair UI
}

-- Simple crosshair creation without animations (fallback)
local function createSimpleCrosshair()
	print("Creating simple crosshair (fallback)") -- Debug print
	
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create ScreenGui for crosshair
	local crosshairGui = Instance.new("ScreenGui")
	crosshairGui.Name = "SimpleCrosshairGui"
	crosshairGui.ResetOnSpawn = false
	crosshairGui.IgnoreGuiInset = true
	crosshairGui.Parent = playerGui
	
	-- Create main crosshair frame
	local crosshairFrame = Instance.new("Frame")
	crosshairFrame.Name = "SimpleCrosshair"
	crosshairFrame.Size = UDim2.new(0, 20, 0, 20)
	crosshairFrame.Position = UDim2.new(0.5, -10, 0.5, -10)
	crosshairFrame.BackgroundTransparency = 1
	crosshairFrame.Visible = true
	crosshairFrame.Parent = crosshairGui
	
	-- Create vertical line
	local verticalLine = Instance.new("Frame")
	verticalLine.Name = "VerticalLine"
	verticalLine.Size = UDim2.new(0, 2, 0, 12)
	verticalLine.Position = UDim2.new(0.5, -1, 0.5, -6)
	verticalLine.BackgroundColor3 = Color3.new(1, 1, 1)
	verticalLine.BackgroundTransparency = 0 -- Make it immediately visible
	verticalLine.BorderSizePixel = 0
	verticalLine.Parent = crosshairFrame
	
	-- Create horizontal line
	local horizontalLine = Instance.new("Frame")
	horizontalLine.Name = "HorizontalLine"
	horizontalLine.Size = UDim2.new(0, 12, 0, 2)
	horizontalLine.Position = UDim2.new(0.5, -6, 0.5, -1)
	horizontalLine.BackgroundColor3 = Color3.new(1, 1, 1)
	horizontalLine.BackgroundTransparency = 0 -- Make it immediately visible
	horizontalLine.BorderSizePixel = 0
	horizontalLine.Parent = crosshairFrame
	
	-- Add outline effect
	for _, line in pairs({verticalLine, horizontalLine}) do
		local outline = Instance.new("UIStroke")
		outline.Color = Color3.new(0, 0, 0)
		outline.Thickness = 1
		outline.Parent = line
	end
	
	print("Simple crosshair created successfully") -- Debug print
	return crosshairGui
end

-- Show crosshair with fade-in effect
local function showCrosshair()
	print("showCrosshair() called") -- Debug print
	
	-- Try simple crosshair first for debugging
	if not Weapons.crosshair then
		print("Creating new crosshair") -- Debug print
		Weapons.crosshair = createSimpleCrosshair() -- Use simple version for now
	end
	
	-- Make sure it's visible
	local crosshairFrame = Weapons.crosshair:FindFirstChild("SimpleCrosshair")
	if crosshairFrame then
		print("Simple crosshair frame found, ensuring visibility") -- Debug print
		crosshairFrame.Visible = true
	else
		print("ERROR: Simple crosshair frame not found!") -- Debug print
	end
end

-- Hide crosshair with fade-out effect
local function hideCrosshair()
	print("hideCrosshair() called") -- Debug print
	
	if Weapons.crosshair then
		local crosshairFrame = Weapons.crosshair:FindFirstChild("Crosshair")
		if crosshairFrame then
			print("Hiding crosshair frame") -- Debug print
			
			-- Tween to invisible
			for _, line in pairs(crosshairFrame:GetChildren()) do
				if line:IsA("Frame") then
					local tween = TweenService:Create(line, TweenInfo.new(0.2), {BackgroundTransparency = 1})
					tween:Play()
				end
			end
			
			-- Hide after animation completes (using spawn to avoid yielding)
			task.spawn(function()
				task.wait(0.25)
				if crosshairFrame then
					crosshairFrame.Visible = false
				end
			end)
		end
	end
end

-- Cleanup crosshair
local function cleanupCrosshair()
	if Weapons.crosshair then
		Weapons.crosshair:Destroy()
		Weapons.crosshair = nil
	end
end

-- Get weapon constants based on weapon type
local function getWeaponConstants(weaponType)
	if weaponType == "shotgun" then
		return ShotgunConstants
	elseif weaponType == "bossattack" then
		return BossAttackConstants
	else
		return WeaponsConstants -- fallback to default constants
	end
end

-- Generate unique bullet ID on client
local function generateBulletId()
	Weapons.bulletCounter = Weapons.bulletCounter + 1
	local player = Players.LocalPlayer
	return player.Name .. "_" .. Weapons.bulletCounter .. "_" .. tick()
end

-- Centralized bullet animation system
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
	print("Server requested weapon change to:", weaponType)
	Weapons.isBoss = weaponType == "bossattack"
	
	if Weapons.isBoss then
		-- Player became boss - equip boss attack weapon
		print("You are now the BOSS! Left-click to perform melee attacks!")
	else
		-- Player is no longer boss or switched to different weapon
		if weaponType == "shotgun" then
			print("Equipped shotgun weapon.")
		else
			print("Equipped weapon:", weaponType)
		end
	end
	
	-- Equip the requested weapon
	Weapons.equip(weaponType)
end)

function Weapons.init()
	-- Initialize weapon selector
	WeaponSelector.init(Weapons)
	
	-- Equip default weapon
	Weapons.equip("shotgun", false)
	
	-- Handle character respawning - cleanup crosshair
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(function()
		cleanupCrosshair()
	end)
	
	player.CharacterAdded:Connect(function()
		-- Small delay to ensure character is fully loaded
		task.wait(1)
		-- Re-equip default weapon after respawn
		Weapons.equip("shotgun", false)
	end)

	-- Handle shooting input
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		UserInputService.TouchTap:Connect(function(touchPositions, processedByUI)
			if not processedByUI then
				Weapons.handleFire()
			end
		end)
	else
		UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.MouseButton1 then
				Weapons.handleFire()
			end
		end)
	end

	-- Handle incoming bullet events from server
	shootEvent.OnClientEvent:Connect(function(data)
		if data.action == "create" and data.bulletData then
			local bulletData = data.bulletData
			-- Fire using the actual shooter's weapon type, position, direction, and spread directions
			Weapons.fire(
				bulletData.id,
				bulletData.weaponType,
				bulletData.currentPosition,
				bulletData.direction,
				bulletData.spreadDirections
			)
		elseif data.action == "destroy" and data.bulletId then
			-- Remove the bullet from active bullets
			Weapons.removeBullet(data.bulletId)
		end
	end)
end

function Weapons.handleFire()
	if not Weapons.currentWeapon or not Weapons.currentWeaponType then
		return
	end
	
	local weaponConstants = getWeaponConstants(Weapons.currentWeaponType)
	local currentTime = tick()
	local fireRate = weaponConstants.FIRE_COOLDOWN or weaponConstants.COOLDOWN or 0.5
	
	if currentTime - Weapons.lastFireTime >= fireRate then
		Weapons.lastFireTime = currentTime
		
		-- Calculate local firing parameters
		local camera = workspace.CurrentCamera
		if camera then
			local direction = camera.CFrame.LookVector
			local startPosition = camera.CFrame.Position + direction * 2
			local bulletId = generateBulletId()
			Weapons.fire(bulletId, Weapons.currentWeaponType, startPosition, direction)
		end
	end
end

function Weapons.equip(weaponType, notifyServer)
	print("Weapons.equip() called with weaponType:", weaponType) -- Debug print
	
	-- Unequip current weapon if any
	if Weapons.currentWeapon then
		Weapons.currentWeapon.unequip()
	end

	-- Equip new weapon
	local weapon = Weapons.availableWeapons[weaponType]
	if weapon then
		print("Weapon found, equipping:", weaponType) -- Debug print
		Weapons.currentWeapon = weapon
		Weapons.currentWeaponType = weaponType
		weapon.equip()
		
		-- Show crosshair when weapon is equipped
		print("About to show crosshair") -- Debug print
		showCrosshair()
		
		-- Notify server of weapon change if requested (for UI-initiated changes)
		if notifyServer then
			weaponSelectionEvent:FireServer(weaponType)
		end
	else
		print("ERROR: Weapon not found:", weaponType) -- Debug print
	end
end

-- Function for UI-initiated weapon changes (notifies server)
function Weapons.equipLocal(weaponType)
	Weapons.equip(weaponType, true)
end

function Weapons.unequip()
	if Weapons.currentWeapon then
		Weapons.currentWeapon.unequip()
		Weapons.currentWeapon = nil
		Weapons.currentWeaponType = nil
		
		-- Hide crosshair when weapon is unequipped
		hideCrosshair()
	end
end

function Weapons.fire(bulletId, weaponType, startPosition, direction)
	local weapon = Weapons.availableWeapons[weaponType]
	if weapon then
		-- Get the animation function for the bullets
		local updateBullet = weapon.animateBullet(startPosition, direction)
		
		if bulletId then
			Weapons.activeBullets[bulletId] = {
				update = updateBullet
			}
		end
		
		-- Check if this is a local firing (bullet ID starts with local player's name)
		local player = Players.LocalPlayer
		if bulletId and bulletId:find("^" .. player.Name .. "_") then
			-- Perform client-side raycast to detect what we hit
			local camera = workspace.CurrentCamera
			local raycastParams = RaycastParams.new()
			raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
			raycastParams.FilterDescendantsInstances = {player.Character}
			
			-- Raycast in the direction we're shooting
			local raycastDistance = 1000 -- Max shooting distance
			local raycastResult = workspace:Raycast(startPosition, direction * raycastDistance, raycastParams)
			
			local hitPart = nil
			local hitPosition = nil
			
			if raycastResult then
				hitPart = raycastResult.Instance
				hitPosition = raycastResult.Position
			end
			
			-- Send shoot event to server with hit information instead of reference position
			shootEvent:FireServer(bulletId, startPosition, {hitPart = hitPart, hitPosition = hitPosition}, direction)
			
			-- Then play weapon effects (animations, sounds, etc.)
			weapon.fire(startPosition, direction)
		end
	end
end

-- Function to remove a bullet animation
function Weapons.removeBullet(bulletId)
	Weapons.activeBullets[bulletId] = nil
end

return Weapons