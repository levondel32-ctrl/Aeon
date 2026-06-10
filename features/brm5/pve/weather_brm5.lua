--[[
    No Weather Module for BRM5 PVP
    Убирает дождь и погодные эффекты.

    Работает на уровне ИНСТАНСОВ (общие для всех VM, в отличие от кода игры):
      1. Глушит ParticleEmitter'ы/эффекты дождя (Enabled=false, Rate=0)
      2. Глушит звуки дождя/грозы/ветра (Volume=0)
      3. Отключает Atmosphere-плотность и туман Lighting
      4. Вотчер на новые эффекты: RainChunk-скрипты игры продолжают
         спавнить дождь — гасим каждый новый инстанс при появлении
      5. Полное восстановление при выключении

    API: Weather.Enable() / Weather.Disable() / Weather.Toggle(bool)
]]

local Weather = {
    enabled = false,
}

local Lighting = game:GetService("Lighting")

-- Сохранённые оригиналы для восстановления
local savedEffects = {}   -- [Instance] = { prop = value }
local savedSounds = {}    -- [Sound] = volume
local savedLighting = nil -- свойства Lighting/Atmosphere
local watchConns = {}

-- ===== Распознавание погодных инстансов =====

local WEATHER_WORDS = { "rain", "storm", "weather", "snow", "fog", "mist", "drizzle", "thunder", "wind", "drop" }

local function isWeatherName(name)
    local n = string.lower(tostring(name))
    for _, w in ipairs(WEATHER_WORDS) do
        if n:find(w) then return true end
    end
    return false
end

-- Погодный ли это инстанс: имя самого инстанса или его родителей (до 4 уровней)
local function isWeatherInstance(inst)
    local node = inst
    for _ = 1, 4 do
        if not node then break end
        if isWeatherName(node.Name) then return true end
        node = node.Parent
    end
    return false
end

-- ===== Глушение одного инстанса =====

local function suppress(inst)
    if not Weather.enabled then return end

    local ok = pcall(function()
        if inst:IsA("ParticleEmitter") then
            if isWeatherInstance(inst) then
                if not savedEffects[inst] then
                    savedEffects[inst] = { Enabled = inst.Enabled, Rate = inst.Rate }
                end
                inst.Enabled = false
                inst.Rate = 0
            end
        elseif inst:IsA("Beam") or inst:IsA("Trail") then
            if isWeatherInstance(inst) then
                if not savedEffects[inst] then
                    savedEffects[inst] = { Enabled = inst.Enabled }
                end
                inst.Enabled = false
            end
        elseif inst:IsA("Sound") then
            if isWeatherInstance(inst) or isWeatherName(inst.SoundId) then
                if savedSounds[inst] == nil then
                    savedSounds[inst] = inst.Volume
                end
                inst.Volume = 0
            end
        elseif inst:IsA("Atmosphere") then
            if not savedEffects[inst] then
                savedEffects[inst] = {
                    Density = inst.Density,
                    Haze = inst.Haze,
                    Glare = inst.Glare,
                }
            end
            inst.Density = 0
            inst.Haze = 0
        elseif inst:IsA("Clouds") then
            if not savedEffects[inst] then
                savedEffects[inst] = { Cover = inst.Cover, Density = inst.Density }
            end
            inst.Cover = 0
            inst.Density = 0
        elseif inst:IsA("BasePart") and isWeatherInstance(inst) then
            -- Части-"капли"/плоскости дождя: прячем только явные погодные
            if not savedEffects[inst] then
                savedEffects[inst] = { Transparency = inst.Transparency }
            end
            inst.Transparency = 1
        end
    end)

    return ok
end

-- ===== Проход по контейнеру =====

local YIELD_EVERY = 400

local function sweep(container)
    task.spawn(function()
        local counter = 0
        for _, inst in ipairs(container:GetDescendants()) do
            counter = counter + 1
            if counter % YIELD_EVERY == 0 then task.wait() end
            suppress(inst)
        end
    end)
end

-- ===== Lighting / туман =====

local function suppressLighting()
    if not savedLighting then
        savedLighting = {
            FogEnd = Lighting.FogEnd,
            FogStart = Lighting.FogStart,
        }
    end
    pcall(function()
        Lighting.FogEnd = 100000
        Lighting.FogStart = 99999
    end)
    for _, child in ipairs(Lighting:GetChildren()) do
        suppress(child)
    end
end

local function restoreLighting()
    if savedLighting then
        pcall(function()
            Lighting.FogEnd = savedLighting.FogEnd
            Lighting.FogStart = savedLighting.FogStart
        end)
        savedLighting = nil
    end
end

-- ===== Публичный API =====

function Weather.Enable()
    if Weather.enabled then return end
    Weather.enabled = true

    -- Разовый проход по workspace и Lighting
    sweep(workspace)
    suppressLighting()

    -- Вотчеры: игра динамически спавнит дождь (RainChunk) — глушим новое
    table.insert(watchConns, workspace.DescendantAdded:Connect(function(inst)
        task.defer(suppress, inst)
    end))
    table.insert(watchConns, Lighting.ChildAdded:Connect(function(inst)
        task.defer(suppress, inst)
    end))

    print("[Aeon Weather] Погодные эффекты ВЫКЛЮЧЕНЫ")
end

function Weather.Disable()
    if not Weather.enabled then return end
    Weather.enabled = false

    for _, conn in ipairs(watchConns) do
        pcall(function() conn:Disconnect() end)
    end
    watchConns = {}

    -- Восстановление
    for inst, props in pairs(savedEffects) do
        pcall(function()
            if inst and inst.Parent then
                for prop, value in pairs(props) do
                    inst[prop] = value
                end
            end
        end)
    end
    savedEffects = {}

    for inst, volume in pairs(savedSounds) do
        pcall(function()
            if inst and inst.Parent then
                inst.Volume = volume
            end
        end)
    end
    savedSounds = {}

    restoreLighting()

    print("[Aeon Weather] Погодные эффекты ВОССТАНОВЛЕНЫ")
end

function Weather.Toggle(state)
    if state then Weather.Enable() else Weather.Disable() end
end

return Weather
