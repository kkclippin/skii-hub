--[[
    Skii UI - dark glass menu library (sidebar categories, pill tabs, cards)

    local UI = loadstring(...)()            -- or paste this file above your script
    local Window = UI:CreateWindow({ Title = "SKII HUB", Subtitle = "PRACTICAL PAID",
                                     User = "samskii", UserSub = "Lifetime", Key = Enum.KeyCode.RightShift })
    local Combat = Window:Category({ Name = "Combat", Icon = "crosshair" })
    local Aimbot = Combat:Page({ Name = "Aimbot", Icon = "target" })
    local Targets = Aimbot:Tab({ Name = "Targets", Icon = "target" })
    local Card = Targets:Card({ Title = "Target Selection", Desc = "Choose which targets assistance follows",
                                Side = "Left", Toggle = true, Default = true, Flag = "TargetSel", Callback = print })
    Card:Toggle({ Name = "Visible Targets", Default = true, Flag = "Visible", Callback = print })
    Card:Slider({ Name = "Detection Radius", Min = 0, Max = 100, Default = 20, Step = 1, Suffix = "%", ShowValue = true })
    Card:Dropdown({ Name = "Target Priority", Items = { "Automatic", "Nearest" }, Default = "Automatic" })
    Card:Keybind({ Name = "Activation Key", Default = nil, Callback = function(key) end })
    Card:Button({ Name = "Do Thing", Callback = function() end })

    UI.Flags[flag] holds every value; UI:SetFlag(flag, value) changes one (and its control).
    UI:GetConfig() / UI:LoadConfig(json) for configs. UI:Notify(title, text, seconds).
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local UI = { Flags = {}, Setters = {}, Unloaded = false, _conns = {} }

--// ===== theme =====
local T = {
    Window   = Color3.fromRGB(24, 25, 29),   WindowA = 0.06,
    Side     = Color3.fromRGB(31, 32, 37),
    Card     = Color3.fromRGB(30, 31, 36),
    Card2    = Color3.fromRGB(37, 38, 44),
    Field    = Color3.fromRGB(22, 23, 27),
    Stroke   = Color3.fromRGB(58, 60, 68),
    StrokeLo = Color3.fromRGB(44, 46, 53),
    Text     = Color3.fromRGB(238, 239, 243),
    Sub      = Color3.fromRGB(150, 153, 163),
    Dim      = Color3.fromRGB(98, 101, 111),
    White    = Color3.fromRGB(248, 248, 250),
    OnTrack  = Color3.fromRGB(196, 198, 204),
    OffTrack = Color3.fromRGB(46, 47, 54),
    -- glass: faint white outlines and see-through panels, so the blurred game shows through
    Line     = Color3.fromRGB(255, 255, 255),
    LineA    = 0.88,   -- cards, fields, sidebar items
    LineB    = 0.80,   -- stronger edges (notifications, dropdown lists, avatar)
    LineW    = 0.76,   -- the window border
    CardA    = 0.22,   -- card see-through
    SideA    = 0.18,   -- sidebar blocks see-through
}
T.WindowA = 0.16
local function font(weight)
    return Font.new("rbxasset://fonts/families/GothamSSm.json", weight or Enum.FontWeight.Regular)
end
local F_REG, F_MED, F_SEMI, F_BOLD = font(Enum.FontWeight.Regular), font(Enum.FontWeight.Medium), font(Enum.FontWeight.SemiBold), font(Enum.FontWeight.Bold)

--// ===== helpers =====
local function new(class, props, children)
    local o = Instance.new(class)
    for k, v in pairs(props or {}) do
        if k ~= "Parent" then o[k] = v end
    end
    for _, c in ipairs(children or {}) do c.Parent = o end
    if props and props.Parent then o.Parent = props.Parent end
    return o
end
local function corner(r) return new("UICorner", { CornerRadius = UDim.new(0, r) }) end
local function stroke(c, t, th) return new("UIStroke", { Color = c or T.Stroke, Transparency = t or 0, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }) end
local function pad(l, t, r, b) return new("UIPadding", { PaddingLeft = UDim.new(0, l), PaddingTop = UDim.new(0, t or l), PaddingRight = UDim.new(0, r or l), PaddingBottom = UDim.new(0, b or t or l) }) end
local function list(gap, dir, align)
    return new("UIListLayout", { Padding = UDim.new(0, gap or 0), FillDirection = dir or Enum.FillDirection.Vertical,
        SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = align or Enum.HorizontalAlignment.Left })
end
local function tween(o, props, t, style)
    local tw = TweenService:Create(o, TweenInfo.new(t or 0.16, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props)
    tw:Play()
    return tw
end
local function text(props)
    props.BackgroundTransparency = 1
    props.FontFace = props.FontFace or F_REG
    props.TextColor3 = props.TextColor3 or T.Text
    props.TextSize = props.TextSize or 13
    props.TextXAlignment = props.TextXAlignment or Enum.TextXAlignment.Left
    props.TextYAlignment = props.TextYAlignment or Enum.TextYAlignment.Center
    return new("TextLabel", props)
end
local function conn(sig, fn)
    local c = sig:Connect(fn)
    table.insert(UI._conns, c)
    return c
end
local order = 0
local function nextOrder() order += 1 return order end

--// ===== icons (drawn from frames so they never depend on asset ids) =====
local Icons = {}
function Icons.target(parent, size, color)
    local s = size or 14
    local h = new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, Parent = parent })
    new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Parent = h }, { corner(s), stroke(color or T.Text, 0, 1.4) })
    new("Frame", { Size = UDim2.fromOffset(math.max(4, s * 0.32), math.max(4, s * 0.32)), AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), BackgroundColor3 = color or T.Text, Parent = h }, { corner(s) })
    return h
end
function Icons.crosshair(parent, size, color)
    local s = size or 14
    local c = color or T.Text
    local h = new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, Parent = parent })
    new("Frame", { Size = UDim2.fromScale(0.62, 0.62), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        BackgroundTransparency = 1, Parent = h }, { corner(s), stroke(c, 0, 1.3) })
    new("Frame", { Size = UDim2.new(0, 1.4, 1, 0), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = c, BorderSizePixel = 0, Parent = h })
    new("Frame", { Size = UDim2.new(1, 0, 0, 1.4), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), BackgroundColor3 = c, BorderSizePixel = 0, Parent = h })
    return h
end
function Icons.glyph(parent, size, color, g)
    return text({ Size = UDim2.fromOffset(size or 14, size or 14), Text = g, TextSize = (size or 14), FontFace = F_BOLD,
        TextColor3 = color or T.Text, TextXAlignment = Enum.TextXAlignment.Center, Parent = parent })
