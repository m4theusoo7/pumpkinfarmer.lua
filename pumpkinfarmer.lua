-- JACK O' LANTERN V11 - DETECTA F/E COM POLLING
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Hit = ReplicatedStorage:WaitForChild("Remotes"):FindFirstChild("Hit")

local ToggleKeys = {Enum.KeyCode.F, Enum.KeyCode.E}
local IslandRadius = 1500
local Farming = false
local lastToggle = 0

local function hrp() return player.Character and player.Character:FindFirstChild("HumanoidRootPart") end
local function hum() return player.Character and player.Character:FindFirstChildOfClass("Humanoid") end

local function getTool()
    local char = player.Character
    local h = hum()
    if not char or not h then return nil end
    local t = char:FindFirstChildOfClass("Tool")
    if t then return t end
    local bp = player.Backpack and player.Backpack:FindFirstChildOfClass("Tool")
    if bp then bp.Parent = char h:EquipTool(bp) end
    return bp
end

local function scan()
    local list = {}
    local e = workspace:FindFirstChild("Enemies")
    if not e then return list end
    for _, m in ipairs(e:GetChildren()) do
        if m:IsA("Model") and m.Name == "Jack o' Lantern" then
            local h = m:FindFirstChildOfClass("Humanoid")
            local r = m:FindFirstChild("HumanoidRootPart")
            if h and h.Health > 0 and r then table.insert(list, {M=m, H=h, R=r}) end
        end
    end
    return list
end

local function flyTo(pos)
    local h = hrp() if not h then return end
    if (h.Position - pos).Magnitude < 5 then return end
    local cf = CFrame.lookAt(pos + Vector3.new(0,3,0), pos)
    local tw = TweenService:Create(h, TweenInfo.new(math.max((h.Position-pos).Magnitude/500, 0.1), Enum.EasingStyle.Linear), {CFrame = cf})
    h.Anchored = true tw:Play() tw.Completed:Wait() h.Anchored = false
end

local function kill(t)
    local tool = getTool() if not tool then return end
    local h = hrp() if not h then return end
    flyTo(t.R.Position) task.wait(0.05)
    local start = os.clock()
    while Farming and t.M.Parent and t.H.Health > 0 do
        if os.clock() - start > 10 then break end
        local r = t.M:FindFirstChild("HumanoidRootPart") if not r then break end
        h.CFrame = CFrame.lookAt(r.Position + Vector3.new(0,3,0), r.Position)
        h.Velocity = Vector3.zero
        tool:Activate()
        if Hit then pcall(function() Hit:FireServer(r.Position) end) end
        task.wait(0.08)
    end
end

local function island(all)
    local h = hrp() if not h then return {} end
    local cur = {}
    for _, t in ipairs(all) do if (t.R.Position - h.Position).Magnitude < IslandRadius then table.insert(cur, t) end end
    if #cur > 0 then table.sort(cur, function(a,b) return (a.R.Position-h.Position).Magnitude < (b.R.Position-h.Position).Magnitude end) return cur end
    table.sort(all, function(a,b) return (a.R.Position-h.Position).Magnitude < (b.R.Position-h.Position).Magnitude end)
    if #all == 0 then return {} end
    local c = all[1].R.Position
    local out = {}
    for _, t in ipairs(all) do if (t.R.Position-c).Magnitude < IslandRadius then table.insert(out, t) end end
    return out
end

local function main()
    while Farming do
        local all = scan()
        if #all == 0 then task.wait(0.5)
        else for _, t in ipairs(island(all)) do if not Farming then break end kill(t) task.wait(0.05) end task.wait(0.2) end
    end
end

-- Polling por frame = sempre funciona, mesmo com o jogo focado
task.spawn(function()
    while true do
        task.wait()
        if os.clock() - lastToggle < 0.3 then continue end
        for _, k in ipairs(ToggleKeys) do
            if UIS:IsKeyDown(k) then
                lastToggle = os.clock()
                Farming = not Farming
                print("[Jack Farm V11] Tecla apertada, Farming:", Farming)
                if Farming then task.spawn(main) end
                break
            end
        end
    end
end)

-- Fallback InputBegan também
UIS.InputBegan:Connect(function(input, gpe)
    if gpe then return end
    for _, k in ipairs(ToggleKeys) do
        if input.KeyCode == k then
            Farming = not Farming
            print("[Jack Farm V11] InputBegan, Farming:", Farming)
            if Farming then task.spawn(main) end
            break
        end
    end
end)

RunService.Stepped:Connect(function()
    if not Farming then return end
    local h = hrp()
    if h then h.CanCollide = false for _, p in ipairs(player.Character:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false end end end
end)

print("[Jack Farm V11] Carregado! Aperta F ou E para iniciar.")
