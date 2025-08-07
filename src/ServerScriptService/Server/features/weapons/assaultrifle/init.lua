local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local AssaultRifleConstants = require(ReplicatedStorage.features.weapons.assaultrifle.constants)
local AssaultRifle = {}
local Workspace = game:GetService("Workspace")

-- Store original character models for restoration
local currentAnimationTracks = {} -- [userId] = animationTrack

-- Equip method - replaces player's character with SMG character temporarily
function AssaultRifle.equip(player)
    -- Ensure the player has a character to begin with
    if not player.Character then
        return
    end

    -- Get the SMG model from ReplicatedStorage (or ServerStorage if preferred)
    local smgModel = Workspace:FindFirstChild("SMG")
    if not smgModel then
        return
    end

    local originalCharacter = player.Character
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Ensure the original character has a Humanoid
    if not originalHumanoid then
        return
    end
    
    -- Clone the SMG character model
    local newCharacterModel = smgModel:Clone()

    -- Preserve original character's clothing
    local clothingItems = {"Shirt", "Pants", "ShirtGraphic"}
    for _, clothingType in ipairs(clothingItems) do
        local originalClothing = originalCharacter:FindFirstChildOfClass(clothingType)
        if originalClothing then
            print("DEBUG: Found", clothingType, "- copying to SMG character")
            -- Remove existing clothing of this type from SMG character
            local existingClothing = newCharacterModel:FindFirstChildOfClass(clothingType)
            if existingClothing then
                existingClothing:Destroy()
            end
            -- Copy the original clothing
            local newClothing = originalClothing:Clone()
            newClothing.Parent = newCharacterModel
        end
    end

    -- Also preserve any Accessory items (hats, etc.)
    for _, child in ipairs(originalCharacter:GetChildren()) do
        if child:IsA("Accessory") then
            print("DEBUG: Found Accessory:", child.Name, "- copying to SMG character")
            local newAccessory = child:Clone()
            newAccessory.Parent = newCharacterModel
        end
    end
    
    -- Get the Humanoid from the new SMG character
    local smgHumanoid = newCharacterModel:FindFirstChildOfClass("Humanoid")
    if not smgHumanoid then
        newCharacterModel:Destroy() -- Clean up the cloned character
        return
    end

    -- Get the HumanoidRootPart from both characters for positioning
    local originalRootPart = originalCharacter:FindFirstChild("HumanoidRootPart")
    local smgRootPart = newCharacterModel:FindFirstChild("HumanoidRootPart")
    
    if not originalRootPart then
        newCharacterModel:Destroy()
        return
    end
    if not smgRootPart then
        newCharacterModel:Destroy()
        return
    end

    smgRootPart.CFrame = originalRootPart.CFrame
    smgRootPart.Anchored = false
    smgHumanoid.MaxHealth = originalHumanoid.MaxHealth
    smgHumanoid.Health = originalHumanoid.Health
    smgHumanoid.WalkSpeed = originalHumanoid.WalkSpeed
    smgHumanoid.JumpPower = originalHumanoid.JumpPower
    smgHumanoid.DisplayName = originalHumanoid.DisplayName
    smgHumanoid.RigType = originalHumanoid.RigType

    local originalAnimateScript = originalCharacter:FindFirstChild("Animate")
    if originalAnimateScript and originalAnimateScript:IsA("LocalScript") then
        local newAnimateScript = originalAnimateScript:Clone()
        newAnimateScript.Parent = newCharacterModel
        newAnimateScript.Enabled = true -- Ensure it's enabled and running
    end

    newCharacterModel.Name = player.Name
    player.Character = newCharacterModel
    newCharacterModel.Parent = Workspace
    originalCharacter:Destroy()

    if smgHumanoid then
        if currentAnimationTracks[player.UserId] then
            currentAnimationTracks[player.UserId]:Stop()
            currentAnimationTracks[player.UserId]:Destroy() -- Clean up the old track
            currentAnimationTracks[player.UserId] = nil
        end

        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        
        wait(0.1)
        
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://124292358269579" -- Replace with your actual custom animation ID
        
        local animationTrack = animator:LoadAnimation(animation)
        
        if animationTrack then
            animationTrack.Looped = true
            animationTrack:Play()
            print("DEBUG: Playing animation for", player.Name)
            currentAnimationTracks[player.UserId] = animationTrack
        end
    end
end

-- Create spread pattern for assault rifle (single bullet, no spread)
function AssaultRifle.createSpreadPattern(startPosition, direction, seed)
    -- Set random seed for deterministic pattern (if needed for future features)
    if seed then
        math.randomseed(seed)
    end
    
    local bullets = {}
    
    -- Single bullet for assault rifle - always shoots straight from the given direction
    local bullet = {
        -- Single raycast per bullet
        raycastData = {{
            direction = direction,
            startPosition = startPosition
        }},
        -- Animation direction is same as raycast direction
        animationDirection = direction,
        animationStartPosition = startPosition
    }
    table.insert(bullets, bullet)
    
    return bullets
end

-- Server-side hit validation
function AssaultRifle.handleFireFromServer(shooterLagPart, direction, startPosition, seed, collisionGroup)
    local bullets = AssaultRifle.createSpreadPattern(startPosition, direction, seed)
    local validatedHits = {}
    
    -- Assign bullet IDs (server-side)
    for i, bullet in ipairs(bullets) do
        bullet.id = shooterLagPart.Name .. "_" .. tick() .. "_" .. i
    end
    
    -- Perform server-side raycasts for each bullet
    for _, bullet in ipairs(bullets) do
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {shooterLagPart}
        raycastParams.CollisionGroup = collisionGroup
        
        local bulletHit = false
        local hitPart = nil
        local hitPosition = nil
        local hitRaycastData = nil
        local hitCharacter = nil
        
        -- Try each raycast for this bullet until we get a hit
        for _, raycastData in ipairs(bullet.raycastData) do
            if bulletHit then break end
            
            -- Raycast in the direction we're shooting
            local raycastDistance = 1000 -- Max shooting distance
            local raycastResult = workspace:Raycast(raycastData.startPosition, raycastData.direction * raycastDistance, raycastParams)
            
            if raycastResult then
                local hitInstance = raycastResult.Instance
                local character = hitInstance.Parent
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                hitPart = hitInstance
                hitPosition = raycastResult.Position
                hitRaycastData = raycastData
                hitCharacter = character -- This will be nil for lag parts, but that's ok
                bulletHit = true
            end
        end
        
        -- Calculate max distance for animation
        local maxDistance = AssaultRifleConstants.MAX_BULLET_DISTANCE
        local hitVector = hitPosition and hitPosition - bullet.animationStartPosition
        if hitVector then
            maxDistance = hitVector.Magnitude
        end
        
        -- Add validated hit data
        if bulletHit then
            table.insert(validatedHits, {
                id = bullet.id,
                direction = hitRaycastData.direction,
                startPosition = hitRaycastData.startPosition,
                animationStartPosition = bullet.animationStartPosition,
                animationDirection = bullet.animationDirection,
                hitPart = hitPart,
                hitPosition = hitPosition,
                hitCharacter = hitCharacter,
                maxDistance = maxDistance,
            })
        else
            table.insert(validatedHits, {
                id = bullet.id,
                animationStartPosition = bullet.animationStartPosition,
                animationDirection = bullet.animationDirection,
                hitPosition = hitPosition,
                maxDistance = maxDistance,
            })
        end
    end
    
    return validatedHits
end

return AssaultRifle
