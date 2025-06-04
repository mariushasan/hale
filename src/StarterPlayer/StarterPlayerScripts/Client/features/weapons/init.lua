local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local shootEvent = ReplicatedStorage:WaitForChild("ShootEvent")

local Shotgun = require(script.shotgun)
local WeaponSelector = require(script.ui.WeaponSelector)
local ShotgunConstants = require(ReplicatedStorage.features.weapons.shotgun.constants)

local Weapons = {
	currentWeapon = nil,
	availableWeapons = {
		shotgun = Shotgun
	},
	activeBullets = {}, -- Table to store active bullet animations
	lastFireTime = 0
}

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

function Weapons.initialize()
	-- Initialize weapon selector
	WeaponSelector.initialize(Weapons)

	-- Handle shooting input
	if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		UserInputService.TouchTap:Connect(function(touchPositions, processedByUI)
			if not processedByUI then
				local currentTime = tick()
				if currentTime - Weapons.lastFireTime >= ShotgunConstants.FIRE_COOLDOWN then
					Weapons.lastFireTime = currentTime
					Weapons.fire(1)
				end
			end
		end)
	else
		UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
			if not gameProcessedEvent and input.UserInputType == Enum.UserInputType.MouseButton1 then
				local currentTime = tick()
				if currentTime - Weapons.lastFireTime >= ShotgunConstants.FIRE_COOLDOWN then
					Weapons.lastFireTime = currentTime
					Weapons.fire(1)
				end
			end
		end)
	end

	-- Handle incoming bullet events from server
	shootEvent.OnClientEvent:Connect(function(data)
		if data.action == "create" and data.bulletData then
			local bulletData = data.bulletData
			local weapon = Weapons.availableWeapons[bulletData.weaponType]
			weapon.fire()
		end
	end)
end

function Weapons.equip(weaponType)
	-- Unequip current weapon if any
	if Weapons.currentWeapon then
		Weapons.currentWeapon.unequip()
	end

	-- Equip new weapon
	local weapon = Weapons.availableWeapons[weaponType]
	if weapon then
		Weapons.currentWeapon = weapon
		weapon.equip()
	end
end

function Weapons.unequip()
	if Weapons.currentWeapon then
		Weapons.currentWeapon.unequip()
		Weapons.currentWeapon = nil
	end
end

function Weapons.fire(bulletId)
	if Weapons.currentWeapon and Weapons.currentWeapon.fire then
		-- Get the animation function for the bullets first
		local updateBullet = Weapons.currentWeapon.animateBullet()
		
		Weapons.activeBullets[bulletId] = {
			update = updateBullet
		}
		
		-- Fire the weapon locally after bullets are created and moving
		local camera = workspace.CurrentCamera
		if not camera then return end
		
		-- Create bullets with spread
		local direction = camera.CFrame.LookVector
		local startPosition = camera.CFrame.Position + direction * 2
		local fireTimestamp = tick()

		Weapons.currentWeapon.fire(startPosition, direction)

		-- Send shoot event to server with complete bullet data and timestamp
		shootEvent:FireServer(startPosition, direction, fireTimestamp)
	end
end

-- Function to remove a bullet animation
function Weapons.removeBullet(bulletId)
	Weapons.activeBullets[bulletId] = nil
end

return Weapons