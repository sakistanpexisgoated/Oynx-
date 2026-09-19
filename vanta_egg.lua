-- language: Lua, file: vanta_egg.lua, target: Roblox Steal An Egg
-- v3: speed capped 190 with bypass, pet egg targeting, best-first priority,
-- clean minimal UI, auto treadmill, egg ESP, auto hatch, auto place

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer

-- ========== CONFIG ==========
local CONFIG = {
    speed = 190,             -- capped, bypassed
    stealInterval = 0.04,
    rescanInterval = 1.5,
    teleportToEgg = true,
    autoSteal = true,
    antiCheatBypass = true,
    bestFirst = true,        -- priority: rarest egg first
    autoTreadmill = false,
    autoHatch = false,
    autoPlace = false,
    eggESP = false,
}

-- rarity priority — higher index = steal first
local RARITY_PRIORITY = {
    ["divine"] = 10, ["eternal"] = 9, ["secret"] = 8,
    ["cosmic"] = 7, ["mythic"] = 6, ["legendary"] = 5,
    ["epic"] = 4, ["rare"] = 3, ["uncommon"] = 2, ["common"] = 1,
}

-- ========== STATE ==========
local state = {
    enabled = true,
    stealConn = nil,
    speedConn = nil,
    originalSpeed = 16,
    originalJump = 50,
    cachedEggs = {},
    cachedRemotes = {},
    cachedHatches = {},
    cachedPlaces = {},
    lastScan = 0,
    espParts = {},
}

-- ========== SAFE GETTERS ==========
local function getHRP()
    local c = player.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function getHumanoid()
    local c = player.Character
    return c and c:FindFirstChildOfClass("Humanoid") or nil
end

-- ========== ANTI-CHEAT BYPASS ==========
local function enableAntiCheat()
    if not CONFIG.antiCheatBypass then return end
    pcall(function()
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
                if n:find("detect") or n:find("report") or n:find("check") or n:find("flag") or n:find("anticheat") then
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)

        setreadonly(mt, true)
    end)
end

-- ========== SCAN ==========
local function scanWorkspace()
    local eggs, remotes, hatches, places = {}, {}, {}, {}
    local hrp = getHRP()
    local myPos = hrp and hrp.Position or Vector3.zero

    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("BasePart") then
            local n = obj.Name:lower()
            local pn = obj.Parent and obj.Parent.Name:lower() or ""
            if n:find("egg") or pn:find("egg") or pn:find("nest") then
                -- detect rarity from name or attributes
                local rarity = "common"
                for r in pairs(RARITY_PRIORITY) do
                    if n:find(r) or pn:find(r) then rarity = r end
                end
                table.insert(eggs, {part = obj, rarity = rarity, dist = (obj.Position - myPos).Magnitude})
            end
        elseif obj:IsA("RemoteEvent") then
            local n = obj.Name:lower()
            if n:find("steal") or n:find("collect") or n:find("pickup") or n:find("grab") then
                table.insert(remotes, obj)
            elseif n:find("hatch") then
                table.insert(hatches, obj)
            elseif n:find("place") or n:find("equip") then
                table.insert(places, obj)
            end
        end
    end

    -- sort eggs by best-first if enabled
    if CONFIG.bestFirst then
        table.sort(eggs, function(a, b)
            local pa = RARITY_PRIORITY[a.rarity] or 0
            local pb = RARITY_PRIORITY[b.rarity] or 0
            if pa ~= pb then return pa > pb end
            return a.dist < b.dist
        end)
    else
        table.sort(eggs, function(a, b) return a.dist < b.dist end)
    end

    state.cachedEggs = eggs
    state.cachedRemotes = remotes
    state.cachedHatches = hatches
    state.cachedPlaces = places
    state.lastScan = tick()
end

local function maybeRescan()
    if tick() - state.lastScan >= CONFIG.rescanInterval then
        scanWorkspace()
    end
end

-- ========== BEST EGG ==========
local function bestEgg()
    for _, e in ipairs(state.cachedEggs) do
        if e.part.Parent then return e end
    end
    return nil
end