end
-- Line icons: segments in 0..1 coordinates, drawn as thin rotated frames.
-- Roblox fonts have no glyphs for most symbols (they render as boxes), and
-- asset ids can be deleted, so these are built from frames.
local LINES = {
    cursor  = { {0.22,0.1,0.22,0.86}, {0.22,0.1,0.82,0.6}, {0.22,0.86,0.46,0.64}, {0.46,0.64,0.82,0.6} },
    filter  = { {0.1,0.2,0.9,0.2}, {0.1,0.2,0.42,0.56}, {0.9,0.2,0.58,0.56}, {0.42,0.56,0.42,0.88}, {0.58,0.56,0.58,0.76}, {0.42,0.88,0.58,0.76} },
    monitor = { {0.08,0.18,0.92,0.18}, {0.92,0.18,0.92,0.68}, {0.92,0.68,0.08,0.68}, {0.08,0.68,0.08,0.18}, {0.5,0.68,0.5,0.86}, {0.3,0.88,0.7,0.88} },
    shield  = { {0.5,0.06,0.88,0.2}, {0.88,0.2,0.82,0.6}, {0.82,0.6,0.5,0.94}, {0.5,0.94,0.18,0.6}, {0.18,0.6,0.12,0.2}, {0.12,0.2,0.5,0.06},
                {0.5,0.34,0.5,0.66}, {0.34,0.5,0.66,0.5} },
    bolt    = { {0.62,0.04,0.3,0.54}, {0.3,0.54,0.6,0.5}, {0.6,0.5,0.38,0.96} },
    eye     = { {0.06,0.5,0.3,0.26}, {0.3,0.26,0.7,0.26}, {0.7,0.26,0.94,0.5}, {0.94,0.5,0.7,0.74}, {0.7,0.74,0.3,0.74}, {0.3,0.74,0.06,0.5},
                {0.42,0.42,0.58,0.58}, {0.42,0.58,0.58,0.42} },
    star    = { {0.5,0.02,0.6,0.4}, {0.6,0.4,0.98,0.5}, {0.98,0.5,0.6,0.6}, {0.6,0.6,0.5,0.98}, {0.5,0.98,0.4,0.6}, {0.4,0.6,0.02,0.5},
                {0.02,0.5,0.4,0.4}, {0.4,0.4,0.5,0.02} },
    chevron = { {0.22,0.36,0.5,0.64}, {0.5,0.64,0.78,0.36} },
    arrow   = { {0.25,0.75,0.75,0.25}, {0.38,0.25,0.75,0.25}, {0.75,0.25,0.75,0.62} },
    user    = { {0.3,0.3,0.5,0.12}, {0.5,0.12,0.7,0.3}, {0.7,0.3,0.5,0.48}, {0.5,0.48,0.3,0.3}, {0.15,0.9,0.3,0.62}, {0.3,0.62,0.7,0.62}, {0.7,0.62,0.85,0.9} },
}
local function drawLines(parent, size, color, segs, thick)
    local s = size or 14
    local th = thick or math.max(1.3, s / 10)
    local h = new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundTransparency = 1, Parent = parent })
    for _, g in ipairs(segs) do
        local x1, y1, x2, y2 = g[1] * s, g[2] * s, g[3] * s, g[4] * s
        local dx, dy = x2 - x1, y2 - y1
        new("Frame", { Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + th, th), AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2), Rotation = math.deg(math.atan2(dy, dx)),
            BackgroundColor3 = color or T.Text, BorderSizePixel = 0, Parent = h }, { corner(th) })
    end
    return h
end
local function icon(name, parent, size, color)
    if Icons[name] then return Icons[name](parent, size, color) end
    if LINES[name] then return drawLines(parent, size, color, LINES[name]) end
    if name == "gear" then return Icons.glyph(parent, size, color, "⚙") end
    return Icons.target(parent, size, color)
end

--// ===== root gui =====
local function guiParent()
    local ok, h = pcall(function() return gethui and gethui() end)
    if ok and h then return h end
    local ok2, cg = pcall(function() return game:GetService("CoreGui") end)
    if ok2 and cg and pcall(function() local _ = cg.Name end) then
        local okp = pcall(function() local t = Instance.new("Folder") t.Parent = cg t:Destroy() end)
        if okp then return cg end
    end
    return Players.LocalPlayer:WaitForChild("PlayerGui")
end

