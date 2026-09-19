--[[
    Oynx Hub - Blade Ball
    Built for current ball structure: Model "Ball" with AttributionCharacter + Parry BindableFunction
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local HAS_FS = (writefile and readfile and isfile) ~= nil
local IsMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local Platform = "Mobile"
pcall(function()
    local r = UserInputService:GetPlatform()
    if r == Enum.Platform.Windows then Platform = "Windows"
    elseif r == Enum.Platform.OSX then Platform = "Mac"
    elseif r == Enum.Platform.IOS then Platform = "iOS"
    elseif r == Enum.Platform.Android then Platform = "Android" end
end)

local Config = {
    AutoParry = true, AutoClash = true, AutoSpam = false, HumanizeDelay = true,
    ParryWindow = 0.55, ParryCooldown = 0.15, ClashDistance = 12, SpamRate = 40,
    BallESP = false, TargetESP = false, PlayerNamesESP = false,
    EnableGUI = true,
    ThemeColor = Color3.fromRGB(14, 14, 16),
}

local parryConnection, clashConnection, spamConnection, espConnection, nameEspConnection
local lastParryTime, parryCount, lastResetTime = 0, 0, tick()
local Parried = false
local espFolder, nameEspFolder
local uiRefs = {}
local CONFIG_FILE = "oynx_hub_config.json"
local JOBS_FILE = "oynx_last_job.txt"

local function Notify(t, x, d)
    pcall(function() StarterGui:SetCore("SendNotification", {Title=t, Text=x, Duration=d or 2}) end)
end

local function GetBall()
    local bf = Workspace:FindFirstChild("Balls")
    if not bf then return nil end
    for _, b in ipairs(bf:GetChildren()) do
        if b:IsA("Model") and b.Name == "Ball" then return b end
    end
    return nil
end

local function GetBallTarget(ball)
    local attr = ball:FindFirstChild("AttributionCharacter")
    if attr and attr.Value then return attr.Value end
    return nil
end

local function GetBallPos(ball)
    local body = ball:FindFirstChild("Body") or ball:FindFirstChild("Collider")
    if body then return body.Position end
    return ball:GetPivot().Position
end

local function GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function InvokeParry(ball)
    local parryFn = ball:FindFirstChild("Parry")
    if parryFn and parryFn:IsA("BindableFunction") then
        pcall(function() parryFn:Invoke() end)
        return true
    end
    return false
end

local function ExecuteParry()
    local ball = GetBall()
    if not ball then return end
    local now = tick()
    if now - lastParryTime < Config.ParryCooldown then return end
    if now - lastResetTime > 1 then parryCount = 0; lastResetTime = now end
    if parryCount >= 6 then return end
    lastParryTime = now
    parryCount = parryCount + 1
    if Config.HumanizeDelay then
        task.wait(math.random() * 0.05 + 0.03)
    end
    InvokeParry(ball)
end

local function StartSpam()
    if spamConnection then spamConnection:Disconnect() end
    if not Config.AutoSpam then return end
    spamConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoSpam then return end
        local ball = GetBall()
        if ball then InvokeParry(ball) end
        task.wait(1 / Config.SpamRate)
    end)
end

local function StartParryLoop()
    if parryConnection then parryConnection:Disconnect() end
    parryConnection = RunService.PreSimulation:Connect(function()
        if not Config.AutoParry then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then return end
        local target = GetBallTarget(ball)
        if target ~= LocalPlayer.Character then return end
        local bp = GetBallPos(ball)
        local dist = (hrp.Position - bp).Magnitude
        if dist > 40 then return end
        local tti = dist / 100
        if dist <= Config.ClashDistance + 3 or tti <= Config.ParryWindow then
            ExecuteParry()
            Parried = true
        end
    end)
end

local function StartClashLoop()
    if clashConnection then clashConnection:Disconnect() end
    clashConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoClash then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then return end
        local target = GetBallTarget(ball)
        if target ~= LocalPlayer.Character then return end
        local bp = GetBallPos(ball)
        if (hrp.Position - bp).Magnitude <= Config.ClashDistance then
            ExecuteParry()
        end
    end)
