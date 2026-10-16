--[[
    AERIZ HUB  -  loader
    loadstring(game:HttpGet("https://raw.githubusercontent.com/hxzy2k/Aeriz-Hub/main/loader.lua"))()
]]

local CONFIG = {
    user   = "hxzy2k",
    repo   = "Aeriz-Hub",
    branch = "main",              -- change to "master" if that is your default branch
    title  = "Aeriz Hub",
    toggle = Enum.KeyCode.RightShift,
    accent = Color3.fromRGB(124, 92, 255),
    esp    = false,
}

-- name, place id (auto-detect + real game icon), folder in repo
local GAMES = {
    { name = "Murder Mystery 2", place = 142823291,   dir = "mm2"    },
    { name = "Rivals",           place = 17625359962, dir = "rivals" },
}

--=====================================================================
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")

local MY_PLACE, MY_UNIVERSE = game.PlaceId, game.GameId
local RAW = "https://raw.githubusercontent.com/%s/%s/%s/%s"
local API = "https://api.github.com/repos/%s/%s/contents/%s?ref=%s"

local C = {
    bg      = Color3.fromRGB(18, 18, 23),
    panel   = Color3.fromRGB(26, 26, 33),
    panel2  = Color3.fromRGB(33, 33, 42),
    row     = Color3.fromRGB(38, 38, 48),
    border  = Color3.fromRGB(48, 48, 60),
    text    = Color3.fromRGB(233, 233, 243),
    dim     = Color3.fromRGB(140, 140, 162),
    bad     = Color3.fromRGB(242, 96, 96),
    good    = Color3.fromRGB(92, 220, 140),
    warn    = Color3.fromRGB(240, 190, 90),
}

local listing, currentGame, currentDir = {}, nil, nil
local espBtn, backHdr, render, selectGame

--=====================================================================
-- http
--=====================================================================
local function urlEncode(s)
    return (tostring(s):gsub("[^%w%-%._~/]", function(c)
        return string.format("%%%02X", string.byte(c))
    end))
end

local function httpGet(url)
    if request then
        local ok, r = pcall(request, { Url = url, Method = "GET" })
        if ok and type(r) == "table" and r.Body then return r.Body end
    end
    if syn and syn.request then
        local ok, r = pcall(syn.request, { Url = url, Method = "GET" })
        if ok and type(r) == "table" and r.Body then return r.Body end
    end
    return game:HttpGet(url)
end

local function rawURL(p)
    return string.format(RAW, CONFIG.user, CONFIG.repo, CONFIG.branch, urlEncode(p))
end

local function apiList(path)
    local url = string.format(API, CONFIG.user, CONFIG.repo, urlEncode(path), CONFIG.branch)
    local ok, body = pcall(httpGet, url)
    if not ok or not body then return nil, "request failed" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 or type(data) ~= "table" then return nil, "bad response" end
    if data.message then return nil, data.message end
    return data
end

local function gameIcon(g)
    if g.icon then return g.icon end
    if g.place and g.place ~= 0 then
        return string.format("rbxthumb://type=GameIcon&id=%d&w=150&h=150", g.place)
    end
    return nil
end

--=====================================================================
-- window
--=====================================================================
local function guiParent()
    if gethui then
        local ok, h = pcall(gethui)
        if ok and h then return h end
    end
    return game:GetService("CoreGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "AerizHub"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent()

local win = Instance.new("Frame")
win.Size = UDim2.fromOffset(500, 520)
win.Position = UDim2.new(0.5, -250, 0.5, -260)
win.BackgroundColor3 = C.bg
win.BorderSizePixel = 0
win.Parent = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 12)
local winStroke = Instance.new("UIStroke", win)
winStroke.Color = C.border
winStroke.Thickness = 1

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 50)
header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0
header.Parent = win
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 12)
local hmask = Instance.new("Frame")
hmask.Size = UDim2.new(1, 0, 0, 14)
hmask.Position = UDim2.new(0, 0, 1, -14)
hmask.BackgroundColor3 = C.panel
hmask.BorderSizePixel = 0
hmask.Parent = header
local hgrad = Instance.new("UIGradient")
hgrad.Color = ColorSequence.new(C.panel, C.panel:Lerp(CONFIG.accent, 0.12))
hgrad.Parent = header

