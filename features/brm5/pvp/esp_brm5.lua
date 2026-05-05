--[[ 
    ESP Module for BRM5 PVP
    Optimized to reduce freezes
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

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Exclude
raycastParams.IgnoreWater = true

local raycastFilter = {}

local pendingModels = {}
local colorAccumulator = 0
local INITIAL_SCAN_BATCH = 120
local UPDATE_INTERVAL = 0.12

local function refreshRaycastFilter()
	table.clear(raycastFilter)
	if LocalPlayer and LocalPlayer.Character then
		raycastFilter[1] = LocalPlayer.Character
	end
	raycastParams.FilterDescendantsInstances = raycastFilter
end

local function isNPC(model)
	return model and ESP.npcNames[model.Name] or false
end

local function shouldTrackModel(model)
	if not model or not model:IsA("Model") then
		return false
	end

	if model == LocalPlayer.Character then
		return false
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	if humanoid.Health <= 0 then
		return false
	end

	local isMale = model.Name == "Male"
	local isNPCModel = isNPC(model)

	if not (isMale or isNPCModel) then
		return false
	end

	if isNPCModel and not ESP.settings.showNPCs then
		return false
	end

	return true, isNPCModel
end

local function addHighlight(model, isNPCModel)
	if ESP.trackedModels[model] then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ESP_Highlight"
	highlight.Adornee = model
	highlight.Parent = model
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.OutlineTransparency = 0.35
	highlight.FillTransparency = 0.85
	highlight.Enabled = false

	ESP.trackedModels[model] = {
		isNPC = isNPCModel,
		highlight = highlight,
		head = model:FindFirstChild("Head")
	}
end

local function removeHighlight(model)
	local data = ESP.trackedModels[model]
	if not data then
		return
	end

	if data.highlight then
		data.highlight:Destroy()
	end

	ESP.trackedModels[model] = nil
end

local function isVisible(targetModel, head, camera)
	if not targetModel or not camera or not head then
		return false
	end

	refreshRaycastFilter()

	local origin = camera.CFrame.Position
	local direction = head.Position - origin
	local result = Workspace:Raycast(origin, direction, raycastParams)

	return not result or result.Instance:IsDescendantOf(targetModel)
end

local function queueModel(model)
	if not ESP.enabled then
		return
	end

	if not model or not model:IsA("Model") then
		return
	end

	if pendingModels[model] or ESP.trackedModels[model] then
		return
	end

	pendingModels[model] = true

	task.defer(function()
		pendingModels[model] = nil

		if not ESP.enabled or not model or not model.Parent then
			return
		end

		local shouldTrack, isNPCModel = shouldTrackModel(model)
		if shouldTrack then
			addHighlight(model, isNPCModel)
		end
	end)
end

local function onDescendantAdded(descendant)
	if not ESP.enabled then
		return
	end

	if descendant:IsA("Model") then
		queueModel(descendant)
		return
	end

	local model = descendant:FindFirstAncestorOfClass("Model")
	if model then
		queueModel(model)
	end
end

local function onDescendantRemoving(descendant)
	if not ESP.enabled then
		return
	end

	if descendant:IsA("Model") and ESP.trackedModels[descendant] then
		removeHighlight(descendant)
	end
end

local function initializeExistingModels()
	local descendants = Workspace:GetDescendants()

	for i = 1, #descendants do
		local descendant = descendants[i]

		if descendant:IsA("Model") then
			local shouldTrack, isNPCModel = shouldTrackModel(descendant)
			if shouldTrack then
				addHighlight(descendant, isNPCModel)
			end
		end

		if i % INITIAL_SCAN_BATCH == 0 then
			task.wait()
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

	local cameraPos = camera.CFrame.Position
	local maxDistance = ESP.settings.maxDistance
	local showBox = ESP.settings.showBox

	for model, data in pairs(ESP.trackedModels) do
		if not model or not model.Parent then
			removeHighlight(model)
		else
			local highlight = data.highlight
			if highlight and highlight.Parent then
				local head = data.head
				if not head or not head.Parent then
					head = model:FindFirstChild("Head")
					data.head = head
				end

				if not head then
					highlight.Enabled = false
				else
					local distance = (cameraPos - head.Position).Magnitude
					if distance > maxDistance then
						highlight.Enabled = false
					else
						local color
						if data.isNPC then
							color = ESP.settings.npcColor
						else
							local visible = isVisible(model, head, camera)
							color = visible and ESP.settings.visibleColor or ESP.settings.hiddenColor
						end

						highlight.Enabled = showBox
						highlight.OutlineColor = color
						highlight.FillColor = color
					end
				end
			end
		end
	end
end

function ESP.Enable()
	if ESP.enabled then
		return
	end

	ESP.enabled = true
	colorAccumulator = 0

	task.spawn(initializeExistingModels)

	ESP.descendantAddedConnection = Workspace.DescendantAdded:Connect(onDescendantAdded)
	ESP.descendantRemovingConnection = Workspace.DescendantRemoving:Connect(onDescendantRemoving)

	ESP.colorConnection = RunService.Heartbeat:Connect(function(dt)
		if not ESP.enabled then
			return
		end

		colorAccumulator += dt
		if colorAccumulator < UPDATE_INTERVAL then
			return
		end

		colorAccumulator = 0
		updateColors()
	end)
end

function ESP.Disable()
	ESP.enabled = false
	colorAccumulator = 0
	table.clear(pendingModels)

	if ESP.descendantAddedConnection then
		ESP.descendantAddedConnection:Disconnect()
		ESP.descendantAddedConnection = nil
	end

	if ESP.descendantRemovingConnection then
		ESP.descendantRemovingConnection:Disconnect()
		ESP.descendantRemovingConnection = nil
	end

	if ESP.colorConnection then
		ESP.colorConnection:Disconnect()
		ESP.colorConnection = nil
	end

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

		if ESP.enabled then
			for model, data in pairs(ESP.trackedModels) do
				if data.isNPC and not ESP.settings.showNPCs then
					removeHighlight(model)
				end
			end

			if ESP.settings.showNPCs then
				task.spawn(initializeExistingModels)
			end
		end
	end

	if newSettings.MaxDistance ~= nil then
		ESP.settings.maxDistance = newSettings.MaxDistance
	end
end

return ESP