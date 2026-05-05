--[[
    ESP Module for BRM5 PVP
    Uses Highlight with visibility detection
    Male = Player, NPC = models with "AI" or "Bot" in name
]]

local ESP = {
    enabled = false,
    colorConnection = nil,
    descendantAddedConnection = nil,
    descendantRemovingConnection = nil,
    trackedModels = {},
    settings = {
        showNames = true,
        showDistance = true,
        showHealth = true,
        showBox = true,
        showNPCs = true,
        maxDistance = 1800,
        teamCheck = false,
        visibleColor = Color3.fromRGB(0, 255, 0),
        hiddenColor = Color3.fromRGB(255, 0, 0),
        npcColor = Color3.fromRGB(255, 165, 0)
    },
    npcNames = {
        ["Rifleman"] = true,
        ["Automatic Rifleman"] = true,
        ["Machine Gunner"] = true,
        ["Marksman"] = true,
        ["Sniper"] = true,
        ["Shotgunner"] = true,
        ["Submachine Gunner"] = true,
        ["Smoker"] = true,
        ["Spec Ops"] = true,
        ["Melee"] = true,
        ["Mortar"] = true,
        ["Anti-Tank"] = true,
        ["High-Value Target"] = true
    }
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Raycast params cache
local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.FilterDescendantsInstances = {}

local function isVisible(targetModel, camera)
    if not targetModel or not camera then
        return false
    end

    local head = targetModel:FindFirstChild("Head")
    if not head then
        return false
    end

    -- Update filter to exclude local player
    if LocalPlayer and LocalPlayer.Character then
        raycastParams.FilterDescendantsInstances = {LocalPlayer.Character}
    end

    local cameraPosition = camera.CFrame.Position
    local result = Workspace:Raycast(cameraPosition, head.Position - cameraPosition, raycastParams)
    
    return not result or result.Instance:IsDescendantOf(targetModel)
end

local function isNPC(model)
    -- NPC определяется по имени модели из списка (используем хеш-таблицу для O(1) lookup)
    return model and ESP.npcNames[model.Name] or false
end

local function shouldTrackModel(model)
    if not model or not model:IsA("Model") then
        return false
    end
    
    -- Must have Humanoid
    if not model:FindFirstChild("Humanoid") then
        return false
    end
    
    -- Skip local player
    if model == LocalPlayer.Character then
        return false
    end
    
    -- Skip dead models (with BallSocketConstraint = ragdoll)
    if model:FindFirstChildWhichIsA("BallSocketConstraint", true) then
        return false
    end
    
    local isMale = model.Name == "Male"
    local isNPCModel = isNPC(model)
    
    -- Must be Male or NPC
    if not (isMale or isNPCModel) then
        return false
    end
    
    -- Skip NPCs if disabled
    if isNPCModel and not ESP.settings.showNPCs then
        return false
    end
    
    return true, isNPCModel
end

local function addHighlight(model, isNPCModel)
    if ESP.trackedModels[model] then
        return
    end
    
    local highlight = model:FindFirstChild("Highlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Parent = model
        highlight.Adornee = model
        highlight.OutlineTransparency = 0.5
        highlight.FillTransparency = 0.8
    end
    
    ESP.trackedModels[model] = {
        isNPC = isNPCModel,
        highlight = highlight
    }
end

local function removeHighlight(model)
    local data = ESP.trackedModels[model]
    if not data then
        return
    end
    
    if data.highlight and data.highlight.Parent then
        data.highlight:Destroy()
    end
    
    ESP.trackedModels[model] = nil
end

local function onDescendantAdded(descendant)
    if not ESP.enabled then
        return
    end
    
    -- Only process Models
    if not descendant:IsA("Model") then
        return
    end
    
    -- Wait a frame for Humanoid to be added
    task.wait()
    
    local shouldTrack, isNPCModel = shouldTrackModel(descendant)
    if shouldTrack then
        addHighlight(descendant, isNPCModel)
    end
end

local function onDescendantRemoving(descendant)
    if not ESP.enabled then
        return
    end
    
    -- If a tracked model is being removed, clean it up
    if ESP.trackedModels[descendant] then
        removeHighlight(descendant)
    end
end

local function initializeExistingModels()
    -- Only called ONCE when ESP is enabled
    for _, descendant in pairs(Workspace:GetDescendants()) do
        if descendant:IsA("Model") then
            local shouldTrack, isNPCModel = shouldTrackModel(descendant)
            if shouldTrack then
                addHighlight(descendant, isNPCModel)
            end
        end
    end
end

local function updateColors()
    if not ESP.enabled then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    -- Fast color update for tracked models only
    for model, data in pairs(ESP.trackedModels) do
        -- Quick validity check (no heavy operations)
        if not model or not model.Parent then
            removeHighlight(model)
        elseif data.highlight and data.highlight.Parent then
            local color
            if data.isNPC then
                -- NPC uses NPC color
                color = ESP.settings.npcColor
            else
                -- Male players use visible/hidden colors
                local visible = isVisible(model, camera)
                color = visible and ESP.settings.visibleColor or ESP.settings.hiddenColor
            end
            
            data.highlight.Enabled = ESP.settings.showBox
            data.highlight.OutlineColor = color
            data.highlight.FillColor = color
        end
    end
end

-- Public API
function ESP.Enable()
    ESP.enabled = true

    -- Initialize existing models ONCE
    initializeExistingModels()
    
    -- Listen for new descendants (event-driven, no GetDescendants spam)
    ESP.descendantAddedConnection = Workspace.DescendantAdded:Connect(onDescendantAdded)
    
    -- Listen for removed descendants to clean up automatically
    ESP.descendantRemovingConnection = Workspace.DescendantRemoving:Connect(onDescendantRemoving)
    
    -- Start fast color update loop using RenderStepped for smooth updates
    ESP.colorConnection = RunService.RenderStepped:Connect(function()
        if not ESP.enabled then
            return
        end
        updateColors()
    end)
end

function ESP.Disable()
    ESP.enabled = false

    -- Stop event listeners
    if ESP.descendantAddedConnection then
        ESP.descendantAddedConnection:Disconnect()
        ESP.descendantAddedConnection = nil
    end
    
    if ESP.descendantRemovingConnection then
        ESP.descendantRemovingConnection:Disconnect()
        ESP.descendantRemovingConnection = nil
    end
    
    -- Stop color update loop
    if ESP.colorConnection then
        ESP.colorConnection:Disconnect()
        ESP.colorConnection = nil
    end

    -- Remove all highlights from tracked models
    for model in pairs(ESP.trackedModels) do
        removeHighlight(model)
    end
end

function ESP.UpdateSettings(newSettings)
    if newSettings.TeamCheck ~= nil then
        ESP.settings.teamCheck = newSettings.TeamCheck
    end
    if newSettings.ShowDistance ~= nil then
        ESP.settings.showDistance = newSettings.ShowDistance
    end
    if newSettings.ShowHealth ~= nil then
        ESP.settings.showHealth = newSettings.ShowHealth
    end
    if newSettings.ShowBox ~= nil then
        ESP.settings.showBox = newSettings.ShowBox
    end
    if newSettings.ShowNPCs ~= nil then
        ESP.settings.showNPCs = newSettings.ShowNPCs
        
        -- Re-evaluate all tracked models when NPC visibility changes
        if ESP.enabled then
            for model, data in pairs(ESP.trackedModels) do
                if data.isNPC and not ESP.settings.showNPCs then
                    removeHighlight(model)
                end
            end
        end
    end
    if newSettings.MaxDistance then
        ESP.settings.maxDistance = newSettings.MaxDistance
    end
end

return ESP