local logo = Instance.new("Frame")
logo.Size = UDim2.fromOffset(26, 26)
logo.Position = UDim2.new(0, 16, 0.5, -13)
logo.BackgroundColor3 = CONFIG.accent
logo.BorderSizePixel = 0
logo.Parent = header
Instance.new("UICorner", logo).CornerRadius = UDim.new(0, 8)
local logoTxt = Instance.new("TextLabel")
logoTxt.Size = UDim2.fromScale(1, 1)
logoTxt.BackgroundTransparency = 1
logoTxt.Font = Enum.Font.GothamBlack
logoTxt.TextSize = 15
logoTxt.TextColor3 = Color3.fromRGB(255, 255, 255)
logoTxt.Text = "A"
logoTxt.Parent = logo

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 50, 0, 8)
titleLbl.Size = UDim2.new(1, -220, 0, 18)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextColor3 = C.text
titleLbl.Text = CONFIG.title
titleLbl.Parent = header

local subLbl = Instance.new("TextLabel")
subLbl.BackgroundTransparency = 1
subLbl.Position = UDim2.new(0, 50, 0, 26)
subLbl.Size = UDim2.new(1, -220, 0, 14)
subLbl.Font = Enum.Font.Gotham
subLbl.TextSize = 11
subLbl.TextXAlignment = Enum.TextXAlignment.Left
subLbl.TextColor3 = C.dim
subLbl.Text = "loading..."
subLbl.Parent = header

local function hdrBtn(text, xOff, width, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(width or 26, 26)
    b.Position = UDim2.new(1, xOff, 0.5, -13)
    b.BackgroundColor3 = C.panel2
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.TextColor3 = C.text
    b.Text = text
    b.AutoButtonColor = false
    b.Parent = header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
    b.MouseEnter:Connect(function()
        if not b:GetAttribute("on") then
            TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = C.row }):Play()
        end
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), {
            BackgroundColor3 = b:GetAttribute("on") and CONFIG.accent or C.panel2
        }):Play()
    end)
    b.MouseButton1Click:Connect(cb)
    return b
end

espBtn = hdrBtn("ESP", -142, 40, function()
    CONFIG.esp = not CONFIG.esp
    espBtn:SetAttribute("on", CONFIG.esp)
    espBtn.BackgroundColor3 = CONFIG.esp and CONFIG.accent or C.panel2
end)
espBtn:SetAttribute("on", CONFIG.esp)
if CONFIG.esp then espBtn.BackgroundColor3 = CONFIG.accent end

hdrBtn("–", -68, 26, function() win.Visible = false end)
hdrBtn("×", -36, 26, function() gui:Destroy() end)

--=====================================================================
-- body
--=====================================================================
local sidebar = Instance.new("Frame")
sidebar.Size = UDim2.new(0, 158, 1, -74)
sidebar.Position = UDim2.new(0, 14, 0, 60)
sidebar.BackgroundColor3 = C.panel
sidebar.BorderSizePixel = 0
sidebar.Parent = win
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 10)

local sidebarScroll = Instance.new("ScrollingFrame")
sidebarScroll.Size = UDim2.new(1, -12, 1, -12)
sidebarScroll.Position = UDim2.new(0, 6, 0, 6)
sidebarScroll.BackgroundTransparency = 1
sidebarScroll.BorderSizePixel = 0
sidebarScroll.ScrollBarThickness = 3
sidebarScroll.ScrollBarImageColor3 = C.border
sidebarScroll.CanvasSize = UDim2.new()
sidebarScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
sidebarScroll.Parent = sidebar

local sidebarLayout = Instance.new("UIListLayout")
sidebarLayout.Padding = UDim.new(0, 4)
sidebarLayout.Parent = sidebarScroll

local content = Instance.new("Frame")
content.Size = UDim2.new(1, -186, 1, -74)
content.Position = UDim2.new(0, 172, 0, 60)
content.BackgroundColor3 = C.panel
content.BorderSizePixel = 0
content.Parent = win
Instance.new("UICorner", content).CornerRadius = UDim.new(0, 10)

local searchWrap = Instance.new("Frame")
searchWrap.Size = UDim2.new(1, -20, 0, 34)
searchWrap.Position = UDim2.new(0, 10, 0, 10)
searchWrap.BackgroundColor3 = C.panel2
searchWrap.BorderSizePixel = 0
searchWrap.Parent = content
Instance.new("UICorner", searchWrap).CornerRadius = UDim.new(0, 8)

