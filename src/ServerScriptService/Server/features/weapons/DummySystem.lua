local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhysicsService = game:GetService("PhysicsService")
local events = ReplicatedStorage:WaitForChild("events")

local PLAYER_CHARACTERS_GROUP = "PlayerCharacters"  -- must match weapons.init

local debugLogEvent = events:FindFirstChild("DebugLogEvent")
if not debugLogEvent then
    debugLogEvent = Instance.new("RemoteEvent")
    debugLogEvent.Name = "DebugLogEvent"
    debugLogEvent.Parent = ReplicatedStorage
end

-- Debug logging function that sends to clients
local function debugLog(message, player)
    print(message) -- Still print to server console
    
    -- Send to specific player or all players
    if player then
        debugLogEvent:FireClient(player, message)
    else
        debugLogEvent:FireAllClients(message)
    end
end

local DummySystem = {}

-- Dummy configuration
local DUMMY_COUNT = 3
-- Relative positions from TeleportArena center
local DUMMY_RELATIVE_POSITIONS = {
    Vector3.new(0, 5, -20),
    Vector3.new(20, 5, -20),
    Vector3.new(-20, 5, -20)
}
local DUMMY_NAMES = {"TestDummy1", "TestDummy2", "TestDummy3"}

-- Store dummy data for lag compensation
local dummyData = {}
local dummyPositionHistory = {}

-- Get TeleportArena reference
local function getTeleportArena()
    local arena = workspace:FindFirstChild("TeleportArena")
    if not arena then
        warn("TeleportArena not found in workspace! Dummies will spawn at origin.")
        return nil
    end
    return arena
end

-- Calculate world position relative to TeleportArena
local function getWorldPosition(relativePosition)
    local arena = getTeleportArena()
    if arena then
        return arena.Position + relativePosition
    else
        -- Fallback to world origin if arena not found
        return relativePosition
    end
end

