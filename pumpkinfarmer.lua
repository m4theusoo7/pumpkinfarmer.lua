-- PUMPKIN FARM / JACK O' LANTERN / V9 PROFISSIONAL (TOGGLE & ISLAND HOP)
-- Autora: Crouton Alpha

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Config = {
    IslandRadius = 400,   -- Raio para detetar abóboras na mesma ilha
    HitDistance = 5,      -- Distância para colar na abóbora e bater
    FlySpeed = 450,       -- Velocidade do deslocamento
    AttackDelay = 0.1,    -- Delay entre cada ataque
    MaxAttackTime = 8,    -- Tempo máximo por abóbora antes de saltar para a próxima
    ToggleKey = Enum.KeyCode.F, -- Tecla para Ligar/Desligar (Podes usar F sem conflitar com o E do jogo)
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

-- 1. SCAN - Procura todas as abóboras espalhadas pelo mapa inteiro
local function findPumpkinTargets()
    local targets = {}
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Jack o' Lantern" or obj.Name:lower():find("jack o' lantern") then
            local rootPart = nil
            local humanoid = nil
            
            if obj:IsA("Model") then
                rootPart = obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("PrimaryPart") or obj:FindFirstChildWhichIsA("BasePart")
                humanoid = obj:FindFirstChildOfClass("Humanoid")
            elseif obj:IsA("BasePart") then
                rootPart = obj
            end
            
            if rootPart then
                local alive = true
                if humanoid and humanoid.Health <= 0 then alive = false end
                
                if alive then
                    local exists = false
                    for _, t in ipairs(targets) do
                        if t.Root == rootPart or t.Object == obj then exists = true break end
                    end
                    if not exists then
                        table.insert(targets, { Object = obj, Root = rootPart, Humanoid = humanoid })
                    end
                end
            end
        end
    end

    return targets
end

-- 2. MOVE - Tween seguro até a abóbora
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

-- 3. ATTACK - Ataca a abóbora atual até ela quebrar / desaparecer
local function attack(target)
    local obj = target.Object
    local root = target.Root
    local hum = target.Humanoid

    local tool = getTool()
    local hrp = getHRP()
    if not hrp then return end

    moveTo(root.Position)
    task.wait(0.05)

    local start = os.clock()
    while Farming and obj and obj.Parent and root and root.Parent do
        if hum and hum.Health <= 0 then break end
        if (os.clock() - start) > Config.MaxAttackTime then break end

        hrp.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 3, 0), root.Position)
        hrp.AssemblyLinearVelocity = Vector3.zero

        if tool then
            tool:Activate()
        end

        task.wait(Config.AttackDelay)
    end
end

-- 4. ORGANIZAR ILHAS: Fica na ilha atual até limpar tudo, depois vai para a ilha mais próxima com abóboras
local function getIslandTargets(targets)
    local hrp = getHRP()
    if not hrp then return {} end

    -- Pega tudo o que está na ilha atual do jogador
    local island = {}
    for _, t in ipairs(targets) do
        if (t.Root.Position - hrp.Position).Magnitude < Config.IslandRadius then
            table.insert(island, t)
        end
    end

    -- Se limpou tudo na ilha atual, pega o centro da próxima ilha mais próxima que ainda tem abóboras
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

    -- Ordena da mais próxima para a mais distante dentro da ilha atual
    table.sort(island, function(a, b)
        return (a.Root.Position - hrp.Position).Magnitude < (b.Root.Position - hrp.Position).Magnitude
    end)

    return island
end

-- 5. LOOP PRINCIPAL DE FARM
local function main()
    while Farming do
        local all = findPumpkinTargets()
        if #all == 0 then
            task.wait(0.5) -- Se não houver abóboras no mapa, aguarda reaparecerem
        else
            local island = getIslandTargets(all)
            for _, target in ipairs(island) do
                if not Farming then break end
                if target.Object and target.Object.Parent then
                    attack(target)
                end
            end
            task.wait(0.2)
        end
    end
end

-- Controlo de Ativação por Tecla (Tecla F)
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == Config.ToggleKey then
        Farming = not Farming
        print("[Pumpkin Farm V9] Estado do Farming:", Farming)
        if Farming then
            task.spawn(main)
        end
    end
end)

-- Evita colisões e empurrões enquanto está a voar/farmar
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

print("[Pumpkin Farm V9] Carregado com sucesso! Equipa a tua arma e aperta a tecla **F** para ligar/desligar.")
