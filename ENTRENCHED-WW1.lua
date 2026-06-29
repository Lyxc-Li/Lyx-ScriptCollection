local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local Camera = workspace.CurrentCamera
local plr = Players.LocalPlayer

local ShootEvent = game:GetService("ReplicatedStorage").ServerEvents.Shoot

local repo = 'https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/'
local Library      = loadstring(game:HttpGet(repo .. 'Library.lua'))()
local ThemeManager = loadstring(game:HttpGet(repo .. 'addons/ThemeManager.lua'))()
local SaveManager  = loadstring(game:HttpGet(repo .. 'addons/SaveManager.lua'))()

local Settings = {
	FOV_Enabled = true,
	FOV_Radius = 100,
	FOV_Visible = true,
	Aimbot_Enabled = false,
	Aimbot_Smoothing = 1,
	Aimbot_AimPart = "Closest",
	VisibleOnly = true,
	NoRecoil = true,
	AntiSpread = false,
	Triggerbot = false,
	TriggerRadius = 15,
	TriggerDelay = 0,
	AimPrediction = true,
	BulletSpeed = 4100,
	BulletGravity = Vector3.zero,
	FOVColor = Color3.fromRGB(255, 255, 255),
	SnaplineColor = Color3.fromRGB(255, 255, 0),
	-- world mods
	Fullbright = true,
	NoFog = true,
	NoSuppression = false,
	NoScopeBlur = false,
	WideFOV = false,
	FOVAmount = 90,
	-- ESP
	ESP_2D = false,
	ESP_3D = false,
	ESP_Skeleton = false,
	ESP_HealthBar = true,
	ESP_Distance = false,
	ESP_Tracers = false,
	ESP_TeamColor = true,
	ESP_Names = true,
	ESP_Weapon = false,
	ESP_Chams = true,
	ESP_Snapline = true,
	ESP_EnemyOnly = true,
	EnemyColor = Color3.fromRGB(255, 0, 0),
	AllyColor = Color3.fromRGB(0, 255, 0),
	-- misc
	SpeedBoost = false,
	SpeedAmount = 5,
	AutoDeploy = false,
	AnimCancel = false,
	NoJumpCooldown = false,
	JumpBoost = false,
	MiscDebug = false,
}

local lockedTarget = nil
local aimbotHeld = false
local currentFOVTarget = nil
local connections = {}

-- save originals for restore on unload
local origAmbient = Lighting.Ambient
local origBrightness = Lighting.Brightness
local origFogEnd = Lighting.FogEnd
local origFogStart = Lighting.FogStart
local origAtmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local origAtmoDensity = origAtmosphere and origAtmosphere.Density or 0
local origAtmoOffset = origAtmosphere and origAtmosphere.Offset or 0

----------------------------------------------------------------
-- Linoria UI
----------------------------------------------------------------
local Window = Library:CreateWindow({
	Title = "Trenches",
	Center = true,
	AutoShow = true,
})

-- render menu above game UI
pcall(function()
	local coreGui = game:GetService("CoreGui")
	for _, gui in coreGui:GetChildren() do
		if gui:IsA("ScreenGui") and gui.Name == "Linoria" then
			gui.DisplayOrder = 999
		end
	end
end)

local AimbotTab = Window:AddTab("Aimbot")
local ESPTab = Window:AddTab("ESP")
local WorldTab = Window:AddTab("World")
local MiscTab = Window:AddTab("Misc")
local SettingsTab = Window:AddTab("Settings")

-- Aimbot > FOV
local FOVGroup = AimbotTab:AddLeftGroupbox("FOV")

FOVGroup:AddToggle("FOV_Enabled", { Text = "Enable FOV", Default = true })
	:OnChanged(function(v) Settings.FOV_Enabled = v end)

FOVGroup:AddToggle("FOV_Visible", { Text = "Show Circle", Default = true })
	:OnChanged(function(v) Settings.FOV_Visible = v end)

FOVGroup:AddSlider("FOV_Radius", { Text = "Radius", Default = 100, Min = 10, Max = 500, Rounding = 0 })
	:OnChanged(function(v) Settings.FOV_Radius = v end)

FOVGroup:AddLabel("FOV Color"):AddColorPicker("FOVColor", { Default = Color3.fromRGB(255, 255, 255) })
Options.FOVColor:OnChanged(function()
	Settings.FOVColor = Options.FOVColor.Value
end)

FOVGroup:AddToggle("VisibleOnly", { Text = "Visible Only", Default = true })
	:OnChanged(function(v) Settings.VisibleOnly = v end)

FOVGroup:AddToggle("ESP_Snapline", { Text = "Snapline", Default = true })
	:OnChanged(function(v) Settings.ESP_Snapline = v end)

FOVGroup:AddLabel("Snapline Color"):AddColorPicker("SnaplineColor", { Default = Color3.fromRGB(255, 255, 0) })
Options.SnaplineColor:OnChanged(function()
	Settings.SnaplineColor = Options.SnaplineColor.Value
end)

-- Aimbot > Lock
local LockGroup = AimbotTab:AddRightGroupbox("Aimlock")

LockGroup:AddToggle("Aimbot_Enabled", { Text = "Enable Aimbot", Default = false })
	:OnChanged(function(v) Settings.Aimbot_Enabled = v end)

LockGroup:AddLabel("Aimbot Key"):AddKeyPicker("AimbotKey", {
	Default = "CapsLock",
	SyncToggleState = false,
	Mode = "Hold",
	Text = "Aimbot Hold",
})

