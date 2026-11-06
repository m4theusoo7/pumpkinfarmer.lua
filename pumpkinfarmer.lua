-- PUMPKIN FARMER - BLOX FRUITS
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

-- CONFIG
local DELAY = 0.05 -- tempo entre cada abóbora
local DISTANCE = 5 -- distancia que ele fica da abóbora
local KEY_TOGGLE = Enum.KeyCode.E -- aperta E para ligar/desligar

local Farming = false
local Tweening = false

-- FUNÇÃO PARA ACHAR AS ABÓBORAS
local function findPumpkins()
    local list = {}
    -- Procura em Enemies (caso esteja spawando como NPC/Enemy de Halloween)
    if workspace:FindFirstChild("Enemies") then
        for _, enemy in pairs(workspace.Enemies:GetDescendants()) do
            if string.find(string.lower(enemy.Name), "pumpkin") or string.find(string.lower(enemy.Name), "abobora") then
                if enemy:FindFirstChild("Humanoid") and enemy:FindFirstChild("HumanoidRootPart") then
                    table.insert(list, enemy)
                end
            end
        end
    end
    -- Procura também na workspace normal (caso seja objeto quebrável)
    for _, obj in pairs(workspace:GetDescendants()) do
        if (string.find(string.lower(obj.Name), "pumpkin") or string.find(string.lower(obj.Name), "abobora")) and obj:IsA("Model") then
            if obj:FindFirstChild("HumanoidRootPart") or obj:FindFirstChild("Part") then
                table.insert(list, obj)
            end
        end
    end
    return list
end

local function getRoot(model)
    return model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Part") or model:FindFirstChildOfClass("Part")
end

local function getHumanoid(model)
    return model:FindFirstChildOfClass("Humanoid")
end

-- TELEPORTE
local function teleportTo(pos)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = CFrame.new(pos + Vector3.new(0, DISTANCE, 0))
        -- travar no ar
        hrp.Velocity = Vector3.new()
    end
end

-- ATACAR / QUEBRAR
local function killPumpkin(model)
    local hrp = getRoot(model)
    local hum = getHumanoid(model)
    if not hrp then return end

    teleportTo(hrp.Position)
    task.wait(0.05)

    -- 1. Simular clique (funciona com espada/pistola equipada)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
    task.wait(DELAY)
    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)

    -- 2. Dano direto (para abóbora quebrável ou enemy com pouca vida)
    if hum and hum.Health > 0 then
        hum:TakeDamage(9999)
    end
end

-- LOOP PRINCIPAL ILHA POR ILHA
local function startFarmer()
    while Farming do
        local pumpkins = findPumpkins()
        if #pumpkins == 0 then
            print("Nenhuma abóbora encontrada, esperando...")
            task.wait(1)
        else
            for _, pumpkin in ipairs(pumpkins) do
                if not Farming then break end
                if pumpkin and pumpkin.Parent then
                    pcall(killPumpkin, pumpkin)
                end
                task.wait(DELAY)
            end
        end
        task.wait(0.5)
    end
end

-- UI BOTÃO
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "PumpkinFarmer"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local Button = Instance.new("TextButton")
Button.Size = UDim2.new(0, 150, 0, 50)
Button.Position = UDim2.new(0.5, -75, 0, 50)
Button.Text = "FARMER: OFF"
Button.BackgroundColor3 = Color3.fromRGB(255, 128, 0)
Button.TextColor3 = Color3.new(1,1,1)
Button.Font = Enum.Font.SourceSansBold
Button.Parent = ScreenGui

local function toggle()
    Farming = not Farming
    Button.Text = Farming and "FARMER: ON" or "FARMER: OFF"
    Button.BackgroundColor3 = Farming and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,128,0)
    print("Pumpkin Farmer:", Farming)
    if Farming then
        task.spawn(startFarmer)
    end
end

Button.MouseButton1Click:Connect(toggle)

-- TECLA E
game:GetService("UserInputService").InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == KEY_TOGGLE then
        toggle()
    end
end)

-- NOCLIP
RunService.Stepped:Connect(function()
    if Farming and player.Character then
        for _, v in pairs(player.Character:GetDescendants()) do
            if v:IsA("BasePart") then
                v.CanCollide = false
            end
        end
    end
end)

print("[Pumpkin Farmer] Carregado! Aperta E para ativar")
