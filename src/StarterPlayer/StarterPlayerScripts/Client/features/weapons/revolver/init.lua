local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local RevolverConstants = require(ReplicatedStorage.features.weapons.revolver.constants)
local HitGui = require(script.Parent.ui.HitGui)
local Workspace = game:GetService("Workspace")

local Revolver = {}

local function createBeam(startPosition, endPosition)
    local direction = (endPosition - startPosition).Unit
    
    local beamLength = 3
    
    local startPart = Instance.new("Part")
    startPart.Name = "BeamStart"
    startPart.Size = Vector3.new(0.1, 0.1, 0.1)
    startPart.Position = startPosition
    startPart.Anchored = true
    startPart.CanCollide = false
    startPart.Transparency = 1
    startPart.Parent = workspace
    startPart.CollisionGroup = "VisualOnly"
    
    local endPart = Instance.new("Part")
    endPart.Name = "BeamEnd"
    endPart.Size = Vector3.new(0.1, 0.1, 0.1)
    endPart.Position = endPosition
    endPart.Anchored = true
    endPart.CanCollide = false
    endPart.Transparency = 1
    endPart.Parent = workspace
    endPart.CollisionGroup = "VisualOnly"
    
    local startAttachment = Instance.new("Attachment")
    startAttachment.Name = "BeamStart"
    startAttachment.Parent = startPart
    
    local endAttachment = Instance.new("Attachment")
    endAttachment.Name = "BeamEnd"
    endAttachment.Parent = endPart
    
    local beam = Instance.new("Beam")
    beam.Name = "BulletBeam"
    beam.Color = ColorSequence.new(Color3.fromRGB(255, 165, 0))
    beam.Transparency = NumberSequence.new(0.1)
    beam.Width0 = 0.03
    beam.Width1 = 0.03
    beam.FaceCamera = true
    beam.LightEmission = 0.8
    beam.LightInfluence = 0
    beam.Attachment0 = startAttachment
    beam.Attachment1 = endAttachment
    beam.Parent = startPart
    
    return beam
end

function Revolver.createSpreadPattern(startPosition, direction)
    local bullets = {}
    
    local bullet = {
        raycastData = {{
            direction = direction,
            startPosition = startPosition
        }},

        animationDirection = direction,
        animationStartOffset = Vector3.new(0, 0, 0),
    }
    table.insert(bullets, bullet)
    
    return bullets
end

function Revolver.animateBullet(startPosition, hitPosition, hitPart, direction)    
    -- Calculate velocity-based offset
    local velocityOffset = Vector3.new(0, 0, 0)
    
    -- Get the shooter's character to calculate velocity
    local Players = game:GetService("Players")
    local shooter = Players.LocalPlayer
    if shooter and shooter.Character and shooter.Character.PrimaryPart then
        local velocity = shooter.Character.PrimaryPart.Velocity
        local velocityMagnitude = velocity.Magnitude
        
        -- Only apply offset if player is moving
        if velocityMagnitude > 1 then
            -- Calculate offset based on velocity and direction
            -- You can tweak these values later
            local velocityMultiplier = 0.1 -- Adjust this to control offset strength
            local directionMultiplier = 0.02 -- Adjust this to control direction influence
            
            -- Offset in the direction of movement
            local movementDirection = velocity.Unit
            local directionDot = movementDirection:Dot(direction)
            
            -- Apply offset based on velocity magnitude and alignment with shooting direction
            velocityOffset = (movementDirection * velocityMagnitude * directionMultiplier)
        end
    end
    
    -- Apply the velocity offset to the start position
    local adjustedStartPosition = startPosition + velocityOffset
    
    local endPosition = adjustedStartPosition + (direction.Unit * RevolverConstants.RANGE)

    if hitPosition then
        endPosition = hitPosition
    end

    local maxDistance = (endPosition - adjustedStartPosition).Magnitude
    
    local beam = createBeam(adjustedStartPosition, endPosition)

    Debris:AddItem(beam, 0.05)

    return nil
end

return Revolver

