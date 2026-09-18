--[[
    Blade Ball Auto Parry Script
    Platforms: Windows, Mac, iOS, Android
    Executors: Delta, Xeno, Wave, Potassium, Codex, Arceus X, Fluxus, Hydrogen
    Note: Based on distance and ball speed. Built-in basic anti-kick logic.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")

local LocalPlayer = Players.LocalPlayer

-- ========== PLATFORM DETECTION ==========
local Platform = "Unknown"
local IsMobile = false
local IsDesktop = false
local HasVirtualInput = pcall(function() return game:GetService("VirtualInputManager") end)
local VirtualInputManager = HasVirtualInput and game:GetService("VirtualInputManager") or nil

pcall(function()
    local ok, result = pcall(function()
        return UserInputService:GetPlatform()
    end)
    if ok and result then
        if result == Enum.Platform.Windows then
            Platform = "Windows"; IsDesktop = true
        elseif result == Enum.Platform.OSX then
            Platform = "Mac"; IsDesktop = true
        elseif result == Enum.Platform.IOS then
            Platform = "iOS"; IsMobile = true
        elseif result == Enum.Platform.Android then
            Platform = "Android"; IsMobile = true
        end
    end
end)

-- Fallback detection if GetPlatform fails
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
    ParryKey = "K",           -- Desktop parry key
    ParryCooldown = 0.15,
    PingOffset = 0.05,
    HumanizeDelay = true,
    HumanizeMin = 0.05,
    HumanizeMax = 0.15,
    AutoSpam = false,
    EnableGUI = true,
    MobileButtonSize = 60,     -- Bigger touch targets on mobile
}

local AntiKick = {
    MaxParryPerSecond = 8,
    UseVirtualInput = HasVirtualInput and IsDesktop,  -- Mobile falls back to remote
}

local parryConnection = nil
local lastParryTime = 0
local parryCount = 0
local lastResetTime = tick()

-- ========== GET BALL ==========
local function GetRealBall()
    local ballsFolder = Workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:IsA("BasePart") and ball:GetAttribute("realBall") then
            return ball
        end
    end
    return nil
end

-- ========== GET CHARACTER ==========
local function GetHRP()
    local char = LocalPlayer.Character
    if char then
        return char:FindFirstChild("HumanoidRootPart")
    end
    return nil
end

-- ========== EXECUTE PARRY ==========
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

    -- Try virtual input first (desktop only)
    if AntiKick.UseVirtualInput and VirtualInputManager then
        local ok = pcall(function()
            VirtualInputManager:SendKeyEvent(true, Config.ParryKey, false, game)
            task.wait(0.02)
            VirtualInputManager:SendKeyEvent(false, Config.ParryKey, false, game)
        end)
        if ok then return end
    end

    -- Fallback: fire the parry remote directly (works on all platforms)
    pcall(function()
        local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("Parry") then
            remotes.Parry:FireServer()
        end
    end)
end

-- ========== MAIN LOOP ==========
local function StartParryLoop()
    if parryConnection then parryConnection:Disconnect() end
    parryConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoParry then return end
        local ball = GetRealBall()
        local hrp = GetHRP()
        if not ball or not hrp then return end
        local target = ball:GetAttribute("target")
        if target ~= LocalPlayer.Name then return end
        local distance = (hrp.Position - ball.Position).Magnitude
        local velocity = ball.AssemblyLinearVelocity.Magnitude
        if velocity < 1 then return end
        local timeToReach = distance / velocity
        local parryWindow = 0.55 + Config.PingOffset
        if timeToReach <= parryWindow and timeToReach > 0 then
            ExecuteParry()
        end
    end)
end

