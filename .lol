local table_insert = table.insert

local Maid = {}
Maid.__index = Maid
function Maid.new() return setmetatable({_tasks = {}, _destroyed = false}, Maid) end
function Maid:GiveTask(task)
    if self._destroyed then
        if typeof(task) == "RBXScriptConnection" then task:Disconnect()
        elseif typeof(task) == "Instance" then task:Destroy()
        elseif type(task) == "function" then task()
        elseif type(task) == "table" and type(task.Destroy) == "function" then task:Destroy() end
        return
    end
    table_insert(self._tasks, task)
    return task
end
function Maid:DoCleaning()
    if self._destroyed then return end
    self._destroyed = true
    for _, t in pairs(self._tasks) do
        if typeof(t) == "RBXScriptConnection" then t:Disconnect()
        elseif typeof(t) == "Instance" then t:Destroy()
        elseif type(t) == "function" then t()
        elseif type(t) == "table" and type(t.Destroy) == "function" then t:Destroy() end
    end
    self._tasks = {}
end
function Maid:Destroy() self:DoCleaning() end

local RootMaid = Maid.new()

local shared = odh_shared_plugins

local Services = {
    Players = game:GetService("Players"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    RunService = game:GetService("RunService"),
    UserInputService = game:GetService("UserInputService"),
    TeleportService = game:GetService("TeleportService"),
    HttpService = game:GetService("HttpService"),
    Lighting = game:GetService("Lighting"),
    MarketplaceService = game:GetService("MarketplaceService"),
    StarterGui = game:GetService("StarterGui"),
    CoreGui = game:GetService("CoreGui")
}

local LocalPlayer = Services.Players.LocalPlayer

local function GetSafeGuiRoot()
    local success, result = pcall(function() return gethui() end)
    if success and typeof(result) == "Instance" then
        return result
    end
    return Services.CoreGui
end

local hiddenGuiParent = GetSafeGuiRoot()
local hiddenGui = hiddenGuiParent:FindFirstChild("HiddenGui")
if not hiddenGui then
    hiddenGui = Instance.new("ScreenGui")
    hiddenGui.Name = "HiddenGui"
    hiddenGui.ResetOnSpawn = false
    hiddenGui.IgnoreGuiInset = true
    hiddenGui.Parent = hiddenGuiParent
    RootMaid:GiveTask(hiddenGui)
end

local _game = shared.game_name

if _game == "Murder Mystery 2" or _game == "Murder Mystery Modded" then

local section = shared.AddSection("Bomb Jump+")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local bjGui = nil
local bjBtn = nil
local timerGui = nil
local timerDisplay = nil
local onCooldown = false
local bombJumpEnabled = false
local clickBombJumpEnabled = false
local guiEnabled = false
local timerGuiEnabled = false
local debounce = false
local bjSize = 40
local timerSize = 40
local autoGetBomb = false
local justRespawned = false

local activeTouches = {}
local TAP_MOVEMENT_THRESHOLD = 10
local TAP_TIME_THRESHOLD = 0.3

local BOMB_NAMES = {"Bomb", "PrankBomb", "FakeBomb"}

local BombJumpMaid = nil
local BombJumpGuiMaid = nil
local BombJumpTimerMaid = nil
local ClickBombJumpMaid = nil

section:AddLabel("Different Bomb Jump Options")

function CreateBJButton()
    if BombJumpGuiMaid then BombJumpGuiMaid:DoCleaning() BombJumpGuiMaid = nil end
    BombJumpGuiMaid = Maid.new()
    
    bjGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
    bjGui.Name = "BJGui"
    bjGui.ResetOnSpawn = false
    BombJumpGuiMaid:GiveTask(bjGui)
    
    bjBtn = Instance.new("TextButton", bjGui)
    bjBtn.Name = "BJButton"
    bjBtn.Text = "Ready"
    bjBtn.TextSize = 14
    bjBtn.Size = UDim2.new(0, bjSize, 0, bjSize)
    bjBtn.Position = UDim2.new(0.5, -bjSize/2, 0.8, 0)
    bjBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    bjBtn.TextColor3 = Color3.new(1, 1, 1)
    bjBtn.Font = Enum.Font.SourceSansLight
    bjBtn.BackgroundTransparency = 0.3
    Instance.new("UICorner", bjBtn).CornerRadius = UDim.new(1, 0)
    
    local stroke = Instance.new("UIStroke", bjBtn)
    stroke.Thickness = 2.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    local gradient = Instance.new("UIGradient", stroke)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 85, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    gradient.Rotation = 45
    
    bjBtn.MouseButton1Click:Connect(function()
        if not onCooldown and not debounce then
            FastBombJump()
        end
    end)
    
    local dragging, dragStart, startPos
    bjBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = bjBtn.Position
            input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then 
                    dragging = false 
                end 
            end)
        end
    end)
    
    bjBtn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            bjBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function CreateTimerDisplay()
    if BombJumpTimerMaid then BombJumpTimerMaid:DoCleaning() BombJumpTimerMaid = nil end
    BombJumpTimerMaid = Maid.new()
    
    timerGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
    timerGui.Name = "TimerGui"
    timerGui.ResetOnSpawn = false
    BombJumpTimerMaid:GiveTask(timerGui)
    
    timerDisplay = Instance.new("TextLabel", timerGui)
    timerDisplay.Name = "TimerDisplay"
    timerDisplay.Text = "Ready"
    timerDisplay.TextSize = 14
    timerDisplay.Size = UDim2.new(0, timerSize, 0, timerSize)
    timerDisplay.Position = UDim2.new(0.5, -timerSize/2 + 60, 0.8, 0)
    timerDisplay.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    timerDisplay.TextColor3 = Color3.new(1, 1, 1)
    timerDisplay.Font = Enum.Font.SourceSansLight
    timerDisplay.BackgroundTransparency = 0.3
    Instance.new("UICorner", timerDisplay).CornerRadius = UDim.new(1, 0)
    
    local stroke = Instance.new("UIStroke", timerDisplay)
    stroke.Thickness = 2.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    local gradient = Instance.new("UIGradient", stroke)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 85, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    gradient.Rotation = 45
    
    local dragging = false
    local dragStart, startPos
    
    timerDisplay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = timerDisplay.Position
            input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then 
                    dragging = false 
                end 
            end)
        end
    end)
    
    timerDisplay.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            timerDisplay.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function GetCenterPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local camera = Workspace.CurrentCamera
        local lookDir = camera.CFrame.LookVector
        return character.HumanoidRootPart.Position + (lookDir * 5)
    end
    return nil