local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -30, 1, 0)
search.Position = UDim2.new(0, 26, 0, 0)
search.BackgroundTransparency = 1
search.Font = Enum.Font.Gotham
search.TextSize = 12
search.TextColor3 = C.text
search.PlaceholderText = "search scripts..."
search.PlaceholderColor3 = C.dim
search.Text = ""
search.ClearTextOnFocus = false
search.Parent = searchWrap

local searchIcon = Instance.new("TextLabel")
searchIcon.Size = UDim2.fromOffset(20, 20)
searchIcon.Position = UDim2.new(0, 8, 0.5, -10)
searchIcon.BackgroundTransparency = 1
searchIcon.Font = Enum.Font.GothamBold
searchIcon.TextSize = 12
searchIcon.TextColor3 = C.dim
searchIcon.Text = "⌕"
searchIcon.Parent = searchWrap

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -88)
list.Position = UDim2.new(0, 10, 0, 52)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.ScrollBarImageColor3 = C.border
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = content

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = list

local footer = Instance.new("TextLabel")
footer.Size = UDim2.new(1, -28, 0, 20)
footer.Position = UDim2.new(0, 14, 1, -26)
footer.BackgroundTransparency = 1
footer.Font = Enum.Font.Gotham
footer.TextSize = 11
footer.TextXAlignment = Enum.TextXAlignment.Left
footer.TextTruncate = Enum.TextTruncate.AtEnd
footer.TextColor3 = C.dim
footer.Text = "ready"
footer.Parent = win

local function status(txt, color)
    footer.Text = tostring(txt)
    footer.TextColor3 = color or C.dim
end

--=====================================================================
-- dragging
--=====================================================================
do
    local dragging, dragStart, startPos
    header.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = win.Position
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch) then
            local d = input.Position - dragStart
            win.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + d.X,
                startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--=====================================================================
-- esp
--=====================================================================
local ESP = {}

local function espFor(plr)
    if ESP[plr] then return ESP[plr] end
    local ok, t = pcall(function()
        local box = Drawing.new("Square")
        box.Thickness = 1.5 box.Filled = false box.Visible = false
        local nm = Drawing.new("Text")
        nm.Size = 13 nm.Center = true nm.Outline = true nm.Visible = false
        local ds = Drawing.new("Text")
        ds.Size = 11 ds.Center = true ds.Outline = true ds.Visible = false
        return { box = box, name = nm, dist = ds }
    end)
    if not ok then return nil end
    ESP[plr] = t
    return t
end

local function espDrop(plr)
    local t = ESP[plr]
    if not t then return end
    pcall(function() t.box:Remove() t.name:Remove() t.dist:Remove() end)
    ESP[plr] = nil
end

RunService.RenderStepped:Connect(function()
    if not Drawing then return end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local camPos = cam.CFrame.Position

    for plr in pairs(ESP) do
        if not plr.Parent then espDrop(plr) end
    end

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= Players.LocalPlayer then
            local char = plr.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local d = ESP[plr]

            if CONFIG.esp and hrp and hum and hum.Health > 0 then
                d = d or espFor(plr)
                if d then
                    local head = cam:WorldToViewportPoint(hrp.Position + Vector3.new(0, 3, 0))
                    local feet = cam:WorldToViewportPoint(hrp.Position - Vector3.new(0, 3.5, 0))
                    local h = math.abs(head.Y - feet.Y)
                    local w = h / 1.5
                    d.box.Size = Vector2.new(w, h)
                    d.box.Position = Vector2.new(head.X - w / 2, head.Y)
                    d.box.Color = CONFIG.accent
                    d.box.Visible = true
                    d.name.Text = plr.Name
                    d.name.Color = C.text
                    d.name.Position = Vector2.new(head.X, head.Y - 30)
                    d.name.Visible = true
                    d.dist.Text = "(" .. math.floor((hrp.Position - camPos).Magnitude) .. ")"
                    d.dist.Color = C.dim
                    d.dist.Position = Vector2.new(head.X, head.Y - 16)
                    d.dist.Visible = true
                end
            elseif d then
                d.box.Visible = false d.name.Visible = false d.dist.Visible = false
            end
        end
    end
end)

