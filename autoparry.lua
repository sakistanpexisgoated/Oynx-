--[[
    Oynx Hub - Blade Ball
    UI-first build. Features start after GUI is up.
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
    AutoParry = true, AutoClash = true, AutoSpam = false,
    ClashPredictor = false, AutoAbility = false, AutoDodge = false,
    ParryChains = false, AutoForcefield = false,
    HumanizeDelay = true,
    ParryWindow = 0.55, ParryCooldown = 0.12, ClashDistance = 12, SpamRate = 50,
    HumanizeMin = 0.03, HumanizeMax = 0.10, DodgeDistance = 20,
    BallESP = false, TargetESP = false, TrajectoryLine = false,
    BallTrail = false, Speedometer = false, PlayerNamesESP = false,
    SwordGiver = false, Visuals = false,
    AutoRejoin = false, ServerRegion = false, AntiAFK = false, DiscordRPC = false,
    AdminDetector = false, TradeTracker = false,
    Debug = false,
    ThemeColor = Color3.fromRGB(14, 14, 16),
}

local AntiKick = { MaxParryPerSecond = 6 }
local parryConnection, clashConnection, spamConnection, espConnection
local adminConnection, predictorConnection, abilityConnection, dodgeConnection
local trailConnection, speedoConnection, nameEspConnection, afkConnection, rejoinConnection, tradeConnection
local lastParryTime, parryCount, lastResetTime = 0, 0, tick()
local lastAbilityCheck, lastDodgeTime = 0, 0
local Parried = false
local espFolder, trailFolder, speedoGui, nameEspFolder
local uiRefs = {}
local knownAdmins = {}
local lastAbilityState = {}
local lastTradeHash = ""
local CONFIG_FILE = "oynx_hub_config.json"
local JOBS_FILE = "oynx_last_job.txt"

local ADMIN_KEYWORDS = {"admin","mod","moderator","owner","staff","dev","developer","manager","supervisor","gm","game master"}
local TradeValues = {["Default Sword"]=0,["Wooden Sword"]=0,["Basic Sword"]=0,["Candy Cane"]=5,["Ice Dagger"]=8,["Frostbite"]=10,["Snowflake"]=12,["Mythril"]=15,["Ninja"]=18,["Yin Yang"]=20,["Shadow"]=22,["Dragon"]=25,["Crystal"]=28,["Radiant"]=30,["Raven"]=32,["Eclipse"]=35,["Divine"]=40,["Void"]=45,["Godly"]=50,["Reaper"]=55,["Phantom"]=60,["Celestial"]=65,["Abyssal"]=70,["Infinity"]=80,["Genesis"]=90,["Chronos"]=100,["Omega"]=110,["Annihilation"]=120,["The Best Sword"]=999}
local TradeStats = {Wins=0, Losses=0, Even=0, Unknown=0, LastResult="—"}

local Remotes, ParryButtonPress, Abilities
local function GetParryRemote()
    if ParryButtonPress then return ParryButtonPress end
    local ok, r = pcall(function()
        local rm = ReplicatedStorage:FindFirstChild("Remotes")
        return rm and rm:FindFirstChild("ParryButtonPress")
    end)
    if ok and r then ParryButtonPress = r end
    return ParryButtonPress
end
local function GetAbilities()
    if Abilities then return Abilities end
    local ok, r = pcall(function()
        local rm = ReplicatedStorage:FindFirstChild("Remotes")
        return rm and rm:FindFirstChild("Abilities")
    end)
    if ok and r then Abilities = r end
    return Abilities
end

local function Notify(t, x, d)
    pcall(function() StarterGui:SetCore("SendNotification", {Title=t, Text=x, Duration=d or 2}) end)
end

local function GetBall()
    local bf = Workspace:FindFirstChild("Balls")
    if not bf then return nil end
    for _, b in ipairs(bf:GetChildren()) do
        if b:IsA("BasePart") and b:GetAttribute("realBall") == true then return b end
    end
    return nil
end

local function GetHRP()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart") or nil
end

local function HSVtoRGB(h,s,v) return Color3.fromHSV(h/360,s/100,v/100) end
local function RGBtoHSV(c) local h,s,v = Color3.toHSV(c) return h*360,s*100,v*100 end
local function RGBtoHEX(c) return string.format("#%02X%02X%02X", math.floor(c.R*255+0.5), math.floor(c.G*255+0.5), math.floor(c.B*255+0.5)) end

local function FireParry()
    local r = GetParryRemote()
    if r then pcall(function() r:Fire() end) end
end

local function GetTradeValue(n)
    if not n then return nil end
    if TradeValues[n] then return TradeValues[n] end
    local l = string.lower(n)
    for k, v in pairs(TradeValues) do
        if string.find(l, string.lower(k), 1, true) then return v end
    end
    return nil
end

local function SaveConfig()
    if not HAS_FS then return end
    pcall(function()
        local d = {}
        for k, v in pairs(Config) do
            if typeof(v) == "Color3" then d[k] = {__color=true, r=v.R, g=v.G, b=v.B}
            else d[k] = v end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(d))
    end)
end

local function LoadConfig()
    if not HAS_FS then return end
    pcall(function()
        if not isfile(CONFIG_FILE) then return end
        local d = HttpService:JSONDecode(readfile(CONFIG_FILE))
        for k, v in pairs(d) do
            if type(v) == "table" and v.__color then Config[k] = Color3.new(v.r, v.g, v.b)
            else Config[k] = v end
        end
    end)
end

local function SaveCurrentJob()
    if not HAS_FS then return end
    pcall(function() writefile(JOBS_FILE, game.JobId .. "\n" .. tostring(game.PlaceId)) end)
end

local function RejoinLastServer()
    if not HAS_FS then Notify("Oynx Hub", "Filesystem not supported", 3) return end
    pcall(function()
        if not isfile(JOBS_FILE) then Notify("Oynx Hub", "No saved server", 2) return end
        local content = readfile(JOBS_FILE)
        local jid, pid = string.match(content, "([^\n]+)\n([^\n]+)")
        if not jid or jid == "" then Notify("Oynx Hub", "Invalid saved server", 2) return end
        Notify("Oynx Hub", "Rejoining...", 2)
        task.wait(1)
        TeleportService:TeleportToPlaceInstance(tonumber(pid) or game.PlaceId, jid, LocalPlayer)
    end)
end

