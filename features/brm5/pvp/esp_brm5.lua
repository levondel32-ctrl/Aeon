--[[ 
    ESP Module for BRM5 PVP (исправленная версия)
    Уменьшены фризы, улучшена классификация NPC/игроков
]]

local ESP = {
    enabled = false,
    colorConnection = nil,
    trackedModels = {},
    settings = {
        showNames = true,
        showDistance = true,
        showHealth = true,
        showBox = true,
        showNPCs = true,
        maxDistance = 1800,
        teamCheck = false,
        visibleColor = Color3.fromRGB(0, 255, 0),
        hiddenColor = Color3.fromRGB(255, 0, 0),
        npcColor     = Color3.fromRGB(255, 165, 0)
    },
    npcNames = {
        ["Rifleman"] = true, ["Automatic Rifleman"] = true, ["Machine Gunner"] = true,
        ["Marksman"] = true, ["Sniper"] = true, ["Shotgunner"] = true,
        ["Submachine Gunner"] = true, ["Smoker"] = true, ["Spec Ops"] = true,
        ["Melee"] = true, ["Mortar"] = true, ["Anti-Tank"] = true,
        ["High-Value Target"] = true, ["SAMs"] = true  -- (SAMs добавлено по списку NPC)
    }
}

local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local Workspace    = game:GetService("Workspace")
local LocalPlayer  = Players.LocalPlayer

local raycastParams = RaycastParams.new()
raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
raycastParams.IgnoreWater = true
local raycastFilter = {}

-- Отслеживаем события и очищаем их при выключении
local connections = {}
local function addConnection(conn)
    table.insert(connections, conn)
    return conn
end

-- Обновляем фильтр луча каждый кадр (чтобы исключить самого себя)
local function refreshRaycastFilter()
    table.clear(raycastFilter)
    if LocalPlayer and LocalPlayer.Character then
        raycastFilter[1] = LocalPlayer.Character
    end
    raycastParams.FilterDescendantsInstances = raycastFilter
end

-- Функция классификации модели: возвращает (следить?, isNPC?)
local function classifyModel(model)
    if not model or not model:IsA("Model") then
        return false
    end

    if model == LocalPlayer.Character then
        return false
    end

    -- Должен иметь живой Humanoid
    local humanoid = model:FindFirstChildOfClass("Humanoid")
    if not humanoid or humanoid.Health <= 0 then
        return false
    end

    -- Пропускаем уже убитых (раґдолл)
    if model:FindFirstChildWhichIsA("BallSocketConstraint", true) then
        return false
    end

    -- Проверяем: принадлежит ли модель игроку?
    local player = Players:GetPlayerFromCharacter(model)
    if player then
        return true, false  -- это игрок
    end

    -- Если NPC-режим выключен, не трогаем
    if not ESP.settings.showNPCs then
        return false
    end

    -- Проверка имени: BRM5 NPC обычно имеют "AI_" или содержат "Bot"
    local nameLower = model.Name:lower()
    if nameLower:find("^ai") or nameLower:find("bot") then
        return true, true   -- это NPC
    end

    -- Проверка списка известных NPC по имени
    if ESP.npcNames[model.Name] then
        return true, true
    end

    return false
end

-- Добавляем подсветку (Highlight) к модели
local function addHighlight(model, isNPCModel)
    if ESP.trackedModels[model] then
        return
    end
    local highlight = model:FindFirstChild("ESP_Highlight")
    if not highlight then
        highlight = Instance.new("Highlight")
        highlight.Name = "ESP_Highlight"
        highlight.Adornee = model
        highlight.Parent = model
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.OutlineTransparency = 0.35
        highlight.FillTransparency = 0.85
    end
    ESP.trackedModels[model] = {
        isNPC = isNPCModel,
        highlight = highlight,
        head = model:FindFirstChild("Head")
    }
end

-- Удаляем подсветку из модели
local function removeHighlight(model)
    local data = ESP.trackedModels[model]
    if not data then
        return
    end
    if data.highlight then
        data.highlight:Destroy()
    end
    ESP.trackedModels[model] = nil
end

-- Проверяем видимость (raycast от камеры к голове)
local function isVisible(targetModel, head, camera)
    if not targetModel or not camera or not head then
        return false
    end
    refreshRaycastFilter()
    local origin = camera.CFrame.Position
    local direction = head.Position - origin
    local result = Workspace:Raycast(origin, direction, raycastParams)
    return not result or result.Instance:IsDescendantOf(targetModel)
end

-- Фоновая обработка: ставим модель в очередь на проверку
local pendingModels = {}
local function queueModel(model)
    if not ESP.enabled or not model or not model:IsA("Model") then
        return
    end
    if pendingModels[model] or ESP.trackedModels[model] then
        return
    end
    pendingModels[model] = true

    task.defer(function()
        pendingModels[model] = nil
        if not ESP.enabled or not model or not model.Parent then
            return
        end
        local shouldTrack, isNPCModel = classifyModel(model)
        if shouldTrack then
            addHighlight(model, isNPCModel)
        end
    end)
end

-- Обработчики событий
local function onDescendantAdded(descendant)
    if not ESP.enabled then
        return
    end
    if descendant:IsA("Model") then
        queueModel(descendant)
        return
    end
    local model = descendant:FindFirstAncestorOfClass("Model")
    if model then
        queueModel(model)
    end
