--[[
	World Modifications Feature for Cursed Tank Simulator
	Handles fullbright, no fog, and black sky functionality
]]

local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WORLD_CTS = {}

-- Hold Sky/Atmosphere while fullbright strips them from Lighting (so they can be restored)
local function getLightingHolder()
	if not WORLD_CTS._lightingHolder or not WORLD_CTS._lightingHolder.Parent then
		local holder = ReplicatedStorage:FindFirstChild("Aeon_DetachedLighting")
		if not holder then
			holder = Instance.new("Folder")
			holder.Name = "Aeon_DetachedLighting"
			holder.Parent = ReplicatedStorage
		end
		WORLD_CTS._lightingHolder = holder
	end
	return WORLD_CTS._lightingHolder
end

-- Store original lighting settings
WORLD_CTS.OrigLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient
}

-- Configuration
WORLD_CTS.Config = {
    FullBrightEnabled = false,
    NoFogEnabled = false,
    BlackSkyEnabled = false
}

function WORLD_CTS.EnableFullBright()
    WORLD_CTS.Config.FullBrightEnabled = true
    Lighting.Brightness = 2
    Lighting.GlobalShadows = false
    Lighting.Ambient = Color3.new(1, 1, 1)
    Lighting.OutdoorAmbient = Color3.new(1, 1, 1)
    local holder = getLightingHolder()
    local lightingKids = Lighting:GetChildren()
    for i = 1, #lightingKids do
        local obj = lightingKids[i]
        if obj:IsA("Sky") or obj:IsA("Atmosphere") then
            obj.Parent = holder
        end
    end
end

function WORLD_CTS.DisableFullBright()
    WORLD_CTS.Config.FullBrightEnabled = false
    Lighting.Brightness = WORLD_CTS.OrigLighting.Brightness
    Lighting.GlobalShadows = WORLD_CTS.OrigLighting.GlobalShadows
    Lighting.Ambient = WORLD_CTS.OrigLighting.Ambient
    Lighting.OutdoorAmbient = WORLD_CTS.OrigLighting.OutdoorAmbient
	local holder = WORLD_CTS._lightingHolder or ReplicatedStorage:FindFirstChild("Aeon_DetachedLighting")
	if holder then
		for _, obj in ipairs(holder:GetChildren()) do
			obj.Parent = Lighting
		end
	end
end

function WORLD_CTS.EnableNoFog()
    WORLD_CTS.Config.NoFogEnabled = true
    Lighting.FogEnd = 9e9
end

function WORLD_CTS.DisableNoFog()
    WORLD_CTS.Config.NoFogEnabled = false
    Lighting.FogEnd = WORLD_CTS.OrigLighting.FogEnd
end

function WORLD_CTS.EnableBlackSky()
    WORLD_CTS.Config.BlackSkyEnabled = true
    local existing = Lighting:FindFirstChild("Elite_BlackSky")
    if existing then
        existing:Destroy()
    end
    local sky = Instance.new("Sky", Lighting)
    sky.Name = "Elite_BlackSky"
    sky.SkyboxBk = "rbxassetid://0"
    sky.SkyboxDn = "rbxassetid://0"
    sky.SkyboxFt = "rbxassetid://0"
    sky.SkyboxLf = "rbxassetid://0"
    sky.SkyboxRt = "rbxassetid://0"
    sky.SkyboxUp = "rbxassetid://0"
    sky.SunTextureId = "rbxassetid://0"
    sky.MoonTextureId = "rbxassetid://0"
    Lighting.ClockTime = 0
end

function WORLD_CTS.DisableBlackSky()
    WORLD_CTS.Config.BlackSkyEnabled = false
    if Lighting:FindFirstChild("Elite_BlackSky") then
        Lighting.Elite_BlackSky:Destroy()
    end
    Lighting.ClockTime = WORLD_CTS.OrigLighting.ClockTime
end

function WORLD_CTS.Initialize()
    if WORLD_CTS._maintainConnection then
        return
    end
    -- Maintain fullbright and no fog in render loop
    WORLD_CTS._maintainConnection = RunService.RenderStepped:Connect(function()
        if WORLD_CTS.Config.FullBrightEnabled then
            Lighting.ClockTime = 14
            Lighting.Brightness = 2
        end
        
        if WORLD_CTS.Config.NoFogEnabled then
            Lighting.FogEnd = 9e9
        end
    end)
end

function WORLD_CTS.Cleanup()
    if WORLD_CTS._maintainConnection then
        WORLD_CTS._maintainConnection:Disconnect()
        WORLD_CTS._maintainConnection = nil
    end
    WORLD_CTS.DisableFullBright()
    WORLD_CTS.DisableNoFog()
    WORLD_CTS.DisableBlackSky()
end

return WORLD_CTS
