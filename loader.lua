local success, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not success or not Rayfield then return end

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub | Blade Ball Absolute",
    LoadingTitle = "Onyx Absolute Accuracy...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Combat", 4483362458)
MainTab:CreateSection("Absolute Auto Parry")

local autoParryEnabled = false
local Connection

local function TriggerParry()
    pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("ParryButtonPress") then
            remotes.ParryButtonPress:Fire()
        end
    end)
end

local function GetActiveBall()
    local ballsFolder = workspace:FindFirstChild("Balls")
    if not ballsFolder then return nil end
    
    for _, ball in ipairs(ballsFolder:GetChildren()) do
        if ball:GetAttribute("realBall") == true then
            return ball
        end
    end
    return nil
end

MainTab:CreateToggle({
    Name = "Absolute Auto Parry (All Targets)",
    CurrentValue = false,
    Flag = "AbsoluteParry",
    Callback = function(Value)
        autoParryEnabled = Value
        
        if autoParryEnabled then
            Connection = RunService.RenderStepped:Connect(function()
                local character = Player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local ball = GetActiveBall()
                
                if not hrp or not ball then return end
                
                -- Check if the ball exists and has a target assigned
                local targetAttr = ball:GetAttribute("target")
                if targetAttr then
                    local distance = (hrp.Position - ball.Position).Magnitude
                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                    if velocity < 1 then velocity = 1 end
                    
                    local timeToCollision = distance / velocity
                    
                    -- Trigger if the ball is heading toward you or if a close clash is happening (< 25 studs)
                    if targetAttr == Player.Name or targetAttr == "Clash" or distance < 25 then
                        -- Highly sensitive threshold for instant response
                        if timeToCollision <= 1.2 or distance <= 18 then
                            TriggerParry()
                        end
                    end
                end
            end)
        else
            if Connection then
                Connection:Disconnect()
                Connection = nil
            end
        end
    end,
})

Rayfield:Notify({
    Title = "Onyx Hub Updated",
    Content = "Absolute parry mode active.",
    Duration = 4,
})
