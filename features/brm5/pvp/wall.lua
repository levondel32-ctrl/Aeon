local Walls = {
    trackedHeads = {},
    connections = {}
}

local function isTargetModel(instance, config)
    return instance and instance:IsA("Model") and instance.Name == config.TARGET_NAME
end

-- Heads are the canonical tracked parts for both ESP coloring and aim target
-- selection, so every public function in this module maintains that set.
function Walls:destroyAllBoxes()
    for head in pairs(self.trackedHeads) do
        if head and head.Parent then
            local box = head:FindFirstChild("Wall_Box")
            if box then
                box:Destroy()
            end
        end
    end
    self.trackedHeads = {}
end

function Walls:untrackHead(head)
    if not head then
        return
    end

    self.trackedHeads[head] = nil
    local box = head:FindFirstChild("Wall_Box")
    if box then
        box:Destroy()
    end
end

function Walls:createBoxForHead(head, config)
    if not head or not head:IsA("BasePart") or head.Parent == nil then
        return
    end

    -- Reuse existing adornments so toggling Walls does not constantly rebuild
    -- instances for already tracked targets.
    local existing = head:FindFirstChild("Wall_Box")
    if existing and existing:IsA("BoxHandleAdornment") then
        existing.Transparency = config.wallEnabled and config.BOX_TRANSPARENCY or 1
        self.trackedHeads[head] = true
        return
    end

    local box = Instance.new("BoxHandleAdornment")
    box.Name = "Wall_Box"
    box.Size = head.Size + Vector3.new(0.1, 0.1, 0.1)
    box.Adornee = head
    box.AlwaysOnTop = true
    box.ZIndex = 5
    box.Color3 = config.hiddenColor
    box.Transparency = config.wallEnabled and config.BOX_TRANSPARENCY or 1
    box.Visible = true
    box.Parent = head

    self.trackedHeads[head] = true
end

function Walls:registerModel(model, config)
    if not isTargetModel(model, config) then
        return
    end

    local head = model:FindFirstChild(config.TARGET_PART)
    if not head or not head:IsA("BasePart") then
        return
    end

    self.trackedHeads[head] = true
    self:createBoxForHead(head, config)
end

function Walls:refreshTrackedTargets(workspace, config)
    for _, instance in ipairs(workspace:GetDescendants()) do
        if isTargetModel(instance, config) then
            self:registerModel(instance, config)
        end
    end
end

function Walls:setupListener(workspace, config)
    table.insert(self.connections, workspace.DescendantAdded:Connect(function(instance)
        if not isTargetModel(instance, config) then
            return
        end

        -- Newly spawned models often arrive before their Head exists, so a
        -- short delay makes registration much more reliable.
        task.delay(0.5, function()
            if config.isUnloaded then
                return
            end
            self:registerModel(instance, config)
        end)
    end))
end

function Walls:setWallEnabled(enabled, config)
    config.wallEnabled = enabled

    for head in pairs(self.trackedHeads) do
        if head and head.Parent then
            local box = head:FindFirstChild("Wall_Box")
            if box then
                box.Transparency = enabled and config.BOX_TRANSPARENCY or 1
            end
        else
            self.trackedHeads[head] = nil
        end
    end
end

function Walls:updateColors(camera, workspace, localPlayer, config)
    if not camera then
        return
    end

    -- Reuse raycast params to avoid creating new objects every frame
    if not self.raycastParams then
        self.raycastParams = RaycastParams.new()
        self.raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
    end
    
    -- Update filter only when character changes
    local character = localPlayer and localPlayer.Character
    if character ~= self.lastCharacter then
        self.lastCharacter = character
        self.raycastParams.FilterDescendantsInstances = character and {character} or {}
    end

    local cameraPosition = camera.CFrame.Position
    local headsToRemove = {}
    
    -- Batch process heads - limit raycasts per frame to prevent freezes
    local processedCount = 0
    local MAX_RAYCASTS_PER_FRAME = 10
    
    for head in pairs(self.trackedHeads) do
        if not head or not head.Parent or not head:IsDescendantOf(workspace) then
            table.insert(headsToRemove, head)
        else
            local model = head.Parent
            local box = head:FindFirstChild("Wall_Box")
            
            if not box then
                self:createBoxForHead(head, config)
                box = head:FindFirstChild("Wall_Box")
            end
            
            if box then
                -- Check for ragdoll/dead state (cached in model to avoid repeated searches)
                if not model:GetAttribute("IsRagdoll") then
                    local hasConstraint = model:FindFirstChildWhichIsA("BallSocketConstraint", true)
                    if hasConstraint then
                        model:SetAttribute("IsRagdoll", true)
                    end
                end
                
                if model:GetAttribute("IsRagdoll") then
                    box.Visible = false
                else
                    -- Limit raycasts per frame
                    if processedCount < MAX_RAYCASTS_PER_FRAME then
                        local result = workspace:Raycast(cameraPosition, head.Position - cameraPosition, self.raycastParams)
                        local isVisible = not result or result.Instance:IsDescendantOf(model)
                        box.Visible = true
                        box.Color3 = isVisible and config.visibleColor or config.hiddenColor
                        box.Transparency = config.wallEnabled and config.BOX_TRANSPARENCY or 1
                        processedCount = processedCount + 1
                    end
                end
            end
        end
    end
    
    -- Clean up invalid heads
    for _, head in ipairs(headsToRemove) do
        self.trackedHeads[head] = nil
    end
end

function Walls:cleanup()
    for _, connection in ipairs(self.connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    self.connections = {}
    self.raycastParams = nil
    self.lastCharacter = nil
    self:destroyAllBoxes()
end

return Walls