gui.Destroying:Connect(function()
    for plr in pairs(ESP) do espDrop(plr) end
end)

--=====================================================================
-- rows
--=====================================================================
local function clearChildren(parent)
    for _, c in ipairs(parent:GetChildren()) do
        if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
    end
end

local function hoverFX(row, normal)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromOffset(3, 0)
    bar.Position = UDim2.new(0, 0, 0.5, 0)
    bar.BackgroundColor3 = CONFIG.accent
    bar.BorderSizePixel = 0
    bar.Parent = row
    Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

    row.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.14), { BackgroundColor3 = normal:Lerp(CONFIG.accent, 0.18) }):Play()
        bar.Size = UDim2.fromOffset(3, 18)
        bar.Position = UDim2.new(0, 0, 0.5, -9)
    end)
    row.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.14), { BackgroundColor3 = normal }):Play()
        bar.Size = UDim2.fromOffset(3, 0)
        bar.Position = UDim2.new(0, 0, 0.5, 0)
    end)
    return bar
end

local function addGameRow(g)
    local row = Instance.new("TextButton")
    row.Size = UDim2.new(1, -2, 0, 38)
    row.BackgroundColor3 = C.panel2
    row.BorderSizePixel = 0
    row.Text = ""
    row.AutoButtonColor = false
    row.Parent = sidebarScroll
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local img = Instance.new("ImageLabel")
    img.Size = UDim2.fromOffset(24, 24)
    img.Position = UDim2.new(0, 9, 0.5, -12)
    img.BackgroundColor3 = C.row
    img.BorderSizePixel = 0
    img.Image = gameIcon(g) or ""
    img.Parent = row
    Instance.new("UICorner", img).CornerRadius = UDim.new(0, 7)

    if not gameIcon(g) then
        local l = Instance.new("TextLabel")
        l.Size = UDim2.fromScale(1, 1)
        l.BackgroundTransparency = 1
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextColor3 = C.text
        l.Text = string.upper(string.sub(g.name, 1, 1))
        l.Parent = img
    end

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.new(1, -46, 1, 0)
    lbl.Position = UDim2.new(0, 40, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Font = Enum.Font.GothamMedium
    lbl.TextSize = 11
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextTruncate = Enum.TextTruncate.AtEnd
    lbl.TextColor3 = C.text
    lbl.Text = g.name
    lbl.Parent = row

    if g == currentGame then
        row.BackgroundColor3 = CONFIG.accent:Lerp(C.panel2, 0.55)
    end

    row.MouseEnter:Connect(function()
        if g ~= currentGame then
            TweenService:Create(row, TweenInfo.new(0.14), { BackgroundColor3 = C.row }):Play()
        end
    end)
    row.MouseLeave:Connect(function()
        if g ~= currentGame then
            TweenService:Create(row, TweenInfo.new(0.14), { BackgroundColor3 = C.panel2 }):Play()
        end
    end)
    row.MouseButton1Click:Connect(function() selectGame(g) end)
end

local function addScriptRow(name, opts)
    opts = opts or {}
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -2, 0, 38)
    row.BackgroundColor3 = C.panel2
    row.BorderSizePixel = 0
    row.Parent = list
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, opts.onCopy and -40 or -14, 1, 0)
    btn.Position = UDim2.new(0, 14, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 12
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = C.text
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.Text = name
    btn.AutoButtonColor = false
    btn.Parent = row

    hoverFX(row, C.panel2)
    btn.MouseEnter:Connect(function() row.MouseEnter:Wait() end)

    local hit = Instance.new("TextButton")
    hit.Size = UDim2.fromScale(1, 1)
    hit.BackgroundTransparency = 1
    hit.Text = ""
    hit.ZIndex = 2
    hit.Parent = row
    hit.MouseEnter:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.14), { BackgroundColor3 = C.panel2:Lerp(CONFIG.accent, 0.18) }):Play()
    end)
    hit.MouseLeave:Connect(function()
        TweenService:Create(row, TweenInfo.new(0.14), { BackgroundColor3 = C.panel2 }):Play()
    end)
    hit.MouseButton1Click:Connect(function() if opts.onClick then opts.onClick() end end)

    if opts.onCopy then
        local cp = Instance.new("TextButton")
        cp.Size = UDim2.fromOffset(26, 26)
        cp.Position = UDim2.new(1, -32, 0.5, -13)
        cp.BackgroundColor3 = C.row
        cp.BorderSizePixel = 0
        cp.Font = Enum.Font.GothamBold
        cp.TextSize = 12
        cp.TextColor3 = C.text
        cp.Text = "⧉"
        cp.ZIndex = 3
        cp.AutoButtonColor = false
        cp.Parent = row
        Instance.new("UICorner", cp).CornerRadius = UDim.new(0, 7)
        cp.MouseButton1Click:Connect(function() if opts.onCopy then opts.onCopy() end end)
    end