LockGroup:AddSlider("Aimbot_Smoothing", { Text = "Smoothing", Default = 1, Min = 0.01, Max = 1, Rounding = 2 })
	:OnChanged(function(v) Settings.Aimbot_Smoothing = v end)

LockGroup:AddDropdown("Aimbot_AimPart", { Text = "Aim Part", Default = "Closest", Values = {"Closest", "Head", "UpperTorso", "HumanoidRootPart"} })
	:OnChanged(function(v) Settings.Aimbot_AimPart = v end)

-- Aimbot > Triggerbot
local TriggerGroup = AimbotTab:AddLeftGroupbox("Triggerbot")

TriggerGroup:AddToggle("Triggerbot", { Text = "Enable Triggerbot", Default = false })
	:OnChanged(function(v) Settings.Triggerbot = v end)

TriggerGroup:AddSlider("TriggerRadius", { Text = "Trigger Radius (px)", Default = 15, Min = 1, Max = 50, Rounding = 0 })
	:OnChanged(function(v) Settings.TriggerRadius = v end)

TriggerGroup:AddSlider("TriggerDelay", { Text = "Trigger Delay (ms)", Default = 0, Min = 0, Max = 100, Rounding = 0 })
	:OnChanged(function(v) Settings.TriggerDelay = v end)

-- Aimbot > Prediction
LockGroup:AddToggle("AimPrediction", { Text = "Aim Prediction", Default = true })
	:OnChanged(function(v) Settings.AimPrediction = v end)

LockGroup:AddInput("BulletSpeed", { Text = "Bullet Speed", Default = "4100", Numeric = true, Finished = true })
	:OnChanged(function(v)
		local n = tonumber(v)
		if n and n > 0 then Settings.BulletSpeed = n end
	end)

-- Aimbot > Weapon Mods
local WeaponModGroup = AimbotTab:AddRightGroupbox("Weapon Mods")

WeaponModGroup:AddToggle("NoRecoil", { Text = "No Recoil", Default = true })
	:OnChanged(function(v) Settings.NoRecoil = v end)

WeaponModGroup:AddToggle("AntiSpread", { Text = "Anti Spread", Default = false })
	:OnChanged(function(v) Settings.AntiSpread = v end)

-- ESP tab
local BoxGroup = ESPTab:AddLeftGroupbox("Visuals")

BoxGroup:AddToggle("ESP_2D", { Text = "2D Box", Default = false })
	:OnChanged(function(v) Settings.ESP_2D = v end)

BoxGroup:AddToggle("ESP_3D", { Text = "3D Box", Default = false })
	:OnChanged(function(v) Settings.ESP_3D = v end)

BoxGroup:AddToggle("ESP_Skeleton", { Text = "Skeleton", Default = false })
	:OnChanged(function(v) Settings.ESP_Skeleton = v end)

BoxGroup:AddToggle("ESP_Names", { Text = "Names", Default = true })
	:OnChanged(function(v) Settings.ESP_Names = v end)

BoxGroup:AddToggle("ESP_Weapon", { Text = "Weapon Name", Default = false })
	:OnChanged(function(v) Settings.ESP_Weapon = v end)

BoxGroup:AddToggle("ESP_Chams", { Text = "Chams (Highlight)", Default = true })
	:OnChanged(function(v) Settings.ESP_Chams = v end)

local ExtrasGroup = ESPTab:AddRightGroupbox("Extras")

ExtrasGroup:AddToggle("ESP_HealthBar", { Text = "Health Bar", Default = true })
	:OnChanged(function(v) Settings.ESP_HealthBar = v end)

ExtrasGroup:AddToggle("ESP_Distance", { Text = "Distance", Default = false })
	:OnChanged(function(v) Settings.ESP_Distance = v end)

ExtrasGroup:AddToggle("ESP_Tracers", { Text = "Tracers", Default = false })
	:OnChanged(function(v) Settings.ESP_Tracers = v end)

ExtrasGroup:AddToggle("ESP_TeamColor", { Text = "Team Colors", Default = true })
	:OnChanged(function(v) Settings.ESP_TeamColor = v end)

ExtrasGroup:AddToggle("ESP_EnemyOnly", { Text = "Enemy Only", Default = true })
	:OnChanged(function(v) Settings.ESP_EnemyOnly = v end)

local ColorGroup = ESPTab:AddRightGroupbox("Colors")

ColorGroup:AddLabel("Enemy Color"):AddColorPicker("EnemyColor", { Default = Color3.fromRGB(255, 0, 0) })
Options.EnemyColor:OnChanged(function()
	Settings.EnemyColor = Options.EnemyColor.Value
end)

ColorGroup:AddLabel("Ally Color"):AddColorPicker("AllyColor", { Default = Color3.fromRGB(0, 255, 0) })
Options.AllyColor:OnChanged(function()
	Settings.AllyColor = Options.AllyColor.Value
end)

-- World tab
local VisualGroup = WorldTab:AddLeftGroupbox("Visual Mods")

VisualGroup:AddToggle("Fullbright", { Text = "Fullbright", Default = true })
	:OnChanged(function(v)
		Settings.Fullbright = v
		if v then
			Lighting.Ambient = Color3.fromRGB(200, 200, 200)
			Lighting.Brightness = 2
		else
			Lighting.Ambient = origAmbient
			Lighting.Brightness = origBrightness
		end
	end)

VisualGroup:AddToggle("NoFog", { Text = "No Fog", Default = true })
	:OnChanged(function(v)
		Settings.NoFog = v
		if v then
			Lighting.FogEnd = 1e6
			Lighting.FogStart = 1e6
			-- also clear Atmosphere fog
			local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmo then
				atmo.Density = 0
				atmo.Offset = 1
			end
		else
			Lighting.FogEnd = origFogEnd
			Lighting.FogStart = origFogStart
			local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
			if atmo then
				atmo.Density = origAtmoDensity
				atmo.Offset = origAtmoOffset
			end
		end
	end)