--// ===== notifications =====
local notifyHolder
function UI:Notify(title, body, seconds)
    if not notifyHolder or not notifyHolder.Parent then return end
    local n = new("Frame", { Size = UDim2.fromOffset(280, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card,
        BackgroundTransparency = 0.05, Parent = notifyHolder }, { corner(12), stroke(T.Line, T.LineB), pad(12, 10), list(2) })
    text({ Size = UDim2.new(1, 0, 0, 16), Text = tostring(title or ""), FontFace = F_BOLD, TextSize = 13, Parent = n, LayoutOrder = 1 })
    text({ Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = tostring(body or ""), TextColor3 = T.Sub,
        TextWrapped = true, TextSize = 12, Parent = n, LayoutOrder = 2 })
    task.delay(seconds or 4, function() if n.Parent then n:Destroy() end end)
end

--// ===== flags / config =====
function UI:SetFlag(flag, value)
    if self.Setters[flag] then self.Setters[flag](value) else self.Flags[flag] = value end
end
-- Flags starting with "_" belong to the menu itself (config name box, menu
-- key, UI scale...) and are never written into a config.
function UI:GetConfig()
    local out = {}
    for k, v in pairs(self.Flags) do
        if type(k) == "string" and k:sub(1, 1) == "_" then continue end
        if typeof(v) == "EnumItem" then out[k] = { __enum = tostring(v) }
        elseif type(v) ~= "function" and typeof(v) ~= "Instance" then out[k] = v end
    end
    return HttpService:JSONEncode(out)
end
function UI:LoadConfig(json)
    local ok, data = pcall(function() return HttpService:JSONDecode(json) end)
    if not ok or type(data) ~= "table" then return false end
    for k, v in pairs(data) do
        if type(k) == "string" and k:sub(1, 1) == "_" then continue end
        if type(v) == "table" and v.__enum then
            local name = tostring(v.__enum):match("KeyCode%.(.+)$")
            v = name and Enum.KeyCode[name] or nil
        end
        pcall(function() self:SetFlag(k, v) end)
    end
    return true
end

--// ===== config files (executor file functions; everything degrades safely) =====
UI.Folder = "SkiiUI"
local function fsOk()
    return type(writefile) == "function" and type(readfile) == "function" and type(isfile) == "function"
end
local function ensureFolder()
    if type(makefolder) ~= "function" or type(isfolder) ~= "function" then return end
    local path = ""
    for part in tostring(UI.Folder):gmatch("[^/]+") do
        path = path == "" and part or (path .. "/" .. part)
        if not isfolder(path) then pcall(makefolder, path) end
    end
end
local function safeName(name)
    return (tostring(name or ""):gsub("[^%w%s%-_]", ""):gsub("^%s+", ""):gsub("%s+$", ""):sub(1, 40))
end
local function configPath(name) return UI.Folder .. "/" .. safeName(name) .. ".json" end

function UI:SaveConfig(name)
    name = safeName(name)
    if name == "" then return false, "type a config name first" end
    if not fsOk() then return false, "your executor can't save files" end
    ensureFolder()
    local ok, err = pcall(writefile, configPath(name), self:GetConfig())
    return ok, ok and nil or tostring(err)
end
function UI:LoadConfigFile(name)
    if not fsOk() then return false, "your executor can't read files" end
    local path = configPath(name)
    if not isfile(path) then return false, "no config called " .. safeName(name) end
    local ok, raw = pcall(readfile, path)
    if not ok then return false, "couldn't read it" end
    return self:LoadConfig(raw), nil
end
function UI:DeleteConfig(name)
    if type(delfile) ~= "function" then return false, "your executor can't delete files" end
    local path = configPath(name)
    if fsOk() and isfile(path) then pcall(delfile, path) return true end
    return false, "no config called " .. safeName(name)
end
function UI:ListConfigs()
    local out = {}
    if type(listfiles) ~= "function" then return out end
    ensureFolder()
    local ok, files = pcall(listfiles, UI.Folder)
    for _, f in ipairs(ok and files or {}) do
        local n = tostring(f):gsub("\\", "/"):match("([^/]+)%.json$")
        if n then table.insert(out, n) end
    end
    table.sort(out)
    return out
end
function UI:SetAutoload(name)
    if not fsOk() then return false, "your executor can't save files" end
    ensureFolder()
    return pcall(writefile, UI.Folder .. "/_autoload.txt", safeName(name or ""))
end
function UI:GetAutoload()
    if not fsOk() or not isfile(UI.Folder .. "/_autoload.txt") then return nil end
    local ok, n = pcall(readfile, UI.Folder .. "/_autoload.txt")
    return ok and n ~= "" and n or nil
end
function UI:LoadAutoload()
    local n = self:GetAutoload()
    if n then
        local ok = self:LoadConfigFile(n)
        if ok then self:Notify("Configs", "autoloaded " .. n, 4) end
        return ok
    end
    return false
end

--// ===== cloud configs (6 character share codes on the Skii Hub server) =====
UI.CloudUrl = "https://skiihubaltss-production.up.railway.app/api/configs"
UI.CloudScript = "skii-ui"
local function httpReq(method, url, payload)
    local req = (type(http_request) == "function" and http_request) or (type(request) == "function" and request)
        or (syn and syn.request) or (fluxus and fluxus.request)
    if req then
        local ok, res = pcall(req, { Url = url, Method = method, Headers = { ["Content-Type"] = "application/json" },
            Body = payload and HttpService:JSONEncode(payload) or nil })
        if not ok or type(res) ~= "table" then return nil, "request failed" end
        local good, data = pcall(function() return HttpService:JSONDecode(res.Body or "") end)
        if not good or type(data) ~= "table" then return nil, "bad reply (" .. tostring(res.StatusCode) .. ")" end
        if (tonumber(res.StatusCode) or 200) >= 400 then return nil, tostring(data.error or res.StatusCode) end
        return data
    end
    if method ~= "GET" then return nil, "your executor can't send web requests" end
    local ok, raw = pcall(function() return game:HttpGet(url) end)
    if not ok then return nil, "request failed" end
    local good, data = pcall(function() return HttpService:JSONDecode(raw) end)
    return good and type(data) == "table" and data or nil, good and nil or "bad reply"
end
function UI:ShareConfig(name)
    local lp = Players.LocalPlayer
    local data, err = httpReq("POST", self.CloudUrl, { name = name or ((lp and lp.Name or "player") .. "'s config"),
        author = lp and lp.Name or "anonymous", script = self.CloudScript, config = self:GetConfig() })
    if not data or not data.code then return nil, err end
    pcall(function() setclipboard(data.code) end)
    return data.code
end
function UI:LoadCloud(code)
    code = tostring(code or ""):upper():gsub("%s", "")
    if #code ~= 6 then return false, "share codes are 6 characters" end
    local data, err = httpReq("GET", self.CloudUrl .. "/" .. code)
    if not data or type(data.config) ~= "string" then return false, err end
    return self:LoadConfig(data.config), nil, data
end
function UI:FeaturedConfigs()
    local data = httpReq("GET", self.CloudUrl .. "/featured")
    return (data and data.configs) or {}
end

--// ===== controls (shared by every card) =====
local Card = {}
Card.__index = Card

local function row(card, height)
    return new("Frame", { Size = UDim2.new(1, 0, 0, height or 30), BackgroundTransparency = 1, LayoutOrder = nextOrder(), Parent = card._body })
end

-- The switch from the reference: light pill + white knob with a tick when on,
-- dark pill + grey knob with a dash when off.
local function makeSwitch(parent, default, onChange)
    local sw = new("TextButton", { Size = UDim2.fromOffset(36, 20), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = T.OffTrack, AutoButtonColor = false, Text = "", Parent = parent }, { corner(10), stroke(T.Line, T.LineA) })
    local knob = new("Frame", { Size = UDim2.fromOffset(16, 16), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        BackgroundColor3 = T.Dim, Parent = sw }, { corner(8) })
    local mark = text({ Size = UDim2.fromScale(1, 1), Text = "", TextSize = 11, FontFace = F_BOLD, TextColor3 = T.Field,
        TextXAlignment = Enum.TextXAlignment.Center, Parent = knob })
    local value = nil
    local function set(v, instant)
        v = v and true or false
        if v == value then return end
        value = v
        local t = instant and 0 or 0.16
        tween(sw, { BackgroundColor3 = v and T.OnTrack or T.OffTrack }, t)
        tween(knob, { Position = v and UDim2.new(1, -18, 0.5, 0) or UDim2.new(0, 2, 0.5, 0), BackgroundColor3 = v and T.White or T.Dim }, t)
        mark.Text = v and "✓" or "–"
        mark.TextColor3 = v and Color3.fromRGB(40, 41, 46) or Color3.fromRGB(34, 35, 40)
        if not instant then onChange(v) end
    end
    conn(sw.MouseButton1Click, function() set(not value) end)
    set(default, true)
    return set, function() return value end
end

function Card:Toggle(o)
    local r = row(self, 30)
    text({ Size = UDim2.new(1, -50, 1, 0), Text = o.Name or "Toggle", TextSize = 13, FontFace = F_MED, Parent = r })
    local flag = o.Flag or (self._title .. "/" .. (o.Name or "Toggle"))
    local cb = o.Callback or function() end
    local set = makeSwitch(r, o.Default, function(v) UI.Flags[flag] = v; task.spawn(cb, v) end)
    UI.Flags[flag] = o.Default and true or false
    UI.Setters[flag] = function(v) local was = UI.Flags[flag]; set(v, true); UI.Flags[flag] = v and true or false; if was ~= UI.Flags[flag] then task.spawn(cb, UI.Flags[flag]) end end
    if o.Default then task.spawn(cb, true) end
    return { Set = function(_, v) UI.Setters[flag](v) end, Get = function() return UI.Flags[flag] end }
end

function Card:Slider(o)
    local min, max, step = o.Min or 0, o.Max or 100, o.Step or 1
    local r = row(self, 46)
    text({ Size = UDim2.new(1, -60, 0, 18), Text = o.Name or "Slider", TextSize = 13, FontFace = F_MED, Parent = r })
    local valueLabel = text({ Size = UDim2.new(0, 60, 0, 18), Position = UDim2.new(1, -60, 0, 0), Text = "", TextSize = 12,
        FontFace = F_SEMI, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Right, Parent = r })
    local function circleBtn(sym, x)
        local b = new("TextButton", { Size = UDim2.fromOffset(14, 14), Position = x, AnchorPoint = Vector2.new(0, 0.5),
            BackgroundColor3 = T.Card2, AutoButtonColor = false, Text = sym, TextSize = 12, FontFace = F_BOLD, TextColor3 = T.Sub, Parent = r },
            { corner(7), stroke(T.Line, T.LineA) })
        return b
    end
    local minus = circleBtn("−", UDim2.new(0, 0, 0, 33))
    local plus = circleBtn("+", UDim2.new(1, -14, 0, 33))
    local track = new("TextButton", { Size = UDim2.new(1, -52, 0, 4), Position = UDim2.new(0, 22, 0, 31), BackgroundColor3 = T.OffTrack,
        AutoButtonColor = false, Text = "", Parent = r }, { corner(2) })
    local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = T.White, BorderSizePixel = 0, Parent = track }, { corner(2) })
    local knob = new("Frame", { Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5),
        BackgroundColor3 = T.White, Parent = track }, { corner(5) })
    local flag = o.Flag or (self._title .. "/" .. (o.Name or "Slider"))
    local cb = o.Callback or function() end
    local function fmt(v)
        local decimals = math.max(0, math.ceil(-math.log10(step) - 1e-9))
        return string.format("%." .. decimals .. "f", v) .. (o.Suffix or "")
    end
    local value
    local function set(v, silent)
        v = math.clamp(math.floor((v - min) / step + 0.5) * step + min, min, max)
        if v == value then return end
        value = v
        UI.Flags[flag] = v
        local a = (max > min) and (v - min) / (max - min) or 0
        fill.Size = UDim2.fromScale(a, 1)
        knob.Position = UDim2.fromScale(a, 0.5)
        valueLabel.Text = (o.ShowValue ~= false) and fmt(v) or ""
        if not silent then task.spawn(cb, v) end
    end
    local dragging = false
    local function fromX(x)
        local a = math.clamp((x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1), 0, 1)
        set(min + (max - min) * a)
    end
    conn(track.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            fromX(i.Position.X)
        end
    end)
    conn(UserInputService.InputChanged, function(i)
        if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
    end)
    conn(UserInputService.InputEnded, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
    conn(minus.MouseButton1Click, function() set(value - step) end)
    conn(plus.MouseButton1Click, function() set(value + step) end)
    set(o.Default or min, true)
    UI.Setters[flag] = function(v) set(tonumber(v) or min) end
    task.spawn(cb, value)
    return { Set = function(_, v) set(v) end, Get = function() return value end }
end

function Card:Dropdown(o)
    local items = o.Items or {}
    local r = row(self, 30)
    text({ Size = UDim2.new(1, -120, 1, 0), Text = o.Name or "Dropdown", TextSize = 13, FontFace = F_MED, Parent = r })
    local box = new("TextButton", { Size = UDim2.fromOffset(104, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = T.Field, AutoButtonColor = false, Text = "", Parent = r }, { corner(7), stroke(T.Line, T.LineA) })
    local label = text({ Size = UDim2.new(1, -26, 1, 0), Position = UDim2.fromOffset(9, 0), Text = "", TextSize = 12, FontFace = F_MED,
        TextTruncate = Enum.TextTruncate.AtEnd, Parent = box })
    local chev = icon("chevron", box, 10, T.Sub)
    chev.Position = UDim2.new(1, -18, 0.5, -5)
    local flag = o.Flag or (self._title .. "/" .. (o.Name or "Dropdown"))
    local cb = o.Callback or function() end
    local value
    local function set(v, silent)
        value = v
        UI.Flags[flag] = v
        label.Text = tostring(v or "None")
        if not silent then task.spawn(cb, v) end
    end
    local open
    local function close() if open then open:Destroy() open = nil end end
    conn(box.MouseButton1Click, function()
        if open then close() return end
        local root = self._window._overlay
        -- Absolute* are screen pixels; offsets inside the window get scaled again, so undo the scale
        local k = (self._window._scale and self._window._scale.Scale) or 1
        local rows = math.max(#items, 1)
        open = new("Frame", { Size = UDim2.fromOffset(box.AbsoluteSize.X / k, math.min(rows, 7) * 26 + 8), BackgroundColor3 = T.Card2,
            Position = UDim2.fromOffset((box.AbsolutePosition.X - root.AbsolutePosition.X) / k, (box.AbsolutePosition.Y - root.AbsolutePosition.Y + box.AbsoluteSize.Y) / k + 4),
            ZIndex = 50, Parent = root }, { corner(8), stroke(T.Line, T.LineB) })
        local sc = new("ScrollingFrame", { Size = UDim2.new(1, -8, 1, -8), Position = UDim2.fromOffset(4, 4), BackgroundTransparency = 1,
            CanvasSize = UDim2.fromOffset(0, #items * 26), ScrollBarThickness = 2, BorderSizePixel = 0, ZIndex = 51, Parent = open }, { list(0) })
        for _, it in ipairs(items) do
            local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 26), BackgroundColor3 = T.Card, BackgroundTransparency = it == value and 0 or 1,
                AutoButtonColor = false, Text = "", ZIndex = 52, Parent = sc }, { corner(6) })
            text({ Size = UDim2.new(1, -12, 1, 0), Position = UDim2.fromOffset(8, 0), Text = tostring(it), TextSize = 12, FontFace = F_MED,
                TextColor3 = it == value and T.Text or T.Sub, ZIndex = 53, Parent = b })
            conn(b.MouseButton1Click, function() set(it); close() end)
        end
    end)
    self._window._closers[#self._window._closers + 1] = close
    set(o.Default or items[1], true)
    UI.Setters[flag] = function(v) set(v) end
    task.spawn(cb, value)
    return {
        Set = function(_, v) set(v) end, Get = function() return value end,
        Refresh = function(_, newItems) items = newItems or {}; if not table.find(items, value) then set(items[1], true) end end,
    }
end

function Card:Keybind(o)
    local r = row(self, 30)
    text({ Size = UDim2.new(1, -90, 1, 0), Text = o.Name or "Keybind", TextSize = 13, FontFace = F_MED, Parent = r })
    local box = new("TextButton", { Size = UDim2.fromOffset(70, 22), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = T.Field, AutoButtonColor = false, Text = "", Parent = r }, { corner(7), stroke(T.Line, T.LineA) })
    local label = text({ Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(8, 0), Text = "None", TextSize = 12, FontFace = F_MED, Parent = box })
    new("Frame", { Size = UDim2.fromOffset(10, 6), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -7, 0.5, 0),
        BackgroundColor3 = T.Sub, Parent = box }, { corner(2) })
    local flag = o.Flag or (self._title .. "/" .. (o.Name or "Keybind"))
    local cb = o.Callback or function() end
    local key, listening = nil, false
    local function set(k)
        key = (typeof(k) == "EnumItem" and k ~= Enum.KeyCode.Unknown and k ~= Enum.KeyCode.Backspace and k ~= Enum.KeyCode.Escape) and k or nil
        UI.Flags[flag] = key
        label.Text = key and key.Name or "None"
        if o.Changed then task.spawn(o.Changed, key) end
    end
    conn(box.MouseButton1Click, function()
        listening = true
        label.Text = "..."
    end)
    conn(UserInputService.InputBegan, function(i, gp)
        if listening then
            if i.UserInputType == Enum.UserInputType.Keyboard then
                listening = false
                set(i.KeyCode)
            end
            return
        end
        if gp or not key or UserInputService:GetFocusedTextBox() then return end
        if i.KeyCode == key then task.spawn(cb, true) end
    end)
    conn(UserInputService.InputEnded, function(i)
        if key and i.KeyCode == key and o.Hold then task.spawn(cb, false) end
    end)
    set(o.Default)
    UI.Setters[flag] = set
    return { Set = function(_, k) set(k) end, Get = function() return key end }
end

function Card:Button(o)
    local r = row(self, 32)
    local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 28), Position = UDim2.fromOffset(0, 2), BackgroundColor3 = T.Card2,
        AutoButtonColor = false, Text = o.Name or "Button", TextSize = 13, FontFace = F_SEMI, TextColor3 = T.Text, Parent = r }, { corner(8), stroke(T.Line, T.LineA) })
    conn(b.MouseEnter, function() tween(b, { BackgroundColor3 = T.Stroke }) end)
    conn(b.MouseLeave, function() tween(b, { BackgroundColor3 = T.Card2 }) end)
    conn(b.MouseButton1Click, function() task.spawn(o.Callback or function() end) end)
    return b