end

--=====================================================================
-- run
--=====================================================================
local function runScript(path, url)
    status("fetching " .. path .. "...", CONFIG.accent)
    local ok, body = pcall(httpGet, url or rawURL(path))
    if not ok or not body or body == "" then
        return status("http failed: " .. tostring(body), C.bad)
    end
    local loader = loadstring or load
    local chunk, err = loader(body, "@" .. path)
    if not chunk then return status("syntax error: " .. tostring(err), C.bad) end
    local ok2, err2 = pcall(chunk)
    if not ok2 then return status("runtime error: " .. tostring(err2), C.bad) end
    status("loaded " .. path, C.good)
end

--=====================================================================
-- render
--=====================================================================
render = function()
    clearChildren(sidebarScroll)
    clearChildren(list)

    local filter = string.lower(search.Text)

    local detected
    for _, g in ipairs(GAMES) do
        if g.place and g.place ~= 0 and (g.place == MY_PLACE or g.place == MY_UNIVERSE) then
            detected = g
            break
        end
    end
    if not currentGame then currentGame = detected or GAMES[1] end
    currentDir = currentDir or currentGame.dir

    for _, g in ipairs(GAMES) do
        if filter == "" or string.find(string.lower(g.name), filter, 1, true) then
            addGameRow(g)
        end
    end

    subLbl.Text = currentGame.name .. (currentGame == detected and "  ·  you are here" or "")
    subLbl.TextColor3 = currentGame == detected and C.good or C.dim

    local cached = listing[currentDir]
    if not cached then
        status("listing " .. currentDir .. "...", CONFIG.accent)
        local want = currentDir
        task.spawn(function()
            local data, err = apiList(want)
            if not data then
                status("github: " .. tostring(err) .. "  (does " .. want .. "/ exist?)", C.warn)
                return
            end
            local out = {}
            for _, f in ipairs(data) do
                if f.type == "file" and f.name:match("%.luau?$") then
                    table.insert(out, { name = f.name, path = f.path, download = f.download_url })
                elseif f.type == "dir" then
                    table.insert(out, { name = f.name, path = f.path, isFolder = true })
                end
            end
            table.sort(out, function(a, b)
                if a.isFolder ~= b.isFolder then return a.isFolder end
                return string.lower(a.name) < string.lower(b.name)
            end)
            listing[want] = out
            if currentDir == want then render() end
        end)
        return
    end

    if #cached == 0 then
        addScriptRow("folder is empty", {})
    end

    for _, e in ipairs(cached) do
        if filter == "" or string.find(string.lower(e.name), filter, 1, true) then
            if e.isFolder then
                addScriptRow("▸ " .. e.name, {
                    onClick = function() currentDir = e.path render() end,
                })
            else
                addScriptRow(e.name, {
                    onClick = function() runScript(e.path, e.download) end,
                    onCopy = function()
                        if setclipboard then
                            setclipboard(string.format('loadstring(game:HttpGet("%s"))()',
                                e.download or rawURL(e.path)))
                            status("copied " .. e.name, CONFIG.accent)
                        else
                            status("no setclipboard")
                        end
                    end,
                })
            end
        end
    end

    status(#cached .. " script" .. (#cached == 1 and "" or "s") .. " in " .. currentDir)
end

selectGame = function(g)
    currentGame = g
    currentDir = g.dir
    search.Text = ""
    render()
end

--=====================================================================
-- boot
--=====================================================================
search:GetPropertyChangedSignal("Text"):Connect(function() render() end)

for _, g in ipairs(GAMES) do
    if g.place and g.place ~= 0 and (g.place == MY_PLACE or g.place == MY_UNIVERSE) then
        currentGame = g
        currentDir = g.dir
        break
    end
end

render()

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.toggle then win.Visible = not win.Visible end
end)
