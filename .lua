--[[
    Universal ESP + Pathfinding
    Одна кнопка, работает в любой игре
    Для Delta Executor (Android)
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PathfindingService = game:GetService("PathfindingService")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

-- Состояние
local enabled = false

-- Объекты
local espItems = {}
local waypoints = {}       -- для pathfinding
local lineToTarget = nil   -- для прямой линии

-- ====================== ГЛАВНАЯ КНОПКА ======================
local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "UniversalTool"

local mainButton = Instance.new("TextButton")
mainButton.Size = UDim2.new(0, 180, 0, 45)
mainButton.Position = UDim2.new(0.5, -90, 0, 20)
mainButton.Text = "ESP + Путь: ВЫКЛ"
mainButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
mainButton.TextColor3 = Color3.new(1, 1, 1)
mainButton.Font = Enum.Font.SourceSansBold
mainButton.TextSize = 16
mainButton.BorderSizePixel = 0
mainButton.Parent = ScreenGui
Instance.new("UICorner", mainButton)

-- ====================== ESP ======================
local function createESP(player)
    if player == LocalPlayer then return end

    local function onCharacter(character)
        local head = character:WaitForChild("Head")
        local highlight = Instance.new("Highlight")
        highlight.FillColor = Color3.fromRGB(255, 0, 0)
        highlight.OutlineColor = Color3.fromRGB(255, 50, 50)
        highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        highlight.Adornee = character
        highlight.Parent = CoreGui

        local billboard = Instance.new("BillboardGui")
        billboard.Size = UDim2.new(0, 200, 0, 30)
        billboard.StudsOffset = Vector3.new(0, 3, 0)
        billboard.AlwaysOnTop = true
        billboard.Parent = head
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.TextColor3 = Color3.fromRGB(255, 255, 255)
        label.Font = Enum.Font.SourceSansBold
        label.TextSize = 18
        label.Text = "..."
        label.Parent = billboard

        espItems[player] = { Highlight = highlight, Billboard = billboard, Label = label }
    end

    if player.Character then onCharacter(player.Character) end
    player.CharacterAdded:Connect(onCharacter)
end

local function clearESP()
    for _, data in pairs(espItems) do
        data.Highlight:Destroy()
        data.Billboard:Destroy()
    end
    espItems = {}
end

local function updateESPDistances()
    if not enabled then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    for player, data in pairs(espItems) do
        local character = player.Character
        if character and character:FindFirstChild("Head") then
            local dist = (character.Head.Position - myRoot.Position).Magnitude
            data.Label.Text = string.format("%.1f м", dist)
        end
    end
end

-- ====================== TRAJECTORY ======================
local function clearPath()
    for _, obj in ipairs(waypoints) do obj:Destroy() end
    waypoints = {}
    if lineToTarget then lineToTarget:Destroy(); lineToTarget = nil end
end

local function buildPathTo(targetPos)
    clearPath()
    local char = LocalPlayer.Character
    if not char then return end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local path = PathfindingService:CreatePath({
        AgentRadius = 2,
        AgentHeight = 5,
        AgentCanJump = true,
        WaypointSpacing = 2,
        Costs = { Water = 100, Lava = math.huge }
    })

    local success, err = pcall(function()
        path:ComputeAsync(root.Position, targetPos)
    end)

    if success and path.Status == Enum.PathStatus.Success then
        -- Рисуем путь по точкам (не через стены)
        local points = path:GetWaypoints()
        local prev = root.Position
        for _, wp in ipairs(points) do
            local p = wp.Position
            local dot = Instance.new("Part")
            dot.Size = Vector3.new(0.8, 0.8, 0.8)
            dot.Shape = Enum.PartType.Ball
            dot.Position = p
            dot.Anchored = true
            dot.CanCollide = false
            dot.Color = Color3.fromRGB(255, 0, 0)
            dot.Material = Enum.Material.Neon
            dot.Parent = CoreGui
            dot.Transparency = 0.6
            table.insert(waypoints, dot)

            local line = Instance.new("Part")
            local dist = (p - prev).Magnitude
            line.Size = Vector3.new(0.15, 0.15, dist)
            line.CFrame = CFrame.lookAt(prev, p) * CFrame.new(0, 0, -dist/2)
            line.Anchored = true
            line.CanCollide = false
            line.Color = Color3.fromRGB(255, 0, 0)
            line.Material = Enum.Material.Neon
            line.Parent = CoreGui
            line.Transparency = 0.7
            table.insert(waypoints, line)
            prev = p
        end
    else
        -- Navmesh нет → прямая линия
        lineToTarget = Instance.new("Beam")
        lineToTarget.Parent = CoreGui
        lineToTarget.Color = ColorSequence.new(Color3.fromRGB(255, 0, 0))
        lineToTarget.Width0 = 0.2
        lineToTarget.Width1 = 0.2
        lineToTarget.Transparency = NumberSequence.new(0.5)
        -- Beam требует Attachments, создадим их
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            local attach0 = Instance.new("Attachment")
            attach0.Parent = char.HumanoidRootPart
            local attach1 = Instance.new("Attachment")
            attach1.Parent = workspace.Terrain -- временно, обновим в цикле
            lineToTarget.Attachment0 = attach0
            lineToTarget.Attachment1 = attach1
        end
    end
end

local function updatePath()
    if not enabled then return end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not myRoot then return end

    local nearestPlayer, nearestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = player
                end
            end
        end
    end

    if nearestPlayer then
        buildPathTo(nearestPlayer.Character.HumanoidRootPart.Position)
    else
        clearPath()
    end
end

-- Обновление прямой линии (если используется)
local function updateBeam()
    if not enabled or not lineToTarget or not lineToTarget.Attachment0 or not lineToTarget.Attachment1 then
        return
    end
    local myRoot = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    local nearestPlayer, nearestDist = nil, math.huge
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local root = player.Character:FindFirstChild("HumanoidRootPart")
            if root then
                local dist = (root.Position - myRoot.Position).Magnitude
                if dist < nearestDist then
                    nearestDist = dist
                    nearestPlayer = player
                end
            end
        end
    end
    if nearestPlayer and nearestPlayer.Character then
        local targetRoot = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
        if targetRoot then
            lineToTarget.Attachment0.Parent = myRoot
            lineToTarget.Attachment1.Parent = targetRoot
        end
    end
end

-- ====================== ВКЛ/ВЫКЛ ======================
local function setEnabled(state)
    enabled = state
    if state then
        mainButton.Text = "ESP + Путь: ВКЛ"
        mainButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)

        for _, player in ipairs(Players:GetPlayers()) do
            createESP(player)
        end
        updatePath()
    else
        mainButton.Text = "ESP + Путь: ВЫКЛ"
        mainButton.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        clearESP()
        clearPath()
    end
end

mainButton.MouseButton1Click:Connect(function()
    setEnabled(not enabled)
end)

-- ====================== ОБРАБОТЧИКИ ======================
Players.PlayerAdded:Connect(function(player)
    if enabled then createESP(player) end
end)

Players.PlayerRemoving:Connect(function(player)
    if espItems[player] then
        espItems[player].Highlight:Destroy()
        espItems[player].Billboard:Destroy()
        espItems[player] = nil
    end
end)

RunService.RenderStepped:Connect(function()
    updateESPDistances()
    updateBeam()
end)

spawn(function()
    while true do
        wait(0.5)
        if enabled then
            updatePath()
        end
    end
end)