end

function Card:Textbox(o)
    local r = row(self, 30)
    text({ Size = UDim2.new(1, -150, 1, 0), Text = o.Name or "Text", TextSize = 13, FontFace = F_MED, Parent = r })
    local box = new("TextBox", { Size = UDim2.fromOffset(140, 24), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
        BackgroundColor3 = T.Field, Text = o.Default or "", PlaceholderText = o.Placeholder or "", PlaceholderColor3 = T.Dim,
        TextColor3 = T.Text, TextSize = 12, FontFace = F_MED, ClearTextOnFocus = false, Parent = r }, { corner(7), stroke(T.Line, T.LineA), pad(8, 0) })
    local flag = o.Flag or (self._title .. "/" .. (o.Name or "Text"))
    UI.Flags[flag] = box.Text
    conn(box.FocusLost, function() UI.Flags[flag] = box.Text; task.spawn(o.Callback or function() end, box.Text) end)
    UI.Setters[flag] = function(v) box.Text = tostring(v or ""); UI.Flags[flag] = box.Text end
    return box
end

function Card:Label(textValue)
    local r = row(self, 20)
    return text({ Size = UDim2.fromScale(1, 1), Text = tostring(textValue), TextSize = 12, TextColor3 = T.Sub, TextWrapped = true, Parent = r })
