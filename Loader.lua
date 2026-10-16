--[[
    AERIZ LOADER  -  github script picker

    Setup
      1. Save this as loader.lua in your repo root
      2. Put your scripts in /scripts  (any .lua files)
      3. Edit CONFIG below
      4. Run:
         loadstring(game:HttpGet("https://raw.githubusercontent.com/USER/REPO/main/loader.lua"))()
]]

local CONFIG = {
    user   = "hxzy2k",
    repo   = "Aeriz-Hub",
    branch = "main",
    dir    = "scripts",        -- folder your scripts live in
    title  = "Aeriz Loader",
    toggle = Enum.KeyCode.RightShift,
    accent = Color3.fromRGB(124, 92, 255),
}

--=====================================================================
local Players          = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local HttpService      = game:GetService("HttpService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer

local RAW = "https://raw.githubusercontent.com/%s/%s/%s/%s"
local API = "https://api.github.com/repos/%s/%s/contents/%s?ref=%s"

local listing = {}          -- cache, so we do not hammer the api
local lastGood = nil        -- last successful path

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
        local ok, res = pcall(request, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and res.Body then return res.Body end
    end
    if syn and syn.request then
        local ok, res = pcall(syn.request, { Url = url, Method = "GET" })
        if ok and type(res) == "table" and res.Body then return res.Body end
    end
    return game:HttpGet(url)
end

local function rawURL(path)
    return string.format(RAW, CONFIG.user, CONFIG.repo, CONFIG.branch, urlEncode(path))
end

--=====================================================================
-- ui
--=====================================================================
local function guiParent()
    if gethui then
        local ok, hui = pcall(gethui)
        if ok and hui then return hui end
    end
    return game:GetService("CoreGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "AerizLoader"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = guiParent()

local win = Instance.new("Frame")
win.Size = UDim2.fromOffset(380, 460)
win.Position = UDim2.new(0.5, -190, 0.5, -230)
win.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
win.BorderSizePixel = 0
win.Parent = gui
Instance.new("UICorner", win).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", win)
stroke.Color = Color3.fromRGB(48, 48, 58)
stroke.Thickness = 1

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundColor3 = Color3.fromRGB(33, 33, 41)
header.BorderSizePixel = 0
header.Parent = win
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local headerMask = Instance.new("Frame")
headerMask.Size = UDim2.new(1, 0, 0, 12)
headerMask.Position = UDim2.new(0, 0, 1, -12)
headerMask.BackgroundColor3 = header.BackgroundColor3
headerMask.BorderSizePixel = 0
headerMask.Parent = header

local dot = Instance.new("Frame")
dot.Size = UDim2.fromOffset(8, 8)
dot.Position = UDim2.new(0, 14, 0.5, -4)
dot.BackgroundColor3 = CONFIG.accent
dot.BorderSizePixel = 0
dot.Parent = header
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local titleLbl = Instance.new("TextLabel")
titleLbl.BackgroundTransparency = 1
titleLbl.Position = UDim2.new(0, 30, 0, 0)
titleLbl.Size = UDim2.new(1, -80, 1, 0)
titleLbl.Font = Enum.Font.GothamBold
titleLbl.TextSize = 14
titleLbl.TextXAlignment = Enum.TextXAlignment.Left
titleLbl.TextColor3 = Color3.fromRGB(235, 235, 245)
titleLbl.Text = CONFIG.title
titleLbl.Parent = header

local function headerBtn(text, xOff, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.fromOffset(24, 24)
    b.Position = UDim2.new(1, xOff, 0.5, -12)
    b.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
    b.BorderSizePixel = 0
    b.Font = Enum.Font.GothamBold
    b.TextSize = 13
    b.TextColor3 = Color3.fromRGB(220, 220, 235)
    b.Text = text
    b.AutoButtonColor = false
    b.Parent = header
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = CONFIG.accent }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(45, 45, 55) }):Play()
    end)
    b.MouseButton1Click:Connect(cb)
    return b
end

headerBtn("–", -68, function() win.Visible = false end)
headerBtn("×", -38, function() gui:Destroy() end)

