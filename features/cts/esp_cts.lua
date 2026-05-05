--[[
	ESP Feature for Cursed Tank Simulator
	Handles all ESP-related functionality for tanks
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")

local Vehicles = workspace:WaitForChild("Vehicles")
local Highlights = {}

local ESP_CTS = {}

-- Configuration (will be set from main script)
ESP_CTS.Config = {
    EnemiesEnabled = true,
    TeamEnabled = false,
    NamesEnabled = true,
    DistanceEnabled = true,
    TracersEnabled = true,
    BoxesEnabled = true,
    HealthEnabled = true,
    
    EnemyColor = Color3.fromRGB(255, 40, 40),
    TeamColor = Color3.fromRGB(40, 255, 120),
    TracerColor = Color3.fromRGB(255, 255, 255),
    VisibleColor = Color3.fromRGB(0, 255, 255),
    
    TracerOrigin = "Bottom",
    TextSize = 14,
    RenderDistance = 5000,
    RainbowSpeed = 1
}

function ESP_CTS.GetHealth(tank)
    local hp = tank:GetAttribute("Health") or tank:GetAttribute("HP")
    local maxHp = tank:GetAttribute("MaxHealth") or tank:GetAttribute("MaxHP") or 100
    
    if hp then return hp, maxHp end
    
    for _, v in ipairs(tank:GetDescendants()) do
        if (v:IsA("NumberValue") or v:IsA("IntValue")) and (v.Name:lower():find("health") or v.Name:lower():find("hp")) then
            return v.Value, 100
        end
    end
    return 100, 100
end

function ESP_CTS.GetPlayerFromTank(model)
    local name = model.Name:lower()
    local playerName = name:gsub("chassis", "")
    for _, player in ipairs(Players:GetPlayers()) do
        if playerName:find(player.Name:lower()) then
            return player
        end
    end
    return nil
end

function ESP_CTS.GetType(model)
    local player = ESP_CTS.GetPlayerFromTank(model)
    if not player then return "Enemy" end
    if player == LocalPlayer then return "Self" end
    if player.Team == LocalPlayer.Team then return "Ally" end
    return "Enemy"
end

function ESP_CTS.CreateTracer()
    local line = Drawing.new("Line")
    line.Thickness = 1.5
    line.Transparency = 0.8
    return line
end

function ESP_CTS.UpdateESP(tank)
    if not tank:IsA("Model") then return end

    local tankType = ESP_CTS.GetType(tank)
    if tankType == "Self" then return end

    local hl = tank:FindFirstChild("Elite_Highlight") or Instance.new("Highlight")
    hl.Name = "Elite_Highlight"
    hl.FillTransparency = 0.4
    hl.OutlineTransparency = 0
    hl.Parent = tank

    local bg = tank:FindFirstChild("Elite_Billboard") or Instance.new("BillboardGui")
    bg.Name = "Elite_Billboard"
    bg.AlwaysOnTop = true
    bg.Size = UDim2.new(0, 200, 0, 70)
    bg.StudsOffset = Vector3.new(0, 12, 0)
    
    local container = bg:FindFirstChild("Container") or Instance.new("Frame")
    container.Name = "Container"
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1
    container.Parent = bg

    local nameLabel = container:FindFirstChild("Name") or Instance.new("TextLabel")
    nameLabel.Name = "Name"
    nameLabel.Size = UDim2.new(1, 0, 0.4, 0)
    nameLabel.Font = Enum.Font.RobotoMono
    nameLabel.TextSize = ESP_CTS.Config.TextSize
    nameLabel.TextStrokeTransparency = 0
    nameLabel.BackgroundTransparency = 1
    nameLabel.Parent = container

    local distLabel = container:FindFirstChild("Distance") or Instance.new("TextLabel")
    distLabel.Name = "Distance"
    distLabel.Position = UDim2.new(0, 0, 0.4, 0)
    distLabel.Size = UDim2.new(1, 0, 0.3, 0)
    distLabel.Font = Enum.Font.RobotoMono
    distLabel.TextSize = ESP_CTS.Config.TextSize
    distLabel.TextStrokeTransparency = 0
    distLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    distLabel.BackgroundTransparency = 1
    distLabel.Parent = container

    local healthLabel = container:FindFirstChild("Health") or Instance.new("TextLabel")
    healthLabel.Name = "Health"
    healthLabel.Position = UDim2.new(0, 0, 0.7, 0)
    healthLabel.Size = UDim2.new(1, 0, 0.3, 0)
    healthLabel.Font = Enum.Font.RobotoMono
    healthLabel.TextSize = ESP_CTS.Config.TextSize - 2
    healthLabel.TextStrokeTransparency = 0
    healthLabel.BackgroundTransparency = 1
    healthLabel.Parent = container

    bg.Parent = tank
    local tracerLine = ESP_CTS.CreateTracer()

    Highlights[tank] = {
        Highlight = hl,
        Billboard = bg,
        NameTag = nameLabel,
        DistTag = distLabel,
        HPLabel = healthLabel,
        Tracer = tracerLine,
        Type = tankType,
        Owner = ESP_CTS.GetPlayerFromTank(tank)
    }
end

function ESP_CTS.Initialize()
    local frameCounter = 0
    local ESP_UPDATE_RATE = 3
    
    if ESP_CTS._renderConnection then
        ESP_CTS._renderConnection:Disconnect()
        ESP_CTS._renderConnection = nil
    end
    if ESP_CTS._vehiclesChildAdded then
        ESP_CTS._vehiclesChildAdded:Disconnect()
        ESP_CTS._vehiclesChildAdded = nil
    end

    ESP_CTS._renderConnection = RunService.RenderStepped:Connect(function()
        frameCounter += 1
        
        if frameCounter % ESP_UPDATE_RATE ~= 0 then
            return
        end
        
        local Camera = workspace.CurrentCamera
        if not Camera then
            return
        end
        
        local camCFrame = Camera.CFrame
        local camPos = camCFrame.Position
        local viewport = Camera.ViewportSize
        
        local tracerOriginBottom = Vector2.new(viewport.X / 2, viewport.Y)
        local tracerOriginCenter = Vector2.new(viewport.X / 2, viewport.Y / 2)
        
        for tank, data in pairs(Highlights) do
            if not tank or not tank.Parent then
                if data.Tracer then
                    data.Tracer:Remove()
                end
                Highlights[tank] = nil
                continue
            end
            
            local part = tank.PrimaryPart or tank:FindFirstChildWhichIsA("BasePart")
            if not part then
                data.Highlight.Enabled = false
                data.Billboard.Enabled = false
                data.Tracer.Visible = false
                continue
            end
            
            local targetPos = part.Position
            local dist = (camPos - targetPos).Magnitude
            
            if dist > ESP_CTS.Config.RenderDistance then
                data.Highlight.Enabled = false
                data.Billboard.Enabled = false
                data.Tracer.Visible = false
                continue
            end
            
            local pos, onScreen = Camera:WorldToViewportPoint(targetPos)
            if not onScreen then
                data.Highlight.Enabled = false
                data.Billboard.Enabled = false
                data.Tracer.Visible = false
                continue
            end
            
            local isAlly = data.Type == "Ally"
            local show = false
            
            if isAlly and ESP_CTS.Config.TeamEnabled then
                show = true
            elseif not isAlly and ESP_CTS.Config.EnemiesEnabled then
                show = true
            end
            
            if not show then
                data.Highlight.Enabled = false
                data.Billboard.Enabled = false
                data.Tracer.Visible = false
                continue
            end
            
            local mainColor = isAlly and ESP_CTS.Config.TeamColor or ESP_CTS.Config.EnemyColor
            
            data.Highlight.Enabled = true
            data.Highlight.FillColor = mainColor
            
            data.Billboard.Enabled = true
            
            if data.LastName ~= tank.Name then
                local player = data.Owner
                data.NameTag.Text = player and player.Name or tank.Name:gsub("Chassis", "")
                data.LastName = tank.Name
            end
            
            data.NameTag.TextColor3 = mainColor
            
            data.DistTag.Visible = ESP_CTS.Config.DistanceEnabled
            if ESP_CTS.Config.DistanceEnabled then
                data.DistTag.Text = "[" .. math.floor(dist * 0.28) .. "m]"
                data.DistTag.TextColor3 = Color3.fromRGB(255, 255, 255)
            end
            
            if ESP_CTS.Config.HealthEnabled then
                local now = tick()
                if not data.NextHealthUpdate or now >= data.NextHealthUpdate then
                    local hp, mhp = ESP_CTS.GetHealth(tank)
                    data.CachedHP = hp
                    data.CachedMaxHP = mhp
                    data.NextHealthUpdate = now + 0.35
                end
                
                local hp = data.CachedHP or 100
                local mhp = data.CachedMaxHP or 100
                
                data.HPLabel.Visible = true
                data.HPLabel.Text = "HP: " .. math.floor(hp) .. "/" .. math.floor(mhp)
                data.HPLabel.TextColor3 = Color3.fromHSV(math.clamp(hp / mhp, 0, 1) * 0.3, 1, 1)
            else
                data.HPLabel.Visible = false
            end
            
            if ESP_CTS.Config.TracersEnabled then
                local origin
                
                if ESP_CTS.Config.TracerOrigin == "Bottom" then
                    origin = tracerOriginBottom
                elseif ESP_CTS.Config.TracerOrigin == "Center" then
                    origin = tracerOriginCenter
                else
                    local mousePos = UserInputService:GetMouseLocation()
                    origin = Vector2.new(mousePos.X, mousePos.Y)
                end
                
                data.Tracer.Visible = true
                data.Tracer.From = origin
                data.Tracer.To = Vector2.new(pos.X, pos.Y)
                data.Tracer.Color = ESP_CTS.Config.TracerColor
            else
                data.Tracer.Visible = false
            end
        end
    end)
    
    -- Initialize ESP for existing tanks
    for _, tank in ipairs(Vehicles:GetChildren()) do
        ESP_CTS.UpdateESP(tank)
    end
    ESP_CTS._vehiclesChildAdded = Vehicles.ChildAdded:Connect(ESP_CTS.UpdateESP)
end

function ESP_CTS.Cleanup()
    if ESP_CTS._renderConnection then
        ESP_CTS._renderConnection:Disconnect()
        ESP_CTS._renderConnection = nil
    end
    if ESP_CTS._vehiclesChildAdded then
        ESP_CTS._vehiclesChildAdded:Disconnect()
        ESP_CTS._vehiclesChildAdded = nil
    end
    for _, data in pairs(Highlights) do
        if data.Tracer then
            data.Tracer:Remove()
        end
        if data.Billboard then
            data.Billboard:Destroy()
        end
        if data.Highlight then
            data.Highlight:Destroy()
        end
    end
    Highlights = {}
end

return ESP_CTS