local function ExecuteParry()
    if not Config.AutoParry then return end
    local now = tick()
    if now - lastParryTime < Config.ParryCooldown then return end
    if now - lastResetTime > 1 then parryCount = 0; lastResetTime = now end
    if parryCount >= AntiKick.MaxParryPerSecond then return end
    lastParryTime = now
    parryCount = parryCount + 1
    if Config.HumanizeDelay then
        task.wait(math.random() * (Config.HumanizeMax - Config.HumanizeMin) + Config.HumanizeMin)
    end
    FireParry()
end

local function ExecuteClash()
    if not Config.AutoClash then return end
    local ball, hrp = GetBall(), GetHRP()
    if not ball or not hrp then return end
    if (hrp.Position - ball.Position).Magnitude <= Config.ClashDistance then FireParry() end
end

local function StartSpam()
    if spamConnection then spamConnection:Disconnect() end
    if not Config.AutoSpam then return end
    spamConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoSpam then return end
        FireParry()
        task.wait(1 / Config.SpamRate)
    end)
end

local function StartClashPredictor()
    if predictorConnection then predictorConnection:Disconnect() end
    if not Config.ClashPredictor then return end
    local lastPos = {}
    predictorConnection = RunService.PreSimulation:Connect(function()
        if not Config.ClashPredictor then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then return end
        local id = ball:GetDebugId()
        local lp = lastPos[id]
        local cp = ball.Position
        lastPos[id] = cp
        if not lp then return end
        local d = cp - lp
        local pred = cp + d
        local dn = (hrp.Position - cp).Magnitude
        local dnn = (hrp.Position - pred).Magnitude
        if dn < 25 and dnn < dn and (dn - dnn) > 0.5 then
            if (hrp.Position - cp).Unit:Dot(d.Unit) > 0.7 then FireParry() end
        end
    end)
end

local function StartAutoAbility()
    if abilityConnection then abilityConnection:Disconnect() end
    if not Config.AutoAbility then return end
    abilityConnection = RunService.Heartbeat:Connect(function()
        if not Config.AutoAbility then return end
        local now = tick()
        if now - lastAbilityCheck < 0.5 then return end
        lastAbilityCheck = now
        local ab = GetAbilities()
        if ab then
            for _, r in ipairs(ab:GetChildren()) do
                if r:IsA("RemoteEvent") then
                    local k = r.Name
                    if not lastAbilityState[k] or now - lastAbilityState[k] > 5 then
                        pcall(function() r:FireServer() end)
                        lastAbilityState[k] = now
                    end
                end
            end
        end
    end)
end

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
            local h = LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if h then
                local side = math.random() > 0.5 and 1 or -1
                local perp = (hrp.CFrame.RightVector * side).Unit
                pcall(function() h:MoveTo(hrp.Position + perp * 12) end)
            end
        end
    end)
end

local function StartParryChains()
    RunService.PreSimulation:Connect(function()
        if not Config.ParryChains then return end
        local bf = Workspace:FindFirstChild("Balls")
        if not bf then return end
        local n = 0
        for _, b in ipairs(bf:GetChildren()) do
            if b:IsA("BasePart") and b:GetAttribute("target") == LocalPlayer.Name then n = n + 1 end
        end
        if n > 1 then FireParry() end
    end)
end

local function StartAutoForcefield()
    RunService.PreSimulation:Connect(function()
        if not Config.AutoForcefield then return end
        local ball = GetBall()
        if not ball then return end
        if ball:GetAttribute("target") ~= LocalPlayer.Name then return end
        local hrp = GetHRP()
        if not hrp then return end
        if (hrp.Position - ball.Position).Magnitude < 30 then
            local ab = GetAbilities()
            if ab then
                local ff = ab:FindFirstChild("Forcefield") or ab:FindFirstChild("ForceField")
                if ff then pcall(function() ff:FireServer() end) end
            end
        end
    end)
end

local function GiveSwords()
    if not Config.SwordGiver then return end
    pcall(function()
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp then
            for _, i in ipairs(bp:GetChildren()) do
                if i:IsA("Tool") and i.Name:find("Sword") then
                    LocalPlayer.Character:FindFirstChildOfClass("Humanoid"):EquipTool(i)
                end
            end
        end
    end)
end

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
end

local function IsAdminName(n)
    local l = string.lower(n)
    for _, k in ipairs(ADMIN_KEYWORDS) do
        if string.find(l, k, 1, true) then return true end
    end
    return false
end

local function CheckPlayer(p)
    if p == LocalPlayer then return end
    if not IsAdminName(p.Name) and not IsAdminName(p.DisplayName) then return end
    if knownAdmins[p.UserId] then return end
    knownAdmins[p.UserId] = true
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

local function GetTradeItems()
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if not pg then return nil, nil end
    local function scan(root)
        local items = {}
        if not root then return items end
        for _, d in ipairs(root:GetDescendants()) do
            if d:IsA("TextLabel") and d.Text and #d.Text > 0 then
                local l = string.lower(d.Text)
                if string.find(l, "sword") or string.find(l, "blade") or string.find(l, "dagger") or string.find(l, "scythe") then
                    table.insert(items, d.Text)
                end
            end
        end
        return items
    end
    local tg = pg:FindFirstChild("Trade") or pg:FindFirstChild("TradeGui")
    if not tg then return nil, nil end
    local their = tg:FindFirstChild("TheirOffer") or tg:FindFirstChild("Other")
    local mine = tg:FindFirstChild("MyOffer") or tg:FindFirstChild("Mine")
    return scan(mine), scan(their)
end

local function EvaluateTrade()
    if not Config.TradeTracker then return end
    local mi, ti = GetTradeItems()
    if not mi or not ti then return end
    if #mi == 0 and #ti == 0 then return end
    local hash = table.concat(mi, ",") .. "|" .. table.concat(ti, ",")
    if hash == lastTradeHash then return end
    lastTradeHash = hash
    local mv, tv = 0, 0
    for _, n in ipairs(mi) do local v = GetTradeValue(n); if v then mv = mv + v end end
    for _, n in ipairs(ti) do local v = GetTradeValue(n); if v then tv = tv + v end end
    local r
    if tv > mv then r = "win" elseif tv < mv then r = "loss" else r = "even" end
    if r == "win" then TradeStats.Wins = TradeStats.Wins + 1
    elseif r == "loss" then TradeStats.Losses = TradeStats.Losses + 1
    else TradeStats.Even = TradeStats.Even + 1 end
    TradeStats.LastResult = r:upper()
    Notify("Oynx Hub", "Trade: " .. r:upper() .. " (you " .. mv .. " / them " .. tv .. ")", 4)