local search = Instance.new("TextBox")
search.Size = UDim2.new(1, -24, 0, 32)
search.Position = UDim2.new(0, 12, 0, 54)
search.BackgroundColor3 = Color3.fromRGB(33, 33, 41)
search.BorderSizePixel = 0
search.Font = Enum.Font.Gotham
search.TextSize = 13
search.TextColor3 = Color3.fromRGB(225, 225, 235)
search.PlaceholderText = "search..."
search.PlaceholderColor3 = Color3.fromRGB(110, 110, 125)
search.Text = ""
search.ClearTextOnFocus = false
search.Parent = win
Instance.new("UICorner", search).CornerRadius = UDim.new(0, 6)
local searchPad = Instance.new("UIPadding", search)
searchPad.PaddingLeft = UDim.new(0, 10)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -24, 1, -140)
list.Position = UDim2.new(0, 12, 0, 96)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.ScrollBarImageColor3 = Color3.fromRGB(70, 70, 85)
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = win

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = list

local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, -24, 0, 30)
statusBar.Position = UDim2.new(0, 12, 1, -42)
statusBar.BackgroundColor3 = Color3.fromRGB(33, 33, 41)
statusBar.BorderSizePixel = 0
statusBar.Parent = win
Instance.new("UICorner", statusBar).CornerRadius = UDim.new(0, 6)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -20, 1, 0)
statusLbl.Position = UDim2.new(0, 10, 0, 0)
statusLbl.BackgroundTransparency = 1
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 12
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.TextTruncate = Enum.TextTruncate.AtEnd
statusLbl.TextColor3 = Color3.fromRGB(160, 160, 175)
statusLbl.Text = "ready"
statusLbl.Parent = statusBar

local function status(txt, color)
    statusLbl.Text = tostring(txt)
    statusLbl.TextColor3 = color or Color3.fromRGB(160, 160, 175)
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
-- rows
--=====================================================================
local function clearList()
    for _, c in ipairs(list:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end
end

local function addRow(name, isFolder, onOpen, onCopy)
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1, -6, 0, 38)
    row.BackgroundColor3 = Color3.fromRGB(33, 33, 41)
    row.BorderSizePixel = 0
    row.Parent = list
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, onCopy and -42 or -12, 1, 0)
    btn.Position = UDim2.new(0, 6, 0, 0)
    btn.BackgroundTransparency = 1
    btn.Font = Enum.Font.GothamMedium
    btn.TextSize = 13
    btn.TextXAlignment = Enum.TextXAlignment.Left
    btn.TextColor3 = Color3.fromRGB(225, 225, 235)
    btn.TextTruncate = Enum.TextTruncate.AtEnd
    btn.Text = (isFolder and "> " or "") .. name
    btn.AutoButtonColor = false
    btn.Parent = row

    local hover = Instance.new("Frame")
    hover.Size = UDim2.fromOffset(3, 16)
    hover.Position = UDim2.new(0, 0, 0.5, -8)
    hover.BackgroundColor3 = CONFIG.accent
    hover.BorderSizePixel = 0
    hover.BackgroundTransparency = 1
    hover.Parent = row
    Instance.new("UICorner", hover).CornerRadius = UDim.new(1, 0)

    btn.MouseEnter:Connect(function()
        hover.BackgroundTransparency = 0
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(42, 42, 52) }):Play()
    end)
    btn.MouseLeave:Connect(function()
        hover.BackgroundTransparency = 1
        TweenService:Create(row, TweenInfo.new(0.12), { BackgroundColor3 = Color3.fromRGB(33, 33, 41) }):Play()
    end)
    btn.MouseButton1Click:Connect(onOpen)

    if onCopy then
        local cp = Instance.new("TextButton")
        cp.Size = UDim2.fromOffset(26, 26)
        cp.Position = UDim2.new(1, -32, 0.5, -13)
        cp.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
        cp.BorderSizePixel = 0
        cp.Font = Enum.Font.GothamBold
        cp.TextSize = 12
        cp.TextColor3 = Color3.fromRGB(200, 200, 215)
        cp.Text = "⧉"
        cp.AutoButtonColor = false
        cp.Parent = row
        Instance.new("UICorner", cp).CornerRadius = UDim.new(0, 6)
        cp.MouseButton1Click:Connect(onCopy)
    end

    return row
