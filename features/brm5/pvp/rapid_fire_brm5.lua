--[[
    Rapid Fire Module for BRM5 PVP
    Modifies weapon RPM (Rounds Per Minute) for faster shooting
]]

local RapidFire = {
    enabled = false,
    rpm = 1000,
    hooked = false,
    originalDischarge = nil,
    patchedConfigs = {},
    hookInProgress = false,
}

local function getModuleInstancesByName(moduleName)
    local matches = {}
    if type(getmodules) ~= "function" then
        return matches
    end

    local ok, modules = pcall(getmodules)
    if not ok or type(modules) ~= "table" then
        return matches
    end

    for _, instance in ipairs(modules) do
        if typeof(instance) == "Instance" and instance:IsA("ModuleScript") and instance.Name == moduleName then
            table.insert(matches, instance)
        end
    end

    return matches
end

-- Find and require a module by exact ModuleScript name.
local function requireModuleByName(moduleName)
    local modules = getModuleInstancesByName(moduleName)
    for _, moduleScript in ipairs(modules) do
        local ok, result = pcall(require, moduleScript)
        if ok and type(result) == "table" then
            return result
        end
    end
    return nil
end

-- Hook the FirearmInventory module to modify RPM
local function hookFirearmInventory()
    if RapidFire.hooked or RapidFire.hookInProgress then
        return true
    end

    RapidFire.hookInProgress = true

    local FirearmInventory = requireModuleByName("FirearmInventory")
    if not FirearmInventory then
        RapidFire.hookInProgress = false
        warn("[Aeon] Failed to find FirearmInventory module")
        return false
    end

    -- Hook the _discharge function (called when weapon fires)
    local oldDischarge = FirearmInventory._discharge
    if type(oldDischarge) ~= "function" then
        RapidFire.hookInProgress = false
        warn("[Aeon] Failed to find _discharge function")
        return false
    end

    RapidFire.originalDischarge = oldDischarge
    FirearmInventory._discharge = function(self, ...)
        local tune = self and self._config and self._config.Tune
        if type(tune) == "table" then
            if RapidFire.enabled then
                if RapidFire.patchedConfigs[tune] == nil and type(tune.RPM) == "number" then
                    RapidFire.patchedConfigs[tune] = tune.RPM
                end
                tune.RPM = RapidFire.rpm
            elseif RapidFire.patchedConfigs[tune] ~= nil then
                tune.RPM = RapidFire.patchedConfigs[tune]
                RapidFire.patchedConfigs[tune] = nil
            end
        end

        return oldDischarge(self, ...)
    end

    RapidFire.hooked = true
    RapidFire.hookInProgress = false
    return true
end

-- Public API
function RapidFire.Enable()
    RapidFire.enabled = true

    -- Try to hook if not already hooked
    if not RapidFire.hooked then
        task.spawn(function()
            local success = hookFirearmInventory()
            if not success then
                warn("[Aeon] Rapid Fire: Failed to hook FirearmInventory")
            end
        end)
    end
end

function RapidFire.Disable()
    RapidFire.enabled = false

    for tune, originalRPM in pairs(RapidFire.patchedConfigs) do
        if type(tune) == "table" and type(originalRPM) == "number" then
            tune.RPM = originalRPM
        end
        RapidFire.patchedConfigs[tune] = nil
    end
end

function RapidFire.Toggle(state)
    if state then
        RapidFire.Enable()
    else
        RapidFire.Disable()
    end
end

function RapidFire.UpdateSettings(settings)
    if settings.RPM ~= nil then
        RapidFire.rpm = math.clamp(settings.RPM, 45, 10000)
    end
end

return RapidFire
