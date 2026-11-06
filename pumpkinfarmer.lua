--//====================================================\\
--|| Blox Fruits Sea 1 - Halloween Pumpkin Auto Farm      ||--
--|| Executor: Synapse / KRNL / Fluxus compatible        ||--
--|| FIX: agora ATACA a pumpkin (M1 + Tool:Activate)     ||--
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

    UseNameFallback = true, -- also accepts names containing "pumpkin"

    TweenSpeed = 150, -- studs per second
    CollectDelay = 0.3,
    ToggleKey = Enum.KeyCode.Insert,

    -- ATTACK
    AttackDelay = 0.08, -- delay between clicks. 0.05 ~ 0.1 is good
    AttackTimeout = 8, -- max seconds attacking the same pumpkin
    AttackDistance = 3, -- studs away from the pumpkin while attacking
    UseCommFAttack = false, -- Blox Fruits remote attack (experimental, keep false if kick/error)

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

--====================================================\\
--|| WEAPON / ATTACK                                     ||--
--====================================================\\
local function getEquippedTool()
    local humanoid = getHumanoid()
    if humanoid and humanoid.EquippedTool then
        return humanoid.EquippedTool
    end
    local character = LocalPlayer.Character
    if not character then return nil end
    for _, item in ipairs(character:GetChildren()) do
        if item:IsA("Tool") then return item end
    end
    return nil
end

local function equipWeapon()
    local humanoid = getHumanoid()
    if not humanoid then return nil end
    local equipped = getEquippedTool()
    if equipped then return equipped end

    local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item:IsA("Tool") then
                humanoid:EquipTool(item)
                task.wait(0.1)
                return item
            end
        end
    end
    return nil
end

local function sendMouseClick()
    -- Synapse / KRNL / Fluxus executor function
    if type(mouse1click) == "function" then
        pcall(mouse1click)
    end

    -- Roblox VirtualInputManager (modern)
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
    end)
end

local function tryCommFAttack(pumpkin)
    if not Config.UseCommFAttack then return end
    local hrp = getHRP()
    if not hrp then return end
    local remotes = ReplicatedStorage:FindFirstChild("Remotes")
    local commf = remotes and remotes:FindFirstChild("CommF_")
    if not commf then return end

    local cf = hrp.CFrame
    local hitbox = {
        cf.X, cf.Y, cf.Z,
        cf.LookVector.X, cf.LookVector.Y, cf.LookVector.Z,
        cf.RightVector.X, cf.RightVector.Y, cf.RightVector.Z,
    }
    pcall(function()
        commf:InvokeServer("Attack", pumpkin, hitbox)
    end)
end

local function tryExecutorTouch(pumpkin)
    local hrp = getHRP()
    local part = getTargetPart(pumpkin)
    if not hrp or not part then return end

    -- ClickDetector (pumpkin may be collected by clicking)
    if type(fireclickdetector) == "function" then
        for _, obj in ipairs(pumpkin:GetDescendants()) do
            if obj:IsA("ClickDetector") then
                pcall(fireclickdetector, obj)
            end
        end
        if pumpkin:IsA("BasePart") then
            local cd = pumpkin:FindFirstChildOfClass("ClickDetector")
            if cd then pcall(fireclickdetector, cd) end
        end
    end

    -- ProximityPrompt
    if type(fireproximityprompt) == "function" then
        for _, obj in ipairs(pumpkin:GetDescendants()) do
            if obj:IsA("ProximityPrompt") then
                pcall(fireproximityprompt, obj, 10, 0)
            end
        end
    end

    -- Touch (teleporting HRP onto the part)
    if type(firetouchinterest) == "function" then
        pcall(firetouchinterest, hrp, part, 0)
        task.wait(0.05)
        pcall(firetouchinterest, hrp, part, 1)
    end
end

-- GUI forward declare (defined later, used by updateStats)
local statusLabel, collectedLabel, distanceLabel, hitsLabel

local function updateStats(statusText)
    if collectedLabel then collectedLabel.Text = string.format("Collected: %d", Collected) end
    if distanceLabel then distanceLabel.Text = string.format("Distance: %s studs", string.format("%.0f", TotalDistance)) end
    if hitsLabel then hitsLabel.Text = string.format("Hits: %d", Attacks) end
    if statusLabel then
        statusLabel.Text = statusText or (Farming and "Status: Farming..." or "Status: Idle")
    end
end

local function attackPumpkin(pumpkin)
    if not pumpkin or not pumpkin.Parent then return false end

    local tool = equipWeapon()
    local humanoid = getPumpkinHumanoid(pumpkin)
    local hasHumanoid = humanoid ~= nil

    -- If it has ClickDetector / Prompt, try that first (fast collect)
    tryExecutorTouch(pumpkin)
    task.wait(0.2)
    if not pumpkin.Parent then return true end

    local maxTime = hasHumanoid and Config.AttackTimeout or 1.5
    local startTime = os.clock()

    while Farming and pumpkin.Parent and (os.clock() - startTime) < maxTime do
        local targetCFrame = getPumpkinCFrame(pumpkin)
        local hrp = getHRP()
        if not targetCFrame or not hrp then break end

        local targetPos = targetCFrame.Position
        local attackPos = targetPos + Vector3.new(0, 0, Config.AttackDistance)

        -- Stay close and face the pumpkin (required for M1 hit in Blox Fruits)
        hrp.Anchored = true
        setNoclip(true)
        hrp.CFrame = CFrame.lookAt(attackPos, targetPos)

        -- ATTACK: M1 click + weapon activate
        sendMouseClick()
        tool = getEquippedTool() or tool
        if tool then
            pcall(function() tool:Activate() end)
        end
        tryCommFAttack(pumpkin)

        Attacks += 1
        updateStats("Status: Attacking pumpkin...")

        task.wait(Config.AttackDelay)

        local pumpkinHumanoid = getPumpkinHumanoid(pumpkin)
        if pumpkinHumanoid and pumpkinHumanoid.Health <= 0 then break end
        if not pumpkin.Parent then break end
    end

    local hrp = getHRP()
    if hrp then hrp.Anchored = false end
    setNoclip(false)

    -- Final fallback: touch / click detector / prompt
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
--|| TWEEN                                               ||--
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

    CurrentTween = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })

    local wasAnchored = hrp.Anchored
    hrp.Anchored = true
    setNoclip(true)

    CurrentTween:Play()
    CurrentTween.Completed:Wait()

    CurrentTween = nil
    setNoclip(false)
    hrp.Anchored = wasAnchored

    return Farming
end

local function farmOnePumpkin(pumpkin)
    local pumpkinCFrame = getPumpkinCFrame(pumpkin)
    if not pumpkinCFrame then return false end

    -- 1. Tween to above the pumpkin
    local ok = tweenTo(pumpkinCFrame + Vector3.new(0, 4, 0))
    if not ok or not Farming or not pumpkin.Parent then return false end

    -- 2. Attack it (this is the fix: before it only teleported)
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
print("[PumpkinFarm] Loaded. Press Insert to toggle GUI.")
