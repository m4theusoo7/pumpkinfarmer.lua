--//====================================================\\
--|| Blox Fruits Sea 1 - Halloween Pumpkin Auto Farm      ||--
--|| Executor: Synapse / KRNL / Fluxus compatible        ||--
--|| FIX v3: Hits travado em 0 / nao atacava             ||--
--\\====================================================//


--====================================================\\
--|| CONFIG - EDIT HERE                                  ||--
--====================================================\\
local Config = {
    PumpkinNames = {
        "Pumpkin",
        "Halloween Pumpkin",
        "HalloweenPumpkin",
    },

    UseNameFallback = true,
    Debug = true, -- prints pumpkin info in console (F9). Turn off after it works

    TweenSpeed = 150,
    CollectDelay = 0.3,
    ToggleKey = Enum.KeyCode.Insert,

    -- ATTACK
    AttackDelay = 0.1,
    AttackTimeout = 8,
    AttackDistance = 3,
    UseCommFAttack = true, -- FIX: Blox Fruits FastAttack remote ON by default

    AntiAFK = true,
}

--====================================================\\
--|| SERVICES                                            ||--
--====================================================\\
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer

--====================================================\\
--|| STATE                                               ||--
--====================================================\\
local Farming = false
local FarmRunning = false
local Collected = 0
local TotalDistance = 0
local Attacks = 0
local CurrentTween = nil
local DebugPrinted = {}

--====================================================\\
--|| HELPERS                                             ||--
--====================================================\\
local function getHRP()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Humanoid")
end

local function isPumpkinName(name)
    for _, pumpkinName in ipairs(Config.PumpkinNames) do
        if name == pumpkinName then return true end
    end
    return false
end

local function getPumpkins()
    local found = {}
    local seen = {}

    for _, obj in ipairs(Workspace:GetDescendants()) do
        if not seen[obj] then
            if isPumpkinName(obj.Name) then
                seen[obj] = true
                table.insert(found, obj)
            elseif Config.UseNameFallback and string.find(string.lower(obj.Name), "pumpkin", 1, true) then
                if obj:IsA("BasePart") or obj:IsA("Model") then
                    seen[obj] = true
                    table.insert(found, obj)
                end
            end
        end
    end

    return found
end

local function getPumpkinCFrame(pumpkin)
    if not pumpkin or not pumpkin.Parent then return nil end
    if pumpkin:IsA("BasePart") then return pumpkin.CFrame end
    if pumpkin:IsA("Model") then
        if pumpkin.PrimaryPart then return pumpkin.PrimaryPart.CFrame end
        local part = pumpkin:FindFirstChildWhichIsA("BasePart", true)
        if part then return part.CFrame end
        local ok, boundingBox = pcall(function() return pumpkin:GetBoundingBox() end)
        if ok and boundingBox then return boundingBox end
    end
    return nil
end

local function getTargetPart(pumpkin)
    if not pumpkin then return nil end
    if pumpkin:IsA("BasePart") then return pumpkin end
    if pumpkin:IsA("Model") then
        return pumpkin.PrimaryPart or pumpkin:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function getPumpkinHumanoid(pumpkin)
    if pumpkin and pumpkin:IsA("Model") then
        return pumpkin:FindFirstChildWhichIsA("Humanoid", true)
    end
    return nil
end

local function getNearestPumpkin()
    local hrp = getHRP()
    if not hrp then return nil end
    local nearest = nil
    local nearestDistance = math.huge
    for _, pumpkin in ipairs(getPumpkins()) do
        local pumpkinCFrame = getPumpkinCFrame(pumpkin)
        if pumpkinCFrame then
            local distance = (pumpkinCFrame.Position - hrp.Position).Magnitude
            if distance < nearestDistance then
                nearestDistance = distance
                nearest = pumpkin
            end
        end
    end
    return nearest
end

local function setNoclip(enabled)
    local character = LocalPlayer.Character
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = not enabled
        end
    end
end

local function debugPumpkin(pumpkin)
    if not Config.Debug or DebugPrinted[pumpkin] then return end
    DebugPrinted[pumpkin] = true
    local cdCount, promptCount, partCount = 0, 0, 0
    for _, obj in ipairs(pumpkin:GetDescendants()) do
        if obj:IsA("ClickDetector") then cdCount += 1 end
        if obj:IsA("ProximityPrompt") then promptCount += 1 end
        if obj:IsA("BasePart") then partCount += 1 end
    end
    print(string.format("[PumpkinFarm] %s | Class=%s Humanoid=%s Parts=%d ClickDetectors=%d Prompts=%d",
        pumpkin:GetFullName(), pumpkin.ClassName, tostring(getPumpkinHumanoid(pumpkin)), partCount, cdCount, promptCount))