end

--=====================================================================
-- running
--=====================================================================
local function runScript(path, url)
    status("fetching " .. path .. "...", CONFIG.accent)
    local ok, body = pcall(httpGet, url or rawURL(path))
    if not ok or not body or body == "" then
        return status("http failed: " .. tostring(body), Color3.fromRGB(240, 90, 90))
    end

    local loader = loadstring or load
    local chunk, err = loader(body, "@" .. path)
    if not chunk then
        return status("syntax error: " .. tostring(err), Color3.fromRGB(240, 90, 90))
    end

    local ok2, err2 = pcall(chunk)
    if not ok2 then
        return status("runtime error: " .. tostring(err2), Color3.fromRGB(240, 90, 90))
    end

    lastGood = path
    status("loaded " .. path, Color3.fromRGB(90, 220, 140))
end

--=====================================================================
-- listing
--=====================================================================
local function apiList(path)
    local url = string.format(API, CONFIG.user, CONFIG.repo, urlEncode(path), CONFIG.branch)
    local ok, body = pcall(httpGet, url)
    if not ok or not body then return nil, "request failed" end
    local ok2, data = pcall(function() return HttpService:JSONDecode(body) end)
    if not ok2 or type(data) ~= "table" then return nil, "bad response" end
    if data.message then return nil, data.message end
    return data
end

local currentDir = CONFIG.dir
local render

local function renderList()
    clearList()
    local filter = string.lower(search.Text)
    local entries = listing[currentDir]
    if not entries then return end

    local shown = 0
    for _, e in ipairs(entries) do
        if filter == "" or string.find(string.lower(e.name), filter, 1, true) then
            shown = shown + 1
            if e.isFolder then
                addRow(e.name, true, function()
                    currentDir = e.path
                    status("opening " .. e.path)
                    render()
                end)
            else
                addRow(e.name, false,
                    function() runScript(e.path, e.download) end,
                    function()
                        if setclipboard then
                            setclipboard(string.format(
                                'loadstring(game:HttpGet("%s"))()',
                                e.download or rawURL(e.path)))
                            status("copied loadstring for " .. e.name, CONFIG.accent)
                        else
                            status("no setclipboard in this executor")
                        end
                    end)
            end
        end
    end

    if currentDir ~= CONFIG.dir then
        local back = addRow("..  (back)", true, function()
            currentDir = currentDir:match("^(.*)/") or CONFIG.dir
            if #currentDir < #CONFIG.dir then currentDir = CONFIG.dir end
            render()
        end)
        back.LayoutOrder = -1
    end

    if shown == 0 then
        addRow(filter == "" and "folder is empty" or "no matches", false, function() end)
    end
end

function render(force)
    if listing[currentDir] and not force then return renderList() end

    status("listing " .. currentDir .. "...", CONFIG.accent)
    task.spawn(function()
        local data, err = apiList(currentDir)
        if not data then
            status("api: " .. tostring(err) .. "  (add manifest.json?)", Color3.fromRGB(240, 190, 90))
            return
        end

        local out = {}
        for _, f in ipairs(data) do
            if f.type == "dir" then
                table.insert(out, { name = f.name, path = f.path, isFolder = true })
            elseif f.type == "file" and f.name:match("%.luau?$") then
                table.insert(out, { name = f.name, path = f.path, download = f.download_url })
            end
        end
        table.sort(out, function(a, b)
            if a.isFolder ~= b.isFolder then return a.isFolder end
            return string.lower(a.name) < string.lower(b.name)
        end)

        listing[currentDir] = out
        status(#out .. " entries in " .. currentDir)
        renderList()
    end)
end

--=====================================================================
-- init
--=====================================================================
search:GetPropertyChangedSignal("Text"):Connect(function() renderList() end)

task.spawn(function()
    task.wait(0.2)
    render()
end)

UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == CONFIG.toggle then
        win.Visible = not win.Visible
    end
end)

status("running  -  " .. CONFIG.user .. "/" .. CONFIG.repo)
