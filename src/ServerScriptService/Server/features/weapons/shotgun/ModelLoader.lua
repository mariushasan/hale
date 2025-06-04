local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InsertService = game:GetService("InsertService")

-- Shotgun model Asset ID
local SHOTGUN_MODEL_ID = 88891310198432

-- Ensure Common folder exists in ReplicatedStorage
local commonFolder = ReplicatedStorage:FindFirstChild("Common")
if not commonFolder then
    commonFolder = Instance.new("Folder")
    commonFolder.Name = "Common"
    commonFolder.Parent = ReplicatedStorage
end

-- Load the shotgun model from Roblox
local function loadShotgunModel()
    
    local success, result = pcall(function()
        return InsertService:LoadAsset(SHOTGUN_MODEL_ID)
    end)
    
    if not success then
        warn("Failed to load shotgun model:", result)
        return
    end
    
    -- Get the model from the loaded asset
    local loadedAsset = result
    local shotgunModel = loadedAsset:FindFirstChildWhichIsA("Model")
    
    if not shotgunModel then
        warn("No model found in loaded asset!")
        loadedAsset:Destroy()
        return
    end
    
    -- Clone the model and place it in ReplicatedStorage
    local shotgunClone = shotgunModel:Clone()
    shotgunClone.Name = "shotgun"
    
    -- Remove any existing shotgun model
    local existingShotgun = commonFolder:FindFirstChild("shotgun")
    if existingShotgun then
        existingShotgun:Destroy()
    end
    
    -- Place the new model in ReplicatedStorage
    shotgunClone.Parent = commonFolder
    
    for _, child in pairs(shotgunClone:GetChildren()) do
        print("- " .. child.Name .. " (" .. child.ClassName .. ")")
        if child:IsA("BasePart") then
            print("  - Material: " .. tostring(child.Material))
            print("  - Color: " .. tostring(child.Color))
            print("  - Transparency: " .. tostring(child.Transparency))
        end
    end
    
    -- Clean up the loaded asset
    loadedAsset:Destroy()
end

-- Load the model when the script starts
return loadShotgunModel