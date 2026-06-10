--[[
    No Recoil Module for BRM5 PVP (fixed)
    - Ждёт появления папки конфигов (WaitForChild с таймаутом)
    - Ищет Receiver-модули через GetDescendants (любая вложенность)
    - Сохраняет оригинальные значения и умеет их восстанавливать (toggle off)
    - Автоматически патчит новые модули (DescendantAdded) пока включён
    - Пишет warn-сообщения, если структура игры не найдена
]]

local NoRecoil = {}

NoRecoil.state = {
    recoil = false,
    firemodes = false,
}

NoRecoil._originals = {}   -- [ModuleScript] = { key = originalValue }
NoRecoil._folder = nil
NoRecoil._watchConn = nil

-- Поиск папки с конфигами оружия (с ожиданием репликации)
local function findWeaponsFolder(replicatedStorage)
    if NoRecoil._folder and NoRecoil._folder.Parent then
        return NoRecoil._folder
    end

    local node = replicatedStorage
    for _, name in ipairs({ "Shared", "Configs", "Weapon", "Weapons_Player" }) do
        node = node:WaitForChild(name, 5)
        if not node then
            warn("[Aeon NoRecoil] Не найдена папка '" .. name .. "' — структура игры могла измениться")
            return nil
        end
    end

    NoRecoil._folder = node
    return node
end

-- Патч/восстановление одного Receiver-модуля
local function applyToModule(child)
    if not (child:IsA("ModuleScript") and child.Name:match("^Receiver")) then
        return
    end

    local success, receiver = pcall(require, child)
    if not (success and type(receiver) == "table" and receiver.Config and receiver.Config.Tune) then
        return
    end

    local tune = receiver.Config.Tune
    NoRecoil._originals[child] = NoRecoil._originals[child] or {}
    local orig = NoRecoil._originals[child]

    -- ===== Recoil =====
    if NoRecoil.state.recoil then
        -- Обнуляем ВСЕ поля, в названии которых есть "Recoil" (защита от обновлений игры)
        for key, value in pairs(tune) do
            if type(key) == "string" and key:find("Recoil") then
                if orig[key] == nil then orig[key] = value end

                local isDamp = key:find("Damp") ~= nil
                local t = typeof(value)
                if t == "number" then
                    tune[key] = isDamp and 1 or 0
                elseif t == "Vector2" then
                    tune[key] = isDamp and Vector2.one or Vector2.zero
                elseif t == "Vector3" then
                    tune[key] = isDamp and Vector3.one or Vector3.zero
                end
            end
        end
    else
        -- Восстанавливаем оригиналы
        for key, value in pairs(orig) do
            if key ~= "Firemodes" then
                tune[key] = value
            end
        end
    end

    -- ===== Firemodes =====
    if NoRecoil.state.firemodes then
        if orig.Firemodes == nil then orig.Firemodes = tune.Firemodes end
        tune.Firemodes = { 3, 2, 1, 0 }
    elseif orig.Firemodes ~= nil then
        tune.Firemodes = orig.Firemodes
    end
end

local function applyToAll(folder)
    local patched = 0
    for _, child in ipairs(folder:GetDescendants()) do
        applyToModule(child)
        if child:IsA("ModuleScript") and child.Name:match("^Receiver") then
            patched = patched + 1
        end
    end
    if patched == 0 then
        warn("[Aeon NoRecoil] Receiver-модули не найдены — проверь структуру Weapons_Player")
    end
end

-- Следим за новыми модулями (новое оружие / стриминг), пока что-то включено
local function updateWatcher(folder)
    local needWatch = NoRecoil.state.recoil or NoRecoil.state.firemodes
    if needWatch and not NoRecoil._watchConn then
        NoRecoil._watchConn = folder.DescendantAdded:Connect(function(child)
            task.defer(applyToModule, child)
        end)
    elseif not needWatch and NoRecoil._watchConn then
        NoRecoil._watchConn:Disconnect()
        NoRecoil._watchConn = nil
    end
end

--[[
    Публичный API (обратно совместим со старым вызовом).
    patchOptions: { recoil = true/false/nil, firemodes = true/false/nil }
    nil = не менять текущее состояние этого флага.
]]
function NoRecoil.patchWeapons(replicatedStorage, patchOptions)
    patchOptions = patchOptions or {}

    if patchOptions.recoil ~= nil then
        NoRecoil.state.recoil = patchOptions.recoil
    end
    if patchOptions.firemodes ~= nil then
        NoRecoil.state.firemodes = patchOptions.firemodes
    end

    local folder = findWeaponsFolder(replicatedStorage)
    if not folder then
        return false
    end

    applyToAll(folder)
    updateWatcher(folder)

    return true
end

return NoRecoil
