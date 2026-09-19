--[[
    Oynx Hub
    Blade Ball - Full Build
    Features: Auto Parry, Auto Clash, Auto Spam, Clash Predictor, Auto Ability,
              Auto Dodge, Parry Chains, Auto Forcefield, Sword Giver, Visuals,
              Ball ESP, Target ESP, Trajectory Line, Ball Trail, Speedometer,
              Player Names ESP, Auto Rejoin, Server Region, Anti-AFK, Config Save/Load,
              Admin Detector, RGB Color Picker, Trade W/L Tracker, Rejoin Last Server
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

-- Startup test notification — remove once confirmed working
pcall(function()
    StarterGui:SetCore("SendNotification", {
        Title = "Oynx Hub",
        Text = "Script started",
        Duration = 3,
    })
end)

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

local HAS_FS = (writefile and readfile and isfile) ~= nil

-- ========== CONFIG ==========
local Config = {
    AutoParry = true,
    AutoClash = true,
    AutoSpam = false,
    ClashPredictor = false,
    AutoAbility = false,
    AutoDodge = false,
    ParryChains = false,
    AutoForcefield = false,
    HumanizeDelay = true,
    ParryWindow = 0.55,
    ParryCooldown = 0.12,
    ClashDistance = 12,
    SpamRate = 50,
    HumanizeMin = 0.03,
    HumanizeMax = 0.10,
    DodgeDistance = 20,
    BallESP = false,
    TargetESP = false,
    TrajectoryLine = false,
    BallTrail = false,
    Speedometer = false,
    PlayerNamesESP = false,
    SwordGiver = false,
    Visuals = false,
    AutoRejoin = false,
    ServerRegion = false,
    AntiAFK = false,
    DiscordRPC = false,
    AdminDetector = false,
    TradeTracker = false,
    EnableGUI = true,
    Debug = false,
    ThemeColor = Color3.fromRGB(14, 14, 16),
}

local AntiKick = { MaxParryPerSecond = 6 }

local parryConnection, clashConnection, spamConnection, espConnection
local adminConnection, predictorConnection, abilityConnection, dodgeConnection
local trailConnection, speedoConnection, nameEspConnection, afkConnection, rejoinConnection
local tradeConnection = nil
local lastParryTime = 0
local parryCount = 0
local lastResetTime = tick()
local lastAbilityCheck = 0
local lastDodgeTime = 0
local Parried = false
local espFolder, trailFolder, speedoGui, nameEspFolder = nil, nil, nil, nil
local uiRefs = {}
local knownAdmins = {}
local lastAbilityState = {}
local lastTradeHash = ""

local CONFIG_FILE = "oynx_hub_config.json"
local JOBS_FILE = "oynx_last_job.txt"

local ADMIN_KEYWORDS = {
    "admin", "mod", "moderator", "owner", "staff", "dev", "developer",
    "manager", "supervisor", "gm", "game master",
}

-- ========== TRADE VALUES ==========
local TradeValues = {
    ["Default Sword"] = 0,
    ["Wooden Sword"] = 0,
    ["Basic Sword"] = 0,
    ["Candy Cane"] = 5,
    ["Ice Dagger"] = 8,
    ["Frostbite"] = 10,
    ["Snowflake"] = 12,
    ["Mythril"] = 15,
    ["Ninja"] = 18,
    ["Yin Yang"] = 20,
    ["Shadow"] = 22,
    ["Dragon"] = 25,
    ["Crystal"] = 28,
    ["Radiant"] = 30,
    ["Raven"] = 32,
    ["Eclipse"] = 35,
    ["Divine"] = 40,
    ["Void"] = 45,
    ["Godly"] = 50,
    ["Reaper"] = 55,
    ["Phantom"] = 60,
    ["Celestial"] = 65,
    ["Abyssal"] = 70,
    ["Infinity"] = 80,
    ["Genesis"] = 90,
    ["Chronos"] = 100,
    ["Omega"] = 110,
    ["Annihilation"] = 120,
    ["The Best Sword"] = 999,
}

local TradeStats = {
    Wins = 0, Losses = 0, Even = 0, Unknown = 0,
    LastResult = "—",
}

local function GetTradeValue(itemName)
    if not itemName then return nil end
    if TradeValues[itemName] then return TradeValues[itemName] end
    local lower = string.lower(itemName)
    for name, val in pairs(TradeValues) do
        if string.find(lower, string.lower(name), 1, true) then
            return val
        end
    end
    return nil
end

-- ========== REMOTES ==========
local Remotes = ReplicatedStorage:WaitForChild("Remotes", 9e9)
local ParryButtonPress = Remotes:WaitForChild("ParryButtonPress", 9e9)
local Abilities = Remotes:FindFirstChild("Abilities")

-- ========== HELPERS ==========
local function Notify(title, text, duration)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = duration or 2,
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

local function GetHRP()
    local char = LocalPlayer.Character
    if char then return char:FindFirstChild("HumanoidRootPart") end
    return nil
end

local function HSVtoRGB(h, s, v) return Color3.fromHSV(h/360, s/100, v/100) end
local function RGBtoHSV(c) local h,s,v = Color3.toHSV(c) return h*360, s*100, v*100 end
local function RGBtoHEX(c) return string.format("#%02X%02X%02X",
    math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)) end

local function FireParry() pcall(function() ParryButtonPress:Fire() end) end

-- ========== CONFIG SAVE / LOAD ==========
local function SaveConfig()
    if not HAS_FS then return end
    pcall(function()
        local data = {}
        for k, v in pairs(Config) do
            if typeof(v) == "Color3" then
                data[k] = {__color = true, r = v.R, g = v.G, b = v.B}
            else
                data[k] = v
            end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

local function LoadConfig()
    if not HAS_FS then return end
    pcall(function()
        if not isfile(CONFIG_FILE) then return end
        local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(data) do
            if type(v) == "table" and v.__color then
                Config[k] = Color3.new(v.r, v.g, v.b)
            else
                Config[k] = v
            end
        end
    end)
end

LoadConfig()
Config.EnableGUI = true  -- force GUI on every load

-- ========== JOB SAVE / REJOIN ==========
local function SaveCurrentJob()
    if not HAS_FS then return end
    pcall(function()
        writefile(JOBS_FILE, game.JobId .. "\n" .. tostring(game.PlaceId))
    end)
end

local function RejoinLastServer()
    if not HAS_FS then
        Notify("Oynx Hub", "Filesystem not supported by executor", 3)
        return
    end
    pcall(function()
        if not isfile(JOBS_FILE) then
            Notify("Oynx Hub", "No saved server", 2)
            return
        end
        local content = readfile(JOBS_FILE)
        local jobId, placeId = string.match(content, "([^\n]+)\n([^\n]+)")
        if not jobId or jobId == "" then
            Notify("Oynx Hub", "Saved server invalid", 2)
            return
        end
        Notify("Oynx Hub", "Rejoining last server...", 2)
        task.wait(1)
        TeleportService:TeleportToPlaceInstance(tonumber(placeId) or game.PlaceId, jobId, LocalPlayer)
    end)
end

-- ========== PARRY ==========
local function ExecuteParry()
    if not Config.AutoParry then return end
    local now = tick()
    if now - lastParryTime < Config.ParryCooldown then return end
    if now - lastResetTime > 1 then parryCount = 0; lastResetTime = now end
    if parryCount >= AntiKick.MaxParryPerSecond then return end
    lastParryTime = now
    parryCount = parryCount + 1
    if Config.HumanizeDelay then
        local delay = math.random() * (Config.HumanizeMax - Config.HumanizeMin) + Config.HumanizeMin
        task.wait(delay)
    end
    FireParry()
    if Config.Debug then print("[Oynx] Parry fired") end
end

-- ========== CLASH ==========
local function ExecuteClash()
    if not Config.AutoClash then return end
    local ball, hrp = GetBall(), GetHRP()
    if not ball or not hrp then return end
    if (hrp.Position - ball.Position).Magnitude <= Config.ClashDistance then
        FireParry()
    end
end

-- ========== SPAM ==========
local function StartSpam()
    if spamConnection then spamConnection:Disconnect() end
    if not Config.AutoSpam then return end
    spamConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoSpam then return end
        FireParry()
        task.wait(1 / Config.SpamRate)
    end)
end

-- ========== CLASH PREDICTOR ==========
local function StartClashPredictor()
    if predictorConnection then predictorConnection:Disconnect() end
    if not Config.ClashPredictor then return end
    local lastPositions = {}
    predictorConnection = RunService.PreSimulation:Connect(function()
        if not Config.ClashPredictor then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then return end
        local id = ball:GetDebugId()
        local lastPos = lastPositions[id]
        local curPos = ball.Position
        lastPositions[id] = curPos
        if not lastPos then return end
        local delta = curPos - lastPos
        local predicted = curPos + delta
        local distNow = (hrp.Position - curPos).Magnitude
        local distNext = (hrp.Position - predicted).Magnitude
        if distNow < 25 and distNext < distNow and (distNow - distNext) > 0.5 then
            local approach = (hrp.Position - curPos).Unit
            if approach:Dot(delta.Unit) > 0.7 then FireParry() end
        end
    end)
end

-- ========== AUTO ABILITY ==========
local function StartAutoAbility()
    if abilityConnection then abilityConnection:Disconnect() end
    if not Config.AutoAbility then return end
    abilityConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoAbility then return end
        local now = tick()
        if now - lastAbilityCheck < 0.5 then return end
        lastAbilityCheck = now
        pcall(function()
            if Abilities then
                for _, remote in ipairs(Abilities:GetChildren()) do
                    if remote:IsA("RemoteEvent") then
                        local key = remote.Name
                        if not lastAbilityState[key] or now - lastAbilityState[key] > 5 then
                            remote:FireServer()
                            lastAbilityState[key] = now
                        end
                    end
                end
            end
        end)
    end)
