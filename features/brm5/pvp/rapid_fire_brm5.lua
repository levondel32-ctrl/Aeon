--[[
    Rapid Fire Module for BRM5 PVP
    Hooks Tool.Activated to bypass fire rate
]]

local RapidFire = {
    enabled = false,
    rpm = 1000,
    lastShot = 0,
    connections = {},
}

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Calculate delay from RPM
local function getRPMDelay()
    return 60 / RapidFire.rpm
end

-- Hook a tool's Activated event
local function hookTool(tool)
    if not tool:IsA("Tool") then return end
    
    -- Disconnect old connection if exists
    if RapidFire.connections[tool] then
        RapidFire.connections[tool]:Disconnect()
    end
    
    -- Store original Activated
    local originalActivated = tool.Activated
    
    -- Hook Activated
    RapidFire.connections[tool] = tool.Activated:Connect(function()
        if not RapidFire.enabled then return end
        
        local currentTime = tick()
        local timeSinceLastShot = currentTime - RapidFire.lastShot
        local requiredDelay = getRPMDelay()
        
        if timeSinceLastShot >= requiredDelay then
            RapidFire.lastShot = currentTime
            -- Let the shot go through
        else
            -- Too soon, but we'll allow it anyway for rapid fire
            RapidFire.lastShot = currentTime
        end
    end)
end

-- Monitor character for new tools
local function monitorCharacter(character)
    if not character then return end
    
    -- Hook existing tools
    for _, tool in pairs(character:GetChildren()) do
        hookTool(tool)
    end
    
    -- Hook new tools
    character.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            hookTool(child)
        end
    end)
end

-- Monitor backpack for tools
local function monitorBackpack()
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not backpack then return end
    
    for _, tool in pairs(backpack:GetChildren()) do
        hookTool(tool)
    end
    
    backpack.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            hookTool(child)
        end
    end)
end

-- Alternative: Hook mouse click and spam fire
local mouse
local mouseConnection
local function setupMouseSpam()
    if not LocalPlayer:GetMouse() then return end
    mouse = LocalPlayer:GetMouse()
    
    if mouseConnection then
        mouseConnection:Disconnect()
    end
    
    mouseConnection = mouse.Button1Down:Connect(function()
        if not RapidFire.enabled then return end
        
        task.spawn(function()
            while RapidFire.enabled and mouse.Button1Down do
                local tool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if tool then
                    tool:Activate()
                end
                task.wait(getRPMDelay())
            end
        end)
    end)
end

-- Public API
function RapidFire.Enable()
    RapidFire.enabled = true
    
    -- Setup character monitoring
    if LocalPlayer.Character then
        monitorCharacter(LocalPlayer.Character)
    end
    
    LocalPlayer.CharacterAdded:Connect(function(character)
        monitorCharacter(character)
    end)
    
    -- Setup backpack monitoring
    monitorBackpack()
    
    -- Setup mouse spam as fallback
    setupMouseSpam()
end

function RapidFire.Disable()
    RapidFire.enabled = false
    
    -- Disconnect all tool connections
    for tool, connection in pairs(RapidFire.connections) do
        connection:Disconnect()
    end
    RapidFire.connections = {}
    
    -- Disconnect mouse
    if mouseConnection then
        mouseConnection:Disconnect()
        mouseConnection = nil
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
