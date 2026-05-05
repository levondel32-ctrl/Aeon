--[[
    Aimbot Module for BRM5 PVP
    Simple logic: find models with Humanoid, aim at head
]]

local Aimbot = {
    fovGui = nil,
    fovCircle = nil,
    fovStroke = nil,
    holdingKey = false,
    enabled = false,
    fovEnabled = true,
    fovRadius = 100,
    fovColor = Color3.fromRGB(255, 255, 255),
    smoothing = 95,
    deadzone = 1.5,
    targetCache = {},  -- Кэш для целей
    lastCacheUpdate = 0
}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

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
    stroke.Color = Aimbot.fovColor
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

function Aimbot:updateFOVCircle(camera)
    ensureFOVCircle()
    if not self.fovCircle or not camera then
        return
    end

    local radius = math.max(self.fovRadius, 0)
    local diameter = radius * 2
    local screenCenter = getScreenCenter(camera)
    self.fovCircle.Size = UDim2.fromOffset(diameter, diameter)
    self.fovCircle.Position = UDim2.fromOffset(screenCenter.X, screenCenter.Y)
    self.fovCircle.Visible = self.fovEnabled and radius > 0
    
    -- Update color
    if self.fovStroke then
        self.fovStroke.Color = self.fovColor
    end
end

function Aimbot:updateTargetCache()
    -- Обновляем кэш только раз в 0.5 секунды
    local currentTime = tick()
    if currentTime - self.lastCacheUpdate < 0.5 then
        return
    end
    self.lastCacheUpdate = currentTime
    
    -- Очищаем старый кэш
    table.clear(self.targetCache)
    
    -- Находим все модели с Humanoid
    for _, desc in pairs(Workspace:GetDescendants()) do
        if desc:IsA("Model") then
            local humanoid = desc:FindFirstChildOfClass("Humanoid")
            if humanoid and humanoid.Health > 0 and LocalPlayer.Character ~= desc then
                local head = desc:FindFirstChild("Head")
                if head and head:IsA("BasePart") then
                    table.insert(self.targetCache, head)
                end
            end
        end
    end
end

function Aimbot:getClosestHead(camera)
    if not camera then
        return nil
    end

    -- Обновляем кэш целей
    self:updateTargetCache()

    local closestTarget, minDistance = nil, math.huge
    local screenCenter = getScreenCenter(camera)

    -- Ищем ближайшую цель из кэша
    for _, head in ipairs(self.targetCache) do
        if head and head.Parent then
            local targetPosition, onScreen = camera:WorldToViewportPoint(head.Position)
            if onScreen then
                local distanceToCenter = (Vector2.new(targetPosition.X, targetPosition.Y) - screenCenter).Magnitude
                if (not self.fovEnabled or distanceToCenter <= self.fovRadius) and distanceToCenter < minDistance then
                    closestTarget = head
                    minDistance = distanceToCenter
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

    if math.abs(delta.X) < self.deadzone and math.abs(delta.Y) < self.deadzone then
        return
    end

    local smoothingFactor = math.clamp(1 - (self.smoothing / 100), 0, 1)
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
    table.clear(self.targetCache)
    self.lastCacheUpdate = 0
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

-- Check if aimbot should be active (enabled AND key held)
function Aimbot.IsActive()
    return Aimbot.enabled and Aimbot.holdingKey
end

function Aimbot.UpdateSettings(settings)
    if settings.FOVRadius ~= nil then
        Aimbot.fovRadius = math.clamp(settings.FOVRadius, 0, 500)
    end
    if settings.Smoothness ~= nil then
        Aimbot.smoothing = math.clamp(settings.Smoothness, 0, 100)
    end
    if settings.DrawFOV ~= nil then
        Aimbot.fovEnabled = settings.DrawFOV
    end
    if settings.FOVColor ~= nil then
        Aimbot.fovColor = settings.FOVColor
    end
end

return Aimbot
