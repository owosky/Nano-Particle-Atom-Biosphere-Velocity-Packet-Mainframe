-- ===========================================================================
-- [[ Load LinoriaLib & Managers ]]
-- ===========================================================================
local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'

local Library = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

-- ===========================================================================
-- [[ Window & Tab Initialization ]]
-- ===========================================================================
local Window = Library:CreateWindow({
    Title = 'Nano-Particle Atom Biosphere Velocity Packet Mainframe',
    Center = true,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2
})

local Tabs = {
    Aim = Window:AddTab('Aim'),
    ['UI Settings'] = Window:AddTab('UI Settings'),
}

-- ===========================================================================
-- [[ AIM TAB ]]
-- ===========================================================================
local AimMain = Tabs.Aim:AddLeftGroupbox('Aim Assist')
local AimSettings = Tabs.Aim:AddLeftGroupbox('Settings')
local FOVBox = Tabs.Aim:AddRightGroupbox('FOV')
local ChecksBox = Tabs.Aim:AddRightGroupbox('Checks')

-- [[ Aim Assist Main ]] 
AimMain:AddToggle('AimEnabled', {
    Text = 'Enable Aim Assist',
    Default = false,
    Tooltip = 'Master switch. If this is off, the keybind does nothing.'
}):AddKeyPicker('AimKey', {
    Default = 'MB2',
    SyncToggleState = false,
    Mode = 'Hold',
    Text = 'Aiming State',
    NoUI = false
})

AimMain:AddDropdown('AimMethod', {
    Values = { 'MouseMoveRel', 'Camera' },
    Default = 1,
    Multi = false,
    Text = 'Aim Method',
    Tooltip = 'Method used to snap to targets'
})

-- Multi-Select Dropdown for Parts
AimMain:AddDropdown('TargetParts', {
    Values = { 'Head', 'HumanoidRootPart', 'UpperTorso', 'LowerTorso' },
    Default = 1,
    Multi = true,
    Text = 'Target Parts',
    Tooltip = 'Select which parts to target. It will lock onto the closest selected part.'
})
Options.TargetParts:SetValue({ Head = true, HumanoidRootPart = true })

AimMain:AddToggle('StickyAim', {
    Text = 'Sticky Aim',
    Default = false,
    Tooltip = 'Keeps aiming at the current target even if others get closer'
})

-- [[ Aim Settings ]] 
AimSettings:AddToggle('UseSmoothness', {
    Text = 'Enable Smoothness',
    Default = false,
    Tooltip = 'Smoothes out the camera/mouse movements to prevent flicking'
})

AimSettings:AddSlider('AimSmoothness', {
    Text = 'Smoothness Amount',
    Default = 5,
    Min = 1,
    Max = 50,
    Rounding = 1,
    Compact = false
})

AimSettings:AddSlider('AimOffsetY', {
    Text = 'Vertical Aim Offset',
    Default = 0,
    Min = -100,
    Max = 100,
    Rounding = 0,
    Compact = false,
    Tooltip = 'Adjust if MouseMoveRel is aiming slightly above or below the target.'
})

AimSettings:AddToggle('UsePrediction', {
    Text = 'Enable Prediction',
    Default = false,
    Tooltip = 'Predicts player movement'
})

AimSettings:AddSlider('AimPredictionX', {
    Text = 'Prediction X (Horizontal)',
    Default = 0.1,
    Min = 0.0,
    Max = 100.0,
    Rounding = 2,
    Compact = false
})

AimSettings:AddSlider('AimPredictionY', {
    Text = 'Prediction Y (Vertical)',
    Default = 0.1,
    Min = 0.0,
    Max = 100.0,
    Rounding = 2,
    Compact = false
})

-- [[ FOV Settings ]] 
FOVBox:AddToggle('UseFOV', {
    Text = 'Limit to FOV',
    Default = true,
    Tooltip = 'Only target players inside your FOV radius'
})

