-- language: Lua, file: vanta_egg.lua, target: Roblox Steal An Egg
-- features: auto steal, instant steal, speed bypass, teleport to egg, anti-cheat layer

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local player = Players.LocalPlayer

-- ========== CONFIG ==========
local CONFIG = {
    speed = 120,
    stealDelay = 0.05,  -- instant steal interval
    teleportToEgg = true,
    autoSteal = true,
    antiCheatBypass = true,
}

-- ========== STATE ==========
local state = {
    enabled = true,
    stealConnection = nil,
    speedConnection = nil,
    originalSpeed = 16,
    originalJump = 50,
}

-- ========== CHARACTER HOOK ==========
local function getChar()
    return player.Character or player.CharacterAdded:Wait()
end

local function getHRP()
    local char = getChar()
    return char:WaitForChild("HumanoidRootPart", 5)
end

local function getHumanoid()
    local char = getChar()
    return char:WaitForChild("Humanoid", 5)
end

-- ========== ANTI-CHEAT BYPASS ==========
-- property spoofing for speed/jump, remote blocking for detection
local function enableAntiCheat()
    if not CONFIG.antiCheatBypass then return end
    
    local mt = getrawmetatable(game)
    local oldIndex = mt.__index
    local oldNamecall = mt.__namecall
    
    setreadonly(mt, false)
    
    mt.__index = newcclosure(function(self, key)
        if key == "WalkSpeed" and self:IsA("Humanoid") then
            return 16 -- report normal speed to anti-cheat
        end
        if key == "JumpPower" and self:IsA("Humanoid") then
            return 50 -- report normal jump
        end
        return oldIndex(self, key)
    end)
    
    mt.__namecall = newcclosure(function(self, ...)
        local method = getnamecallmethod()
        local args = {...}
        
        -- block suspicious remote fires (common detection vectors)
        if method == "FireServer" and self:IsA("RemoteEvent") then
            local name = self.Name:lower()
            if name:find("detect") or name:find("report") or name:find("check") then
                return nil -- silently drop
            end
        end
        
        return oldNamecall(self, ...)
    end)
    
    setreadonly(mt, true)
end

-- ========== TELEPORT TO EGG ==========
-- scans workspace for egg models, returns nearest CFrame
local function findNearestEgg()
    local hrp = getHRP()
    if not hrp then return nil end
    
    local myPos = hrp.Position
    local nearest, nearestDist = nil, math.huge
    
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") and (obj.Name:lower():find("egg") or obj.Parent.Name:lower():find("egg")) then
            local dist = (obj.Position - myPos).Magnitude
            if dist < nearestDist then
                nearestDist = dist
                nearest = obj
            end
        end
    end
    
    return nearest
end

local function teleportToEgg()
    local egg = findNearestEgg()
    if not egg then return end
    
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = egg.CFrame + Vector3.new(0, 3, 0)
    end
end

-- ========== INSTANT STEAL ==========
-- fires steal remote at high frequency targeting egg positions
local function startStealLoop()
    if state.stealConnection then
        state.stealConnection:Disconnect()
    end
    
    state.stealConnection = RunService.Heartbeat:Connect(function()
        if not state.enabled or not CONFIG.autoSteal then return end
        
        local hrp = getHRP()
        if not hrp then return end
        
        -- teleport first if configured
        if CONFIG.teleportToEgg then
            teleportToEgg()
        end
        
        -- fire all remotes that look like steal prompts
        -- this is the brute-force approach: spam every RemoteEvent
        for _, remote in ipairs(game:GetDescendants()) do
            if remote:IsA("RemoteEvent") then
                local name = remote.Name:lower()
                if name:find("steal") or name:find("collect") or name:find("pickup") or name:find("egg") then
                    pcall(function()
                        remote:FireServer()
                    end)
                end
            end
        end
        
        task.wait(CONFIG.stealDelay)
    end)
end

-- ========== SPEED ==========
local function startSpeed()
    if state.speedConnection then
        state.speedConnection:Disconnect()
    end
    
    local humanoid = getHumanoid()
    if humanoid then
        state.originalSpeed = humanoid.WalkSpeed
        state.originalJump = humanoid.JumpPower
    end
    
    state.speedConnection = RunService.Heartbeat:Connect(function()
        if not state.enabled then return end
        
        local h = getHumanoid()
        if h and h.Parent then
            h.WalkSpeed = CONFIG.speed
            h.JumpPower = CONFIG.speed * 0.8
        end
    end)
end

