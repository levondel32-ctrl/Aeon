--[[
    Rapid Fire Module for BRM5 PVP
    Modifies weapon RPM (Rounds Per Minute) for faster shooting
]]

local RapidFire = {
    enabled = false,
    rpm = 1000,
    hooked = false,
}

-- Function to find and require a module by name
local function requireModule(moduleName)
    for _, module in pairs(getgc()) do
        if type(module) == "table" and rawget(module, "__index") then
            local success, result = pcall(function()
                return module.__index
            end)
            if success and type(result) == "table" then
                local name = tostring(result)
                if name:find(moduleName) then
                    return result
                end
            end
        end
    end
    
    -- Fallback: search through all modules
    for _, instance in pairs(getmodules()) do
        if instance.Name == moduleName then
            return require(instance)
        end
    end
    
    return nil
end

-- Hook the FirearmInventory module to modify RPM
local function hookFirearmInventory()
    if RapidFire.hooked then
        return true
    end
    
    local FirearmInventory = requireModule("FirearmInventory")
    if not FirearmInventory then
        warn("[Aeon] Failed to find FirearmInventory module")
        return false
    end
    
    -- Hook the _discharge function (called when weapon fires)
    local oldDischarge = FirearmInventory._discharge
    if not oldDischarge then
        warn("[Aeon] Failed to find _discharge function")
        return false
    end
    
    FirearmInventory._discharge = function(self, ...)
        if RapidFire.enabled then
            -- Modify the weapon's RPM
            if self._config and self._config.Tune then
                self._config.Tune.RPM = RapidFire.rpm
            end
        end
        
        return oldDischarge(self, ...)
    end
    
    RapidFire.hooked = true
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
