--[[
    Freeze Target Feature for BRM5 PVP
    Properly freezes Humanoid controller and physics
    Fixed: Only anchors HumanoidRootPart to prevent falling through ground
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Freeze = {
	enabled = false,
	frozenModels = {}, -- [Model] = { humanoid = Humanoid, hrp = BasePart, oldWalkSpeed = number, oldJumpPower = number, frozenCFrame = CFrame }
	connection = nil,
	trackedModels = {}, -- Cache of Male models to avoid GetDescendants spam
	descendantConnection = nil,
	removingConnection = nil,
}

local function getHumanoid(model)
	if not model or not model:IsA("Model") then
		return nil
	end
	return model:FindFirstChildOfClass("Humanoid")
end

local function getHumanoidRootPart(model)
	if not model or not model:IsA("Model") then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart")
end

local function isValidTarget(model)
	if not model or not model:IsA("Model") then
		return false
	end
	
	if model.Name ~= "Male" then
		return false
	end
	
	if model == LocalPlayer.Character then
		return false
	end
	
	local humanoid = getHumanoid(model)
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	
	return true
end

local function freezeMale(maleModel)
	if Freeze.frozenModels[maleModel] then
		return true
	end

	local humanoid = getHumanoid(maleModel)
	local hrp = getHumanoidRootPart(maleModel)
	
	if not humanoid or not hrp then
		return false
	end

	-- Stop all animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			pcall(function()
				track:Stop(0)
			end)
		end
	end

	-- Save original values
	local oldWalkSpeed = humanoid.WalkSpeed
	local oldJumpPower = humanoid.JumpPower

	-- Disable Humanoid movement completely
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	humanoid.PlatformStand = true -- This disables the Humanoid controller

	-- Save current CFrame before anchoring
	local frozenCFrame = hrp.CFrame
	
	-- CRITICAL: Only anchor HumanoidRootPart, NOT all parts
	-- Anchoring all parts causes joints to break and character falls through ground
	hrp.Anchored = true
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero

	-- Save state
	Freeze.frozenModels[maleModel] = {
		humanoid = humanoid,
		hrp = hrp,
		oldWalkSpeed = oldWalkSpeed,
		oldJumpPower = oldJumpPower,
		frozenCFrame = frozenCFrame,
	}

	return true
end

local function unfreezeMale(maleModel)
	local state = Freeze.frozenModels[maleModel]
	if not state then
		return
	end

	-- Restore Humanoid settings
	if state.humanoid and state.humanoid.Parent then
		state.humanoid.WalkSpeed = state.oldWalkSpeed
		state.humanoid.JumpPower = state.oldJumpPower
		state.humanoid.AutoRotate = true
		state.humanoid.PlatformStand = false
	end

	-- Unanchor HumanoidRootPart
	if state.hrp and state.hrp.Parent then
		state.hrp.Anchored = false
	end

	Freeze.frozenModels[maleModel] = nil
end

local function unfreezeAll()
	for maleModel in pairs(Freeze.frozenModels) do
		unfreezeMale(maleModel)
	end
end

local function cleanupInvalidModels()
	-- Clean up tracked models that no longer exist
	for model in pairs(Freeze.trackedModels) do
		if not model or not model.Parent then
			Freeze.trackedModels[model] = nil
		end
	end
	
	-- Clean up frozen models that no longer exist
	for model in pairs(Freeze.frozenModels) do
		if not model or not model.Parent then
			unfreezeMale(model)
		end
	end
end

local function freezeLoop()
	if not Freeze.enabled then
		return
	end

	-- Freeze all tracked models
	for model in pairs(Freeze.trackedModels) do
		if model and model.Parent and isValidTarget(model) then
			if not Freeze.frozenModels[model] then
				freezeMale(model)
			else
				-- Keep frozen state maintained
				local state = Freeze.frozenModels[model]
				
				-- Keep Humanoid disabled
				if state.humanoid and state.humanoid.Parent then
					state.humanoid.WalkSpeed = 0
					state.humanoid.JumpPower = 0
					state.humanoid.PlatformStand = true
				end
				
				-- Keep HRP anchored and in frozen position
				if state.hrp and state.hrp.Parent then
					state.hrp.Anchored = true
					state.hrp.CFrame = state.frozenCFrame
					state.hrp.AssemblyLinearVelocity = Vector3.zero
					state.hrp.AssemblyAngularVelocity = Vector3.zero
				end
			end
		end
	end
	
	-- Periodic cleanup (every ~3 seconds)
	if math.random(1, 180) == 1 then
		cleanupInvalidModels()
	end
end

local function onDescendantAdded(descendant)
	if not Freeze.enabled then
		return
	end
	
	if descendant:IsA("Model") and isValidTarget(descendant) then
		Freeze.trackedModels[descendant] = true
	end
end

local function onDescendantRemoving(descendant)
	if descendant:IsA("Model") and Freeze.trackedModels[descendant] then
		Freeze.trackedModels[descendant] = nil
		if Freeze.frozenModels[descendant] then
			unfreezeMale(descendant)
		end
	end
end

function Freeze.Enable()
	Freeze.enabled = true

	-- Initial scan for Male models
	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("Model") and isValidTarget(desc) then
			Freeze.trackedModels[desc] = true
		end
	end

	-- Setup event listeners to track new/removed models
	if not Freeze.descendantConnection then
		Freeze.descendantConnection = Workspace.DescendantAdded:Connect(onDescendantAdded)
	end
	
	if not Freeze.removingConnection then
		Freeze.removingConnection = Workspace.DescendantRemoving:Connect(onDescendantRemoving)
	end

	-- Start freeze loop
	if not Freeze.connection then
		Freeze.connection = RunService.Heartbeat:Connect(freezeLoop)
	end
end

function Freeze.Disable()
	Freeze.enabled = false
	unfreezeAll()
	
	-- Clear tracked models
	table.clear(Freeze.trackedModels)

	-- Disconnect all connections
	if Freeze.connection then
		Freeze.connection:Disconnect()
		Freeze.connection = nil
	end
	
	if Freeze.descendantConnection then
		Freeze.descendantConnection:Disconnect()
		Freeze.descendantConnection = nil
	end
	
	if Freeze.removingConnection then
		Freeze.removingConnection:Disconnect()
		Freeze.removingConnection = nil
	end
end

function Freeze.Toggle(state)
	if state then
		Freeze.Enable()
	else
		Freeze.Disable()
	end
end

function Freeze.UpdateSettings(_)
	-- reserved
end

return Freeze
