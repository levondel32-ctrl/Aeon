--[[
    Target Sizing Module for BRM5 PVP
    Handles adjustment of player target bounds for visibility/testing
]]

local TargetSizing = {
    originalSizes = {},
    enabled = false,
    config = {
        TARGET_BOX_SIZE = Vector3.new(10, 10, 10),
        showTargetBox = false
    }
}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

-- Applies target sizing to a specific player model
function TargetSizing:applyTargetSizing(model, root)
    if not model or not root or not root:IsA("BasePart") then
        return
    end
    
    if not self.originalSizes[model] then 
        self.originalSizes[model] = root.Size 
    end
    
    if root.Size ~= self.config.TARGET_BOX_SIZE then
        root.Size = self.config.TARGET_BOX_SIZE
    end
    
    local targetTransparency = self.config.showTargetBox and 0.85 or 1
    if root.Transparency ~= targetTransparency then
        root.Transparency = targetTransparency
    end
    
    if not root.CanCollide then
        root.CanCollide = true
    end
end

-- Restores target bounds to their normal size
function TargetSizing:restoreOriginalSize(model, root)
    if not root or not root:IsA("BasePart") then
        return
    end
    
    if self.originalSizes[model] then
        root.Size = self.originalSizes[model]
        root.Transparency = 1
        root.CanCollide = false
        self.originalSizes[model] = nil
    end
end

-- Updates target bounds for all player models
function TargetSizing:updateAllTargets()
    if not self.enabled then
        if next(self.originalSizes) then
            self:cleanup()
        end
        return
    end
    
    local localPlayer = Players.LocalPlayer
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= localPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                self:applyTargetSizing(player.Character, root)
            end
        end
    end
end

-- Cleanup all adjusted target bounds
function TargetSizing:cleanup()
    for model, _ in pairs(self.originalSizes) do
        if model and model.Parent then
            local root = model:FindFirstChild("HumanoidRootPart")
            if root then
                self:restoreOriginalSize(model, root)
            end
        end
    end
    self.originalSizes = {}
end

-- Public API
function TargetSizing.Enable()
    TargetSizing.enabled = true
end

function TargetSizing.Disable()
    TargetSizing.enabled = false
    TargetSizing:cleanup()
end

function TargetSizing.UpdateSettings(settings)
    if settings.TargetBoxSize ~= nil then
        TargetSizing.config.TARGET_BOX_SIZE = settings.TargetBoxSize
    end
    if settings.ShowTargetBox ~= nil then
        TargetSizing.config.showTargetBox = settings.ShowTargetBox
    end
end

return TargetSizing
