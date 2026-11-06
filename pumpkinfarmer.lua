-- PUMPKIN FARM / BLOX FRUITS - ALTERNATIVA DIRETA
-- Autora: Crouton Alpha

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local hrp = character:WaitForChild("HumanoidRootPart")

local ToggleKey = Enum.KeyCode.F
local Farming = false
local IslandRadius = 400
local FlySpeed = 450

-- Função para equipar a ferramenta automaticamente
local function getTool()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    
    local bpTool = player.Backpack:FindFirstChildOfClass("Tool")
    if bpTool and hum then
        hum:EquipTool(bpTool)
        return bpTool
    end
    return nil
end

-- Varre o workspace à procura de abóboras
local function getPumpkins()
    local pumpkins = {}
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj.Name == "Jack o' Lantern" or obj.Name:lower():find("pumpkin") then
            local part = nil
            if obj:IsA("Model") then
                part = obj.PrimaryPart or obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChildWhichIsA("BasePart")
            elseif obj:IsA("BasePart") then
                part = obj
            end
            
            if part then
                table.insert(pumpkins, { Model = obj, Part = part })
            end
        end
    end
    return pumpkins
end

-- Movimento suave até a abóbora
local function flyTo(targetPos)
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    local dist = (targetPos - root.Position).Magnitude
    if dist < 5 then return end

    local time = math.max(dist / FlySpeed, 0.1)
    local tween = TweenService:Create(root, TweenInfo.new(time, Enum.EasingStyle.Linear), {
        CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 3, 0), targetPos)
    })

    root.Anchored = true
    tween:Play()
    tween.Completed:Wait()
    root.Anchored = false
end

-- Loop principal de limpeza por ilhas
local function farmLoop()
    while Farming do
        local list = getPumpkins()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        
        if #list == 0 or not root then
            task.wait(1)
        else
            -- Filtra abóboras da ilha atual do jogador
            local currentIsland = {}
            for _, p in ipairs(list) do
                if (p.Part.Position - root.Position).Magnitude < IslandRadius then
                    table.insert(currentIsland, p)
                end
            end
            
            -- Se não houver na ilha atual, pega a ilha mais próxima seguinte
            if #currentIsland == 0 then
                table.sort(list, function(a, b)
                    return (a.Part.Position - root.Position).Magnitude < (b.Part.Position - root.Position).Magnitude
                end)
                local center = list[1].Part.Position
                for _, p in ipairs(list) do
                    if (p.Part.Position - center).Magnitude < IslandRadius then
                        table.insert(currentIsland, p)
                    end
                end
            end
            
            -- Ordena da mais perto para a mais longe dentro da ilha
            table.sort(currentIsland, function(a, b)
                return (a.Part.Position - root.Position).Magnitude < (b.Part.Position - root.Position).Magnitude
            end)
            
            -- Executa a quebra de cada abóbora na ilha
            for _, p in ipairs(currentIsland) do
                if not Farming then break end
                if p.Model and p.Model.Parent and p.Part and p.Part.Parent then
                    flyTo(p.Part.Position)
                    
                    local startTime = os.clock()
                    while Farming and p.Model.Parent and p.Part.Parent do
                        if os.clock() - startTime > 7 then break end
                        
                        local tool = getTool()
                        if tool then
                            tool:Activate()
                        end
                        
                        local r = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                        if r then
                            r.CFrame = CFrame.lookAt(p.Part.Position + Vector3.new(0, 3, 0), p.Part.Position)
                            r.AssemblyLinearVelocity = Vector3.zero
                        end
                        
                        task.wait(0.15)
                    end
                end
            end
        end
        task.wait(0.2)
    end
end

-- Ativação/Desativação pela tecla F
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode == ToggleKey then
        Farming = not Farming
        print("[Farm Alternativo] Estado:", Farming)
        if Farming then
            task.spawn(farmLoop)
        end
    end
end)

-- Remove colisão para o teletransporte funcionar sem prender nas paredes
RunService.Stepped:Connect(function()
    if Farming then
        local char = player.Character
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") then
                    part.CanCollide = false
                end
            end
        end
    end
end)

print("[Farm Alternativo] Carregado! Equipa a tua arma e prime a tecla F para começar.")
