local BossAttackWeapon = {}

-- Boss constants (transformation only - attack constants are in ReplicatedStorage)
local BOSS_JUMP_POWER = 100 -- much higher than normal (50)

-- Track who is currently a boss (for transformation validation)
local currentBossPlayers = {} -- Track who is currently a boss

-- Internal functions
local function toggleCharacterSize(character, enlarge)
	local scaleFactor = 1 -- The scale factor for enlarging the character
	local currentFactor = enlarge and scaleFactor or (1 / scaleFactor) -- Determine the scale factor based on the 'enlarge' parameter

	-- Ensure the character and its parts are fully loaded
	character:WaitForChild("Humanoid")

	-- Scale each part of the character
	for _, part in pairs(character:GetChildren()) do
		if part:IsA("MeshPart") or part:IsA("Part") then
			part.Size = part.Size * currentFactor
			local centerOffset = part.Position - character.PrimaryPart.Position
			centerOffset = centerOffset * currentFactor
			part.Position = character.PrimaryPart.Position + centerOffset
		end
	end

	-- Adjust Humanoid scale factors based on the action
	local humanoid = character:FindFirstChildOfClass("Humanoid")
end

-- Setup boss controls
local function setupBossControls(player)
	local character = player.Character
	if not character then return end
	
	-- Enhanced jump ability
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.JumpPower = BOSS_JUMP_POWER
	end
	
	-- Mark player as boss for validation
	currentBossPlayers[player.UserId] = true
end

-- Server-side equip function (transforms player into boss)
function BossAttackWeapon.equip(player)
	if not player.Character then return end
	
	local humanoid = player.Character.Humanoid
	humanoid.MaxHealth = 1000
	humanoid.Health = 1000

	print("Equipping boss attack")
	
	toggleCharacterSize(player.Character, true)
	setupBossControls(player)
end

-- Server-side unequip function (removes boss transformation)
function BossAttackWeapon.unequip(player)
	if not player.Character then return end
	
	local humanoid = player.Character.Humanoid
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.JumpPower = 50 -- Reset to normal jump power
	
	toggleCharacterSize(player.Character, false)
	
	-- Clear boss status
	currentBossPlayers[player.UserId] = nil
end

return BossAttackWeapon 