end

-- ========== AUTO DODGE ==========
local function StartAutoDodge()
    if dodgeConnection then dodgeConnection:Disconnect() end
    if not Config.AutoDodge then return end
    dodgeConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoDodge then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then return end
        if ball:GetAttribute("target") ~= LocalPlayer.Name then return end
        local dist = (hrp.Position - ball.Position).Magnitude
        if dist < Config.DodgeDistance and dist > 8 then
            local now = tick()
            if now - lastDodgeTime < 0.3 then return end
            lastDodgeTime = now
            local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if humanoid then
                local side = math.random() > 0.5 and 1 or -1
                local perp = (hrp.CFrame.RightVector * side).Unit
                pcall(function() humanoid:MoveTo(hrp.Position + perp * 12) end)
            end
        end
    end)
end

-- ========== PARRY CHAINS ==========
local function StartParryChains()
    local lastChainFire = 0
    RunService.PreSimulation:Connect(function()
        if not Config.ParryChains then return end
        local ballsFolder = Workspace:FindFirstChild("Balls")
        if not ballsFolder then return end
        local targeting = 0
        for _, b in ipairs(ballsFolder:GetChildren()) do
            if b:IsA("BasePart") and b:GetAttribute("target") == LocalPlayer.Name then
                targeting = targeting + 1
            end
        end
        if targeting > 1 then
            local now = tick()
            if now - lastChainFire > 0.15 then
                lastChainFire = now
                FireParry()
            end
        end
    end)
end

-- ========== AUTO FORCEFIELD ==========
local function StartAutoForcefield()
    RunService.PreSimulation:Connect(function()
        if not Config.AutoForcefield then return end
        local ball = GetBall()
        if not ball then return end
        if ball:GetAttribute("target") ~= LocalPlayer.Name then return end
        local hrp = GetHRP()
        if not hrp then return end
        if (hrp.Position - ball.Position).Magnitude < 30 then
            pcall(function()
                if Abilities then
                    local ff = Abilities:FindFirstChild("Forcefield") or Abilities:FindFirstChild("ForceField")
                    if ff then ff:FireServer() end
                end
            end)
        end
    end)
end

-- ========== SWORD GIVER ==========
local function GiveSwords()
    if not Config.SwordGiver then return end
    pcall(function()
        local backpack = LocalPlayer:FindFirstChild("Backpack")
        if backpack then
            for _, item in ipairs(backpack:GetChildren()) do
                if item:IsA("Tool") and item.Name:find("Sword") then
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):EquipTool(item)
                end
            end
        end
    end)
end

-- ========== VISUALS ==========
local function ApplyVisuals()
    if not Config.Visuals then return end
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then
        head.Transparency = 1
        for _, c in ipairs(head:GetChildren()) do
            if c:IsA("Decal") then c.Transparency = 1 end
        end
    end
    pcall(function()
        for _, acc in ipairs(char:GetChildren()) do
            if acc:IsA("Accessory") then acc:Destroy() end
        end
    end)
end

