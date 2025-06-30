local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local shootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local weaponSelectionEvent = ReplicatedStorage:WaitForChild("WeaponSelectionEvent")

local Shotgun = require(script.shotgun)
local BossAttack = require(script.bossattack)
local WeaponSelector = require(script.ui.WeaponSelector)
local WeaponConstants = require(ReplicatedStorage.features.weapons)

local Weapons = {
	currentWeapon = nil,
	availableWeapons = {
		shotgun = Shotgun,
		bossattack = BossAttack
	},
	activeBullets = {}, -- Table to store active bullet animations
	lastFireTime = 0,
	bulletCounter = 0,
	crosshair = nil -- Store crosshair UI
}

-- Damage animation system
local function createDamageGui()
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	
	-- Create or get existing damage GUI
	local damageGui = playerGui:FindFirstChild("DamageGui")
	if not damageGui then
		damageGui = Instance.new("ScreenGui")
		damageGui.Name = "DamageGui"
		damageGui.ResetOnSpawn = false
		damageGui.IgnoreGuiInset = true
		damageGui.Parent = playerGui
	end
	
	return damageGui
end

local function showDamageNumber(totalDamage, hitPosition)
	local damageGui = createDamageGui()
	local camera = workspace.CurrentCamera
	
	-- Convert 3D position to screen position
	local screenPosition, onScreen = camera:WorldToScreenPoint(hitPosition)
	
	if not onScreen then
		-- If hit position is off-screen, show damage near crosshair
		screenPosition = Vector3.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2, 0)
	end
	
	-- Create damage label
	local damageLabel = Instance.new("TextLabel")
	damageLabel.Name = "DamageNumber"
	damageLabel.Size = UDim2.new(0, 100, 0, 40)
	damageLabel.Position = UDim2.new(0, screenPosition.X - 50, 0, screenPosition.Y - 20)
	damageLabel.BackgroundTransparency = 1
	damageLabel.Text = "-" .. totalDamage
	damageLabel.TextColor3 = Color3.fromRGB(255, 100, 100) -- Red damage color
	damageLabel.TextScaled = true
	damageLabel.Font = Enum.Font.GothamBold
	damageLabel.TextStrokeTransparency = 0
	damageLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	damageLabel.ZIndex = 1000
	damageLabel.Parent = damageGui
	
	-- Add text size constraint for better readability
	local textSizeConstraint = Instance.new("UITextSizeConstraint")
	textSizeConstraint.MaxTextSize = 36
	textSizeConstraint.MinTextSize = 18
	textSizeConstraint.Parent = damageLabel
	
	-- Animate the damage number
	local startScale = 0.5
	local peakScale = 1.2
	local endScale = 0.8
	
	-- Initial scale
	damageLabel.Size = UDim2.new(0, 100 * startScale, 0, 40 * startScale)
	
	-- Create animation sequence
	local scaleUpTween = TweenService:Create(damageLabel, 
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), 
		{
			Size = UDim2.new(0, 100 * peakScale, 0, 40 * peakScale),
			Position = UDim2.new(0, screenPosition.X - 50 * peakScale, 0, screenPosition.Y - 20 * peakScale - 20)
		}
	)
	
	local fadeOutTween = TweenService:Create(damageLabel,
		TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{
			Size = UDim2.new(0, 100 * endScale, 0, 40 * endScale),
			Position = UDim2.new(0, screenPosition.X - 50 * endScale, 0, screenPosition.Y - 20 * endScale - 60),
			TextTransparency = 1,
			TextStrokeTransparency = 1
		}
	)
	
	-- Play animations in sequence
	scaleUpTween:Play()
	scaleUpTween.Completed:Connect(function()
		fadeOutTween:Play()
		fadeOutTween.Completed:Connect(function()
			damageLabel:Destroy()
		end)
	end)
	
	-- Add some random horizontal drift for variety
	local driftTween = TweenService:Create(damageLabel,
		TweenInfo.new(0.95, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{
			Position = UDim2.new(0, screenPosition.X - 50 + math.random(-30, 30), 0, screenPosition.Y - 80)
		}
	)
	driftTween:Play()
end

-- Simple crosshair creation without animations (fallback)
local function createSimpleCrosshair()	
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
	
	return crosshairGui
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
	Weapons.equip(weaponType)
end)