-- Create a basic dummy character
local function createDummy(name, spawnPosition)
    local dummy = Instance.new("Model")
    dummy.Name = name
    dummy.Parent = workspace
    
    -- Create humanoid first
    local humanoid = Instance.new("Humanoid")
    humanoid.Parent = dummy
    humanoid.MaxHealth = 100
    humanoid.Health = 100
    humanoid.WalkSpeed = 24
    humanoid.JumpPower = 50
    humanoid.PlatformStand = false
    humanoid.Sit = false
    
    -- Create HumanoidRootPart (important for live servers)
    local rootPart = Instance.new("Part")
    rootPart.Name = "HumanoidRootPart"
    rootPart.Size = Vector3.new(2, 2, 1)
    rootPart.Position = spawnPosition
    rootPart.BrickColor = BrickColor.new("Medium blue")
    rootPart.Material = Enum.Material.Plastic
    rootPart.CanCollide = false
    rootPart.Anchored = false
    rootPart.Transparency = 1 -- Make root part invisible
    rootPart.Parent = dummy
    
    -- Create head
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Size = Vector3.new(2, 1, 1)
    head.Position = spawnPosition + Vector3.new(0, 1.5, 0)
    head.BrickColor = BrickColor.new("Bright yellow")
    head.Material = Enum.Material.Plastic
    head.CanCollide = true
    head.Anchored = false
    head.Parent = dummy
    
    -- Create R15 torso parts
    local upperTorso = Instance.new("Part")
    upperTorso.Name = "UpperTorso"
    upperTorso.Size = Vector3.new(2, 1.5, 1)
    upperTorso.Position = spawnPosition + Vector3.new(0, 0.25, 0)
    upperTorso.BrickColor = BrickColor.new("Bright blue")
    upperTorso.Material = Enum.Material.Plastic
    upperTorso.CanCollide = true
    upperTorso.Anchored = false
    upperTorso.Parent = dummy
    
    local lowerTorso = Instance.new("Part")
    lowerTorso.Name = "LowerTorso"
    lowerTorso.Size = Vector3.new(2, 1, 1)
    lowerTorso.Position = spawnPosition + Vector3.new(0, -0.75, 0)
    lowerTorso.BrickColor = BrickColor.new("Bright blue")
    lowerTorso.Material = Enum.Material.Plastic
    lowerTorso.CanCollide = true
    lowerTorso.Anchored = false
    lowerTorso.Parent = dummy
    
    -- Create R15 left arm parts
    local leftUpperArm = Instance.new("Part")
    leftUpperArm.Name = "LeftUpperArm"
    leftUpperArm.Size = Vector3.new(1, 1.2, 1)
    leftUpperArm.Position = spawnPosition + Vector3.new(-1.5, 0.4, 0)
    leftUpperArm.BrickColor = BrickColor.new("Bright yellow")
    leftUpperArm.Material = Enum.Material.Plastic
    leftUpperArm.CanCollide = true
    leftUpperArm.Anchored = false
    leftUpperArm.Parent = dummy
    
    local leftLowerArm = Instance.new("Part")
    leftLowerArm.Name = "LeftLowerArm"
    leftLowerArm.Size = Vector3.new(1, 1.2, 1)
    leftLowerArm.Position = spawnPosition + Vector3.new(-1.5, -0.8, 0)
    leftLowerArm.BrickColor = BrickColor.new("Bright yellow")
    leftLowerArm.Material = Enum.Material.Plastic
    leftLowerArm.CanCollide = true
    leftLowerArm.Anchored = false
    leftLowerArm.Parent = dummy
    
    local leftHand = Instance.new("Part")
    leftHand.Name = "LeftHand"
    leftHand.Size = Vector3.new(1, 0.8, 1)
    leftHand.Position = spawnPosition + Vector3.new(-1.5, -1.8, 0)
    leftHand.BrickColor = BrickColor.new("Bright yellow")
    leftHand.Material = Enum.Material.Plastic
    leftHand.CanCollide = true
    leftHand.Anchored = false
    leftHand.Parent = dummy
    
    -- Create R15 right arm parts
    local rightUpperArm = Instance.new("Part")
    rightUpperArm.Name = "RightUpperArm"
    rightUpperArm.Size = Vector3.new(1, 1.2, 1)
    rightUpperArm.Position = spawnPosition + Vector3.new(1.5, 0.4, 0)
    rightUpperArm.BrickColor = BrickColor.new("Bright yellow")
    rightUpperArm.Material = Enum.Material.Plastic
    rightUpperArm.CanCollide = true
    rightUpperArm.Anchored = false
    rightUpperArm.Parent = dummy
    
    local rightLowerArm = Instance.new("Part")
    rightLowerArm.Name = "RightLowerArm"
    rightLowerArm.Size = Vector3.new(1, 1.2, 1)
    rightLowerArm.Position = spawnPosition + Vector3.new(1.5, -0.8, 0)
    rightLowerArm.BrickColor = BrickColor.new("Bright yellow")
    rightLowerArm.Material = Enum.Material.Plastic
    rightLowerArm.CanCollide = true
    rightLowerArm.Anchored = false
    rightLowerArm.Parent = dummy
    
    local rightHand = Instance.new("Part")
    rightHand.Name = "RightHand"
    rightHand.Size = Vector3.new(1, 0.8, 1)
    rightHand.Position = spawnPosition + Vector3.new(1.5, -1.8, 0)
    rightHand.BrickColor = BrickColor.new("Bright yellow")
    rightHand.Material = Enum.Material.Plastic
    rightHand.CanCollide = true
    rightHand.Anchored = false
    rightHand.Parent = dummy
    
    -- Create R15 left leg parts
    local leftUpperLeg = Instance.new("Part")
    leftUpperLeg.Name = "LeftUpperLeg"
    leftUpperLeg.Size = Vector3.new(1, 1.5, 1)
    leftUpperLeg.Position = spawnPosition + Vector3.new(-0.5, -1.75, 0)
    leftUpperLeg.BrickColor = BrickColor.new("Bright green")
    leftUpperLeg.Material = Enum.Material.Plastic
    leftUpperLeg.CanCollide = true
    leftUpperLeg.Anchored = false
    leftUpperLeg.Parent = dummy
    
    local leftLowerLeg = Instance.new("Part")
    leftLowerLeg.Name = "LeftLowerLeg"
    leftLowerLeg.Size = Vector3.new(1, 1.5, 1)
    leftLowerLeg.Position = spawnPosition + Vector3.new(-0.5, -3.25, 0)
    leftLowerLeg.BrickColor = BrickColor.new("Bright green")
    leftLowerLeg.Material = Enum.Material.Plastic
    leftLowerLeg.CanCollide = true
    leftLowerLeg.Anchored = false
    leftLowerLeg.Parent = dummy
    
    local leftFoot = Instance.new("Part")
    leftFoot.Name = "LeftFoot"
    leftFoot.Size = Vector3.new(1, 0.8, 1)
    leftFoot.Position = spawnPosition + Vector3.new(-0.5, -4.4, 0)
    leftFoot.BrickColor = BrickColor.new("Bright green")
    leftFoot.Material = Enum.Material.Plastic
    leftFoot.CanCollide = true
    leftFoot.Anchored = false
    leftFoot.Parent = dummy
    
    -- Create R15 right leg parts
    local rightUpperLeg = Instance.new("Part")
    rightUpperLeg.Name = "RightUpperLeg"
    rightUpperLeg.Size = Vector3.new(1, 1.5, 1)
    rightUpperLeg.Position = spawnPosition + Vector3.new(0.5, -1.75, 0)
    rightUpperLeg.BrickColor = BrickColor.new("Bright green")
    rightUpperLeg.Material = Enum.Material.Plastic
    rightUpperLeg.CanCollide = true
    rightUpperLeg.Anchored = false
    rightUpperLeg.Parent = dummy
    
    local rightLowerLeg = Instance.new("Part")
    rightLowerLeg.Name = "RightLowerLeg"
    rightLowerLeg.Size = Vector3.new(1, 1.5, 1)
    rightLowerLeg.Position = spawnPosition + Vector3.new(0.5, -3.25, 0)
    rightLowerLeg.BrickColor = BrickColor.new("Bright green")
    rightLowerLeg.Material = Enum.Material.Plastic
    rightLowerLeg.CanCollide = true
    rightLowerLeg.Anchored = false
    rightLowerLeg.Parent = dummy
    
    local rightFoot = Instance.new("Part")
    rightFoot.Name = "RightFoot"
    rightFoot.Size = Vector3.new(1, 0.8, 1)
    rightFoot.Position = spawnPosition + Vector3.new(0.5, -4.4, 0)
    rightFoot.BrickColor = BrickColor.new("Bright green")
    rightFoot.Material = Enum.Material.Plastic
    rightFoot.CanCollide = true
    rightFoot.Anchored = false
    rightFoot.Parent = dummy
    
    -- Set primary part to HumanoidRootPart (standard for Roblox characters)
    dummy.PrimaryPart = rootPart
    
    -- Create proper Motor6D joints (important for live servers)
    local function createMotor6D(part0, part1, name, c0, c1)
        local motor = Instance.new("Motor6D")
        motor.Name = name
        motor.Part0 = part0
        motor.Part1 = part1
        motor.C0 = c0 or CFrame.new()
        motor.C1 = c1 or CFrame.new()
        motor.Parent = part0
        return motor
    end
    
    -- Create R15 joints
    createMotor6D(rootPart, lowerTorso, "Root", CFrame.new(), CFrame.new())
    createMotor6D(lowerTorso, upperTorso, "Waist", CFrame.new(0, 0.75, 0), CFrame.new(0, -0.75, 0))
    createMotor6D(upperTorso, head, "Neck", CFrame.new(0, 0.75, 0), CFrame.new(0, -0.5, 0))
    
    -- Arm joints
    createMotor6D(upperTorso, leftUpperArm, "LeftShoulder", CFrame.new(-1, 0.5, 0), CFrame.new(0, 0.6, 0))
    createMotor6D(leftUpperArm, leftLowerArm, "LeftElbow", CFrame.new(0, -0.6, 0), CFrame.new(0, 0.6, 0))
    createMotor6D(leftLowerArm, leftHand, "LeftWrist", CFrame.new(0, -0.6, 0), CFrame.new(0, 0.4, 0))
    
    createMotor6D(upperTorso, rightUpperArm, "RightShoulder", CFrame.new(1, 0.5, 0), CFrame.new(0, 0.6, 0))
    createMotor6D(rightUpperArm, rightLowerArm, "RightElbow", CFrame.new(0, -0.6, 0), CFrame.new(0, 0.6, 0))
    createMotor6D(rightLowerArm, rightHand, "RightWrist", CFrame.new(0, -0.6, 0), CFrame.new(0, 0.4, 0))
    
    -- Leg joints
    createMotor6D(lowerTorso, leftUpperLeg, "LeftHip", CFrame.new(-0.5, -0.5, 0), CFrame.new(0, 0.75, 0))
    createMotor6D(leftUpperLeg, leftLowerLeg, "LeftKnee", CFrame.new(0, -0.75, 0), CFrame.new(0, 0.75, 0))
    createMotor6D(leftLowerLeg, leftFoot, "LeftAnkle", CFrame.new(0, -0.75, 0), CFrame.new(0, 0.4, 0))
    
    createMotor6D(lowerTorso, rightUpperLeg, "RightHip", CFrame.new(0.5, -0.5, 0), CFrame.new(0, 0.75, 0))
    createMotor6D(rightUpperLeg, rightLowerLeg, "RightKnee", CFrame.new(0, -0.75, 0), CFrame.new(0, 0.75, 0))
    createMotor6D(rightLowerLeg, rightFoot, "RightAnkle", CFrame.new(0, -0.75, 0), CFrame.new(0, 0.4, 0))
    
    -- Add Body parts for proper physics on live servers
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(0, 0, 0)
    bodyVelocity.Velocity = Vector3.new(0, 0, 0)
    bodyVelocity.Parent = rootPart
    
    -- Force network ownership to server for all R15 parts
    rootPart:SetNetworkOwner(nil)
    head:SetNetworkOwner(nil)
    upperTorso:SetNetworkOwner(nil)
    lowerTorso:SetNetworkOwner(nil)
    leftUpperArm:SetNetworkOwner(nil)
    leftLowerArm:SetNetworkOwner(nil)
    leftHand:SetNetworkOwner(nil)
    rightUpperArm:SetNetworkOwner(nil)
    rightLowerArm:SetNetworkOwner(nil)
    rightHand:SetNetworkOwner(nil)
    leftUpperLeg:SetNetworkOwner(nil)
    leftLowerLeg:SetNetworkOwner(nil)
    leftFoot:SetNetworkOwner(nil)
    rightUpperLeg:SetNetworkOwner(nil)
    rightLowerLeg:SetNetworkOwner(nil)
    rightFoot:SetNetworkOwner(nil)
    
    -- At the very end of createDummy after joints setup, assign collision group
    -- Set collision group so server-side projectiles ignore live dummies
    for _, part in ipairs(dummy:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CollisionGroup = PLAYER_CHARACTERS_GROUP
        end
    end

    return dummy
end

-- Record dummy position for lag compensation
local function recordDummyPosition(dummy)
    if not dummy or not dummy.PrimaryPart then return end
    
    local currentTime = DateTime.now().UnixTimestampMillis
    local position = dummy.PrimaryPart.Position
    
    local dummyName = dummy.Name
    if not dummyPositionHistory[dummyName] then
        dummyPositionHistory[dummyName] = {}
    end
    
    -- Add current position to history
    table.insert(dummyPositionHistory[dummyName], {
        time = currentTime,
        position = position,
        dummy = dummy
    })
    
    -- Clean up old history (keep 1 second)
    local cutoffTime = currentTime - 1000 -- 1000 milliseconds = 1 second
    local history = dummyPositionHistory[dummyName]
    for i = #history, 1, -1 do
        if history[i].time < cutoffTime then
            table.remove(history, i)
        end
    end
end

-- Get dummy position at a specific time
local function getDummyPositionAtTime(dummy, targetTime)
    local dummyName = dummy.Name
    local history = dummyPositionHistory[dummyName]
    if not history or #history == 0 then
        if dummy.PrimaryPart then
            return dummy.PrimaryPart.Position, dummy
        end
        return nil, nil
    end
    
    -- Find closest recorded position
    local closestEntry = history[1]
    local closestTimeDiff = math.abs(history[1].time - targetTime)
    
    for i, entry in ipairs(history) do
        local timeDiff = math.abs(entry.time - targetTime)
        if timeDiff < closestTimeDiff then
            closestTimeDiff = timeDiff
            closestEntry = entry
        end
    end
    
    return closestEntry.position, closestEntry.dummy
end

-- AI movement for dummies
local function startDummyAI(dummy)
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    local lastJump = 0
    local currentTarget = nil
    local lastTargetUpdate = 0
    
    spawn(function()
        while dummy.Parent and humanoid.Parent do
            wait(0.1)
            
            -- Jump more frequently - 20% chance every 2+ seconds
            local currentTime = DateTime.now().UnixTimestampMillis
            if currentTime - lastJump > 2000 and math.random() < 0.2 then
                humanoid.Jump = true
                lastJump = currentTime
            end
            
            -- Update movement target every 8-15 seconds (longer movements)
            if currentTime - lastTargetUpdate > math.random(8000, 15000) then
                -- Create more varied movement patterns relative to TeleportArena
                local arena = getTeleportArena()
                local arenaPosition = arena and arena.Position or Vector3.new(0, 0, 0)
                
                local movementDistance = math.random(30, 80) -- Larger movement range
                local angle = math.random() * 2 * math.pi -- Random direction
                local randomX = math.cos(angle) * movementDistance
                local randomZ = math.sin(angle) * movementDistance
                
                -- Target position relative to arena
                currentTarget = arenaPosition + Vector3.new(randomX, 0, randomZ)
                lastTargetUpdate = currentTime
                
                if dummy.PrimaryPart then
                    humanoid:MoveTo(currentTarget)
                end
            end
        end
    end)
end

-- Respawn dummy on death
local function setupDummyRespawn(dummy, dummyIndex)
    local humanoid = dummy:FindFirstChildOfClass("Humanoid")
    if not humanoid then return end
    
    humanoid.Died:Connect(function()
        wait(3)
        
        -- Clean up old dummy
        dummy:Destroy()
        
        -- Recalculate spawn position relative to current TeleportArena position
        local spawnPosition = getWorldPosition(DUMMY_RELATIVE_POSITIONS[dummyIndex])
        
        -- Create new dummy
        local newDummy = createDummy(DUMMY_NAMES[dummyIndex], spawnPosition)
        dummyData[dummyIndex] = newDummy
        
        -- Setup AI and respawn for new dummy
        startDummyAI(newDummy)
        setupDummyRespawn(newDummy, dummyIndex)
    end)
end

-- Initialize dummy system
function DummySystem.init()
    
    -- Create dummies
    for i = 1, DUMMY_COUNT do
        local dummy = createDummy(DUMMY_NAMES[i], getWorldPosition(DUMMY_RELATIVE_POSITIONS[i]))
        dummyData[i] = dummy
        
        -- Start AI
        startDummyAI(dummy)
        
        -- Setup respawn
        setupDummyRespawn(dummy, i)
    end
    
    -- Start position recording for all dummies
    local recordingConnection
    recordingConnection = RunService.Heartbeat:Connect(function()
        for i, dummy in pairs(dummyData) do
            if dummy and dummy.Parent then
                recordDummyPosition(dummy)
            end
        end
    end)
    
    -- Test position recording after a delay
    task.wait(2)
    for i, dummy in pairs(dummyData) do
        if dummy and dummy.Name then
            local history = dummyPositionHistory[dummy.Name]
        end
    end
end

-- Get all active dummies (for lag compensation)
function DummySystem.getAllDummies()
    local activeDummies = {}
    for _, dummy in pairs(dummyData) do
        if dummy and dummy.Parent then
            table.insert(activeDummies, dummy)
        end
    end
    return activeDummies
end

-- Get dummy position at time (for lag compensation)
function DummySystem.getDummyPositionAtTime(dummy, targetTime)
    return getDummyPositionAtTime(dummy, targetTime)
end

return DummySystem 