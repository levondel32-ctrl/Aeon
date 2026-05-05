--[[
    Fullbright Module for BRM5 PVP
    Based on Dexter Scripts
]]

local Fullbright = {
    originalLighting = {},
    fullBrightApplied = false,
    enabled = false
}

function Fullbright:storeOriginalSettings(lightingService)
    self.originalLighting = {
        Brightness = lightingService.Brightness,
        ClockTime = lightingService.ClockTime,
        FogEnd = lightingService.FogEnd,
        GlobalShadows = lightingService.GlobalShadows,
        Ambient = lightingService.Ambient
    }
end

function Fullbright:applyFullBright(lightingService)
    lightingService.Brightness = 2
    lightingService.ClockTime = 12
    lightingService.FogEnd = 100000
    lightingService.GlobalShadows = false
    lightingService.Ambient = Color3.new(1, 1, 1)
    self.fullBrightApplied = true
end

function Fullbright:restoreOriginal(lightingService)
    for property, value in pairs(self.originalLighting) do
        lightingService[property] = value
    end
    self.fullBrightApplied = false
end

function Fullbright:update(lightingService)
    if self.enabled then
        self:applyFullBright(lightingService)
        return
    end

    if self.fullBrightApplied then
        self:restoreOriginal(lightingService)
    end
end

-- Public API
function Fullbright.Enable()
    Fullbright.enabled = true
    local Lighting = game:GetService("Lighting")
    if next(Fullbright.originalLighting) == nil then
        Fullbright:storeOriginalSettings(Lighting)
    end
    Fullbright:applyFullBright(Lighting)
end

function Fullbright.Disable()
    Fullbright.enabled = false
    local Lighting = game:GetService("Lighting")
    Fullbright:restoreOriginal(Lighting)
end

return Fullbright
