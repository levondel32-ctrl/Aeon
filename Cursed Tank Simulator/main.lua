--[[
	CTS Script - Elite Tanker v2.5
	Core functionality loader
]]

-- Load feature modules
local ESP_CTS = loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/cts/esp_cts.lua'))()
local CAMERA_CTS = loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/cts/camera_cts.lua'))()
local WORLD_CTS = loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/cts/world_cts.lua'))()
local FREEZE_CTS = loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/cts/freeze_cts.lua'))()

-- Initialize features
ESP_CTS.Initialize()
WORLD_CTS.Initialize()

-- Export to global environment for UI access
getgenv().CTS_Features = {
    ESP = ESP_CTS,
    Camera = CAMERA_CTS,
    World = WORLD_CTS,
    Freeze = FREEZE_CTS
}

-- Load UI configuration
loadstring(game:HttpGet('https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/Cursed%20Tank%20Simulator/ui_config.lua'))()
