-- PUMPKIN FARM / JACK O' LANTERN / V9 PROFISSIONAL
-- Autora: Crouton Alpha

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local Hit = Remotes:WaitForChild("Hit")

local Config = {
    IslandRadius = 1500,
    HitDistance = 6,
    FlySpeed = 450,
    AttackDelay = 0.12,
    MaxAttackTime = 10,
    ToggleKey = Enum.KeyCode.E,
}

local Farming = false

local function getHRP()
    local char = player.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local char = player.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getTool()
    local hum = getHumanoid()
    local char = player.Character
    if not hum or not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local bpTool = player.Backpack:FindFirstChildOfClass("Tool")
    if bpTool then
        bpTool.Parent = char
        hum:EquipTool(bpTool)
    end
    return bpTool
end

-- 1. SCAN - só vivos, só Enemies, só Jack o' Lantern
local function findTargets()
    local targets = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return targets end

    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") and model.Name == "Jack o' Lantern" then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = model:FindFirstChild("HumanoidRootPart")
            if hum and hum.Health > 0 and root then
                table.insert(targets, { Model = model, Humanoid = hum, Root = root })
            end
        end
    end
    return targets
end

-- 2. MOVE - tween ancorado, sem cair debaixo do mapa
local function moveTo(targetPos: Vector3)
    local hrp = getHRP()
    if not hrp then return end

    local distance = (targetPos - hrp.Position).Magnitude
    if distance < Config.HitDistance then return end

    local targetCF = CFrame.lookAt(targetPos + Vector3.new(0, 3, 0), targetPos)
    local time = math.max(distance / Config.FlySpeed, 0.1)
    local tween = TweenService:Create(hrp, TweenInfo.new(time, Enum.EasingStyle.Linear), { CFrame = targetCF })

    hrp.Anchored = true
    tween:Play()
    tween.Completed:Wait()
    hrp.Anchored = false
end

-- 3. ATTACK - até quebrar, sem desistir
local function attack(target)
    local model = target.Model
    local hum = target.Humanoid

    local tool = getTool()
    if not tool then return end

    local hrp = getHRP()
    if not hrp then return end

    -- Teleporta primeiro, depois ataca
    moveTo(target.Root.Position)
    task.wait(0.05)

    local start = os.clock()
    while Farming and model.Parent and hum.Health > 0 do
        if (os.clock() - start) > Config.MaxAttackTime then break end

        local root = model:FindFirstChild("HumanoidRootPart")
        if not root then break end

        -- fica colado e olhando
        hrp.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 3, 0), root.Position)
        hrp.AssemblyLinearVelocity = Vector3.zero

        -- Spam M1
        tool:Activate()
        Hit:FireServer(root.Position)

        task.wait(Config.AttackDelay)
    end
end

-- 4. LOOP COORDENADO
local function getIslandTargets(targets)
    local hrp = getHRP()
    if not hrp then return {} end

    -- Ilha atual = tudo dentro do radius do jogador
    local island = {}
    for _, t in ipairs(targets) do
        if (t.Root.Position - hrp.Position).Magnitude < Config.IslandRadius then
            table.insert(island, t)
        end
    end

    -- Se nada perto, pega a ilha mais próxima
    if #island == 0 and #targets > 0 then
        table.sort(targets, function(a, b)
            return (a.Root.Position - hrp.Position).Magnitude < (b.Root.Position - hrp.Position).Magnitude
        end)
        local center = targets[1].Root.Position
        for _, t in ipairs(targets) do
            if (t.Root.Position - center).Magnitude < Config.IslandRadius then
                table.insert(island, t)
            end
        end
    end

    -- Mais perto primeiro na ilha
    table.sort(island, function(a, b)
        return (a.Root.Position - hrp.Position).Magnitude < (b.Root.Position - hrp.Position).Magnitude
    end)

    return island
end

local function main()
    while Farming do
        local all = findTargets()
        if #all == 0 then
            task.wait(0.5)
        else
            local island = getIslandTargets(all)
            for _, target in ipairs(island) do
                if not Farming then break end
                if target.Model and target.Model.Parent and target.Humanoid.Health > 0 then
                    attack(target)
                end
            end
            task.wait(0.2)
        end
    end
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.ToggleKey then
        Farming = not Farming
        print("[Pumpkin Farm V9] Farming:", Farming)
        if Farming then task.spawn(main) end
    end
end)

RunService.Stepped:Connect(function()
    if Farming then
        local hrp = getHRP()
        if hrp then
            hrp.CanCollide = false
            for _, p in ipairs(player.Character:GetDescendants()) do
                if p:IsA("BasePart") then p.CanCollide = false end
            end
        end
    end
end)

print("[Pumpkin Farm V9] Carregado! Aperte E com a arma equipada.")
