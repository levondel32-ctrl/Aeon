--[[
    Freeze Target Feature for Cursed Tank Simulator
    Freezes the tank under mouse cursor
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Vehicles = workspace:WaitForChild("Vehicles")

local FREEZE_CTS = {}

-- Freeze state
FREEZE_CTS.Enabled = false
FREEZE_CTS.FreezeConnection = nil
FREEZE_CTS.CurrentFrozenTank = nil
FREEZE_CTS.FrozenParts = {}

-- Get player from tank (same logic as ESP)
local function GetPlayerFromTank(model)
    local name = model.Name:lower()
    local playerName = name:gsub("chassis", "")
    for _, player in ipairs(Players:GetPlayers()) do
        if playerName:find(player.Name:lower()) then
            return player
        end
    end
    return nil
end

-- Get tank type
local function GetType(model)
    local player = GetPlayerFromTank(model)
    if not player then return "Enemy" end
    if player == LocalPlayer then return "Self" end
    if player.Team == LocalPlayer.Team then return "Ally" end
    return "Enemy"
end

-- Get tank under mouse cursor
local function GetTankUnderMouse()
    local Camera = workspace.CurrentCamera
    if not Camera then
        return nil
    end
    local mouse = UserInputService:GetMouseLocation()
    local ray = Camera:ViewportPointToRay(mouse.X, mouse.Y)
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Include
    raycastParams.FilterDescendantsInstances = {Vehicles}
    
    local result = workspace:Raycast(ray.Origin, ray.Direction * 5000, raycastParams)
    
    if result and result.Instance then
        local tank = result.Instance:FindFirstAncestorOfClass("Model")
        if tank and tank.Parent == Vehicles then
            -- Don't freeze self
            if GetType(tank) ~= "Self" then
                return tank
            end
        end
    end
    
    return nil
end

-- Freeze tank using multiple methods
local function FreezeTank(tank)
    for _, part in ipairs(tank:GetDescendants()) do
        if part:IsA("BasePart") and not FREEZE_CTS.FrozenParts[part] then
            -- Store original state
            FREEZE_CTS.FrozenParts[part] = {
                CFrame = part.CFrame,
                Anchored = part.Anchored,
                CanCollide = part.CanCollide
            }
            
            -- Try to set network ownership
            pcall(function()
                part:SetNetworkOwner(nil)
            end)
            
            -- Anchor the part
            part.Anchored = true
        end
    end
end

-- Unfreeze tank
local function UnfreezeTank(tank)
    for _, part in ipairs(tank:GetDescendants()) do
        if part:IsA("BasePart") and FREEZE_CTS.FrozenParts[part] then
            local original = FREEZE_CTS.FrozenParts[part]
            
            -- Restore original state
            part.Anchored = original.Anchored
            
            -- Clear from frozen parts
            FREEZE_CTS.FrozenParts[part] = nil
        end
    end
end

-- Maintain freeze (keep parts anchored)
local function MaintainFreeze()
    if not FREEZE_CTS.Enabled or not FREEZE_CTS.CurrentFrozenTank then return end
    
    local tank = FREEZE_CTS.CurrentFrozenTank
    if not tank or not tank.Parent then return end
    
    -- Keep all frozen parts anchored
    for part, data in pairs(FREEZE_CTS.FrozenParts) do
        if part and part.Parent then
            if not part.Anchored then
                part.Anchored = true
            end
            -- Lock to original position
            part.CFrame = data.CFrame
            part.AssemblyLinearVelocity = Vector3.zero
            part.AssemblyAngularVelocity = Vector3.zero
        end
    end
end

-- Freeze loop
local function FreezeLoop()
    if not FREEZE_CTS.Enabled then return end
    
    local targetTank = GetTankUnderMouse()
    
    -- Unfreeze previous tank if different
    if FREEZE_CTS.CurrentFrozenTank and FREEZE_CTS.CurrentFrozenTank ~= targetTank then
        if FREEZE_CTS.CurrentFrozenTank.Parent then
            UnfreezeTank(FREEZE_CTS.CurrentFrozenTank)
        end
        FREEZE_CTS.CurrentFrozenTank = nil
    end
    
    -- Freeze new tank
    if targetTank then
        if FREEZE_CTS.CurrentFrozenTank ~= targetTank then
            FreezeTank(targetTank)
            FREEZE_CTS.CurrentFrozenTank = targetTank
        else
            -- Maintain freeze on current tank
            MaintainFreeze()
        end
    end
end

-- Public functions
function FREEZE_CTS.Enable()
    if FREEZE_CTS.FreezeConnection then
        return
    end
    FREEZE_CTS.Enabled = true
    
    -- Start freeze loop
    FREEZE_CTS.FreezeConnection = RunService.Heartbeat:Connect(function()
        FreezeLoop()
    end)
end

function FREEZE_CTS.Disable()
    FREEZE_CTS.Enabled = false
    
    -- Stop freeze loop
    if FREEZE_CTS.FreezeConnection then
        FREEZE_CTS.FreezeConnection:Disconnect()
        FREEZE_CTS.FreezeConnection = nil
    end
    
    -- Unfreeze current tank
    if FREEZE_CTS.CurrentFrozenTank and FREEZE_CTS.CurrentFrozenTank.Parent then
        UnfreezeTank(FREEZE_CTS.CurrentFrozenTank)
    end
    
    FREEZE_CTS.CurrentFrozenTank = nil
    FREEZE_CTS.FrozenParts = {}
end

function FREEZE_CTS.Toggle(enabled)
    if enabled then
        FREEZE_CTS.Enable()
    else
        FREEZE_CTS.Disable()
    end
end

return FREEZE_CTS
