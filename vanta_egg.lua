-- language: Lua, file: vanta_egg.lua, target: Roblox Steal An Egg
-- v2: cached remote scan, cached egg scan, throttled loops, fixed anti-cheat write path

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ========== CONFIG ==========
local CONFIG = {
    speed = 120,
    stealInterval = 0.05,   -- seconds between steal fires
    rescanInterval = 2,     -- seconds between workspace rescans
    teleportToEgg = true,
    autoSteal = true,
    antiCheatBypass = true,
}

-- ========== STATE ==========
local state = {
    enabled = true,
    stealConn = nil,
    speedConn = nil,
    scanConn = nil,
    originalSpeed = 16,
    originalJump = 50,
    cachedEggs = {},
    cachedRemotes = {},
    lastScan = 0,
}

-- ========== SAFE GETTERS ==========
local function getChar()
    return player.Character
end

local function getHRP()
    local c = getChar()
    if not c then return nil end
    return c:FindFirstChild("HumanoidRootPart")
end

local function getHumanoid()
    local c = getChar()
    if not c then return nil end
    return c:FindFirstChildOfClass("Humanoid")
end

-- ========== ANTI-CHEAT BYPASS ==========
-- spoofs the read AND blocks the server-side detection remotes.
-- the real fix for speed detection is not writing WalkSpeed every frame —
-- write once, then spoof reads so the client-side check sees 16.
local function enableAntiCheat()
    if not CONFIG.antiCheatBypass then return end
    local ok = pcall(function()
        local mt = getrawmetatable(game)
        local oldIndex = mt.__index
        local oldNamecall = mt.__namecall
        setreadonly(mt, false)

        mt.__index = newcclosure(function(self, key)
            if key == "WalkSpeed" and typeof(self) == "Instance" and self:IsA("Humanoid") then
                return 16
            end
            if key == "JumpPower" and typeof(self) == "Instance" and self:IsA("Humanoid") then
                return 50
            end
            return oldIndex(self, key)
        end)

        mt.__namecall = newcclosure(function(self, ...)
            local method = getnamecallmethod()
            if method == "FireServer" and typeof(self) == "Instance" and self:IsA("RemoteEvent") then
                local n = self.Name:lower()
                if n:find("detect") or n:find("report") or n:find("check") or n:find("flag") then
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
    end)
    if not ok then
        warn("[VANTA] anti-cheat hook failed — executor missing getrawmetatable/newcclosure")
    end
end

-- ========== SCAN (cached) ==========
-- walking GetDescendants every frame is the lag source.
-- scan once, cache, rescan on a timer only.
local function scanWorkspace()
    local eggs = {}
    local remotes = {}
    local myPos = getHRP() and getHRP().Position or Vector3.zero

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            local pn = obj.Parent and obj.Parent.Name:lower() or ""
            if n:find("egg") or pn:find("egg") then
                table.insert(eggs, obj)
            end
        elseif obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("steal") or n:find("collect") or n:find("pickup") or n:find("egg") then
                table.insert(remotes, obj)
            end
        end
    end

    state.cachedEggs = eggs
    state.cachedRemotes = remotes
    state.lastScan = tick()
end

local function maybeRescan()
    if tick() - state.lastScan >= CONFIG.rescanInterval then
        scanWorkspace()
    end
end

-- ========== TELEPORT ==========
local function nearestEgg()
    local hrp = getHRP()
    if not hrp then return nil end
    local myPos = hrp.Position
    local best, bestD = nil, math.huge
    for _, egg in ipairs(state.cachedEggs) do
        if egg.Parent then
            local d = (egg.Position - myPos).Magnitude
            if d < bestD then bestD = d; best = egg end
        end
    end
    return best
end

local function teleportToEgg()
    local egg = nearestEgg()
    if not egg then return end
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = egg.CFrame + Vector3.new(0, 3, 0)
    end
end

-- ========== STEAL LOOP ==========
-- fires only cached remotes, on its own interval, not every Heartbeat.
local function startSteal()
    if state.stealConn then state.stealConn:Disconnect() end
    state.stealConn = task.spawn(function()
        while state.enabled and CONFIG.autoSteal do
            maybeRescan()

            if CONFIG.teleportToEgg then
                teleportToEgg()
            end

            for _, remote in ipairs(state.cachedRemotes) do
                if remote.Parent then
                    pcall(function() remote:FireServer() end)
                end
            end

            task.wait(CONFIG.stealInterval)
        end
    end)
end

-- ========== SPEED ==========
-- write once per character, don't re-write every frame — the per-frame
-- write is what trips server-side replication checks.
local function applySpeed()
    local h = getHumanoid()
    if not h then return end
    h.WalkSpeed = CONFIG.speed
    h.JumpPower = CONFIG.speed * 0.8
end

local function startSpeed()
    if state.speedConn then state.speedConn:Disconnect() end
    applySpeed()
    state.speedConn = RunService.Heartbeat:Connect(function()
        if not state.enabled then return end
        local h = getHumanoid()
        if h and h.WalkSpeed ~= CONFIG.speed then
            h.WalkSpeed = CONFIG.speed
            h.JumpPower = CONFIG.speed * 0.8
        end
    end)
end

-- ========== STOP ==========
local function stopAll()
    state.enabled = false
    if state.stealConn then state.stealConn:Disconnect() state.stealConn = nil end
    if state.speedConn then state.speedConn:Disconnect() state.speedConn = nil end
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

Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
title.Text = "VANTA EGG"
title.TextColor3 = Color3.fromRGB(180, 140, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.Parent = frame
Instance.new("UICorner", title).CornerRadius = UDim.new(0, 8)

local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -20, 0, 20)
status.Position = UDim2.new(0, 10, 0, 40)
status.BackgroundTransparency = 1
status.Text = "RUNNING"
status.TextColor3 = Color3.fromRGB(100, 220, 100)
status.Font = Enum.Font.Gotham
status.TextSize = 11
status.Parent = frame

local function mkBtn(text, y, bg)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(1, -20, 0, 35)
    b.Position = UDim2.new(0, 10, 0, y)
    b.BackgroundColor3 = bg or Color3.fromRGB(40, 40, 55)
    b.Text = text
    b.TextColor3 = Color3.fromRGB(200, 200, 220)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = frame
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local toggle = mkBtn("TOGGLE ON/OFF", 70)
toggle.MouseButton1Click:Connect(function()
    state.enabled = not state.enabled
    if state.enabled then
        status.Text = "RUNNING"
        status.TextColor3 = Color3.fromRGB(100, 220, 100)
        startSteal()
        startSpeed()
    else
        status.Text = "STOPPED"
        status.TextColor3 = Color3.fromRGB(220, 100, 100)
        stopAll()
    end
end)

local tpBtn = mkBtn("TP TO EGG", 115)
tpBtn.MouseButton1Click:Connect(teleportToEgg)

local speedLabel = Instance.new("TextLabel")
speedLabel.Size = UDim2.new(1, -20, 0, 20)
speedLabel.Position = UDim2.new(0, 10, 0, 160)
speedLabel.BackgroundTransparency = 1
speedLabel.Text = "Speed: " .. CONFIG.speed
speedLabel.TextColor3 = Color3.fromRGB(150, 150, 170)
speedLabel.Font = Enum.Font.Gotham
speedLabel.TextSize = 11
speedLabel.Parent = frame

local speedBtn = mkBtn("50 | 120 | 300", 185)
speedBtn.TextSize = 10
local speeds = {50, 120, 300}
local speedIndex = 2
speedBtn.MouseButton1Click:Connect(function()
    speedIndex = speedIndex % #speeds + 1
    CONFIG.speed = speeds[speedIndex]
    speedLabel.Text = "Speed: " .. CONFIG.speed
    applySpeed()
end)

local killBtn = mkBtn("STOP ALL", 220, Color3.fromRGB(80, 30, 30))
killBtn.TextColor3 = Color3.fromRGB(220, 150, 150)
killBtn.MouseButton1Click:Connect(function()
    stopAll()
    state.enabled = false
    status.Text = "STOPPED"
    status.TextColor3 = Color3.fromRGB(220, 100, 100)
end)

-- ========== BOOT ==========
enableAntiCheat()
scanWorkspace()
startSteal()
startSpeed()

player.CharacterAdded:Connect(function()
    task.wait(1)
    if state.enabled then
        applySpeed()
    end
end)

print(("[VANTA] loaded. %d eggs, %d remotes cached."):format(#state.cachedEggs, #state.cachedRemotes))