end

function MakeCharacterJump()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

function ResetCooldown()
    onCooldown = false
    
    if bjBtn and bjBtn.Parent then
        bjBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        bjBtn.Text = "Ready"
    end
    
    if timerDisplay and timerDisplay.Parent then
        timerDisplay.Text = "Ready"
        timerDisplay.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

function StartCooldown()
    onCooldown = true
    debounce = false
    
    if bjBtn then
        bjBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        bjBtn.Text = "Wait"
    end
    
    if timerDisplay then
        timerDisplay.Text = "Wait"
        timerDisplay.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
    
    task.spawn(function()
        for i = 22, 1, -1 do
            if not onCooldown then break end
            
            if bjBtn and bjBtn.Parent then
                bjBtn.Text = tostring(i)
            end
            
            if timerDisplay then
                timerDisplay.Text = tostring(i)
            end
            task.wait(1)
        end
        
        if onCooldown then
            ResetCooldown()
        end
    end)
end

function UnequipBomb()
    task.spawn(function()
        task.wait(0.5)
        local character = LocalPlayer.Character
        if character then
            for _, bombName in ipairs(BOMB_NAMES) do
                local bomb = character:FindFirstChild(bombName)
                if bomb then
                    bomb.Parent = LocalPlayer.Backpack or character
                    break
                end
            end
        end
    end)
end

function GetBombInHand()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    for _, bombName in ipairs(BOMB_NAMES) do
        local bomb = character:FindFirstChild(bombName)
        if bomb then
            return bomb
        end
    end
    
    return nil
end

