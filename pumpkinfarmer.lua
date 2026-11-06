-- PUMPKIN FARMER V8 - JACK O' LANTERN DEFINITIVO
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Farming = false
local ISLAND_RADIUS = 1500

local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Hit")

local function getHRP() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function getHum() return player.Character and player.Character:FindFirstChild("Humanoid") end

-- Só pega o HumanoidRootPart de verdade, nunca um BasePart aleatório
local function getRoot(model)
    return model:FindFirstChild("HumanoidRootPart", true)
end

local function findPumpkins()
    local list = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return list end

    for _, model in ipairs(enemies:GetChildren()) do
        if model:IsA("Model") and string.lower(model.Name) == "jack o' lantern" then
            local hum = model:FindFirstChildOfClass("Humanoid")
            local root = getRoot(model)
            -- só conta se ele está vivo e tem posição válida
            if hum and hum.Health > 0 and root then
                table.insert(list, model)
            end
        end
    end
    return list
end

local function equipWeapon()
    local hum = getHum()
    local char = player.Character
    if not hum or not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local bp = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
    if bp then bp.Parent = char hum:EquipTool(bp) return bp end
    return nil
end

-- VOO ANCORADO - nunca cai pra debaixo do mapa
local function flyTo(targetPos, speed)
    local hrp = getHRP()
    if not hrp then return end
    hrp.Anchored = true
    pcall(function() hrp:SetNetworkOwner(player) end)

    while Farming and hrp.Parent do
        local cur = hrp.Position
        local dist = (targetPos - cur).Magnitude
        if dist < 5 then break end
        local dt = RunService.Heartbeat:Wait()
        local step = math.min(dist, (speed or 400) * dt)
        local newPos = cur + (targetPos - cur).Unit * step
        -- mantém sempre 15 studs acima para não entrar no terreno
        hrp.CFrame = CFrame.lookAt(newPos + Vector3.new(0, 8, 0), targetPos)
    end
    hrp.Anchored = false
end

-- ATACA ATÉ QUEBRAR
local function attackUntilBreak(pumpkin)
    local hrp = getHRP()
    local root = getRoot(pumpkin)
    if not hrp or not root then return end
    if not pumpkin.Parent then return end

    local humAlvo = pumpkin:FindFirstChildOfClass("Humanoid")
    if not humAlvo or humAlvo.Health <= 0 then return end

    -- 1. Voa até a abóbora (ancorado, sem cair)
    flyTo(root.Position, 400)
    task.wait(0.05)

    -- 2. Começa o ataque até quebrar
    local tool = equipWeapon()
    if not tool then warn("EQUIPA SUA ARMA!") return end

    local start = os.clock()
    while Farming and pumpkin and pumpkin.Parent do
        if humAlvo.Health <= 0 then break end
        if os.clock() - start > 8 then break end

        local hrp2 = getHRP()
        local root2 = getRoot(pumpkin)
        if not hrp2 or not root2 then break end

        -- fica colado e olhando
        local p = root2.Position
        hrp2.Anchored = true
        hrp2.CFrame = CFrame.lookAt(p + Vector3.new(0, 4, 0), p)

        pcall(function() tool:Activate() end)
        if hitRemote then pcall(function() hitRemote:FireServer(p) end) end

        task.wait(0.08)
    end
    local hrp2 = getHRP()
    if hrp2 then hrp2.Anchored = false end
end

local function getNearestIsland(all)
    local hrp = getHRP() if not hrp then return {} end
    local current = {}
    for _,p in ipairs(all) do
        local r = getRoot(p)
        if r and (r.Position - hrp.Position).Magnitude < ISLAND_RADIUS then
            table.insert(current, p)
        end
    end
    if #current > 0 then
        table.sort(current, function(a,b) return (getRoot(a).Position-hrp.Position).Magnitude < (getRoot(b).Position-hrp.Position).Magnitude end)
        return current
    end
    local nearest, nd = nil, 999999
    for _,p in ipairs(all) do
        local r = getRoot(p)
        if r then local d=(r.Position-hrp.Position).Magnitude if d<nd then nd=d nearest=p end end
    end
    if not nearest then return {} end
    local center = getRoot(nearest).Position
    local island = {}
    for _,p in ipairs(all) do
        local r = getRoot(p)
        if r and (r.Position - center).Magnitude < ISLAND_RADIUS then table.insert(island,p) end
    end
    table.sort(island, function(a,b) return (getRoot(a).Position-hrp.Position).Magnitude < (getRoot(b).Position-hrp.Position).Magnitude end)
    return island
end

local function mainLoop()
    while Farming do
        local all = findPumpkins()
        local btn = getgenv().PumpBtn
        if #all == 0 then
            if btn then btn.Text = string.format("FARMER: ON (0) - TOTAL 0") end
            print("Nenhum Jack o' Lantern vivo na Enemies")
            task.wait(2)
        else
            local island = getNearestIsland(all)
            if btn then btn.Text = string.format("ILHA: %d/%d Jack", #island, #all) end
            print("Ilha atual:", #island)
            for _, p in ipairs(island) do
                if not Farming then break end
                pcall(attackUntilBreak, p)
                task.wait(0.1)
            end
        end
        task.wait(0.4)
    end
end

-- UI
local gui = Instance.new("ScreenGui") gui.ResetOnSpawn=false gui.Parent=player:WaitForChild("PlayerGui")
local btn = Instance.new("TextButton") btn.Size=UDim2.new(0,220,0,60) btn.Position=UDim2.new(0.5,-110,0,60) btn.Text="FARMER: OFF" btn.BackgroundColor3=Color3.fromRGB(255,128,0) btn.TextColor3=Color3.new(1,1,1) btn.TextScaled=true btn.Parent=gui
getgenv().PumpBtn = btn

local function toggle()
    Farming = not Farming
    btn.Text = Farming and "FARMER: ON" or "FARMER: OFF"
    btn.BackgroundColor3 = Farming and Color3.fromRGB(0,255,0) or Color3.fromRGB(255,128,0)
    if Farming then equipWeapon() task.spawn(mainLoop) end
end
btn.MouseButton1Click:Connect(toggle)
UIS.InputBegan:Connect(function(i,g) if not g and i.KeyCode==Enum.KeyCode.E then toggle() end end)

RunService.Stepped:Connect(function()
    if Farming then
        local hrp = getHRP()
        if hrp then
            for _,p in ipairs(player.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end
            hrp.CanCollide = false
        end
    end
end)

print("[V8] Jack o' Lantern - Liga com E, com arma no 1!")
