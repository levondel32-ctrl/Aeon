--[[
	BRM5 Script - Aeon
	Core functionality loader
]]

-- Load feature modules
local ESP = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/esp_brm5.lua"))()
local Aimbot = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/aimbot_brm5.lua"))()
local Freeze = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/freeze_brm5.lua"))()
local NoRecoil = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/norecoil_brm5.lua"))()
local Fullbright = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/fullbright_brm5.lua"))()
local Wall = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/wall.lua"))()
local AllyScan = loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/ally_scan.lua"))()

-- Export to global environment for UI access
getgenv().BRM5_Features = {
    ESP = ESP,
    Aimbot = Aimbot,
    Freeze = Freeze,
    NoRecoil = NoRecoil,
    Fullbright = Fullbright,
    Wall = Wall,
    AllyScan = AllyScan
}

-- Load UI configuration
loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/Blackhawk%20Rescue%20Mission%205/ui_config.lua"))()