function GetAnyBomb()
    local character = LocalPlayer.Character
    if not character then return false, nil end
    
    for _, bombName in ipairs(BOMB_NAMES) do
        local bomb = character:FindFirstChild(bombName)
        if bomb then return true, bomb end
    end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, bombName in ipairs(BOMB_NAMES) do
            local bomb = backpack:FindFirstChild(bombName)
            if bomb then
                bomb.Parent = character
                return true, bomb
            end
        end
    end
    
    local success = pcall(function()
        ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("FakeBomb")
    end)
    
    if success then
        for _ = 1, 5 do
            for _, bombName in ipairs(BOMB_NAMES) do
                local bomb = character:FindFirstChild(bombName)
                if bomb then return true, bomb end
                
                if backpack then
                    bomb = backpack:FindFirstChild(bombName)
                    if bomb then
                        bomb.Parent = character
                        return true, bomb
                    end
                end
            end
            task.wait(0.05)
        end
    end
    
    return false, nil
end

function FastBombJump()
    if onCooldown or debounce or justRespawned then return end
    debounce = true
    
    local success, bomb = GetAnyBomb()
    
    if success and bomb then
        local position = GetCenterPosition()
        if position then
            local remote = bomb:FindFirstChild("Remote")
            if remote then
                pcall(function()
                    remote:FireServer(CFrame.new(position), 50)
                end)
            end
            
            MakeCharacterJump()
            UnequipBomb()
            
            task.spawn(function()
                task.wait(0.1)
                StartCooldown()
            end)
        end
    end
    
    task.spawn(function()
        task.wait(0.5)
        debounce = false
    end)
end

function SetupBombEquipDetection()
    if ClickBombJumpMaid then ClickBombJumpMaid:DoCleaning() ClickBombJumpMaid = nil end
    if not clickBombJumpEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    ClickBombJumpMaid = Maid.new()
    
    ClickBombJumpMaid:GiveTask(character.ChildAdded:Connect(function(child)
        if not clickBombJumpEnabled or justRespawned then return end
        
        for _, bombName in ipairs(BOMB_NAMES) do
            if child.Name == bombName then
                if not onCooldown and not debounce then
                    FastBombJump()
                end
                break
            end
        end
    end))
end

BombJumpMaid = Maid.new()
RootMaid:GiveTask(BombJumpMaid)

BombJumpMaid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.UserInputType == Enum.UserInputType.Touch or 
       input.UserInputType == Enum.UserInputType.MouseButton1 then
        
        activeTouches[input] = {
            startPosition = input.Position,
            startTime = tick(),
            moved = false
        }
    end
end))

BombJumpMaid:GiveTask(UserInputService.InputChanged:Connect(function(input)
    local touchData = activeTouches[input]
    if not touchData then return end
    
    local delta = input.Position - touchData.startPosition
    local distance = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)
    
    if distance > TAP_MOVEMENT_THRESHOLD then
        touchData.moved = true
    end
end))

BombJumpMaid:GiveTask(UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then 
        activeTouches[input] = nil
        return 
    end
    
    local touchData = activeTouches[input]
    if not touchData then return end
    
    local touchDuration = tick() - touchData.startTime
    local isRealTap = not touchData.moved and touchDuration <= TAP_TIME_THRESHOLD
    
    if isRealTap and bombJumpEnabled and not onCooldown and not debounce then
        local bombInHand = GetBombInHand()
        if bombInHand then
            FastBombJump()
        end
    end
    
    activeTouches[input] = nil
end))

BombJumpMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
    ResetCooldown()
    activeTouches = {}
    justRespawned = true
    
    task.spawn(function()
        task.wait(1)
        justRespawned = false
    end)
    
    if autoGetBomb then
        task.wait(1.2)
        pcall(function()
            ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("FakeBomb")
        end)
    end
    
    if clickBombJumpEnabled then
        task.wait(1.2)
        SetupBombEquipDetection()
    end
end))

section:AddToggle("Enable Auto Bomb Jump", function(bool)
    bombJumpEnabled = bool
end)

