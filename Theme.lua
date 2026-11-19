-- Lootwright Theme.lua: the "dark field guide" look (Phase 9). Flat dark panels with 1 px borders,
-- item-quality colours as the only bright accents, and one brass line under the emblem.
-- Everything is drawn with the plain white texture and backdrops, so no Blizzard frame art is used.

local _, ns = ...
local T = {}
ns.Theme = T

local WHITE = "Interface\\Buttons\\WHITE8x8"
T.MEDIA = "Interface\\AddOns\\Lootwright\\Media\\"

-- {r, g, b} 0..1. Same values as docs/design-preview-dark.png (tools/preview_dark.py).
T.C = {
    bg        = { 0.078, 0.090, 0.110 },
    panel     = { 0.102, 0.118, 0.145 },
    line      = { 0.184, 0.208, 0.251 },
    text      = { 0.839, 0.855, 0.882 },
    muted     = { 0.541, 0.576, 0.639 },
    white     = { 1, 1, 1 },
    brass     = { 0.788, 0.635, 0.290 },
    green     = { 0.310, 0.827, 0.416 },
    greenDim  = { 0.118, 0.165, 0.133 },
    greenEdge = { 0.184, 0.420, 0.235 },
    yellow    = { 1, 0.820, 0 },
    sel       = { 0.114, 0.165, 0.247 },
    blue      = { 0.431, 0.635, 1 },
    craft     = { 0.443, 0.835, 1 }, -- WoW's link blue for spells and trade skills (71d5ff): crafted materials
}

local function rgb(c, a) return c[1], c[2], c[3], a or 1 end
T.RGB = rgb

-- Gives a frame a flat background and a 1 px border.
function T.Backdrop(f, bg, edge, bgAlpha)
    if not f.SetBackdrop then
        Mixin(f, BackdropTemplateMixin)
        f:HookScript("OnSizeChanged", f.OnBackdropSizeChanged)
    end
    f:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
    if bg then f:SetBackdropColor(rgb(bg, bgAlpha)) else f:SetBackdropColor(0, 0, 0, 0) end
    f:SetBackdropBorderColor(rgb(edge or T.C.line))
end

-- A horizontal or vertical 1 px line (or `thick` px) as a texture.
function T.Line(parent, color, thick)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(WHITE)
    t:SetVertexColor(rgb(color or T.C.line))
    t.thick = thick or 1
    return t
end

-- A flat button: panel background, border, label. b:SetText works as usual.
function T.Button(parent, text, w, h)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(w or 80, h or 22)
    T.Backdrop(b, T.C.panel, T.C.line)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("CENTER")
    b:SetFontString(fs)
    b:SetText(text or "")
    b:SetHighlightTexture(WHITE, "ADD")
    b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.06)
    b:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(rgb(T.C.muted)) end)
    b:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(rgb(T.C.line)) end)
    return b
end

-- A toggle pill. style "filter" (green when on) or "tab" (blue when on). b:SetOn(bool).
function T.Pill(parent, text, style)
    local b = T.Button(parent, text, 10, 18)
    b:SetWidth(b:GetFontString():GetStringWidth() + 18)
    b.style = style or "filter"
    function b:SetOn(on)
        self.on = on
        if on and self.style == "tab" then
            self:SetBackdropColor(rgb(T.C.sel)); self.edge = T.C.sel; self:GetFontString():SetTextColor(rgb(T.C.blue))
        elseif on then
            self:SetBackdropColor(rgb(T.C.greenDim)); self.edge = T.C.greenEdge; self:GetFontString():SetTextColor(rgb(T.C.green))
        else
            self:SetBackdropColor(0, 0, 0, 0); self.edge = T.C.line; self:GetFontString():SetTextColor(rgb(T.C.muted))
        end
        self:SetBackdropBorderColor(rgb(self.edge))
    end
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(rgb(self.edge or T.C.line)) end)
    b:SetOn(false)
    return b
end

-- A header text tab: large text, white and underlined in brass when active, muted otherwise.
-- 36 px tall, meant to sit with its bottom edge on the header line. b:SetOn(bool).
function T.TextTab(parent, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(36)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fs:SetPoint("TOP", 0, -4)
    fs:SetText(text)
    b:SetWidth(fs:GetStringWidth() + 8)
    b.text = fs
    local u = b:CreateTexture(nil, "OVERLAY")
    u:SetTexture(WHITE)
    u:SetVertexColor(rgb(T.C.brass))
    u:SetHeight(3)
    u:SetPoint("BOTTOMLEFT", -4, 0)
    u:SetPoint("BOTTOMRIGHT", 4, 0)
    b.underline = u
    function b:SetOn(on)
        self.on = on
        self.text:SetTextColor(rgb(on and T.C.white or T.C.muted))
        self.underline:SetShown(on)
    end
    b:SetScript("OnEnter", function(self) if not self.on then self.text:SetTextColor(rgb(T.C.text)) end end)
    b:SetScript("OnLeave", function(self) if not self.on then self.text:SetTextColor(rgb(T.C.muted)) end end)
    b:SetOn(false)
    return b
end

-- Restyles a SearchBoxTemplate edit box: hides its Blizzard art, draws a dark field behind it.
-- (SearchBoxTemplate is the edit box that takes typing on Forever; InputBoxTemplate didn't.)
function T.StyleEditBox(eb)
    for _, key in ipairs({ "Left", "Right", "Middle", "Mid" }) do
        if eb[key] and eb[key].Hide then eb[key]:Hide() end
    end
    local bg = CreateFrame("Frame", nil, eb, "BackdropTemplate")
    bg:SetPoint("TOPLEFT", eb, "TOPLEFT", -6, 2)
    bg:SetPoint("BOTTOMRIGHT", eb, "BOTTOMRIGHT", 2, -2)
    bg:SetFrameLevel(math.max(0, eb:GetFrameLevel() - 1))
    T.Backdrop(bg, T.C.panel, T.C.line)
    eb:HookScript("OnEditFocusGained", function() bg:SetBackdropBorderColor(rgb(T.C.muted)) end)
    eb:HookScript("OnEditFocusLost", function() bg:SetBackdropBorderColor(rgb(T.C.line)) end)
    return bg
end

-- Row hover and selection textures for list rows (used by UI.RowBase).
function T.StyleRow(button)
    button:SetHighlightTexture(WHITE, "ADD")
    button:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
    button.sel = button:CreateTexture(nil, "BACKGROUND")
    button.sel:SetAllPoints()
    button.sel:SetTexture(WHITE)
    button.sel:SetVertexColor(rgb(T.C.sel))
    button.sel:Hide()
end
