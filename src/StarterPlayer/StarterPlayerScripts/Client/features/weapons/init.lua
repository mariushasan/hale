local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local events = ReplicatedStorage:WaitForChild("events")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local shootEvent = events:WaitForChild("ShootEvent")
local weaponSelectionEvent = events:WaitForChild("WeaponSelectionEvent")
local RandomSeedEvent = events:WaitForChild("RandomSeedEvent")
local WeaponConstants = require(ReplicatedStorage:WaitForChild("features"):WaitForChild("weapons"))

local Shotgun = require(script.shotgun)
local BossAttack = require(script.bossattack)
local AssaultRifle = require(script.assaultrifle)
local HitGui = require(script.ui.HitGui)

-- Seed management for deterministic spread patterns
local currentSeed = tick()
local gunStates = {}

-- Get current seed and increment it
local function getAndIncrementSeed()
    local seed = currentSeed
    currentSeed = currentSeed + 1
    return seed
end

local Weapons = {}

local availableWeapons = {
	shotgun = Shotgun,
	bossattack = BossAttack,
	AssaultRifle = AssaultRifle
}

local currentWeapon = nil
local bulletAnimations = {}
local crosshair = nil
local visualRig = nil
local cameraArmSyncConnection = nil
local currentHoldAnimationTrack = nil
local currentFireAnimationTrack = nil
local currentReloadAnimationTrack = nil
local visualRootPart = nil

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
	for _, updateFunction in pairs(bulletAnimations) do
		updateFunction(deltaTime)
	end
end

-- Start the central heartbeat for bullet animations
RunService.Heartbeat:Connect(updateBullets)

-- Handle weapon selection events from server or local UI
weaponSelectionEvent.OnClientEvent:Connect(function(weaponType)
	Weapons.equip(weaponType)
end)

function Weapons.handleFireFromClient()
	if not currentWeapon then
		return
	end

	print("1")

	local weaponConstants = WeaponConstants[currentWeapon]

	print("2")

	if not gunStates[currentWeapon] then
		gunStates[currentWeapon] = {
			clips = weaponConstants.STARTING_CLIPS,
			ammo = weaponConstants.CLIP_SIZE,
			reloading = false,
			lastFireTime = 0,
		}
	end

	print("3")

	local currentTime = tick()
    if not (currentTime - gunStates[currentWeapon].lastFireTime >= weaponConstants.FIRE_COOLDOWN) then
		print(currentTime - gunStates[currentWeapon].lastFireTime)
		print(weaponConstants.FIRE_COOLDOWN)
        return
    end

	print("4")

	if gunStates[currentWeapon].reloading then
		return
	end

	if gunStates[currentWeapon].ammo <= 0 and gunStates[currentWeapon].clips <= 0 then
		return
	end

	gunStates[currentWeapon].lastFireTime = currentTime

	print("5")

	if gunStates[currentWeapon].ammo <= 0 then
        gunStates[currentWeapon].reloading = true
        if currentReloadAnimationTrack then
            currentReloadAnimationTrack:Play()
        end
        task.spawn(function()
            wait(weaponConstants.RELOAD_TIME)
            gunStates[currentWeapon].ammo = weaponConstants.CLIP_SIZE
            gunStates[currentWeapon].clips = gunStates[currentWeapon].clips - 1
            gunStates[currentWeapon].reloading = false
        end)
        return
    end

	print("6")

	local weapon = availableWeapons[currentWeapon]

	gunStates[currentWeapon].ammo = gunStates[currentWeapon].ammo - 1

	print("7")

	local player = Players.LocalPlayer

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	local direction = camera.CFrame.LookVector
	local startPosition = camera.CFrame.Position + direction * 2

	local bullets = weapon.createSpreadPattern(startPosition, direction)

	print("8")

	local hits = {}

	local bulletStart = visualRig:FindFirstChild("BulletStart", true)
	local bulletStartPosition = bulletStart and bulletStart.WorldPosition

	print("9")

	for _, bullet in ipairs(bullets) do
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {player.Character}
        raycastParams.CollisionGroup = "PlayerCharacters"

		local hitPosition = nil

		for _, raycastData in ipairs(bullet.raycastData) do                
			local raycastDistance = weaponConstants.RANGE
			local raycastResult = workspace:Raycast(raycastData.startPosition, raycastData.direction * raycastDistance, raycastParams)

			print("raycastResult")
			print(raycastResult)
			
			if raycastResult then
				hitPosition = raycastResult.Position
				print("hitPosition")
				print(hitPosition)
				print("hitPart")
				print(raycastResult.Instance)

				table.insert(hits, {
					hitPart = raycastResult.Instance,
					hitPosition = raycastResult.Position,
				})
				break
			end
		end

		local updateFunction = weapon.animateBullet(bulletStartPosition + bullet.animationStartOffset, hitPosition, hitPart, bullet.animationDirection)

		if updateFunction then
			table.insert(bulletAnimations, updateFunction)
		end
	end

	print("10")

	if currentFireAnimationTrack then
		currentFireAnimationTrack:Play()
	end
	
	print("11")

	if #hits > 0 then
		local avgHitPosition, validHits = HitGui.calculateAverageHitPosition(hits)
		if avgHitPosition and validHits > 0 then
			local totalDamage = validHits * weaponConstants.DAMAGE_PER_HIT
			HitGui.showDamageNumber(totalDamage, avgHitPosition)
		end

		print("12")

		shootEvent:FireServer(hits, direction, startPosition, seed)
	end
end

