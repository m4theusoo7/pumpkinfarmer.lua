--//====================================================\\
--|| Blox Fruits Sea 1 - Halloween Pumpkin Auto Farm      ||--
--|| Executor: Synapse / KRNL / Fluxus compatible        ||--
--|| TweenService + HRP CFrame collect, no deprecated \n wait() --||--
--\\====================================================//


--====================================================\\
--|| CONFIG - EDIT HERE                                  ||--
--====================================================\\
local Config = {
    -- Pumpkin model name in Workspace
    -- HOW TO FIND REAL NAME WITH DEX EXPLORER:
    -- 1. Open Dex Explorer in your executor
    -- 2. Go to Workspace and press Search / Find (Ctrl+F)
    -- 3. Search for: Pumpkin
    -- 4. Copy the EXACT Name of the model/Part you find
    -- 5. Paste it here inside PumpkinNames
    PumpkinNames = {
        "Pumpkin",
        "Halloween Pumpkin",
        "HalloweenPumpkin",
    },

    -- If no exact match is found, also search names containing "pumpkin"
    UseNameFallback = true,

    TweenSpeed = 150, -- Studs per second. Increase for faster teleport. 100 ~ 200 is safe. 300+ = risky.
    CollectDelay = 0.5, -- Seconds to stay on pumpkin before going to next
    ToggleKey = Enum.KeyCode.Insert, -- Press Insert to hide / show GUI
    AntiAFK = true,
}

--====================================================\\
--|| SERVICES (modern, non-deprecated)                   ||--
--====================================================\\
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local UserInputService = game:GetService("UserInputService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer

--====================================================\\
--|| STATE                                               ||--
--====================================================\\
local Farming = false
local FarmRunning = false
local Collected = 0
local TotalDistance = 0
local CurrentTween = nil

--====================================================\\
--|| HELPERS                                             ||--
--====================================================\\
local function getHRP()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart")
end

local function waitForHRP()
    local hrp = getHRP()
    while not hrp do
        LocalPlayer.CharacterAdded:Wait()
        hrp = getHRP()
        if not hrp then task.wait(0.1) end
    end
    return hrp
end

local function isPumpkinName(name)
    for _, pumpkinName in ipairs(Config.PumpkinNames) do
        if name == pumpkinName then
            return true
        end
    end
    return false
end

local function getPumpkins()
    local found = {}
    local seen = {}

    -- Search everything in Workspace, including folders and subfolders
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if not seen[obj] then
            if isPumpkinName(obj.Name) then
                seen[obj] = true
                table.insert(found, obj)
            elseif Config.UseNameFallback and string.find(string.lower(obj.Name), "pumpkin", 1, true) then
                -- Fallback: catches "HalloweenPumpkin", "Pumpkin_1", etc.
                -- Only accepts Models / BaseParts to avoid duplicate GUI / scripts
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

    if pumpkin:IsA("BasePart") then
        return pumpkin.CFrame
    end

    if pumpkin:IsA("Model") then
        if pumpkin.PrimaryPart then
            return pumpkin.PrimaryPart.CFrame
        end

        local part = pumpkin:FindFirstChildWhichIsA("BasePart", true)
        if part then
            return part.CFrame
        end

        local ok, boundingBox = pcall(function()
            return pumpkin:GetBoundingBox()
        end)
        if ok and boundingBox then
            return boundingBox
        end
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

--====================================================\\
--|| GUI                                                 ||--
--====================================================\\
local gui, statusLabel, collectedLabel, distanceLabel, toggleButton

local function updateStats(statusText)
    if collectedLabel then
        collectedLabel.Text = string.format("Collected: %d", Collected)
    end
    if distanceLabel then
        distanceLabel.Text = string.format("Distance: %s studs", string.format("%.0f", TotalDistance))
    end
    if statusLabel and statusText then
        statusLabel.Text = statusText
    elseif statusLabel then
        statusLabel.Text = Farming and "Status: Farming..." or "Status: Idle"
    end
end

local function getGuiParent()
    -- gethui() exists on Synapse / KRNL / Fluxus, hides GUI from Dex
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
    mainFrame.Size = UDim2.new(0, 270, 0, 190)
    mainFrame.Position = UDim2.new(0.5, -135, 0.5, -95)
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
    titleLabel.Name = "Title"
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

    toggleButton = Instance.new("TextButton")
    toggleButton.Size = UDim2.new(1, -20, 0, 40)
    toggleButton.Position = UDim2.new(0, 10, 0, 132)
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

    -- Draggable by title bar (works with mouse + touch)
    local dragging = false
    local dragStart
    local frameStart

    titleLabel.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            frameStart = mainFrame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
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
            if CurrentTween then
                CurrentTween:Cancel()
                CurrentTween = nil
            end
            local hrp = getHRP()
            if hrp then
                hrp.Anchored = false
            end
        end
    end)

    updateStats()
end

--====================================================\\
--|| ANTI-AFK                                            ||--
--====================================================\\
if Config.AntiAFK then
    LocalPlayer.Idled:Connect(function()
        -- Modern anti-AFK: simulate mouse click so server does not kick you
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
--|| TWEEN + COLLECT                                     ||--
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

    -- TweenSpeed = studs per second, so Time = Distance / Speed
    local tweenTime = math.max(distance / Config.TweenSpeed, 0.1)
    local tweenInfo = TweenInfo.new(tweenTime, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)

    CurrentTween = TweenService:Create(hrp, tweenInfo, { CFrame = targetCFrame })

    local wasAnchored = hrp.Anchored
    hrp.Anchored = true -- prevents physics / falling while tweening HRP

    CurrentTween:Play()
    CurrentTween.Completed:Wait()

    CurrentTween = nil
    hrp.Anchored = wasAnchored

    return Farming -- false if user turned farm OFF during tween
end

local function collectPumpkin(pumpkin)
    local hrp = getHRP()
    if not hrp or not pumpkin or not pumpkin.Parent then return false end

    local pumpkinCFrame = getPumpkinCFrame(pumpkin)
    if not pumpkinCFrame then return false end

    -- 1. Tween to just above the pumpkin
    local aboveCFrame = pumpkinCFrame + Vector3.new(0, 4, 0)
    local ok = tweenTo(aboveCFrame)
    if not ok or not Farming or not pumpkin.Parent then return false end

    -- 2. Direct CFrame teleport ON TOP of it to trigger touch / collect
    --    This is what most Blox Fruits pumpkin scripts use.
    local freshCFrame = getPumpkinCFrame(pumpkin)
    if not freshCFrame then return false end

    hrp.CFrame = freshCFrame
    task.wait(Config.CollectDelay)

    if pumpkin.Parent then
        Collected += 1
        updateStats("Status: Farming... (collected!)")
        return true
    end

    return false
end

--====================================================\\
--|| FARM LOOP: find -> teleport -> collect -> next      ||--
--====================================================\\
function farmLoop()
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
                local ok, err = pcall(collectPumpkin, pumpkin)
                if not ok then
                    warn("[PumpkinFarm] Error:", err)
                    task.wait(0.5)
                end
            end
        end

        task.wait(0.1) -- small yield so executor / game does not freeze
    end

    FarmRunning = false
end

--====================================================\\
--|| KEYBIND - Insert toggles GUI                         ||--
--====================================================\\
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Config.ToggleKey and gui then
        gui.Enabled = not gui.Enabled
    end
end)

--====================================================\\
--|| INIT                                                ||--
--====================================================\\
createGui()
updateStats("Status: Idle - press START FARM")
print("[PumpkinFarm] Loaded. Press Insert to toggle GUI.")
