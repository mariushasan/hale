local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UMP = {}

-- Create spread pattern for UMP (single bullet, no spread)
function UMP.createSpreadPattern(startPosition, direction, seed)
    -- Set random seed for deterministic pattern (if needed for future features)
    if seed then
        math.randomseed(seed)
    end
    
    local bullets = {}
    
    -- Single bullet for UMP - always shoots straight from the given direction
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

return UMP