-- ========== STOP ==========
local function stopAll()
    state.enabled = false
    if state.stealConnection then state.stealConnection:Disconnect() state.stealConnection = nil end
    if state.speedConnection then state.speedConnection:Disconnect() state.speedConnection = nil end
    
    local h = getHumanoid()
    if h then
        h.WalkSpeed = state.originalSpeed
        h.JumpPower = state.originalJump
    end
end

-- ========== UI ==========
local gui = Instance.new("ScreenGui")
gui.Name = "VantaEgg"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 220, 0, 280)
frame.Position = UDim2.new(0, 20, 0, 100)
frame.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
title.Text = "VANTA EGG"
title.TextColor3 = Color3.fromRGB(180, 140, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = frame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = title

-- status
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 20)
status.Position = UDim2.new(0, 10, 0, 40)
status.BackgroundTransparency = 1
status.Text = "RUNNING"
status.TextColor3 = Color3.fromRGB(100, 220, 100)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = frame

-- toggle button
local toggle = Instance.new("TextButton")
toggle.Size = UDim2.new(1, -20, 0, 35)
toggle.Position = UDim2.new(0, 10, 0, 70)
toggle.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
toggle.Text = "TOGGLE ON/OFF"
toggle.TextColor3 = Color3.fromRGB(200, 200, 220)
toggle.Font = Enum.Font.GothamBold
toggle.TextSize = 12
toggle.Parent = frame

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 6)
toggleCorner.Parent = toggle

toggle.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    if state.enabled then
        status.Text = "RUNNING"
        status.TextColor3 = Color3.fromRGB(100, 220, 100)
        startStealLoop()
        startSpeed()
    else
        status.Text = "STOPPED"
        status.TextColor3 = Color3.fromRGB(220, 100, 100)
        stopAll()
    end
end)

-- teleport button
local tpBtn = Instance.new("TextButton")
tpBtn.Size = UDim2.new(1, -20, 0, 35)
tpBtn.Position = UDim2.new(0, 10, 0, 115)
tpBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
tpBtn.Text = "TP TO EGG"
tpBtn.TextColor3 = Color3.fromRGB(200, 200, 220)
tpBtn.Font = Enum.Font.GothamBold
tpBtn.TextSize = 12
tpBtn.Parent = frame

local tpCorner = Instance.new("UICorner")
tpCorner.CornerRadius = UDim.new(0, 6)
tpCorner.Parent = tpBtn

tpBtn.MouseButton1Click:Connect(function()
    teleportToEgg()
end)

-- speed slider
local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 20)
speedLabel.Position = UDim2.new(0, 10, 0, 160)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: " .. CONFIG.speed
speedLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 11
speedLabel.Parent = frame

local speedSlider = Instance.new("TextButton")
speedSlider.Size = UDim2.new(1, -20, 0, 25)
speedSlider.Position = UDim2.new(0, 10, 0, 185)
speedSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 55)
speedSlider.Text = "50 | 120 | 300"
speedSlider.TextColor3 = Color3.fromRGB(200, 200, 220)
speedSlider.Font = Enum.Font.Gotham
speedSlider.TextSize = 10
speedSlider.Parent = frame

local speedCorner = Instance.new("UICorner")
speedCorner.CornerRadius = UDim.new(0, 6)
speedCorner.Parent = speedSlider

local speedIndex = 2
local speeds = {50, 120, 300}

speedSlider.MouseButton1Click:Connect(function()
    speedIndex = speedIndex % #speeds + 1
    CONFIG.speed = speeds[speedIndex]
    speedLabel.Text = "Speed: " .. CONFIG.speed
end)

-- kill/stop all
local killBtn = Instance.new("TextButton")
killBtn.Size = UDim2.new(1, -20, 0, 30)
killBtn.Position = UDim2.new(0, 10, 0, 220)
killBtn.BackgroundColor3 = Color3.fromRGB(80, 30, 30)
killBtn.Text = "STOP ALL"
killBtn.TextColor3 = Color3.fromRGB(220, 150, 150)
killBtn.Font = Enum.Font.GothamBold
killBtn.TextSize = 11
killBtn.Parent = frame

local killCorner = Instance.new("UICorner")
killCorner.CornerRadius = UDim.new(0, 6)
killCorner.Parent = killBtn

killBtn.MouseButton1Click:Connect(function()
    stopAll()
    state.enabled = false
    status.Text = "STOPPED"
    status.TextColor3 = Color3.fromRGB(220, 100, 100)
end)

-- ========== BOOT ==========
enableAntiCheat()
startStealLoop()
startSpeed()

player.CharacterAdded:Connect(function()
    task.wait(1)
    if state.enabled then
        startSpeed()
    end
end)

print("[VANTA] loaded. " .. CONFIG.speed .. " speed, instant steal, tp to egg.")