VisualGroup:AddToggle("NoSuppression", { Text = "No Suppression", Default = false })
	:OnChanged(function(v) Settings.NoSuppression = v end)

VisualGroup:AddToggle("NoScopeBlur", { Text = "No Scope Blur", Default = false })
	:OnChanged(function(v)
		Settings.NoScopeBlur = v
		local blur = Lighting:FindFirstChild("scopeBlur")
		if blur then blur.Size = v and 0 or blur.Size end
	end)

local CameraGroup = WorldTab:AddRightGroupbox("Camera")

CameraGroup:AddToggle("WideFOV", { Text = "Wide FOV", Default = false })
	:OnChanged(function(v) Settings.WideFOV = v end)

CameraGroup:AddSlider("FOVAmount", { Text = "FOV", Default = 90, Min = 70, Max = 120, Rounding = 0 })
	:OnChanged(function(v) Settings.FOVAmount = v end)

-- Misc tab
local SpeedGroup = MiscTab:AddLeftGroupbox("Movement")

SpeedGroup:AddToggle("SpeedBoost", { Text = "Speed Boost", Default = false })
	:OnChanged(function(v) Settings.SpeedBoost = v end)

SpeedGroup:AddSlider("SpeedAmount", { Text = "Extra Speed", Default = 5, Min = 1, Max = 8, Rounding = 0 })
	:OnChanged(function(v) Settings.SpeedAmount = v end)

SpeedGroup:AddToggle("NoJumpCooldown", { Text = "No Jump Cooldown", Default = false })
	:OnChanged(function(v) Settings.NoJumpCooldown = v end)

SpeedGroup:AddToggle("JumpBoost", { Text = "Max Jump Height", Default = false })
	:OnChanged(function(v) Settings.JumpBoost = v end)

local CombatGroup = MiscTab:AddLeftGroupbox("Combat")

CombatGroup:AddToggle("AnimCancel", { Text = "Anim Cancel", Default = false })
	:OnChanged(function(v) Settings.AnimCancel = v end)


local AutoGroup = MiscTab:AddRightGroupbox("Automation")

AutoGroup:AddToggle("AutoDeploy", { Text = "Auto Deploy", Default = false })
	:OnChanged(function(v) Settings.AutoDeploy = v end)

AutoGroup:AddToggle("MiscDebug", { Text = "Debug Log", Default = false })
	:OnChanged(function(v) Settings.MiscDebug = v end)

-- Settings tab
SaveManager:SetLibrary(Library)
ThemeManager:SetLibrary(Library)
SaveManager:SetFolder("Trenches")
ThemeManager:SetFolder("Trenches")

SaveManager:BuildConfigSection(SettingsTab)
ThemeManager:ApplyToTab(SettingsTab)

local MenuGroup = SettingsTab:AddRightGroupbox("Menu")

MenuGroup:AddLabel("Menu Keybind"):AddKeyPicker("MenuKeybind", {
	Default = "LeftControl",
	SyncToggleState = false,
	Mode = "Toggle",
	Text = "Menu Toggle",
})
Library.ToggleKeybind = Options.MenuKeybind

MenuGroup:AddButton("Unload", function()
	for _, conn in connections do
		if conn.Connected then conn:Disconnect() end
	end
	pcall(function() fovCircle:Remove() end)
	pcall(function() snapline:Remove() end)
	pcall(function() highlightDot:Remove() end)
	if espCache then
		for _, esp in espCache do
			for _, l in esp.box2d do l:Remove() end
			for _, l in esp.box3d do l:Remove() end
			for _, l in esp.skeleton do l:Remove() end
			esp.name:Remove()
			esp.weapon:Remove()
			esp.dist:Remove()
			esp.tracer:Remove()
			esp.healthBg:Remove()
			esp.healthBar:Remove()
		end
	end
	espCache = {}
	if chamsCache then
		for _, hl in chamsCache do hl:Destroy() end
	end
	chamsCache = {}
	-- restore world
	Lighting.Ambient = origAmbient
	Lighting.Brightness = origBrightness
	Lighting.FogEnd = origFogEnd
	Lighting.FogStart = origFogStart
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = origAtmoDensity
		atmo.Offset = origAtmoOffset
	end
	Library:Unload()
end)

-- apply defaults on startup
if Settings.Fullbright then
	Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	Lighting.Brightness = 2
end
if Settings.NoFog then
	Lighting.FogEnd = 1e6
	Lighting.FogStart = 1e6
	local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmo then
		atmo.Density = 0
		atmo.Offset = 1
	end
end

-- force FOV override via GetPropertyChangedSignal — kills game tweens instantly
connections[#connections + 1] = workspace.CurrentCamera:GetPropertyChangedSignal("FieldOfView"):Connect(function()
	if Settings.WideFOV and workspace.CurrentCamera.FieldOfView ~= Settings.FOVAmount then
		workspace.CurrentCamera.FieldOfView = Settings.FOVAmount
	end
end)

----------------------------------------------------------------
-- FOV circle + Snapline
----------------------------------------------------------------
local fovCircle = Drawing.new("Circle")
fovCircle.Color = Color3.fromRGB(255, 255, 255)
fovCircle.Thickness = 1
fovCircle.Filled = false
fovCircle.Transparency = 0.7

