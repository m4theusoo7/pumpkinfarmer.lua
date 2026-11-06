-- JACK O' LANTERN / PUMPKIN FARM / V10 FINAL
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Hit = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Hit")

local FARM = {
    IslandRadius = 1500,
    FlySpeed = 500,
    HitDistance = 5,
    AttackDelay = 0.08,
    Toggle = Enum.KeyCode.E,
}

local Farming = false

local function hrp() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function hum() return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end

local function getTool()
    local char = player.Character
    local h = hum()
    if not char or not h then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    if tool then return tool end
    local bp = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
    if bp then bp.Parent = char h:EquipTool(bp) end
    return bp
end

-- So conta Jack o' Lantern vivo. Sem contar partes de PumpkinHunt, sem GetDescendants.
local function scan()
    local list = {}
    local enemies = workspace:FindFirstChild("Enemies")
    if not enemies then return list end
    for _, m in ipairs(enemies:GetChildren()) do
        if m:IsA("Model") and m.Name == "Jack o' Lantern" then
            local h = m:FindFirstChildOfClass("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if h and h.Health > 0 and r then
                table.insert(list, {Model = m, Hum = h, Root = r})
            end
        end
    end
    return list
end

-- Voo suave ancorado: nunca cai debaixo da ilha
local function flyTo(pos)
    local h = hrp()
    if not h then return end
    local dist = (h.Position - pos).Magnitude
    if dist < FARM.HitDistance then return end
    local target = CFrame.lookAt(pos + Vector3.new(0, 3, 0), pos)
    local tween = TweenService:Create(h, TweenInfo.new(math.max(dist/FARM.FlySpeed, 0.1), Enum.EasingStyle.Linear), {CFrame = target})
    h.Anchored = true
    tween:Play()
    tween.Completed:Wait()
    h.Anchored = false
end

-- Teleporta na abóbora e ataca até quebrar
local function kill(target)
    local model, hHum = target.Model, target.Hum
    local tool = getTool()
    if not tool then return end

    local h = hrp()
    if not h then return end

    flyTo(target.Root.Position)
    task.wait(0.05)

    local start = os.clock()
    while Farming and model.Parent and hHum.Health > 0 do
        if os.clock() - start > 10 then break end
        local root = model:FindFirstChild("HumanoidRootPart")
        if not root or not h then break end

        -- reposiciona a cada golpe para não errar
        h.CFrame = CFrame.lookAt(root.Position + Vector3.new(0, 3, 0), root.Position)
        h.Velocity = Vector3.zero

        tool:Activate()
        if Hit then pcall(function() Hit:FireServer(root.Position) end) end

        task.wait(FARM.AttackDelay)
    end
end

-- Ilha atual primeiro, depois a mais próxima
local function islandTargets(all)
    local h = hrp()
    if not h then return {} end
    local near = {}
    for _, t in ipairs(all) do
        if (t.Root.Position - h.Position).Magnitude < FARM.IslandRadius then
            table.insert(near, t)
        end
    end
    if #near > 0 then return near end

    table.sort(all, function(a,b) return (a.Root.Position - h.Position).Magnitude < (b.Root.Position - h.Position).Magnitude end)
    if #all == 0 then return {} end
    local center = all[1].Root.Position
    local out = {}
    for _, t in ipairs(all) do
        if (t.Root.Position - center).Magnitude < FARM.IslandRadius then table.insert(out, t) end
    end
    return out
end

local function main()
    while Farming do
        local all = scan()
        if #all == 0 then task.wait(0.5)
        else
            for _, t in ipairs(islandTargets(all)) do
                if not Farming then break end
                kill(t)
                task.wait(0.05)
            end
            task.wait(0.2)
        end
    end
end

UIS.InputBegan:Connect(function(i,g)
    if g or i.KeyCode ~= FARM.Toggle then return end
    Farming = not Farming
    print("[Jack Farm] Farming:", Farming)
    if Farming then task.spawn(main) end
end)

RunService.Stepped:Connect(function()
    if not Farming then return end
    local h = hrp()
    if h then
        h.CanCollide = false
        for _, p in ipairs(player.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end
    end
end)

print("[Jack Farm] Pronto. Aperta E com a arma no 1.")
