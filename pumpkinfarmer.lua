-- PUMPKIN FARMER V3 - ILHA POR ILHA + DANO FIX
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Farming = false
local DELAY = 0.08
local ISLAND_DISTANCE = 1000 -- se a abóbora estiver >1000 studs da outra, é outra ilha

local KEYWORDS = {"pumpkin", "abobora", "pumpk", "halloween"}

local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Hit")

local function isPumpkin(obj)
    local n = string.lower(obj.Name)
    for _, k in pairs(KEYWORDS) do
        if string.find(n, k) then return true end
    end
    return false
end

local function findPumpkins()
    local list = {}
    for _, obj in pairs(workspace:GetDescendants()) do
        if isPumpkin(obj) then table.insert(list, obj) end
    end
    return list
end

local function getRoot(m)
    if m:IsA("BasePart") or m:IsA("MeshPart") then return m end
    return m:FindFirstChild("HumanoidRootPart", true) or m:FindFirstChildOfClass("BasePart", true)
end

local function equipWeapon()
    local char = player.Character
    local tool = char and char:FindFirstChildOfClass("Tool")
    if not tool then
        tool = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
        if tool then tool.Parent = char end
    end
    return tool
end

-- AGRUPA AS ABÓBORAS POR ILHA
local function groupByIsland(pumpkins)
    local groups = {}
    for _, p in ipairs(pumpkins) do
        local root = getRoot(p)
        if root then
            local pos = root.Position
            local placed = false
            for _, g in ipairs(groups) do
                if (g.center - pos).Magnitude < ISLAND_DISTANCE then
                    table.insert(g.items, p)
                    placed = true
                    break
                end
            end
            if not placed then
                table.insert(groups, {center = pos, items = {p}})
            end
        end
    end
    -- ordena pela ilha mais perto do jogador
    local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if hrp then
        table.sort(groups, function(a,b)
            return (a.center - hrp.Position).Magnitude < (b.center - hrp.Position).Magnitude
        end)
    end
    return groups
end

local function kill(pumpkin)
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local root = getRoot(pumpkin)
    if not hrp or not root then return end
    if not pumpkin or not pumpkin.Parent then return end

    local hum = pumpkin:FindFirstChildOfClass("Humanoid", true)

    -- fica colado e olhando para a abobora
    local targetPos = root.Position
    hrp.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 3.5, 0), targetPos)
    hrp.Velocity = Vector3.zero
    task.wait(0.05)
    hrp.CFrame = CFrame.lookAt(targetPos + Vector3.new(0, 3, 0), targetPos)

    -- equipa a arma e bate
    local tool = equipWeapon()
    if tool then tool:Activate() end

    -- dano via remote oficial do Blox Fruits (3x para garantir)
    for i = 1, 3 do
        pcall(function()
            local hitbox = { [1] = pumpkin }
            hitRemote:FireServer(tool and tool.Name or "M1", targetPos)
        end)
        task.wait(0.03)
    end

    -- fallback para NPC com Humanoid
    if hum and hum.Health > 0 then
        -- só tira dano se ainda estiver vivo após o hit
        if hum.Health > 0 then
            hum:TakeDamage(500) -- pequeno empurrão, não rely nele
        end
    end
end

-- MAIN LOOP ILHA POR ILHA
local function mainLoop()
    while Farming do
        local pumpkins = findPumpkins()
        local btn = getgenv().PumpBtn
        
        if #pumpkins == 0 then
            if btn then btn.Text = "FARMER: ON (0 aboboras)" end
            print("Sem aboboras, esperando...")
            task.wait(2)
        else
            local islands = groupByIsland(pumpkins)
            print(string.format("Detectadas %d aboboras em %d ilhas", #pumpkins, #islands))
            
            for islandIdx, island in ipairs(islands) do
                if not Farming then break end
                print(string.format("=== ILHA %d/%d - %d aboboras ===", islandIdx, #islands, #island.items))
                if btn then btn.Text = string.format("ILHA %d/%d", islandIdx, #islands) end

                -- quebra TODAS da ilha atual primeiro
                for _, p in ipairs(island.items) do
                    if not Farming then break end
                    if p and p.Parent then
                        pcall(kill, p)
                    end
                    task.wait(DELAY)
                end
                -- espera a ilha limpar antes de ir pra próxima
                task.wait(0.3)
                -- re-escaneia a mesma ilha, se sobrou alguma, ele volta nela
            end
        end
        task.wait(0.5)
    end
end

-- UI
local gui = Instance.new("ScreenGui")
gui.Name = "PumpkinV3"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 200, 0, 60)
btn.Position = UDim2.new(0.5, -100, 0, 60)
btn.Text = "FARMER: OFF"
btn.BackgroundColor3 = Color3.fromRGB(255, 128, 0)
btn.TextColor3 = Color3.new(1,1,1)
btn.TextScaled = true
btn.Parent = gui
getgenv().PumpBtn = btn

local function toggle()
    Farming = not Farming
    btn.Text = Farming and "FARMER: ON" or "FARMER: OFF"
    btn.BackgroundColor3 = Farming and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,128,0)
    if Farming then
        equipWeapon()
        task.spawn(mainLoop)
    end
end

btn.MouseButton1Click:Connect(toggle)
UIS.InputBegan:Connect(function(input,gpe)
    if not gpe and input.KeyCode == Enum.KeyCode.E then toggle() end
end)

-- NoClip enquanto farmeia
RunService.Stepped:Connect(function()
    if Farming and player.Character then
        for _, p in pairs(player.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)

print("[Pumpkin V3] Liga com E - EQUIPA TUA ESPADA ANTES!")