local snapline = Drawing.new("Line")
snapline.Color = Color3.fromRGB(255, 255, 0)
snapline.Thickness = 1
snapline.Visible = false

----------------------------------------------------------------
-- Utility
----------------------------------------------------------------
local function isAlive(character)
	local hum = character:FindFirstChildOfClass("Humanoid")
	return hum and hum.Health > 0
end

local function isVisible(origin, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(ignore, p.Character) end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, target.Position - origin, params)
	return result == nil
end

-- info: like isVisible but pierces through semi-transparent objects (Transparency > 0.3)
local function isVisibleThroughGlass(origin, target)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(ignore, p.Character) end
	end
	params.FilterDescendantsInstances = ignore
	local dir = target.Position - origin
	local pos = origin
	for _ = 1, 10 do
		local result = workspace:Raycast(pos, dir - (pos - origin), params)
		if not result then return true end
		if result.Instance.Transparency <= 0.3 then return false end
		table.insert(ignore, result.Instance)
		params.FilterDescendantsInstances = ignore
		pos = result.Position + (dir).Unit * 0.1
	end
	return false
end

local function isEnemy(player)
	if player == plr then return false end
	if player.Team and plr.Team and player.Team == plr.Team then return false end
	return true
end

-- info: "Closest" checks Head + UpperTorso + HumanoidRootPart, picks nearest to screen center
local AIM_PARTS = {"Head", "UpperTorso", "HumanoidRootPart"}

local function getAimPart(character)
	if Settings.Aimbot_AimPart ~= "Closest" then
		return character:FindFirstChild(Settings.Aimbot_AimPart) or character:FindFirstChild("Head")
	end
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
	local best, bestDist = nil, math.huge
	for _, name in AIM_PARTS do
		local part = character:FindFirstChild(name)
		if not part then continue end
		local sPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen then continue end
		local dist = (Vector2.new(sPos.X, sPos.Y) - screenCenter).Magnitude
		if dist < bestDist then
			best = part
			bestDist = dist
		end
	end
	return best or character:FindFirstChild("Head")
end

local function getEquippedWeapon(character)
	if not character then return nil end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") then return child.Name end
	end
	return nil
end

local function getAllInFOV()
	local mousePos = UserInputService:GetMouseLocation()
	local targets = {}

	for _, player in Players:GetPlayers() do
		if not isEnemy(player) or not player.Character then continue end
		if not isAlive(player.Character) then continue end

		local part = getAimPart(player.Character)
		if not part then continue end

		local screenPos, onScreen = Camera:WorldToViewportPoint(part.Position)
		if not onScreen then continue end
		if Settings.VisibleOnly and not isVisible(Camera.CFrame.Position, part) then continue end

		local dist = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
		if dist < Settings.FOV_Radius then
			table.insert(targets, { player = player, part = part, dist = dist })
		end
	end

	table.sort(targets, function(a, b) return a.dist < b.dist end)
	return targets
end

local function getClosestInFOV()
	if not Settings.FOV_Enabled then return nil end
	local t = getAllInFOV()
	return t[1] and t[1].part or nil
end

----------------------------------------------------------------
-- Aim prediction: lead target based on velocity + bullet travel time
-- info: 750 studs/s default from game's FastCast projectile speed
----------------------------------------------------------------
-- info: prediction accounts for target velocity + bullet drop (gravity)
local function getPredictedPosition(part)
	if not Settings.AimPrediction then return part.Position end
	local hrp = part.Parent and part.Parent:FindFirstChild("HumanoidRootPart")
	if not hrp then return part.Position end
	local vel = hrp.AssemblyLinearVelocity
	local camPos = Camera.CFrame.Position

	-- iterative prediction: 2 passes for convergence
	local predicted = part.Position
	for _ = 1, 2 do
		local dist = (predicted - camPos).Magnitude
		local travelTime = dist / Settings.BulletSpeed
		local dropCompensation = Vector3.zero
		if Settings.BulletGravity.Magnitude > 0 then
			dropCompensation = -0.5 * Settings.BulletGravity * travelTime * travelTime
		end
		predicted = part.Position + vel * travelTime + dropCompensation
	end
	return predicted
end

-- check if predicted position is reachable (no walls in the way)
local function isPredictedVisible(origin, predictedPos)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = {}
	for _, p in Players:GetPlayers() do
		if p.Character then table.insert(ignore, p.Character) end
	end
	params.FilterDescendantsInstances = ignore
	local result = workspace:Raycast(origin, predictedPos - origin, params)
	return result == nil
end

----------------------------------------------------------------
-- Triggerbot state
----------------------------------------------------------------
local triggerHeld = false
local triggerLockTime = 0

----------------------------------------------------------------
-- Aimbot input
----------------------------------------------------------------
local targetIndex = 1

connections[#connections + 1] = UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.Tab and aimbotHeld then
		local targets = getAllInFOV()
		if #targets > 1 then
			targetIndex = targetIndex % #targets + 1
			lockedTarget = targets[targetIndex].part
		end
	end
end)

----------------------------------------------------------------
-- Auto-detect bullet speed from ClientEvents.Projectile
-- info: server sends exact speed as arg 3 every shot — capture it
----------------------------------------------------------------
----------------------------------------------------------------
-- No Spread + auto bullet speed via namecall hook
----------------------------------------------------------------
local lastDetectedWeapon = ""