FOVBox:AddToggle('DrawFOV', {
    Text = 'Draw FOV Circle',
    Default = false,
    Tooltip = 'Visually draws the FOV limits on screen'
}):AddColorPicker('FOVColor', {
    Default = Color3.fromRGB(255, 255, 255),
    Title = 'FOV Color',
    Transparency = 0.5,
})

FOVBox:AddSlider('FOVRadius', {
    Text = 'FOV Radius',
    Default = 100,
    Min = 10,
    Max = 800,
    Rounding = 0,
    Compact = false
})

-- [[ Checks ]] 
ChecksBox:AddToggle('TeamCheck', {
    Text = 'Team Check',
    Default = true,
    Tooltip = 'Prevents the aim assist from locking onto teammates'
})

ChecksBox:AddToggle('HealthCheck', {
    Text = 'Health Check',
    Default = true,
    Tooltip = 'Prevents the aim assist from locking onto dead players'
})

ChecksBox:AddToggle('VisCheck', {
    Text = 'Visibility Check',
    Default = true,
    Tooltip = 'Only targets players visible on your screen (behind walls are ignored)'
})

-- ===========================================================================
-- [[ UI SETTINGS TAB ]]
-- ===========================================================================
local MenuGroup = Tabs['UI Settings']:AddLeftGroupbox('Menu')

MenuGroup:AddButton('Unload', function() Library:Unload() end)
MenuGroup:AddLabel('Menu bind'):AddKeyPicker('MenuKeybind', { Default = 'End', NoUI = true, Text = 'Menu keybind' })

Library.ToggleKeybind = Options.MenuKeybind 

ThemeManager:SetLibrary(Library)
SaveManager:SetLibrary(Library)
SaveManager:IgnoreThemeSettings()
SaveManager:SetIgnoreIndexes({ 'MenuKeybind' })
ThemeManager:SetFolder('MyScriptHub')
SaveManager:SetFolder('MyScriptHub/AimScript')

SaveManager:BuildConfigSection(Tabs['UI Settings'])
ThemeManager:ApplyToTab(Tabs['UI Settings'])
SaveManager:LoadAutoloadConfig()

-- ===========================================================================
-- [[ AIMBOT LOGIC & MATH ]]
-- ===========================================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local Camera = Workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer

local FOVCircle = Drawing.new("Circle")
FOVCircle.Thickness = 1
FOVCircle.Filled = false
FOVCircle.NumSides = 60

local currentTarget = nil
local fractionX = 0
local fractionY = 0

Library:OnUnload(function()
    FOVCircle:Remove()
end)

-- Wall Check Raycasting
local function checkVisibility(targetPart)
    if not targetPart then return false end
    
    local origin = Camera.CFrame.Position
    local direction = targetPart.Position - origin
    
    local raycastParams = RaycastParams.new()
    raycastParams.FilterDescendantsInstances = {LocalPlayer.Character, Camera}
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.IgnoreWater = true

    local result = Workspace:Raycast(origin, direction, raycastParams)
    
    if result then
        if result.Instance:IsDescendantOf(targetPart.Parent) then
            return true
        end
        return false 
    end
    
    return true 
end

local function isPlayerValid(player)
    if not player or not player.Character or not player.Character:FindFirstChild("Humanoid") then return false end
    if Toggles.HealthCheck.Value and player.Character.Humanoid.Health <= 0 then return false end
    if Toggles.TeamCheck.Value and player.Team == LocalPlayer.Team then return false end
    return true
end