end

-- GUI forward declare
local statusLabel, collectedLabel, distanceLabel, hitsLabel

local function updateStats(statusText)
    if collectedLabel then collectedLabel.Text = string.format("Collected: %d", Collected) end
    if distanceLabel then distanceLabel.Text = string.format("Distance: %s studs", string.format("%.0f", TotalDistance)) end
    if hitsLabel then hitsLabel.Text = string.format("Hits: %d", Attacks) end
    if statusLabel then
        statusLabel.Text = statusText or (Farming and "Status: Farming..." or "Status: Idle")
    end
end

--====================================================\\
--|| WEAPON / ATTACK                                     ||--
--====================================================\\
local function getEquippedTool()
    local humanoid = getHumanoid()
    if humanoid and humanoid.EquippedTool then return humanoid.EquippedTool end
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then return item end
    end
    return nil
end

-- FIX: EquipTool can yield forever. Never call it directly in the attack loop.
local function equipWeaponAsync()
    task.spawn(function()
        local humanoid = getHumanoid()
        if not humanoid then return end
        if humanoid.EquippedTool then return end
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if not backpack then return end
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                pcall(function() humanoid:EquipTool(item) end)
                break
            end
        end
    end)
end

-- FIX: click in the CENTER of the screen (where you aim), not in 0,0.
-- FIX: mouse1click removed - it hangs on KRNL/Fluxus and was blocking Hits.
local function sendMouseClickCenter()
    local camera = Workspace.CurrentCamera
    local center = camera and camera.ViewportSize * 0.5 or Vector2.new(960, 540)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 1)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 1)
    end)
end

local function cframeToHitbox(cf)
    return {
        cf.X, cf.Y, cf.Z,
        cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z,
        cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z,
        cf.UpVector.X, cf.UpVector.Y, cf.UpVector.Z,
    }
end

-- FIX: Blox Fruits FastAttack = CommF_ remote. This is the main damage method.
local function tryCommFAttack(pumpkin)
    if not Config.UseCommFAttack then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commf = remotes and remotes:FindFirstChild("CommF_")
    if not commf then return end

    local mobCF = getPumpkinCFrame(pumpkin)
    if not mobCF then return end

    pcall(function()
        commf:InvokeServer("Attack", pumpkin, cframeToHitbox(mobCF))
    end)
end

-- FIX: executor touch/click/prompt helpers run in their own thread,
-- so a slow fireproximityprompt can never block the attack loop again.
local function tryExecutorTouch(pumpkin)
    task.spawn(function()
        local hrp = getHRP()
        local part = getTargetPart(pumpkin)
        if not hrp or not part or not pumpkin.Parent then return end

        if type(fireclickdetector) == "function" then
            for _, obj in ipairs(pumpkin:GetDescendants()) do
                if obj:IsA("ClickDetector") then pcall(fireclickdetector, obj) end
            end
        end

        if type(fireproximityprompt) == "function" then
            for _, obj in ipairs(pumpkin:GetDescendants()) do
                if obj:IsA("ProximityPrompt") then pcall(fireproximityprompt, obj, 10, 0) end
            end
        end

        if type(firetouchinterest) == "function" then
            pcall(firetouchinterest, hrp, part, 0)
            task.wait(0.05)
            pcall(firetouchinterest, hrp, part, 1)
        end
    end)
end