end

local function StartTradeTracker()
    if tradeConnection then tradeConnection:Disconnect() end
    tradeConnection = RunService.Heartbeat:Connect(function() pcall(EvaluateTrade) end)
end

local function StartESP()
    if espConnection then espConnection:Disconnect() end
    if espFolder then espFolder:Destroy() end
    if not (Config.BallESP or Config.TargetESP) then return end
    espFolder = Instance.new("Folder"); espFolder.Name = "OynxHubESP"; espFolder.Parent = Workspace
    espConnection = RunService.RenderStepped:Connect(function()
        for _, o in ipairs(espFolder:GetChildren()) do o:Destroy() end
        if Config.BallESP then
            local bf = Workspace:FindFirstChild("Balls")
            if bf then
                for _, b in ipairs(bf:GetChildren()) do
                    if b:IsA("BasePart") and b:GetAttribute("realBall") then
                        local h = Instance.new("Highlight"); h.Adornee = b
                        h.FillColor = Color3.fromRGB(255, 50, 50); h.FillTransparency = 0.5; h.Parent = espFolder
                    end
                end
            end
        end
        if Config.TargetESP then
            local ball = GetBall()
            if ball and ball:GetAttribute("target") then
                local tp = Players:FindFirstChild(ball:GetAttribute("target"))
                if tp and tp.Character then
                    local h = Instance.new("Highlight"); h.Adornee = tp.Character
                    h.FillColor = Color3.fromRGB(255, 0, 0); h.FillTransparency = 0.6; h.Parent = espFolder
                end
            end
        end
    end)
end

local function StartTrajectoryLine()
    if trailConnection then trailConnection:Disconnect() end
    if trailFolder then trailFolder:Destroy() end
    if not Config.TrajectoryLine then return end
    trailFolder = Instance.new("Folder"); trailFolder.Name = "OynxTrajectory"; trailFolder.Parent = Workspace
    trailConnection = RunService.RenderStepped:Connect(function()
        for _, o in ipairs(trailFolder:GetChildren()) do o:Destroy() end
        local ball = GetBall()
        if not ball then return end
        local vel = ball.AssemblyLinearVelocity
        if vel.Magnitude < 1 then return end
        local from = ball.Position
        local to = from + vel * 2
        local mid = from + (to - from) / 2
        local p = Instance.new("Part"); p.Anchored = true; p.CanCollide = false
        p.Material = Enum.Material.Neon
        p.Size = Vector3.new(0.2, 0.2, (to - from).Magnitude)
        p.CFrame = CFrame.lookAt(mid, to)
        p.Color = Color3.fromRGB(255, 100, 100); p.Transparency = 0.5; p.Parent = trailFolder
    end)
end

local function StartSpeedometer()
    if speedoConnection then speedoConnection:Disconnect() end
    if speedoGui then speedoGui:Destroy() end
    if not Config.Speedometer then return end
    speedoGui = Instance.new("ScreenGui"); speedoGui.ResetOnSpawn = false
    if gethui then pcall(function() speedoGui.Parent = gethui() end) end
    if not speedoGui.Parent then pcall(function() speedoGui.Parent = CoreGui end) end
    if not speedoGui.Parent then speedoGui.Parent = LocalPlayer:WaitForChild("PlayerGui") end
    local f = Instance.new("Frame")
    f.Size = UDim2.new(0, 200, 0, 90); f.Position = UDim2.new(0, 20, 0.5, -45)
    f.BackgroundColor3 = Color3.fromRGB(14, 14, 16); f.BackgroundTransparency = 0.2
    f.BorderSizePixel = 0; f.Parent = speedoGui
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0, 6); fc.Parent = f
    local l = Instance.new("TextLabel"); l.Size = UDim2.new(1, 0, 1, 0)
    l.BackgroundTransparency = 1; l.Text = "Speed: 0\nDistance: 0\nETA: 0.00s"
    l.TextColor3 = Color3.fromRGB(230, 230, 235); l.TextSize = 14
    l.Font = Enum.Font.GothamMedium; l.Parent = f
    speedoConnection = RunService.Heartbeat:Connect(function()
        if not Config.Speedometer then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then l.Text = "Speed: —\nDistance: —\nETA: —" return end
        local s = ball.AssemblyLinearVelocity.Magnitude
        local d = (hrp.Position - ball.Position).Magnitude
        local e = s > 0 and (d / s) or 0
        l.Text = string.format("Speed: %.1f\nDistance: %.1f\nETA: %.2fs", s, d, e)
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
                    local bb = Instance.new("BillboardGui"); bb.Adornee = head
                    bb.Size = UDim2.new(0, 120, 0, 20); bb.StudsOffset = Vector3.new(0, 3, 0)
                    bb.AlwaysOnTop = true; bb.Parent = nameEspFolder
                    local nl = Instance.new("TextLabel"); nl.Size = UDim2.new(1, 0, 1, 0)
                    nl.BackgroundTransparency = 1; nl.Text = p.Name
                    nl.TextColor3 = Color3.fromRGB(255, 255, 255); nl.TextStrokeTransparency = 0
                    nl.TextSize = 14; nl.Font = Enum.Font.GothamBold; nl.Parent = bb
                end
            end
        end
    end)
end

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

local function StartAntiAFK()
    if afkConnection then afkConnection:Disconnect() end
    if not Config.AntiAFK then return end
    afkConnection = LocalPlayer.Idled:Connect(function()
        if Config.AntiAFK then
            pcall(function() VirtualUser:CaptureController() VirtualUser:ClickButton2(Vector2.new()) end)
        end
    end)
end

