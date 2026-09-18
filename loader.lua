local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub | Blade Ball Max",
    LoadingTitle = "Onyx Max Accuracy...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Combat", 4483362458)
MainTab:CreateSection("Advanced Auto Parry")

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
    Name = "Ultra Auto Parry + Clash Mode",
    CurrentValue = false,
    Flag = "UltraParry",
    Callback = function(Value)
        autoParryEnabled = Value
        
        if autoParryEnabled then
            Connection = RunService.RenderStepped:Connect(function()
                local character = Player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local ball = GetActiveBall()
                
                if not hrp or not ball then return end
                
                local targetAttr = ball:GetAttribute("target")
                
                -- Check if ball is targeting us OR if it's close enough for a clash check
                if targetAttr == Player.Name or targetAttr == "Clash" then
                    local distance = (hrp.Position - ball.Position).Magnitude
                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                    if velocity < 1 then velocity = 1 end
                    
                    local timeToCollision = distance / velocity
                    
                    -- Dynamic threshold: If it's a clash, spam faster. If normal, use optimized timing.
                    local threshold = (targetAttr == "Clash") and 1.2 or 0.68
                    
                    if timeToCollision <= threshold then
                        TriggerParry()
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
    Content = "Max accuracy & clash handler loaded.",
    Duration = 4,
})