end

local function StartESP()
    if espConnection then espConnection:Disconnect() end
    if espFolder then espFolder:Destroy() end
    if not (Config.BallESP or Config.TargetESP) then return end
    espFolder = Instance.new("Folder"); espFolder.Name = "OynxESP"; espFolder.Parent = Workspace
    espConnection = RunService.RenderStepped:Connect(function()
        for _, o in ipairs(espFolder:GetChildren()) do o:Destroy() end
        if Config.BallESP then
            local bf = Workspace:FindFirstChild("Balls")
            if bf then
                for _, b in ipairs(bf:GetChildren()) do
                    if b:IsA("Model") and b.Name == "Ball" then
                        local body = b:FindFirstChild("Body") or b:FindFirstChild("Collider")
                        if body then
                            local h = Instance.new("Highlight")
                            h.Adornee = b
                            h.FillColor = Color3.fromRGB(255, 50, 50)
                            h.FillTransparency = 0.5
                            h.Parent = espFolder
                        end
                    end
                end
            end
        end
        if Config.TargetESP then
            local ball = GetBall()
            if ball then
                local target = GetBallTarget(ball)
                if target then
                    local h = Instance.new("Highlight")
                    h.Adornee = target
                    h.FillColor = Color3.fromRGB(255, 0, 0)
                    h.FillTransparency = 0.6
                    h.Parent = espFolder
                end
            end
        end
    end)
end

local function StartPlayerNamesESP()
    if nameEspConnection then nameEspConnection:Disconnect() end
    if nameEspFolder then nameEspFolder:Destroy() end
    if not Config.PlayerNamesESP then return end
    nameEspFolder = Instance.new("Folder"); nameEspFolder.Name = "OynxNames"; nameEspFolder.Parent = Workspace
    nameEspConnection = RunService.RenderStepped:Connect(function()
        for _, o in ipairs(nameEspFolder:GetChildren()) do o:Destroy() end
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local head = p.Character:FindFirstChild("Head")
                if head then
                    local bb = Instance.new("BillboardGui")
                    bb.Adornee = head
                    bb.Size = UDim2.new(0, 120, 0, 20)
                    bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = nameEspFolder
                    local nl = Instance.new("TextLabel")
                    nl.Size = UDim2.new(1, 0, 1, 0)
                    nl.BackgroundTransparency = 1
                    nl.Text = p.Name
                    nl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nl.TextStrokeTransparency = 0
                    nl.TextSize = 14
                    nl.Font = Enum.Font.GothamBold
                    nl.Parent = bb
                end
            end
        end
    end)
end