local function StartParryLoop()
    if parryConnection then parryConnection:Disconnect() end
    parryConnection = RunService.PreSimulation:Connect(function()
        if not Config.AutoParry then return end
        local ball, hrp = GetBall(), GetHRP()
        if not ball or not hrp then return end
        if ball:GetAttribute("target") ~= LocalPlayer.Name then return end
        local z = ball:FindFirstChild("zoomies")
        if not z then return end
        local s = z.VectorVelocity.Magnitude
        if s < 1 then return end
        local d = (hrp.Position - ball.Position).Magnitude
        local tti = d / s
        if tti <= Config.ParryWindow and tti > 0 and not Parried then
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

local function StartBallTrail()
    local bp = {}
    RunService.Heartbeat:Connect(function()
        if not Config.BallTrail then bp = {} return end
        local ball = GetBall()
        if not ball then bp = {} return end
        table.insert(bp, {pos = ball.Position, time = tick()})
        local now = tick()
        local f = {}
        for _, p in ipairs(bp) do if now - p.time < 2 then table.insert(f, p) end end
        bp = f
        if trailFolder and #bp > 1 then
            for i = 2, #bp do
                local a, b = bp[i-1].pos, bp[i].pos
                local s = Instance.new("Part"); s.Anchored = true; s.CanCollide = false
                s.Material = Enum.Material.Neon
                s.Size = Vector3.new(0.15, 0.15, (a - b).Magnitude)
                s.CFrame = CFrame.lookAt((a + b) / 2, b)
                s.Color = Color3.fromRGB(255, 200, 50); s.Transparency = 0.6
                s.Parent = trailFolder or Workspace
                game:GetService("Debris"):AddItem(s, 0.3)
            end
        end
    end)
end

local function CreateUI()
    local sg = Instance.new("ScreenGui")
    sg.ResetOnSpawn = false
    sg.Name = "R_" .. tostring(math.random(100000, 999999))
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
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

    local W = IsMobile and 420 or 640
    local H = IsMobile and 300 or 420
    local SIDEBAR_W = 140
    local TOPBAR_H = 36

    local main = Instance.new("Frame")
    main.Size = UDim2.new(0, W, 0, H)
    main.Position = UDim2.new(0.5, -W/2, 0.5, -H/2)
    main.BackgroundColor3 = COL_BG; main.BorderSizePixel = 0
    main.Active = true; main.Draggable = true; main.Parent = sg
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 8); mc.Parent = main
    local ms = Instance.new("UIStroke"); ms.Color = COL_STROKE; ms.Thickness = 1; ms.Parent = main

    local bar = Instance.new("Frame")
    bar.Size = UDim2.new(1, 0, 0, TOPBAR_H)
    bar.BackgroundColor3 = COL_SIDEBAR; bar.BorderSizePixel = 0; bar.Parent = main
    local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(0, 8); bc.Parent = bar
    local bfix = Instance.new("Frame")
    bfix.Size = UDim2.new(1, 0, 0, 8); bfix.Position = UDim2.new(0, 0, 1, -8)
    bfix.BackgroundColor3 = COL_SIDEBAR; bfix.BorderSizePixel = 0; bfix.Parent = bar

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -70, 1, 0); title.Position = UDim2.new(0, 12, 0, 0)
    title.BackgroundTransparency = 1; title.Text = "Oynx Hub  |  Blade Ball"
    title.TextColor3 = COL_TEXT; title.TextSize = 13; title.Font = Enum.Font.GothamMedium
    title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = bar

    local minBtn = Instance.new("TextButton")
    minBtn.Size = UDim2.new(0, 28, 0, 28); minBtn.Position = UDim2.new(1, -62, 0, 4)
    minBtn.BackgroundColor3 = COL_PANEL; minBtn.Text = "—"
    minBtn.TextColor3 = COL_TEXT; minBtn.TextSize = 14
    minBtn.Font = Enum.Font.GothamBold; minBtn.BorderSizePixel = 0; minBtn.Parent = bar
    local mnc = Instance.new("UICorner"); mnc.CornerRadius = UDim.new(0, 5); mnc.Parent = minBtn

    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 28); closeBtn.Position = UDim2.new(1, -32, 0, 4)
    closeBtn.BackgroundColor3 = COL_RED; closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255); closeBtn.TextSize = 13
    closeBtn.Font = Enum.Font.GothamBold; closeBtn.BorderSizePixel = 0; closeBtn.Parent = bar
    local cbc = Instance.new("UICorner"); cbc.CornerRadius = UDim.new(0, 5); cbc.Parent = closeBtn
    closeBtn.MouseButton1Click:Connect(function() SaveConfig() sg:Destroy() end)

    local sidebar = Instance.new("Frame")
    sidebar.Size = UDim2.new(0, SIDEBAR_W, 1, -TOPBAR_H - 12)
    sidebar.Position = UDim2.new(0, 6, 0, TOPBAR_H + 6)
    sidebar.BackgroundColor3 = COL_SIDEBAR; sidebar.BorderSizePixel = 0; sidebar.Parent = main
    local sc = Instance.new("UICorner"); sc.CornerRadius = UDim.new(0, 6); sc.Parent = sidebar

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -SIDEBAR_W - 18, 1, -TOPBAR_H - 12)
    content.Position = UDim2.new(0, SIDEBAR_W + 12, 0, TOPBAR_H + 6)
    content.BackgroundColor3 = COL_PANEL; content.BorderSizePixel = 0; content.Parent = main
    local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = content

    local pages = {}
    local function newPage(name)
        local p = Instance.new("ScrollingFrame")
        p.Size = UDim2.new(1, -16, 1, -16); p.Position = UDim2.new(0, 8, 0, 8)
        p.BackgroundTransparency = 1; p.BorderSizePixel = 0
        p.ScrollBarThickness = 3; p.ScrollBarImageColor3 = COL_ACCENT
        p.CanvasSize = UDim2.new(0, 0, 0, 0)
        p.AutomaticCanvasSize = Enum.AutomaticSize.Y
        p.Visible = false; p.Parent = content
        pages[name] = p
        return p
    end
    local function showPage(n)
        for k, v in pairs(pages) do v.Visible = (k == n) end
    end
    local function addSection(parent, t, y)
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, 0, 0, 24); l.Position = UDim2.new(0, 0, 0, y)
        l.BackgroundTransparency = 1; l.Text = t
        l.TextColor3 = COL_MUTED; l.TextSize = 11; l.Font = Enum.Font.GothamBold
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = parent
    end
    local function addToggle(parent, label, key, y, cb)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 34); row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundColor3 = COL_BG; row.BorderSizePixel = 0; row.Parent = parent
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -60, 1, 0); l.Position = UDim2.new(0, 10, 0, 0)
        l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = COL_TEXT
        l.TextSize = 12; l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = row
        local pill = Instance.new("Frame")
        pill.Size = UDim2.new(0, 40, 0, 20); pill.Position = UDim2.new(1, -50, 0.5, -10)
        pill.BackgroundColor3 = Config[key] and COL_ACCENT or COL_STROKE
        pill.BorderSizePixel = 0; pill.Parent = row
        local pc = Instance.new("UICorner"); pc.CornerRadius = UDim.new(1, 0); pc.Parent = pill
        local knob = Instance.new("Frame")
        knob.Size = UDim2.new(0, 16, 0, 16)
        knob.Position = Config[key] and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)
        knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255); knob.BorderSizePixel = 0; knob.Parent = pill
        local kc = Instance.new("UICorner"); kc.CornerRadius = UDim.new(1, 0); kc.Parent = knob
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, 0, 1, 0); b.BackgroundTransparency = 1; b.Text = ""; b.Parent = row
        b.MouseButton1Click:Connect(function()
            Config[key] = not Config[key]
            TweenService:Create(pill, TweenInfo.new(0.15), {BackgroundColor3 = Config[key] and COL_ACCENT or COL_STROKE}):Play()
            TweenService:Create(knob, TweenInfo.new(0.15), {Position = Config[key] and UDim2.new(1, -18, 0, 2) or UDim2.new(0, 2, 0, 2)}):Play()
            if cb then cb(Config[key]) end
        end)
    end
    local function addSlider(parent, label, mn, mx, dflt, y, cb)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 48); row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundColor3 = COL_BG; row.BorderSizePixel = 0; row.Parent = parent
        local rc = Instance.new("UICorner"); rc.CornerRadius = UDim.new(0, 5); rc.Parent = row
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(1, -60, 0, 20); l.Position = UDim2.new(0, 10, 0, 4)
        l.BackgroundTransparency = 1; l.Text = label; l.TextColor3 = COL_TEXT
        l.TextSize = 12; l.Font = Enum.Font.Gotham
        l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = row
        local vl = Instance.new("TextLabel")
        vl.Size = UDim2.new(0, 50, 0, 20); vl.Position = UDim2.new(1, -60, 0, 4)
        vl.BackgroundTransparency = 1; vl.Text = string.format("%.2f", dflt)
        vl.TextColor3 = COL_ACCENT; vl.TextSize = 12
        vl.Font = Enum.Font.GothamMedium; vl.TextXAlignment = Enum.TextXAlignment.Right; vl.Parent = row
        local track = Instance.new("Frame")
        track.Size = UDim2.new(1, -20, 0, 6); track.Position = UDim2.new(0, 10, 0, 30)
        track.BackgroundColor3 = COL_STROKE; track.BorderSizePixel = 0; track.Parent = row
        local tc = Instance.new("UICorner"); tc.CornerRadius = UDim.new(1, 0); tc.Parent = track
        local pct = (dflt - mn) / (mx - mn)
        local fill = Instance.new("Frame")
        fill.Size = UDim2.new(pct, 0, 1, 0); fill.BackgroundColor3 = COL_ACCENT
        fill.BorderSizePixel = 0; fill.Parent = track
        local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill
        local drag = false
        local function update(x)
            local r = math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1)
            local v = mn + (mx - mn) * r
            fill.Size = UDim2.new(r, 0, 1, 0)
            vl.Text = string.format("%.2f", v)
            if cb then cb(v) end
        end
        local hit = Instance.new("TextButton")
        hit.Size = UDim2.new(1, 0, 1, 0); hit.BackgroundTransparency = 1
        hit.Text = ""; hit.Parent = track
        hit.MouseButton1Down:Connect(function() drag = true; update(UserInputService:GetMouseLocation().X) end)
        UserInputService.InputChanged:Connect(function(i)
            if drag and i.UserInputType == Enum.UserInputType.MouseMovement then update(i.Position.X) end
        end)
        UserInputService.InputEnded:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 then drag = false end
        end)
    end
    local sideButtons = {}
    local function addSideBtn(name, icon, y)
        local b = Instance.new("TextButton")
        b.Size = UDim2.new(1, -12, 0, 34); b.Position = UDim2.new(0, 6, 0, y)
        b.BackgroundColor3 = COL_SIDEBAR; b.Text = ""; b.BorderSizePixel = 0; b.Parent = sidebar
        local bcc = Instance.new("UICorner"); bcc.CornerRadius = UDim.new(0, 5); bcc.Parent = b
        local ic = Instance.new("TextLabel")
        ic.Size = UDim2.new(0, 20, 1, 0); ic.Position = UDim2.new(0, 8, 0, 0)
        ic.BackgroundTransparency = 1; ic.Text = icon; ic.TextColor3 = COL_MUTED
        ic.TextSize = 14; ic.Font = Enum.Font.GothamBold; ic.Parent = b
        local lb = Instance.new("TextLabel")
        lb.Size = UDim2.new(1, -34, 1, 0); lb.Position = UDim2.new(0, 30, 0, 0)
        lb.BackgroundTransparency = 1; lb.Text = name; lb.TextColor3 = COL_MUTED
        lb.TextSize = 12; lb.Font = Enum.Font.Gotham
        lb.TextXAlignment = Enum.TextXAlignment.Left; lb.Parent = b
        b.MouseButton1Click:Connect(function()
            showPage(name)
            for _, x in pairs(sideButtons) do
                x.btn.BackgroundColor3 = COL_SIDEBAR
                x.ic.TextColor3 = COL_MUTED
                x.lb.TextColor3 = COL_MUTED
            end
            b.BackgroundColor3 = COL_PANEL
            ic.TextColor3 = COL_ACCENT
            lb.TextColor3 = COL_TEXT
        end)
        sideButtons[name] = {btn = b, ic = ic, lb = lb}
    end

    local homePage = newPage("Home")
    local combatPage = newPage("Combat")
    local visualPage = newPage("Visual")
    local utilityPage = newPage("Utility")
    local settingsPage = newPage("Settings")

    addSection(homePage, "WELCOME", 0)
    local welcome = Instance.new("TextLabel")
    welcome.Size = UDim2.new(1, 0, 0, 60); welcome.Position = UDim2.new(0, 0, 0, 26)
    welcome.BackgroundColor3 = COL_BG
    welcome.Text = "Oynx Hub running. Detection locked.\nPlatform: " .. Platform
    welcome.TextColor3 = COL_MUTED; welcome.TextSize = 11
    welcome.Font = Enum.Font.Gotham; welcome.TextWrapped = true; welcome.Parent = homePage
    local wC = Instance.new("UICorner"); wC.CornerRadius = UDim.new(0, 5); wC.Parent = welcome

    addSection(homePage, "STATUS", 100)
    local statusLbl = Instance.new("TextLabel")
    statusLbl.Size = UDim2.new(1, 0, 0, 40); statusLbl.Position = UDim2.new(0, 0, 0, 126)
    statusLbl.BackgroundColor3 = COL_BG; statusLbl.Text = "● Ready"
    statusLbl.TextColor3 = COL_GREEN; statusLbl.TextSize = 12
    statusLbl.Font = Enum.Font.GothamMedium; statusLbl.Parent = homePage
    local sC = Instance.new("UICorner"); sC.CornerRadius = UDim.new(0, 5); sC.Parent = statusLbl

    addSection(homePage, "TRADE TRACKER", 176)
    local tradeLbl = Instance.new("TextLabel")
    tradeLbl.Size = UDim2.new(1, 0, 0, 76); tradeLbl.Position = UDim2.new(0, 0, 0, 202)
    tradeLbl.BackgroundColor3 = COL_BG
    tradeLbl.Text = "W: 0   L: 0   Even: 0   ?: 0\nLast: —"
    tradeLbl.TextColor3 = COL_TEXT; tradeLbl.TextSize = 11
    tradeLbl.Font = Enum.Font.Gotham; tradeLbl.TextWrapped = true; tradeLbl.Parent = homePage
    local tlC = Instance.new("UICorner"); tlC.CornerRadius = UDim.new(0, 5); tlC.Parent = tradeLbl

    task.spawn(function()
        while tradeLbl.Parent do
            tradeLbl.Text = string.format("W: %d   L: %d   Even: %d   ?: %d\nLast: %s",
                TradeStats.Wins, TradeStats.Losses, TradeStats.Even, TradeStats.Unknown, TradeStats.LastResult)
            tradeLbl.TextColor3 = (TradeStats.LastResult == "WIN") and COL_GREEN
                or (TradeStats.LastResult == "LOSS") and COL_RED or COL_TEXT
            task.wait(1)
        end
    end)

    addSection(combatPage, "CORE", 0)
    addToggle(combatPage, "Auto Parry", "AutoParry", 26, function(v)
        statusLbl.Text = v and "● Auto Parry ON" or "● Auto Parry OFF"
        statusLbl.TextColor3 = v and COL_GREEN or COL_RED
    end)
    addToggle(combatPage, "Auto Clash", "AutoClash", 62)
    addToggle(combatPage, "Auto Spam", "AutoSpam", 98, function() StartSpam() end)
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
    addToggle(combatPage, "Admin Detector", "AdminDetector", 686, function(v) if v then StartAdminWatch() end end)

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

    addSection(utilityPage, "AUTOMATION", 0)
    addToggle(utilityPage, "Auto Rejoin on Death", "AutoRejoin", 26, function(v) if v then StartAutoRejoin() end end)
    addToggle(utilityPage, "Anti-AFK", "AntiAFK", 98, function(v) if v then StartAntiAFK() end end)
    addToggle(utilityPage, "Trade W/L Tracker", "TradeTracker", 170, function(v) if v then StartTradeTracker() end end)

    addSection(utilityPage, "CONFIG", 216)
    local saveBtn = Instance.new("TextButton")
    saveBtn.Size = UDim2.new(1, 0, 0, 34); saveBtn.Position = UDim2.new(0, 0, 0, 242)
    saveBtn.BackgroundColor3 = COL_ACCENT; saveBtn.Text = "Save Config"
    saveBtn.TextColor3 = Color3.fromRGB(255, 255, 255); saveBtn.TextSize = 12
    saveBtn.Font = Enum.Font.GothamBold; saveBtn.BorderSizePixel = 0; saveBtn.Parent = utilityPage
    local sbc = Instance.new("UICorner"); sbc.CornerRadius = UDim.new(0, 5); sbc.Parent = saveBtn
    saveBtn.MouseButton1Click:Connect(function() SaveConfig() Notify("Oynx Hub", "Config saved", 2) end)

    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(1, 0, 0, 34); loadBtn.Position = UDim2.new(0, 0, 0, 282)
    loadBtn.BackgroundColor3 = COL_PANEL; loadBtn.Text = "Load Config"
    loadBtn.TextColor3 = COL_TEXT; loadBtn.TextSize = 12
    loadBtn.Font = Enum.Font.GothamBold; loadBtn.BorderSizePixel = 0; loadBtn.Parent = utilityPage
    local lbc = Instance.new("UICorner"); lbc.CornerRadius = UDim.new(0, 5); lbc.Parent = loadBtn
    loadBtn.MouseButton1Click:Connect(function() LoadConfig() Notify("Oynx Hub", "Config loaded", 2) end)

    addSection(utilityPage, "SERVER", 336)
    local rejBtn = Instance.new("TextButton")
    rejBtn.Size = UDim2.new(1, 0, 0, 34); rejBtn.Position = UDim2.new(0, 0, 0, 362)
    rejBtn.BackgroundColor3 = COL_ACCENT; rejBtn.Text = "Rejoin Last Server"
    rejBtn.TextColor3 = Color3.fromRGB(255, 255, 255); rejBtn.TextSize = 12
    rejBtn.Font = Enum.Font.GothamBold; rejBtn.BorderSizePixel = 0; rejBtn.Parent = utilityPage
    local rjc = Instance.new("UICorner"); rjc.CornerRadius = UDim.new(0, 5); rjc.Parent = rejBtn
    rejBtn.MouseButton1Click:Connect(function() SaveCurrentJob() task.wait(0.5) RejoinLastServer() end)

    local sjBtn = Instance.new("TextButton")
    sjBtn.Size = UDim2.new(1, 0, 0, 34); sjBtn.Position = UDim2.new(0, 0, 0, 402)
    sjBtn.BackgroundColor3 = COL_PANEL; sjBtn.Text = "Save Current Server"
    sjBtn.TextColor3 = COL_TEXT; sjBtn.TextSize = 12
    sjBtn.Font = Enum.Font.GothamBold; sjBtn.BorderSizePixel = 0; sjBtn.Parent = utilityPage
    local sjc = Instance.new("UICorner"); sjc.CornerRadius = UDim.new(0, 5); sjc.Parent = sjBtn
    sjBtn.MouseButton1Click:Connect(function() SaveCurrentJob() Notify("Oynx Hub", "Server saved", 2) end)

    addSection(settingsPage, "GENERAL", 0)
    addToggle(settingsPage, "Debug Notifications", "Debug", 26)

    addSection(settingsPage, "UI COLOR", 70)
    local pickerFrame = Instance.new("Frame")
    pickerFrame.Size = UDim2.new(1, 0, 0, 280); pickerFrame.Position = UDim2.new(0, 0, 0, 96)
    pickerFrame.BackgroundColor3 = COL_BG; pickerFrame.BorderSizePixel = 0; pickerFrame.Parent = settingsPage
    local pfc = Instance.new("UICorner"); pfc.CornerRadius = UDim.new(0, 6); pfc.Parent = pickerFrame

    local wheel = Instance.new("ImageLabel")
    wheel.Size = UDim2.new(0, 160, 0, 160); wheel.Position = UDim2.new(0, 10, 0, 10)
    wheel.BackgroundColor3 = Color3.fromRGB(255, 255, 255); wheel.BorderSizePixel = 0
    wheel.Image = "rbxassetid://5655816373"; wheel.Parent = pickerFrame
    local wcc = Instance.new("UICorner"); wcc.CornerRadius = UDim.new(1, 0); wcc.Parent = wheel
    local ws = Instance.new("UIStroke"); ws.Color = COL_STROKE; ws.Thickness = 2; ws.Parent = wheel

    local marker = Instance.new("Frame")
    marker.Size = UDim2.new(0, 10, 0, 10); marker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    marker.BorderSizePixel = 2; marker.BorderColor3 = Color3.fromRGB(0, 0, 0)
    marker.Position = UDim2.new(0, 85, 0, 85); marker.Parent = wheel
    local mkc = Instance.new("UICorner"); mkc.CornerRadius = UDim.new(1, 0); mkc.Parent = marker

    local bTrack = Instance.new("Frame")
    bTrack.Size = UDim2.new(0, 16, 0, 160); bTrack.Position = UDim2.new(0, 180, 0, 10)
    bTrack.BackgroundColor3 = Color3.fromRGB(0, 0, 0); bTrack.BorderSizePixel = 0; bTrack.Parent = pickerFrame
    local btc = Instance.new("UICorner"); btc.CornerRadius = UDim.new(1, 0); btc.Parent = bTrack
    local bGrad = Instance.new("UIGradient")
    bGrad.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    bGrad.Rotation = 90; bGrad.Parent = bTrack

    local bKnob = Instance.new("Frame")
    bKnob.Size = UDim2.new(0, 20, 0, 20); bKnob.Position = UDim2.new(0, -2, 0, 0)
    bKnob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    bKnob.BorderSizePixel = 2; bKnob.BorderColor3 = Color3.fromRGB(0, 0, 0); bKnob.Parent = bTrack
    local bkc = Instance.new("UICorner"); bkc.CornerRadius = UDim.new(1, 0); bkc.Parent = bKnob

    local tabHolder = Instance.new("Frame")
    tabHolder.Size = UDim2.new(1, -20, 0, 26); tabHolder.Position = UDim2.new(0, 10, 0, 180)
    tabHolder.BackgroundTransparency = 1; tabHolder.Parent = pickerFrame

    local tabs = {}
    for i, name in ipairs({"RGB","HSV","HEX"}) do
        local tb = Instance.new("TextButton")
        tb.Size = UDim2.new(1/3, -4, 1, 0); tb.Position = UDim2.new((i-1)/3, 2, 0, 0)
        tb.BackgroundColor3 = COL_SIDEBAR; tb.Text = name
        tb.TextColor3 = COL_MUTED; tb.TextSize = 11
        tb.Font = Enum.Font.GothamMedium; tb.BorderSizePixel = 0; tb.Parent = tabHolder
        local tbc = Instance.new("UICorner"); tbc.CornerRadius = UDim.new(0, 4); tbc.Parent = tb
        tabs[name] = tb
    end

    local vHolder = Instance.new("Frame")
    vHolder.Size = UDim2.new(1, -20, 0, 60); vHolder.Position = UDim2.new(0, 10, 0, 212)
    vHolder.BackgroundTransparency = 1; vHolder.Parent = pickerFrame

    local function makeRow(label, y)
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, 0, 0, 16); row.Position = UDim2.new(0, 0, 0, y)
        row.BackgroundTransparency = 1; row.Parent = vHolder
        local l = Instance.new("TextLabel")
        l.Size = UDim2.new(0.5, 0, 1, 0); l.BackgroundTransparency = 1
        l.Text = label; l.TextColor3 = COL_MUTED; l.TextSize = 11
        l.Font = Enum.Font.Gotham; l.TextXAlignment = Enum.TextXAlignment.Left; l.Parent = row
        local v = Instance.new("TextLabel")
        v.Size = UDim2.new(0.5, 0, 1, 0); v.Position = UDim2.new(0.5, 0, 0, 0)
        v.BackgroundTransparency = 1; v.Text = "0"
        v.TextColor3 = COL_TEXT; v.TextSize = 11
        v.Font = Enum.Font.GothamMedium; v.TextXAlignment = Enum.TextXAlignment.Right; v.Parent = row
        return v
    end
    local rgbR = makeRow("R:", 0)
    local rgbG = makeRow("G:", 20)
    local rgbB = makeRow("B:", 40)
    local hsvH = makeRow("H:", 0)
    local hsvS = makeRow("S:", 20)
    local hsvV = makeRow("V:", 40)

    local hexRow = Instance.new("TextLabel")
    hexRow.Size = UDim2.new(1, 0, 1, 0); hexRow.BackgroundTransparency = 1
    hexRow.Text = "#0E0E10"; hexRow.TextColor3 = COL_TEXT
    hexRow.TextSize = 14; hexRow.Font = Enum.Font.GothamBold; hexRow.Parent = vHolder

    local function showTab(name)
        for k, tb in pairs(tabs) do
            tb.TextColor3 = (k == name) and COL_TEXT or COL_MUTED
            tb.BackgroundColor3 = (k == name) and COL_PANEL or COL_SIDEBAR
        end
        rgbR.Parent.Visible = (name == "RGB")
        rgbG.Parent.Visible = (name == "RGB")
        rgbB.Parent.Visible = (name == "RGB")
        hsvH.Parent.Visible = (name == "HSV")
        hsvS.Parent.Visible = (name == "HSV")
        hsvV.Parent.Visible = (name == "HSV")
        hexRow.Visible = (name == "HEX")
    end
    for k, tb in pairs(tabs) do
        tb.MouseButton1Click:Connect(function() showTab(k) end)
    end

    local function updateReadouts(c)
        rgbR.Text = tostring(math.floor(c.R * 255 + 0.5))
        rgbG.Text = tostring(math.floor(c.G * 255 + 0.5))
        rgbB.Text = tostring(math.floor(c.B * 255 + 0.5))
        local h, s, v = RGBtoHSV(c)
        hsvH.Text = string.format("%.2f", h)
        hsvS.Text = string.format("%d", s)
        hsvV.Text = string.format("%d", v)
        hexRow.Text = RGBtoHEX(c)
    end

    local function applyTheme(c)
        Config.ThemeColor = c
        if uiRefs.main then uiRefs.main.BackgroundColor3 = c end
        if uiRefs.bar then
            uiRefs.bar.BackgroundColor3 = c:Lerp(Color3.fromRGB(0, 0, 0), 0.15)
            uiRefs.bfix.BackgroundColor3 = c:Lerp(Color3.fromRGB(0, 0, 0), 0.15)
        end
        if uiRefs.sidebar then uiRefs.sidebar.BackgroundColor3 = c:Lerp(Color3.fromRGB(0, 0, 0), 0.15) end
        if uiRefs.content then uiRefs.content.BackgroundColor3 = c:Lerp(Color3.fromRGB(255, 255, 255), 0.05) end
        wheel.BackgroundColor3 = c
        updateReadouts(c)
    end

    local wDrag = false
    local function updateWheel(x, y)
        local cx = wheel.AbsolutePosition.X + wheel.AbsoluteSize.X / 2
        local cy = wheel.AbsolutePosition.Y + wheel.AbsoluteSize.Y / 2
        local dx = (x - cx) / (wheel.AbsoluteSize.X / 2)
        local dy = (y - cy) / (wheel.AbsoluteSize.Y / 2)
        local dist = math.min(math.sqrt(dx*dx + dy*dy), 1)
        local angle = math.deg(math.atan2(dy, dx)) + 90
        if angle < 0 then angle = angle + 360 end
        local _, s, v = RGBtoHSV(Config.ThemeColor)
        applyTheme(HSVtoRGB(angle, dist * 100, v))
        marker.Position = UDim2.new(0.5, dx * (wheel.AbsoluteSize.X / 2) - 5, 0.5, dy * (wheel.AbsoluteSize.Y / 2) - 5)
    end
    local wHit = Instance.new("TextButton")
    wHit.Size = UDim2.new(1, 0, 1, 0); wHit.BackgroundTransparency = 1
    wHit.Text = ""; wHit.Parent = wheel
    wHit.MouseButton1Down:Connect(function() wDrag = true end)
    UserInputService.InputChanged:Connect(function(i)
        if wDrag and i.UserInputType == Enum.UserInputType.MouseMovement then updateWheel(i.Position.X, i.Position.Y) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then wDrag = false end
    end)

    local bDrag = false
    local function updateBright(y)
        local rel = math.clamp((y - bTrack.AbsolutePosition.Y) / bTrack.AbsoluteSize.Y, 0, 1)
        bKnob.Position = UDim2.new(0, -2, rel, -10)
        local h, s, _ = RGBtoHSV(Config.ThemeColor)
        applyTheme(HSVtoRGB(h, s, (1 - rel) * 100))
    end
    local bHit = Instance.new("TextButton")
    bHit.Size = UDim2.new(1, 0, 1, 0); bHit.BackgroundTransparency = 1
    bHit.Text = ""; bHit.Parent = bTrack
    bHit.MouseButton1Down:Connect(function()
        bDrag = true
        updateBright(UserInputService:GetMouseLocation().Y)
    end)
    UserInputService.InputChanged:Connect(function(i)
        if bDrag and i.UserInputType == Enum.UserInputType.MouseMovement then updateBright(i.Position.Y) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 then bDrag = false end
    end)

    showTab("HSV")
    updateReadouts(Config.ThemeColor)

    local unloadBtn = Instance.new("TextButton")
    unloadBtn.Size = UDim2.new(1, 0, 0, 34); unloadBtn.Position = UDim2.new(0, 0, 0, 390)
    unloadBtn.BackgroundColor3 = COL_RED; unloadBtn.Text = "Unload Script"
    unloadBtn.TextColor3 = Color3.fromRGB(255, 255, 255); unloadBtn.TextSize = 12
    unloadBtn.Font = Enum.Font.GothamBold; unloadBtn.BorderSizePixel = 0; unloadBtn.Parent = settingsPage
    local ubc = Instance.new("UICorner"); ubc.CornerRadius = UDim.new(0, 5); ubc.Parent = unloadBtn
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
        sg:Destroy()
    end)

    addSideBtn("Home", "◆", 8)
    addSideBtn("Combat", "⚔", 48)
    addSideBtn("Visual", "◉", 88)
    addSideBtn("Utility", "⚙", 128)
    addSideBtn("Settings", "✱", 168)

    showPage("Home")

    uiRefs.main = main
    uiRefs.bar = bar
    uiRefs.bfix = bfix
    uiRefs.sidebar = sidebar
    uiRefs.content = content

    local minimized = false
    minBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        sidebar.Visible = not minimized
        content.Visible = not minimized
        main.Size = UDim2.new(0, W, 0, minimized and TOPBAR_H or H)
    end)

    return sg
