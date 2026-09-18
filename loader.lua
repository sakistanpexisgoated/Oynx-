local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Player = Players.LocalPlayer

local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub | Blade Ball",
    LoadingTitle = "Onyx Framework Initializing...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = { Enabled = false }
})

local MainTab = Window:CreateTab("Combat & Main", 4483362458)
MainTab:CreateSection("Auto Parry")

-- Reference variables
local autoParryEnabled = false
local Connection

-- Helper function to fire the parry remote safely
local function TriggerParry()
    local success = pcall(function()
        local remotes = ReplicatedStorage:FindFirstChild("Remotes")
        if remotes and remotes:FindFirstChild("ParryButtonPress") then
            remotes.ParryButtonPress:Fire()
        end
    end)
end

-- Helper to find the active real ball in the match
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
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParryToggle",
    Callback = function(Value)
        autoParryEnabled = Value
        
        if autoParryEnabled then
            -- Connect loop to frame updates for precise tracking
            Connection = RunService.PreSimulation:Connect(function()
                local character = Player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                local ball = GetActiveBall()
                
                if not hrp or not ball then return end
                
                -- Check if the ball's current target attribute matches local player
                local targetAttr = ball:GetAttribute("target")
                if targetAttr == Player.Name then
                    local distance = (hrp.Position - ball.Position).Magnitude
                    
                    -- Fallback velocity tracking safely handle vector components
                    local velocity = ball.AssemblyLinearVelocity.Magnitude
                    if velocity < 1 then velocity = 1 end
                    
                    local timeToCollision = distance / velocity
                    
                    -- Standard threshold trigger range
                    if timeToCollision <= 0.65 then
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
    Title = "Onyx Hub Loaded!",
    Content = "Auto-parry framework ready.",
    Duration = 4,
})
