-- PUMPKIN FARMER V6 - COORDENADO E RÁPIDO
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Farming = false
local ISLAND_RADIUS = 1500 -- 1500 studs = mesma ilha
local FLY_SPEED = 450 -- velocidade do voo entre ilhas
local WALK_SPEED = 150 -- velocidade dentro da ilha

local KEYWORDS = {"pumpkin", "abobora", "pumpk"}
local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Hit")

local function getHRP() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function getHum() return player.Character and player.Character:FindFirstChild("Humanoid") end
local function isPumpkin(o) local n=string.lower(o.Name) for _,k in ipairs(KEYWORDS) do if string.find(n,k) then return true end end return false end
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
    local bp = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
    if bp then bp.Parent = char hum:EquipTool(bp) return bp end
    return nil
end

-- VOO SUAVE - sem piscar entre ilhas
local function flyTo(targetPos, speed)
    speed = speed or FLY_SPEED
    local hrp = getHRP()
    if not hrp then return end
    pcall(function() hrp:SetNetworkOwner(player) end)
    while Farming and hrp and hrp.Parent do
        local cur = hrp.Position
        local dist = (targetPos - cur).Magnitude
        if dist < 3 then break end
        local dt = RunService.Heartbeat:Wait()
        local step = math.min(dist, speed * dt)
        local newPos = cur + (targetPos - cur).Unit * step
        -- mantém 3 studs acima do chão e olhando para frente
        hrp.CFrame = CFrame.lookAt(newPos + Vector3.new(0, 3, 0), targetPos)
        hrp.Velocity = Vector3.zero
    end
end

-- ATACA ATÉ QUEBRAR (rápido)
local function attackUntilBreak(pumpkin)
    local start = os.clock()
    while Farming and pumpkin and pumpkin.Parent do
        local humAlvo = pumpkin:FindFirstChildOfClass("Humanoid", true)
        if humAlvo and humAlvo.Health <= 0 then break end
        if os.clock() - start > 8 then break end -- timeout de segurança

        local hrp = getHRP()
        local root = getRoot(pumpkin)
        if not hrp or not root then break end

        local pos = root.Position
        -- fica do lado a 4 studs, olhando pra ela
        local dir = (hrp.Position - pos)
        if dir.Magnitude < 0.1 then dir = Vector3.new(0,0,1) end
        local sidePos = pos + dir.Unit * 4 + Vector3.new(0, 3, 0)

        -- se estiver longe, voa até perto, se já estiver perto, só reposiciona
        if (hrp.Position - sidePos).Magnitude > 8 then
            flyTo(sidePos, 350)
        else
            hrp.CFrame = CFrame.lookAt(sidePos, pos)
            hrp.Velocity = Vector3.zero
        end
        task.wait(0.02)

        -- SPAM DE DANO - 3 métodos ao mesmo tempo para quebrar rápido
        local tool = equipWeapon()
        if tool then pcall(function() tool:Activate() end) end
        if hitRemote then pcall(function() hitRemote:FireServer(pos) end) end

        -- se for part sem Humanoid, toca nele
        if not humAlvo then
            hrp.CFrame = CFrame.new(pos + Vector3.new(0, 2, 0))
        end

        task.wait(0.05)
    end
end

-- PEGA SÓ AS DA ILHA ATUAL (coordenado)
local function pickCurrentIsland(all)
    local hrp = getHRP() if not hrp then return {} end
    -- 1. tenta pegar as que já estão perto do jogador (ilha atual)
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
    -- 2. se nenhuma perto, pega a abóbora mais próxima e o cluster dela = próxima ilha
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
            if btn then btn.Text = "FARMER: ON (0)" end
            task.wait(1)
        else
            local island = pickCurrentIsland(all)
            if btn then btn.Text = string.format("ILHA: %d/%d", #island, #all) end
            print(string.format("Farme coordenado: %d abóboras nesta ilha", #island))

            -- TERMINA TODAS DA ILHA ATUAL PRIMEIRO
            for _, p in ipairs(island) do
                if not Farming then break end
                pcall(attackUntilBreak, p)
                task.wait(0.05)
            end
            -- terminou a ilha -> loop volta e pega automaticamente a próxima mais perto
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
            hrp.Velocity = Vector3.zero
        end
    end
end)

print("[V6] Liga com E - com espada no 1!")