-- ========== ADMIN DETECTOR ==========
local function IsAdminName(name)
    local lower = string.lower(name)
    for _, kw in ipairs(ADMIN_KEYWORDS) do
        if string.find(lower, kw, 1, true) then return true end
    end
    return false
end

local function CheckPlayer(player)
    if player == LocalPlayer then return end
    if not IsAdminName(player.Name) and not IsAdminName(player.DisplayName) then return end
    if knownAdmins[player.UserId] then return end
    knownAdmins[player.UserId] = true
    Notify("Oynx Hub", "A admin of the game has joined you will rejoin and will be putted in a new srv", 6)
    task.wait(2)
    pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
end

local function StartAdminWatch()
    if adminConnection then adminConnection:Disconnect() end
    if not Config.AdminDetector then return end
    for _, p in ipairs(Players:GetPlayers()) do CheckPlayer(p) end
    adminConnection = Players.PlayerAdded:Connect(function(p)
        if Config.AdminDetector then CheckPlayer(p) end
    end)
end

-- ========== TRADE W/L TRACKER ==========
local function GetTradeItems()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if not playerGui then return nil, nil end

    local function scan(root)
        local items = {}
        if not root then return items end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text and #d.Text > 0 then
                local lower = string.lower(d.Text)
                if string.find(lower, "sword") or string.find(lower, "blade")
                   or string.find(lower, "dagger") or string.find(lower, "scythe") then
                    table.insert(items, d.Text)
                end
            end
        end
        return items
    end

    local tradeGui = playerGui:FindFirstChild("Trade") or playerGui:FindFirstChild("TradeGui")
    if not tradeGui then return nil, nil end

    local theirSide = tradeGui:FindFirstChild("TheirOffer") or tradeGui:FindFirstChild("Other")
    local mySide = tradeGui:FindFirstChild("MyOffer") or tradeGui:FindFirstChild("Mine")

    return scan(mySide), scan(theirSide)
end

local function EvaluateTrade()
    if not Config.TradeTracker then return nil end
    local myItems, theirItems = GetTradeItems()
    if not myItems or not theirItems then return nil end
    if #myItems == 0 and #theirItems == 0 then return nil end

    local hash = table.concat(myItems, ",") .. "|" .. table.concat(theirItems, ",")
    if hash == lastTradeHash then return nil end
    lastTradeHash = hash

    local myVal, theirVal = 0, 0
    local unknown = false

    for _, n in ipairs(myItems) do
        local v = GetTradeValue(n)
        if v then myVal = myVal + v else unknown = true end
    end
    for _, n in ipairs(theirItems) do
        local v = GetTradeValue(n)
        if v then theirVal = theirVal + v else unknown = true end
    end

    local result
    if unknown and myVal == 0 and theirVal == 0 then result = "unknown"
    elseif theirVal > myVal then result = "win"
    elseif theirVal < myVal then result = "loss"
    else result = "even" end

    if result == "win" then TradeStats.Wins = TradeStats.Wins + 1
    elseif result == "loss" then TradeStats.Losses = TradeStats.Losses + 1
    elseif result == "even" then TradeStats.Even = TradeStats.Even + 1
    else TradeStats.Unknown = TradeStats.Unknown + 1 end

    TradeStats.LastResult = result:upper()
    Notify("Oynx Hub", "Trade: " .. result:upper() .. " (you " .. myVal .. " / them " .. theirVal .. ")", 4)
    return result
end

local function StartTradeTracker()
    if tradeConnection then tradeConnection:Disconnect() end
    tradeConnection = RunService.Heartbeat:Connect(function()
        pcall(EvaluateTrade)
    end)
end

-- ========== ESP ==========
local function StartESP()
    if espConnection then espConnection:Disconnect() end
    if espFolder then espFolder:Destroy() end
    if not (Config.BallESP or Config.TargetESP) then return end
    espFolder = Instance.new("Folder")
    espFolder.Name = "OynxHubESP"
    espFolder.Parent = Workspace
    espConnection = RunService.RenderStepped:Connect(function()
        for _, obj in ipairs(espFolder:GetChildren()) do obj:Destroy() end
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
                local tp = Players:FindFirstChild(ball:GetAttribute("target"))
                if tp and tp.Character then
                    local hl = Instance.new("Highlight")
                    hl.Adornee = tp.Character
                    hl.FillColor = Color3.fromRGB(255, 0, 0)
                    hl.OutlineColor = Color3.fromRGB(255, 255, 255)
                    hl.FillTransparency = 0.6
                    hl.Parent = espFolder
                end
            end
        end
    end)
end

-- ========== TRAJECTORY LINE ==========
local function StartTrajectoryLine()
    if trailConnection then trailConnection:Disconnect() end
    if trailFolder then trailFolder:Destroy() end
    if not Config.TrajectoryLine then return end
    trailFolder = Instance.new("Folder")
    trailFolder.Name = "OynxTrajectory"
    trailFolder.Parent = Workspace
    trailConnection = RunService.RenderStepped:Connect(function()
        for _, obj in ipairs(trailFolder:GetChildren()) do obj:Destroy() end
        local ball = GetBall()
        if not ball then return end
        local velocity = ball.AssemblyLinearVelocity
        if velocity.Magnitude < 1 then return end
        local from = ball.Position
        local to = from + velocity * 2
        local mid = from + (to - from) / 2
        local part = Instance.new("Part")
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Size = Vector3.new(0.2, 0.2, (to - from).Magnitude)
        part.CFrame = CFrame.lookAt(mid, to)
        part.Color = Color3.fromRGB(255, 100, 100)
        part.Transparency = 0.5
        part.Parent = trailFolder
    end)
end

-- ========== BALL TRAIL ==========
local function StartBallTrail()
    local ballPath = {}
    RunService.Heartbeat:Connect(function()
        if not Config.BallTrail then ballPath = {} return end
        local ball = GetBall()
        if not ball then ballPath = {} return end
        table.insert(ballPath, {pos = ball.Position, time = tick()})
        local now = tick()
        local filtered = {}
        for _, p in ipairs(ballPath) do
            if now - p.time < 2 then table.insert(filtered, p) end
        end
        ballPath = filtered
        if trailFolder and #ballPath > 1 then
            for i = 2, #ballPath do
                local a, b = ballPath[i-1].pos, ballPath[i].pos
                local seg = Instance.new("Part")
                seg.Anchored = true
                seg.CanCollide = false
                seg.Material = Enum.Material.Neon
                seg.Size = Vector3.new(0.15, 0.15, (a - b).Magnitude)
                seg.CFrame = CFrame.lookAt((a + b) / 2, b)
                seg.Color = Color3.fromRGB(255, 200, 50)
                seg.Transparency = 0.6
                seg.Parent = trailFolder or Workspace
                game:GetService("Debris"):AddItem(seg, 0.3)
            end
        end
    end)