end

--// ===== tabs (top pills) =====
local Tab = {}
Tab.__index = Tab

function Tab:Card(o)
    -- phones get one full-width column: two would be unreadably narrow
    local col = (not self._window._mobile and (o.Side == "Right" or o.Side == 2)) and self._right or self._left
    local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = T.Card, BackgroundTransparency = T.CardA,
        LayoutOrder = nextOrder(), Parent = col }, { corner(14), stroke(T.Line, T.LineA), pad(14, 12, 14, 12), list(4) })
    local head = new("Frame", { Size = UDim2.new(1, 0, 0, o.Desc and 36 or 22), BackgroundTransparency = 1, LayoutOrder = 0, Parent = frame })
    text({ Size = UDim2.new(1, -50, 0, 20), Text = o.Title or "Card", TextSize = 14, FontFace = F_BOLD, Parent = head })
    if o.Desc then
        text({ Size = UDim2.new(1, -50, 0, 14), Position = UDim2.fromOffset(0, 20), Text = o.Desc, TextSize = 11, TextColor3 = T.Sub, Parent = head })
    end
    local c = setmetatable({ _body = frame, _title = o.Title or "Card", _window = self._window }, Card)
    if o.Toggle then
        local holder = new("Frame", { Size = UDim2.new(0, 40, 0, 20), Position = UDim2.new(1, -40, 0, 0), BackgroundTransparency = 1, Parent = head })
        local flag = o.Flag or (c._title .. "/Enabled")
        local cb = o.Callback or function() end
        local set = makeSwitch(holder, o.Default, function(v) UI.Flags[flag] = v; task.spawn(cb, v) end)
        UI.Flags[flag] = o.Default and true or false
        UI.Setters[flag] = function(v) set(v, true); UI.Flags[flag] = v and true or false; task.spawn(cb, UI.Flags[flag]) end
        if o.Default then task.spawn(cb, true) end
    end
    return c
end

--// ===== pages (sidebar sub items) =====
local Page = {}
Page.__index = Page

