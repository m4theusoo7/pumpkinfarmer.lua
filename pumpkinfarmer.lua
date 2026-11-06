-- PUMPKIN FARMER V2 - CORRIGIDO
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local Farming = false
local DISTANCE = 6
local DELAY = 0.05

-- Lista de palavras que vão detectar a abobora
local KEYWORDS = {"pumpkin", "abobora", "pumpk", "halloween"}

local function isPumpkin(obj)
    local n = string.lower(obj.Name)
    for _, k in pairs(KEYWORDS) do
        if string.find(n, k) then
            return true
        end
    end
    return false
end

local function findPumpkins()
    local list = {}
    -- Procura em lugares de streaming
    local folders = {workspace, workspace:FindFirstChild("Enemies"), workspace:FindFirstChild("Map"), workspace:FindFirstChild("NPCs")}
    for _, folder in pairs(folders) do
        if folder then
            for _, obj in pairs(folder:GetDescendants()) do
                if isPumpkin(obj) then
                    table.insert(list, obj)
                end
            end
        end
    end
    return list
end

local function getRoot(model)
    if model:IsA("BasePart") or model:IsA("MeshPart") then
        return model
    end
    return model:FindFirstChild("HumanoidRootPart", true) or model:FindFirstChildOfClass("BasePart", true)
end

local function kill(target)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local root = getRoot(target)
    if not hrp or not root then return end
    
    hrp.CFrame = CFrame.new(root.Position + Vector3.new(0, DISTANCE, 0))
    hrp.Velocity = Vector3.zero
    task.wait(0.05)
    
    -- Clique
    VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1)
    task.wait(DELAY)
    VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1)

    -- Se for NPC com Humanoid, dá dano direto
    local hum = target:FindFirstChildOfClass("Humanoid", true)
    if hum and hum.Health > 0 then
        hum:TakeDamage(9999)
    end
    
    -- Se for Part quebrável, também toca (CanTouch)
    root.CanTouch = true
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "PumpkinV2"
gui.ResetOnSpawn = false
local ok, hu = pcall(function() return gethui() end)
gui.Parent = ok and hu or player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 200, 0, 60)
btn.Position = UDim2.new(0.5, -100, 0, 60)
btn.Text = "FARMER: OFF (0 aboboras)"
btn.BackgroundColor3 = Color3.fromRGB(255, 128, 0)
btn.TextColor3 = Color3.new(1,1,1)
btn.TextScaled = true
btn.Parent = gui

local function toggle()
    Farming = not Farming
    btn.BackgroundColor3 = Farming and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 128, 0)
    print("[Pumpkin V2] Ligado:", Farming)
    task.spawn(function()
        while Farming do
            local list = findPumpkins()
            btn.Text = string.format("FARMER: %s (%d)", Farming and "ON" or "OFF", #list)
            if #list == 0 then
                warn("Nenhuma abobora encontrada. Esperando...")
                task.wait(1)
            else
                for _, p in pairs(list) do
                    if not Farming then break end
                    pcall(kill, p)
                    task.wait(DELAY)
                end
            end
            task.wait(0.2)
        end
    end)
end

btn.MouseButton1Click:Connect(toggle)
UIS.InputBegan:Connect(function(input, gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.E then toggle() end
end)

-- NoClip
RunService.Stepped:Connect(function()
    if Farming and player.Character then
        for _, p in pairs(player.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

print("[Pumpkin V2] Carregado - Aperta E")