function Weapons.init()
	-- Initialize weapon selector
	WeaponSelector.init(Weapons)
	
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
		print("data", data)
		if data.action == "create" then
			Weapons.fire(
				data.weaponType,
				data.bullets
			)
		elseif data.action == "destroy" then
			Weapons.activeBullets[bulletId] = nil
		end
	end)
end

function Weapons.handleFire()
	if not Weapons.currentWeapon then
		return
	end
	local weaponConstants = WeaponConstants[Weapons.currentWeapon]
	local weapon = Weapons.availableWeapons[Weapons.currentWeapon]
	local currentTime = tick()
	local fireRate = weaponConstants.FIRE_COOLDOWN or weaponConstants.COOLDOWN or 0.5
	
	if currentTime - Weapons.lastFireTime >= fireRate then
		Weapons.lastFireTime = currentTime
		-- Calculate local firing parameters
		local camera = workspace.CurrentCamera
		if camera then
			local direction = camera.CFrame.LookVector
			local startPosition = camera.CFrame.Position + direction * 2
			local directions = weapon.createSpreadPattern(startPosition, direction)
			for _, direction in ipairs(directions) do
				direction["id"] = generateBulletId()
			end
			Weapons.fire(Weapons.currentWeapon, directions)
		end
	end
end

function Weapons.equip(weaponType, notifyServer)	
	-- Unequip current weapon if any
	if Weapons.currentWeapon then
		Weapons.availableWeapons[Weapons.currentWeapon].unequip()
	end

	-- Equip new weapon
	local weapon = Weapons.availableWeapons[weaponType]

	if not weapon then
		print("Weapon not found:", weaponType)
		return
	end
	
	weapon.equip()
	Weapons.currentWeapon = weaponType
	
	if not weapon.hideCrosshair then
		Weapons.crosshair = createSimpleCrosshair()
	end
	
	if notifyServer then
		weaponSelectionEvent:FireServer(weaponType)
	end
end

function Weapons.fire(weaponType, bullets)
	local weapon = Weapons.availableWeapons[weaponType]
	local weaponConstants = WeaponConstants[weaponType]
	if weapon then
		-- Get the animation function for the bullets
		local hits = {}
		for _, bullet in ipairs(bullets) do			
			-- Check if this is a local firing (bullet ID starts with local player's name)
			local player = Players.LocalPlayer
			if bullet.id and bullet.id:find("^" .. player.Name .. "_") then
				-- Perform client-side raycast to detect what we hit
				local camera = workspace.CurrentCamera
				local raycastParams = RaycastParams.new()
				raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
				raycastParams.FilterDescendantsInstances = {player.Character}
				
				-- Raycast in the direction we're shooting
				local raycastDistance = 1000 -- Max shooting distance
				local raycastResult = workspace:Raycast(bullet.startPosition, bullet.direction * raycastDistance, raycastParams)
				local hitPart = nil
				local hitPosition = nil
				
				if raycastResult and raycastResult.Instance.Parent:FindFirstChildOfClass("Humanoid") then
					hitPart = raycastResult.Instance
					hitPosition = raycastResult.Position
				end
				
				table.insert(hits, {
					id = bullet.id,
					direction = bullet.direction,
					startPosition = bullet.startPosition,
					hitPart = hitPart,
					hitPosition = hitPosition
				})
				local maxDistance = weaponConstants.MAX_BULLET_DISTANCE
				local hitVector = hitPosition and hitPosition - bullet.startPosition
				if hitVector then
					maxDistance = hitVector.Magnitude
				end

				local updateBullet = weapon.animateBullet(bullet.startPosition, bullet.direction, maxDistance)
				if updateBullet then
					Weapons.activeBullets[bullet.id] = {
						update = updateBullet
					}
				end
			end
		end

		if #hits > 0 then
			-- Find the average hit position for damage display
			local avgHitPosition = Vector3.new(0, 0, 0)
			local validHits = 0
			for _, hit in ipairs(hits) do
				if hit.hitPosition then
					avgHitPosition = avgHitPosition + hit.hitPosition
					validHits = validHits + 1
				end
			end

			totalDamage = validHits * weaponConstants.DAMAGE_PER_BULLET
			
			if validHits > 0 then
				avgHitPosition = avgHitPosition / validHits
				showDamageNumber(totalDamage, avgHitPosition)
			end
			
			shootEvent:FireServer(hits)
		end
	end
end

return Weapons