end

-- ========== SPEEDOMETER ==========
local function StartSpeedometer()
    if speedoConnection then speedoConnection:Disconnect() end
    if speedoGui then speedoGui:Destroy() end
    if not Config.Speedometer then return end

    speedoGui = Instance.new("ScreenGui")
    speedoGui.ResetOnSpawn = false
    speedoGui.Name = "OynxSpeedo"
    speedoGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    if gethui then pcall(function() speedoGui.Parent = gethui() end) end
    if not speedoGui.Parent then pcall(function() speedoGui.Parent = CoreGui end) end
    if not speedoGui.Parent then speedoGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 200, 0, 90)
    frame.Position = UDim2.new(0, 20, 0.5, -45)
    frame.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
    frame.BackgroundTransparency = 0.2
    frame.BorderSizePixel = 0
    frame.Parent = speedoGui

    local fc = Instance.new("UICorner")
    fc.CornerRadius = UDim.new(0, 6)
    fc.Parent = frame

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text = "Speed: 0\nDistance: 0\nETA: 0.00s"
    lbl.TextColor3 = Color3.fromRGB(230, 230, 235)
    lbl.TextSize = 14
    lbl.Font = Enum.Font.GothamMedium
    lbl.Parent = frame

    speedoConnection = RunService.Heartbeat:Connect(function()
        if not Config.Speedometer then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then
            lbl.Text = "Speed: —\nDistance: —\nETA: —"
            return
        end
        local speed = ball.AssemblyLinearVelocity.Magnitude
        local dist = (hrp.Position - ball.Position).Magnitude
        local eta = speed > 0 and (dist / speed) or 0
        lbl.Text = string.format("Speed: %.1f\nDistance: %.1f\nETA: %.2fs", speed, dist, eta)
    end)
end

-- ========== PLAYER NAMES ESP ==========
local function StartPlayerNamesESP()
    if nameEspConnection then nameEspConnection:Disconnect() end
    if nameEspFolder then nameEspFolder:Destroy() end
    if not Config.PlayerNamesESP then return end
    nameEspFolder = Instance.new("Folder")
    nameEspFolder.Name = "OynxNames"
    nameEspFolder.Parent = Workspace
    nameEspConnection = RunService.RenderStepped:Connect(function()
        for _, obj in ipairs(nameEspFolder:GetChildren()) do obj:Destroy() end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local head = player.Character:FindFirstChild("Head")
                if head then
                    local bb = Instance.new("BillboardGui")
                    bb.Adornee = head
                    bb.Size = UDim2.new(0, 120, 0, 20)
                    bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.AlwaysOnTop = true
                    bb.Parent = nameEspFolder
                    local nameLbl = Instance.new("TextLabel")
                    nameLbl.Size = UDim2.new(1, 0, 1, 0)
                    nameLbl.BackgroundTransparency = 1
                    nameLbl.Text = player.Name
                    nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
                    nameLbl.TextStrokeTransparency = 0
                    nameLbl.TextSize = 14
                    nameLbl.Font = Enum.Font.GothamBold
                    nameLbl.Parent = bb
                end
            end
        end
    end)
end

-- ========== AUTO REJOIN ==========
local function StartAutoRejoin()
    if rejoinConnection then rejoinConnection:Disconnect() end
    if not Config.AutoRejoin then return end
    rejoinConnection = LocalPlayer.CharacterAdded:Connect(function()
        if Config.AutoRejoin then
            task.wait(2)
            pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
        end
    end)
end

-- ========== SERVER REGION ==========
local function StartServerRegion()
    RunService.Heartbeat:Connect(function()
        if not Config.ServerRegion then return end
        pcall(function()
            -- stub: real region-hopping requires external API
        end)
    end)
end

-- ========== ANTI-AFK ==========
local function StartAntiAFK()
    if afkConnection then afkConnection:Disconnect() end
    if not Config.AntiAFK then return end
    afkConnection = LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end)
end

-- ========== DISCORD RPC ==========
local function StartDiscordRPC()
    if not Config.DiscordRPC then return end
    pcall(function()
        print("[Oynx] Discord RPC requested: Blade Ball — Oynx Hub")
    end)
end

-- ========== MAIN LOOPS ==========
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
        local Ball, hrp = GetBall(), GetHRP()
        if not Ball or not hrp then return end
        if Ball:GetAttribute("target") ~= LocalPlayer.Name then return end
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

local function StartClashLoop()
    if clashConnection then clashConnection:Disconnect() end
    clashConnection = RunService.Heartbeat:Connect(function()
        if Config.AutoClash then ExecuteClash() end
    end)
end

