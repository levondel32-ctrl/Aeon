--[[
    No Recoil Module for BRM5 PVP (v6, строго по принципу lirp)

    Принцип lirp (дословно):
        ВКЛ:  один проход по конфигам -> сохранить оригинал -> SetAttribute(..., 0)
        ВЫКЛ: один проход -> вернуть сохранённые значения
    Никаких хуков, никаких RenderStepped-циклов, никаких require игровых модулей.
    Вся работа происходит ОДИН раз в момент переключения тоггла.

    Отличие от lirp только одно: lirp написан под игру, где конфиги лежат в
    ReplicatedStorage.AmmoTypes и атрибут называется RecoilStrength.
    В BRM5 путь другой, поэтому:
      - список папок-кандидатов (AmmoTypes + путь BRM5),
      - обнуляем ЛЮБОЙ числовой атрибут с "recoil" в имени.

    Проход делается в task.spawn с периодическим task.wait(),
    чтобы не было фриза кадра даже на большом дереве.
]]

local NoRecoil = {}

NoRecoil.state = { recoil = false, firemodes = false }

-- [Instance] = { [attrName] = originalValue }  (как saved[] в lirp)
local savedAttrs = {}
-- [ModuleScript] = originalFiremodes
local savedFiremodes = {}

local busy = false
local YIELD_EVERY = 400 -- инстансов на кадр, защита от фриза

-- ===== Папки с конфигами (кэшируются после первого поиска) =====

local cachedContainers = nil

local function getContainers(replicatedStorage)
    if cachedContainers and #cachedContainers > 0 then
        local alive = true
        for _, c in ipairs(cachedContainers) do
            if not c.Parent then alive = false break end
        end
        if alive then return cachedContainers end
    end

    local out = {}

    -- 1) Как в lirp: ReplicatedStorage.AmmoTypes (вдруг есть)
    local ammo = replicatedStorage:FindFirstChild("AmmoTypes")
    if ammo then table.insert(out, ammo) end

    -- 2) Путь BRM5: Shared/Configs/Weapon
    local node = replicatedStorage
    for _, name in ipairs({ "Shared", "Configs", "Weapon" }) do
        node = node and node:FindFirstChild(name)
    end
    if node then table.insert(out, node) end

    if #out == 0 then
        warn("[Aeon NoRecoil] Папки конфигов не найдены (AmmoTypes / Shared.Configs.Weapon)")
    end

    cachedContainers = out
    return out
end

-- ===== Один проход: применить или восстановить (lirp-style) =====

local function isRecoilName(name)
    return type(name) == "string" and name:lower():find("recoil") ~= nil
end

local function processInstance(inst, enable)
    local ok, attrs = pcall(inst.GetAttributes, inst)
    if not ok or type(attrs) ~= "table" then return 0 end

    local touched = 0

    if enable then
        for name, value in pairs(attrs) do
            if isRecoilName(name) and type(value) == "number" then
                -- как в lirp: сохранить оригинал один раз
                savedAttrs[inst] = savedAttrs[inst] or {}
                if savedAttrs[inst][name] == nil then
                    savedAttrs[inst][name] = value
                end
                local isDamp = name:lower():find("damp") ~= nil
                pcall(inst.SetAttribute, inst, name, isDamp and 1 or 0)
                touched = touched + 1
            end
        end
    elseif savedAttrs[inst] then
        -- как в lirp: вернуть сохранённое
        for name, value in pairs(savedAttrs[inst]) do
            pcall(inst.SetAttribute, inst, name, value)
            touched = touched + 1
        end
        savedAttrs[inst] = nil
    end

    return touched
end