local function getBestTarget()
    local mousePos = UserInputService:GetMouseLocation()
    local closestDist = math.huge
    local bestTarget = nil

    if Toggles.StickyAim.Value and currentTarget and currentTarget.Player and currentTarget.Part then
        local p = currentTarget.Player
        local part = currentTarget.Part
        
        if isPlayerValid(p) and part.Parent == p.Character and Options.TargetParts.Value[part.Name] then
            local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen then
                if not Toggles.VisCheck.Value or checkVisibility(part) then
                    return currentTarget 
                end
            end
        end
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if not isPlayerValid(player) then continue end
        
        for partName, isSelected in pairs(Options.TargetParts.Value) do
            if isSelected then
                local part = player.Character:FindFirstChild(partName)
                if part then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
                    
                    if onScreen then
                        if not Toggles.VisCheck.Value or checkVisibility(part) then
                            local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
                            
                            if not Toggles.UseFOV.Value or dist <= Options.FOVRadius.Value then
                                if dist < closestDist then
                                    closestDist = dist
                                    bestTarget = { Player = player, Part = part }
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    
    return bestTarget
end

-- Main Render Loop
RunService.RenderStepped:Connect(function()
    local rawMouse = UserInputService:GetMouseLocation()
    
    if Toggles.DrawFOV.Value then
        FOVCircle.Visible = true
        FOVCircle.Radius = Options.FOVRadius.Value
        FOVCircle.Position = rawMouse
        FOVCircle.Color = Options.FOVColor.Value
        FOVCircle.Transparency = 1 - Options.FOVColor.Transparency
    else
        FOVCircle.Visible = false
    end

    local isMasterOn = Toggles.AimEnabled.Value
    local isAiming = Options.AimKey:GetState()

    if isMasterOn and isAiming then
        
        currentTarget = getBestTarget()

        if currentTarget and currentTarget.Part then
            local targetPart = currentTarget.Part
            local aimPosition = targetPart.Position
            
            local velocity = targetPart.AssemblyLinearVelocity
            
            if velocity.Magnitude < 2 then
                velocity = Vector3.new(0, 0, 0)
            elseif velocity.Magnitude > 300 then
                velocity = Vector3.new(0, 0, 0)
            end

            if Toggles.UsePrediction.Value then
                local predX = Options.AimPredictionX.Value
                local predY = Options.AimPredictionY.Value
                aimPosition = aimPosition + Vector3.new(velocity.X * predX, velocity.Y * predY, velocity.Z * predX)
            end
            
            local screenPos, onScreen = Camera:WorldToViewportPoint(aimPosition)
            if not onScreen then return end
            
            local smoothFactor = Toggles.UseSmoothness.Value and Options.AimSmoothness.Value or 1

            if Options.AimMethod.Value == 'Camera' then
                local targetCFrame = CFrame.new(Camera.CFrame.Position, aimPosition)
                if Toggles.UseSmoothness.Value then
                    Camera.CFrame = Camera.CFrame:Lerp(targetCFrame, 1 / smoothFactor)
                else
                    Camera.CFrame = targetCFrame
                end
                
            elseif Options.AimMethod.Value == 'MouseMoveRel' then
                -- Calculate pure pixel difference
                local deltaX = (screenPos.X - rawMouse.X)
                -- Add the user's custom vertical offset (Slide this up or down in the UI to fix the aiming height)
                local deltaY = (screenPos.Y - rawMouse.Y) + Options.AimOffsetY.Value
                
                if Toggles.UseSmoothness.Value then
                    deltaX = deltaX / smoothFactor
                    deltaY = deltaY / smoothFactor
                end
                
                -- Add current movement to the sub-pixel accumulator
                fractionX = fractionX + deltaX
                fractionY = fractionY + deltaY
                
                -- Separate the whole pixels from the decimals
                local moveX, fracX = math.modf(fractionX)
                local moveY, fracY = math.modf(fractionY)
                
                -- Save the decimals for the next frame
                fractionX = fracX
                fractionY = fracY
                
                -- Only move the mouse if we have a whole pixel to move
                if moveX ~= 0 or moveY ~= 0 then
                    mousemoverel(moveX, moveY)
                end
            end
        end
    else
        currentTarget = nil 
        fractionX = 0 
        fractionY = 0
    end
end)
