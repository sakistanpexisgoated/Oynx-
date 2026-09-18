local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local Player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub | Ultimate Parry v2",
    LoadingTitle = "Onyx Final Build...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Combat", 4483362458)
MainTab:CreateSection("Bulletproof Auto Parry")

local autoParryEnabled = false

local function TriggerParry()
    -- Try firing known Blade Ball remotes safely
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes then
            if remotes:FindFirstChild("ParryButtonPress") then
                remotes.ParryButtonPress:FireServer()
            elseif remotes:FindFirstChild("ParryAttempt") then
                remotes.ParryAttempt:FireServer()
            end
        end
    end)
    
    -- Universal mobile tap simulation fallback
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(400, 400, 0, true, game, 0)
        task.wait(0.01)
        VirtualInputManager:SendMouseButtonEvent(400, 400, 0, false, game, 0)
    end)
end

MainTab:CreateToggle({
    Name = "Auto Parry (With Debug Notifier)",
    CurrentValue = false,
    Flag = "DebugParry",
    Callback = function(Value)
        autoParryEnabled = Value
        
        task.spawn(function()
            while autoParryEnabled do
                task.wait(0.02)
                pcall(function()
                    local character = Player.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    local ballsFolder = workspace:FindFirstChild("Balls")
                    
                    if hrp and ballsFolder then
                        for _, ball in ipairs(ballsFolder:GetChildren()) do
                            local ballPos = ball:IsA("Model") and ball.PrimaryPart and ball.PrimaryPart.Position or (ball:IsA("BasePart") and ball.Position)
                            
                            if ballPos then
                                local distance = (hrp.Position - ballPos).Magnitude
                                
                                -- If ball is within 35 studs, fire parry and notify you
                                if distance <= 35 then
                                    TriggerParry()
                                    
                                    -- Popup notification to prove it triggered
                                    Rayfield:Notify({
                                        Title = "Parry Triggered!",
                                        Content = "Distance: " .. math.floor(distance) .. " studs",
                                        Duration = 1,
                                    })
                                    
                                    task.wait(0.25) -- cooldown block
                                end
                            end
                        end
                    end
                end)
            end
        end)
    end,
})

Rayfield:Notify({
    Title = "Onyx Hub Loaded",
    Content = "Ready for match testing.",
    Duration = 3,
})
