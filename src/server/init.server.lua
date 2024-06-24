local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerAbilities = require(game.ServerScriptService.Server.PlayerAbilities)
local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local Game = require(game.ServerScriptService.Server.Game.Game) -- Initialize the game
local Players = game:GetService("Players")

local speed = 5
local dropDistance = 1000
local dropAngle = 0
local damage = 5

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		PlayerAbilities.setPlayerAbilities(player)
	end)
end)

local function handleShoot(player, startPosition, direction)
	-- Check if the player is in the arena
	if not Game.isPlayerInArena(player) then
		return
	end
	-- Initializing
	local ray, object, position

	-- Creating the bullet
	local bullet = Instance.new("Part")
	bullet.Name = "Bullet"
	bullet.FormFactor = Enum.FormFactor.Custom
	bullet.Anchored = true
	bullet.CanCollide = false
	bullet.Massless = true
	bullet.Locked = true
	bullet.Parent = game.Workspace -- Or anything you want to like in a folder in workspace

	-- Ray casting function
	local function RayCast()
		ray = Ray.new(bullet.CFrame.p, bullet.CFrame.LookVector * speed)
		object, position = game.Workspace:FindPartOnRayWithIgnoreList(ray, { player.Character }, false, true)

		local dropDamageModifier = (position - startPosition).Magnitude / dropDistance
		local _damage = damage / dropDamageModifier

		if _damage > damage then
			_damage = damage
		end

		if _damage < 1 then
			_damage = 0
			game:GetService("Debris"):AddItem(bullet, 0.01)
			bullet = nil -- To remove the bullet object
		end

		if object and bullet then
			local humanoid = object.Parent:FindFirstChildWhichIsA("Humanoid")
			if humanoid then
				humanoid:TakeDamage(_damage)
			end
			game:GetService("Debris"):AddItem(bullet, 0.01)
			bullet = nil -- To remove the bullet object
		end
	end
	--
	bullet.Color = Color3.fromRGB(255, 150, 0)
	bullet.Material = Enum.Material.Metal
	bullet.Transparency = 0

	--
	bullet.Size = Vector3.new(1, 1, 1)

	-- Setting the initial position and orientation of the bullet
	bullet.CFrame = CFrame.new(startPosition, startPosition + direction) * CFrame.new(0, 0, -0.7)
	RayCast() -- Initial checking

	local createBulletTrajectory = coroutine.wrap(function()
		while bullet do
			-- Updating the position
			bullet.CFrame = bullet.CFrame * CFrame.new(0, 0, -speed) * CFrame.Angles(-dropAngle, 0, 0) -- Note: Drop angle should be in radians

			RayCast() -- Hit detection

			wait()
		end
	end)
	createBulletTrajectory() -- Running the coroutine thread
end

ShootEvent.OnServerEvent:Connect(handleShoot)
