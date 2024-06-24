-- Function to set player walk speed
local function setPlayerSpeed(player)
	local speed = 70 -- Adjust this value to change the run speed

	-- Wait for the character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

local function setPlayerJumpHeight(player)
	local jumpHeight = 50 -- Adjust this value to change the jump height

	-- Wait for the character to load
	local character = player.Character or player.CharacterAdded:Wait()
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = jumpHeight
	end
end

local PlayerAbilities = {}

function PlayerAbilities.setPlayerAbilities(player)
	setPlayerSpeed(player)
	setPlayerJumpHeight(player)
end

return PlayerAbilities