end

-- ========== UI FIRST, EVERYTHING ELSE DELAYED ==========
local ok, err = pcall(CreateUI)
if not ok then
    Notify("Oynx Error", tostring(err), 8)
    warn("[Oynx] CreateUI failed: " .. tostring(err))
else
    Notify("Oynx Hub", "Oynx Hub Loaded (We would rather you use your alt account).", 3)
    task.wait(3)
    pcall(function()
        pcall(StartParryLoop)
        pcall(StartClashLoop)
        pcall(StartParryChains)
        pcall(StartAutoForcefield)
        pcall(StartBallTrail)
        if Config.AdminDetector then pcall(StartAdminWatch) end
        if Config.ClashPredictor then pcall(StartClashPredictor) end
        if Config.AutoAbility then pcall(StartAutoAbility) end
        if Config.AutoDodge then pcall(StartAutoDodge) end
        if Config.BallESP or Config.TargetESP then pcall(StartESP) end
        if Config.TrajectoryLine then pcall(StartTrajectoryLine) end
        if Config.Speedometer then pcall(StartSpeedometer) end
        if Config.PlayerNamesESP then pcall(StartPlayerNamesESP) end
        if Config.AntiAFK then pcall(StartAntiAFK) end
        if Config.AutoRejoin then pcall(StartAutoRejoin) end
        if Config.TradeTracker then pcall(StartTradeTracker) end
        pcall(SaveCurrentJob)
    end)
end

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.K then
        Config.AutoParry = not Config.AutoParry
        Notify("Oynx Hub", Config.AutoParry and "Auto Parry ON" or "Auto Parry OFF", 1)
    end
end)

game:BindToClose(function() SaveConfig() end)
