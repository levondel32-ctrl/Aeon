--[[
	Camera Feature for Cursed Tank Simulator
	Handles infinite camera zoom functionality for tanks
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer

local Vehicles = workspace:WaitForChild("Vehicles")

local CAMERA_CTS = {}

-- Camera state
CAMERA_CTS.zoom = 15
CAMERA_CTS.minZoom = 0.5
CAMERA_CTS.maxZoom = 999999
CAMERA_CTS.zoomStep = 5
CAMERA_CTS.cameraEnabled = false
CAMERA_CTS.CameraZoomConnection = nil

-- Helper function to get player from tank
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

-- Get local player's tank
local function getLocalTank()
    local lpName = LocalPlayer.Name:lower()
    
    for _, model in ipairs(Vehicles:GetChildren()) do
        if model:IsA("Model") then
            local modelName = model.Name:lower()
            
            if modelName:find(lpName) then
                return model
            end
            
            local owner = GetPlayerFromTank(model)
            if owner == LocalPlayer then
                return model
            end
        end
    end
    
    return nil
end

-- Get best part from tank for camera focus
local function getBestTankPart(tank)
    if not tank then return nil end
    
    if tank.PrimaryPart then
        return tank.PrimaryPart
    end
    
    local possibleNames = {
        "Chassis",
        "Hull",
        "Body",
        "Base",
        "Main",
        "VehicleSeat",
        "Seat",
        "Root",
        "Turret"
    }
    
    for _, name in ipairs(possibleNames) do
        local obj = tank:FindFirstChild(name, true)
        if obj and obj:IsA("BasePart") then
            return obj
        end
    end
    
    local biggest = nil
    local biggestSize = 0
    
    for _, obj in ipairs(tank:GetDescendants()) do
        if obj:IsA("BasePart") then
            local size = obj.Size.X * obj.Size.Y * obj.Size.Z
            if size > biggestSize then
                biggestSize = size
                biggest = obj
            end
        end
    end
    
    return biggest
end

function CAMERA_CTS.Enable()
    if CAMERA_CTS.cameraEnabled then
        return
    end
    CAMERA_CTS.cameraEnabled = true
    CAMERA_CTS.zoom = 80
    
    LocalPlayer.CameraMaxZoomDistance = 999999
    LocalPlayer.CameraMinZoomDistance = 0.5
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    
    -- Mouse wheel zoom control
    CAMERA_CTS.CameraZoomConnection = UserInputService.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseWheel then
            CAMERA_CTS.zoom = math.clamp(CAMERA_CTS.zoom - input.Position.Z * 20, 30, 5000)
        end
    end)
    
    -- Camera render step
    RunService:BindToRenderStep(
        "AeonTankCameraOverride",
        Enum.RenderPriority.Last.Value,
        function()
            if not CAMERA_CTS.cameraEnabled then return end
            
            local Camera = workspace.CurrentCamera
            if not Camera then return end
            
            local tank = getLocalTank()
            if not tank then return end
            
            local targetPart = getBestTankPart(tank)
            if not targetPart then return end
            
            Camera.CameraType = Enum.CameraType.Custom
            
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and Camera.CameraSubject ~= hum then
                Camera.CameraSubject = hum
            end
            
            local focus = targetPart.Position + Vector3.new(0, 8, 0)
            
            local currentCFrame = Camera.CFrame
            local look = currentCFrame.LookVector
            
            if look.Magnitude <= 0 then
                look = targetPart.CFrame.LookVector
            end
            
            look = look.Unit
            
            local height = math.clamp(CAMERA_CTS.zoom * 0.18, 8, 120)
            local camPos = focus - look * CAMERA_CTS.zoom + Vector3.new(0, height, 0)
            
            Camera.CFrame = CFrame.new(camPos, camPos + look)
            Camera.Focus = CFrame.new(focus)
        end
    )
end

function CAMERA_CTS.Disable()
    CAMERA_CTS.cameraEnabled = false
    
    RunService:UnbindFromRenderStep("AeonTankCameraOverride")
    
    if CAMERA_CTS.CameraZoomConnection then
        CAMERA_CTS.CameraZoomConnection:Disconnect()
        CAMERA_CTS.CameraZoomConnection = nil
    end
    
    LocalPlayer.CameraMaxZoomDistance = 128
    LocalPlayer.CameraMinZoomDistance = 0.5
    
    local Camera = workspace.CurrentCamera
    if Camera then
        Camera.CameraType = Enum.CameraType.Custom
        
        local char = LocalPlayer.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if hum then
            Camera.CameraSubject = hum
        end
    end
    
    CAMERA_CTS.zoom = 15
end

function CAMERA_CTS.Toggle(enabled)
    if enabled then
        CAMERA_CTS.Enable()
    else
        CAMERA_CTS.Disable()
    end
end

return CAMERA_CTS
