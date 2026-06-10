--[[
    No Recoil Module for BRM5 PVP (v5, безопасный — без хуков)

    v4 крашил игру: замена методов игровых модулей (CharacterCamera.Update)
    означает, что наша closure исполняется внутри игрового потока — многие
    экзекьюторы на этом падают.

    v5 вообще НЕ трогает функции игры. Вместо этого мы из СВОЕГО потока
    каждый кадр (RenderStepped) обнуляем накопленную отдачу:
        CharacterCamera._recoil.Velocity *= 0
    Игра сама вызывает свой Update как обычно — крашить нечему.

    Firemodes: раз в секунду дописываем режимы 1/2/3 в Tune.Firemodes
    конфига текущего оружия (FirearmInventory._config) + в Receiver-модули.

    Всё обёрнуто в pcall. API прежний: patchWeapons(RS, {recoil=, firemodes=})
]]

local NoRecoil = {}

NoRecoil.state = { recoil = false, firemodes = false }

local RunService = game:GetService("RunService")

local loopConn = nil
local camModule = nil
local fiModule = nil
local lastSearch = 0
local lastFiremodePatch = 0
local storedRS = nil

-- ===== Доступ к загруженным модулям игры =====

local function getModuleInstances()
    local getter = (type(getloadedmodules) == "function" and getloadedmodules)
        or (type(getmodules) == "function" and getmodules)
    if not getter then return nil end
    local ok, list = pcall(getter)
    if ok and type(list) == "table" then return list end
    return nil
end

local function requireModuleByName(name)
    local list = getModuleInstances()
    if not list then return nil end
    for _, inst in ipairs(list) do
        if inst.Name == name then
            local ok, mod = pcall(require, inst)
            if ok and type(mod) == "table" then return mod end
        end
    end
    return nil
end

-- Ищем модули не чаще раза в 2 секунды, чтобы не грузить игру
local function refreshModules()
    if camModule and fiModule then return end
    local now = tick()
    if now - lastSearch < 2 then return end
    lastSearch = now

    if not camModule then
        camModule = requireModuleByName("CharacterCamera")
        if camModule then print("[Aeon NoRecoil] CharacterCamera найден") end
    end
    if not fiModule then
        fiModule = requireModuleByName("FirearmInventory")
        if fiModule then print("[Aeon NoRecoil] FirearmInventory найден") end
    end
end

-- ===== Recoil: глушим накопленную отдачу из своего потока =====

local function suppressRecoil()
    if not camModule then return end
    local rec = camModule._recoil
    if rec and rec.Velocity then
        rec.Velocity = rec.Velocity * 0
    end
end

-- ===== Firemodes =====

local function addModes(modesTable)
    if type(modesTable) ~= "table" then return end
    for _, m in ipairs({ 1, 2, 3 }) do
        if not table.find(modesTable, m) then
            table.insert(modesTable, m)
        end
    end
end

local function patchFiremodes()
    local now = tick()
    if now - lastFiremodePatch < 1 then return end
    lastFiremodePatch = now

    -- Конфиг текущего оружия в инвентаре
    if fiModule and fiModule._config and fiModule._config.Tune then
        addModes(fiModule._config.Tune.Firemodes)
    end

    -- Запасной путь: Receiver-модули в ReplicatedStorage
    if storedRS then
        local node = storedRS
        for _, name in ipairs({ "Shared", "Configs", "Weapon", "Weapons_Player" }) do
            node = node and node:FindFirstChild(name)
        end
        if node then
            for _, child in ipairs(node:GetDescendants()) do
                if child:IsA("ModuleScript") and child.Name:match("^Receiver") then
                    local ok, receiver = pcall(require, child)
                    if ok and type(receiver) == "table"
                        and receiver.Config and receiver.Config.Tune then
                        addModes(receiver.Config.Tune.Firemodes)
                    end
                end
            end
        end
    end
end

-- ===== Цикл =====

local function startLoop()
    if loopConn then return end
    loopConn = RunService.RenderStepped:Connect(function()
        if NoRecoil.state.recoil or NoRecoil.state.firemodes then
            pcall(refreshModules)
        end
        if NoRecoil.state.recoil then
            pcall(suppressRecoil)
        end
        if NoRecoil.state.firemodes then
            pcall(patchFiremodes)
        end
    end)
end

local function stopLoopIfIdle()
    if not NoRecoil.state.recoil and not NoRecoil.state.firemodes and loopConn then
        loopConn:Disconnect()
        loopConn = nil
    end
end

-- ===== Публичный API (обратно совместим) =====

function NoRecoil.patchWeapons(replicatedStorage, patchOptions)
    patchOptions = patchOptions or {}
    storedRS = replicatedStorage or storedRS

    if patchOptions.recoil ~= nil then NoRecoil.state.recoil = patchOptions.recoil end
    if patchOptions.firemodes ~= nil then NoRecoil.state.firemodes = patchOptions.firemodes end

    if NoRecoil.state.recoil or NoRecoil.state.firemodes then
        lastSearch = 0 -- разрешаем немедленный поиск модулей
        startLoop()
    else
        stopLoopIfIdle()
    end
    return true
end

-- ===== Диагностика =====

function NoRecoil.Scan()
    local list = getModuleInstances()
    if not list then
        print("[Aeon NoRecoil] getloadedmodules/getmodules недоступны")
        return
    end
    print("[Aeon NoRecoil] === SCAN ===")
    local found = 0
    for _, inst in ipairs(list) do
        local n = inst.Name:lower()
        if n:find("camera") or n:find("firearm") or n:find("recoil") or n:find("weapon") then
            print("  [module] " .. inst:GetFullName())
            found = found + 1
        end
    end
    local cam = requireModuleByName("CharacterCamera")
    if cam then
        print("  CharacterCamera._recoil = " .. tostring(cam._recoil))
        if cam._recoil then
            print("  _recoil.Velocity = " .. tostring(cam._recoil.Velocity))
        end
    end
    print(("[Aeon NoRecoil] === SCAN END, найдено: %d ==="):format(found))
end

return NoRecoil