function Page:Tab(o)
    local w = self._window
    local btn = new("TextButton", { Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = T.Side, BackgroundTransparency = T.SideA,
        AutoButtonColor = false, Text = "", LayoutOrder = nextOrder(), Parent = self._tabBar }, { corner(17), stroke(T.Line, T.LineA), pad(14, 0, 16, 0), list(8, Enum.FillDirection.Horizontal) })
    btn:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Center
    local ic = icon(o.Icon or "target", btn, 12, T.Sub)
    ic.LayoutOrder = 1
    local lbl = text({ Size = UDim2.fromOffset(0, 34), AutomaticSize = Enum.AutomaticSize.X, Text = o.Name or "Tab", TextSize = 13,
        FontFace = F_SEMI, TextColor3 = T.Sub, LayoutOrder = 2, Parent = btn })
    local holder = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false,
        ScrollBarThickness = 2, ScrollBarImageColor3 = T.Stroke, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = self._content })
    local function column(x)
        local width = w._mobile and (x == 0 and UDim2.new(1, -6, 0, 0) or UDim2.new(0, 0, 0, 0)) or UDim2.new(0.5, -8, 0, 0)
        return new("Frame", { Size = width, Position = UDim2.new(x, x == 0 and 0 or 8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
            BackgroundTransparency = 1, Visible = not (w._mobile and x ~= 0), Parent = holder }, { list(w._mobile and 10 or 14) })
    end
    local tab = setmetatable({ _window = w, _left = column(0), _right = column(0.5), _holder = holder, _btn = btn, _lbl = lbl, _icon = ic, _page = self }, Tab)
    self._tabs[#self._tabs + 1] = tab
    conn(btn.MouseButton1Click, function() self:SelectTab(tab) end)
    if #self._tabs == 1 then self:SelectTab(tab) end
    return tab
end

local function paintIcon(ic, color)
    for _, d in ipairs(ic:GetDescendants()) do
        if d:IsA("UIStroke") then d.Color = color
        elseif d:IsA("Frame") and d.BackgroundTransparency < 1 then d.BackgroundColor3 = color
        elseif d:IsA("TextLabel") then d.TextColor3 = color end
    end
    if ic:IsA("TextLabel") then ic.TextColor3 = color end
end

function Page:SelectTab(tab)
    for _, t in ipairs(self._tabs) do
        local on = t == tab
        t._holder.Visible = on
        tween(t._btn, { BackgroundColor3 = on and T.Field or T.Side })
        t._btn:FindFirstChildOfClass("UIStroke").Color = on and T.White or T.StrokeLo
        t._lbl.TextColor3 = on and T.Text or T.Sub
        paintIcon(t._icon, on and T.Text or T.Sub)
    end
    self._current = tab
end

--// ===== categories (sidebar) =====
local Category = {}
Category.__index = Category

function Category:Page(o)
    local w = self._window
    local item = new("TextButton", { Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = T.Side, BackgroundTransparency = 1,
        AutoButtonColor = false, Text = "", LayoutOrder = nextOrder(), Parent = self._items }, { corner(10) })
    local st = stroke(T.White, 1, 1.2)
    st.Parent = item
    local ic = icon(o.Icon or "target", item, 12, T.Sub)
    ic.Position = UDim2.new(0, 14, 0.5, -6)
    local lbl = text({ Size = UDim2.new(1, -60, 1, 0), Position = UDim2.fromOffset(36, 0), Text = o.Name or "Page", TextSize = 13,
        FontFace = F_MED, TextColor3 = T.Sub, Parent = item })
    local dot = new("Frame", { Size = UDim2.fromOffset(5, 5), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
        BackgroundColor3 = T.White, Visible = false, Parent = item }, { corner(3) })
    -- every page has its own tab bar + content area in the right pane
    local area = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, Parent = w._right })
    local tabBar = new("Frame", { Size = UDim2.new(1, -60, 0, 36), Position = UDim2.fromOffset(30, 18), BackgroundTransparency = 1, Parent = area },
        { list(10, Enum.FillDirection.Horizontal, Enum.HorizontalAlignment.Center) })
    local content = new("Frame", { Size = UDim2.new(1, -40, 1, -84), Position = UDim2.fromOffset(20, 70), BackgroundTransparency = 1, Parent = area })
    local page = setmetatable({ _window = w, _tabs = {}, _tabBar = tabBar, _content = content, _area = area,
        _item = item, _stroke = st, _lbl = lbl, _dot = dot, _icon = ic, _category = self }, Page)
    w._pages[#w._pages + 1] = page
    self._pages[#self._pages + 1] = page
    conn(item.MouseButton1Click, function() w:SelectPage(page) end)
    self:_resize()
    if not w._current then w:SelectPage(page) end
    return page
end

function Category:_resize()
    local open = self._open and #self._pages > 0
    self._items.Visible = open
    local h = 46 + (open and (#self._pages * 42 + 6) or 0)
    tween(self._frame, { Size = UDim2.new(1, 0, 0, h) }, 0.18)
    tween(self._chev, { Rotation = open and 90 or 0 }, 0.18)
end

function Category:Toggle(state)
    if state == nil then state = not self._open end
    self._open = state
    self:_resize()
end

--// ===== window =====
local Window = {}
Window.__index = Window

function Window:Category(o)
    local frame = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundColor3 = T.Side, BackgroundTransparency = T.SideA, ClipsDescendants = true,
        LayoutOrder = nextOrder(), Parent = self._cats }, { corner(14), stroke(T.Line, T.LineA) })
    local head = new("TextButton", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Parent = frame })
    local ic = icon(o.Icon or "crosshair", head, 15, T.Text)
    ic.Position = UDim2.new(0, 16, 0.5, -7)
    text({ Size = UDim2.new(1, -80, 1, 0), Position = UDim2.fromOffset(42, 0), Text = o.Name or "Category", TextSize = 14, FontFace = F_BOLD, Parent = head })
    local chev = text({ Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -20, 0.5, 0), Text = "›",
        TextSize = 16, FontFace = F_BOLD, TextColor3 = T.Sub, TextXAlignment = Enum.TextXAlignment.Center, Parent = head })
    local items = new("Frame", { Size = UDim2.new(1, -16, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Position = UDim2.fromOffset(8, 46),
        BackgroundTransparency = 1, Visible = false, Parent = frame }, { list(4) })
    local cat = setmetatable({ _window = self, _frame = frame, _items = items, _chev = chev, _pages = {}, _open = o.Open ~= false and #self._categories == 0 }, Category)
    self._categories[#self._categories + 1] = cat
    conn(head.MouseButton1Click, function() cat:Toggle() end)
    cat:_resize()
    return cat
end

function Window:SelectPage(page)
    for _, p in ipairs(self._pages) do
        local on = p == page
        p._area.Visible = on
        p._dot.Visible = on
        tween(p._item, { BackgroundTransparency = on and 0 or 1 })
        p._item.BackgroundColor3 = T.Field
        p._stroke.Transparency = on and 0 or 1
        p._lbl.TextColor3 = on and T.Text or T.Sub
        p._lbl.FontFace = on and F_SEMI or F_MED
        paintIcon(p._icon, on and T.Text or T.Sub)
    end
    self._current = page
    if not page._category._open then page._category:Toggle(true) end
end

function Window:SetOpen(open)
    self._open = open
    self._main.Visible = open
    if self._blur then tween(self._blur, { Size = open and self._blurSize or 0 }, 0.25) end
end

-- Background blur on/off and strength (0-56). Blurs the 3D world behind the menu.
function Window:SetBlur(on, size)
    if size then self._blurSize = math.clamp(tonumber(size) or 18, 0, 56) end
    if on == false then
        if self._blur then self._blur:Destroy() self._blur = nil end
        return
    end
    if not self._blur then
        local ok, b = pcall(function()
            local e = Instance.new("BlurEffect")
            e.Name = HttpService:GenerateGUID(false):sub(1, 8)
            e.Size = 0
            e.Parent = game:GetService("Lighting")
            return e
        end)
        if ok then self._blur = b; UI._blur = b end
    end
    if self._blur then tween(self._blur, { Size = self._open and self._blurSize or 0 }, 0.25) end
end

function Window:Toggle() self:SetOpen(not self._open) end

function Window:SetUser(name, sub)
    self._userName.Text = tostring(name or "")
    self._userSub.Text = tostring(sub or "")
end

-- Ready-made Settings page: config files, cloud share codes and menu options.
-- The gear button (top right) jumps to it. Call once, after your own pages.
--   Window:AddSettings({ Folder = "SkiiHub/Practical", Autoload = true })
function Window:AddSettings(o)
    o = o or {}
    if o.Folder then UI.Folder = o.Folder end
    if o.CloudScript then UI.CloudScript = o.CloudScript end
    local w = self
    local cat = self:Category({ Name = o.Name or "Settings", Icon = "gear", Open = false })
    local page = cat:Page({ Name = "Configs", Icon = "gear" })
    local cfgTab = page:Tab({ Name = "Configs", Icon = "filter" })
    local menuTab = page:Tab({ Name = "Menu", Icon = "monitor" })

    -- local config files
    local files = cfgTab:Card({ Title = "Configs", Desc = "Save your settings and load them any time", Side = "Left" })
    local nameBox = files:Textbox({ Name = "Config Name", Flag = "_cfgName", Placeholder = "my config" })
    local pick = files:Dropdown({ Name = "Saved Configs", Flag = "_cfgPick", Items = UI:ListConfigs() })
    local autoLabel = files:Label("Autoload: " .. (UI:GetAutoload() or "off"))
    local function chosen()
        local typed = tostring(UI.Flags._cfgName or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if typed ~= "" then return typed end
        return UI.Flags._cfgPick
    end
    local function refresh() pick:Refresh(UI:ListConfigs()) end
    files:Button({ Name = "Save", Callback = function()
        local n = chosen()
        local ok, err = UI:SaveConfig(n)
        UI:Notify("Configs", ok and ("saved " .. tostring(n)) or tostring(err), 4)
        if ok then refresh(); pick:Set(n); nameBox.Text = ""; UI.Flags._cfgName = "" end
    end })
    files:Button({ Name = "Load", Callback = function()
        local n = UI.Flags._cfgPick or chosen()
        if not n then UI:Notify("Configs", "pick a config first", 4) return end
        local ok, err = UI:LoadConfigFile(n)
        UI:Notify("Configs", ok and ("loaded " .. tostring(n)) or tostring(err or "that config is broken"), 4)
    end })
    files:Button({ Name = "Delete", Callback = function()
        local n = UI.Flags._cfgPick
        if not n then UI:Notify("Configs", "pick a config first", 4) return end
        local ok, err = UI:DeleteConfig(n)
        UI:Notify("Configs", ok and ("deleted " .. tostring(n)) or tostring(err), 4)
        refresh()
    end })
    files:Button({ Name = "Set As Autoload", Callback = function()
        local n = UI.Flags._cfgPick
        if not n then UI:Notify("Configs", "pick a config first", 4) return end
        UI:SetAutoload(n)
        autoLabel.Text = "Autoload: " .. n
        UI:Notify("Configs", n .. " loads every time you execute", 4)
    end })
    files:Button({ Name = "Clear Autoload", Callback = function()
        UI:SetAutoload("")
        autoLabel.Text = "Autoload: off"
    end })
    files:Button({ Name = "Refresh List", Callback = refresh })

    -- cloud share codes
    local cloud = cfgTab:Card({ Title = "Cloud Configs", Desc = "Share a config with a 6 character code", Side = "Right" })
    cloud:Textbox({ Name = "Share Code", Flag = "_cloudCode", Placeholder = "ABC123" })
    cloud:Button({ Name = "Load Code", Callback = function()
        local ok, err, data = UI:LoadCloud(UI.Flags._cloudCode)
        UI:Notify("Cloud Configs", ok and ("loaded " .. tostring(data and data.name) .. " by " .. tostring(data and data.author)) or ("couldn't load: " .. tostring(err)), 6)
    end })
    cloud:Button({ Name = "Share My Config", Callback = function()
        local code, err = UI:ShareConfig()
        UI:Notify("Cloud Configs", code and ("your code: " .. code .. " (copied)") or ("share failed: " .. tostring(err)), 12)
    end })
    local featured = cloud:Dropdown({ Name = "Featured", Flag = "_cloudPick", Items = {} })
    local function refreshFeatured()
        local items = {}
        for _, c in ipairs(UI:FeaturedConfigs()) do items[#items + 1] = string.format("%s (%s)", tostring(c.name), tostring(c.code)) end
        featured:Refresh(items)
        return #items
    end
    cloud:Button({ Name = "Load Featured", Callback = function()
        local code = tostring(UI.Flags._cloudPick or ""):match("%((%w+)%)$")
        if not code then UI:Notify("Cloud Configs", "pick a featured config first", 4) return end
        local ok, err, data = UI:LoadCloud(code)
        UI:Notify("Cloud Configs", ok and ("loaded " .. tostring(data and data.name)) or ("couldn't load: " .. tostring(err)), 5)
    end })
    cloud:Button({ Name = "Refresh Featured", Callback = function()
        local n = refreshFeatured()
        UI:Notify("Cloud Configs", n > 0 and (n .. " featured configs") or "no featured configs yet", 4)
    end })
    task.spawn(function() pcall(refreshFeatured) end)

    -- menu options
    local menu = menuTab:Card({ Title = "Menu", Desc = "How the menu looks and opens", Side = "Left" })
    menu:Keybind({ Name = "Menu Key", Flag = "_menuKey", Default = w:GetMenuKey(), Changed = function(k) if k then w:SetMenuKey(k) end end })
    menu:Slider({ Name = "UI Scale", Flag = "_uiScale", Min = 50, Max = 150, Default = 100, Step = 5, Suffix = "%",
        Callback = function(v) w:SetScale(v / 100) end })
    menu:Toggle({ Name = "Background Blur", Flag = "_blur", Default = w._blur ~= nil,
        Callback = function(v) w:SetBlur(v) end })
    menu:Slider({ Name = "Blur Strength", Flag = "_blurSize", Min = 0, Max = 40, Default = w._blurSize or 18, Step = 1,
        Callback = function(v) w:SetBlur(w._blur ~= nil, v) end })
    menu:Toggle({ Name = "Floating Button", Flag = "_float", Default = w.FloatingButton.Visible,
        Callback = function(v) w:SetFloatingButton(v) end })
    menu:Button({ Name = "Close Menu", Callback = function() w:SetOpen(false) end })
    menu:Button({ Name = "Unload", Callback = function() UI:Unload() end })

    conn(self.Gear.MouseButton1Click, function() w:SelectPage(page) end)
    if o.Autoload ~= false then task.defer(function() UI:LoadAutoload() end) end
    self.SettingsPage = page
    return page
end

function UI:CreateWindow(o)
    o = o or {}
    local gui = new("ScreenGui", { Name = HttpService:GenerateGUID(false):sub(1, 8), ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50 })
    gui.Parent = guiParent()
    UI.Gui = gui
    notifyHolder = new("Frame", { Size = UDim2.new(0, 290, 1, -20), Position = UDim2.new(1, -300, 0, 10), BackgroundTransparency = 1, Parent = gui },
        { list(8, nil, Enum.HorizontalAlignment.Right) })
    notifyHolder:FindFirstChildOfClass("UIListLayout").VerticalAlignment = Enum.VerticalAlignment.Bottom

    -- Phone / tablet: touch with no keyboard, or a small screen. Override with o.Mobile = true/false.
    local cam0 = workspace.CurrentCamera
    local vp0 = cam0 and cam0.ViewportSize or Vector2.new(1920, 1080)
    local mobile = o.Mobile
    if mobile == nil then
        mobile = (UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled) or vp0.X < 760
    end
    local SW = mobile and 168 or 214          -- sidebar width
    local DIV = SW + 28                        -- divider x
    local size = o.Size or (mobile and UDim2.fromOffset(720, 430) or UDim2.fromOffset(980, 640))
    local main = new("Frame", { Size = size, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        BackgroundColor3 = T.Window, BackgroundTransparency = T.WindowA, Parent = gui }, { corner(20), stroke(T.Line, T.LineW) })
    new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 207, 214)), Parent = main })
    -- scale down on small screens (phones)
    local scale = new("UIScale", { Parent = main })
    local userScale = 1
    local function fit()
        local cam = workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1920, 1080)
        -- never bigger than the screen; userScale (Settings > UI Scale) shrinks or grows within that
        local maxFit = math.min((vp.X - 16) / main.Size.X.Offset, (vp.Y - 16) / main.Size.Y.Offset)
        scale.Scale = math.max(0.35, math.min(userScale, maxFit))
    end
    fit()
    if workspace.CurrentCamera then conn(workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"), fit) end

    -- left column
    local side = new("Frame", { Size = UDim2.new(0, SW, 1, -28), Position = UDim2.fromOffset(14, 14), BackgroundTransparency = 1, Parent = main })
    local logo = new("Frame", { Size = UDim2.new(1, 0, 0, 58), BackgroundColor3 = T.Side, BackgroundTransparency = T.SideA, Parent = side }, { corner(14), stroke(T.Line, T.LineA) })
    local badge = new("Frame", { Size = UDim2.fromOffset(36, 36), Position = UDim2.fromOffset(10, 11), BackgroundColor3 = T.Field, Parent = logo }, { corner(18), stroke(T.Line, T.LineB) })
    if o.Logo then
        new("ImageLabel", { Size = UDim2.fromScale(0.7, 0.7), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
            BackgroundTransparency = 1, Image = o.Logo, Parent = badge })
    else
        local star = drawLines(badge, 20, T.White, LINES.star, 1.6)
        star.AnchorPoint = Vector2.new(0.5, 0.5)
        star.Position = UDim2.fromScale(0.5, 0.5)
    end
    text({ Size = UDim2.new(1, -70, 0, 20), Position = UDim2.fromOffset(56, 12), Text = o.Title or "SKII HUB", TextSize = 17, FontFace = F_BOLD, Parent = logo })
    text({ Size = UDim2.new(1, -70, 0, 12), Position = UDim2.fromOffset(56, 33), Text = o.Subtitle or "", TextSize = 9, FontFace = F_SEMI, TextColor3 = T.Sub, Parent = logo })
    new("Frame", { Size = UDim2.fromOffset(5, 5), Position = UDim2.new(1, -14, 0, 10), BackgroundColor3 = T.White, Parent = logo }, { corner(1) })

    local cats = new("ScrollingFrame", { Size = UDim2.new(1, 0, 1, mobile and -72 or -146), Position = UDim2.fromOffset(0, 72), BackgroundTransparency = 1, BorderSizePixel = 0,
        ScrollBarThickness = 0, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, Parent = side }, { list(10) })

    local user = new("Frame", { Size = UDim2.new(1, 0, 0, 58), Position = UDim2.new(0, 0, 1, -58), BackgroundColor3 = T.Side, BackgroundTransparency = T.SideA,
        Visible = not mobile, Parent = side }, { corner(29), stroke(T.Line, T.LineA) }) -- phones need the space for categories
    local avatar = new("ImageLabel", { Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(12, 12), BackgroundColor3 = T.Field, Parent = user }, { corner(17), stroke(T.Line, T.LineB) })
    pcall(function()
        avatar.Image = Players:GetUserThumbnailAsync(Players.LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    local userName = text({ Size = UDim2.new(1, -100, 0, 18), Position = UDim2.fromOffset(56, 11), TextSize = 14, FontFace = F_BOLD, Parent = user,
        Text = o.User or (Players.LocalPlayer and Players.LocalPlayer.DisplayName) or "Player" })
    local userSub = text({ Size = UDim2.new(1, -100, 0, 14), Position = UDim2.fromOffset(56, 30), TextSize = 11, TextColor3 = T.Sub, Parent = user, Text = o.UserSub or "" })
    local userBtn = new("TextButton", { Size = UDim2.fromOffset(28, 28), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0),
        BackgroundColor3 = T.Card2, AutoButtonColor = false, Text = "↗", TextSize = 13, FontFace = F_BOLD, TextColor3 = T.Text, Parent = user }, { corner(14), stroke(T.Line, T.LineA) })

    -- divider + right pane
    new("Frame", { Size = UDim2.new(0, 1, 1, 0), Position = UDim2.fromOffset(DIV, 0), BackgroundColor3 = T.Line, BackgroundTransparency = 0.9, BorderSizePixel = 0, Parent = main })
    local right = new("Frame", { Size = UDim2.new(1, -(DIV + 1), 1, 0), Position = UDim2.fromOffset(DIV + 1, 0), BackgroundTransparency = 1, Parent = main })
    local gear = new("TextButton", { Size = UDim2.fromOffset(32, 32), Position = UDim2.new(1, -46, 0, 20), BackgroundColor3 = T.Side,
        AutoButtonColor = false, Text = "⚙", TextSize = 16, FontFace = F_BOLD, TextColor3 = T.Sub, ZIndex = 5, Parent = right }, { corner(16), stroke(T.Line, T.LineA) })
    local overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 40, Parent = main })

    local w = setmetatable({ _gui = gui, _main = main, _cats = cats, _right = right, _overlay = overlay, _pages = {}, _categories = {},
        _closers = {}, _open = true, _userName = userName, _userSub = userSub, Gear = gear, UserButton = userBtn,
        _mobile = mobile, _scale = scale }, Window)
    function w:SetScale(v) userScale = math.clamp(tonumber(v) or 1, 0.5, 1.5); fit() end

    -- close dropdowns when clicking elsewhere
    conn(UserInputService.InputBegan, function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
            task.defer(function()
                local p = i.Position
                for _, d in ipairs(overlay:GetChildren()) do
                    local a, s = d.AbsolutePosition, d.AbsoluteSize
                    if not (p.X >= a.X and p.X <= a.X + s.X and p.Y >= a.Y and p.Y <= a.Y + s.Y) then
                        for _, c in ipairs(w._closers) do pcall(c) end
                        break
                    end
                end
            end)
        end
    end)

    -- drag by the logo card or the empty top of the right pane
    local function draggable(handle)
        local dragging, start, startPos
        conn(handle.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                dragging, start, startPos = true, i.Position, main.Position
            end
        end)
        conn(UserInputService.InputChanged, function(i)
            if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - start
                main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
            end
        end)
        conn(UserInputService.InputEnded, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
        end)
    end
    logo.Active = true
    draggable(logo)
    local topStrip = new("Frame", { Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Active = true, Parent = right })
    draggable(topStrip)

    -- Floating button: tap to open/close the menu, drag to move it. The only
    -- way back into a hidden menu on a phone, which has no keyboard.
    local float = new("TextButton", { Size = UDim2.fromOffset(48, 48), Position = UDim2.new(0, 18, 0.35, 0), BackgroundColor3 = T.Window,
        BackgroundTransparency = 0.05, AutoButtonColor = false, Text = "", Visible = mobile or o.FloatingButton == true, ZIndex = 60, Parent = gui },
        { corner(24), stroke(T.Line, T.LineB) })
    local fstar = drawLines(float, 22, T.White, LINES.star, 1.7)
    fstar.AnchorPoint = Vector2.new(0.5, 0.5)
    fstar.Position = UDim2.fromScale(0.5, 0.5)
    for _, d in ipairs(fstar:GetDescendants()) do d.ZIndex = 61 end
    fstar.ZIndex = 61
    do
        local down, moved, start, startPos
        conn(float.InputBegan, function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                down, moved, start, startPos = true, false, i.Position, float.Position
            end
        end)
        conn(UserInputService.InputChanged, function(i)
            if down and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
                local d = i.Position - start
                if d.Magnitude > 8 then moved = true end
                if moved then float.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
            end
        end)
        conn(UserInputService.InputEnded, function(i)
            if down and (i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch) then
                down = false
                if not moved then w:Toggle() end
            end
        end)
    end
    w.FloatingButton = float
    function w:SetFloatingButton(on) float.Visible = on and true or false end

    -- blur the game behind the menu (o.Blur = false to turn off, o.BlurSize = 0-56)
    w._blurSize = o.BlurSize or 18
    if o.Blur ~= false then w:SetBlur(true) end

    -- menu key
    local menuKey = o.Key or Enum.KeyCode.RightShift
    conn(UserInputService.InputBegan, function(i, gp)
        if not gp and i.KeyCode == menuKey and not UserInputService:GetFocusedTextBox() then w:Toggle() end
    end)
    function w:SetMenuKey(k) if typeof(k) == "EnumItem" then menuKey = k end end
    function w:GetMenuKey() return menuKey end

    return w
end

function UI:Unload()
    UI.Unloaded = true
    for _, c in ipairs(UI._conns) do pcall(function() c:Disconnect() end) end
    UI._conns = {}
    if UI.Gui then UI.Gui:Destroy() end
    if UI._blur then pcall(function() UI._blur:Destroy() end) UI._blur = nil end
end

return UI
