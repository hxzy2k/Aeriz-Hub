local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local Stats            = game:GetService("Stats")
local StarterGui       = game:GetService("StarterGui")
local GuiService       = game:GetService("GuiService")
local VirtualUser      = game:GetService("VirtualUser")
local VirtualInput     = game:GetService("VirtualInputManager")
local HttpService      = game:GetService("HttpService")
local TeleportService  = game:GetService("TeleportService")
local LocalPlayer      = Players.LocalPlayer

local HUB_NAME    = "Aeriz Hub"
local VERSION     = "v8.0"
local CONFIG_PATH = "AerizHub_MM2_Config.json"

---------------------------------------------------------------------
-- Error plumbing
---------------------------------------------------------------------
local lastErr, lastErrClock = nil, 0
local function reportErr(err)
    lastErr = tostring(err)
    lastErrClock = os.clock()
end
local function try(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then reportErr(err) end
    return ok
end

---------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------
local S = {
    -- aimbot
    Aimbot        = true,
    AimKey        = "Right Mouse",
    AimMode       = "Hold",
    AimAt         = "Auto",
    Priority      = "Crosshair",
    AimPart       = "Head",
    FOV           = 40,
    MaxDist       = 600,
    Smooth        = 30,
    Sticky        = true,
    WallCheck     = false,
    Prediction    = false,
    PredTime      = 0.12,
    AimOnlyArmed  = false,
    AimDeadzone   = 0,
    ShowFOV       = true,
    RainbowFOV    = false,
    TargetHud     = false,
    TargetLine    = false,

    Trigger       = false,
    TriggerFOV    = 6,
    TriggerDelay  = 0.12,

    KillAura      = false,
    KaRange       = 14,
    KaDelay       = 0.12,

    FlingTime     = 1.5,
    FlingPower    = 500000,
    FlingReturn   = true,
    FlingAura     = false,
    FlingAuraRange= 12,
    WalkFling     = false,

    AutoEquip     = true,
    AutoPickupGun = false,

    -- esp
    ESP           = true,
    Box           = true,
    BoxFill       = false,
    BoxFillAlpha  = 0.15,
    Name          = true,
    Distance      = true,
    Health        = true,
    HealthText    = false,
    Skeleton      = false,
    Tracer        = false,
    TracerOrigin  = "Bottom",
    Chams         = false,
    ChamsFillAlpha= 0.65,
    ChamsOutline  = false,
    HeadDot       = false,
    WeaponESP     = true,
    Beacon        = true,
    RoleText      = true,
    ShowInnocents = true,
    GunDrop       = true,
    CoinESP       = false,
    ESPDist       = 3000,
    TextSize      = 13,
    BoxThick      = 1.5,
    Crosshair     = false,
    Watermark     = true,

    -- world
    Fullbright    = false,
    NoFog         = false,
    NoShadows     = false,
    TimeOn        = false,
    TimeOfDay     = 14,
    CamFOVOn      = false,
    CamFOV        = 70,

    -- notifications / ui
    NotifyRoles   = true,
    NotifyTime    = 4,
    KeybindList   = false,

    -- colours
    UseRoleColors = true,
    ColMurderer   = Color3.fromRGB(255, 60, 60),
    ColSheriff    = Color3.fromRGB(60, 140, 255),
    ColInnocent   = Color3.fromRGB(70, 225, 110),
    ColBox        = Color3.fromRGB(255, 255, 255),
    ColName       = Color3.fromRGB(255, 255, 255),
    ColDistance   = Color3.fromRGB(205, 205, 220),
    ColHealthHi   = Color3.fromRGB(60, 230, 90),
    ColHealthLo   = Color3.fromRGB(240, 60, 60),
    ColSkeleton   = Color3.fromRGB(255, 255, 255),
    ColChams      = Color3.fromRGB(255, 255, 255),
    ColHeadDot    = Color3.fromRGB(255, 255, 255),
    ColTracer     = Color3.fromRGB(255, 255, 255),
    ColBeacon     = Color3.fromRGB(255, 90, 90),
    ColGunDrop    = Color3.fromRGB(255, 220, 0),
    ColCoin       = Color3.fromRGB(255, 215, 0),
    ColFOV        = Color3.fromRGB(255, 105, 180),
    ColCrosshair  = Color3.fromRGB(0, 255, 180),
    ColWatermark  = Color3.fromRGB(255, 255, 255),
    ColTarget     = Color3.fromRGB(255, 255, 0),

    -- movement
    SpeedEnabled  = false,
    Speed         = 16,
    JumpEnabled   = false,
    Jump          = 50,
    InfJump       = false,
    BHop          = false,
    Fly           = false,
    FlySpeed      = 60,
    Noclip        = false,
    GravityOn     = false,
    Gravity       = 196.2,
    Spin          = false,
    SpinSpeed     = 8,
    ScaleOn       = false,
    Scale         = 1,
    ClickTP       = false,
    AntiVoid      = false,

    -- farm / misc
    AutoCollect   = false,
    CoinRange     = 45,
    CollectDelay  = 0.15,
    LobbyGuard    = true,
    AntiAFK       = true,

    _theme        = "Violet",
    _tptarget     = "-",
    _flingtarget  = "-",

    Unloaded      = false,
}

local DEFAULTS = {}
for k, v in pairs(S) do DEFAULTS[k] = v end

---------------------------------------------------------------------
-- Forward declarations
---------------------------------------------------------------------
local Roles = {}
local unload
local hasTool, heldTool, getRole, roleColor, refreshRoles, elemColor
local gunPart, autoPickupGun, autoCollect
local teleportTo, findGunDrop, getCoins, touch
local applyLighting, applySpeed, applyGravity, applyScale, applyNoclip, applyCamFOV, applyEverything
local PlayerDrop, ThemeDrop, FlingDrop
local flingAsync, flingAll, flingByRole
local coinCache, coinScan = nil, 0
local runDiagnostics

---------------------------------------------------------------------
-- Library
---------------------------------------------------------------------
local Library, LIB = nil, nil

local SOURCES = {
    "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/main/Library.lua",
    "https://cdn.jsdelivr.net/gh/violin-suzutsuki/LinoriaLib@main/Library.lua",
    "https://github.com/violin-suzutsuki/LinoriaLib/raw/main/Library.lua",
    "https://raw.githubusercontent.com/violin-suzutsuki/LinoriaLib/master/Library.lua",
}

for _, url in ipairs(SOURCES) do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(res) == "table" and res.CreateWindow then
        Library = res
        LIB = "Linoria"
        break
    end
end

local function notify(title, text)
    print("[aeriz] " .. tostring(title) .. ": " .. tostring(text))
    local ok = false
    if LIB == "Linoria" then
        ok = pcall(function()
            Library:Notify(tostring(title) .. "  |  " .. tostring(text), S.NotifyTime)
        end)
    end
    if not ok then
        pcall(function()
            StarterGui:SetCore("SendNotification", {
                Title = tostring(title), Text = tostring(text), Duration = S.NotifyTime,
            })
        end)
    end
end

notify(HUB_NAME, "loading MM2 " .. VERSION .. "...")

if not Drawing then
    notify(HUB_NAME .. " FAILED", "executor has no Drawing library")
    return
end

if not Library then
    LIB = "stub"
    notify(HUB_NAME .. ": UI failed", "every mirror failed. ESP + aimbot run on defaults.")
    Library = {}
    setmetatable(Library, { __index = function() return function() return Library end end })
end

---------------------------------------------------------------------
-- Side effects: settings that need code to run when they change
---------------------------------------------------------------------
local SIDE = {}
local building = true

local function setSetting(key, v)
    S[key] = v
    if building then return end
    local f = SIDE[key]
    if f then try(f) end
end

SIDE.SpeedEnabled = function() applySpeed() end
SIDE.Speed        = function() applySpeed() end
SIDE.JumpEnabled  = function() applySpeed() end
SIDE.Jump         = function() applySpeed() end
SIDE.Fullbright   = function() applyLighting() end
SIDE.NoFog        = function() applyLighting() end
SIDE.NoShadows    = function() applyLighting() end
SIDE.TimeOn       = function() applyLighting() end
SIDE.TimeOfDay    = function() applyLighting() end
SIDE.CamFOVOn     = function() applyCamFOV() end
SIDE.CamFOV       = function() applyCamFOV() end
SIDE.GravityOn    = function() applyGravity() end
SIDE.Gravity      = function() applyGravity() end
SIDE.ScaleOn      = function() applyScale() end
SIDE.Scale        = function() applyScale() end
SIDE.Noclip       = function() applyNoclip(S.Noclip) end
SIDE.KeybindList  = function()
    pcall(function() Library.KeybindFrame.Visible = S.KeybindList end)
end

---------------------------------------------------------------------
-- Menu
---------------------------------------------------------------------
local UI = {}
local Window

local okBuild, buildErr = pcall(function()
    Window = Library:CreateWindow({
        Title = HUB_NAME .. "  |  MM2  " .. VERSION,
        Center = true,
        AutoShow = true,
        TabPadding = 8,
        MenuFadeTime = 0.2,
        Size = UDim2.fromOffset(640, 660),
    })

    local function newTab(name)
        local ok, t = pcall(function() return Window:AddTab(name) end)
        return ok and t or Window
    end

    local function section(tab, name, side)
        local ok, g = pcall(function()
            if side == "R" then return tab:AddRightGroupbox(name) end
            return tab:AddLeftGroupbox(name)
        end)
        return ok and g or tab
    end

    local function divider(g)
        pcall(function() g:AddDivider() end)
    end

    -- Linoria returns different things from different Add calls depending on
    -- the version, so fall back to the global Toggles / Options tables.
    local function resolve(ret, id, kind)
        if type(ret) == "table" and ret.SetValue then return ret end
        local ok, o = pcall(function()
            if kind == "toggle" then return Toggles[id] end
            return Options[id]
        end)
        if ok and o then return o end
        return nil
    end

    local function addToggle(parent, id, title, key, default, tip)
        local ok, ret = pcall(function()
            return parent:AddToggle(id, {
                Text = title,
                Default = default,
                Tooltip = tip,
                Callback = function(v) setSetting(key, v) end,
            })
        end)
        local obj = ok and resolve(ret, id, "toggle") or nil
        if obj then
            UI[key] = obj
            pcall(function() obj:SetValue(default) end)
        end
        return obj
    end

    local function addKey(tog, id, text, default)
        if not tog then return end
        pcall(function()
            tog:AddKeyPicker(id, {
                Default = default,
                SyncToggleState = true,
                Mode = "Toggle",
                Text = text,
                NoUI = false,
            })
        end)
    end

    local function addSlider(parent, id, title, key, default, min, max, round, suffix)
        local ok, ret = pcall(function()
            return parent:AddSlider(id, {
                Text = title,
                Default = default,
                Min = min,
                Max = max,
                Rounding = round or 0,
                Suffix = suffix,
                Callback = function(v) setSetting(key, v) end,
            })
        end)
        local obj = ok and resolve(ret, id, "option") or nil
        if obj then
            UI[key] = obj
            pcall(function() obj:SetValue(default) end)
        end
        return obj
    end

    local function addDropdown(parent, id, title, values, key, default)
        local idx = table.find(values, default) or 1
        local ok, ret = pcall(function()
            return parent:AddDropdown(id, {
                Text = title,
                Values = values,
                Default = idx,
                Multi = false,
                Callback = function(v) if type(v) == "string" then setSetting(key, v) end end,
            })
        end)
        local obj = ok and resolve(ret, id, "option") or nil
        if obj then
            UI[key] = obj
            pcall(function() obj:SetValue(default) end)
        end
        return obj
    end

    -- colour pickers live on a label in Linoria, not on the groupbox
    local function addColor(parent, id, title, key, default)
        local ok = pcall(function()
            local lbl = parent:AddLabel(title)
            lbl:AddColorPicker(id, {
                Default = default,
                Title = title,
                Callback = function(v) setSetting(key, v) end,
            })
        end)
        if not ok then return nil end
        local picker = resolve(nil, id, "option")
        if picker then
            UI[key] = picker
            pcall(function() picker:SetValueRGB(default) end)
        end
        return picker
    end

    local function addButton(parent, title, cb)
        pcall(function() parent:AddButton(title, function() try(cb) end) end)
    end

    local function addLabel(parent, text)
        local ok, obj = pcall(function() return parent:AddLabel(text) end)
        return ok and obj or nil
    end

    local function setUi(key, v)
        local obj = UI[key]
        if not obj then return end
        if typeof(v) == "Color3" then
            pcall(function() obj:SetValueRGB(v) end)
        else
            pcall(function() obj:SetValue(v) end)
        end
    end

    local TCombat   = newTab("Combat")
    local TVisuals  = newTab("Visuals")
    local TColours  = newTab("Colours")
    local TMovement = newTab("Movement")
    local TFarm     = newTab("Farm")
    local TTeleport = newTab("Teleport")
    local TMisc     = newTab("Misc")
    local TSettings = newTab("Settings")

    local g, t

    ----------------------------------------------------------------
    -- COMBAT
    ----------------------------------------------------------------
    g = section(TCombat, "Aimbot", "L")
    t = addToggle(g, "Aimbot", "Aimbot", "Aimbot", S.Aimbot)
    addKey(t, "AimbotKey", "Aimbot", "None")
    addDropdown(g, "AimKey", "Aim key",
        { "Right Mouse", "Left Mouse", "Middle Mouse", "Q", "E", "Left Shift", "Left Alt", "Always On" },
        "AimKey", S.AimKey)
    addDropdown(g, "AimMode", "Activation", { "Hold", "Toggle" }, "AimMode", S.AimMode)
    addToggle(g, "AimOnlyArmed", "Only while armed", "AimOnlyArmed", S.AimOnlyArmed,
        "Aimbot only works while you hold a knife or gun")
    addSlider(g, "Smooth", "Smoothness", "Smooth", S.Smooth, 0, 95)
    addSlider(g, "AimDeadzone", "Deadzone", "AimDeadzone", S.AimDeadzone, 0, 40, 0, "px")
    divider(g)
    addToggle(g, "Prediction", "Velocity prediction", "Prediction", S.Prediction)
    addSlider(g, "PredTime", "Prediction time", "PredTime", S.PredTime, 0, 0.5, 2, "s")

    g = section(TCombat, "Triggerbot", "L")
    addToggle(g, "Trigger", "Triggerbot", "Trigger", S.Trigger)
    addSlider(g, "TriggerFOV", "Trigger radius", "TriggerFOV", S.TriggerFOV, 1, 60, 0, "px")
    addSlider(g, "TriggerDelay", "Trigger delay", "TriggerDelay", S.TriggerDelay, 0.02, 1, 2, "s")

    g = section(TCombat, "Kill Aura", "L")
    addToggle(g, "KillAura", "Kill aura", "KillAura", S.KillAura)
    addSlider(g, "KaRange", "Aura range", "KaRange", S.KaRange, 5, 40)
    addSlider(g, "KaDelay", "Aura delay", "KaDelay", S.KaDelay, 0.05, 1, 2, "s")

    g = section(TCombat, "Targeting", "R")
    addDropdown(g, "AimAt", "Aim at", { "Auto", "Any", "Murderer", "Sheriff", "Innocent" }, "AimAt", S.AimAt)
    addDropdown(g, "Priority", "Priority", { "Crosshair", "Distance", "Health" }, "Priority", S.Priority)
    addDropdown(g, "AimPart", "Aim part", { "Head", "HumanoidRootPart", "Torso" }, "AimPart", S.AimPart)
    addSlider(g, "FOV", "FOV", "FOV", S.FOV, 5, 180, 0, "deg")
    addSlider(g, "MaxDist", "Max distance", "MaxDist", S.MaxDist, 50, 2000)
    divider(g)
    addToggle(g, "Sticky", "Sticky target", "Sticky", S.Sticky)
    addToggle(g, "WallCheck", "Visible check", "WallCheck", S.WallCheck)

    g = section(TCombat, "Aim Visuals", "R")
    addToggle(g, "ShowFOV", "Draw FOV ring", "ShowFOV", S.ShowFOV)
    addToggle(g, "RainbowFOV", "Rainbow ring", "RainbowFOV", S.RainbowFOV)
    addToggle(g, "TargetHud", "Target info text", "TargetHud", S.TargetHud)
    addToggle(g, "TargetLine", "Line to target", "TargetLine", S.TargetLine)

    g = section(TCombat, "Weapons", "R")
    addToggle(g, "AutoEquip", "Auto equip knife / gun", "AutoEquip", S.AutoEquip)

    g = section(TCombat, "Fling", "R")
    FlingDrop = addDropdown(g, "FlingTarget", "Fling target", { "-" }, "_flingtarget", "-")
    addButton(g, "Fling selected player", function()
        local name = S._flingtarget
        if not name or name == "-" then return notify("Fling", "no target selected") end
        local p = Players:FindFirstChild(name)
        if not p then return notify("Fling", "target not found") end
        flingAsync(p)
    end)
    addButton(g, "Fling murderer", function() flingByRole("Murderer") end)
    addButton(g, "Fling sheriff", function() flingByRole("Sheriff") end)
    addButton(g, "Fling everyone", function() flingAll() end)
    divider(g)
    addSlider(g, "FlingTime", "Fling duration", "FlingTime", S.FlingTime, 0.5, 5, 1, "s")
    addSlider(g, "FlingPower", "Fling power", "FlingPower", S.FlingPower, 10000, 5000000, 0)
    addToggle(g, "FlingReturn", "Return to start after", "FlingReturn", S.FlingReturn)
    divider(g)
    addToggle(g, "FlingAura", "Fling aura", "FlingAura", S.FlingAura, "Flings anyone who walks close to you")
    addSlider(g, "FlingAuraRange", "Aura range", "FlingAuraRange", S.FlingAuraRange, 5, 40)
    addToggle(g, "WalkFling", "Walk fling", "WalkFling", S.WalkFling, "Anyone you touch gets launched")

    ----------------------------------------------------------------
    -- VISUALS
    ----------------------------------------------------------------
    g = section(TVisuals, "Player ESP", "L")
    t = addToggle(g, "ESP", "ESP", "ESP", S.ESP)
    addKey(t, "ESPKey", "ESP", "None")
    addToggle(g, "Box", "2D box", "Box", S.Box)
    addToggle(g, "BoxFill", "Box fill", "BoxFill", S.BoxFill)
    addSlider(g, "BoxFillAlpha", "Fill opacity", "BoxFillAlpha", S.BoxFillAlpha, 0.05, 0.8, 2)
    addToggle(g, "Name", "Name", "Name", S.Name)
    addToggle(g, "Distance", "Distance", "Distance", S.Distance)
    addToggle(g, "Health", "Health bar", "Health", S.Health)
    addToggle(g, "HealthText", "Health number", "HealthText", S.HealthText)
    addToggle(g, "Skeleton", "Skeleton", "Skeleton", S.Skeleton)
    addToggle(g, "HeadDot", "Head dots", "HeadDot", S.HeadDot)
    addToggle(g, "WeaponESP", "Weapon held", "WeaponESP", S.WeaponESP)
    addToggle(g, "Beacon", "Murderer beacon", "Beacon", S.Beacon)

    g = section(TVisuals, "Tracers & Chams", "L")
    addToggle(g, "Tracer", "Tracers", "Tracer", S.Tracer)
    addDropdown(g, "TracerOrigin", "Tracer origin", { "Bottom", "Center", "Mouse" }, "TracerOrigin", S.TracerOrigin)
    divider(g)
    addToggle(g, "Chams", "Chams", "Chams", S.Chams)
    addSlider(g, "ChamsFillAlpha", "Chams fill transparency", "ChamsFillAlpha", S.ChamsFillAlpha, 0, 1, 2)
    addToggle(g, "ChamsOutline", "Chams outline", "ChamsOutline", S.ChamsOutline)

    g = section(TVisuals, "Filters & Sizing", "R")
    addToggle(g, "ShowInnocents", "Show innocents", "ShowInnocents", S.ShowInnocents)
    addToggle(g, "RoleText", "Role in name tag", "RoleText", S.RoleText)
    addSlider(g, "TextSize", "Text size", "TextSize", S.TextSize, 8, 24)
    addSlider(g, "BoxThick", "Box thickness", "BoxThick", S.BoxThick, 1, 5, 1)
    addSlider(g, "ESPDist", "ESP max distance", "ESPDist", S.ESPDist, 100, 8000)

    g = section(TVisuals, "World ESP", "R")
    addToggle(g, "GunDrop", "Gun drop", "GunDrop", S.GunDrop)
    addToggle(g, "CoinESP", "Coins", "CoinESP", S.CoinESP)

    g = section(TVisuals, "Overlays", "R")
    addToggle(g, "Crosshair", "Custom crosshair", "Crosshair", S.Crosshair)
    addToggle(g, "Watermark", "Watermark", "Watermark", S.Watermark)

    g = section(TVisuals, "Camera & Lighting", "R")
    addToggle(g, "Fullbright", "Fullbright", "Fullbright", S.Fullbright)
    addToggle(g, "NoFog", "No fog", "NoFog", S.NoFog)
    addToggle(g, "NoShadows", "No shadows", "NoShadows", S.NoShadows)
    addToggle(g, "TimeOn", "Force time of day", "TimeOn", S.TimeOn)
    addSlider(g, "TimeOfDay", "Time of day", "TimeOfDay", S.TimeOfDay, 0, 24, 1)
    addToggle(g, "CamFOVOn", "Custom camera FOV", "CamFOVOn", S.CamFOVOn)
    addSlider(g, "CamFOV", "Camera FOV", "CamFOV", S.CamFOV, 40, 120)

    ----------------------------------------------------------------
    -- COLOURS
    ----------------------------------------------------------------
    g = section(TColours, "Roles", "L")
    addToggle(g, "UseRoleColors", "Use role colours", "UseRoleColors", S.UseRoleColors,
        "When off, every element uses its own colour below")
    addColor(g, "ColMurderer", "Murderer", "ColMurderer", S.ColMurderer)
    addColor(g, "ColSheriff", "Sheriff", "ColSheriff", S.ColSheriff)
    addColor(g, "ColInnocent", "Innocent", "ColInnocent", S.ColInnocent)

    g = section(TColours, "ESP Elements", "L")
    addColor(g, "ColBox", "Box", "ColBox", S.ColBox)
    addColor(g, "ColName", "Name", "ColName", S.ColName)
    addColor(g, "ColDistance", "Distance", "ColDistance", S.ColDistance)
    addColor(g, "ColSkeleton", "Skeleton", "ColSkeleton", S.ColSkeleton)
    addColor(g, "ColChams", "Chams", "ColChams", S.ColChams)
    addColor(g, "ColHeadDot", "Head dot", "ColHeadDot", S.ColHeadDot)
    addColor(g, "ColTracer", "Tracer", "ColTracer", S.ColTracer)

    g = section(TColours, "Health & World", "R")
    addColor(g, "ColHealthHi", "Health (full)", "ColHealthHi", S.ColHealthHi)
    addColor(g, "ColHealthLo", "Health (low)", "ColHealthLo", S.ColHealthLo)
    addColor(g, "ColBeacon", "Murderer beacon", "ColBeacon", S.ColBeacon)
    addColor(g, "ColGunDrop", "Gun drop", "ColGunDrop", S.ColGunDrop)
    addColor(g, "ColCoin", "Coins", "ColCoin", S.ColCoin)

    g = section(TColours, "Overlays & Aim", "R")
    addColor(g, "ColFOV", "FOV ring", "ColFOV", S.ColFOV)
    addColor(g, "ColTarget", "Target text / line", "ColTarget", S.ColTarget)
    addColor(g, "ColCrosshair", "Crosshair", "ColCrosshair", S.ColCrosshair)
    addColor(g, "ColWatermark", "Watermark", "ColWatermark", S.ColWatermark)
    divider(g)
    addButton(g, "Reset all colours", function()
        for k, v in pairs(DEFAULTS) do
            if string.sub(k, 1, 3) == "Col" then
                S[k] = v
                setUi(k, v)
            end
        end
        notify("Colours", "reset")
    end)

    ----------------------------------------------------------------
    -- MOVEMENT
    ----------------------------------------------------------------
    g = section(TMovement, "Speed & Jump", "L")
    addToggle(g, "SpeedEnabled", "Custom WalkSpeed", "SpeedEnabled", S.SpeedEnabled)
    addSlider(g, "Speed", "WalkSpeed", "Speed", S.Speed, 8, 200)
    addToggle(g, "JumpEnabled", "Custom JumpPower", "JumpEnabled", S.JumpEnabled)
    addSlider(g, "Jump", "JumpPower", "Jump", S.Jump, 30, 250)
    divider(g)
    addToggle(g, "InfJump", "Infinite jump", "InfJump", S.InfJump)
    addToggle(g, "BHop", "Bunny hop (hold space)", "BHop", S.BHop)

    g = section(TMovement, "Fly & Noclip", "L")
    t = addToggle(g, "Fly", "Fly", "Fly", S.Fly)
    addKey(t, "FlyKey", "Fly", "F")
    addSlider(g, "FlySpeed", "Fly speed", "FlySpeed", S.FlySpeed, 10, 300)
    t = addToggle(g, "Noclip", "Noclip", "Noclip", S.Noclip)
    addKey(t, "NoclipKey", "Noclip", "N")

    g = section(TMovement, "Physics", "R")
    addToggle(g, "GravityOn", "Custom gravity", "GravityOn", S.GravityOn)
    addSlider(g, "Gravity", "Gravity", "Gravity", S.Gravity, 0, 500, 1)
    addToggle(g, "ScaleOn", "Custom scale", "ScaleOn", S.ScaleOn)
    addSlider(g, "Scale", "Scale", "Scale", S.Scale, 0.3, 3, 2)

    g = section(TMovement, "Utility", "R")
    addToggle(g, "ClickTP", "Ctrl + click teleport", "ClickTP", S.ClickTP)
    addToggle(g, "AntiVoid", "Anti-void", "AntiVoid", S.AntiVoid,
        "Teleports you back if you fall out of the map")
    addToggle(g, "Spin", "Spin bot", "Spin", S.Spin)
    addSlider(g, "SpinSpeed", "Spin speed", "SpinSpeed", S.SpinSpeed, 1, 60)

    ----------------------------------------------------------------
    -- FARM
    ----------------------------------------------------------------
    g = section(TFarm, "Coins", "L")
    addToggle(g, "AutoCollect", "Auto collect coins", "AutoCollect", S.AutoCollect)
    addSlider(g, "CoinRange", "Collect range", "CoinRange", S.CoinRange, 10, 200)
    addSlider(g, "CollectDelay", "Collect delay", "CollectDelay", S.CollectDelay, 0, 1, 2, "s")

    g = section(TFarm, "Gun", "R")
    addToggle(g, "AutoPickupGun", "Auto pickup dropped gun", "AutoPickupGun", S.AutoPickupGun)
    addButton(g, "Grab gun now", function() autoPickupGun(true) end)

    ----------------------------------------------------------------
    -- TELEPORT
    ----------------------------------------------------------------
    local function tpToRole(role)
        for _, p in ipairs(Players:GetPlayers()) do
            if Roles[p] == role then
                local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    teleportTo(hrp.Position)
                    return notify("TP", "-> " .. string.lower(role))
                end
            end
        end
        notify("TP", string.lower(role) .. " not found")
    end

    g = section(TTeleport, "Players", "L")
    PlayerDrop = addDropdown(g, "TPTarget", "Teleport target", { "-" }, "_tptarget", "-")
    addButton(g, "Teleport to selected player", function()
        local name = S._tptarget
        if not name or name == "-" then return notify("TP", "no target selected") end
        local p = Players:FindFirstChild(name)
        local hrp = p and p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return notify("TP", "target not found") end
        if teleportTo(hrp.Position) then notify("TP", "-> " .. name) end
    end)
    addButton(g, "Teleport to murderer", function() tpToRole("Murderer") end)
    addButton(g, "Teleport to sheriff", function() tpToRole("Sheriff") end)
    addButton(g, "Teleport to random player", function()
        local pool = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
                table.insert(pool, p)
            end
        end
        if #pool == 0 then return notify("TP", "no players") end
        local p = pool[math.random(1, #pool)]
        teleportTo(p.Character.HumanoidRootPart.Position)
        notify("TP", "-> " .. p.Name)
    end)

    g = section(TTeleport, "Locations", "R")
    addButton(g, "Teleport to dropped gun", function()
        local part = gunPart(findGunDrop())
        if not part then return notify("TP", "no gun drop") end
        teleportTo(part.Position)
        touch(LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart"), part)
    end)
    addButton(g, "Teleport to nearest coin", function()
        local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local best, bestD = nil, math.huge
        for _, c in ipairs(getCoins()) do
            if c.Parent and c:IsA("BasePart") then
                local d = (c.Position - hrp.Position).Magnitude
                if d < bestD then
                    bestD = d
                    best = c
                end
            end
        end
        if best then teleportTo(best.Position) else notify("TP", "no coins") end
    end)
    addButton(g, "Teleport to spawn", function()
        local sp = workspace:FindFirstChildOfClass("SpawnLocation")
        if not sp then return notify("TP", "no spawn found") end
        teleportTo(sp.Position)
    end)

    ----------------------------------------------------------------
    -- MISC
    ----------------------------------------------------------------
    g = section(TMisc, "Utility", "L")
    addToggle(g, "AntiAFK", "Anti-AFK", "AntiAFK", S.AntiAFK)
    addToggle(g, "LobbyGuard", "Lobby guard", "LobbyGuard", S.LobbyGuard,
        "Pauses auto farm and auto pickup while no round is running")
    addToggle(g, "NotifyRoles", "Notify when roles found", "NotifyRoles", S.NotifyRoles)
    addButton(g, "Reset character", function()
        local char = LocalPlayer.Character
        if char then char:BreakJoints() end
    end)

    g = section(TMisc, "Player List", "L")
    UI._playerLabels = {}
    for _ = 1, 14 do
        local lbl = addLabel(g, " ")
        if lbl then table.insert(UI._playerLabels, lbl) end
    end

    g = section(TMisc, "Server", "R")
    addButton(g, "Rejoin server", function()
        pcall(function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end)
    end)
    addButton(g, "Server hop", function()
        local ok, res = pcall(function()
            return game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?limit=100")
        end)
        if not ok or not res then return notify("Hop", "request failed") end
        local ok2, data = pcall(function() return HttpService:JSONDecode(res) end)
        if not ok2 or not data or not data.data then return notify("Hop", "bad response") end
        local pool = {}
        for _, srv in ipairs(data.data) do
            if srv.id ~= game.JobId and srv.playing < srv.maxPlayers then
                table.insert(pool, srv.id)
            end
        end
        if #pool == 0 then return notify("Hop", "no open servers") end
        local ok3 = pcall(function()
            TeleportService:TeleportToPlaceInstance(game.PlaceId, pool[math.random(1, #pool)], LocalPlayer)
        end)
        notify("Hop", ok3 and "hopping..." or "teleport failed")
    end)
    addButton(g, "Copy Job ID", function()
        if setclipboard then pcall(function() setclipboard(game.JobId) end) end
        notify("Server", game.JobId)
    end)
    addButton(g, "Copy Place ID", function()
        if setclipboard then pcall(function() setclipboard(tostring(game.PlaceId)) end) end
        notify("Server", tostring(game.PlaceId))
    end)

    ----------------------------------------------------------------
    -- SETTINGS
    ----------------------------------------------------------------
    local THEMES = {
        ["Violet"]   = { MainColor = Color3.fromRGB(24, 22, 32), BackgroundColor = Color3.fromRGB(16, 15, 22), AccentColor = Color3.fromRGB(124, 92, 255), OutlineColor = Color3.fromRGB(44, 42, 60) },
        ["Cyan"]     = { MainColor = Color3.fromRGB(20, 26, 32), BackgroundColor = Color3.fromRGB(14, 18, 22), AccentColor = Color3.fromRGB(56, 189, 248), OutlineColor = Color3.fromRGB(36, 48, 60) },
        ["Emerald"]  = { MainColor = Color3.fromRGB(20, 28, 24), BackgroundColor = Color3.fromRGB(14, 20, 17), AccentColor = Color3.fromRGB(52, 211, 153), OutlineColor = Color3.fromRGB(34, 50, 42) },
        ["Amber"]    = { MainColor = Color3.fromRGB(30, 26, 20), BackgroundColor = Color3.fromRGB(22, 19, 14), AccentColor = Color3.fromRGB(251, 191, 36), OutlineColor = Color3.fromRGB(52, 45, 32) },
        ["Rose"]     = { MainColor = Color3.fromRGB(30, 22, 28), BackgroundColor = Color3.fromRGB(22, 16, 20), AccentColor = Color3.fromRGB(244, 114, 182), OutlineColor = Color3.fromRGB(52, 38, 48) },
        ["Crimson"]  = { MainColor = Color3.fromRGB(28, 20, 20), BackgroundColor = Color3.fromRGB(20, 14, 14), AccentColor = Color3.fromRGB(248, 113, 113), OutlineColor = Color3.fromRGB(50, 36, 36) },
        ["Obsidian"] = { MainColor = Color3.fromRGB(15, 15, 17), BackgroundColor = Color3.fromRGB(10, 10, 12), AccentColor = Color3.fromRGB(255, 120, 0), OutlineColor = Color3.fromRGB(34, 34, 38) },
    }
    local themeNames = {}
    for k in pairs(THEMES) do table.insert(themeNames, k) end
    table.sort(themeNames)

    local function applyTheme(th)
        if not th then return end
        pcall(function()
            Library.MainColor = th.MainColor
            Library.BackgroundColor = th.BackgroundColor
            Library.AccentColor = th.AccentColor
            Library.AccentColorDark = Library:GetDarkerColor(th.AccentColor)
            Library.OutlineColor = th.OutlineColor
            Library:UpdateColorsUsingRegistry()
        end)
    end
    UI._applyTheme = function() applyTheme(THEMES[S._theme]) end

    g = section(TSettings, "Appearance", "L")
    ThemeDrop = addDropdown(g, "Theme", "Theme", themeNames, "_theme", "Violet")
    if ThemeDrop then
        pcall(function() ThemeDrop:OnChanged(function(v) applyTheme(THEMES[v]) end) end)
    end
    applyTheme(THEMES["Violet"])
    addToggle(g, "KeybindList", "Show keybind list", "KeybindList", S.KeybindList)
    addSlider(g, "NotifyTime", "Notification time", "NotifyTime", S.NotifyTime, 1, 10, 0, "s")

    g = section(TSettings, "Config", "L")

    addButton(g, "Save config", function()
        if not writefile then return notify("Config", "executor has no writefile") end
        local data = {}
        for k, v in pairs(S) do
            if k ~= "Unloaded" then
                if typeof(v) == "Color3" then
                    data[k] = { __c = { v.R, v.G, v.B } }
                elseif type(v) ~= "table" then
                    data[k] = v
                end
            end
        end
        local ok = pcall(function() writefile(CONFIG_PATH, HttpService:JSONEncode(data)) end)
        notify("Config", ok and "saved" or "save failed")
    end)

    addButton(g, "Load config", function()
        if not (isfile and readfile) then return notify("Config", "executor has no readfile") end
        local okF, exists = pcall(isfile, CONFIG_PATH)
        if not okF or not exists then return notify("Config", "no config file") end
        local ok, content = pcall(readfile, CONFIG_PATH)
        if not ok or not content then return notify("Config", "no config file") end
        local ok2, data = pcall(function() return HttpService:JSONDecode(content) end)
        if not ok2 or type(data) ~= "table" then return notify("Config", "corrupt config") end
        for k, v in pairs(data) do
            if S[k] ~= nil then
                if type(v) == "table" and v.__c then
                    v = Color3.new(v.__c[1], v.__c[2], v.__c[3])
                end
                S[k] = v
                setUi(k, v)
            end
        end
        UI._applyTheme()
        applyEverything()
        notify("Config", "loaded")
    end)

    addButton(g, "Reset all settings", function()
        for k, v in pairs(DEFAULTS) do
            if k ~= "Unloaded" then
                S[k] = v
                setUi(k, v)
            end
        end
        UI._applyTheme()
        applyEverything()
        notify("Settings", "reset to defaults")
    end)

    g = section(TSettings, "Menu", "R")
    UI._infoLabel = addLabel(g, "Status: loading...")
    pcall(function()
        g:AddLabel("Menu bind"):AddKeyPicker("MenuKeybind", {
            Default = "RightShift", NoUI = true, Text = "Menu keybind",
        })
        if Options and Options.MenuKeybind then Library.ToggleKeybind = Options.MenuKeybind end
    end)
    addButton(g, "Unload", function() if unload then unload() end end)

    g = section(TSettings, "Diagnostics", "R")
    addButton(g, "Run diagnostics", function() if runDiagnostics then runDiagnostics() end end)

    g = section(TSettings, "About", "R")
    addLabel(g, HUB_NAME .. " MM2 " .. VERSION)
    addLabel(g, "Delete key also unloads")
end)

building = false

if not okBuild then
    notify(HUB_NAME .. ": menu failed", "script still runs on defaults. " .. string.sub(tostring(buildErr), 1, 90))
end

---------------------------------------------------------------------
-- Roles
---------------------------------------------------------------------
local lastMurderer, lastSheriff = nil, nil
local anyMurdererKnown = false

hasTool = function(player, names)
    local containers = {}
    if player.Character then table.insert(containers, player.Character) end
    local bp = player:FindFirstChildOfClass("Backpack")
    if bp then table.insert(containers, bp) end

    for _, c in ipairs(containers) do
        for _, child in ipairs(c:GetChildren()) do
            if child:IsA("Tool") then
                local lower = string.lower(child.Name)
                for _, n in ipairs(names) do
                    if lower == string.lower(n) then return true end
                end
            end
        end
    end
    return false
end

heldTool = function(player)
    local char = player.Character
    if not char then return nil end
    local tool = char:FindFirstChildOfClass("Tool")
    return tool and tool.Name or nil
end

getRole = function(player)
    if hasTool(player, { "Knife" }) then return "Murderer" end
    if hasTool(player, { "Gun", "GoldenGun", "Revolver" }) then return "Sheriff" end
    return "Innocent"
end

roleColor = function(role)
    if role == "Murderer" then return S.ColMurderer end
    if role == "Sheriff" then return S.ColSheriff end
    return S.ColInnocent
end

elemColor = function(customKey, role)
    local c
    if S.UseRoleColors then
        c = roleColor(role)
    else
        c = S[customKey]
    end
    if typeof(c) ~= "Color3" then return Color3.fromRGB(255, 255, 255) end
    return c
end

local function safeColor(c, fallback)
    if typeof(c) == "Color3" then return c end
    return fallback
end

refreshRoles = function()
    local murderer, sheriff = nil, nil
    for _, p in ipairs(Players:GetPlayers()) do
        local role = getRole(p)
        Roles[p] = role
        if role == "Murderer" then murderer = p.Name end
        if role == "Sheriff" then sheriff = p.Name end
    end
    anyMurdererKnown = murderer ~= nil

    if S.NotifyRoles then
        if murderer and murderer ~= lastMurderer then notify("Murderer", murderer) end
        if sheriff and sheriff ~= lastSheriff then notify("Sheriff", sheriff) end
    end
    lastMurderer = murderer
    lastSheriff = sheriff
end

---------------------------------------------------------------------
-- Lobby detection
---------------------------------------------------------------------
local inLobbyCached = false
local lastLobbyCheck = 0

local function computeInLobby()
    for _, p in ipairs(Players:GetPlayers()) do
        local char = p.Character
        if char and char:FindFirstChildOfClass("Tool") then return false end
        local bp = p:FindFirstChildOfClass("Backpack")
        if bp and bp:FindFirstChildOfClass("Tool") then return false end
    end
    if coinCache and coinCache.Parent and #coinCache:GetChildren() > 0 then return false end
    for _, n in ipairs({ "Map", "MapFolder", "CurrentMap" }) do
        if workspace:FindFirstChild(n) then return false end
    end
    return true
end

local function inLobby()
    if not S.LobbyGuard then return false end
    return inLobbyCached
end

---------------------------------------------------------------------
-- Drawings
---------------------------------------------------------------------
local FOVCircle = Drawing.new("Circle")
FOVCircle.Color = S.ColFOV
FOVCircle.Thickness = 1.5
FOVCircle.Transparency = 1
FOVCircle.Filled = false
FOVCircle.Visible = false
FOVCircle.ZIndex = 999

local GunText = Drawing.new("Text")
GunText.Visible = false
GunText.Color = S.ColGunDrop
GunText.Size = 14
GunText.Center = true
GunText.Outline = true
GunText.ZIndex = 998

local WatermarkDraw = Drawing.new("Text")
WatermarkDraw.Visible = false
WatermarkDraw.Color = S.ColWatermark
WatermarkDraw.Size = 15
WatermarkDraw.Position = Vector2.new(10, 8)
WatermarkDraw.Outline = true
WatermarkDraw.ZIndex = 1000

local ErrorDraw = Drawing.new("Text")
ErrorDraw.Visible = false
ErrorDraw.Color = Color3.fromRGB(255, 90, 90)
ErrorDraw.Size = 13
ErrorDraw.Position = Vector2.new(10, 28)
ErrorDraw.Outline = true
ErrorDraw.ZIndex = 1001

local TargetText = Drawing.new("Text")
TargetText.Visible = false
TargetText.Color = S.ColTarget
TargetText.Size = 15
TargetText.Center = true
TargetText.Outline = true
TargetText.ZIndex = 1000

local TargetLine = Drawing.new("Line")
TargetLine.Visible = false
TargetLine.Color = S.ColTarget
TargetLine.Thickness = 1.5
TargetLine.ZIndex = 996

local CrossLines = {}
for i = 1, 4 do
    local l = Drawing.new("Line")
    l.Visible = false
    l.Color = S.ColCrosshair
    l.Thickness = 1.2
    CrossLines[i] = l
end

local COIN_CAP = 32
local CoinTexts = {}

local function coinText(i)
    local t = CoinTexts[i]
    if t then return t end
    if i > COIN_CAP then return nil end
    local ok, obj = pcall(function()
        local nt = Drawing.new("Text")
        nt.Visible = false
        nt.Color = S.ColCoin
        nt.Size = 12
        nt.Center = true
        nt.Outline = true
        nt.ZIndex = 997
        return nt
    end)
    if not ok then return nil end
    CoinTexts[i] = obj
    return obj
end

local ESP = {}
local ESP_DRAW_KEYS = { "BoxFill", "Box", "Name", "Dist", "HpText", "Tracer", "HeadDot", "Beacon", "HealthBarBg", "HealthBar" }

local function createESP(player)
    if player == LocalPlayer or ESP[player] then return end

    local ok = pcall(function()
        local boxFill = Drawing.new("Square")
        boxFill.Visible = false boxFill.Filled = true boxFill.Thickness = 1

        local box = Drawing.new("Square")
        box.Visible = false box.Thickness = 1.5 box.Filled = false

        local nameTag = Drawing.new("Text")
        nameTag.Visible = false nameTag.Size = 13 nameTag.Center = true nameTag.Outline = true

        local distTag = Drawing.new("Text")
        distTag.Visible = false distTag.Size = 12 distTag.Center = true distTag.Outline = true

        local hpText = Drawing.new("Text")
        hpText.Visible = false hpText.Size = 11 hpText.Center = false hpText.Outline = true

        local tracer = Drawing.new("Line")
        tracer.Visible = false tracer.Thickness = 1 tracer.Transparency = 0.85

        local headDot = Drawing.new("Circle")
        headDot.Visible = false headDot.Filled = true headDot.Radius = 3
        headDot.Transparency = 1 headDot.Thickness = 1

        local beacon = Drawing.new("Line")
        beacon.Visible = false beacon.Thickness = 2 beacon.Transparency = 1

        local healthBarBg = Drawing.new("Square")
        healthBarBg.Visible = false healthBarBg.Filled = true healthBarBg.Thickness = 1

        local healthBar = Drawing.new("Square")
        healthBar.Visible = false healthBar.Filled = true healthBar.Thickness = 1

        local skeletonLines = {}
        for i = 1, 10 do
            local line = Drawing.new("Line")
            line.Visible = false line.Thickness = 1.2
            skeletonLines[i] = line
        end

        local highlight
        local hOk, hRes = pcall(function()
            local h = Instance.new("Highlight")
            h.Name = "AerizChams"
            h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            h.FillTransparency = 0.65
            h.OutlineTransparency = 1
            h.Enabled = false
            h.Parent = workspace
            return h
        end)
        if hOk then highlight = hRes end

        ESP[player] = {
            BoxFill = boxFill, Box = box, Name = nameTag, Dist = distTag, HpText = hpText,
            Tracer = tracer, HeadDot = headDot, Beacon = beacon,
            HealthBarBg = healthBarBg, HealthBar = healthBar,
            Skeleton = skeletonLines, Highlight = highlight,
        }
    end)
    if not ok then reportErr("createESP failed") end
end

local function hideDrawings(d)
    if not d then return end
    for _, k in ipairs(ESP_DRAW_KEYS) do
        if d[k] then d[k].Visible = false end
    end
    if d.Skeleton then
        for _, line in ipairs(d.Skeleton) do line.Visible = false end
    end
    if d.Highlight then d.Highlight.Enabled = false end
end

local function removeESP(player)
    local d = ESP[player]
    if not d then return end
    pcall(function()
        for _, k in ipairs(ESP_DRAW_KEYS) do
            if d[k] then d[k]:Remove() end
        end
        if d.Skeleton then
            for _, line in ipairs(d.Skeleton) do line:Remove() end
        end
        if d.Highlight then d.Highlight:Destroy() end
    end)
    ESP[player] = nil
    Roles[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do createESP(player) end
local playerAddedConn = Players.PlayerAdded:Connect(createESP)
local playerRemovingConn = Players.PlayerRemoving:Connect(removeESP)

local function tracerOrigin(cam)
    local vs = cam.ViewportSize
    if S.TracerOrigin == "Center" then return Vector2.new(vs.X / 2, vs.Y / 2) end
    if S.TracerOrigin == "Mouse" then return UserInputService:GetMouseLocation() end
    return Vector2.new(vs.X / 2, vs.Y)
end

local function drawPlayer(player, d, character, rootPart, hum, role, dist, cam)
    local headPos = rootPart.Position + Vector3.new(0, 3, 0)
    local legPos  = rootPart.Position - Vector3.new(0, 3.5, 0)
    local screenHead, onHead = cam:WorldToViewportPoint(headPos)
    local screenLeg, onLeg   = cam:WorldToViewportPoint(legPos)

    if not (onHead or onLeg) then
        hideDrawings(d)
        return
    end

    local boxColor    = elemColor("ColBox", role)
    local nameColor   = elemColor("ColName", role)
    local skelColor   = elemColor("ColSkeleton", role)
    local chamsColor  = elemColor("ColChams", role)
    local dotColor    = elemColor("ColHeadDot", role)
    local beaconColor = elemColor("ColBeacon", role)

    local height = math.abs(screenHead.Y - screenLeg.Y)
    local width  = height / 1.5
    local boxPos = Vector2.new(screenHead.X - width / 2, screenHead.Y)

    if S.BoxFill and d.BoxFill then
        d.BoxFill.Size = Vector2.new(width, height)
        d.BoxFill.Position = boxPos
        d.BoxFill.Color = boxColor
        d.BoxFill.Transparency = S.BoxFillAlpha
        d.BoxFill.Visible = true
    elseif d.BoxFill then
        d.BoxFill.Visible = false
    end

    if S.Box and d.Box then
        d.Box.Size = Vector2.new(width, height)
        d.Box.Position = boxPos
        d.Box.Color = boxColor
        d.Box.Thickness = S.BoxThick
        d.Box.Visible = true
    elseif d.Box then
        d.Box.Visible = false
    end

    if S.Tracer and d.Tracer then
        d.Tracer.From = tracerOrigin(cam)
        d.Tracer.To = Vector2.new(screenHead.X, screenHead.Y)
        d.Tracer.Color = safeColor(S.ColTracer, Color3.fromRGB(255, 255, 255))
        d.Tracer.Visible = true
    elseif d.Tracer then
        d.Tracer.Visible = false
    end

    if S.HeadDot and d.HeadDot then
        d.HeadDot.Position = Vector2.new(screenHead.X, screenHead.Y)
        d.HeadDot.Radius = math.max(2, width * 0.09)
        d.HeadDot.Color = dotColor
        d.HeadDot.Visible = true
    elseif d.HeadDot then
        d.HeadDot.Visible = false
    end

    if S.Beacon and d.Beacon and role == "Murderer" then
        local top, onTop = cam:WorldToViewportPoint(headPos + Vector3.new(0, 5, 0))
        if onTop then
            d.Beacon.From = Vector2.new(screenHead.X, screenHead.Y)
            d.Beacon.To = Vector2.new(top.X, top.Y)
            d.Beacon.Color = beaconColor
            d.Beacon.Visible = true
        else
            d.Beacon.Visible = false
        end
    elseif d.Beacon then
        d.Beacon.Visible = false
    end

    if (S.Name or S.RoleText or S.WeaponESP) and d.Name then
        local text = ""
        if S.Name then text = player.Name end
        if S.RoleText and role ~= "Innocent" then
            text = text .. (text ~= "" and " " or "") .. "[" .. string.upper(role) .. "]"
        end
        if S.WeaponESP then
            local tool = heldTool(player)
            if tool then text = text .. (text ~= "" and " " or "") .. "<" .. string.upper(tool) .. ">" end
        end
        d.Name.Text = text
        d.Name.Size = S.TextSize
        d.Name.Color = nameColor
        d.Name.Position = Vector2.new(screenHead.X, screenHead.Y - (S.Distance and 28 or 16))
        d.Name.Visible = text ~= ""
    elseif d.Name then
        d.Name.Visible = false
    end

    if S.Distance and d.Dist then
        d.Dist.Text = "(" .. math.floor(dist) .. ")"
        d.Dist.Size = math.max(9, S.TextSize - 1)
        d.Dist.Color = safeColor(S.ColDistance, Color3.fromRGB(205, 205, 220))
        d.Dist.Position = Vector2.new(screenHead.X, screenHead.Y - 16)
        d.Dist.Visible = true
    elseif d.Dist then
        d.Dist.Visible = false
    end

    if S.Health and hum and d.HealthBar and d.HealthBarBg then
        local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
        local barHeight = height * pct
        local lo = safeColor(S.ColHealthLo, Color3.fromRGB(240, 60, 60))
        local hi = safeColor(S.ColHealthHi, Color3.fromRGB(60, 230, 90))

        d.HealthBarBg.Size = Vector2.new(4, height + 2)
        d.HealthBarBg.Position = Vector2.new(boxPos.X - 6, boxPos.Y - 1)
        d.HealthBarBg.Color = Color3.fromRGB(0, 0, 0)
        d.HealthBarBg.Visible = true
        d.HealthBar.Size = Vector2.new(2, barHeight)
        d.HealthBar.Position = Vector2.new(boxPos.X - 5, boxPos.Y + (height - barHeight))
        d.HealthBar.Color = lo:Lerp(hi, pct)
        d.HealthBar.Visible = true
    else
        if d.HealthBar then d.HealthBar.Visible = false end
        if d.HealthBarBg then d.HealthBarBg.Visible = false end
    end

    if S.HealthText and hum and d.HpText then
        d.HpText.Text = tostring(math.floor(hum.Health))
        d.HpText.Size = math.max(9, S.TextSize - 2)
        d.HpText.Color = safeColor(S.ColHealthHi, Color3.fromRGB(60, 230, 90))
        d.HpText.Position = Vector2.new(boxPos.X + width + 4, boxPos.Y)
        d.HpText.Visible = true
    elseif d.HpText then
        d.HpText.Visible = false
    end

    if d.Highlight then
        if S.Chams then
            d.Highlight.Adornee = character
            d.Highlight.FillColor = chamsColor
            d.Highlight.FillTransparency = S.ChamsFillAlpha
            d.Highlight.OutlineColor = chamsColor
            d.Highlight.OutlineTransparency = S.ChamsOutline and 0 or 1
            d.Highlight.Enabled = true
        else
            d.Highlight.Enabled = false
        end
    end

    if S.Skeleton and d.Skeleton then
        local function pick(a, b) return character:FindFirstChild(a) or character:FindFirstChild(b) end
        local head = character:FindFirstChild("Head")
        local upperTorso = pick("UpperTorso", "Torso")
        local lowerTorso = character:FindFirstChild("LowerTorso") or upperTorso
        local lUpArm = pick("LeftUpperArm", "Left Arm")
        local lLoArm = character:FindFirstChild("LeftLowerArm") or lUpArm
        local rUpArm = pick("RightUpperArm", "Right Arm")
        local rLoArm = character:FindFirstChild("RightLowerArm") or rUpArm
        local lUpLeg = pick("LeftUpperLeg", "Left Leg")
        local lLoLeg = character:FindFirstChild("LeftLowerLeg") or lUpLeg
        local rUpLeg = pick("RightUpperLeg", "Right Leg")
        local rLoLeg = character:FindFirstChild("RightLowerLeg") or rUpLeg

        local links = {
            { head, upperTorso }, { upperTorso, lowerTorso },
            { upperTorso, lUpArm }, { lUpArm, lLoArm },
            { upperTorso, rUpArm }, { rUpArm, rLoArm },
            { lowerTorso, lUpLeg }, { lUpLeg, lLoLeg },
            { lowerTorso, rUpLeg }, { rUpLeg, rLoLeg },
        }

        for i, link in ipairs(links) do
            local a, b = link[1], link[2]
            local line = d.Skeleton[i]
            if line and a and b then
                local pa, oa = cam:WorldToViewportPoint(a.Position)
                local pb, ob = cam:WorldToViewportPoint(b.Position)
                if oa or ob then
                    line.From = Vector2.new(pa.X, pa.Y)
                    line.To = Vector2.new(pb.X, pb.Y)
                    line.Color = skelColor
                    line.Visible = true
                else
                    line.Visible = false
                end
            elseif line then
                line.Visible = false
            end
        end
    elseif d.Skeleton then
        for _, line in ipairs(d.Skeleton) do line.Visible = false end
    end
end

---------------------------------------------------------------------
-- Teleport
---------------------------------------------------------------------
touch = function(a, b)
    if not a or not b then return end
    if firetouchinterest then
        pcall(function()
            firetouchinterest(a, b, 0)
            firetouchinterest(a, b, 1)
        end)
    end
end

teleportTo = function(pos)
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or hum.Health <= 0 then return false end

    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.new()
            p.AssemblyAngularVelocity = Vector3.new()
        end
    end
    char:PivotTo(CFrame.new(pos + Vector3.new(0, 3, 0)))
    return true
end

---------------------------------------------------------------------
-- Fling
---------------------------------------------------------------------
local flinging = false
local flingCooldown = {}

local function zeroVelocity(char)
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            p.AssemblyLinearVelocity = Vector3.new()
            p.AssemblyAngularVelocity = Vector3.new()
        end
    end
end

-- glues our root part to the target and spins at huge velocity so the
-- collision launches them, then calms everything down and puts us back
local function flingBlocking(target)
    if flinging or not target or target == LocalPlayer then return false end

    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return false end

    local tchar = target.Character
    local thrp = tchar and tchar:FindFirstChild("HumanoidRootPart")
    if not thrp then return false end

    flinging = true
    local origin = hrp.CFrame
    local started = os.clock()
    local power = S.FlingPower

    while not S.Unloaded and (os.clock() - started) < S.FlingTime do
        local c = LocalPlayer.Character
        local h = c and c:FindFirstChild("HumanoidRootPart")
        local tc = target.Character
        local th = tc and tc:FindFirstChild("HumanoidRootPart")
        if not h or not th then break end

        local thum = tc:FindFirstChildOfClass("Humanoid")
        if thum and thum.Health <= 0 then break end

        local jitter = Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
        h.CFrame = th.CFrame + th.AssemblyLinearVelocity * 0.12 + jitter
        h.AssemblyLinearVelocity = Vector3.new(power, power, power)
        h.AssemblyAngularVelocity = Vector3.new(power, power, power)
        RunService.Heartbeat:Wait()
    end

    local c = LocalPlayer.Character
    local h = c and c:FindFirstChild("HumanoidRootPart")
    if h then
        for _ = 1, 8 do
            zeroVelocity(c)
            if S.FlingReturn then h.CFrame = origin end
            RunService.Heartbeat:Wait()
        end
    end

    flinging = false
    return true
end

flingAsync = function(target)
    task.spawn(function()
        local ok, err = pcall(flingBlocking, target)
        if not ok then
            flinging = false
            reportErr(err)
        end
    end)
end

flingAll = function()
    if flinging then return end
    task.spawn(function()
        for _, p in ipairs(Players:GetPlayers()) do
            if S.Unloaded then break end
            if p ~= LocalPlayer then
                local ok, err = pcall(flingBlocking, p)
                if not ok then
                    flinging = false
                    reportErr(err)
                end
                task.wait(0.15)
            end
        end
    end)
end

flingByRole = function(role)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and Roles[p] == role then
            flingAsync(p)
            return notify("Fling", "-> " .. p.Name)
        end
    end
    notify("Fling", string.lower(role) .. " not found")
end

local function flingAuraStep()
    if not S.FlingAura or flinging then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local th = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            if th and (th.Position - hrp.Position).Magnitude <= S.FlingAuraRange then
                if os.clock() - (flingCooldown[p] or 0) > 4 then
                    flingCooldown[p] = os.clock()
                    flingAsync(p)
                    return
                end
            end
        end
    end
end

---------------------------------------------------------------------
-- Gun drop / coins
---------------------------------------------------------------------
local gunDropCache, gunDropScan = nil, 0

findGunDrop = function()
    if gunDropCache and gunDropCache.Parent then return gunDropCache end

    local direct = workspace:FindFirstChild("GunDrop")
    if direct then
        gunDropCache = direct
        return direct
    end

    for _, d in ipairs(workspace:GetChildren()) do
        if d:IsA("Tool") and string.find(string.lower(d.Name), "gun") then
            gunDropCache = d
            return d
        end
    end

    if os.clock() - gunDropScan > 1 then
        gunDropScan = os.clock()
        local deep = workspace:FindFirstChild("GunDrop", true)
        if deep then
            gunDropCache = deep
            return deep
        end
    end
    return nil
end

getCoins = function()
    if not (coinCache and coinCache.Parent) then
        coinCache = nil
        if os.clock() - coinScan > 2 then
            coinScan = os.clock()
            coinCache = workspace:FindFirstChild("CoinContainer", true)
                or workspace:FindFirstChild("Coins")
                or workspace:FindFirstChild("CoinFolder")
        end
    end

    local out = {}
    if coinCache then
        for _, c in ipairs(coinCache:GetChildren()) do
            if c:IsA("BasePart") then
                table.insert(out, c)
            elseif c:IsA("Model") then
                local bp = c:FindFirstChildWhichIsA("BasePart")
                if bp then table.insert(out, bp) end
            end
        end
        return out
    end

    for _, d in ipairs(workspace:GetChildren()) do
        if d:IsA("BasePart") and string.find(string.lower(d.Name), "coin") then
            table.insert(out, d)
        end
    end
    return out
end

gunPart = function(obj)
    if not obj then return nil end
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Tool") then return obj:FindFirstChild("Handle") end
    if obj:IsA("Model") then return obj:FindFirstChildWhichIsA("BasePart") end
    return nil
end

---------------------------------------------------------------------
-- Aimbot
---------------------------------------------------------------------
local MOUSE_KEYS = {
    ["Right Mouse"]  = Enum.UserInputType.MouseButton2,
    ["Left Mouse"]   = Enum.UserInputType.MouseButton1,
    ["Middle Mouse"] = Enum.UserInputType.MouseButton3,
}
local KEY_KEYS = {
    ["Q"] = Enum.KeyCode.Q, ["E"] = Enum.KeyCode.E,
    ["Left Shift"] = Enum.KeyCode.LeftShift, ["Left Alt"] = Enum.KeyCode.LeftAlt,
}

local aimToggle = false
local locked = nil
local lastTrigger, lastAura = 0, 0

local function aimHeld()
    local k = S.AimKey
    if k == "Always On" then return true end
    if S.AimMode == "Toggle" then return aimToggle end
    local m = MOUSE_KEYS[k]
    if m then return UserInputService:IsMouseButtonPressed(m) end
    local c = KEY_KEYS[k]
    if c then return UserInputService:IsKeyDown(c) end
    return false
end

local function getAimPart(character)
    if S.AimPart == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
            or character:FindFirstChild("HumanoidRootPart")
    end
    return character:FindFirstChild(S.AimPart) or character:FindFirstChild("HumanoidRootPart")
end

local function isAliveCharacter(character)
    if not character then return false end
    local hum = character:FindFirstChildOfClass("Humanoid")
    return hum ~= nil and hum.Health > 0
end

local function roleAllowed(role)
    local mode = S.AimAt
    if mode == "Any" then return true end
    if mode == "Murderer" then return role == "Murderer" end
    if mode == "Sheriff" then return role == "Sheriff" end
    if mode == "Innocent" then return role == "Innocent" end

    local myRole = Roles[LocalPlayer] or "Innocent"
    if myRole == "Murderer" then return true end
    if anyMurdererKnown then return role == "Murderer" end
    return true
end

local function isVisible(origin, part, character)
    local filter = {}
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    if character then table.insert(filter, character) end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = filter
    return workspace:Raycast(origin, part.Position - origin, params) == nil
end

local function validTarget(player, camPos, maxDist)
    if not player or player == LocalPlayer then return nil end
    local character = player.Character
    if not isAliveCharacter(character) then return nil end
    if not roleAllowed(Roles[player] or "Innocent") then return nil end
    local part = getAimPart(character)
    if not part then return nil end
    if (part.Position - camPos).Magnitude > maxDist then return nil end
    if S.WallCheck and not isVisible(camPos, part, character) then return nil end
    return part
end

local function pickTarget(cam)
    local camPos = cam.CFrame.Position
    local look = cam.CFrame.LookVector
    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    local bestPlayer, bestPart, bestScore = nil, nil, math.huge
    local maxAngle = math.rad(S.FOV)

    for _, player in ipairs(Players:GetPlayers()) do
        local part = validTarget(player, camPos, S.MaxDist)
        if part then
            local dir = part.Position - camPos
            if dir.Magnitude > 0.1 then
                local angle = math.acos(math.clamp(look:Dot(dir.Unit), -1, 1))
                if angle <= maxAngle then
                    local score
                    if S.Priority == "Distance" then
                        score = dir.Magnitude
                    elseif S.Priority == "Health" then
                        local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
                        score = hum and hum.Health or 100
                    else
                        local sp, on = cam:WorldToViewportPoint(part.Position)
                        score = on and (Vector2.new(sp.X, sp.Y) - center).Magnitude or angle * 1000
                    end
                    if score < bestScore then
                        bestScore = score
                        bestPlayer = player
                        bestPart = part
                    end
                end
            end
        end
    end
    return bestPlayer, bestPart
end

local function click()
    if mouse1click then
        pcall(mouse1click)
    else
        pcall(function()
            VirtualInput:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            VirtualInput:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end
end

local function auraStep(cam)
    if not S.KillAura then return end
    if os.clock() - lastAura < S.KaDelay then return end
    local camPos = cam.CFrame.Position
    for _, player in ipairs(Players:GetPlayers()) do
        if validTarget(player, camPos, S.KaRange) then
            lastAura = os.clock()
            click()
            return
        end
    end
end

local function hideTargetDrawings()
    TargetText.Visible = false
    TargetLine.Visible = false
end

local function aimStep()
    if S.Unloaded then return end
    local cam = workspace.CurrentCamera
    if not cam then return end

    local aiming = S.Aimbot and aimHeld()
    if aiming and S.AimOnlyArmed and not heldTool(LocalPlayer) then aiming = false end
    if not aiming then locked = nil end

    local targetPlayer, part
    if aiming then
        local camPos = cam.CFrame.Position
        if S.Sticky and locked then
            part = validTarget(locked, camPos, S.MaxDist)
            if part then
                targetPlayer = locked
            else
                locked = nil
            end
        end
        if not targetPlayer then targetPlayer, part = pickTarget(cam) end
        locked = targetPlayer
    end

    local center = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)

    if aiming and targetPlayer and part then
        local aimPos = part.Position
        if S.Prediction and part:IsA("BasePart") then
            aimPos = aimPos + part.AssemblyLinearVelocity * S.PredTime
        end

        local sp, on = cam:WorldToViewportPoint(aimPos)
        local pxOff = on and (Vector2.new(sp.X, sp.Y) - center).Magnitude or 9999

        if pxOff > S.AimDeadzone then
            local alpha = 1 - math.clamp(S.Smooth / 100, 0, 0.99)
            cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, aimPos), alpha)
        end

        local tc = safeColor(S.ColTarget, Color3.fromRGB(255, 255, 0))
        if S.TargetHud then
            local dist = math.floor((part.Position - cam.CFrame.Position).Magnitude)
            TargetText.Text = targetPlayer.Name .. " [" .. string.upper(Roles[targetPlayer] or "Innocent") .. "] (" .. dist .. ")"
            TargetText.Color = tc
            TargetText.Position = Vector2.new(center.X, 60)
            TargetText.Visible = true
        else
            TargetText.Visible = false
        end

        if S.TargetLine and on then
            TargetLine.From = center
            TargetLine.To = Vector2.new(sp.X, sp.Y)
            TargetLine.Color = tc
            TargetLine.Visible = true
        else
            TargetLine.Visible = false
        end
    else
        hideTargetDrawings()
    end

    if S.Trigger and targetPlayer and part then
        local sp, on = cam:WorldToViewportPoint(part.Position)
        if on then
            if (Vector2.new(sp.X, sp.Y) - center).Magnitude <= S.TriggerFOV then
                if os.clock() - lastTrigger >= S.TriggerDelay then
                    lastTrigger = os.clock()
                    click()
                end
            end
        end
    end

    auraStep(cam)
end

RunService:BindToRenderStep("AerizAimbot", Enum.RenderPriority.Camera.Value + 1, aimStep)

---------------------------------------------------------------------
-- Lighting / camera
---------------------------------------------------------------------
local LightOrig = {
    Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient, OutdoorAmbient = Lighting.OutdoorAmbient,
    FogEnd = Lighting.FogEnd, FogStart = Lighting.FogStart,
    GlobalShadows = Lighting.GlobalShadows,
}
local CamFOVOrig = (workspace.CurrentCamera and workspace.CurrentCamera.FieldOfView) or 70

applyLighting = function()
    if S.Unloaded then return end

    if S.Fullbright then
        Lighting.Brightness = 2
        Lighting.Ambient = Color3.fromRGB(178, 178, 178)
        Lighting.OutdoorAmbient = Color3.fromRGB(178, 178, 178)
    else
        Lighting.Brightness = LightOrig.Brightness
        Lighting.Ambient = LightOrig.Ambient
        Lighting.OutdoorAmbient = LightOrig.OutdoorAmbient
    end

    if S.Fullbright then
        Lighting.ClockTime = 14
    elseif S.TimeOn then
        Lighting.ClockTime = S.TimeOfDay
    else
        Lighting.ClockTime = LightOrig.ClockTime
    end

    if S.Fullbright or S.NoShadows then
        Lighting.GlobalShadows = false
    else
        Lighting.GlobalShadows = LightOrig.GlobalShadows
    end

    if S.NoFog then
        Lighting.FogEnd = 100000
        Lighting.FogStart = 100000
    else
        Lighting.FogEnd = LightOrig.FogEnd
        Lighting.FogStart = LightOrig.FogStart
    end
end

applyCamFOV = function()
    local cam = workspace.CurrentCamera
    if not cam then return end
    cam.FieldOfView = S.CamFOVOn and S.CamFOV or CamFOVOrig
end

---------------------------------------------------------------------
-- Movement
---------------------------------------------------------------------
applySpeed = function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    hum.WalkSpeed = S.SpeedEnabled and S.Speed or 16
    if S.JumpEnabled then
        pcall(function()
            hum.UseJumpPower = true
            hum.JumpPower = S.Jump
        end)
    end
end

applyGravity = function()
    workspace.Gravity = S.GravityOn and S.Gravity or 196.2
end

applyScale = function()
    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local s = S.ScaleOn and S.Scale or 1
    for _, prop in ipairs({ "BodyDepthScale", "BodyWidthScale", "BodyHeightScale",
                            "BodyProportionScale", "HeadScale" }) do
        local v = hum:FindFirstChild(prop)
        if v and v:IsA("NumberValue") then pcall(function() v.Value = s end) end
    end
end

local noclipSaved = {}

applyNoclip = function(on)
    local char = LocalPlayer.Character
    if not char then
        noclipSaved = {}
        return
    end

    if on then
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") then
                if noclipSaved[p] == nil then noclipSaved[p] = p.CanCollide end
                p.CanCollide = false
            end
        end
    else
        for p, orig in pairs(noclipSaved) do
            if p and p.Parent then
                pcall(function() p.CanCollide = orig end)
            end
        end
        noclipSaved = {}
    end
end

local function noclipRefresh()
    local char = LocalPlayer.Character
    if not char then return end
    for _, p in ipairs(char:GetDescendants()) do
        if p:IsA("BasePart") then
            if noclipSaved[p] == nil then noclipSaved[p] = p.CanCollide end
            if p.CanCollide then p.CanCollide = false end
        end
    end
end

applyEverything = function()
    applyLighting()
    applyCamFOV()
    applySpeed()
    applyGravity()
    applyScale()
    applyNoclip(S.Noclip)
end

local flyBV

local function flyStep()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then
        if flyBV then
            flyBV:Destroy()
            flyBV = nil
        end
        return
    end
    if not S.Fly then
        if flyBV then
            flyBV:Destroy()
            flyBV = nil
            hum.PlatformStand = false
        end
        return
    end
    if not flyBV then
        flyBV = Instance.new("BodyVelocity")
        flyBV.Name = "AerizFly"
        flyBV.MaxForce = Vector3.new(1e5, 1e5, 1e5)
        flyBV.Velocity = Vector3.new()
        flyBV.Parent = hrp
    end
    hum.PlatformStand = true
    local cam = workspace.CurrentCamera
    local dir = Vector3.new()
    local look, right = cam.CFrame.LookVector, cam.CFrame.RightVector
    if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir = dir + look end
    if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir = dir - look end
    if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir = dir + right end
    if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir = dir - right end
    if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir = dir + Vector3.new(0, 1, 0) end
    if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir = dir - Vector3.new(0, 1, 0) end
    if dir.Magnitude > 0 then dir = dir.Unit end
    flyBV.Velocity = dir * S.FlySpeed
end

local function spinStep()
    if not S.Spin then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(S.SpinSpeed), 0)
    end
end

local function bhopStep()
    if not S.BHop then return end
    if not UserInputService:IsKeyDown(Enum.KeyCode.Space) then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum and hum.FloorMaterial ~= Enum.Material.Air then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end

local lastSafe = nil

local function antiVoidStep()
    if not S.AntiVoid then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum then return end

    local floorY = workspace.FallenPartsDestroyHeight + 60
    if hrp.Position.Y < floorY then
        if lastSafe then char:PivotTo(lastSafe) end
        return
    end
    if hum.FloorMaterial ~= Enum.Material.Air then
        lastSafe = hrp.CFrame
    end
end

---------------------------------------------------------------------
-- Auto actions
---------------------------------------------------------------------
local lastCollect = 0

local function autoEquip()
    if not S.AutoEquip then return end
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:FindFirstChildOfClass("Humanoid")
    local bp = LocalPlayer:FindFirstChildOfClass("Backpack")
    if not hum or not bp then return end
    if char:FindFirstChildOfClass("Tool") then return end
    local tool = bp:FindFirstChild("Knife")
        or bp:FindFirstChild("Gun")
        or bp:FindFirstChild("GoldenGun")
    if tool then hum:EquipTool(tool) end
end

autoPickupGun = function(force)
    if not (S.AutoPickupGun or force) then return false end
    if not force and inLobby() then return false end

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not char or not hum or not hrp or hum.Health <= 0 then return false end
    if hasTool(LocalPlayer, { "Gun", "GoldenGun" }) then return false end

    local part = gunPart(findGunDrop())
    if not part then return false end

    if (part.Position - hrp.Position).Magnitude > 3 then
        teleportTo(part.Position)
    end
    touch(hrp, part)
    return true
end

autoCollect = function()
    if not S.AutoCollect or S.Fly then return end
    if inLobby() then return end
    if os.clock() - lastCollect < S.CollectDelay then return end
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return end
    for _, coin in ipairs(getCoins()) do
        if coin.Parent and coin:IsA("BasePart") then
            if (coin.Position - hrp.Position).Magnitude <= S.CoinRange then
                lastCollect = os.clock()
                teleportTo(coin.Position)
                touch(hrp, coin)
                break
            end
        end
    end
end

---------------------------------------------------------------------
-- Render
---------------------------------------------------------------------
local fps, frameCount, fpsClock = 0, 0, os.clock()
local lastRoleRefresh, lastListRefresh, lastWatermark, lastListSig = 0, 0, 0, ""
local lastNoclip, lastSpeedApply, lastWorldApply = 0, 0, 0
local hue = 0

local function getFOVRadius(cam)
    if S.FOV >= 89 then return 99999 end
    local tanFov = math.tan(math.rad(cam.FieldOfView / 2))
    return (math.tan(math.rad(S.FOV)) / tanFov) * (cam.ViewportSize.Y / 2)
end

local function updatePlayerList()
    local list = {}
    local cam = workspace.CurrentCamera
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
            local dist = hrp and math.floor((hrp.Position - cam.CFrame.Position).Magnitude) or -1
            table.insert(list, { name = p.Name, role = Roles[p] or "?", dist = dist })
        end
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)

    local labels = UI._playerLabels
    local names = {}
    if labels then
        for i, lbl in ipairs(labels) do
            local e = list[i]
            if e then
                pcall(function() lbl:SetText(string.format("  %s  [%s]  %dm", e.name, e.role, e.dist)) end)
                table.insert(names, e.name)
            else
                pcall(function() lbl:SetText(" ") end)
            end
        end
    end

    local newSig = table.concat(names, ",")
    if newSig ~= lastListSig and #names > 0 and PlayerDrop then
        lastListSig = newSig
        pcall(function() PlayerDrop:SetValues(names) end)
        local keep = S._tptarget
        if not keep or not table.find(names, keep) then keep = names[1] end
        pcall(function() PlayerDrop:SetValue(keep) end)
        S._tptarget = keep

        if FlingDrop then
            pcall(function() FlingDrop:SetValues(names) end)
            local fk = S._flingtarget
            if not fk or not table.find(names, fk) then fk = names[1] end
            pcall(function() FlingDrop:SetValue(fk) end)
            S._flingtarget = fk
        end
    end

    if UI._infoLabel then
        pcall(function()
            UI._infoLabel:SetText(string.format("%d players  |  You: %s  |  %s",
                #Players:GetPlayers(), Roles[LocalPlayer] or "?", inLobby() and "LOBBY" or "ROUND"))
        end)
    end
end

local function renderFrame()
    local cam = workspace.CurrentCamera
    if not cam then return end

    frameCount = frameCount + 1
    if os.clock() - fpsClock >= 1 then
        fps = frameCount
        frameCount = 0
        fpsClock = os.clock()
    end

    local now = os.clock()

    if now - lastRoleRefresh > 0.2 then
        lastRoleRefresh = now
        try(refreshRoles)
    end
    if now - lastLobbyCheck > 0.4 then
        lastLobbyCheck = now
        try(function() inLobbyCached = computeInLobby() end)
    end
    if now - lastListRefresh > 0.5 then
        lastListRefresh = now
        try(updatePlayerList)
    end
    if (S.SpeedEnabled or S.JumpEnabled) and now - lastSpeedApply > 0.5 then
        lastSpeedApply = now
        try(applySpeed)
    end
    if S.Noclip and now - lastNoclip > 0.25 then
        lastNoclip = now
        try(noclipRefresh)
    end
    if (S.Fullbright or S.NoFog or S.NoShadows or S.TimeOn) and now - lastWorldApply > 0.5 then
        lastWorldApply = now
        try(applyLighting)
    end
    if S.CamFOVOn and math.abs(cam.FieldOfView - S.CamFOV) > 0.01 then
        cam.FieldOfView = S.CamFOV
    end

    local fovC = safeColor(S.ColFOV, Color3.fromRGB(255, 105, 180))
    if S.RainbowFOV then
        hue = (hue + 0.005) % 1
        FOVCircle.Color = Color3.fromHSV(hue, 1, 1)
    else
        FOVCircle.Color = fovC
    end
    FOVCircle.Position = Vector2.new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
    FOVCircle.Radius = getFOVRadius(cam)
    FOVCircle.Visible = S.Aimbot and S.ShowFOV and S.FOV < 89

    local crossC = safeColor(S.ColCrosshair, Color3.fromRGB(0, 255, 180))
    if S.Crosshair then
        local cx, cy = cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2
        local gap, len = 6, 10
        local pts = {
            { Vector2.new(cx - gap - len, cy), Vector2.new(cx - gap, cy) },
            { Vector2.new(cx + gap, cy), Vector2.new(cx + gap + len, cy) },
            { Vector2.new(cx, cy - gap - len), Vector2.new(cx, cy - gap) },
            { Vector2.new(cx, cy + gap), Vector2.new(cx, cy + gap + len) },
        }
        for i = 1, 4 do
            CrossLines[i].From = pts[i][1]
            CrossLines[i].To = pts[i][2]
            CrossLines[i].Color = crossC
            CrossLines[i].Visible = true
        end
    else
        for _, l in ipairs(CrossLines) do l.Visible = false end
    end

    if now - lastWatermark > 0.5 then
        lastWatermark = now
        local ping, mem = 0, 0
        pcall(function() ping = math.floor(LocalPlayer:GetNetworkPing() * 1000) end)
        pcall(function() mem = math.floor(Stats:GetTotalMemoryUsageMb()) end)
        local wm = string.format("%s MM2  |  %s  |  FPS %d  |  Ping %dms  |  Mem %dMB  |  Players %d  |  You: %s",
            HUB_NAME, inLobby() and "LOBBY" or "ROUND", fps, ping, mem,
            #Players:GetPlayers(), Roles[LocalPlayer] or "?")

        local usedNative = false
        if LIB == "Linoria" and Library.SetWatermark then
            usedNative = pcall(function() Library:SetWatermark(wm) end)
            if Library.SetWatermarkVisibility then
                pcall(function() Library:SetWatermarkVisibility(S.Watermark) end)
            end
        end

        WatermarkDraw.Text = wm
        WatermarkDraw.Color = safeColor(S.ColWatermark, Color3.fromRGB(255, 255, 255))
        WatermarkDraw.Visible = S.Watermark and not usedNative
    end

    spinStep()
    bhopStep()
    antiVoidStep()
    flingAuraStep()
    local gunHandled = autoPickupGun(false)
    if not gunHandled then autoCollect() end
    flyStep()
    autoEquip()

    GunText.Color = safeColor(S.ColGunDrop, Color3.fromRGB(255, 220, 0))
    local coinC = safeColor(S.ColCoin, Color3.fromRGB(255, 215, 0))

    if not S.ESP then
        for _, d in pairs(ESP) do hideDrawings(d) end
        GunText.Visible = false
        for _, t in ipairs(CoinTexts) do t.Visible = false end
        return
    end

    local camPos = cam.CFrame.Position

    for player, d in pairs(ESP) do
        local character = player.Character
        local rootPart = character and character:FindFirstChild("HumanoidRootPart")
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        local role = Roles[player] or "Innocent"

        if rootPart and hum and hum.Health > 0 and (S.ShowInnocents or role ~= "Innocent") then
            local dist = (rootPart.Position - camPos).Magnitude
            if dist <= S.ESPDist then
                try(drawPlayer, player, d, character, rootPart, hum, role, dist, cam)
            else
                hideDrawings(d)
            end
        else
            hideDrawings(d)
        end
    end

    if S.GunDrop then
        local part = gunPart(findGunDrop())
        if part then
            local screen, onScreen = cam:WorldToViewportPoint(part.Position)
            if onScreen then
                GunText.Text = "GUN DROP (" .. math.floor((part.Position - camPos).Magnitude) .. ")"
                GunText.Position = Vector2.new(screen.X, screen.Y)
                GunText.Visible = true
            else
                GunText.Visible = false
            end
        else
            GunText.Visible = false
        end
    else
        GunText.Visible = false
    end

    local shown = 0
    if S.CoinESP then
        for _, coin in ipairs(getCoins()) do
            if coin:IsA("BasePart") and coin.Parent then
                local screen, onScreen = cam:WorldToViewportPoint(coin.Position)
                if onScreen then
                    shown = shown + 1
                    local t = coinText(shown)
                    if not t then break end
                    t.Color = coinC
                    t.Text = "COIN (" .. math.floor((coin.Position - camPos).Magnitude) .. ")"
                    t.Position = Vector2.new(screen.X, screen.Y)
                    t.Visible = true
                end
            end
        end
    end
    for i = shown + 1, #CoinTexts do
        if CoinTexts[i] then CoinTexts[i].Visible = false end
    end
end

local renderConn = RunService.RenderStepped:Connect(function()
    if S.Unloaded then return end
    local ok, err = pcall(renderFrame)
    if not ok then reportErr(err) end

    if lastErr and (os.clock() - lastErrClock) < 4 then
        ErrorDraw.Text = "ERR: " .. lastErr
        ErrorDraw.Visible = true
    else
        ErrorDraw.Visible = false
    end
end)

---------------------------------------------------------------------
-- Input / character hooks
---------------------------------------------------------------------
local connections = {}

table.insert(connections, UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end

    if S.AimMode == "Toggle" and S.AimKey ~= "Always On" then
        local m = MOUSE_KEYS[S.AimKey]
        local c = KEY_KEYS[S.AimKey]
        if (m and input.UserInputType == m) or (c and input.KeyCode == c) then
            aimToggle = not aimToggle
        end
    end

    if S.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1
        and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        local cam = workspace.CurrentCamera
        local loc = UserInputService:GetMouseLocation() - GuiService:GetGuiInset()
        local ray = cam:ViewportPointToRay(loc.X, loc.Y)
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = { LocalPlayer.Character }
        local res = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
        if res then teleportTo(res.Position) end
    end

    if input.KeyCode == Enum.KeyCode.Delete then
        if unload then unload() end
    end
end))

table.insert(connections, UserInputService.JumpRequest:Connect(function()
    if not S.InfJump then return end
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
end))

-- walk fling: big velocity on Heartbeat (what other players see), real velocity on RenderStepped
local wfVel = nil

table.insert(connections, RunService.Heartbeat:Connect(function()
    if S.Unloaded or not S.WalkFling or flinging then
        wfVel = nil
        return
    end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        wfVel = nil
        return
    end
    wfVel = hrp.AssemblyLinearVelocity
    hrp.AssemblyLinearVelocity = wfVel * 10000 + Vector3.new(0, 10000, 0)
end))

table.insert(connections, RunService.RenderStepped:Connect(function()
    if not wfVel then return end
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp then hrp.AssemblyLinearVelocity = wfVel end
    wfVel = nil
end))

table.insert(connections, LocalPlayer.Idled:Connect(function()
    if not S.AntiAFK then return end
    pcall(function()
        VirtualUser:CaptureController()
        VirtualUser:ClickButton2(Vector2.new())
    end)
end))

table.insert(connections, LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.6)
    noclipSaved = {}
    lastSafe = nil
    applySpeed()
    applyScale()
    if S.Noclip then applyNoclip(true) end
    aimToggle = false
end))

---------------------------------------------------------------------
-- Unload
---------------------------------------------------------------------
runDiagnostics = function()
    local lines = {}
    local function add(t) lines[#lines + 1] = t end
    local function yn(b) return b and "yes" or "NO" end

    add(HUB_NAME .. " MM2 " .. VERSION .. " diagnostics")
    add("ui library: " .. tostring(LIB))
    add("Drawing: " .. yn(Drawing ~= nil))
    add("firetouchinterest: " .. yn(firetouchinterest ~= nil))
    add("mouse1click: " .. yn(mouse1click ~= nil))
    add("writefile + readfile: " .. yn(writefile ~= nil and readfile ~= nil))
    add("setclipboard: " .. yn(setclipboard ~= nil))
    add("chams (Highlight): " .. yn(pcall(function() Instance.new("Highlight"):Destroy() end)))

    local murd, sher = "none", "none"
    for p, r in pairs(Roles) do
        if r == "Murderer" then murd = p.Name end
        if r == "Sheriff" then sher = p.Name end
    end
    add("roles: murderer=" .. murd .. "  sheriff=" .. sher .. "  you=" .. tostring(Roles[LocalPlayer]))

    local coins = getCoins()
    add("coins found: " .. #coins .. (coinCache and (" in " .. coinCache:GetFullName()) or " (no container found)"))

    local gd = findGunDrop()
    add("gun drop: " .. (gd and gd:GetFullName() or "none right now"))

    local espCount = 0
    for _ in pairs(ESP) do espCount = espCount + 1 end
    add("esp objects: " .. espCount .. " for " .. (#Players:GetPlayers() - 1) .. " other players")
    add("lobby detected: " .. tostring(inLobbyCached))
    add("last error: " .. tostring(lastErr))

    local report = table.concat(lines, "\n")
    print(report)
    if writefile then pcall(writefile, "AerizHub_diag.txt", report) end
    notify("Diagnostics", "printed to F9" .. (writefile and " and saved to AerizHub_diag.txt" or ""))
end

unload = function()
    if S.Unloaded then return end
    S.Unloaded = true
    flinging = false

    pcall(function() RunService:UnbindFromRenderStep("AerizAimbot") end)
    if renderConn then renderConn:Disconnect() end
    if playerAddedConn then playerAddedConn:Disconnect() end
    if playerRemovingConn then playerRemovingConn:Disconnect() end
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end

    pcall(function()
        FOVCircle.Visible = false FOVCircle:Remove()
        GunText.Visible = false GunText:Remove()
        WatermarkDraw.Visible = false WatermarkDraw:Remove()
        ErrorDraw.Visible = false ErrorDraw:Remove()
        TargetText.Visible = false TargetText:Remove()
        TargetLine.Visible = false TargetLine:Remove()
        for _, l in ipairs(CrossLines) do l.Visible = false l:Remove() end
        for _, t in ipairs(CoinTexts) do t.Visible = false t:Remove() end
    end)

    for player in pairs(ESP) do removeESP(player) end
    table.clear(ESP)
    table.clear(Roles)

    if flyBV then
        flyBV:Destroy()
        flyBV = nil
    end
    if S.Noclip then pcall(function() applyNoclip(false) end) end

    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then
        pcall(function() hum.PlatformStand = false end)
        pcall(function() hum.WalkSpeed = 16 end)
    end
    pcall(function() workspace.Gravity = 196.2 end)
    pcall(function()
        local cam = workspace.CurrentCamera
        if cam then cam.FieldOfView = CamFOVOrig end
    end)

    Lighting.Brightness = LightOrig.Brightness
    Lighting.ClockTime = LightOrig.ClockTime
    Lighting.Ambient = LightOrig.Ambient
    Lighting.OutdoorAmbient = LightOrig.OutdoorAmbient
    Lighting.FogEnd = LightOrig.FogEnd
    Lighting.FogStart = LightOrig.FogStart
    Lighting.GlobalShadows = LightOrig.GlobalShadows

    pcall(function() Library:Unload() end)
    print("[aeriz] unloaded")
end

pcall(function() Library:OnUnload(function() unload() end) end)

applyEverything()

local missingCaps = {}
if not firetouchinterest then table.insert(missingCaps, "firetouchinterest") end
if not writefile then table.insert(missingCaps, "writefile") end
if not setclipboard then table.insert(missingCaps, "setclipboard") end
if #missingCaps > 0 then
    notify("Limited executor", "missing: " .. table.concat(missingCaps, ", "))
end

notify(HUB_NAME .. " MM2 " .. VERSION, "loaded  |  RightShift = menu")