-- ========== UI ==========
local function CreateUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.ResetOnSpawn = false
    screenGui.Name = "R_" .. tostring(math.random(100000, 999999))
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.IgnoreGuiInset = true

    local parented = false
    if gethui then
        parented = pcall(function() screenGui.Parent = gethui() end)
    end
    if not parented then
        parented = pcall(function() screenGui.Parent = CoreGui end)
    end
    if not parented then
        pcall(function() screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end)
    end

    local COL_BG = Config.ThemeColor
    local COL_PANEL = Config.ThemeColor:Lerp(Color3.fromRGB(255, 255, 255), 0.05)
    local COL_SIDEBAR = Config.ThemeColor:Lerp(Color3.fromRGB(0, 0, 0), 0.15)
    local COL_STROKE = Color3.fromRGB(40, 40, 46)
    local COL_TEXT = Color3.fromRGB(230, 230, 235)
    local COL_MUTED = Color3.fromRGB(130, 130, 140)
    local COL_ACCENT = Color3.fromRGB(0, 170, 255)
    local COL_GREEN = Color3.fromRGB(50, 210, 120)
    local COL_RED = Color3.fromRGB(220, 60, 60)

    local W = IsMobile and 420 or 640
    local H = IsMobile and 300 or 420
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

    local topBar = Instance.new("Frame")
    topBar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
    topBar.BackgroundColor3 = COL_SIDEBAR
    topBar.BorderSizePixel = 0
    topBar.Parent = main

    local topCorner = Instance.new("UICorner")
    topCorner.CornerRadius = UDim.new(0, 8)
    topCorner.Parent = topBar

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
    title.Text = "Oynx Hub  |  Blade Ball"
    title.TextColor3 = COL_TEXT
    title.TextSize = 13
    title.Font = Enum.Font.GothamMedium
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = topBar

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
        SaveConfig()
        screenGui:Destroy()
    end)

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H - 12)
    sidebar.Position = UDim2.new(0, 6, 0, TOPBAR_H + 6)
    sidebar.BackgroundColor3 = COL_SIDEBAR
    sidebar.BorderSizePixel = 0
    sidebar.Parent = main

    local sideCorner = Instance.new("UICorner")
    sideCorner.CornerRadius = UDim.new(0, 6)
    sideCorner.Parent = sidebar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -SIDEBAR_W - 18, 1, -TOPBAR_H - 12)
    content.Position = UDim2.new(0, SIDEBAR_W + 12, 0, TOPBAR_H + 6)
    content.BackgroundColor3 = COL_PANEL
    content.BorderSizePixel = 0
    content.Parent = main

    local contentCorner = Instance.new("UICorner")
    contentCorner.CornerRadius = UDim.new(0, 6)
    contentCorner.Parent = content

    local pages = {}

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
        for n, p in pairs(pages) do p.Visible = (n == name) end
    end

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

    local function addToggle(parent, label, key, yOffset, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34)
        row.Position = UDim2.new(0, 0, 0, yOffset)
        row.BackgroundColor3 = COL_BG
        row.BorderSizePixel = 0
        row.Parent = parent
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row

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

    local function addSlider(parent, label, min, max, default, yOffset, callback)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48)
        row.Position = UDim2.new(0, 0, 0, yOffset)
        row.BackgroundColor3 = COL_BG
        row.BorderSizePixel = 0
        row.Parent = parent
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row

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
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = track

        local pct = (default - min) / (max - min)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(pct, 0, 1, 0)
        fill.BackgroundColor3 = COL_ACCENT
        fill.BorderSizePixel = 0
        fill.Parent = track
        local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill

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
            if input.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end
        end)
        return row
    end

    local sidebarButtons = {}

    local function addSidebarButton(name, icon, yOffset)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, -12, 0, 34)
        btn.Position = UDim2.new(0, 6, 0, yOffset)
        btn.BackgroundColor3 = COL_SIDEBAR
        btn.Text = ""
        btn.BorderSizePixel = 0
        btn.Parent = sidebar
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 5); bc.Parent = btn

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

    local homePage = newPage("Home")
    local combatPage = newPage("Combat")
    local visualPage = newPage("Visual")
    local utilityPage = newPage("Utility")
    local settingsPage = newPage("Settings")

    -- HOME
    addSection(homePage, "WELCOME", 0)
    local welcome = Instance.new("TextLabel")
    welcome.Size = UDim2.new(1, 0, 0, 60)
    welcome.Position = UDim2.new(0, 0, 0, 26)
    welcome.BackgroundColor3 = COL_BG
    welcome.Text = "Oynx Hub running. Detection locked.\nPlatform: " .. Platform
    welcome.TextColor3 = COL_MUTED
    welcome.TextSize = 11
    welcome.Font = Enum.Font.Gotham
    welcome.TextWrapped = true
    welcome.Parent = homePage
    local wC = Instance.new("UICorner"); wC.CornerRadius = UDim.new(0, 5); wC.Parent = welcome

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
    local sC = Instance.new("UICorner"); sC.CornerRadius = UDim.new(0, 5); sC.Parent = statusLbl

    addSection(homePage, "TRADE TRACKER", 176)
    local tradeStatsLbl = Instance.new("TextLabel")
    tradeStatsLbl.Size = UDim2.new(1, 0, 0, 76)
    tradeStatsLbl.Position = UDim2.new(0, 0, 0, 202)
    tradeStatsLbl.BackgroundColor3 = COL_BG
    tradeStatsLbl.Text = "W: 0   L: 0   Even: 0   ?: 0\nLast: —"
    tradeStatsLbl.TextColor3 = COL_TEXT
    tradeStatsLbl.TextSize = 11
    tradeStatsLbl.Font = Enum.Font.Gotham
    tradeStatsLbl.TextWrapped = true
    tradeStatsLbl.Parent = homePage
    local tsC = Instance.new("UICorner"); tsC.CornerRadius = UDim.new(0, 5); tsC.Parent = tradeStatsLbl

    task.spawn(function()
        while tradeStatsLbl.Parent do
            tradeStatsLbl.Text = string.format(
                "W: %d   L: %d   Even: %d   ?: %d\nLast: %s",
                TradeStats.Wins, TradeStats.Losses,
                TradeStats.Even, TradeStats.Unknown,
                TradeStats.LastResult
            )
            tradeStatsLbl.TextColor3 = (TradeStats.LastResult == "WIN") and COL_GREEN
                or (TradeStats.LastResult == "LOSS") and COL_RED
                or COL_TEXT
            task.wait(1)
        end
    end)

    -- COMBAT
    addSection(combatPage, "CORE", 0)
    addToggle(combatPage, "Auto Parry", "AutoParry", 26, function(v)
        statusLbl.Text = v and "● Auto Parry ON" or "● Auto Parry OFF"
        statusLbl.TextColor3 = v and COL_GREEN or COL_RED
    end)
    addToggle(combatPage, "Auto Clash", "AutoClash", 62)
    addToggle(combatPage, "Auto Spam", "AutoSpam", 98, function(v) StartSpam() end)
    addToggle(combatPage, "Humanize Delay", "HumanizeDelay", 134)

    addSection(combatPage, "ADVANCED", 180)
    addToggle(combatPage, "Clash Predictor", "ClashPredictor", 206, function(v) if v then StartClashPredictor() end end)
    addToggle(combatPage, "Auto Ability", "AutoAbility", 242, function(v) if v then StartAutoAbility() end end)
    addToggle(combatPage, "Auto Dodge", "AutoDodge", 278, function(v) if v then StartAutoDodge() end end)
    addToggle(combatPage, "Parry Chains", "ParryChains", 314)
    addToggle(combatPage, "Auto Forcefield", "AutoForcefield", 350)

    addSection(combatPage, "TUNING", 396)
    addSlider(combatPage, "Parry Window", 0.3, 0.9, Config.ParryWindow, 422, function(v) Config.ParryWindow = v end)
    addSlider(combatPage, "Parry Cooldown", 0.05, 0.3, Config.ParryCooldown, 470, function(v) Config.ParryCooldown = v end)
    addSlider(combatPage, "Clash Distance", 5, 30, Config.ClashDistance, 518, function(v) Config.ClashDistance = v end)
    addSlider(combatPage, "Dodge Distance", 10, 40, Config.DodgeDistance, 566, function(v) Config.DodgeDistance = v end)
    addSlider(combatPage, "Spam Rate", 10, 200, Config.SpamRate, 614, function(v) Config.SpamRate = v end)

    addSection(combatPage, "DETECTION", 660)
    addToggle(combatPage, "Admin Detector", "AdminDetector", 686, function(v)
        if v then StartAdminWatch() end
    end)

    -- VISUAL
    addSection(visualPage, "ESP", 0)
    addToggle(visualPage, "Ball ESP", "BallESP", 26, function() StartESP() end)
    addToggle(visualPage, "Target ESP", "TargetESP", 62, function() StartESP() end)
    addToggle(visualPage, "Player Names ESP", "PlayerNamesESP", 98, function() StartPlayerNamesESP() end)

    addSection(visualPage, "BALL TRACKING", 144)
    addToggle(visualPage, "Trajectory Line", "TrajectoryLine", 170, function() StartTrajectoryLine() end)
    addToggle(visualPage, "Ball Trail (2s)", "BallTrail", 206)
    addToggle(visualPage, "Speedometer HUD", "Speedometer", 242, function() StartSpeedometer() end)

    addSection(visualPage, "AVATAR", 288)
    addToggle(visualPage, "Sword Giver", "SwordGiver", 314, function(v) if v then GiveSwords() end end)
    addToggle(visualPage, "Visuals (Headless/Korblox)", "Visuals", 350, function(v) if v then ApplyVisuals() end end)

    -- UTILITY
    addSection(utilityPage, "AUTOMATION", 0)
    addToggle(utilityPage, "Auto Rejoin on Death", "AutoRejoin", 26, function(v) if v then StartAutoRejoin() end end)
    addToggle(utilityPage, "Server Region Selector", "ServerRegion", 62, function(v) if v then StartServerRegion() end end)
    addToggle(utilityPage, "Anti-AFK", "AntiAFK", 98, function(v) if v then StartAntiAFK() end end)
    addToggle(utilityPage, "Discord RPC", "DiscordRPC", 134, function(v) if v then StartDiscordRPC() end end)
    addToggle(utilityPage, "Trade W/L Tracker", "TradeTracker", 170, function(v)
        if v then StartTradeTracker() end
    end)

    addSection(utilityPage, "CONFIG", 216)
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(1, 0, 0, 34)
    saveBtn.Position = UDim2.new(0, 0, 0, 242)
    saveBtn.BackgroundColor3 = COL_ACCENT
    saveBtn.Text = "Save Config"
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.BorderSizePixel = 0
    saveBtn.Parent = utilityPage
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 5); sc.Parent = saveBtn
    saveBtn.MouseButton1Click:Connect(function()
        SaveConfig()
        Notify("Oynx Hub", "Config saved", 2)
    end)

    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(1, 0, 0, 34)
    loadBtn.Position = UDim2.new(0, 0, 0, 282)
    loadBtn.BackgroundColor3 = COL_PANEL
    loadBtn.Text = "Load Config"
    loadBtn.TextColor3 = COL_TEXT
    loadBtn.TextSize = 12
    loadBtn.Font = Enum.Font.GothamBold
    loadBtn.BorderSizePixel = 0
    loadBtn.Parent = utilityPage
    local lc = Instance.new("UICorner"); lc.CornerRadius = UDim.new(0, 5); lc.Parent = loadBtn
    loadBtn.MouseButton1Click:Connect(function()
        LoadConfig()
        Notify("Oynx Hub", "Config loaded", 2)
    end)

    addSection(utilityPage, "SERVER", 336)
    local rejoinBtn = Instance.new("TextButton")
    rejoinBtn.Size = UDim2.new(1, 0, 0, 34)
    rejoinBtn.Position = UDim2.new(0, 0, 0, 362)
    rejoinBtn.BackgroundColor3 = COL_ACCENT
    rejoinBtn.Text = "Rejoin Last Server"
    rejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    rejoinBtn.TextSize = 12
    rejoinBtn.Font = Enum.Font.GothamBold
    rejoinBtn.BorderSizePixel = 0
    rejoinBtn.Parent = utilityPage
    local rjC = Instance.new("UICorner"); rjC.CornerRadius = UDim.new(0, 5); rjC.Parent = rejoinBtn
    rejoinBtn.MouseButton1Click:Connect(function()
        SaveCurrentJob()
        task.wait(0.5)
        RejoinLastServer()
    end)

    local saveJobBtn = Instance.new("TextButton")
    saveJobBtn.Size = UDim2.new(1, 0, 0, 34)
    saveJobBtn.Position = UDim2.new(0, 0, 0, 402)
    saveJobBtn.BackgroundColor3 = COL_PANEL
    saveJobBtn.Text = "Save Current Server"
    saveJobBtn.TextColor3 = COL_TEXT
    saveJobBtn.TextSize = 12
    saveJobBtn.Font = Enum.Font.GothamBold
    saveJobBtn.BorderSizePixel = 0
    saveJobBtn.Parent = utilityPage
    local sjC = Instance.new("UICorner"); sjC.CornerRadius = UDim.new(0, 5); sjC.Parent = saveJobBtn
    saveJobBtn.MouseButton1Click:Connect(function()
        SaveCurrentJob()
        Notify("Oynx Hub", "Server saved", 2)
    end)

    -- SETTINGS
    addSection(settingsPage, "GENERAL", 0)
    addToggle(settingsPage, "Debug Notifications", "Debug", 26)

    addSection(settingsPage, "UI COLOR PICKER", 70)

    local pickerFrame = Instance.new("Frame")
    pickerFrame.Size = UDim2.new(1, 0, 0, 280)
    pickerFrame.Position = UDim2.new(0, 0, 0, 96)
    pickerFrame.BackgroundColor3 = COL_BG
    pickerFrame.BorderSizePixel = 0
    pickerFrame.Parent = settingsPage
    local pfC = Instance.new("UICorner"); pfC.CornerRadius = UDim.new(0, 6); pfC.Parent = pickerFrame

    local wheel = Instance.new("ImageLabel")
    wheel.Size = UDim2.new(0, 160, 0, 160)
    wheel.Position = UDim2.new(0, 10, 0, 10)
    wheel.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    wheel.BorderSizePixel = 0
    wheel.Image = "rbxassetid://5655816373"
    wheel.Parent = pickerFrame
    local wcc = Instance.new("UICorner"); wcc.CornerRadius = UDim.new(1, 0); wcc.Parent = wheel

    local wheelStroke = Instance.new("UIStroke")
    wheelStroke.Color = COL_STROKE
    wheelStroke.Thickness = 2
    wheelStroke.Parent = wheel

    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0, 10, 0, 10)
    marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    marker.BorderSizePixel = 2
    marker.BorderColor3 = Color3.fromRGB(0, 0, 0)
    marker.Position = UDim2.new(0, 85, 0, 85)
    marker.Parent = wheel
    local mC = Instance.new("UICorner"); mC.CornerRadius = UDim.new(1, 0); mC.Parent = marker

    local brightTrack = Instance.new("Frame")
    brightTrack.Size = UDim2.new(0, 16, 0, 160)
    brightTrack.Position = UDim2.new(0, 180, 0, 10)
    brightTrack.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    brightTrack.BorderSizePixel = 0
    brightTrack.Parent = pickerFrame
    local bC = Instance.new("UICorner"); bC.CornerRadius = UDim.new(1, 0); bC.Parent = brightTrack

    local brightGrad = Instance.new("UIGradient")
    brightGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    brightGrad.Rotation = 90
    brightGrad.Parent = brightTrack

    local brightKnob = Instance.new("Frame")
    brightKnob.Size = UDim2.new(0, 20, 0, 20)
    brightKnob.Position = UDim2.new(0, -2, 0, 0)
    brightKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    brightKnob.BorderSizePixel = 2
    brightKnob.BorderColor3 = Color3.fromRGB(0, 0, 0)
    brightKnob.Parent = brightTrack
    local bkC = Instance.new("UICorner"); bkC.CornerRadius = UDim.new(1, 0); bkC.Parent = brightKnob

    local tabHolder = Instance.new("Frame")
    tabHolder.Size = UDim2.new(1, -20, 0, 26)
    tabHolder.Position = UDim2.new(0, 10, 0, 180)
    tabHolder.BackgroundTransparency = 1
    tabHolder.Parent = pickerFrame

    local tabs = {}
    local tabNames = {"RGB", "HSV", "HEX"}
    local tabW = 1 / #tabNames
    for i, name in ipairs(tabNames) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(tabW, -4, 1, 0)
        tb.Position = UDim2.new((i - 1) * tabW, 2, 0, 0)
        tb.BackgroundColor3 = COL_SIDEBAR
        tb.Text = name
        tb.TextColor3 = COL_MUTED
        tb.TextSize = 11
        tb.Font = Enum.Font.GothamMedium
        tb.BorderSizePixel = 0
        tb.Parent = tabHolder
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(0, 4); tc.Parent = tb
        tabs[name] = tb
    end

    local valueHolder = Instance.new("Frame")
    valueHolder.Size = UDim2.new(1, -20, 0, 60)
    valueHolder.Position = UDim2.new(0, 10, 0, 212)
    valueHolder.BackgroundTransparency = 1
    valueHolder.Parent = pickerFrame

    local function makeValueRow(label, yOff)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 16)
        row.Position = UDim2.new(0, 0, 0, yOff)
        row.BackgroundTransparency = 1
        row.Parent = valueHolder
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.5, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = label
        lbl.TextColor3 = COL_MUTED
        lbl.TextSize = 11
        lbl.Font = Enum.Font.Gotham
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = row
        local val = Instance.new("TextLabel")
        val.Size = UDim2.new(0.5, 0, 1, 0)
        val.Position = UDim2.new(0.5, 0, 0, 0)
        val.BackgroundTransparency = 1
        val.Text = "0"
        val.TextColor3 = COL_TEXT
        val.TextSize = 11
        val.Font = Enum.Font.GothamMedium
        val.TextXAlignment = Enum.TextXAlignment.Right
        val.Parent = row
        return val
    end

    local rgbR = makeValueRow("R:", 0)
    local rgbG = makeValueRow("G:", 20)
    local rgbB = makeValueRow("B:", 40)
    local hsvH = makeValueRow("H:", 0)
    local hsvS = makeValueRow("S:", 20)
    local hsvV = makeValueRow("V:", 40)

    local hexRow = Instance.new("TextLabel")
    hexRow.Size = UDim2.new(1, 0, 1, 0)
    hexRow.BackgroundTransparency = 1
    hexRow.Text = "#0E0E10"
    hexRow.TextColor3 = COL_TEXT
    hexRow.TextSize = 14
    hexRow.Font = Enum.Font.GothamBold
    hexRow.Parent = valueHolder

    local function showTab(name)
        for n, tb in pairs(tabs) do
            tb.TextColor3 = (n == name) and COL_TEXT or COL_MUTED
            tb.BackgroundColor3 = (n == name) and COL_PANEL or COL_SIDEBAR
        end
        rgbR.Parent.Visible = (name == "RGB")
        rgbG.Parent.Visible = (name == "RGB")
        rgbB.Parent.Visible = (name == "RGB")
        hsvH.Parent.Visible = (name == "HSV")
        hsvS.Parent.Visible = (name == "HSV")
        hsvV.Parent.Visible = (name == "HSV")
        hexRow.Visible = (name == "HEX")
    end

    for n, tb in pairs(tabs) do
        tb.MouseButton1Click:Connect(function() showTab(n) end)
    end

    local function updateReadouts(color)
        local r = math.floor(color.R * 255 + 0.5)
        local g = math.floor(color.G * 255 + 0.5)
        local b = math.floor(color.B * 255 + 0.5)
        local h, s, v = RGBtoHSV(color)
        rgbR.Text = tostring(r)
        rgbG.Text = tostring(g)
        rgbB.Text = tostring(b)
        hsvH.Text = string.format("%.2f", h)
        hsvS.Text = string.format("%d", s)
        hsvV.Text = string.format("%d", v)
        hexRow.Text = RGBtoHEX(color)
    end

    local function applyTheme(color)
        Config.ThemeColor = color
        if uiRefs.main then uiRefs.main.BackgroundColor3 = color end
        if uiRefs.topBar then
            uiRefs.topBar.BackgroundColor3 = color:Lerp(Color3.fromRGB(0, 0, 0), 0.15)
            uiRefs.topFix.BackgroundColor3 = color:Lerp(Color3.fromRGB(0, 0, 0), 0.15)
        end
        if uiRefs.sidebar then uiRefs.sidebar.BackgroundColor3 = color:Lerp(Color3.fromRGB(0, 0, 0), 0.15) end
        if uiRefs.content then uiRefs.content.BackgroundColor3 = color:Lerp(Color3.fromRGB(255, 255, 255), 0.05) end
        wheel.BackgroundColor3 = color
        updateReadouts(color)
    end

    local wheelDragging = false
    local function updateFromWheel(x, y)
        local cx = wheel.AbsolutePosition.X + wheel.AbsoluteSize.X / 2
        local cy = wheel.AbsolutePosition.Y + wheel.AbsoluteSize.Y / 2
        local dx = (x - cx) / (wheel.AbsoluteSize.X / 2)
        local dy = (y - cy) / (wheel.AbsoluteSize.Y / 2)
        local dist = math.min(math.sqrt(dx*dx + dy*dy), 1)
        local angle = math.deg(math.atan2(dy, dx)) + 90
        if angle < 0 then angle = angle + 360 end
        local _, s, v = RGBtoHSV(Config.ThemeColor)
        applyTheme(HSVtoRGB(angle, dist * 100, v))
        marker.Position = UDim2.new(0.5, dx * (wheel.AbsoluteSize.X / 2) - 5,
                                     0.5, dy * (wheel.AbsoluteSize.Y / 2) - 5)
    end

    local wheelHit = Instance.new("TextButton")
    wheelHit.Size = UDim2.new(1, 0, 1, 0)
    wheelHit.BackgroundTransparency = 1
    wheelHit.Text = ""
    wheelHit.Parent = wheel

    wheelHit.MouseButton1Down:Connect(function() wheelDragging = true end)
    UserInputService.InputChanged:Connect(function(input)
        if wheelDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateFromWheel(input.Position.X, input.Position.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then wheelDragging = false end
    end)

    local bDragging = false
    local function updateBrightness(y)
        local rel = math.clamp((y - brightTrack.AbsolutePosition.Y) / brightTrack.AbsoluteSize.Y, 0, 1)
        brightKnob.Position = UDim2.new(0, -2, rel, -10)
        local h, s, _ = RGBtoHSV(Config.ThemeColor)
        applyTheme(HSVtoRGB(h, s, (1 - rel) * 100))
    end

    local brightHit = Instance.new("TextButton")
    brightHit.Size = UDim2.new(1, 0, 1, 0)
    brightHit.BackgroundTransparency = 1
    brightHit.Text = ""
    brightHit.Parent = brightTrack

    brightHit.MouseButton1Down:Connect(function()
        bDragging = true
        updateBrightness(UserInputService:GetMouseLocation().Y)
    end)
    UserInputService.InputChanged:Connect(function(input)
        if bDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            updateBrightness(input.Position.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then bDragging = false end
    end)

    showTab("HSV")
    updateReadouts(Config.ThemeColor)

    local unloadBtn = Instance.new("TextButton")
    unloadBtn.Size = UDim2.new(1, 0, 0, 34)
    unloadBtn.Position = UDim2.new(0, 0, 0, 390)
    unloadBtn.BackgroundColor3 = COL_RED
    unloadBtn.Text = "Unload Script"
    unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    unloadBtn.TextSize = 12
    unloadBtn.Font = Enum.Font.GothamBold
    unloadBtn.BorderSizePixel = 0
    unloadBtn.Parent = settingsPage
    local uC = Instance.new("UICorner"); uC.CornerRadius = UDim.new(0, 5); uC.Parent = unloadBtn

    unloadBtn.MouseButton1Click:Connect(function()
        SaveConfig()
        for _, c in ipairs({parryConnection, clashConnection, spamConnection, espConnection,
                            adminConnection, predictorConnection, abilityConnection, dodgeConnection,
                            trailConnection, speedoConnection, nameEspConnection, afkConnection,
                            rejoinConnection, tradeConnection}) do
            if c then c:Disconnect() end
        end
        if espFolder then espFolder:Destroy() end
        if trailFolder then trailFolder:Destroy() end
        if speedoGui then speedoGui:Destroy() end
        if nameEspFolder then nameEspFolder:Destroy() end
        screenGui:Destroy()
    end)

    addSidebarButton("Home", "◆", 8)
    addSidebarButton("Combat", "⚔", 48)
    addSidebarButton("Visual", "◉", 88)
    addSidebarButton("Utility", "⚙", 128)
    addSidebarButton("Settings", "✱", 168)

    showPage("Home")

    uiRefs.main = main
    uiRefs.topBar = topBar
    uiRefs.topFix = topFix
    uiRefs.sidebar = sidebar
    uiRefs.content = content

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        sidebar.Visible = not minimized
        content.Visible = not minimized
        main.Size = UDim2.new(0, W, 0, minimized and TOPBAR_H or H)
    end)

    return screenGui
end

-- ========== START ==========
if Config.EnableGUI then
    local ok, err = pcall(CreateUI)
    if not ok then
        warn("[Oynx] CreateUI failed: " .. tostring(err))
        Notify("Oynx Hub", "GUI failed: " .. tostring(err), 5)
    else
        Notify("Oynx Hub", "Oynx Hub Loaded (We would rather you use your alt account).", 3)
    end
end

StartParryLoop()
StartClashLoop()
StartParryChains()
StartAutoForcefield()
StartBallTrail()

if Config.AdminDetector then StartAdminWatch() end
if Config.ClashPredictor then StartClashPredictor() end
if Config.AutoAbility then StartAutoAbility() end
if Config.AutoDodge then StartAutoDodge() end
if Config.BallESP or Config.TargetESP then StartESP() end
if Config.TrajectoryLine then StartTrajectoryLine() end
if Config.Speedometer then StartSpeedometer() end
if Config.PlayerNamesESP then StartPlayerNamesESP() end
if Config.AntiAFK then StartAntiAFK() end
if Config.AutoRejoin then StartAutoRejoin() end
if Config.DiscordRPC then StartDiscordRPC() end
if Config.TradeTracker then StartTradeTracker() end

SaveCurrentJob()

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.K then
        Config.AutoParry = not Config.AutoParry
        Notify("Oynx Hub", Config.AutoParry and "Auto Parry ON" or "Auto Parry OFF", 1)
    end
end)

game:BindToClose(function() SaveConfig() end)
