local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local HitGui = {}

-- Create damage GUI container
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

-- Show damage number at hit position
function HitGui.showDamageNumber(totalDamage, hitPosition)
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
end

-- Calculate average hit position from multiple hits
function HitGui.calculateAverageHitPosition(hits)
	local avgHitPosition = Vector3.new(0, 0, 0)
	local validHits = 0
	
	for _, hit in ipairs(hits) do
		if hit.hitPosition and hit.hitPart.Parent:FindFirstChildOfClass("Humanoid") then
			avgHitPosition = avgHitPosition + hit.hitPosition
			validHits = validHits + 1
		end
	end
	
	if validHits > 0 then
		avgHitPosition = avgHitPosition / validHits
		return avgHitPosition, validHits
	end
	
	return nil, 0
end

return HitGui
