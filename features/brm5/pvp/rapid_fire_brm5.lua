--[[
    Rapid Fire Module for BRM5 PVP
    Modifies weapon RPM (Rounds Per Minute) for faster shooting
]]

local RapidFire = {
    enabled = false,
    rpm = 1000,
    hooked = false,
}

local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Hook __index metamethod to intercept RPM reads
local function hookMetatable()
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    
    setreadonly(mt, false)
    
    mt.__index = newcclosure(function(t, k)
        if RapidFire.enabled and k == "RPM" and type(rawget(t, "RPM")) == "number" then
            return RapidFire.rpm
        end
        return oldIndex(t, k)
    end)
    
    setreadonly(mt, true)
    return true
end

-- Direct config patching
local function patchAllConfigs()
    local weaponPath = ReplicatedStorage:FindFirstChild("Shared")
    if not weaponPath then return 0 end
    
    weaponPath = weaponPath:FindFirstChild("Configs")
    if not weaponPath then return 0 end
    
    weaponPath = weaponPath:FindFirstChild("Weapon")
    if not weaponPath then return 0 end
    
    local count = 0
    
    for _, folder in pairs(weaponPath:GetDescendants()) do
        if folder:IsA("ModuleScript") then
            local success, config = pcall(require, folder)
            if success and type(config) == "table" then
                if config.Tune and type(config.Tune.RPM) == "number" then
                    if RapidFire.enabled then
                        config.Tune.RPM = RapidFire.rpm
                    end
                    count = count + 1
                end
            end
        end
    end
    
    return count
end

-- Continuous patching loop
local patchConnection
local function startPatchLoop()
    if patchConnection then return end
    
    patchConnection = game:GetService("RunService").Heartbeat:Connect(function()
        if RapidFire.enabled then
            patchAllConfigs()
        end
    end)
end

local function stopPatchLoop()
    if patchConnection then
        patchConnection:Disconnect()
        patchConnection = nil
    end
end

-- Public API
function RapidFire.Enable()
    RapidFire.enabled = true
    
    -- Try metamethod hook first
    if not RapidFire.hooked then
        local success = pcall(hookMetatable)
        if success then
            RapidFire.hooked = true
        end
    end
    
    -- Start continuous patching
    startPatchLoop()
    
    -- Initial patch
    local count = patchAllConfigs()
end

function RapidFire.Disable()
    RapidFire.enabled = false
    stopPatchLoop()
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