section:AddToggle("Enable Equip Bomb Jump", function(bool)
    clickBombJumpEnabled = bool
    
    if bool then
        SetupBombEquipDetection()
    else
        if ClickBombJumpMaid then ClickBombJumpMaid:DoCleaning() ClickBombJumpMaid = nil end
    end
end)

section:AddToggle("Auto-Get Fake Bomb", function(bool)
    autoGetBomb = bool
end)

section:AddToggle("Enable BJ Button", function(e)
    guiEnabled = e
    if e then 
        CreateBJButton() 
    else 
        if BombJumpGuiMaid then BombJumpGuiMaid:DoCleaning() BombJumpGuiMaid = nil end
    end
end)

section:AddSlider("BJ Button Size", 30, 150, bjSize, function(s)
    bjSize = s
    if bjBtn then 
        bjBtn.Size = UDim2.new(0, s, 0, s)
        bjBtn.Position = UDim2.new(0.5, -s/2, 0.8, 0)
    end
end)

section:AddToggle("Enable Timer Display", function(e)
    timerGuiEnabled = e
    if e then 
        CreateTimerDisplay() 
    else 
        if BombJumpTimerMaid then BombJumpTimerMaid:DoCleaning() BombJumpTimerMaid = nil end
    end
end)

section:AddSlider("Timer Display Size", 30, 150, timerSize, function(s)
    timerSize = s
    if timerDisplay then 
        timerDisplay.Size = UDim2.new(0, s, 0, s)
        timerDisplay.Position = UDim2.new(0.5, -s/2 + 60, 0.8, 0)
    end
end)

section:AddKeybind("Manual Bomb Jump", "E", function()
    if not onCooldown and not debounce then
        FastBombJump()
    end
end)

RootMaid:GiveTask(function()
    if BombJumpGuiMaid then BombJumpGuiMaid:DoCleaning() end
    if BombJumpTimerMaid then BombJumpTimerMaid:DoCleaning() end
    if ClickBombJumpMaid then ClickBombJumpMaid:DoCleaning() end
    if BombJumpMaid then BombJumpMaid:DoCleaning() end
    
    activeTouches = {}
    ResetCooldown()
    bombJumpEnabled = false
    clickBombJumpEnabled = false
    guiEnabled = false
    timerGuiEnabled = false
    autoGetBomb = false
end)

end

if _game == "Murder Mystery Modded" then

local gbjSection = shared.AddSection("Gold Bomb Jump+")

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local gbjGui = nil
local gbjBtn = nil
local gbjTimerGui = nil
local gbjTimerDisplay = nil
local gbjOnCooldown = false
local goldBombJumpEnabled = false
local clickGoldBombJumpEnabled = false
local gbjGuiEnabled = false
local gbjTimerGuiEnabled = false
local gbjDebounce = false
local gbjSize = 40
local gbjTimerSize = 40
local autoGetGoldBomb = false
local gbjJustRespawned = false

local gbjActiveTouches = {}
local GBJ_TAP_MOVEMENT_THRESHOLD = 10
local GBJ_TAP_TIME_THRESHOLD = 0.3

local GOLD_BOMB_NAME = "GoldBomb"

local GoldBombJumpMaid = nil
local GoldBombJumpGuiMaid = nil
local GoldBombJumpTimerMaid = nil
local ClickGoldBombJumpMaid = nil

gbjSection:AddLabel("Different Gold Bomb Jump Options")