local function teleportToBest()
    local e = bestEgg()
    if not e then return end
    local hrp = getHRP()
    if hrp then
        hrp.CFrame = e.part.CFrame + Vector3.new(0, 4, 0)
    end
end

-- ========== ESP ==========
local function clearESP()
    for _, g in ipairs(state.espParts) do
        if g and g.Parent then g:Destroy() end
    end
    state.espParts = {}
end

local function renderESP()
    if not CONFIG.eggESP then clearESP(); return end
    -- lightweight: tag closest 5 eggs only
    for i = 1, math.min(5, #state.cachedEggs) do
        local e = state.cachedEggs[i]
        if e.part.Parent and not e.esp then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 100, 0, 30)
            bb.Adornee = e.part
            bb.AlwaysOnTop = true
            bb.Parent = e.part

            local t = Instance.new("TextLabel")
            t.Size = UDim2.new(1, 0, 1, 0)
            t.BackgroundTransparency = 1
            t.Text = string.upper(e.rarity) .. " | " .. math.floor(e.dist) .. "m"
            t.TextColor3 = Color3.fromRGB(180, 140, 255)
            t.TextStrokeTransparency = 0
            t.Font = Enum.Font.GothamBold
            t.TextSize = 11
            t.Parent = bb

            e.esp = bb
            table.insert(state.espParts, bb)
        end
    end
end

-- ========== STEAL LOOP ==========
local function startSteal()
    if state.stealConn then state.stealConn:Disconnect() end
    state.stealConn = task.spawn(function()
        while state.enabled and CONFIG.autoSteal do
            maybeRescan()
            if CONFIG.eggESP then renderESP() end

            if CONFIG.teleportToEgg then
                teleportToBest()
            end

            -- fire steal remotes targeting the best egg
            local target = bestEgg()
            for _, remote in ipairs(state.cachedRemotes) do
                if remote.Parent then
                    pcall(function()
                        if target and target.part then
                            remote:FireServer(target.part)
                        else
                            remote:FireServer()
                        end
                    end)
                end
            end

            -- auto hatch if enabled and something is ready
            if CONFIG.autoHatch then
                for _, h in ipairs(state.cachedHatches) do
                    if h.Parent then pcall(function() h:FireServer() end) end
                end
            end

            -- auto place if enabled
            if CONFIG.autoPlace then
                for _, p in ipairs(state.cachedPlaces) do
                    if p.Parent then pcall(function() p:FireServer() end) end
                end
            end

            task.wait(CONFIG.stealInterval)
        end
    end)
end

-- ========== SPEED ==========
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

-- ========== TREADMILL ==========
local function startTreadmill()
    if not CONFIG.autoTreadmill then return end
    task.spawn(function()
        while state.enabled and CONFIG.autoTreadmill do
            -- look for treadmill part, stand on it
            local hrp = getHRP()
            if hrp then
                for _, obj in ipairs(workspace:GetDescendants()) do
                    if obj:IsA("BasePart") and obj.Name:lower():find("treadmill") then
                        hrp.CFrame = obj.CFrame + Vector3.new(0, 3, 0)
                        break
                    end
                end
            end
            task.wait(1)
        end
    end)
end

-- ========== STOP ==========
local function stopAll()
    state.enabled = false
    if state.stealConn then state.stealConn:Disconnect() state.stealConn = nil end
    if state.speedConn then state.speedConn:Disconnect() state.speedConn = nil end
    clearESP()
    local h = getHumanoid()
    if h then
        h.WalkSpeed = state.originalSpeed
        h.JumpPower = state.originalJump
    end
end

-- ========== UI (clean minimal) ==========
local gui = Instance.new("ScreenGui")
gui.Name = "VantaEgg"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 240, 0, 340)
main.Position = UDim2.new(0, 20, 0, 100)
main.BackgroundColor3 = Color3.fromRGB(12, 12, 16)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

-- header
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 36)
header.BackgroundColor3 = Color3.fromRGB(20, 20, 28)
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -20, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "VANTA"
title.TextColor3 = Color3.fromRGB(180, 140, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 8, 0, 8)
dot.Position = UDim2.new(1, -20, 0.5, -4)
dot.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
dot.Parent = header
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

