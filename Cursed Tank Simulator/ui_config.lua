--[[
	CTS UI Configuration
	Defines the user interface for Elite Tanker
]]

local library = loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/UILibrary/UILibrary.lua'))()
local Wait = library.subs.Wait

-- Get features from global environment
local ESP_CTS = getgenv().CTS_Features.ESP
local CAMERA_CTS = getgenv().CTS_Features.Camera
local WORLD_CTS = getgenv().CTS_Features.World
local FREEZE_CTS = getgenv().CTS_Features.Freeze

-- Create UI Window
local Window = library:CreateWindow({
	Name = "Aeon CTS",
	Themeable = {}
})

-- Create Tabs
local CombatTab = Window:CreateTab({
	Name = "Combat"
})

local VisualsTab = Window:CreateTab({
	Name = "Visuals"
})

local MiscTab = Window:CreateTab({
	Name = "Misc"
})

-- ========== COMBAT TAB ==========
local FreezeSection = CombatTab:CreateSection({
	Name = "Freeze Target"
})

FreezeSection:AddToggle({
	Name = "Freeze",
	Flag = "CTS_FreezeEnabled",
	Value = false,
	Keybind = {
		Mode = "Hold"
	},
	Callback = function(v)
		FREEZE_CTS.Toggle(v)
	end
})

-- ========== VISUALS TAB ==========
local ESPSection = VisualsTab:CreateSection({
	Name = "ESP"
})

ESPSection:AddToggle({
	Name = "Master Enemy ESP",
	Flag = "CTS_EnemyESP",
	Value = true,
	Callback = function(v)
		ESP_CTS.Config.EnemiesEnabled = v
	end
})

ESPSection:AddToggle({
	Name = "Show Team ESP",
	Flag = "CTS_TeamESP",
	Value = false,
	Callback = function(v)
		ESP_CTS.Config.TeamEnabled = v
	end
})

local EnhancementsSection = VisualsTab:CreateSection({
	Name = "Enhancements"
})

EnhancementsSection:AddToggle({
	Name = "Health Scanner",
	Flag = "CTS_HealthScanner",
	Value = true,
	Callback = function(v)
		ESP_CTS.Config.HealthEnabled = v
	end
})

EnhancementsSection:AddToggle({
	Name = "Tracers",
	Flag = "CTS_Tracers",
	Value = true,
	Callback = function(v)
		ESP_CTS.Config.TracersEnabled = v
	end
})

EnhancementsSection:AddDropdown({
	Name = "Tracer Origin",
	Flag = "CTS_TracerOrigin",
	Value = "Bottom",
	List = {"Bottom", "Center", "Mouse"},
	Callback = function(v)
		ESP_CTS.Config.TracerOrigin = v
	end
})

local ColorsSection = VisualsTab:CreateSection({
	Name = "Colors",
	Side = "Right"
})

ColorsSection:AddColorpicker({
	Name = "Enemy Color",
	Flag = "CTS_EnemyColor",
	Value = ESP_CTS.Config.EnemyColor,
	Callback = function(v)
		ESP_CTS.Config.EnemyColor = v
	end
})

local RenderSection = VisualsTab:CreateSection({
	Name = "Render Settings",
	Side = "Right"
})

RenderSection:AddSlider({
	Name = "Render Distance",
	Flag = "CTS_RenderDistance",
	Value = 5000,
	Min = 100,
	Max = 10000,
	Callback = function(v)
		ESP_CTS.Config.RenderDistance = v
	end
})

-- ========== MISC TAB ==========
local WorldSection = MiscTab:CreateSection({
	Name = "World"
})

WorldSection:AddToggle({
	Name = "FullBright & No Sun",
	Flag = "CTS_FullBright",
	Value = false,
	Callback = function(v)
		if v then
			WORLD_CTS.EnableFullBright()
		else
			WORLD_CTS.DisableFullBright()
		end
	end
})

WorldSection:AddToggle({
	Name = "No Fog",
	Flag = "CTS_NoFog",
	Value = false,
	Callback = function(v)
		if v then
			WORLD_CTS.EnableNoFog()
		else
			WORLD_CTS.DisableNoFog()
		end
	end
})

WorldSection:AddToggle({
	Name = "Black Skybox",
	Flag = "CTS_BlackSky",
	Value = false,
	Callback = function(v)
		if v then
			WORLD_CTS.EnableBlackSky()
		else
			WORLD_CTS.DisableBlackSky()
		end
	end
})

WorldSection:AddToggle({
	Name = "Infinite Camera Zoom",
	Flag = "CTS_InfiniteCamera",
	Value = false,
	Callback = function(v)
		CAMERA_CTS.Toggle(v)
	end
})

local SettingsSection = MiscTab:CreateSection({
	Name = "Settings",
	Side = "Right"
})

SettingsSection:AddButton({
	Name = "Destroy Script",
	Callback = function()
		ESP_CTS.Cleanup()
		CAMERA_CTS.Disable()
		WORLD_CTS.Cleanup()
		FREEZE_CTS.Disable()
		library.unload()
	end
})
