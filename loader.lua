-- Aeon Universal Loader
-- Automatically detects game and loads appropriate script

-- Check for duplicate loading
if getgenv().Aeon_Loaded then
    return
end

getgenv().Aeon_Loading = true

-- Game IDs (can include multiple PlaceIds for games with sub-places)
local GAME_IDS = {
    BRM5 = {
        2916899287,   -- Blackhawk Rescue Mission 5 (Main)
        3028602840,   -- Blackhawk Rescue Mission (Indev-Alpha)
        3701546109,   -- OW_Ronogrod
        3774307372,   -- _factory
        3826587512,   -- _nyc
        4482712909,   -- _gym
        4524359706,   -- _tokyo
        4747446334,   -- ZM_NYC
        4798700600,   -- _slum
        4843465225,   -- CM_Mission1
        5289429734,   -- _office
        5321709389,   -- Blackhawk Rescue Mission (Operation Viper)
        5468388011,   -- PVP_Sandbox
        5480112241,   -- _coast
        5518833349,   -- _newdawn
        5899968224,   -- OW_Blank
        8474644403,   -- _skirmish
        8909103690,   -- Blackhawk Rescue Mission (Operation Resurgence)
        10938546013,  -- PVP_Blank
        13622622708,  -- _desert
        14014688944   -- HQ_Seychelles
    },
    CTS = {
        6608498361,  -- Cursed Tank Simulator (Main Menu)
        6925857548   -- Cursed Tank Simulator (Game Server)
    }
}

-- Helper function to check if PlaceId is in game list
local function isGamePlace(placeIds, currentId)
    for _, id in ipairs(placeIds) do
        if id == currentId then
            return true
        end
    end
    return false
end

-- Get current game ID
local currentGameId = game.PlaceId

-- Detect game and load appropriate script
if isGamePlace(GAME_IDS.BRM5, currentGameId) then
    -- Load BRM5 Script
    loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/Blackhawk%20Rescue%20Mission%205/main.lua"))()
elseif isGamePlace(GAME_IDS.CTS, currentGameId) then
    -- Load CTS Script
    loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/Cursed%20Tank%20Simulator/main.lua"))()
else
    -- Unknown game - try CTS as fallback
    warn("Unknown PlaceId: " .. tostring(currentGameId) .. " - Loading CTS script as fallback")
    loadstring(game:HttpGet("https://raw.githubusercontent.com/levondel32-ctrl/Aeon/main/Cursed%20Tank%20Simulator/main.lua"))()
end

getgenv().Aeon_Loaded = true
getgenv().Aeon_Loading = false
