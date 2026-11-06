-- PUMPKIN FARMER V4 - ILHA ATUAL PRIMEIRO, LOOP PROGRESSIVO
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local Farming = false
local ISLAND_RADIUS = 1500 -- tudo dentro de 1500 studs = 1 ilha
local HIT_DISTANCE = 5 -- distancia ideal pra contar o golpe

local KEYWORDS = {"pumpkin", "abobora", "pumpk"}

local hitRemote = ReplicatedStorage:FindFirstChild("Remotes") and ReplicatedStorage.Remotes:FindFirstChild("Hit")

local function getHRP()
    return player.Character and player.Character:FindFirstChild("HumanoidRootPart")
end
local function getHum()
    return player.Character and player.Character:FindFirstChild("Humanoid")
end

local function isPumpkin(obj) local n=string.lower(obj.Name) for _,k in ipairs(KEYWORDS) do if string.find(n,k) then return true end end return false end
local function getRoot(m) if m:IsA("BasePart") then return m end return m:FindFirstChild("HumanoidRootPart", true) or m:FindFirstChildOfClass("BasePart", true) end

local function findPumpkins()
    local list = {}
    for _, o in ipairs(workspace:GetDescendants()) do
        if isPumpkin(o) then table.insert(list,o) end
    end
    return list
end

local function equipWeapon()
    local hum = getHum()
    local char = player.Character
    if not hum or not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local bpTool = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
    if bpTool then
        bpTool.Parent = char
        hum:EquipTool(bpTool)
        return bpTool
    end
    return nil
end

-- pega TODAS as aboboras da ILHA ATUAL (perto do jogador)
local function getCurrentIslandPumpkins(allPumpkins)
    local hrp = getHRP()
    if not hrp then return {} end
    local current = {}
    for _, p in ipairs(allPumpkins) do
        local r = getRoot(p)
        if r and (r.Position - hrp.Position).Magnitude < ISLAND_RADIUS then
            table.insert(current, p)
        end
    end
    -- ordena pelas mais perto
    table.sort(current, function(a,b)
        return (getRoot(a) and (getRoot(a).Position - hrp.Position).Magnitude or 99999) < (getRoot(b) and (getRoot(b).Position - hrp.Position).Magnitude or 99999)
    end)
    return current
end

-- move suave e rapido (em vez de CFrame instantaneo que deixa o teleporte bugado)
local function moveTo(pos)
    local hrp = getHRP()
    if not hrp then return end
    local target = CFrame.lookAt(pos, pos + (pos - hrp.Position).Unit * 10)
    -- teleporte rapido MAS com controle pra nao piscar entre ilhas
    hrp.CFrame = target
    hrp.Velocity = Vector3.zero
    task.wait(0.05)
end

local function attackPumpkin(pumpkin)
    local hrp = getHRP()
    local root = getRoot(pumpkin)
    if not hrp or not root then return end
    if not pumpkin.Parent then return end

    local humAlvo = pumpkin:FindFirstChildOfClass("Humanoid", true)
    local pos = root.Position

    -- 1. Vai até o lado da abobora (não em cima dela)
    -- fica 4 studs do lado, olhando pra ela
    local offset = (hrp.Position - pos)
    if offset.Magnitude < 0.1 then offset = Vector3.new(0,0,1) end
    local sidePos = pos + offset.Unit * HIT_DISTANCE + Vector3.new(0, 3, 0)

    moveTo(sidePos)

    -- 2. Garante distancia e direção
    hrp.CFrame = CFrame.lookAt(hrp.Position, pos)
    task.wait(0.03)

    local tool = equipWeapon()
    if not tool then warn("EQUIPA TUA ESPADA ANTES!") return end

    -- 3. Spamma o golpe até quebrar
    local start = os.clock()
    while Farming and pumpkin.Parent and (os.clock() - start) < 3 do
        if humAlvo and humAlvo.Health <= 0 then break end
        
        -- Ativa a ferramenta (melee)
        pcall(function() tool:Activate() end)
        
        -- Hit oficial
        if hitRemote then
            pcall(function() hitRemote:FireServer(pos) end)
        end
        
        -- se for part quebrável sem humanoid, força o toque
        if not humAlvo then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2.5, 0))
            hrp.Velocity = Vector3.zero
            root.CanTouch = true
        end
        task.wait(0.08)
    end
end

local function getNearestIsland(allPumpkins)
    local hrp = getHRP()
    if not hrp then return {} end
    -- acha a abobora mais proxima de todas e pega o cluster dela
    local nearest, nearestDist = nil, math.huge
    for _, p in ipairs(allPumpkins) do
        local r = getRoot(p)
        if r then
            local d = (r.Position - hrp.Position).Magnitude
            if d < nearestDist then nearestDist = d; nearest = p end
        end
    end
    if not nearest then return {} end
    local center = getRoot(nearest).Position
    local island = {}
    for _, p in ipairs(allPumpkins) do
        local r = getRoot(p)
        if r and (r.Position - center).Magnitude < ISLAND_RADIUS then
            table.insert(island, p)
        end
    end
    -- ordena as dessa ilha pelas mais perto
    table.sort(island, function(a,b)
        return (getRoot(a).Position - hrp.Position).Magnitude < (getRoot(b).Position - hrp.Position).Magnitude
    end)
    return island
end

local function mainLoop()
    while Farming do
        local all = findPumpkins()
        local btn = getgenv().PumpBtn
        if #all == 0 then
            if btn then btn.Text = "FARMER: ON (0)" end
            task.wait(1)
        else
            -- CRITICO: a cada volta ele escolhe de novo a ilha mais perto DO JOGADOR
            local island = getNearestIsland(all)
            if #island == 0 then island = all end

            if btn then btn.Text = string.format("ILHA ATUAL: %d aboboras", #island) end
            print("FARM na ilha atual:", #island, "aboboras")

            -- termina TODAS dessa ilha antes de recalcular proxima
            for _, p in ipairs(island) do
                if not Farming then break end
                pcall(attackPumpkin, p)
                task.wait(0.05)
            end
            -- terminou a ilha -> loop volta e pega a proxima mais perto automaticamente
        end
        task.wait(0.3)
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

print("[V4] Liga com E - com espada equipada!")
