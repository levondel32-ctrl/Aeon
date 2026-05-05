--[[
    Rapid Fire Module for BRM5 PVP
    Modifies weapon RPM (Rounds Per Minute) for faster shooting
]]

local RapidFire = {
    enabled = false,
    rpm = 1000,
    hooked = false,
    originalConfigs = {},
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Method 1: Direct config patching (most reliable for BRM5)
local function patchWeaponConfigs()
    local weaponConfigs = ReplicatedStorage:FindFirstChild("Shared")
    if not weaponConfigs then return false end
    
    weaponConfigs = weaponConfigs:FindFirstChild("Configs")
    if not weaponConfigs then return false end
    
    weaponConfigs = weaponConfigs:FindFirstChild("Weapon")
    if not weaponConfigs then return false end
    
    local patchedCount = 0
    
    -- Iterate through all weapon config modules
    for _, weaponFolder in pairs(weaponConfigs:GetChildren()) do
        if weaponFolder:IsA("Folder") then
            for _, configModule in pairs(weaponFolder:GetDescendants()) do
                if configModule:IsA("ModuleScript") then
                    local success, config = pcall(require, configModule)
                    if success and type(config) == "table" then
                        -- Look for Tune table with RPM
                        if config.Tune and type(config.Tune) == "table" and type(config.Tune.RPM) == "number" then
                            -- Save original RPM if not already saved
                            if not RapidFire.originalConfigs[config.Tune] then
                                RapidFire.originalConfigs[config.Tune] = config.Tune.RPM
                            end
                            
                            -- Apply rapid fire if enabled
                            if RapidFire.enabled then
                                config.Tune.RPM = RapidFire.rpm
                                patchedCount = patchedCount + 1
                            end
                        end
                    end
                end
            end
        end
    end
    
    return patchedCount > 0
end

-- Method 2: Hook Item module (fallback)
local function hookItemModule()
    local itemModule = ReplicatedStorage:FindFirstChild("Shared")
    if itemModule then
        itemModule = itemModule:FindFirstChild("Inventory")
        if itemModule then
            itemModule = itemModule:FindFirstChild("Item")
            if itemModule and itemModule:IsA("ModuleScript") then
                local success, Item = pcall(require, itemModule)
                if success and type(Item) == "table" then
                    -- Try to hook any fire-related methods
                    for key, value in pairs(Item) do
                        if type(value) == "function" and (key:lower():find("fire") or key:lower():find("shoot") or key:lower():find("discharge")) then
                            local original = value
                            Item[key] = function(...)
                                -- Patch configs before firing
                                if RapidFire.enabled then
                                    patchWeaponConfigs()
                                end
                                return original(...)
                            end
                            return true
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Public API
function RapidFire.Enable()
    RapidFire.enabled = true
    
    -- Try direct patching first
    local success = patchWeaponConfigs()
    
    if not success then
        -- Fallback to hooking
        task.spawn(function()
            local hooked = hookItemModule()
            if not hooked then
                warn("[Aeon] Rapid Fire: Failed to patch weapon configs")
            end
        end)
    end
    
    RapidFire.hooked = true
end

function RapidFire.Disable()
    RapidFire.enabled = false
    
    -- Restore original RPM values
    for tune, originalRPM in pairs(RapidFire.originalConfigs) do
        if type(tune) == "table" and type(originalRPM) == "number" then
            tune.RPM = originalRPM
        end
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
        
        -- Re-apply if already enabled
        if RapidFire.enabled then
            patchWeaponConfigs()
        end
    end
end

return RapidFire
