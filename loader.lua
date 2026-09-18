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
    KeySystem = false, -- Set to true if you want a key system later
})

-- 2. Create Tabs
local MainTab = Window:CreateTab("Combat & Main", 4483362458)
local VisualsTab = Window:CreateTab("Visuals", 4483362458)

-- 3. Add Elements to Main Tab
MainTab:CreateSection("Auto Parry & Gameplay")

MainTab:CreateToggle({
    Name = "Auto Parry",
    CurrentValue = false,
    Flag = "AutoParryToggle",
    Callback = function(Value)
        if Value then
            print("Auto Parry Enabled!")
            -- Put your auto-parry activation code here
        else
            print("Auto Parry Disabled!")
            -- Put your auto-parry deactivation code here
        end
    end,
})

MainTab:CreateButton({
    Name = "Spam Parry Test",
    Callback = function()
        print("Spam parry executed!")
        -- Put manual/spam parry trigger code here
    end,
})

-- 4. Add Elements to Visuals Tab
VisualsTab:CreateSection("ESP & Settings")

VisualsTab:CreateToggle({
    Name = "Ball ESP",
    CurrentValue = false,
    Flag = "BallESP",
    Callback = function(Value)
        if Value then
            print("Ball ESP Enabled")
        else
            print("Ball ESP Disabled")
        end
    end,
})

-- Notify that the script has loaded successfully
Rayfield:Notify({
    Title = "Onyx Hub Loaded!",
    Content = "Successfully executed in Blade Ball.",
    Duration = 4,
    Image = 4483362458,
})
