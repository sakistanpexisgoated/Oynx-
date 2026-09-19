--[[
    Blade Ball Auto Parry - Balagan UI Build
    Detection: target attribute + zoomies.VectorVelocity
    Remote: ParryButtonPress
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer

-- ========== PLATFORM ==========
local Platform = "Unknown"
local IsMobile = false
local IsDesktop = false

pcall(function()
    local result = UserInputService:GetPlatform()
    if result == Enum.Platform.Windows then Platform = "Windows"; IsDesktop = true
    elseif result == Enum.Platform.OSX then Platform = "Mac"; IsDesktop = true
    elseif result == Enum.Platform.IOS then Platform = "iOS"; IsMobile = true
    elseif result == Enum.Platform.Android then Platform = "Android"; IsMobile = true
    end
end)

if Platform == "Unknown" then
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        Platform = "Mobile"; IsMobile = true
    else
        Platform = "Desktop"; IsDesktop = true
    end
end

-- ========== CONFIG ==========
local Config = {
    AutoParry = true,
    AutoSpam = false,
    AutoClash = false,
    BallESP = false,
    TargetESP = false,
    ParryWindow = 0.55,
    ParryCooldown = 0.12,
    SpamRate = 50,
    HumanizeDelay = true,
    HumanizeMin = 0.03,
    HumanizeMax = 0.10,
    EnableGUI = true,
    Debug = true,
}

local AntiKick = {
    MaxParryPerSecond = 6,
}

local parryConnection = nil
local spamConnection = nil
local espConnection = nil
local lastParryTime = 0
local parryCount = 0
local lastResetTime = tick()
local Parried = false
local espFolder = nil

local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local ParryButtonPress = Remotes:WaitForChild("ParryButtonPress", 9e9)

-- ========== HELPERS ==========
local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title,
            Text = text,
            Duration = duration or 2,
        })
    end)
end

local function GetBall()
    local ballsFolder = Workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") and ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

-- ========== PARRY ==========
local function ExecuteParry()
    if not Config.AutoParry then return end
    local now = tick()
    if now - lastParryTime < Config.ParryCooldown then return end

    if now - lastResetTime > 1 then
        parryCount = 0
        lastResetTime = now
    end
    if parryCount >= AntiKick.MaxParryPerSecond then return end

    lastParryTime = now
    parryCount = parryCount + 1

    if Config.HumanizeDelay then
        local delay = math.random() * (Config.HumanizeMax - Config.HumanizeMin) + Config.HumanizeMin
        task.wait(delay)
    end

    pcall(function()
        ParryButtonPress:Fire()
        if Config.Debug then print("[FAx] Parry fired") end
    end)
end

-- ========== SPAM ==========
local function StartSpam()
    if spamConnection then spamConnection:Disconnect() end
    if not Config.AutoSpam then return end
    spamConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoSpam then return end
        pcall(function() ParryButtonPress:Fire() end)
        task.wait(1 / Config.SpamRate)
    end)
end

-- ========== ESP ==========
local function StartESP()
    if espConnection then espConnection:Disconnect() end
    if espFolder then espFolder:Destroy() end
    if not (Config.BallESP or Config.TargetESP) then return end

    espFolder = Instance.new("Folder")
    espFolder.Name = "AutoParryESP"
    espFolder.Parent = Workspace

    espConnection = RunService.RenderStepped:Connect(function()
        for _, obj in ipairs(espFolder:GetChildren()) do
            obj:Destroy()
        end

        if Config.BallESP then
            local balls = Workspace:FindFirstChild("Balls")
            if balls then
                for _, ball in ipairs(balls:GetChildren()) do
                    if ball:IsA("BasePart") and ball:GetAttribute("realBall") then
                        local hl = Instance.new("Highlight")
                        hl.Adornee = ball
                        hl.FillColor = Color3.fromRGB(255, 50, 50)
                        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                        hl.FillTransparency = 0.5
                        hl.Parent = espFolder
                    end
                end
            end
        end

        if Config.TargetESP then
            local ball = GetBall()
            if ball and ball:GetAttribute("target") then
                local targetName = ball:GetAttribute("target")
                local targetPlayer = Players:FindFirstChild(targetName)
                if targetPlayer and targetPlayer.Character then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = targetPlayer.Character
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.6
                    hl.Parent = espFolder
                end
            end
        end
    end)
