--[[
    Aimbot Module for BRM5 PVP
    Optimized version using Wall system
]]

local Aimbot = {
    fovGui = nil,
    fovCircle = nil,
    fovStroke = nil,
    holdingKey = false,
    enabled = false,
    wallSystem = nil,
    config = {
        fovEnabled = true,
        fovRadius = 100,
        fovColor = Color3.fromRGB(255, 255, 255),
        smoothing = 95,
        DEADZONE = 1.5,
        REQUIRED_CHILD = "Wall_Box",
        visibleColor = Color3.fromRGB(0, 255, 0),
        isUnloaded = false
    }
}

local Players = game:GetService("Players")

local function getPlayerGui()
    local localPlayer = Players.LocalPlayer
    if not localPlayer then
        return nil
    end
    return localPlayer:FindFirstChildOfClass("PlayerGui")
end

local function ensureFOVCircle()
    if Aimbot.fovCircle then
        return
    end

    local playerGui = getPlayerGui()
    if not playerGui then
        return
    end

    local existing = playerGui:FindFirstChild("Aeon_FOV_GUI")
    if existing then
        existing:Destroy()
    end

    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "Aeon_FOV_GUI"
    screenGui.ResetOnSpawn = false
    screenGui.DisplayOrder = 100000
    screenGui.IgnoreGuiInset = true
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = playerGui

    local circle = Instance.new("Frame")
    circle.Name = "Aeon_FOV"
    circle.AnchorPoint = Vector2.new(0.5, 0.5)
    circle.BackgroundTransparency = 1
    circle.BorderSizePixel = 0
    circle.Visible = false
    circle.ZIndex = 99999
    circle.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = circle

    local stroke = Instance.new("UIStroke")
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Aimbot.config.fovColor
    stroke.Thickness = 2
    stroke.Parent = circle

    Aimbot.fovGui = screenGui
    Aimbot.fovCircle = circle
    Aimbot.fovStroke = stroke
end

local function getScreenCenter(camera)
    return Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
end

function Aimbot:setHoldingKey(isHeld)
    self.holdingKey = isHeld and true or false
end

function Aimbot:setWallSystem(wallSystem)
    self.wallSystem = wallSystem
end

function Aimbot:updateFOVCircle(camera)
    ensureFOVCircle()
    if not self.fovCircle or not camera then
        return
    end

    local radius = math.max(self.config.fovRadius, 0)
    local diameter = radius * 2
    local screenCenter = getScreenCenter(camera)
    self.fovCircle.Size = UDim2.fromOffset(diameter, diameter)
    self.fovCircle.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
    self.fovCircle.Visible = self.config.fovEnabled and not self.config.isUnloaded and radius > 0
    
    -- Update color
    if self.fovStroke then
        self.fovStroke.Color = self.config.fovColor
    end
end

function Aimbot:getClosestHead(camera, visibleColor)
    if not self.wallSystem or not camera then
        return nil
    end

    local visible = visibleColor or self.config.visibleColor
    local closestTarget, minDistance = nil, math.huge
    local screenCenter = getScreenCenter(camera)
    local fovRadiusSq = self.config.fovRadius * self.config.fovRadius -- Use squared distance to avoid sqrt

    -- Use Wall system's tracked heads - only aim at visible targets
    for head in pairs(self.wallSystem.trackedHeads) do
        local box = head and head:FindFirstChild(self.config.REQUIRED_CHILD)
        if head and head.Parent and box and box:IsA("BoxHandleAdornment") and box.Color3 == visible and box.Visible then
            local targetPosition, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local deltaX = targetPosition.X - screenCenter.X
                local deltaY = targetPosition.Y - screenCenter.Y
                local distanceSq = deltaX * deltaX + deltaY * deltaY -- Squared distance (faster)
                
                if (not self.config.fovEnabled or distanceSq <= fovRadiusSq) and distanceSq < minDistance then
                    closestTarget = head
                    minDistance = distanceSq
                end
            end
        end
    end

    return closestTarget
end

function Aimbot:aimAtTarget(target, camera)
    if not target or not camera or type(mousemoverel) ~= "function" then
        return
    end

    local targetPosition = camera:WorldToViewportPoint(target.Position)
    local screenCenter = getScreenCenter(camera)
    local delta = targetPosition - Vector3.new(screenCenter.X, screenCenter.Y, targetPosition.Z)

    if math.abs(delta.X) < self.config.DEADZONE and math.abs(delta.Y) < self.config.DEADZONE then
        return
    end

    local smoothingFactor = math.clamp(1 - (self.config.smoothing / 100), 0, 1)
    mousemoverel(
        math.clamp(delta.X * smoothingFactor, -25, 25),
        math.clamp(delta.Y * smoothingFactor, -25, 25)
    )
end

function Aimbot:cleanup()
    if self.fovGui then
        self.fovGui:Destroy()
    end

    self.fovGui = nil
    self.fovCircle = nil
    self.fovStroke = nil
    self.holdingKey = false
    self.wallSystem = nil
end

-- Public API
function Aimbot.Enable()
    Aimbot.enabled = true
end

function Aimbot.Disable()
    Aimbot.enabled = false
    Aimbot.holdingKey = false
    Aimbot:cleanup()
end

function Aimbot.IsActive()
    return Aimbot.enabled and Aimbot.holdingKey
end

function Aimbot.UpdateSettings(settings)
    if settings.FOVRadius ~= nil then
        Aimbot.config.fovRadius = math.clamp(settings.FOVRadius, 0, 500)
    end
    if settings.Smoothness ~= nil then
        Aimbot.config.smoothing = math.clamp(settings.Smoothness, 0, 100)
    end
    if settings.DrawFOV ~= nil then
        Aimbot.config.fovEnabled = settings.DrawFOV
    end
    if settings.FOVColor ~= nil then
        Aimbot.config.fovColor = settings.FOVColor
    end
    if settings.VisibleColor ~= nil then
        Aimbot.config.visibleColor = settings.VisibleColor
    end
end

return Aimbot
