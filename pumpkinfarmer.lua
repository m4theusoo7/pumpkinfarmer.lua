-- PUMPKIN FARMER V5 - ATACA ATÉ QUEBRAR
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local player = Players.LocalPlayer

local Farming = false
local ISLAND_RADIUS = 1500
local HIT_DISTANCE = 5

local KEYWORDS = {"pumpkin", "abobora", "pumpk"}
local hitRemote = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Hit")

local function getHRP() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function getHumChar() return player.Character and player.Character:FindFirstChild("Humanoid") end
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
    local hum = getHumChar()
    local char = player.Character
    if not hum or not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local bpTool = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
    if bpTool then bpTool.Parent = char hum:EquipTool(bpTool) return bpTool end
    return nil
end

local function getNearestIsland(all)
    local hrp = getHRP() if not hrp then return {} end
    local nearest, nd = nil, 999999
    for _,p in ipairs(all) do local r=getRoot(p) if r then local d=(r.Position-hrp.Position).Magnitude if d<nd then nd=d nearest=p end end end
    if not nearest then return {} end
    local center = getRoot(nearest).Position
    local island = {}
    for _,p in ipairs(all) do local r=getRoot(p) if r and (r.Position-center).Magnitude < ISLAND_RADIUS then table.insert(island,p) end end
    table.sort(island, function(a,b) return (getRoot(a).Position-hrp.Position).Magnitude < (getRoot(b).Position-hrp.Position).Magnitude end)
    return island
end

-- FUNÇÃO QUE VOCÊ PEDIU: ATACA ATÉ QUEBRAR
local function attackUntilBreak(pumpkin)
    local tool = equipWeapon()
    if not tool then warn("EQUIPA TUA ESPADA ANTES!") return end

    local startTime = os.clock()
    local hitsDone = 0

    while Farming do
        -- Verificações de saída: quebrou ou timeout
        if not pumpkin or not pumpkin.Parent then break end
        local humAlvo = pumpkin:FindFirstChildOfClass("Humanoid", true)
        if humAlvo and humAlvo.Health <= 0 then break end
        if os.clock() - startTime > 10 then
            warn("Não quebrou em 10s, pulando para próxima")
            break
        end

        local hrp = getHRP()
        local root = getRoot(pumpkin)
        if not hrp or not root then break end

        -- Fica do lado e olhando para ela
        local pos = root.Position
        local dir = (hrp.Position - pos)
        if dir.Magnitude < 0.1 then dir = Vector3.new(0,0,1) end
        local sidePos = pos + dir.Unit * HIT_DISTANCE + Vector3.new(0, 3, 0)

        hrp.CFrame = CFrame.lookAt(sidePos, pos)
        hrp.Velocity = Vector3.zero
        task.wait(0.02)

        -- Ataque M1
        tool = equipWeapon() or tool
        pcall(function() tool:Activate() end)
        
        -- clique virtual
        VirtualInputManager:SendMouseButtonEvent(0,0,0,true,game,1)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(0,0,0,false,game,1)

        -- remote oficial
        if hitRemote then pcall(function() hitRemote:FireServer(pos) end) end

        hitsDone += 1
        -- a cada 5 hits, reforça
        if hitsDone % 5 == 0 and humAlvo then
            -- só para empurrar caso o servidor não aceite o hit por lag
            -- pcall(function() humAlvo:TakeDamage(50) end)
        end

        task.wait(0.05)
    end
    if hitsDone > 0 then print("Abóbora quebrada após", hitsDone, "hits") end
end

local function mainLoop()
    while Farming do
        local all = findPumpkins()
        local btn = getgenv().PumpBtn
        if #all == 0 then
            if btn then btn.Text = "FARMER: ON (0)" end
            task.wait(1)
        else
            local island = getNearestIsland(all)
            if btn then btn.Text = string.format("ILHA ATUAL: %d aboboras", #island) end
            print("Iniciando ilha com", #island, "aboboras")

            for _, p in ipairs(island) do
                if not Farming then break end
                pcall(attackUntilBreak, p)
                task.wait(0.1)
            end
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
        if hrp then for _,p in ipairs(player.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide=false end end end
    end
end)

print("[V5] Liga com E - com espada equipada! Agora ataca até quebrar")