local function runRecoilPass(replicatedStorage, enable, onDone)
    task.spawn(function()
        if busy then return end
        busy = true

        local total = 0
        local counter = 0

        for _, container in ipairs(getContainers(replicatedStorage)) do
            total = total + processInstance(container, enable)
            for _, inst in ipairs(container:GetDescendants()) do
                total = total + processInstance(inst, enable)
                counter = counter + 1
                if counter % YIELD_EVERY == 0 then
                    task.wait() -- отдаём кадр, чтобы не фризило
                end
            end
        end

        busy = false
        if onDone then onDone(total) end
    end)
end

-- ===== Firemodes: тоже один проход, без циклов =====

local function runFiremodesPass(replicatedStorage, enable)
    task.spawn(function()
        local node = replicatedStorage
        for _, name in ipairs({ "Shared", "Configs", "Weapon", "Weapons_Player" }) do
            node = node and node:FindFirstChild(name)
        end
        if not node then return end

        local counter = 0
        for _, child in ipairs(node:GetDescendants()) do
            counter = counter + 1
            if counter % YIELD_EVERY == 0 then task.wait() end

            if child:IsA("ModuleScript") and child.Name:match("^Receiver") then
                local ok, receiver = pcall(require, child)
                if ok and type(receiver) == "table"
                    and receiver.Config and receiver.Config.Tune then
                    local tune = receiver.Config.Tune
                    if enable then
                        if savedFiremodes[child] == nil then
                            savedFiremodes[child] = tune.Firemodes
                        end
                        tune.Firemodes = { 3, 2, 1, 0 }
                    elseif savedFiremodes[child] ~= nil then
                        tune.Firemodes = savedFiremodes[child]
                        savedFiremodes[child] = nil
                    end
                end
            end
        end
    end)
end

-- ===== Публичный API (обратно совместим) =====

function NoRecoil.patchWeapons(replicatedStorage, patchOptions)
    patchOptions = patchOptions or {}
    replicatedStorage = replicatedStorage or game:GetService("ReplicatedStorage")

    if patchOptions.recoil ~= nil and patchOptions.recoil ~= NoRecoil.state.recoil then
        NoRecoil.state.recoil = patchOptions.recoil
        runRecoilPass(replicatedStorage, NoRecoil.state.recoil, function(total)
            if NoRecoil.state.recoil and total == 0 then
                warn("[Aeon NoRecoil] Recoil-атрибуты не найдены. Запусти NoRecoil.Scan() и пришли вывод")
            else
                print(("[Aeon NoRecoil] %s, изменено атрибутов: %d")
                    :format(NoRecoil.state.recoil and "ВКЛ" or "ВЫКЛ (восстановлено)", total))
            end
        end)
    end

    if patchOptions.firemodes ~= nil and patchOptions.firemodes ~= NoRecoil.state.firemodes then
        NoRecoil.state.firemodes = patchOptions.firemodes
        runFiremodesPass(replicatedStorage, NoRecoil.state.firemodes)
    end

    return true
end

-- ===== Диагностика: где в этой игре лежит отдача =====

function NoRecoil.Scan()
    task.spawn(function()
        local RS = game:GetService("ReplicatedStorage")
        print("[Aeon NoRecoil] === SCAN: ищу recoil-атрибуты в ReplicatedStorage ===")
        local found, counter = 0, 0
        for _, inst in ipairs(RS:GetDescendants()) do
            counter = counter + 1
            if counter % YIELD_EVERY == 0 then task.wait() end
            local ok, attrs = pcall(inst.GetAttributes, inst)
            if ok and type(attrs) == "table" then
                for name, value in pairs(attrs) do
                    if isRecoilName(name) then
                        print(("  %s -> %s = %s"):format(inst:GetFullName(), name, tostring(value)))
                        found = found + 1
                    end
                end
            end
        end
        print(("[Aeon NoRecoil] === SCAN END, найдено атрибутов: %d ==="):format(found))
        if found == 0 then
            print("  (Атрибутов нет — значит отдача в этой игре хранится не в атрибутах.")
            print("   Пришли мне этот вывод, добавлю поиск по ValueObjects/конфигам.)")
        end
    end)
end

return NoRecoil
