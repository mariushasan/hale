local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterPlayer = game:GetService("StarterPlayer")
local AssaultRifleConstants = require(ReplicatedStorage.features.weapons.assaultrifle.constants)
local AssaultRifle = {}
local Workspace = game:GetService("Workspace")

-- Store original character models for restoration
local currentAnimationTracks = {} -- [userId] = animationTrack
local gunStates = {} -- [userId] = {clips = number, ammo = number, reloading = boolean}

-- Equip method - replaces player's character with SMG character temporarily
function AssaultRifle.equip(player)
    -- Ensure the player has a character to begin with
    print("1")
    if not player.Character then
        return
    end

    print("2")

    -- Get the SMG model from ReplicatedStorage (or ServerStorage if preferred)
    local smgModel = ReplicatedStorage:FindFirstChild("models"):FindFirstChild("weapons"):FindFirstChild("AssaultRifle")
    if not smgModel then
        return
    end

    print("3")

    local originalCharacter = player.Character
    local originalHumanoid = originalCharacter:FindFirstChildOfClass("Humanoid")
    
    -- Ensure the original character has a Humanoid
    if not originalHumanoid then
        return
    end

    print("4")
    
    -- Clone the SMG character model
    local newCharacterModel = smgModel:Clone()

    print("5")

    -- Preserve original character's clothing
    local clothingItems = {"Shirt", "Pants", "ShirtGraphic"}
    for _, clothingType in ipairs(clothingItems) do
        local originalClothing = originalCharacter:FindFirstChildOfClass(clothingType)
        if originalClothing then
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

    print("6")

    -- Also preserve any Accessory items (hats, etc.)
    for _, child in ipairs(originalCharacter:GetChildren()) do
        if child:IsA("Accessory") then
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

    print("7")

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

    print("8")

    smgRootPart.CFrame = originalRootPart.CFrame
    smgRootPart.Anchored = false
    smgHumanoid.MaxHealth = originalHumanoid.MaxHealth
    smgHumanoid.Health = originalHumanoid.Health
    smgHumanoid.WalkSpeed = originalHumanoid.WalkSpeed
    smgHumanoid.JumpPower = originalHumanoid.JumpPower
    smgHumanoid.DisplayName = originalHumanoid.DisplayName
    smgHumanoid.RigType = originalHumanoid.RigType

    print("9")

    local originalAnimateScript = originalCharacter:FindFirstChild("Animate")
    if originalAnimateScript and originalAnimateScript:IsA("LocalScript") then
        local newAnimateScript = originalAnimateScript:Clone()
        newAnimateScript.Parent = newCharacterModel
        newAnimateScript.Enabled = true -- Ensure it's enabled and running
    end

    print("10")

    newCharacterModel.Name = player.Name
    player.Character = newCharacterModel
    newCharacterModel.Parent = Workspace
    originalCharacter:Destroy()

    wait(0.5)

    print("11")

    if smgHumanoid then
        if currentAnimationTracks[player.UserId] then
            currentAnimationTracks[player.UserId]:Stop()
            currentAnimationTracks[player.UserId]:Destroy() -- Clean up the old track
            currentAnimationTracks[player.UserId] = nil
        end

        print("12")

        local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

        local animator = humanoid:FindFirstChildOfClass("Animator")
        if not animator then
            animator = Instance.new("Animator")
            animator.Parent = humanoid
        end
        
        local animation = Instance.new("Animation")
        animation.AnimationId = "rbxassetid://124292358269579" -- Replace with your actual custom animation ID
        
        local animationTrack = animator:LoadAnimation(animation)
        
        if animationTrack then
            animationTrack.Looped = true
            animationTrack:Play()
            currentAnimationTracks[player.UserId] = animationTrack
        end
    end

    print("13")
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
        animationStartOffset = Vector3.new(0, 0, 0),
    }
    table.insert(bullets, bullet)
    
    return bullets
end

return AssaultRifle