function CreateGBJButton()
    if GoldBombJumpGuiMaid then GoldBombJumpGuiMaid:DoCleaning() GoldBombJumpGuiMaid = nil end
    GoldBombJumpGuiMaid = Maid.new()
    
    gbjGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
    gbjGui.Name = "GBJGui"
    gbjGui.ResetOnSpawn = false
    GoldBombJumpGuiMaid:GiveTask(gbjGui)
    
    gbjBtn = Instance.new("TextButton", gbjGui)
    gbjBtn.Name = "GBJButton"
    gbjBtn.Text = "Ready"
    gbjBtn.TextSize = 14
    gbjBtn.Size = UDim2.new(0, gbjSize, 0, gbjSize)
    gbjBtn.Position = UDim2.new(0.5, -gbjSize/2, 0.7, 0)
    gbjBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    gbjBtn.TextColor3 = Color3.new(1, 1, 1)
    gbjBtn.Font = Enum.Font.SourceSans
    gbjBtn.BackgroundTransparency = 0.3
    Instance.new("UICorner", gbjBtn).CornerRadius = UDim.new(1, 0)
    
    local stroke = Instance.new("UIStroke", gbjBtn)
    stroke.Thickness = 2.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    local gradient = Instance.new("UIGradient", stroke)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(218, 165, 32)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    gradient.Rotation = 45
    
    gbjBtn.MouseButton1Click:Connect(function()
        if not gbjOnCooldown and not gbjDebounce then
            FastGoldBombJump()
        end
    end)
    
    local dragging, dragStart, startPos
    gbjBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gbjBtn.Position
            input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then 
                    dragging = false 
                end 
            end)
        end
    end)
    
    gbjBtn.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            gbjBtn.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function CreateGBJTimerDisplay()
    if GoldBombJumpTimerMaid then GoldBombJumpTimerMaid:DoCleaning() GoldBombJumpTimerMaid = nil end
    GoldBombJumpTimerMaid = Maid.new()
    
    gbjTimerGui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
    gbjTimerGui.Name = "GBJTimerGui"
    gbjTimerGui.ResetOnSpawn = false
    GoldBombJumpTimerMaid:GiveTask(gbjTimerGui)
    
    gbjTimerDisplay = Instance.new("TextLabel", gbjTimerGui)
    gbjTimerDisplay.Name = "GBJTimerDisplay"
    gbjTimerDisplay.Text = "Ready"
    gbjTimerDisplay.TextSize = 14
    gbjTimerDisplay.Size = UDim2.new(0, gbjTimerSize, 0, gbjTimerSize)
    gbjTimerDisplay.Position = UDim2.new(0.5, -gbjTimerSize/2 + 60, 0.7, 0)
    gbjTimerDisplay.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    gbjTimerDisplay.TextColor3 = Color3.new(1, 1, 1)
    gbjTimerDisplay.Font = Enum.Font.SourceSans
    gbjTimerDisplay.BackgroundTransparency = 0.3
    Instance.new("UICorner", gbjTimerDisplay).CornerRadius = UDim.new(1, 0)
    
    local stroke = Instance.new("UIStroke", gbjTimerDisplay)
    stroke.Thickness = 2.5
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    
    local gradient = Instance.new("UIGradient", stroke)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(218, 165, 32)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 0))
    }
    gradient.Rotation = 45
    
    local dragging = false
    local dragStart, startPos
    
    gbjTimerDisplay.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = gbjTimerDisplay.Position
            input.Changed:Connect(function() 
                if input.UserInputState == Enum.UserInputState.End then 
                    dragging = false 
                end 
            end)
        end
    end)
    
    gbjTimerDisplay.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            gbjTimerDisplay.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)
end

function GBJGetCenterPosition()
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local camera = Workspace.CurrentCamera
        local lookDir = camera.CFrame.LookVector
        return character.HumanoidRootPart.Position + (lookDir * 5)
    end
    return nil
end

function GBJMakeCharacterJump()
    local character = LocalPlayer.Character
    if character then
        local humanoid = character:FindFirstChild("Humanoid")
        if humanoid then
            humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end
end

function GBJResetCooldown()
    gbjOnCooldown = false
    
    if gbjBtn and gbjBtn.Parent then
        gbjBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        gbjBtn.Text = "Ready"
    end
    
    if gbjTimerDisplay and gbjTimerDisplay.Parent then
        gbjTimerDisplay.Text = "Ready"
        gbjTimerDisplay.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    end
end

function GBJStartCooldown()
    gbjOnCooldown = true
    gbjDebounce = false
    
    if gbjBtn then
        gbjBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
        gbjBtn.Text = "Wait"
    end
    
    if gbjTimerDisplay then
        gbjTimerDisplay.Text = "Wait"
        gbjTimerDisplay.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    end
    
    task.spawn(function()
        for i = 4, 1, -1 do
            if not gbjOnCooldown then break end
            
            if gbjBtn and gbjBtn.Parent then
                gbjBtn.Text = tostring(i)
            end
            
            if gbjTimerDisplay then
                gbjTimerDisplay.Text = tostring(i)
            end
            task.wait(1)
        end
        
        if gbjOnCooldown then
            GBJResetCooldown()
        end
    end)
