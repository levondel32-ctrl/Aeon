--[[
BRM5 UI Configuration
Defines the user interface for Blackhawk Rescue Mission 5
]]

local library = loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/UILibrary/UILibrary.lua'))()
local Wait = library.subs.Wait

-- Get features from global environment
local ESP = getgenv().BRM5_Features.ESP
local Aimbot = getgenv().BRM5_Features.Aimbot
local Freeze = getgenv().BRM5_Features.Freeze
local NoRecoil = getgenv().BRM5_Features.NoRecoil
local Fullbright = getgenv().BRM5_Features.Fullbright
local Wall = getgenv().BRM5_Features.Wall
local AllyScan = getgenv().BRM5_Features.AllyScan

-- Wall system configuration
local wallConfig = {
    TARGET_NAME = "Male",
    TARGET_PART = "Head",
    REQUIRED_CHILD = "Wall_Box",
    BOX_TRANSPARENCY = 0.5,
    visibleColor = Color3.fromRGB(0, 255, 0),
    hiddenColor = Color3.fromRGB(255, 0, 0),
    wallEnabled = false,
    isUnloaded = false,
    ALLY_SCAN_DURATION = 3,
    ALLY_SCAN_CHECK_INTERVAL = 0.5
}

-- Services for Wall and AllyScan
local services = {
    Players = game:GetService("Players"),
    RunService = game:GetService("RunService"),
    Workspace = game:GetService("Workspace"),
    camera = workspace.CurrentCamera
}

-- Initialize Wall system
Wall:refreshTrackedTargets(services.Workspace, wallConfig)
Wall:setupListener(services.Workspace, wallConfig)

-- Set Wall system reference in Aimbot
Aimbot:setWallSystem(Wall)

-- Start AllyScan round monitor
AllyScan:startRoundMonitor(services, Wall, wallConfig)

-- Create UI Window
local Window = library:CreateWindow({
	Name = "Aeon - BRM5",
	Themeable = {}
})

-- Create Tabs
local CombatTab = Window:CreateTab({ Name = "Combat" })
local VisualsTab = Window:CreateTab({ Name = "Visuals" })
local MiscTab = Window:CreateTab({ Name = "Misc" })

-- ========== COMBAT TAB ==========
local AimbotSection = CombatTab:CreateSection({ Name = "Aimbot" })

AimbotSection:AddToggle({
	Name = "Enable Aimbot",
	Flag = "BRM5_AimbotEnabled",
	Value = false,
	Keybind = { Mode = "Hold" },
	Callback = function(v)
		if v then
			Aimbot.Enable()
		else
			Aimbot.Disable()
		end
	end
})

AimbotSection:AddSlider({
	Name = "FOV Radius",
	Flag = "BRM5_FOVRadius",
	Value = 100,
	Min = 50,
	Max = 300,
	Callback = function(v)
		Aimbot.UpdateSettings({ FOVRadius = v })
	end
})

AimbotSection:AddSlider({
	Name = "Smoothness",
	Flag = "BRM5_Smoothness",
	Value = 95,
	Min = 1,
	Max = 100,
	Callback = function(v)
		Aimbot.UpdateSettings({ Smoothness = v })
	end
})

AimbotSection:AddToggle({
	Name = "Draw FOV",
	Flag = "BRM5_DrawFOV",
	Value = true,
	Callback = function(v)
		Aimbot.UpdateSettings({ DrawFOV = v })
	end
})

AimbotSection:AddColorpicker({
	Name = "FOV Color",
	Flag = "BRM5_FOVColor",
	Value = Color3.fromRGB(255, 255, 255),
	Callback = function(v)
		Aimbot.UpdateSettings({ FOVColor = v })
	end
})

local FreezeSection = CombatTab:CreateSection({ Name = "Freeze Target", Side = "Right" })

FreezeSection:AddToggle({
	Name = "Enable Freeze",
	Flag = "BRM5_FreezeEnabled",
	Value = false,
	Keybind = { Mode = "Hold" },
	Callback = function(v)
		Freeze.Toggle(v)
	end
})

local WeaponSection = CombatTab:CreateSection({ Name = "Weapon Mods" })

WeaponSection:AddToggle({
	Name = "No Recoil",
	Flag = "BRM5_NoRecoil",
	Value = false,
	Callback = function(v)
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		NoRecoil.patchWeapons(ReplicatedStorage, { recoil = v, firemodes = false })
	end
})

