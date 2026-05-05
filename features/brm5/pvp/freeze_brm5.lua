--[[
    Freeze Target Feature for BRM5 PVP
    Freeze is controlled by toggle state only.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Freeze = {
	enabled = false,
	frozenModels = {}, -- [Model] = { cframe = CFrame, bodyVelocity = Instance, bodyGyro = Instance, humanoid = Humanoid, oldWalkSpeed = number, animator = Animator }
	connection = nil,
}

local function getRoot(model)
	if not model or not model:IsA("Model") then
		return nil
	end
	return model:FindFirstChild("HumanoidRootPart")
end

local function freezeMale(maleModel)
	local hrp = getRoot(maleModel)
	if not hrp then
		return false
	end

	if Freeze.frozenModels[maleModel] then
		return true
	end

	local humanoid = maleModel:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return false
	end

	-- Stop all animations
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then
		for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
			track:Stop(0)
		end
	end

	-- Disable Humanoid movement controller
	local oldWalkSpeed = humanoid.WalkSpeed
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.AutoRotate = false
	
	-- Set Humanoid state to Physics to disable internal controller
	pcall(function()
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end)

	-- Anchor all body parts to completely freeze physics
	for _, part in ipairs(maleModel:GetDescendants()) do
		if part:IsA("BasePart") and part ~= hrp then
			part.Anchored = true
		end
	end

	-- Create BodyVelocity to lock position
	local bodyVelocity = Instance.new("BodyVelocity")
	bodyVelocity.Velocity = Vector3.zero
	bodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
	bodyVelocity.P = 10000
	bodyVelocity.Parent = hrp

	-- Create BodyGyro to lock rotation
	local bodyGyro = Instance.new("BodyGyro")
	bodyGyro.CFrame = hrp.CFrame
	bodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
	bodyGyro.P = 10000
	bodyGyro.D = 500
	bodyGyro.Parent = hrp

	-- Save state
	Freeze.frozenModels[maleModel] = {
		cframe = hrp.CFrame,
		bodyVelocity = bodyVelocity,
		bodyGyro = bodyGyro,
		humanoid = humanoid,
		oldWalkSpeed = oldWalkSpeed,
		animator = animator,
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
		state.humanoid.JumpPower = 50
		state.humanoid.AutoRotate = true
		
		-- Restore normal state
		pcall(function()
			state.humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end

	-- Unanchor all body parts
	for _, part in ipairs(maleModel:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false
		end
	end

	-- Remove BodyVelocity and BodyGyro
	if state.bodyVelocity and state.bodyVelocity.Parent then
		state.bodyVelocity:Destroy()
	end
	if state.bodyGyro and state.bodyGyro.Parent then
		state.bodyGyro:Destroy()
	end

	Freeze.frozenModels[maleModel] = nil
end

local function unfreezeAll()
	for maleModel in pairs(Freeze.frozenModels) do
		unfreezeMale(maleModel)
	end
end

local function freezeLoop()
	if not Freeze.enabled then
		unfreezeAll()
		return
	end

	for _, desc in ipairs(Workspace:GetDescendants()) do
		if desc:IsA("Model") and desc.Name == "Male" then
			if LocalPlayer.Character ~= desc then
				local hrp = getRoot(desc)
				if hrp and Freeze.frozenModels[desc] then
					-- Keep frozen position locked
					local state = Freeze.frozenModels[desc]
					if state.bodyVelocity and state.bodyVelocity.Parent then
						state.bodyVelocity.Velocity = Vector3.zero
						hrp.CFrame = state.cframe
					end
					if state.bodyGyro and state.bodyGyro.Parent then
						state.bodyGyro.CFrame = state.cframe
					end
					
					-- Keep Humanoid disabled
					if state.humanoid and state.humanoid.Parent then
						state.humanoid.WalkSpeed = 0
						state.humanoid.JumpPower = 0
						pcall(function()
							if state.humanoid:GetState() ~= Enum.HumanoidStateType.Physics then
								state.humanoid:ChangeState(Enum.HumanoidStateType.Physics)
							end
						end)
					end
				else
					freezeMale(desc)
				end
			end
		end
	end
end

function Freeze.Enable()
	Freeze.enabled = true

	if not Freeze.connection then
		Freeze.connection = RunService.Heartbeat:Connect(freezeLoop)
	end
end

function Freeze.Disable()
	Freeze.enabled = false
	unfreezeAll()

	if Freeze.connection then
		Freeze.connection:Disconnect()
		Freeze.connection = nil
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
