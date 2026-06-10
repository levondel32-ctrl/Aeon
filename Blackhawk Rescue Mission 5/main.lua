--[[
	BRM5 Script - Aeon
	Core functionality loader
]]

local BASE = "https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/features/brm5/pvp/"

-- Безопасная загрузка: 404/битый файл не роняет весь скрипт,
-- а пишет внятную ошибку в консоль
local function safeLoad(fileName)
	local okHttp, source = pcall(game.HttpGet, game, BASE .. fileName)
	if not okHttp or type(source) ~= "string" or source:find("^404") then
		warn("[Aeon] НЕ СКАЧАЛСЯ модуль " .. fileName .. " (404/сеть). Проверь, что файл запушен, и подожди кэш GitHub ~5 мин")
		return nil
	end

	local chunk, err = loadstring(source)
	if not chunk then
		warn("[Aeon] СИНТАКСИЧЕСКАЯ ОШИБКА в " .. fileName .. ": " .. tostring(err))
		return nil
	end

	local okRun, result = pcall(chunk)
	if not okRun then
		warn("[Aeon] ОШИБКА ВЫПОЛНЕНИЯ " .. fileName .. ": " .. tostring(result))
		return nil
	end
	if result == nil then
		warn("[Aeon] Модуль " .. fileName .. " вернул nil (пустой файл?)")
	end
	return result
end

-- Load feature modules
local ESP = safeLoad("esp_brm5.lua")
local Aimbot = safeLoad("aimbot_brm5.lua")
local Freeze = safeLoad("freeze_brm5.lua")
local NoRecoil = safeLoad("norecoil_brm5.lua")
local Fullbright = safeLoad("fullbright_brm5.lua")
local RapidFire = safeLoad("rapid_fire_brm5.lua")
local Wall = safeLoad("wall.lua")
local AllyScan = safeLoad("ally_scan.lua")
local ThirdPerson = safeLoad("thirdperson_brm5.lua")
local Weather = safeLoad("weather_brm5.lua")

-- Export to global environment for UI access
local genv = (type(getgenv) == "function" and getgenv()) or _G
genv.BRM5_Features = {
    ESP = ESP,
    Aimbot = Aimbot,
    Freeze = Freeze,
    NoRecoil = NoRecoil,
    Fullbright = Fullbright,
    RapidFire = RapidFire,
    Wall = Wall,
    AllyScan = AllyScan,
    ThirdPerson = ThirdPerson,
    Weather = Weather
}

-- Load UI configuration
local okUI, uiErr = pcall(function()
	loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/Blackhawk%20Rescue%20Mission%205/ui_config.lua"))()
end)
if not okUI then
	warn("[Aeon] Ошибка загрузки UI: " .. tostring(uiErr))
end