local function attackPumpkin(pumpkin)
    if not pumpkin or not pumpkin.Parent then return false end

    debugPumpkin(pumpkin)
    equipWeaponAsync()
    tryExecutorTouch(pumpkin)
    task.wait(0.2)
    if not pumpkin.Parent then return true end

    local hasHumanoid = getPumpkinHumanoid(pumpkin) ~= nil
    local maxTime = hasHumanoid and Config.AttackTimeout or 2
    local startTime = os.clock()
    local hitCount = 0

    while Farming and pumpkin.Parent and (os.clock() - startTime) < maxTime do
        local targetCFrame = getPumpkinCFrame(pumpkin)
        local hrp = getHRP()
        if not targetCFrame or not hrp then break end

        -- FIX: count the hit FIRST, so Hits can never stay at 0 while attacking
        Attacks += 1
        hitCount += 1
        updateStats("Status: Attacking pumpkin...")

        local targetPos = targetCFrame.Position

        -- FIX: stay on the SAME side you approached from (not always +Z through walls)
        local dir = hrp.Position - targetPos
        dir = Vector3.new(dir.X, 0, dir.Z)
        if dir.Magnitude < 0.5 then
            local camera = Workspace.CurrentCamera
            local look = camera and camera.CFrame.LookVector or Vector3.new(0, 0, 1)
            dir = Vector3.new(look.X, 0, look.Z)
            if dir.Magnitude < 0.5 then dir = Vector3.new(0, 0, 1) end
        end
        local attackPos = targetPos + dir.Unit * Config.AttackDistance

        hrp.Anchored = true
        setNoclip(true)
        hrp.CFrame = CFrame.lookAt(attackPos, targetPos)

        -- 1. Blox Fruits remote damage (main method)
        tryCommFAttack(pumpkin)

        -- 2. M1 click at screen center (in a thread, cannot block the loop)
        task.spawn(sendMouseClickCenter)

        -- 3. Weapon activate occasionally (in a thread too)
        if hitCount % 3 == 0 then
            task.spawn(function()
                local tool = getEquippedTool()
                if tool then pcall(function() tool:Activate() end) end
            end)
        end

        -- 4. Re-try prompt / click / touch every ~1s for collectable pumpkins
        if hitCount % 10 == 0 then
            tryExecutorTouch(pumpkin)
        end

        task.wait(Config.AttackDelay)

        local pumpkinHumanoid = getPumpkinHumanoid(pumpkin)
        if pumpkinHumanoid and pumpkinHumanoid.Health <= 0 then break end
        if not pumpkin.Parent then break end
    end

    local hrp = getHRP()
    if hrp then hrp.Anchored = false end
    setNoclip(false)

    if Farming and pumpkin.Parent then
        tryExecutorTouch(pumpkin)
        task.wait(0.2)
    end

    if not pumpkin.Parent then return true end
    local pumpkinHumanoid = getPumpkinHumanoid(pumpkin)
    if pumpkinHumanoid and pumpkinHumanoid.Health <= 0 then return true end
    return false
end

--====================================================\\
--|| TWEEN (with timeout, Completed:Wait can hang)       ||--
--====================================================\\
local function tweenTo(targetCFrame)
    local hrp = getHRP()
    if not hrp or not targetCFrame then return false end

    local distance = (targetCFrame.Position - hrp.Position).Magnitude
    if distance < 3 then
        hrp.CFrame = targetCFrame
        return true
    end

    TotalDistance += distance
    updateStats()

    local tweenTime = math.max(distance / Config.TweenSpeed, 0.1)
    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })
    CurrentTween = tween

    local finished = false
    tween.Completed:Connect(function() finished = true end)

    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    setNoclip(true)

    tween:Play()

    local start = os.clock()
    while not finished and Farming and (os.clock() - start) < tweenTime + 1.5 do
        task.wait()
    end
    if not finished then
        pcall(function() tween:Cancel() end)
    end

    CurrentTween = nil
    setNoclip(false)
    hrp.Anchored = wasAnchored

    return Farming
end

local function farmOnePumpkin(pumpkin)
    local pumpkinCFrame = getPumpkinCFrame(pumpkin)
    if not pumpkinCFrame then return false end

    local ok = tweenTo(pumpkinCFrame + Vector3.new(0, 4, 0))
    if not ok or not Farming or not pumpkin.Parent then return false end

    updateStats("Status: Attacking pumpkin...")
    local killed = attackPumpkin(pumpkin)

    if killed then
        Collected += 1
        updateStats("Status: Farming... (collected!)")
        task.wait(Config.CollectDelay)
        return true
    end

    return false
end

--====================================================\\
--|| FARM LOOP                                           ||--
--====================================================\\
local function farmLoop()
    if FarmRunning then return end
    FarmRunning = true

    while Farming do
        local hrp = getHRP()
        if not hrp then
            updateStats("Status: Waiting for character...")
            task.wait(0.5)
        else
            local pumpkin = getNearestPumpkin()
            if not pumpkin then
                updateStats("Status: No pumpkin found, waiting...")
                task.wait(1)
            else
                local ok, err = pcall(farmOnePumpkin, pumpkin)
                if not ok then
                    warn("[PumpkinFarm] Error:", err)
                    task.wait(0.5)
                end
            end
        end
        task.wait(0.1)
    end

    FarmRunning = false
end

--====================================================\\
--|| GUI                                                 ||--
--====================================================\\
local gui