end

-- ========== MAIN PARRY LOOP ==========
local function StartParryLoop()
    if parryConnection then parryConnection:Disconnect() end

    Workspace.Balls.ChildAdded:Connect(function()
        local Ball = GetBall()
        if Ball then
            Ball:GetAttributeChangedSignal("target"):Connect(function()
                Parried = false
            end)
        end
    end)

    parryConnection = RunService.PreSimulation:Connect(function()
        if not Config.AutoParry then return end

        local Ball = GetBall()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not Ball or not hrp then return end

        local target = Ball:GetAttribute("target")
        if target ~= LocalPlayer.Name then return end

        local Zoomies = Ball:FindFirstChild("zoomies")
        if not Zoomies then return end

        local Speed = Zoomies.VectorVelocity.Magnitude
        if Speed < 1 then return end

        local Distance = (hrp.Position - Ball.Position).Magnitude
        local TimeToImpact = Distance / Speed

        if TimeToImpact <= Config.ParryWindow and TimeToImpact > 0 and not Parried then
            ExecuteParry()
            Parried = true
        end
    end)
end

-- ========== UI BUILD ==========
local function CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "R_" .. tostring(math.random(100000, 999999))
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true

    if gethui then pcall(function() screenGui.Parent = gethui() end) end
    if not screenGui.Parent then pcall(function() screenGui.Parent = CoreGui end) end
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    -- Colors
    local COL_BG = Color3.fromRGB(14, 14, 16)
    local COL_PANEL = Color3.fromRGB(20, 20, 24)
    local COL_SIDEBAR = Color3.fromRGB(16, 16, 19)
    local COL_STROKE = Color3.fromRGB(40, 40, 46)
    local COL_TEXT = Color3.fromRGB(230, 230, 235)
    local COL_MUTED = Color3.fromRGB(130, 130, 140)
    local COL_ACCENT = Color3.fromRGB(0, 170, 255)
    local COL_GREEN = Color3.fromRGB(50, 210, 120)
    local COL_RED = Color3.fromRGB(220, 60, 60)

    local W = IsMobile and 420 or 620
    local H = IsMobile and 260 or 360
    local SIDEBAR_W = 140
    local TOPBAR_H = 36

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, W, 0, H)
    main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    main.BackgroundColor3 = COL_BG
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = screenGui

    local mainCorner = Instance.new("UICorner")
    mainCorner.CornerRadius = UDim.new(0, 8)
    mainCorner.Parent = main

    local mainStroke = Instance.new("UIStroke")
    mainStroke.Color = COL_STROKE
    mainStroke.Thickness = 1
    mainStroke.Parent = main

    -- Top bar
    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
    topBar.BackgroundColor3 = COL_SIDEBAR
    topBar.BorderSizePixel = 0
    topBar.Parent = main

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 8)
    topCorner.Parent = topBar

    -- fix bottom corners of topbar
    local topFix = Instance.new("Frame")
    topFix.Size = UDim2.new(1, 0, 0, 8)
    topFix.Position = UDim2.new(0, 0, 1, -8)
    topFix.BackgroundColor3 = COL_SIDEBAR
    topFix.BorderSizePixel = 0
    topFix.Parent = topBar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -16, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "AutoParry  |  Blade Ball"
    title.TextColor3 = COL_TEXT
    title.TextSize = 13
    title.Font = Enum.Font.GothamMedium
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

    -- Minimize button
    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28)
    minBtn.Position = UDim2.new(1, -62, 0, 4)
    minBtn.BackgroundColor3 = COL_PANEL
    minBtn.Text = "—"
    minBtn.TextColor3 = COL_TEXT
    minBtn.TextSize = 14
    minBtn.Font = Enum.Font.GothamBold
    minBtn.BorderSizePixel = 0
    minBtn.Parent = topBar

    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 5)
    minCorner.Parent = minBtn

    -- Close button
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = COL_RED
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = topBar

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 5)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    -- Sidebar
    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H - 12)
    sidebar.Position = UDim2.new(0, 6, 0, TOPBAR_H + 6)
    sidebar.BackgroundColor3 = COL_SIDEBAR
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 6)
    sideCorner.Parent = sidebar

    -- Content area
    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -SIDEBAR_W - 18, 1, -TOPBAR_H - 12)
    content.Position = UDim2.new(0, SIDEBAR_W + 12, 0, TOPBAR_H + 6)
    content.BackgroundColor3 = COL_PANEL
    content.BorderSizePixel = 0
    content.Parent = main

    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 6)
    contentCorner.Parent = content

    -- Page container
    local pages = {}
    local currentPage = nil

    local function newPage(name)
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, -16, 1, -16)
        page.Position = UDim2.new(0, 8, 0, 8)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = COL_ACCENT
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        page.AutomaticCanvasSize = Enum.AutomaticSize.Y
        page.Visible = false
        page.Parent = content
        pages[name] = page
        return page
    end

    local function showPage(name)
        for n, p in pairs(pages) do
            p.Visible = (n == name)
        end
        currentPage = name
    end

    -- Section header
    local function addSection(parent, text, yOffset)
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 24)
        lbl.Position = UDim2.new(0, 0, 0, yOffset)
        lbl.BackgroundTransparency = 1
        lbl.Text = text
        lbl.TextColor3 = COL_MUTED
        lbl.TextSize = 11
        lbl.Font = Enum.Font.GothamBold
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = parent
        return lbl
    end

    -- Toggle row
    local function addToggle(parent, label, key, yOffset, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.Position = UDim2.new(0, 0, 0, yOffset)
        row.BackgroundColor3 = COL_BG
        row.BorderSizePixel = 0
        row.Parent = parent

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 5)
        rowCorner.Parent = row

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 1, 0)
        lbl.Position = UDim2.new(0, 10, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = COL_TEXT
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        -- Toggle pill
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 40, 0, 20)
        pill.Position = UDim2.new(1, -50, 0.5, -10)
        pill.BackgroundColor3 = Config[key] and COL_ACCENT or COL_STROKE
        pill.BorderSizePixel = 0
        pill.Parent = row

        local pillCorner = Instance.new("UICorner")
        pillCorner.CornerRadius = UDim.new(1, 0)
        pillCorner.Parent = pill

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Config[key] and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = pill

        local knobCorner = Instance.new("UICorner")
        knobCorner.CornerRadius = UDim.new(1, 0)
        knobCorner.Parent = knob

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 1, 0)
        btn.BackgroundTransparency = 1
        btn.Text = ""
        btn.Parent = row

        btn.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            TweenService:Create(pill, TweenInfo.new(0.15), {
                BackgroundColor3 = Config[key] and COL_ACCENT or COL_STROKE
            }):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {
                Position = Config[key] and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
            }):Play()
            if callback then callback(Config[key]) end
        end)

        return row
    end

    -- Slider row
    local function addSlider(parent, label, min, max, default, yOffset, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48)
        row.Position = UDim2.new(0, 0, 0, yOffset)
        row.BackgroundColor3 = COL_BG
        row.BorderSizePixel = 0
        row.Parent = parent

        local rowCorner = Instance.new("UICorner")
        rowCorner.CornerRadius = UDim.new(0, 5)
        rowCorner.Parent = row

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -60, 0, 20)
        lbl.Position = UDim2.new(0, 10, 0, 4)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = COL_TEXT
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row

        local valLbl = Instance.new("TextLabel")
        valLbl.Size = UDim2.new(0, 50, 0, 20)
        valLbl.Position = UDim2.new(1, -60, 0, 4)
        valLbl.BackgroundTransparency = 1
        valLbl.Text = tostring(default)
        valLbl.TextColor3 = COL_ACCENT
        valLbl.TextSize = 12
        valLbl.Font = Enum.Font.GothamMedium
        valLbl.TextXAlignment = Enum.TextXAlignment.Right
        valLbl.Parent = row

        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -20, 0, 6)
        track.Position = UDim2.new(0, 10, 0, 30)
        track.BackgroundColor3 = COL_STROKE
        track.BorderSizePixel = 0
        track.Parent = row

        local trackCorner = Instance.new("UICorner")
        trackCorner.CornerRadius = UDim.new(1, 0)
        trackCorner.Parent = track

        local pct = (default - min) / (max - min)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = COL_ACCENT
        fill.BorderSizePixel = 0
        fill.Parent = track

        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(1, 0)
        fillCorner.Parent = fill

        local dragging = false

        local function updateFromX(x)
            local rel = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local val = min + (max - min) * rel
            fill.Size = UDim2.new(rel, 0, 1, 0)
            valLbl.Text = string.format("%.2f", val)
            if callback then callback(val) end
        end

        local hit = Instance.new("TextButton")
        hit.Size = UDim2.new(1, 0, 1, 0)
        hit.BackgroundTransparency = 1
        hit.Text = ""
        hit.Parent = track

        hit.MouseButton1Down:Connect(function()
            dragging = true
            updateFromX(UserInputService:GetMouseLocation().X)
        end)

        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                updateFromX(input.Position.X)
            end
        end)

        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)

        return row
    end

    -- Sidebar buttons
    local sidebarButtons = {}

    local function addSidebarButton(name, icon, yOffset)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 34)
        btn.Position = UDim2.new(0, 6, 0, yOffset)
        btn.BackgroundColor3 = COL_SIDEBAR
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.Parent = sidebar

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 5)
        btnCorner.Parent = btn

        local iconLbl = Instance.new("TextLabel")
        iconLbl.Size = UDim2.new(0, 20, 1, 0)
        iconLbl.Position = UDim2.new(0, 8, 0, 0)
        iconLbl.BackgroundTransparency = 1
        iconLbl.Text = icon
        iconLbl.TextColor3 = COL_MUTED
        iconLbl.TextSize = 14
        iconLbl.Font = Enum.Font.GothamBold
        iconLbl.Parent = btn

        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, -34, 1, 0)
        lbl.Position = UDim2.new(0, 30, 0, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = COL_MUTED
        lbl.TextSize = 12
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = btn

        btn.MouseButton1Click:Connect(function()
            showPage(name)
            for _, b in pairs(sidebarButtons) do
                b.btn.BackgroundColor3 = COL_SIDEBAR
                b.icon.TextColor3 = COL_MUTED
                b.lbl.TextColor3 = COL_MUTED
            end
            btn.BackgroundColor3 = COL_PANEL
            iconLbl.TextColor3 = COL_ACCENT
            lbl.TextColor3 = COL_TEXT
        end)

        sidebarButtons[name] = { btn = btn, icon = iconLbl, lbl = lbl }
        return btn
    end

    -- Pages
    local homePage = newPage("Home")
    local combatPage = newPage("Combat")
    local visualPage = newPage("Visual")
    local settingsPage = newPage("Settings")

    -- === HOME PAGE ===
    addSection(homePage, "WELCOME", 0)
    local welcome = Instance.new("TextLabel")
    welcome.Size = UDim2.new(1, 0, 0, 60)
    welcome.Position = UDim2.new(0, 0, 0, 26)
    welcome.BackgroundColor3 = COL_BG
    welcome.Text = "AutoParry running. Detection locked.\nPlatform: " .. Platform
    welcome.TextColor3 = COL_MUTED
    welcome.TextSize = 11
    welcome.Font = Enum.Font.Gotham
    welcome.TextWrapped = true
    welcome.Parent = homePage

    local wCorner = Instance.new("UICorner")
    wCorner.CornerRadius = UDim.new(0, 5)
    wCorner.Parent = welcome

    addSection(homePage, "STATUS", 100)

    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, 0, 0, 40)
    statusLbl.Position = UDim2.new(0, 0, 0, 126)
    statusLbl.BackgroundColor3 = COL_BG
    statusLbl.Text = "● Ready"
    statusLbl.TextColor3 = COL_GREEN
    statusLbl.TextSize = 12
    statusLbl.Font = Enum.Font.GothamMedium
    statusLbl.Parent = homePage

    local sCorner = Instance.new("UICorner")
    sCorner.CornerRadius = UDim.new(0, 5)
    sCorner.Parent = statusLbl

    -- === COMBAT PAGE ===
    addSection(combatPage, "PARRY", 0)
    addToggle(combatPage, "Auto Parry", "AutoParry", 26, function(v)
        statusLbl.Text = v and "● Auto Parry ON" or "● Auto Parry OFF"
        statusLbl.TextColor3 = v and COL_GREEN or COL_RED
    end)
    addToggle(combatPage, "Auto Spam", "AutoSpam", 62, function(v) StartSpam() end)
    addToggle(combatPage, "Auto Clash", "AutoClash", 98)
    addToggle(combatPage, "Humanize Delay", "HumanizeDelay", 134)

    addSection(combatPage, "TUNING", 180)
    addSlider(combatPage, "Parry Window", 0.3, 0.9, Config.ParryWindow, 206, function(v)
        Config.ParryWindow = v
    end)
    addSlider(combatPage, "Parry Cooldown", 0.05, 0.3, Config.ParryCooldown, 254, function(v)
        Config.ParryCooldown = v
    end)
    addSlider(combatPage, "Spam Rate", 10, 200, Config.SpamRate, 302, function(v)
        Config.SpamRate = v
    end)

    -- === VISUAL PAGE ===
    addSection(visualPage, "ESP", 0)
    addToggle(visualPage, "Ball ESP", "BallESP", 26, function() StartESP() end)
    addToggle(visualPage, "Target ESP", "TargetESP", 62, function() StartESP() end)

    -- === SETTINGS PAGE ===
    addSection(settingsPage, "GENERAL", 0)
    addToggle(settingsPage, "Debug Notifications", "Debug", 26)

    local unloadBtn = Instance.new("TextButton")
    unloadBtn.Size = UDim2.new(1, 0, 0, 34)
    unloadBtn.Position = UDim2.new(0, 0, 0, 70)
    unloadBtn.BackgroundColor3 = COL_RED
    unloadBtn.Text = "Unload Script"
    unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unloadBtn.TextSize = 12
    unloadBtn.Font = Enum.Font.GothamBold
    unloadBtn.BorderSizePixel = 0
    unloadBtn.Parent = settingsPage

    local uCorner = Instance.new("UICorner")
    uCorner.CornerRadius = UDim.new(0, 5)
    uCorner.Parent = unloadBtn

    unloadBtn.MouseButton1Click:Connect(function()
        if parryConnection then parryConnection:Disconnect() end
        if spamConnection then spamConnection:Disconnect() end
        if espConnection then espConnection:Disconnect() end
        if espFolder then espFolder:Destroy() end
        screenGui:Destroy()
    end)

    -- Sidebar buttons
    addSidebarButton("Home", "◆", 8)
    addSidebarButton("Combat", "⚔", 48)
    addSidebarButton("Visual", "◉", 88)
    addSidebarButton("Settings", "⚙", 128)

    -- Start on Home
    showPage("Home")

    -- Minimize behavior
    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        sidebar.Visible = not minimized
        content.Visible = not minimized
        if minimized then
            main.Size = UDim2.new(0, W, 0, TOPBAR_H)
        else
            main.Size = UDim2.new(0, W, 0, H)
        end
    end)

    return screenGui
end

-- ========== START ==========
Notify("Auto Parry", "Script loaded", 2)

if Config.EnableGUI then CreateUI() end
StartParryLoop()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        Config.AutoParry = not Config.AutoParry
        Notify("Auto Parry", Config.AutoParry and "ON" or "OFF", 1)
    end
end)
