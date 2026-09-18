--[[
    Blade Ball Auto Parry
    Detection: ball targets you (color/attribute)
    Remote: ParryButtonPress
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

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
    ParryCooldown = 0.12,
    PingOffset = 0.03,
    HumanizeDelay = true,
    HumanizeMin = 0.03,
    HumanizeMax = 0.10,
    EnableGUI = true,
    Debug = false,
}

local AntiKick = {
    MaxParryPerSecond = 6,
}

local parryConnection = nil
local lastParryTime = 0
local parryCount = 0
local lastResetTime = tick()

-- ========== REMOTE ==========
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local ParryButtonPress = Remotes:WaitForChild("ParryButtonPress", 9e9)

-- ========== BALL ==========
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

-- ========== TARGET CHECK ==========
local function IsBallTargetingUs(ball)
    if not ball then return false end

    -- Method 1: attribute check
    local target = ball:GetAttribute("target")
    if target == LocalPlayer.Name then return true end
    if target == LocalPlayer.UserId then return true end

    -- Method 2: ball color is red
    local c = ball.Color
    if c.R > 0.6 and c.G < 0.4 and c.B < 0.4 then return true end

    -- Method 3: ball has a Highlight or selection
    local hl = ball:FindFirstChild("Highlight")
    if hl and hl.Enabled then return true end

    return false
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

-- ========== LOOP ==========
local function StartParryLoop()
    if parryConnection then parryConnection:Disconnect() end
    parryConnection = RunService.PreSimulation:Connect(function()
        if not Config.AutoParry then return end

        local ball = GetBall()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not ball or not hrp then return end
        if not IsBallTargetingUs(ball) then return end

        local distance = (hrp.Position - ball.Position).Magnitude
        local velocity = ball.AssemblyLinearVelocity.Magnitude
        if velocity < 1 then return end

        local timeToReach = distance / velocity
        local parryWindow = 0.6 + Config.PingOffset

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

    if gethui then pcall(function() screenGui.Parent = gethui() end) end
    if not screenGui.Parent then pcall(function() screenGui.Parent = CoreGui end) end
    if not screenGui.Parent then screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local frameW = IsMobile and 300 or 280
    local frameH = IsMobile and 280 or 240
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

    local status = Instance.new("TextLabel")
    status.Size = UDim2.new(0.9, 0, 0, 30)
    status.Position = UDim2.new(0.05, 0, 0, 60 + btnH + 20)
    status.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
    status.Text = "Detection: Multi | Ready"
    status.TextColor3 = Color3.fromRGB(52, 211, 153)
    status.TextSize = IsMobile and 13 or 12
    status.Font = Enum.Font.Gotham
    status.Parent = mainFrame

    local statusCorner = Instance.new("UICorner")
    statusCorner.CornerRadius = UDim.new(0, 6)
    statusCorner.Parent = status

    local info = Instance.new("TextLabel")
    info.Size = UDim2.new(0.9, 0, 0, 50)
    info.Position = UDim2.new(0.05, 0, 0, 60 + btnH + 60)
    info.BackgroundColor3 = Color3.fromRGB(11, 9, 17)
    info.Text = "Remote: ParryButtonPress\nRate: " .. AntiKick.MaxParryPerSecond .. "/s"
    info.TextColor3 = Color3.fromRGB(186, 172, 212)
    info.TextSize = IsMobile and 12 or 11
    info.Font = Enum.Font.Gotham
    info.Parent = mainFrame

    local infoCorner = Instance.new("UICorner")
    infoCorner.CornerRadius = UDim.new(0, 6)
    infoCorner.Parent = info

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

if Config.EnableGUI then CreateGUI() end
StartParryLoop()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        Config.AutoParry = not Config.AutoParry
        print("[FAx] Auto Parry: " .. (Config.AutoParry and "ON" or "OFF"))
    end
end)