end

function UnequipGoldBomb()
    task.spawn(function()
        task.wait(0.5)
        local character = LocalPlayer.Character
        if character then
            local bomb = character:FindFirstChild(GOLD_BOMB_NAME)
            if bomb then
                bomb.Parent = LocalPlayer.Backpack or character
            end
        end
    end)
end

function GetGoldBombInHand()
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChild(GOLD_BOMB_NAME)
end

function GetAnyGoldBomb()
    local character = LocalPlayer.Character
    if not character then return false, nil end

    local bomb = character:FindFirstChild(GOLD_BOMB_NAME)
    if bomb then return true, bomb end

    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        bomb = backpack:FindFirstChild(GOLD_BOMB_NAME)
        if bomb then
            bomb.Parent = character
            return true, bomb
        end
    end

    local success = pcall(function()
        ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("GoldBomb")
    end)

    if success then
        for _ = 1, 5 do
            bomb = character:FindFirstChild(GOLD_BOMB_NAME)
            if bomb then return true, bomb end

            if backpack then
                bomb = backpack:FindFirstChild(GOLD_BOMB_NAME)
                if bomb then
                    bomb.Parent = character
                    return true, bomb
                end
            end
            task.wait(0.05)
        end
    end

    return false, nil
end

function FastGoldBombJump()
    if gbjOnCooldown or gbjDebounce or gbjJustRespawned then return end
    gbjDebounce = true

    local success, bomb = GetAnyGoldBomb()

    if success and bomb then
        local position = GBJGetCenterPosition()
        if position then
            local remote = bomb:FindFirstChild("Remote")
            if remote then
                pcall(function()
                    remote:FireServer(CFrame.new(position), 50)
                end)
            end

            GBJMakeCharacterJump()
            UnequipGoldBomb()

            task.spawn(function()
                task.wait(0.1)
                GBJStartCooldown()
            end)
        end
    end

    task.spawn(function()
        task.wait(0.5)
        gbjDebounce = false
    end)
end

function SetupGoldBombEquipDetection()
    if ClickGoldBombJumpMaid then ClickGoldBombJumpMaid:DoCleaning() ClickGoldBombJumpMaid = nil end
    if not clickGoldBombJumpEnabled then return end

    local character = LocalPlayer.Character
    if not character then return end

    ClickGoldBombJumpMaid = Maid.new()
    
    ClickGoldBombJumpMaid:GiveTask(character.ChildAdded:Connect(function(child)
        if not clickGoldBombJumpEnabled or gbjJustRespawned then return end

        if child.Name == GOLD_BOMB_NAME then
            if not gbjOnCooldown and not gbjDebounce then
                FastGoldBombJump()
            end
        end
    end))
end

GoldBombJumpMaid = Maid.new()
RootMaid:GiveTask(GoldBombJumpMaid)

GoldBombJumpMaid:GiveTask(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if input.UserInputType == Enum.UserInputType.Touch or
       input.UserInputType == Enum.UserInputType.MouseButton1 then

        gbjActiveTouches[input] = {
            startPosition = input.Position,
            startTime = tick(),
            moved = false
        }
    end
end))

GoldBombJumpMaid:GiveTask(UserInputService.InputChanged:Connect(function(input)
    local gbjTouchData = gbjActiveTouches[input]
    if not gbjTouchData then return end

    local delta = input.Position - gbjTouchData.startPosition
    local distance = math.sqrt(delta.X * delta.X + delta.Y * delta.Y)

    if distance > GBJ_TAP_MOVEMENT_THRESHOLD then
        gbjTouchData.moved = true
    end
end))

