-- OYNX HUB - Steal a Brainrot
-- Features: Auto Brainrot AFK, Auto Buy Secret, Auto Steal Best, Teleports, Infinite Jump, NoClip
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "🖤 Oynx Hub",
   LoadingTitle = "Oynx Hub",
   LoadingSubtitle = "steal a brainrot",
   ConfigurationSaving = {Enabled = false},
   Discord = {Enabled = false},
})

local MainTab = Window:CreateTab("Home", nil)
local TeleTab = Window:CreateTab("Teleports", nil)
local MiscTab = Window:CreateTab("Misc", nil)

-- state
local S = {
    infiniteJump = false,
    autoBrainrot = false,
    autoBuySecret = false,
    autoStealBest = false,
    noClip = false,
}
local conns = {}
local function track(c) table.insert(conns, c) return c end

local plr = game:GetService("Players").LocalPlayer
local function humanoid()
    local c = plr.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

-- Infinite Jump (single hook, respects toggle)
local uis = game:GetService("UserInputService")
track(uis.JumpRequest:Connect(function()
    if S.infiniteJump and humanoid() then
        humanoid():ChangeState(Enum.HumanoidStateType.Jumping)
    end
end))

MainTab:CreateToggle({
   Name = "Infinite Jump",
   CurrentValue = false,
   Flag = "InfiniteJump",
   Callback = function(v) S.infiniteJump = v end
})

-- WalkSpeed
MainTab:CreateSlider({
   Name = "WalkSpeed",
   Range = {16, 300},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = 16,
   Flag = "WalkSpeed",
   Callback = function(v)
       local h = humanoid()
       if h then h.WalkSpeed = v end
   end
})

-- Auto Brainrot AFK: keeps character from idling out, re-grabs on respawn
track(plr.CharacterAdded:Connect(function(c)
    c:WaitForChild("Humanoid")
    task.wait(0.5)
    if S.autoBrainrot then
        local h = c:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = 16 end
    end
end))

task.spawn(function()
    while task.wait(1) do
        if S.autoBrainrot then
            local h = humanoid()
            if h then
                h:ChangeState(Enum.HumanoidStateType.Physics) -- resets idle timer
                task.wait(0.1)
                h:ChangeState(Enum.HumanoidStateType.Running)
            end
        end
    end
end)

MainTab:CreateToggle({
   Name = "Auto Brainrot AFK",
   CurrentValue = false,
   Flag = "AutoBrainrot",
   Callback = function(v) S.autoBrainrot = v end
})

-- Auto Buy Secret: scans for a ProximityPrompt / ClickDetector tagged secret and fires it
task.spawn(function()
    while task.wait(0.75) do
        if S.autoBuySecret then
            for _, d in ipairs(workspace:GetDescendants()) do
                if d:IsA("ProximityPrompt") and d.Enabled then
                    local name = string.lower(d.Parent.Name .. " " .. d.ActionText)
                    if string.find(name, "secret") or string.find(name, "buy") then
                        pcall(function() fireproximityprompt(d) end)
                    end
                elseif d:IsA("ClickDetector") then
                    local name = string.lower(d.Parent.Name)
                    if string.find(name, "secret") then
                        pcall(function() fireclickdetector(d) end)
                    end
                end
            end
        end
    end
end)

MainTab:CreateToggle({
   Name = "Auto Buy Secret",
   CurrentValue = false,
   Flag = "AutoBuySecret",
   Callback = function(v) S.autoBuySecret = v end
})

-- Auto Steal Best: walks to nearest stealable plot and triggers its prompt
task.spawn(function()
    while task.wait(0.5) do
        if S.autoStealBest then
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root then
                local best, bestDist
                for _, d in ipairs(workspace:GetDescendants()) do
                    if d:IsA("ProximityPrompt") and d.Enabled then
                        local n = string.lower(d.Parent.Name .. " " .. d.ActionText)
                        if string.find(n, "steal") then
                            local part = d.Parent:IsA("BasePart") and d.Parent or d.Parent:FindFirstChildWhichIsA("BasePart")
                            if part then
                                local dist = (part.Position - root.Position).Magnitude
                                if not bestDist or dist < bestDist then
                                    best, bestDist = d, dist
                                end
                            end
                        end
                    end
                end
                if best then
                    local part = best.Parent:IsA("BasePart") and best.Parent or best.Parent:FindFirstChildWhichIsA("BasePart")
                    if part then
                        root.CFrame = CFrame.new(part.Position + Vector3.new(0, 3, 0))
                        task.wait(0.15)
                        pcall(function() fireproximityprompt(best) end)
                    end
                end
            end
        end
    end
end)

MainTab:CreateToggle({
   Name = "Auto Steal Best Items",
   CurrentValue = false,
   Flag = "AutoStealBest",
   Callback = function(v) S.autoStealBest = v end
})

-- Teleports: pulled from SpawnLocation at runtime, no hardcoded guesses
local function getSpawns()
    local out = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("SpawnLocation") then
            out["Spawn " .. #out + 1] = d.Position
        end
    end
    return out
end

TeleTab:CreateButton({
   Name = "Refresh Spawns",
   Callback = function()
       for name, pos in pairs(getSpawns()) do
           TeleTab:CreateButton({
               Name = "TP " .. name,
               Callback = function()
                   local r = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
                   if r then r.CFrame = CFrame.new(pos + Vector3.new(0, 5, 0)) end
               end
           })
       end
   end
})

-- NoClip: single Stepped connection, gated by flag so off actually restores collision
local noclipConn = game:GetService("RunService").Stepped:Connect(function()
    if S.noClip and plr.Character then
        for _, p in ipairs(plr.Character:GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
    end
end)
track(noclipConn)

MiscTab:CreateToggle({
   Name = "NoClip",
   CurrentValue = false,
   Flag = "NoClip",
   Callback = function(v)
       S.noClip = v
       if not v and plr.Character then
           for _, p in ipairs(plr.Character:GetDescendants()) do
               if p:IsA("BasePart") then p.CanCollide = true end
           end
       end
   end
})