local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
	if getnamecallmethod() == "FireServer" and self == ShootEvent then
		local args = table.pack(...)
		local weaponData = args[1]

		-- info: defer attribute reads outside the hook to avoid re-entrant namecall conflicts
		if weaponData and weaponData.Tool then
			local tool = weaponData.Tool
			task.defer(function()
				pcall(function()
					local speed = tool:GetAttribute("Velocity")
					if speed and type(speed) == "number" and speed > 0 and Settings.BulletSpeed ~= speed then
						Settings.BulletSpeed = speed
						local rounded = math.clamp(math.round(speed), 100, 6000)
						-- try both Linoria methods for slider update
						-- GUI update handled in render loop
					end
					local gravity = tool:GetAttribute("ProjectileGravity")
					if typeof(gravity) == "Vector3" then
						Settings.BulletGravity = gravity
					end
				end)
			end)
		end

		-- info: anti-spread reduces spread to 5% of original — near-perfect accuracy
		-- keeps value positive so game math doesn't break, server sees non-zero spread
		if Settings.AntiSpread and weaponData and weaponData.Tool then
			local toolRef = weaponData.Tool
			local charRef = weaponData.Character
			task.defer(function()
				pcall(function()
					if not toolRef or not toolRef.Parent or toolRef.Parent ~= charRef then return end
					local hold = toolRef:FindFirstChild("Hold")
					if hold then
						local spread = hold:FindFirstChild("SpreadDefault")
						local bloom = hold:FindFirstChild("Bloom")
						if spread and spread.Value > 0.01 then spread.Value = spread.Value * 0.05 end
						if bloom and bloom.Value > 0.01 then bloom.Value = bloom.Value * 0.05 end
					end
				end)
			end)
		end

		if Settings.NoRecoil then
			local savedRotation = Camera.CFrame.Rotation
			task.spawn(function()
				for _ = 1, 15 do
					RunService.RenderStepped:Wait()
					Camera.CFrame = CFrame.new(Camera.CFrame.Position) * savedRotation
				end
			end)
		end
	end

	return oldNamecall(self, ...)
end))

----------------------------------------------------------------
-- Chams
----------------------------------------------------------------
local chamsCache = {}

local function updateChams(player, character)
	if not Settings.ESP_Chams then
		if chamsCache[player] then
			chamsCache[player]:Destroy()
			chamsCache[player] = nil
		end
		return
	end

	if not character or not isAlive(character) then
		if chamsCache[player] then
			chamsCache[player]:Destroy()
			chamsCache[player] = nil
		end
		return
	end

	local hl = chamsCache[player]
	if not hl then
		hl = Instance.new("Highlight")
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.FillTransparency = 0.5
		hl.OutlineTransparency = 0
		chamsCache[player] = hl
	end

	local color = isEnemy(player) and Settings.EnemyColor or Settings.AllyColor
	if Settings.ESP_TeamColor then
		hl.FillColor = color
		hl.OutlineColor = color
	else
		hl.FillColor = Color3.fromRGB(255, 255, 255)
		hl.OutlineColor = Color3.fromRGB(255, 255, 255)
	end

	if hl.Parent ~= character then
		hl.Adornee = character
		hl.Parent = character
	end
end

connections[#connections + 1] = Players.PlayerRemoving:Connect(function(player)
	-- clear aimbot/triggerbot refs if they pointed at this player
	if lockedTarget and lockedTarget.Parent and Players:GetPlayerFromCharacter(lockedTarget.Parent) == player then
		lockedTarget = nil
	end
	if currentFOVTarget and currentFOVTarget.Parent and Players:GetPlayerFromCharacter(currentFOVTarget.Parent) == player then
		currentFOVTarget = nil
	end

	if chamsCache[player] then
		chamsCache[player]:Destroy()
		chamsCache[player] = nil
	end
	if not espCache then return end
	local esp = espCache[player]
	if esp then
		for _, l in esp.box2d do l:Remove() end
		for _, l in esp.box3d do l:Remove() end
		for _, l in esp.skeleton do l:Remove() end
		esp.name:Remove()
		esp.weapon:Remove()
		esp.dist:Remove()
		esp.tracer:Remove()
		esp.healthBg:Remove()
		esp.healthBar:Remove()
		espCache[player] = nil
	end
end)

----------------------------------------------------------------
-- Skeleton bone map (R15)
----------------------------------------------------------------
local BONES = {
	{"Head", "UpperTorso"},
	{"UpperTorso", "LowerTorso"},
	{"UpperTorso", "LeftUpperArm"},
	{"LeftUpperArm", "LeftLowerArm"},
	{"LeftLowerArm", "LeftHand"},
	{"UpperTorso", "RightUpperArm"},
	{"RightUpperArm", "RightLowerArm"},
	{"RightLowerArm", "RightHand"},
	{"LowerTorso", "LeftUpperLeg"},
	{"LeftUpperLeg", "LeftLowerLeg"},
	{"LeftLowerLeg", "LeftFoot"},
	{"LowerTorso", "RightUpperLeg"},
	{"RightUpperLeg", "RightLowerLeg"},
	{"RightLowerLeg", "RightFoot"},
}
local NUM_BONES = #BONES

----------------------------------------------------------------
-- ESP cache
----------------------------------------------------------------
local espCache = {}

local function makeLine()
	local l = Drawing.new("Line")
	l.Thickness = 1
	l.Visible = false
	return l
end

