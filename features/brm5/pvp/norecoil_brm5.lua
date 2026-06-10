--[[
    No Recoil Module for BRM5 PVP (v4, Parvus-style)

    Конфиги (Receiver.Tune / атрибуты) BRM5 не перечитывает в момент выстрела —
    отдача применяется рантайм-модулем камеры. Поэтому патчим сам рантайм:

    * Recoil:    хук CharacterCamera.Update -> Self._recoil.Velocity *= 0
    * Firemodes: хук FirearmInventory._firemode -> добавляем режимы 1,2,3

    Модули игры достаём через getloadedmodules()/getmodules() + require,
    как это делает Parvus (AlexR32) — проверенный подход именно для BRM5.

    API совместим со старым: NoRecoil.patchWeapons(RS, {recoil=, firemodes=})
]]

local NoRecoil = {}

NoRecoil.state = { recoil = false, firemodes = false }

local hooksInstalled = false

-- ===== Получение загруженных модулей игры =====

local function getModuleInstances()
    local getter = (type(getloadedmodules) == "function" and getloadedmodules)
        or (type(getmodules) == "function" and getmodules)
    if not getter then
        warn("[Aeon NoRecoil] Экзекьютор не поддерживает getloadedmodules/getmodules")
        return nil
    end
    local ok, list = pcall(getter)
    if ok and type(list) == "table" then
        return list
    end
    return nil
end

local function requireModuleByName(name)
    local list = getModuleInstances()
    if not list then return nil end
    for _, inst in ipairs(list) do
        if inst.Name == name then
            local ok, mod = pcall(require, inst)
            if ok and type(mod) == "table" then
                return mod
            end
        end
    end
    return nil
end

-- ===== Установка хука на метод модуля (с ожиданием загрузки) =====

local function hookMethod(moduleName, fnName, wrapper)
    task.spawn(function()
        local mod
        local deadline = tick() + 60
        repeat
            mod = requireModuleByName(moduleName)
            if mod and type(mod[fnName]) == "function" then break end
            mod = nil
            task.wait(0.5)
        until tick() > deadline

        if not mod then
            warn(("[Aeon NoRecoil] Модуль '%s' с методом '%s' не найден за 60с")
                :format(moduleName, fnName))
            return
        end

        local old = mod[fnName]
        mod[fnName] = function(...)
            return wrapper(old, ...)
        end
        print(("[Aeon NoRecoil] Хук установлен: %s.%s"):format(moduleName, fnName))
    end)
end

local function installHooks()
    if hooksInstalled then return end
    hooksInstalled = true

    -- Отдача: камера применяет _recoil.Velocity каждый кадр — глушим его
    hookMethod("CharacterCamera", "Update", function(old, self, ...)
        if NoRecoil.state.recoil and self and self._recoil and self._recoil.Velocity then
            self._recoil.Velocity = self._recoil.Velocity * 0
        end
        return old(self, ...)
    end)

    -- Все режимы огня: при переключении дописываем 1 (авто), 2, 3
    hookMethod("FirearmInventory", "_firemode", function(old, self, ...)
        if NoRecoil.state.firemodes and self and self._config
            and self._config.Tune and type(self._config.Tune.Firemodes) == "table" then
            local modes = self._config.Tune.Firemodes
            for _, m in ipairs({ 1, 2, 3 }) do
                if not table.find(modes, m) then
                    table.insert(modes, m)
                end
            end
        end
        return old(self, ...)
    end)
end

-- ===== Публичный API (обратно совместим) =====

function NoRecoil.patchWeapons(_replicatedStorage, patchOptions)
    patchOptions = patchOptions or {}
    if patchOptions.recoil ~= nil then NoRecoil.state.recoil = patchOptions.recoil end
    if patchOptions.firemodes ~= nil then NoRecoil.state.firemodes = patchOptions.firemodes end

    -- Хуки ставим один раз; дальше тогглы просто меняют state,
    -- выключение мгновенно возвращает оригинальное поведение.
    installHooks()
    return true
end

-- ===== Диагностика =====

function NoRecoil.Scan()
    local list = getModuleInstances()
    if not list then
        print("[Aeon NoRecoil] getloadedmodules недоступен")
        return
    end
    print("[Aeon NoRecoil] === SCAN: ищем модули камеры/оружия ===")
    local found = 0
    for _, inst in ipairs(list) do
        local n = inst.Name:lower()
        if n:find("camera") or n:find("firearm") or n:find("recoil") or n:find("weapon") then
            print("  [module] " .. inst:GetFullName())
            found = found + 1
        end
    end
    print(("[Aeon NoRecoil] === SCAN END, найдено: %d ==="):format(found))
end

return NoRecoil
