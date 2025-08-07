-- Test CFrame.Angles to see the actual matrix values
local cf = CFrame.Angles(0.1, 0, 0)  -- 0.1 radians around X-axis

print("CFrame.Angles(0.1, 0, 0):")
print("Position:", cf.Position)
print("RightVector:", cf.RightVector)
print("UpVector:", cf.UpVector) 
print("LookVector:", cf.LookVector)
print()

-- Let's also try a Y rotation
local cf2 = CFrame.Angles(0, 0.1, 0)  -- 0.1 radians around Y-axis
print("CFrame.Angles(0, 0.1, 0):")
print("Position:", cf2.Position)
print("RightVector:", cf2.RightVector)
print("UpVector:", cf2.UpVector)
print("LookVector:", cf2.LookVector)
print()

-- And show the math
print("For X rotation of 0.1 radians:")
print("cos(0.1) =", math.cos(0.1))
print("sin(0.1) =", math.sin(0.1))
