local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Oynx", Text = "UI only test", Duration = 3,
    })
end)

local sg = Instance.new("ScreenGui")
sg.ResetOnSpawn = false
sg.Name = "R_" .. tostring(math.random(100000, 999999))
sg.IgnoreGuiInset = true

local parented = false
if gethui then parented = pcall(function() sg.Parent = gethui() end) end
if not parented then parented = pcall(function() sg.Parent = CoreGui end) end
if not parented then pcall(function() sg.Parent = LocalPlayer:WaitForChild("PlayerGui", 5) end) end

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 500, 0, 320)
main.Position = UDim2.new(0.5, -250, 0.5, -160)
main.BackgroundColor3 = Color3.fromRGB(14, 14, 16)
main.BorderSizePixel = 0
main.Active = true
main.Draggable = true
main.Parent = sg

local c = Instance.new("UICorner")
c.CornerRadius = UDim.new(0, 8)
c.Parent = main

local s = Instance.new("UIStroke")
s.Color = Color3.fromRGB(40, 40, 46)
s.Thickness = 1
s.Parent = main

local bar = Instance.new("Frame")
bar.Size = UDim2.new(1, 0, 0, 36)
bar.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
bar.BorderSizePixel = 0
bar.Parent = main

local bc = Instance.new("UICorner")
bc.CornerRadius = UDim.new(0, 8)
bc.Parent = bar

local fix = Instance.new("Frame")
fix.Size = UDim2.new(1, 0, 0, 8)
fix.Position = UDim2.new(0, 0, 1, -8)
fix.BackgroundColor3 = Color3.fromRGB(16, 16, 19)
fix.BorderSizePixel = 0
fix.Parent = bar

local t = Instance.new("TextLabel")
t.Size = UDim2.new(1, -16, 1, 0)
t.Position = UDim2.new(0, 12, 0, 0)
t.BackgroundTransparency = 1
t.Text = "Oynx Hub  |  Blade Ball"
t.TextColor3 = Color3.fromRGB(230, 230, 235)
t.TextSize = 13
t.Font = Enum.Font.GothamMedium
t.TextXAlignment = Enum.TextXAlignment.Left
t.Parent = bar

local close = Instance.new("TextButton")
close.Size = UDim2.new(0, 28, 0, 28)
close.Position = UDim2.new(1, -32, 0, 4)
close.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(255, 255, 255)
close.TextSize = 13
close.Font = Enum.Font.GothamBold
close.BorderSizePixel = 0
close.Parent = bar

local cc = Instance.new("UICorner")
cc.CornerRadius = UDim.new(0, 5)
cc.Parent = close

close.MouseButton1Click:Connect(function()
    sg:Destroy()
end)

local body = Instance.new("TextLabel")
body.Size = UDim2.new(1, -20, 1, -60)
body.Position = UDim2.new(0, 10, 0, 46)
body.BackgroundTransparency = 1
body.Text = "UI Test OK\nNo remote calls fired.\nIf this shows and you don't get kicked,\nthe anti-cheat is triggered by the combat features."
body.TextColor3 = Color3.fromRGB(200, 200, 205)
body.TextSize = 14
body.Font = Enum.Font.Gotham
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top
body.Parent = main

game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Oynx", Text = "UI built OK", Duration = 3,
})