local function getESP(player)
	if espCache[player] then return espCache[player] end
	local esp = {
		box2d = {makeLine(), makeLine(), makeLine(), makeLine()},
		box3d = {},
		skeleton = {},
		name = Drawing.new("Text"),
		weapon = Drawing.new("Text"),
		dist = Drawing.new("Text"),
		tracer = makeLine(),
		healthBg = makeLine(),
		healthBar = makeLine(),
	}
	esp.name.Size = 13
	esp.name.Center = true
	esp.name.Outline = true
	esp.name.Visible = false

	esp.weapon.Size = 11
	esp.weapon.Center = true
	esp.weapon.Outline = true
	esp.weapon.Color = Color3.fromRGB(255, 200, 50)
	esp.weapon.Visible = false

	esp.dist.Size = 12
	esp.dist.Center = true
	esp.dist.Outline = true
	esp.dist.Color = Color3.fromRGB(255, 255, 255)
	esp.dist.Visible = false

	esp.healthBg.Color = Color3.fromRGB(40, 40, 40)
	esp.healthBg.Thickness = 3
	esp.healthBar.Thickness = 1

	for i = 1, 12 do esp.box3d[i] = makeLine() end
	for i = 1, NUM_BONES do esp.skeleton[i] = makeLine() end
	espCache[player] = esp
	return esp
end

local function hideESP(esp)
	for _, l in esp.box2d do l.Visible = false end
	for _, l in esp.box3d do l.Visible = false end
	for _, l in esp.skeleton do l.Visible = false end
	esp.name.Visible = false
	esp.weapon.Visible = false
	esp.dist.Visible = false
	esp.tracer.Visible = false
	esp.healthBg.Visible = false
	esp.healthBar.Visible = false
end

local function getTeamColor(player)
	if not Settings.ESP_TeamColor then return Color3.fromRGB(255, 255, 255) end
	if player.Team and plr.Team and player.Team == plr.Team then
		return Settings.AllyColor
	end
	return Settings.EnemyColor
end

local function applyColor(esp, color)
	for _, l in esp.box2d do l.Color = color end
	for _, l in esp.box3d do l.Color = color end
	for _, l in esp.skeleton do l.Color = color end
	esp.name.Color = color
	esp.tracer.Color = color
end