-- ========== GUI ==========
local function CreateGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "R_" .. tostring(math.random(100000, 999999))
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Pick parent based on platform
    if gethui then
        pcall(function() screenGui.Parent = gethui() end)
    end
    if not screenGui.Parent then
        pcall(function() screenGui.Parent = CoreGui end)
    end
    if not screenGui.Parent then
        screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    -- Mobile gets a bigger, repositioned frame
    local frameW = IsMobile and 300 or 280
    local frameH = IsMobile and 340 or 300
    local btnH = IsMobile and 50 or 40

    local mainFrame = Instance.new("Frame")
    mainFrame.Size = UDim2.new(0, frameW, 0, frameH)
    mainFrame.Position = IsMobile
        and UDim2.new(0.5, -frameW/2, 0.1, 0)
        or UDim2.new(0.5, -frameW/2, 0.5, -frameH/2)
    mainFrame.BackgroundColor3 = Color3.fromRGB(15, 12, 22)
    mainFrame.BorderSizePixel = 0
    mainFrame.Active = true
    mainFrame.Draggable = true
    mainFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 10)
    corner.Parent = mainFrame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(168, 85, 247)
    stroke.Thickness = 1
    stroke.Parent = mainFrame

    -- Title bar
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 45)
    title.BackgroundColor3 = Color3.fromRGB(11, 9, 17)
    title.Text = "  Auto Parry  [" .. Platform .. "]"
    title.TextColor3 = Color3.fromRGB(243, 235, 255)
    title.TextSize = 16
    title.Font = Enum.Font.GothamBold
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = mainFrame

    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 10)
    titleCorner.Parent = title

    -- Auto Parry toggle
    local parryBtn = Instance.new("TextButton")
    parryBtn.Size = UDim2.new(0.9, 0, 0, btnH)
    parryBtn.Position = UDim2.new(0.05, 0, 0, 60)
    parryBtn.BackgroundColor3 = Color3.fromRGB(168, 85, 247)
    parryBtn.Text = "Auto Parry: ON"
    parryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    parryBtn.TextSize = IsMobile and 16 or 14
    parryBtn.Font = Enum.Font.Gotham
    parryBtn.Parent = mainFrame

    local parryCorner = Instance.new("UICorner")
    parryCorner.CornerRadius = UDim.new(0, 6)
    parryCorner.Parent = parryBtn

    parryBtn.MouseButton1Click:Connect(function()
        Config.AutoParry = not Config.AutoParry
        parryBtn.Text = "Auto Parry: " .. (Config.AutoParry and "ON" or "OFF")
        parryBtn.BackgroundColor3 = Config.AutoParry and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(60, 50, 80)
    end)

    -- Auto Spam toggle
    local spamBtn = Instance.new("TextButton")
    spamBtn.Size = UDim2.new(0.9, 0, 0, btnH)
    spamBtn.Position = UDim2.new(0.05, 0, 0, 60 + btnH + 10)
    spamBtn.BackgroundColor3 = Color3.fromRGB(60, 50, 80)
    spamBtn.Text = "Auto Spam: OFF"
    spamBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    spamBtn.TextSize = IsMobile and 16 or 14
    spamBtn.Font = Enum.Font.Gotham
    spamBtn.Parent = mainFrame

    local spamCorner = Instance.new("UICorner")
    spamCorner.CornerRadius = UDim.new(0, 6)
    spamCorner.Parent = spamBtn

    spamBtn.MouseButton1Click:Connect(function()
        Config.AutoSpam = not Config.AutoSpam
        spamBtn.Text = "Auto Spam: " .. (Config.AutoSpam and "ON" or "OFF")
        spamBtn.BackgroundColor3 = Config.AutoSpam and Color3.fromRGB(168, 85, 247) or Color3.fromRGB(60, 50, 80)
    end)

    -- Status
    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0.9, 0, 0, 30)
    status.Position = UDim2.new(0.05, 0, 0, 60 + (btnH * 2) + 20)
    status.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
    status.Text = "Platform: " .. Platform .. " | Ready"
    status.TextColor3 = Color3.fromRGB(52, 211, 153)
    status.TextSize = IsMobile and 13 or 12
    status.Font = Enum.Font.Gotham
    status.Parent = mainFrame

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = status

    -- Anti-kick info
    local antiKickInfo = Instance.new("TextLabel")
    antiKickInfo.Size = UDim2.new(0.9, 0, 0, 60)
    antiKickInfo.Position = UDim2.new(0.05, 0, 0, 60 + (btnH * 2) + 60)
    antiKickInfo.BackgroundColor3 = Color3.fromRGB(11, 9, 17)
    antiKickInfo.Text = "Anti-Kick: ON\nRate: " .. AntiKick.MaxParryPerSecond .. "/s | VInput: " .. (AntiKick.UseVirtualInput and "ON" or "OFF")
    antiKickInfo.TextColor3 = Color3.fromRGB(186, 172, 212)
    antiKickInfo.TextSize = IsMobile and 12 or 11
    antiKickInfo.Font = Enum.Font.Gotham
    antiKickInfo.Parent = mainFrame

    local antiCorner = Instance.new("UICorner")
    antiCorner.CornerRadius = UDim.new(0, 6)
    antiCorner.Parent = antiKickInfo

    -- Close
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -35, 0, 8)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 14
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = mainFrame

    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn

    closeBtn.MouseButton1Click:Connect(function()
        screenGui:Destroy()
    end)

    return screenGui
end

-- ========== START ==========
print("[FAx] Blade Ball Auto Parry loaded")
print("[FAx] Platform: " .. Platform)
print("[FAx] Virtual Input: " .. (AntiKick.UseVirtualInput and "available" or "using remote fallback"))

if Config.EnableGUI then
    CreateGUI()
end

StartParryLoop()

-- Desktop hotkey
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        Config.AutoParry = not Config.AutoParry
        print("[FAx] Auto Parry: " .. (Config.AutoParry and "ON" or "OFF"))
    end
end)
