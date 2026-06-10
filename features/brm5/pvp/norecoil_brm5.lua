--[[
    No Recoil Module for BRM5 PVP (v3, lirp-style)

    Почему предыдущая версия могла не работать:
    require() из экзекьютора часто возвращает СВОЮ копию модуля (отдельная VM),
    и игровые скрипты не видят изменений в Config.Tune.

    Подход (как в lirp leaked):
    1) Основной метод — атрибуты: SetAttribute(..., 0) на инстансах конфигов.
       Атрибуты общие для всех VM, поэтому игра их видит всегда.
    2) Fallback — старый require-патч Tune (вдруг экзекьютор шарит кэш).
    3) NoRecoil.Scan() — печатает в консоль всё, что нашёл, для отладки.
]]

local NoRecoil = {}

NoRecoil.state = { recoil = false, firemodes = false }

-- [Instance] = { [attrName] = originalValue }
local attrOriginals = {}
-- [ModuleScript] = { [key] = originalValue }
local tuneOriginals = {}

local watchConn = nil
local cachedRoots = nil

-- ============ Поиск корневых папок с конфигами оружия ============

local function getRoots(replicatedStorage)
    if cachedRoots then
        local ok = true
        for _, r in ipairs(cachedRoots) do
            if not r.Parent then ok = false break end
        end
        if ok and #cachedRoots > 0 then return cachedRoots end
    end

    local roots = {}

    -- Известный путь BRM5
    local node = replicatedStorage
    for _, name in ipairs({ "Shared", "Configs", "Weapon" }) do
        node = node and (node:FindFirstChild(name) or node:WaitForChild(name, 3))
    end
    if node then
        table.insert(roots, node) -- берём Weapon целиком (Weapons_Player + всё рядом)
    end

    -- Запасной поиск: любые папки с "Weapon"/"Ammo" в имени в ReplicatedStorage
    if #roots == 0 then
        for _, child in ipairs(replicatedStorage:GetDescendants()) do
            if child:IsA("Folder") and (child.Name:find("Weapon") or child.Name:find("Ammo")) then
                table.insert(roots, child)
                if #roots >= 3 then break end
            end
        end
    end

    if #roots == 0 then
        warn("[Aeon NoRecoil] Не нашёл папки конфигов оружия в ReplicatedStorage")
    end

    cachedRoots = roots
    return roots
end

-- ============ Метод 1: атрибуты (lirp-style, работает между VM) ============

local function isRecoilAttr(name)
    local n = name:lower()
    return n:find("recoil") ~= nil
end

local function patchAttributes(inst, enable)
    local ok, attrs = pcall(inst.GetAttributes, inst)
    if not ok or type(attrs) ~= "table" then return 0 end

    local count = 0
    for name, value in pairs(attrs) do
        if isRecoilAttr(name) and type(value) == "number" then
            if enable then
                attrOriginals[inst] = attrOriginals[inst] or {}
                if attrOriginals[inst][name] == nil then
                    attrOriginals[inst][name] = value
                end
                local isDamp = name:lower():find("damp") ~= nil
                pcall(inst.SetAttribute, inst, name, isDamp and 1 or 0)
                count = count + 1
            end
        end
    end

    if not enable and attrOriginals[inst] then
        for name, value in pairs(attrOriginals[inst]) do
            pcall(inst.SetAttribute, inst, name, value)
            count = count + 1
        end
        attrOriginals[inst] = nil
    end

    return count
end

-- ============ Метод 2: require-патч Tune (fallback) ============

local function patchTune(child)
    if not (child:IsA("ModuleScript") and child.Name:match("^Receiver")) then
        return false
    end

    local success, receiver = pcall(require, child)
    if not (success and type(receiver) == "table" and receiver.Config and receiver.Config.Tune) then
        return false
    end

    local tune = receiver.Config.Tune
    tuneOriginals[child] = tuneOriginals[child] or {}
    local orig = tuneOriginals[child]

    if NoRecoil.state.recoil then
        for key, value in pairs(tune) do
            if type(key) == "string" and key:lower():find("recoil") then
                if orig[key] == nil then orig[key] = value end
                local isDamp = key:lower():find("damp") ~= nil
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
        for key, value in pairs(orig) do
            if key ~= "Firemodes" then tune[key] = value end
        end
    end

    if NoRecoil.state.firemodes then
        if orig.Firemodes == nil then orig.Firemodes = tune.Firemodes end
        tune.Firemodes = { 3, 2, 1, 0 }
    elseif orig.Firemodes ~= nil then
        tune.Firemodes = orig.Firemodes
    end

    return true
end

-- ============ Применение ко всему дереву ============

local function applyEverywhere(replicatedStorage)
    local roots = getRoots(replicatedStorage)
    local attrCount, tuneCount = 0, 0

    for _, root in ipairs(roots) do
        attrCount = attrCount + patchAttributes(root, NoRecoil.state.recoil)
        for _, child in ipairs(root:GetDescendants()) do
            attrCount = attrCount + patchAttributes(child, NoRecoil.state.recoil)
            if patchTune(child) then tuneCount = tuneCount + 1 end
        end
    end

    if NoRecoil.state.recoil and attrCount == 0 and tuneCount == 0 then
        warn("[Aeon NoRecoil] Ничего не запатчено. Запусти NoRecoil.Scan() для диагностики")
    else
        print(("[Aeon NoRecoil] attrs: %d, tune-modules: %d"):format(attrCount, tuneCount))
    end
end

local function updateWatcher(replicatedStorage)
    local need = NoRecoil.state.recoil or NoRecoil.state.firemodes
    if need and not watchConn then
        local roots = getRoots(replicatedStorage)
        if roots[1] then
            watchConn = roots[1].DescendantAdded:Connect(function(child)
                task.defer(function()
                    patchAttributes(child, NoRecoil.state.recoil)
                    patchTune(child)
                end)
            end)
        end
    elseif not need and watchConn then
        watchConn:Disconnect()
        watchConn = nil
    end
end

-- ============ Публичный API ============

function NoRecoil.patchWeapons(replicatedStorage, patchOptions)
    patchOptions = patchOptions or {}
    if patchOptions.recoil ~= nil then NoRecoil.state.recoil = patchOptions.recoil end
    if patchOptions.firemodes ~= nil then NoRecoil.state.firemodes = patchOptions.firemodes end

    applyEverywhere(replicatedStorage)
    updateWatcher(replicatedStorage)
    return true
end

-- Диагностика: печатает все recoil-атрибуты и Receiver-модули, которые видит
function NoRecoil.Scan(replicatedStorage)
    replicatedStorage = replicatedStorage or game:GetService("ReplicatedStorage")
    print("[Aeon NoRecoil] === SCAN START ===")
    local found = 0
    for _, inst in ipairs(replicatedStorage:GetDescendants()) do
        local ok, attrs = pcall(inst.GetAttributes, inst)
        if ok and type(attrs) == "table" then
            for name, value in pairs(attrs) do
                if isRecoilAttr(name) then
                    print(("  [attr] %s -> %s = %s"):format(inst:GetFullName(), name, tostring(value)))
                    found = found + 1
                end
            end
        end
        if inst:IsA("ModuleScript") and inst.Name:lower():find("receiver") then
            print(("  [module] %s"):format(inst:GetFullName()))
            found = found + 1
        end
    end
    print(("[Aeon NoRecoil] === SCAN END, найдено: %d ==="):format(found))
end

return NoRecoil