----------------------------------------------------------------
-- Draw functions
----------------------------------------------------------------
local function drawESP2D(esp, character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local topPos, topOn = Camera:WorldToViewportPoint((hrp.CFrame * CFrame.new(0, 3, 0)).Position)
	local botPos, botOn = Camera:WorldToViewportPoint((hrp.CFrame * CFrame.new(0, -3, 0)).Position)
	if not topOn or not botOn then return end
	local top2 = Vector2.new(topPos.X, topPos.Y)
	local bot2 = Vector2.new(botPos.X, botPos.Y)
	local h = (bot2 - top2).Magnitude
	local w = h * 0.5
	local corners = {
		Vector2.new(top2.X - w/2, top2.Y), Vector2.new(top2.X + w/2, top2.Y),
		Vector2.new(bot2.X + w/2, bot2.Y), Vector2.new(bot2.X - w/2, bot2.Y),
	}
	for i = 1, 4 do
		esp.box2d[i].From = corners[i]
		esp.box2d[i].To = corners[i % 4 + 1]
		esp.box2d[i].Visible = true
	end
end

local function drawESP3D(esp, character)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	local cf = hrp.CFrame
	local sx, sy, sz = 2, 6, 2
	local offsets = {
		Vector3.new(-sx, -sy, -sz), Vector3.new( sx, -sy, -sz),
		Vector3.new( sx, -sy,  sz), Vector3.new(-sx, -sy,  sz),
		Vector3.new(-sx,  sy, -sz), Vector3.new( sx,  sy, -sz),
		Vector3.new( sx,  sy,  sz), Vector3.new(-sx,  sy,  sz),
	}
	local pts = {}
	for i, off in offsets do
		local sPos, onScreen = Camera:WorldToViewportPoint((cf * CFrame.new(off / 2)).Position)
		if not onScreen then
			for j = 1, 12 do esp.box3d[j].Visible = false end
			return
		end
		pts[i] = Vector2.new(sPos.X, sPos.Y)
	end
	local edges = {
		{1,2},{2,3},{3,4},{4,1},{5,6},{6,7},{7,8},{8,5},{1,5},{2,6},{3,7},{4,8},
	}
	for i, e in edges do
		esp.box3d[i].From = pts[e[1]]
		esp.box3d[i].To = pts[e[2]]
		esp.box3d[i].Visible = true
	end
end

local function drawSkeleton(esp, character)
	for i, bone in BONES do
		local partA = character:FindFirstChild(bone[1])
		local partB = character:FindFirstChild(bone[2])
		local line = esp.skeleton[i]
		if not partA or not partB then line.Visible = false continue end
		local posA, onA = Camera:WorldToViewportPoint(partA.Position)
		local posB, onB = Camera:WorldToViewportPoint(partB.Position)
		if onA and onB then
			line.From = Vector2.new(posA.X, posA.Y)
			line.To = Vector2.new(posB.X, posB.Y)
			line.Visible = true
		else
			line.Visible = false
		end
	end
end

----------------------------------------------------------------
-- Target highlight
----------------------------------------------------------------
local highlightDot = Drawing.new("Circle")
highlightDot.Color = Color3.fromRGB(255, 0, 0)
highlightDot.Thickness = 2
highlightDot.Filled = false
highlightDot.Transparency = 1
highlightDot.Radius = 5
highlightDot.Visible = false

----------------------------------------------------------------
-- Render loop
----------------------------------------------------------------
connections[#connections + 1] = RunService.RenderStepped:Connect(function()
	Camera = workspace.CurrentCamera
	currentFOVTarget = getClosestInFOV()
	-- clear stale refs from disconnected players
	if currentFOVTarget and not currentFOVTarget.Parent then currentFOVTarget = nil end
	if lockedTarget and not lockedTarget.Parent then lockedTarget = nil end

	-- sync bullet speed input with auto-detected value
	if Options.BulletSpeed and tostring(math.round(Settings.BulletSpeed)) ~= Options.BulletSpeed.Value then
		pcall(function() Options.BulletSpeed:SetValue(tostring(math.round(Settings.BulletSpeed))) end)
	end

	-- FOV circle
	fovCircle.Radius = Settings.FOV_Radius
	fovCircle.Visible = Settings.FOV_Visible and Settings.FOV_Enabled
	fovCircle.Color = Settings.FOVColor
	fovCircle.Position = UserInputService:GetMouseLocation()

	-- aimbot: drops target behind wall, re-acquires when visible
	if Settings.Aimbot_Enabled and Options.AimbotKey:GetState() then
		if not aimbotHeld then aimbotHeld = true end
		if lockedTarget and lockedTarget.Parent then
			if Settings.VisibleOnly and not isVisible(Camera.CFrame.Position, lockedTarget) then
				lockedTarget = nil
			end
		end
		if not lockedTarget or not lockedTarget.Parent then
			lockedTarget = currentFOVTarget
		end
		if lockedTarget and lockedTarget.Parent then
			local aimPos = getPredictedPosition(lockedTarget)
			local targetCF = CFrame.lookAt(Camera.CFrame.Position, aimPos)
			Camera.CFrame = Camera.CFrame:Lerp(targetCF, Settings.Aimbot_Smoothing)
		end
	else
		if aimbotHeld then
			aimbotHeld = false
			lockedTarget = nil
		end
	end

	-- triggerbot: auto-fire when predicted enemy position is near crosshair
	-- info: checks Head + UpperTorso with prediction for near-perfect accuracy
	if Settings.Triggerbot then
		local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
		local triggerTarget = nil
		local closestDist = Settings.TriggerRadius
		local checkParts = {"Head", "UpperTorso"}

		for _, player in Players:GetPlayers() do
			if not isEnemy(player) or not player.Character then continue end
			if not isAlive(player.Character) then continue end

			for _, partName in checkParts do
				local part = player.Character:FindFirstChild(partName)
				if not part then continue end

				-- check visibility to current position
				if Settings.VisibleOnly and not isVisibleThroughGlass(Camera.CFrame.Position, part) then continue end

				local predictedPos = getPredictedPosition(part)

				-- also check line of sight to predicted position
				if Settings.VisibleOnly and not isPredictedVisible(Camera.CFrame.Position, predictedPos) then continue end

				local sPos, onScreen = Camera:WorldToViewportPoint(predictedPos)
				if not onScreen then continue end

				local dist = (Vector2.new(sPos.X, sPos.Y) - screenCenter).Magnitude
				if dist < closestDist then
					closestDist = dist
					triggerTarget = part
				end
			end
		end

		if triggerTarget then
			if not triggerHeld then
				if triggerLockTime == 0 then
					triggerLockTime = tick()
				end
				if (tick() - triggerLockTime) * 1000 >= Settings.TriggerDelay then
					triggerHeld = true
					mouse1press()
				end
			end
		else
			triggerLockTime = 0
			if triggerHeld then
				triggerHeld = false
				mouse1release()
			end
		end
	elseif triggerHeld then
		triggerHeld = false
		triggerLockTime = 0
		mouse1release()
	end

	-- highlight dot (shows predicted position if enabled)
	if currentFOVTarget then
		local aimPos = getPredictedPosition(currentFOVTarget)
		local pos, onScreen = Camera:WorldToViewportPoint(aimPos)
		highlightDot.Position = Vector2.new(pos.X, pos.Y)
		highlightDot.Visible = onScreen
	else
		highlightDot.Visible = false
	end

	-- snapline
	snapline.Color = Settings.SnaplineColor
	local snapTarget = lockedTarget or currentFOVTarget
	if Settings.ESP_Snapline and snapTarget and snapTarget.Parent then
		local pos, onScreen = Camera:WorldToViewportPoint(snapTarget.Position)
		if onScreen then
			snapline.From = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
			snapline.To = Vector2.new(pos.X, pos.Y)
			snapline.Visible = true
		else
			snapline.Visible = false
		end
	else
		snapline.Visible = false
	end

	-- world mods
	if Settings.NoSuppression then
		local gui = plr.PlayerGui:FindFirstChild("GameGui")
		if gui then
			local hud = gui:FindFirstChild("headsUpDisplay")
			if hud then
				local vignette = hud:FindFirstChild("supressionVignette")
				if vignette then vignette.ImageTransparency = 1 end
			end
		end
	end

	if Settings.NoScopeBlur then
		local blur = Lighting:FindFirstChild("scopeBlur")
		if blur then blur.Size = 0 end
	end

	-- misc: speed boost — override DefaultWalkSpeed attribute so game's speedChanger uses our value
	if Settings.SpeedBoost then
		local char = plr.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				local backup = hum:GetAttribute("DefaultWalkSpeedBackup") or 12
				local boosted = backup + Settings.SpeedAmount
				local current = hum:GetAttribute("DefaultWalkSpeed")
				if current ~= boosted then
					hum:SetAttribute("DefaultWalkSpeed", boosted)
					hum.WalkSpeed = boosted
					if Settings.MiscDebug then
						print("[Speed] Backup:", backup, "Boosted:", boosted)
					end
				end
			end
		end
	end

	-- misc: no jump cooldown + jump boost
	if Settings.NoJumpCooldown or Settings.JumpBoost then
		local char = plr.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				if Settings.NoJumpCooldown then
					hum:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
				end
				-- max out jump to just under AC threshold (50 power / 7.2 height)
				if Settings.JumpBoost then
					hum.JumpPower = 50
					hum.JumpHeight = 7.2
					if Settings.MiscDebug and hum.JumpPower ~= 50 then
						print("[Jump] Set to max — Power:", hum.JumpPower, "Height:", hum.JumpHeight)
					end
				end
			end
		end
	end

	-- misc: auto deploy — fire Deploy when dead/on deploy screen
	if Settings.AutoDeploy then
		local char = plr.Character
		local isDead = not char or not char:FindFirstChildOfClass("Humanoid") or char:FindFirstChildOfClass("Humanoid").Health <= 0
		if isDead then
			pcall(function()
				-- search all PlayerGui for any visible deploy-related screen
				local found = false
				for _, gui in plr.PlayerGui:GetChildren() do
					if not gui:IsA("ScreenGui") or not gui.Enabled then continue end
					for _, desc in gui:GetDescendants() do
						if desc:IsA("GuiButton") and desc.Visible and string.lower(desc.Name):find("deploy") then
							found = true
							break
						end
					end
					if found then break end
				end
				if found or isDead then
					game:GetService("ReplicatedStorage").ServerEvents.Deploy:FireServer()
					if Settings.MiscDebug then
						print("[Auto Deploy] Fired Deploy remote, found button:", found)
					end
				end
			end)
		end
	end

	-- misc: animation cancel — speed up reload/bolt animations
	if Settings.AnimCancel then
		local char = plr.Character
		if char then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				for _, track in hum:GetPlayingAnimationTracks() do
					local name = track.Animation and track.Animation.Name or ""
					if name == "reload" or name == "boltCycle" then
						if track.Speed < 2 then
							track:AdjustSpeed(3)
							if Settings.MiscDebug then
								print("[Anim Cancel] Sped up:", name, "Length:", track.Length)
							end
						end
					end
				end
			end
		end
	end


	-- ESP loop
	local screenBottom = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y)

	for _, player in Players:GetPlayers() do
		if player == plr then continue end
		if Settings.ESP_EnemyOnly and not isEnemy(player) then
			local esp = espCache[player]
			if esp then hideESP(esp) end
			if chamsCache[player] then chamsCache[player]:Destroy() chamsCache[player] = nil end
			continue
		end

		updateChams(player, player.Character)

		local esp = getESP(player)
		local char = player.Character

		if not char or not isAlive(char) then hideESP(esp) continue end

		local hrp = char:FindFirstChild("HumanoidRootPart")
		if not hrp then hideESP(esp) continue end

		local rootPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
		if not onScreen then hideESP(esp) continue end

		local rootScreen = Vector2.new(rootPos.X, rootPos.Y)
		applyColor(esp, getTeamColor(player))

		if Settings.ESP_2D then drawESP2D(esp, char) else for _, l in esp.box2d do l.Visible = false end end
		if Settings.ESP_3D then drawESP3D(esp, char) else for _, l in esp.box3d do l.Visible = false end end
		if Settings.ESP_Skeleton then drawSkeleton(esp, char) else for _, l in esp.skeleton do l.Visible = false end end

		local topPos = Camera:WorldToViewportPoint((hrp.CFrame * CFrame.new(0, 3, 0)).Position)
		local nameY = topPos.Y - 16

		if Settings.ESP_Names then
			esp.name.Position = Vector2.new(topPos.X, nameY)
			esp.name.Text = player.DisplayName
			esp.name.Visible = true
			nameY = nameY - 14
		else esp.name.Visible = false end

		if Settings.ESP_Weapon then
			local wep = getEquippedWeapon(char)
			if wep then
				esp.weapon.Position = Vector2.new(topPos.X, nameY)
				esp.weapon.Text = "[" .. wep .. "]"
				esp.weapon.Visible = true
			else esp.weapon.Visible = false end
		else esp.weapon.Visible = false end

		if Settings.ESP_Distance then
			local dist = (hrp.Position - Camera.CFrame.Position).Magnitude
			esp.dist.Text = string.format("%dm", dist)
			esp.dist.Position = Vector2.new(rootScreen.X, rootScreen.Y + 20)
			esp.dist.Visible = true
		else esp.dist.Visible = false end

		if Settings.ESP_Tracers then
			esp.tracer.From = screenBottom
			esp.tracer.To = rootScreen
			esp.tracer.Visible = true
		else esp.tracer.Visible = false end

		if Settings.ESP_HealthBar then
			local hum = char:FindFirstChildOfClass("Humanoid")
			if hum then
				local topP = Camera:WorldToViewportPoint((hrp.CFrame * CFrame.new(0, 3, 0)).Position)
				local botP = Camera:WorldToViewportPoint((hrp.CFrame * CFrame.new(0, -3, 0)).Position)
				local top2 = Vector2.new(topP.X, topP.Y)
				local bot2 = Vector2.new(botP.X, botP.Y)
				local h = (bot2 - top2).Magnitude
				local barX = top2.X - (h * 0.25) - 5
				local frac = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
				esp.healthBg.From = Vector2.new(barX, top2.Y)
				esp.healthBg.To = Vector2.new(barX, bot2.Y)
				esp.healthBg.Visible = true
				local barTop = bot2.Y - (bot2.Y - top2.Y) * frac
				esp.healthBar.From = Vector2.new(barX, barTop)
				esp.healthBar.To = Vector2.new(barX, bot2.Y)
				esp.healthBar.Color = Color3.fromRGB(255 * (1 - frac), 255 * frac, 0)
				esp.healthBar.Visible = true
			end
		else
			esp.healthBg.Visible = false
			esp.healthBar.Visible = false
		end
	end
end)
