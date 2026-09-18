local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub | Blade Ball Fixed",
    LoadingTitle = "Onyx Direct Hook...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Combat", 4483362458)
MainTab:CreateSection("Direct Auto Parry")

local autoParryEnabled = false

local function TriggerParry()
    pcall(function()
        ReplicatedStorage.Remotes.ParryButtonPress:Fire()
    end)
end

MainTab:CreateToggle({
    Name = "Instant Auto Parry",
    CurrentValue = false,
    Flag = "InstantParry",
    Callback = function(Value)
        autoParryEnabled = Value
        
        -- Start a background task loop while toggled on
        task.spawn(function()
            while autoParryEnabled do
                task.wait()
                pcall(function()
                    local character = Player.Character
                    local hrp = character and character:FindFirstChild("HumanoidRootPart")
                    local ballsFolder = workspace:FindFirstChild("Balls")
                    
                    if hrp and ballsFolder then
                        for _, ball in ipairs(ballsFolder:GetChildren()) do
                            if ball:GetAttribute("realBall") == true then
                                local distance = (hrp.Position - ball.Position).Magnitude
                                local target = ball:GetAttribute("target")
                                
                                -- If it's targeting us or gets dangerously close, fire instantly
                                if target == Player.Name or distance <= 22 then
                                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                                    if velocity < 1 then velocity = 1 end
                                    
                                    local timeToCollision = distance / velocity
                                    
                                    -- Generous trigger window to guarantee it hits
                                    if timeToCollision <= 1.5 or distance <= 16 then
                                        TriggerParry()
                                        task.wait(0.15)
                                    end
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
    Title = "Onyx Hub Ready",
    Content = "Direct parry loop active.",
    Duration = 4,
})