local function CreateUI()
    local sg = Instance.new("ScreenGui")
    sg.ResetOnSpawn = false
    sg.Name = "R_" .. tostring(math.random(100000, 999999))
    sg.IgnoreGuiInset = true

    local parented = false
    if gethui then parented = pcall(function() sg.Parent = gethui() end) end
    if not parented then parented = pcall(function() sg.Parent = CoreGui end) end
    if not parented then pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end) end

    local COL_BG = Config.ThemeColor
    local COL_PANEL = Config.ThemeColor:Lerp(Color3.fromRGB(255, 255, 255), 0.05)
    local COL_SIDEBAR = Config.ThemeColor:Lerp(Color3.fromRGB(0, 0, 0), 0.15)
    local COL_STROKE = Color3.fromRGB(40, 40, 46)
    local COL_TEXT = Color3.fromRGB(230, 230, 235)
    local COL_MUTED = Color3.fromRGB(130, 130, 140)
    local COL_ACCENT = Color3.fromRGB(0, 170, 255)
    local COL_GREEN = Color3.fromRGB(50, 210, 120)
    local COL_RED = Color3.fromRGB(220, 60, 60)

    local W = IsMobile and 420 or 600
    local H = IsMobile and 320 or 380

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, W, 0, H)
    main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    main.BackgroundColor3 = COL_BG
    main.BorderSizePixel = 0
    main.Active = true
    main.Draggable = true
    main.Parent = sg

    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 8); mc.Parent = main
    local ms = Instance.new("UIStroke"); ms.Color = COL_STROKE; ms.Thickness = 1; ms.Parent = main

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, 36)
    bar.BackgroundColor3 = COL_SIDEBAR
    bar.BorderSizePixel = 0
    bar.Parent = main
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = bar
    local bfix = Instance.new("Frame")
    bfix.Size = UDim2.new(1, 0, 0, 8)
    bfix.Position = UDim2.new(0, 0, 1, -8)
    bfix.BackgroundColor3 = COL_SIDEBAR
    bfix.BorderSizePixel = 0
    bfix.Parent = bar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 1, 0)
    title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "Oynx Hub  |  Blade Ball"
    title.TextColor3 = COL_TEXT
    title.TextSize = 13
    title.Font = Enum.Font.GothamMedium
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = bar

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28)
    closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = COL_RED
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 13
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.BorderSizePixel = 0
    closeBtn.Parent = bar
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 5); cbc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() sg:Destroy() end)

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -16, 1, -52)
    content.Position = UDim2.new(0, 8, 0, 44)
    content.BackgroundColor3 = COL_PANEL
    content.BorderSizePixel = 0
    content.Parent = main
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = content

    local scroll = Instance.new("ScrollingFrame")
    scroll.Size = UDim2.new(1, -16, 1, -16)
    scroll.Position = UDim2.new(0, 8, 0, 8)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 3
    scroll.ScrollBarImageColor3 = COL_ACCENT
    scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
    scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
    scroll.Parent = content

    local function addSection(text, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 24)
        l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1
        l.Text = text
        l.TextColor3 = COL_MUTED
        l.TextSize = 11
        l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = scroll
    end

    local function addToggle(label, key, y, cb)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundColor3 = COL_BG
        row.BorderSizePixel = 0
        row.Parent = scroll
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row

        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -60, 1, 0)
        l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1
        l.Text = label
        l.TextColor3 = COL_TEXT
        l.TextSize = 12
        l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.Parent = row

        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 40, 0, 20)
        pill.Position = UDim2.new(1, -50, 0.5, -10)
        pill.BackgroundColor3 = Config[key] and COL_ACCENT or COL_STROKE
        pill.BorderSizePixel = 0
        pill.Parent = row
        local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(1, 0); pc.Parent = pill

        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Config[key] and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        knob.BorderSizePixel = 0
        knob.Parent = pill
        local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob

        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0)
        b.BackgroundTransparency = 1
        b.Text = ""
        b.Parent = row
        b.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = Config[key] and COL_ACCENT or COL_STROKE}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = Config[key] and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)}):Play()
            if cb then cb(Config[key]) end
        end)
    end

    addSection("COMBAT", 0)
    addToggle("Auto Parry", "AutoParry", 26)
    addToggle("Auto Clash", "AutoClash", 62)
    addToggle("Auto Spam", "AutoSpam", 98, function() StartSpam() end)
    addToggle("Humanize Delay", "HumanizeDelay", 134)

    addSection("VISUAL", 180)
    addToggle("Ball ESP", "BallESP", 206, function() StartESP() end)
    addToggle("Target ESP", "TargetESP", 242, function() StartESP() end)
    addToggle("Player Names ESP", "PlayerNamesESP", 278, function() StartPlayerNamesESP() end)

    return sg
end

-- ========== START ==========
local ok, err = pcall(CreateUI)
if not ok then
    Notify("Oynx Error", tostring(err), 8)
else
    Notify("Oynx Hub", "Oynx Hub Loaded (We would rather you use your alt account).", 3)
    task.wait(2)
    pcall(StartParryLoop)
    pcall(StartClashLoop)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then
        Config.AutoParry = not Config.AutoParry
        Notify("Oynx Hub", Config.AutoParry and "Auto Parry ON" or "Auto Parry OFF", 1)
    end
end)
