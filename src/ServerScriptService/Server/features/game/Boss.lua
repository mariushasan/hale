local Boss = {}

-- Internal functions
function toggleCharacterSize(character, enlarge)
	local scaleFactor = 5 -- The scale factor for enlarging the character
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
	if humanoid then
		if enlarge then
			humanoid.BodyWidthScale.Value = scaleFactor
			humanoid.BodyHeightScale.Value = scaleFactor
			humanoid.BodyDepthScale.Value = scaleFactor
			humanoid.HeadScale.Value = scaleFactor
		else
			humanoid.BodyWidthScale.Value = 1
			humanoid.BodyHeightScale.Value = 1
			humanoid.BodyDepthScale.Value = 1
			humanoid.HeadScale.Value = 1
		end
	end
end

function Boss.makeBoss(player)
	player.Character.Humanoid.MaxHealth = 1000
	player.Character.Humanoid.Health = 1000
	toggleCharacterSize(player.Character, true)
end

function Boss.removeBoss(player)
	player.Character.Humanoid.MaxHealth = 100
	player.Character.Humanoid.Health = 100
	toggleCharacterSize(player.Character, false)
end

return Boss
