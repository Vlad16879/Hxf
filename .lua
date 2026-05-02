--[[
    Specter Helper для Delta Executor
    Функции: ESP игроков, Pathfinding до ближайшего игрока
    GitHub: ...
--]]

-- Сервисы
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Основной GUI
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "SpecterHelperGUI"
ScreenGui.Parent = CoreGui

-- Переменные состояния
local espEnabled = false
local pathEnabled = false
local waypoints = {} -- для хранения точек пути

-- Функция для создания кнопки GUI
local function createButton(name, position, callback)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(0, 150, 0, 40)
    button.Position = position
    button.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = name
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 16
    button.BorderSizePixel = 0
    button.Parent = ScreenGui
    Instance.new("UICorner", button)

    button.MouseButton1Click:Connect(function()
        callback()
    end)

    return button
end

-- Функция для создания чекбокса
local function createCheckbox(name, position, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0, 150, 0, 40)
    button.Position = position
    button.Text = name .. ": ВЫКЛ"
    button.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 16
    button.BorderSizePixel = 0
    button.Parent = ScreenGui
    Instance.new("UICorner", button)

    local enabled = false
    button.MouseButton1Click:Connect(function()
        enabled = not enabled
        button.Text = name .. ": " .. (enabled and "ВКЛ" or "ВЫКЛ")
        button.BackgroundColor3 = enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(60, 60, 60)
        callback(enabled)
    end)

    return button
end

-- ====================== ESP ======================
local espHighlights = {}

local function createESPForPlayer(player)
    if player == LocalPlayer then return end

    local function onCharacterAdded(character)
        local highlight = Instance.new("Highlight")
        highlight.Name = player.Name .. "_ESP"
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
        highlight.FillTransparency = 0.5
        highlight.OutlineTransparency = 0
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = character
        highlight.Parent = CoreGui

        -- Расстояние
        local billboardGui = Instance.new("BillboardGui")
        billboardGui.Name = "Distance"
        billboardGui.Size = UDim2.new(0, 200, 0, 30)
        billboardGui.StudsOffset = Vector3.new(0, 3, 0)
        billboardGui.AlwaysOnTop = true
        billboardGui.Parent = character:WaitForChild("Head")

        local textLabel = Instance.new("TextLabel")
        textLabel.Size = UDim2.new(1, 0, 1, 0)
        textLabel.BackgroundTransparency = 1
        textLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        textLabel.Font = Enum.Font.SourceSansBold
        textLabel.TextSize = 18
        textLabel.Text = "..."
        textLabel.Parent = billboardGui

        espHighlights[player] = {
            Highlight = highlight,
            Billboard = billboardGui,
            TextLabel = textLabel
        }
    end

    if player.Character then
        onCharacterAdded(player.Character)
    end
    player.CharacterAdded:Connect(onCharacterAdded)
end

local function updateESPDistances()
    if not espEnabled then return end
    for _, data in pairs(espHighlights) do
        local character = data.Highlight.Adornee
        if character and character:FindFirstChild("Head") then
            local distance = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and (character.Head.Position - LocalPlayer.Character.HumanoidRootPart.Position).Magnitude) or 0
            data.TextLabel.Text = string.format("%.1f м", distance)
        end
    end
end

local function toggleESP(enabled)
    espEnabled = enabled
    if enabled then
        for _, player in ipairs(Players:GetPlayers()) do
            createESPForPlayer(player)
        end
    else
        for _, data in pairs(espHighlights) do
            if data.Highlight then data.Highlight:Destroy() end
            if data.Billboard then data.Billboard:Destroy() end
        end
        espHighlights = {}
    end
end

-- ====================== PATHFINDING ======================
local function clearPath()
    for _, waypointPart in ipairs(waypoints) do
        waypointPart:Destroy()
    end
    waypoints = {}
end

local function createPathToTarget(targetPosition)
    clearPath()

    local character = LocalPlayer.Character
    if not character then return end

    local rootPart = character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    -- Создаем путь с помощью PathfindingService
    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 3,
        Costs = {
            Water = 100,
            Lava = math.huge
        }
    })

    path:ComputeAsync(rootPart.Position, targetPosition)

    if path.Status == Enum.PathStatus.Success then
        local waypointsList = path:GetWaypoints()
        local previousPoint = rootPart.Position

        for _, waypoint in ipairs(waypointsList) do
            local point = waypoint.Position

            -- Создаем визуальную точку пути
            local part = Instance.new("Part")
            part.Size = Vector3.new(1, 1, 1)
            part.Shape = Enum.PartType.Ball
            part.Position = point
            part.Anchored = true
            part.CanCollide = false
            part.Color = Color3.fromRGB(255, 0, 0)
            part.Material = Enum.Material.Neon
            part.Parent = CoreGui
            part.Transparency = 0.7
            table.insert(waypoints, part)

            -- Создаем линию между точками
            local linePart = Instance.new("Part")
            linePart.Size = Vector3.new(1, 1, 1)
            linePart.Anchored = true
            linePart.CanCollide = false
            linePart.Color = Color3.fromRGB(255, 0, 0)
            linePart.Material = Enum.Material.Neon
            linePart.Parent = CoreGui
            linePart.Transparency = 0.9

            local distance = (point - previousPoint).Magnitude
            linePart.Size = Vector3.new(0.2, 0.2, distance)
            linePart.CFrame = CFrame.lookAt(previousPoint, point) * CFrame.new(0, 0, -distance / 2)
            table.insert(waypoints, linePart)

            previousPoint = point
        end
    end
end

local function togglePathfinding(enabled)
    pathEnabled = enabled
    if not enabled then
        clearPath()
    end
end

-- ====================== UI ======================
local yOffset = 10
local checkboxESP = createCheckbox("ESP Игроков", UDim2.new(0, 10, 0, yOffset), toggleESP)
yOffset = yOffset + 45
local checkboxPath = createCheckbox("Pathfinding", UDim2.new(0, 10, 0, yOffset), togglePathfinding)

-- Кнопка для перезапуска Pathfinding
yOffset = yOffset + 45
local refreshButton = createButton("Обновить путь", UDim2.new(0, 10, 0, yOffset), function()
    if not pathEnabled then return end
    local nearestPlayer = nil
    local nearestDistance = math.huge
    local character = LocalPlayer.Character
    if not character then return end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local rootPart = player.Character:FindFirstChild("HumanoidRootPart")
            if rootPart then
                local distance = (rootPart.Position - character:FindFirstChild("HumanoidRootPart").Position).Magnitude
                if distance < nearestDistance then
                    nearestDistance = distance
                    nearestPlayer = player
                end
            end
        end
    end

    if nearestPlayer then
        createPathToTarget(nearestPlayer.Character.HumanoidRootPart.Position)
    end
end)

-- Заголовок
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(0, 200, 0, 30)
titleLabel.Position = UDim2.new(0, 10, 0, -50)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 18
titleLabel.Text = "Specter Helper"
titleLabel.Parent = ScreenGui

-- ====================== ИНИЦИАЛИЗАЦИЯ ======================
-- Подключаем ESP для новых игроков
Players.PlayerAdded:Connect(function(player)
    if espEnabled then
        createESPForPlayer(player)
    end
end)

Players.PlayerRemoving:Connect(function(player)
    if espHighlights[player] then
        espHighlights[player].Highlight:Destroy()
        espHighlights[player].Billboard:Destroy()
        espHighlights[player] = nil
    end
end)

-- Обновление расстояний ESP и Pathfinding
RunService.RenderStepped:Connect(function()
    updateESPDistances()
end)

print("Specter Helper загружен. Готов к работе!")