GoldBombJumpMaid:GiveTask(UserInputService.InputEnded:Connect(function(input, gameProcessed)
    if gameProcessed then
        gbjActiveTouches[input] = nil
        return
    end

    local gbjTouchData = gbjActiveTouches[input]
    if not gbjTouchData then return end

    local touchDuration = tick() - gbjTouchData.startTime
    local isRealTap = not gbjTouchData.moved and touchDuration <= GBJ_TAP_TIME_THRESHOLD

    if isRealTap and goldBombJumpEnabled and not gbjOnCooldown and not gbjDebounce then
        local bombInHand = GetGoldBombInHand()
        if bombInHand then
            FastGoldBombJump()
        end
    end

    gbjActiveTouches[input] = nil
end))

GoldBombJumpMaid:GiveTask(LocalPlayer.CharacterAdded:Connect(function()
    GBJResetCooldown()
    gbjActiveTouches = {}
    gbjJustRespawned = true

    task.spawn(function()
        task.wait(1)
        gbjJustRespawned = false
    end)

    if autoGetGoldBomb then
        task.wait(1.2)
        pcall(function()
            ReplicatedStorage.Remotes.Extras.ReplicateToy:InvokeServer("GoldBomb")
        end)
    end

    if clickGoldBombJumpEnabled then
        task.wait(1.2)
        SetupGoldBombEquipDetection()
    end
end))

gbjSection:AddToggle("Enable Auto Gold Bomb Jump", function(bool)
    goldBombJumpEnabled = bool
end)

gbjSection:AddToggle("Enable Equip Gold Bomb Jump", function(bool)
    clickGoldBombJumpEnabled = bool

    if bool then
        SetupGoldBombEquipDetection()
    else
        if ClickGoldBombJumpMaid then ClickGoldBombJumpMaid:DoCleaning() ClickGoldBombJumpMaid = nil end
    end
end)

gbjSection:AddToggle("Auto-Get Gold Bomb", function(bool)
    autoGetGoldBomb = bool
end)

gbjSection:AddToggle("Enable GBJ Button", function(e)
    gbjGuiEnabled = e
    if e then
        CreateGBJButton()
    else
        if GoldBombJumpGuiMaid then GoldBombJumpGuiMaid:DoCleaning() GoldBombJumpGuiMaid = nil end
    end
end)

gbjSection:AddSlider("GBJ Button Size", 30, 150, gbjSize, function(s)
    gbjSize = s
    if gbjBtn then
        gbjBtn.Size = UDim2.new(0, s, 0, s)
        gbjBtn.Position = UDim2.new(0.5, -s/2, 0.7, 0)
    end
end)

gbjSection:AddToggle("Enable GBJ Timer Display", function(e)
    gbjTimerGuiEnabled = e
    if e then
        CreateGBJTimerDisplay()
    else
        if GoldBombJumpTimerMaid then GoldBombJumpTimerMaid:DoCleaning() GoldBombJumpTimerMaid = nil end
    end
end)

gbjSection:AddSlider("GBJ Timer Display Size", 30, 150, gbjTimerSize, function(s)
    gbjTimerSize = s
    if gbjTimerDisplay then
        gbjTimerDisplay.Size = UDim2.new(0, s, 0, s)
        gbjTimerDisplay.Position = UDim2.new(0.5, -s/2 + 60, 0.7, 0)
    end
end)

gbjSection:AddKeybind("Manual Gold Bomb Jump", "G", function()
    if not gbjOnCooldown and not gbjDebounce then
        FastGoldBombJump()
    end
end)

RootMaid:GiveTask(function()
    if GoldBombJumpGuiMaid then GoldBombJumpGuiMaid:DoCleaning() end
    if GoldBombJumpTimerMaid then GoldBombJumpTimerMaid:DoCleaning() end
    if ClickGoldBombJumpMaid then ClickGoldBombJumpMaid:DoCleaning() end
    if GoldBombJumpMaid then GoldBombJumpMaid:DoCleaning() end
    
    gbjActiveTouches = {}
    GBJResetCooldown()
    goldBombJumpEnabled = false
    clickGoldBombJumpEnabled = false
    gbjGuiEnabled = false
    gbjTimerGuiEnabled = false
    autoGetGoldBomb = false
end)

end