WeaponSection:AddToggle({
	Name = "All Firemodes",
	Flag = "BRM5_AllFiremodes",
	Value = false,
	Callback = function(v)
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		NoRecoil.patchWeapons(ReplicatedStorage, { recoil = false, firemodes = v })
	end
})

-- ========== VISUALS TAB ==========
local ESPSection = VisualsTab:CreateSection({ Name = "ESP / Wallhack" })

ESPSection:AddToggle({
	Name = "Enable ESP",
	Flag = "BRM5_ESPEnabled",
	Value = false,
	Callback = function(v)
		if v then
			ESP.Enable()
		else
			ESP.Disable()
		end
	end
})

ESPSection:AddToggle({
	Name = "Show Enemy NPCs",
	Flag = "BRM5_ShowNPCs",
	Value = true,
	Callback = function(v)
		ESP.UpdateSettings({ ShowNPCs = v })
	end
})

ESPSection:AddColorpicker({
	Name = "Visible Color",
	Flag = "BRM5_VisibleColor",
	Value = Color3.fromRGB(0, 255, 0),
	Callback = function(v)
		ESP.settings.visibleColor = v
	end
})

ESPSection:AddColorpicker({
	Name = "Hidden Color",
	Flag = "BRM5_HiddenColor",
	Value = Color3.fromRGB(255, 0, 0),
	Callback = function(v)
		ESP.settings.hiddenColor = v
	end
})

ESPSection:AddColorpicker({
	Name = "NPC Color",
	Flag = "BRM5_NPCColor",
	Value = Color3.fromRGB(255, 165, 0),
	Callback = function(v)
		ESP.settings.npcColor = v
	end
})

local LightingSection = VisualsTab:CreateSection({ Name = "Lighting", Side = "Right" })

LightingSection:AddToggle({
	Name = "Fullbright",
	Flag = "BRM5_Fullbright",
	Value = false,
	Callback = function(v)
		if v then
			Fullbright.Enable()
		else
			Fullbright.Disable()
		end
	end
})

-- ========== MISC TAB ==========
local MiscSection = MiscTab:CreateSection({ Name = "Misc" })

MiscSection:AddButton({
	Name = "Destroy Script",
	Callback = function()
		cleanup()
		library.unload()
	end
})

-- Setup RenderStepped loop for Aimbot and Wall system
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera

-- Track aimbot keybind state
local aimbotKeyHeld = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	
	-- Check if this is the aimbot keybind
	if library.flags and library.flags["BRM5_AimbotEnabled_ToggleKeybind"] then
		if input.KeyCode == library.flags["BRM5_AimbotEnabled_ToggleKeybind"] then
			aimbotKeyHeld = true
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	-- Check if this is the aimbot keybind
	if library.flags and library.flags["BRM5_AimbotEnabled_ToggleKeybind"] then
		if input.KeyCode == library.flags["BRM5_AimbotEnabled_ToggleKeybind"] then
			aimbotKeyHeld = false
		end
	end
end)

-- Main update loop
local colorAccumulator = 0
RunService.RenderStepped:Connect(function(dt)
	-- Update aimbot keybind state
	Aimbot:setHoldingKey(aimbotKeyHeld)
	
	-- Always update FOV circle if Draw FOV is enabled
	Aimbot:updateFOVCircle(Camera)
	
	-- Update Wall colors (throttled to reduce performance impact)
	colorAccumulator = colorAccumulator + dt
	if colorAccumulator >= 0.1 then
		colorAccumulator = 0
		Wall:updateColors(Camera, services.Workspace, services.Players.LocalPlayer, wallConfig)
	end
	
	-- Only aim when aimbot is enabled AND key is held
	if Aimbot.IsActive() then
		local target = Aimbot:getClosestHead(Camera, wallConfig.visibleColor)
		if target then
			Aimbot:aimAtTarget(target, Camera)
		end
	end
end)

-- Cleanup on script unload
local function cleanup()
	wallConfig.isUnloaded = true
	Wall:cleanup()
	AllyScan:stopRoundMonitor()
	AllyScan:stop()
	ESP.Disable()
	Aimbot.Disable()
	Freeze.Disable()
	Fullbright.Disable()
end