-- status line
local status = Instance.new("TextLabel")
status.Size = UDim2.new(1, -28, 0, 18)
status.Position = UDim2.new(0, 14, 0, 42)
status.BackgroundTransparency = 1
status.Text = "speed 190 | best-first | bypass on"
status.TextColor3 = Color3.fromRGB(90, 90, 110)
status.Font = Enum.Font.Gotham
status.TextSize = 10
status.TextXAlignment = Enum.TextXAlignment.Left
status.Parent = main

-- toggle row
local function mkRow(text, y, cb, on)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -28, 0, 32)
    btn.Position = UDim2.new(0, 14, 0, y)
    btn.BackgroundColor3 = on and Color3.fromRGB(40, 35, 60) or Color3.fromRGB(22, 22, 30)
    btn.Text = text
    btn.TextColor3 = on and Color3.fromRGB(180, 140, 255) or Color3.fromRGB(120, 120, 140)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 11
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.Parent = main
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    btn.MouseButton1Click:Connect(function()
        cb()
        btn.BackgroundColor3 = CONFIG[text:lower()] and Color3.fromRGB(40, 35, 60) or Color3.fromRGB(22, 22, 30)
    end)
    return btn
end

mkRow("Auto Steal", 68, function()
    CONFIG.autoSteal = not CONFIG.autoSteal
end)

mkRow("Best First", 104, function()
    CONFIG.bestFirst = not CONFIG.bestFirst
    scanWorkspace()
end)

mkRow("Egg ESP", 140, function()
    CONFIG.eggESP = not CONFIG.eggESP
    if not CONFIG.eggESP then clearESP() end
end)

mkRow("Auto Hatch", 176, function()
    CONFIG.autoHatch = not CONFIG.autoHatch
end)

mkRow("Auto Place", 212, function()
    CONFIG.autoPlace = not CONFIG.autoPlace
end)

-- stop button
local stopBtn = Instance.new("TextButton")
stopBtn.Size = UDim2.new(1, -28, 0, 34)
stopBtn.Position = UDim2.new(0, 14, 0, 254)
stopBtn.BackgroundColor3 = Color3.fromRGB(60, 22, 22)
stopBtn.Text = "STOP ALL"
stopBtn.TextColor3 = Color3.fromRGB(220, 130, 130)
stopBtn.Font = Enum.Font.GothamBold
stopBtn.TextSize = 11
stopBtn.Parent = main
Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0, 6)
stopBtn.MouseButton1Click:Connect(function()
    stopAll()
    state.enabled = false
    dot.BackgroundColor3 = Color3.fromRGB(220, 100, 100)
    status.Text = "stopped"
end)

-- re-enable button (small)
local reBtn = Instance.new("TextButton")
reBtn.Size = UDim2.new(1, -28, 0, 24)
reBtn.Position = UDim2.new(0, 14, 0, 296)
reBtn.BackgroundColor3 = Color3.fromRGB(22, 22, 30)
reBtn.Text = "resume"
reBtn.TextColor3 = Color3.fromRGB(120, 120, 140)
reBtn.Font = Enum.Font.Gotham
reBtn.TextSize = 10
reBtn.Parent = main
Instance.new("UICorner", reBtn).CornerRadius = UDim.new(0, 6)
reBtn.MouseButton1Click:Connect(function()
    if not state.enabled then
        state.enabled = true
        dot.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
        status.Text = "speed 190 | best-first | bypass on"
        startSteal()
        startSpeed()
    end
end)

-- ========== BOOT ==========
enableAntiCheat()
scanWorkspace()
startSteal()
startSpeed()
startTreadmill()

player.CharacterAdded:Connect(function()
    task.wait(1)
    if state.enabled then
        applySpeed()
    end
end)

print(("[VANTA v3] %d eggs | %d remotes | %d hatch | %d place"):format(
    #state.cachedEggs, #state.cachedRemotes, #state.cachedHatches, #state.cachedPlaces))