local function getGuiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    local ok, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if ok and coreGui then return coreGui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function createGui()
    gui = Instance.new("ScreenGui")
    gui.Name = "PumpkinFarmGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 10
    gui.Parent = getGuiParent()

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Size = UDim2.new(0, 270, 0, 215)
    mainFrame.Position = UDim2.new(0.5, -135, 0.5, -107)
    mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = gui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 10)
    mainCorner.Parent = mainFrame

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = Color3.fromRGB(255, 140, 0)
    mainStroke.Thickness = 2
    mainStroke.Parent = mainFrame

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Size = UDim2.new(1, 0, 0, 36)
    titleLabel.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
    titleLabel.Text = "Halloween Pumpkin Farm"
    titleLabel.TextColor3 = Color3.fromRGB(255, 170, 60)
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextSize = 15
    titleLabel.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = titleLabel

    statusLabel = Instance.new("TextLabel")
    statusLabel.Size = UDim2.new(1, -20, 0, 24)
    statusLabel.Position = UDim2.new(0, 10, 0, 46)
    statusLabel.BackgroundTransparency = 1
    statusLabel.Text = "Status: Idle"
    statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 14
    statusLabel.Parent = mainFrame

    collectedLabel = Instance.new("TextLabel")
    collectedLabel.Size = UDim2.new(1, -20, 0, 24)
    collectedLabel.Position = UDim2.new(0, 10, 0, 72)
    collectedLabel.BackgroundTransparency = 1
    collectedLabel.Text = "Collected: 0"
    collectedLabel.TextColor3 = Color3.fromRGB(180, 255, 180)
    collectedLabel.Font = Enum.Font.Gotham
    collectedLabel.TextSize = 14
    collectedLabel.Parent = mainFrame

    distanceLabel = Instance.new("TextLabel")
    distanceLabel.Size = UDim2.new(1, -20, 0, 24)
    distanceLabel.Position = UDim2.new(0, 10, 0, 98)
    distanceLabel.BackgroundTransparency = 1
    distanceLabel.Text = "Distance: 0 studs"
    distanceLabel.TextColor3 = Color3.fromRGB(150, 200, 255)
    distanceLabel.Font = Enum.Font.Gotham
    distanceLabel.TextSize = 14
    distanceLabel.Parent = mainFrame

    hitsLabel = Instance.new("TextLabel")
    hitsLabel.Size = UDim2.new(1, -20, 0, 24)
    hitsLabel.Position = UDim2.new(0, 10, 0, 124)
    hitsLabel.BackgroundTransparency = 1
    hitsLabel.Text = "Hits: 0"
    hitsLabel.TextColor3 = Color3.fromRGB(255, 200, 120)
    hitsLabel.Font = Enum.Font.Gotham
    hitsLabel.TextSize = 14
    hitsLabel.Parent = mainFrame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, -20, 0, 40)
    toggleButton.Position = UDim2.new(0, 10, 0, 156)
    toggleButton.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
    toggleButton.Text = "START FARM"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.GothamBold
    toggleButton.TextSize = 16
    toggleButton.AutoButtonColor = true
    toggleButton.Parent = mainFrame

    local buttonCorner = Instance.new("UICorner")
    buttonCorner.CornerRadius = UDim.new(0, 8)
    buttonCorner.Parent = toggleButton

    local dragging = false
    local dragStart
    local frameStart

    titleLabel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            mainFrame.Position = UDim2.new(frameStart.X.Scale, frameStart.X.Offset + delta.X, frameStart.Y.Scale, frameStart.Y.Offset + delta.Y)
        end
    end)

    toggleButton.MouseButton1Click:Connect(function()
        Farming = not Farming
        if Farming then
            toggleButton.Text = "STOP FARM"
            toggleButton.BackgroundColor3 = Color3.fromRGB(50, 170, 80)
            updateStats("Status: Farming...")
            task.spawn(farmLoop)
        else
            toggleButton.Text = "START FARM"
            toggleButton.BackgroundColor3 = Color3.fromRGB(170, 50, 50)
            updateStats("Status: Idle")
            if CurrentTween then CurrentTween:Cancel() CurrentTween = nil end
            local hrp = getHRP()
            if hrp then hrp.Anchored = false end
            setNoclip(false)
        end
    end)

    updateStats()
end

--====================================================\\
--|| ANTI-AFK                                            ||--
--====================================================\\
if Config.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)

    task.spawn(function()
        while true do
            task.wait(60)
            if Config.AntiAFK then
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end
        end
    end)
end

--====================================================\\
--|| KEYBIND + INIT                                     ||--
--====================================================\\
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleKey and gui then
        gui.Enabled = not gui.Enabled
    end
end)

createGui()
updateStats("Status: Idle - press START FARM")
print("[PumpkinFarm] Loaded. Press Insert to toggle GUI. Check F9 console for pumpkin debug info.")