function Weapons.handleFireFromServer(weaponType, shooter, bullets)
	local weapon = availableWeapons[weaponType]

	local shooterCharacter = shooter.Character

	if not shooterCharacter then
		return
	end

	local bulletStart = shooterCharacter:FindFirstChild("BulletStart", true)
	local bulletStartPosition = bulletStart and bulletStart.WorldPosition

	for _, bullet in ipairs(bullets) do
		local updateFunction = weapon.animateBullet(bulletStartPosition + bullet.animationStartOffset, bullet.hitPosition, bullet.hitPart, bullet.animationDirection)
		if updateFunction then
			table.insert(bulletAnimations, updateFunction)
		end
	end
end

function Weapons.init()
	
	-- Equip default weapon
	local currentWeaponType = currentWeapon or "shotgun"
	Weapons.equip(currentWeaponType, true)
	
	-- Handle character respawning - cleanup crosshair
	local player = Players.LocalPlayer
	player.CharacterRemoving:Connect(function()
		if crosshair then
			crosshair:Destroy()
			crosshair = nil
		end
	end)

	player.CharacterAdded:Connect(function(character)
		if crosshair then
			crosshair:Destroy()
		end
		crosshair = createDynamicCrosshair()

		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if crosshair then
				crosshair:Destroy()
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
				data.shooter,
				data.bullets
			)
		end
	end)
end

function Weapons.equip(weaponType, notifyServer)
	currentWeapon = weaponType
	
	if not Players.LocalPlayer.Character then
        return
    end

	local weaponConstants = WeaponConstants[weaponType]

	local weaponModel = ReplicatedStorage:FindFirstChild("models"):FindFirstChild("weapons"):FindFirstChild(weaponType)
    if not weaponModel then
        return
    end

    local originalCharacter = Players.LocalPlayer.Character
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")

	if not originalHumanoid then
        return
    end

	local newCharacterModel = weaponModel:Clone()

	local weaponHumanoid = newCharacterModel:FindFirstChildOfClass("Humanoid")

	if not weaponHumanoid then
		return
	end

    local clothingItems = {"Shirt", "Pants", "ShirtGraphic"}

    for _, clothingType in ipairs(clothingItems) do
        local originalClothing = originalCharacter:FindFirstChildOfClass(clothingType)
        if originalClothing then
            local existingClothing = newCharacterModel:FindFirstChildOfClass(clothingType)
            if existingClothing then
                existingClothing:Destroy()
            end
            local newClothing = originalClothing:Clone()
            newClothing.Parent = newCharacterModel
        end
    end

	local newHumanoid = newCharacterModel:FindFirstChildOfClass("Humanoid")
    local newRootPart = newCharacterModel:FindFirstChild("HumanoidRootPart")

	if not (newHumanoid and newRootPart) then
        return
    end

	if visualRig then
		visualRig:Destroy()
		visualRig = nil
	end

	visualRootPart = nil

	-- Clone the character for visual rig
	visualRig = newCharacterModel:Clone()
	visualRig.Name = "VisualRig"

	local visualHumanoid = visualRig:FindFirstChildOfClass("Humanoid")
    visualRootPart = visualRig:FindFirstChild("HumanoidRootPart")

	if not (visualHumanoid or visualRootPart) then
        visualRig:Destroy()
        visualRig = nil
        return
    end

	visualRig:ScaleTo(0.7)

	for _, part in pairs(visualRig:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
            part.CollisionGroup = "VisualOnly"
        end
    end

	visualRig.Parent = workspace.CurrentCamera

	if visualHumanoid then
        local animator = visualHumanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = visualHumanoid
        end
        
        local animation = Instance.new("Animation")
        animation.AnimationId = weaponConstants.HOLD_ANIM_ID

		if currentHoldAnimationTrack then
			currentHoldAnimationTrack:Stop()
			currentHoldAnimationTrack:Destroy()
			currentHoldAnimationTrack = nil
		end
        
        currentHoldAnimationTrack = animator:LoadAnimation(animation)
        
        if currentHoldAnimationTrack then
            currentHoldAnimationTrack.Looped = true
            currentHoldAnimationTrack.Priority = Enum.AnimationPriority.Action
            currentHoldAnimationTrack:Play()
        end

        local animation = Instance.new("Animation")
        animation.AnimationId = weaponConstants.FIRE_ANIM_ID

		if currentFireAnimationTrack then
			currentFireAnimationTrack:Stop()
			currentFireAnimationTrack:Destroy()
			currentFireAnimationTrack = nil
		end
        
        currentFireAnimationTrack = animator:LoadAnimation(animation)

        if currentFireAnimationTrack then
            currentFireAnimationTrack.Looped = false
        end

        local animation = Instance.new("Animation")
        animation.AnimationId = weaponConstants.RELOAD_ANIM_ID

		if currentReloadAnimationTrack then
			currentReloadAnimationTrack:Stop()
			currentReloadAnimationTrack:Destroy()
			currentReloadAnimationTrack = nil
		end
        
        currentReloadAnimationTrack = animator:LoadAnimation(animation)

        if currentReloadAnimationTrack then
            currentReloadAnimationTrack.Looped = false
            currentReloadAnimationTrack:AdjustSpeed(currentReloadAnimationTrack.Length / weaponConstants.RELOAD_TIME)
        end
    end

    local cameraOffset = Vector3.new(0.7, -1, 0.5)

    cameraArmSyncConnection = RunService.RenderStepped:Connect(function()
        local camera = workspace.CurrentCamera
        if not camera or not visualRootPart then return end
        
        local visualRigCFrame = camera.CFrame * CFrame.new(cameraOffset)
        visualRootPart.CFrame = visualRigCFrame
    end)
	
	if not crosshair then
		crosshair = createDynamicCrosshair()
	end
	
	if notifyServer then
		weaponSelectionEvent:FireServer(weaponType)
	end
end

return Weapons