end

local function onDescendantRemoving(descendant)
    if not ESP.enabled then
        return
    end
    if descendant:IsA("Model") and ESP.trackedModels[descendant] then
        removeHighlight(descendant)
    end
end

-- Привязываем существующего и нового игрока
local function bindPlayer(player)
    -- Сразу обрабатываем уже существующий character (если есть)
    if player.Character then
        -- Немного ждём, чтобы Character был полностью инициализирован
        task.delay(0.1, function()
            queueModel(player.Character)
        end)
    end
    -- Когда спавнится персонаж игрока
    local conn = player.CharacterAdded:Connect(function(character)
        task.delay(0.05, function()
            queueModel(character)
        end)
    end)
    addConnection(conn)
end

-- Инициализация: сканируем уже существующие модели и игроков
local function initializeExistingModels()
    -- Сначала клиенты: подключаем обработчики для игроков
    for _, player in ipairs(Players:GetPlayers()) do
        bindPlayer(player)
    end

    -- Сканируем текущие модели в Workspace
    local descendants = Workspace:GetDescendants()
    for i = 1, #descendants do
        local obj = descendants[i]
        if obj:IsA("Model") then
            queueModel(obj)
        end
        if i % 120 == 0 then
            task.wait()
        end
    end
end

-- Обновление цветов подсветки (вызывается по Heartbeat с throttling)
local colorAccumulator = 0
local function updateColors()
    if not ESP.enabled then return end
    local camera = Workspace.CurrentCamera
    if not camera then return end

    local cameraPos = camera.CFrame.Position
    local maxDist = ESP.settings.maxDistance
    local showBox = ESP.settings.showBox

    for model, data in pairs(ESP.trackedModels) do
        if not model or not model.Parent then
            removeHighlight(model)
        else
            local highlight = data.highlight
            if highlight and highlight.Parent then
                local head = data.head
                if not head or not head.Parent then
                    head = model:FindFirstChild("Head")
                    data.head = head
                end
                if not head then
                    highlight.Enabled = false
                else
                    local dist = (cameraPos - head.Position).Magnitude
                    if dist > maxDist then
                        highlight.Enabled = false
                    else
                        local color
                        if data.isNPC then
                            color = ESP.settings.npcColor
                        else
                            local vis = isVisible(model, head, camera)
                            color = vis and ESP.settings.visibleColor or ESP.settings.hiddenColor
                        end
                        highlight.Enabled = showBox
                        highlight.OutlineColor = color
                        highlight.FillColor = color
                    end
                end
            end
        end
    end
end

-- Публичный API ESP
function ESP.Enable()
    if ESP.enabled then return end
    ESP.enabled = true
    colorAccumulator = 0

    task.spawn(initializeExistingModels)

    -- Подключаем события
    addConnection(Players.PlayerAdded:Connect(bindPlayer))
    addConnection(Workspace.DescendantAdded:Connect(onDescendantAdded))
    addConnection(Workspace.DescendantRemoving:Connect(onDescendantRemoving))
    addConnection(Workspace.ChildAdded:Connect(function(child)
        if child:IsA("Model") then
            queueModel(child)
        end
    end))

    -- Цикл обновления по кадру (с накоплением dt)
    ESP.colorConnection = RunService.Heartbeat:Connect(function(dt)
        if not ESP.enabled then return end
        colorAccumulator = colorAccumulator + dt
        if colorAccumulator >= 0.12 then
            colorAccumulator = 0
            updateColors()
        end
    end)
end

function ESP.Disable()
    ESP.enabled = false
    colorAccumulator = 0
    table.clear(pendingModels)

    if ESP.colorConnection then
        ESP.colorConnection:Disconnect()
        ESP.colorConnection = nil
    end
    for _, conn in ipairs(connections) do
        conn:Disconnect()
    end
    table.clear(connections)

    for model in pairs(ESP.trackedModels) do
        removeHighlight(model)
    end
end

function ESP.UpdateSettings(newSettings)
    if newSettings.TeamCheck ~= nil then
        ESP.settings.teamCheck = newSettings.TeamCheck
    end
    if newSettings.ShowDistance ~= nil then
        ESP.settings.showDistance = newSettings.ShowDistance
    end
    if newSettings.ShowHealth ~= nil then
        ESP.settings.showHealth = newSettings.ShowHealth
    end
    if newSettings.ShowBox ~= nil then
        ESP.settings.showBox = newSettings.ShowBox
    end
    if newSettings.ShowNPCs ~= nil then
        ESP.settings.showNPCs = newSettings.ShowNPCs
        if ESP.enabled then
            -- Если отключаем NPC, удаляем их подсветку
            for model, data in pairs(ESP.trackedModels) do
                if data.isNPC and not ESP.settings.showNPCs then
                    removeHighlight(model)
                end
            end
            -- Если включаем обратно, пересканируем
            if ESP.settings.showNPCs then
                task.spawn(initializeExistingModels)
            end
        end
    end
    if newSettings.MaxDistance ~= nil then
        ESP.settings.maxDistance = newSettings.MaxDistance
    end
end

return ESP