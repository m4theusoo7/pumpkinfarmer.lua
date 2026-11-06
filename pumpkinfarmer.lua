-- JACK O' LANTERN / PUMPKIN FARM / V12 FINAL
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local VirtualInputManager = game:GetService("VirtualInputManager")

local player = Players.LocalPlayer
local Hit = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Hit")

local IslandRadius = 1800
local Farming = false
local Running = false
local lastToggle = 0

local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function getHum()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function getTool()
    local c = player.Character
    local h = getHum()
    if not c or not h then return nil end
    local t = c:FindFirstChildOfClass("Tool")
    if t then return t end
    local bp = player.Backpack:FindFirstChildOfClass("Tool")
    if bp then bp.Parent = c h:EquipTool(bp) end
    return bp
end

local function scan()
    local list = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return list end
    for _, m in ipairs(enemies:GetChildren()) do
        if m:IsA("Model") and m.Name == "Jack o' Lantern" then
            local h = m:FindFirstChildOfClass("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if h and r and h.Health > 0 then
                table.insert(list, {Model = m, Hum = h, Root = r})
            end
        end
    end
    return list
end

local function flyTo(pos)
    local h = getHRP()
    if not h then return end
    local dist = (h.Position - pos).Magnitude
    if dist < 6 then return end
    local target = CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos)
    local time = math.max(dist / 600, 0.15)
    h.Anchored = true
    local tw = TweenService:Create(h, TweenInfo.new(time, Enum.EasingStyle.Linear), {CFrame = target})
    tw:Play()
    tw.Completed:Wait()
    h.Anchored = false
end

local function attackUntilBreak(t)
    local tool = getTool()
    local myHRP = getHRP()
    if not tool or not myHRP then return end

    -- 1. teleporta primeiro
    flyTo(t.Root.Position)
    task.wait(0.05)

    -- 2. ataca até quebrar
    local start = os.clock()
    while Farming and t.Model.Parent and t.Hum.Health > 0 do
        if os.clock() - start > 10 then break end
        local root = t.Model:FindFirstChild("HumanoidRootPart")
        if not root then break end
        local h = getHRP()
        if not h then break end

        h.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 3, 0), root.Position)
        h.Velocity = Vector3.zero

        -- M1 + remote
        pcall(function() tool:Activate() end)
        VirtualInputManager:SendMouseButtonEvent(0,0,0,true, game, 1)
        task.wait(0.03)
        VirtualInputManager:SendMouseButtonEvent(0,0,0,false, game, 1)
        if Hit then pcall(function() Hit:FireServer(root.Position) end) end

        task.wait(0.06)
    end
    if t.Hum.Health <= 0 then
        print("[Jack Farm] Quebrado!")
    end
end

local function getIsland(all)
    local h = getHRP()
    if not h then return {} end
    local cur = {}
    for _, t in ipairs(all) do
        if (t.Root.Position - h.Position).Magnitude < IslandRadius then
            table.insert(cur, t)
        end
    end
    if #cur > 0 then
        table.sort(cur, function(a,b) return (a.Root.Position - h.Position).Magnitude < (b.Root.Position - h.Position).Magnitude end)
        return cur
    end
    table.sort(all, function(a,b) return (a.Root.Position - h.Position).Magnitude < (b.Root.Position - h.Position).Magnitude end)
    if #all == 0 then return {} end
    local center = all[1].Root.Position
    local island = {}
    for _, t in ipairs(all) do
        if (t.Root.Position - center).Magnitude < IslandRadius then
            table.insert(island, t)
        end
    end
    return island
end

local function main()
    if Running then return end
    Running = true
    while Farming do
        local all = scan()
        if #all == 0 then
            print("[Jack Farm] Nenhum Jack vivo, esperando...")
            task.wait(1.5)
        else
            local ilha = getIsland(all)
            print(string.format("[Jack Farm] Ilha atual: %d abóboras (total %d)", #ilha, #all))
            for _, t in ipairs(ilha) do
                if not Farming then break end
                if t.Model.Parent and t.Hum.Health > 0 then
                    pcall(attackUntilBreak, t)
                end
                task.wait(0.05)
            end
        end
        task.wait(0.3)
    end
    Running = false
end

UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    if input.KeyCode ~= Enum.KeyCode.F and input.KeyCode ~= Enum.KeyCode.E then return end
    if os.clock() - lastToggle < 0.3 then return end
    lastToggle = os.clock()
    Farming = not Farming
    print("[Jack Farm V12] Farming:", Farming)
    if Farming then task.spawn(main) end
end)

-- NoClip enquanto farma
game:GetService("RunService").Stepped:Connect(function()
    if not Farming then return end
    local c = player.Character
    if not c then return end
    for _, p in ipairs(c:GetDescendants()) do
        if p:IsA("BasePart") then p.CanCollide = false end
    end
end)

print("[Jack Farm V12] Carregado! Aperta F ou E para iniciar.")
