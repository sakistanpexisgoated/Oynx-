-- Onyx Hub: Custom Mobile Framework
-- Powered by Rayfield UI Library

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

-- 1. Create the Main Window
local Window = Rayfield:CreateWindow({
    Name = "Onyx Hub | Blade Ball",
    LoadingTitle = "Onyx Framework Initializing...",
    LoadingSubtitle = "by You",
    ConfigurationSaving = {
        Enabled = false,
        FolderName = "OnyxConfig",
        FileName = "BladeBall"
    },
    KeySystem = false,
})

-- 2. Create Tabs
local MainTab = Window:CreateTab("Main", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483345998)

-- 3. Feature Variables
local HubSettings = {
    AutoParry = false,
    ParryDistance = 25,
}

-- 4. Add Elements to the Main Tab
MainTab:CreateSection("Combat Controls")

MainTab:CreateToggle({
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParryToggle",
    Callback = function(Value)
        HubSettings.AutoParry = Value
        print("Auto Parry is now: " .. tostring(Value))
    end,
})

MainTab:CreateSlider({
    Name = "Parry Distance Threshold",
    Range = {10, 45},
    Increment = 1,
    Suffix = "studs",
    CurrentValue = 25,
    Flag = "DistanceSlider",
    Callback = function(Value)
        HubSettings.ParryDistance = Value
        print("Distance set to: " .. Value)
    end,
})

MainTab:CreateButton({
    Name = "Instant Manual Parry",
    Callback = function()
        local char = game.Players.LocalPlayer.Character
        if char then
            local tool = char:FindFirstChildOfClass("Tool")
            if tool then tool:Activate() end
        end
    end,
})

-- Notification to confirm load
Rayfield:Notify({
    Title = "Onyx Hub Loaded!",
    Content = "Your custom mobile framework is ready.",
    Duration = 4.5,
    Image = 4483362458,
})
