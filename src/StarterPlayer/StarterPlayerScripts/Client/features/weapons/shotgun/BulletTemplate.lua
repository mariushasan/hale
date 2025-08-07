local BulletTemplate = Instance.new("Part")
BulletTemplate.Name = "ShotgunPellet"
BulletTemplate.FormFactor = Enum.FormFactor.Custom
BulletTemplate.Anchored = true
BulletTemplate.CanCollide = false
BulletTemplate.Massless = true
BulletTemplate.Locked = true
BulletTemplate.Color = Color3.fromRGB(200, 200, 200)
BulletTemplate.Material = Enum.Material.Metal
BulletTemplate.Transparency = 0
BulletTemplate.Size = Vector3.new(0.15, 0.15, 0.15)

return BulletTemplate