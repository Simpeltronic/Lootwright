-- Lootwright MinimapButton.lua: the Option E emblem as a minimap button.
-- Left-click: open/close the window. Right-click: options. Drag: move it around the minimap edge.
-- Named LootwrightMinimapButton and created at load time, so MinimapButtonButton (and similar
-- collectors that look for "MinimapButton" in child frame names) pick it up in their login scan.
-- Settings: LootwrightDB.minimapButton (false = hidden), LootwrightDB.minimapAngle (degrees).

local _, ns = ...
local MB = {}
ns.MinimapButton = MB

local T = ns.Theme
local DEFAULT_ANGLE = 200 -- lower left of the minimap

local b = CreateFrame("Button", "LootwrightMinimapButton", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetMovable(true)

local icon = b:CreateTexture(nil, "ARTWORK")
icon:SetSize(28, 28)
icon:SetPoint("CENTER")
icon:SetTexture(T.MEDIA .. "emblem")
b.icon = icon

local function place(angle)
    local r = math.rad(angle or DEFAULT_ANGLE)
    local radius = Minimap:GetWidth() / 2 + 6
    b:ClearAllPoints()
    b:SetPoint("CENTER", Minimap, "CENTER", math.cos(r) * radius, math.sin(r) * radius)
end

-- Angle (degrees) from the minimap centre to the cursor.
local function cursorAngle()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    return math.deg(math.atan2(cy / s - my, cx / s - mx))
end

b:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function() place(cursorAngle()) end)
end)
b:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
    LootwrightDB.minimapAngle = cursorAngle()
end)

b:SetScript("OnClick", function(_, button)
    if button == "RightButton" then ns.Options.Open() else ns.UI.Toggle() end
end)

b:SetScript("OnEnter", function(self)
    icon:SetTexture(T.MEDIA .. "emblem_hover")
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Lootwright")
    GameTooltip:AddLine("Find any item. Farm what you need.", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("Left-click: open or close", 0.2, 1, 0.6)
    GameTooltip:AddLine("Right-click: options", 0.2, 1, 0.6)
    GameTooltip:AddLine("Drag: move around the minimap", 0.6, 0.6, 0.6)
    GameTooltip:Show()
end)
b:SetScript("OnLeave", function()
    icon:SetTexture(T.MEDIA .. "emblem")
    GameTooltip:Hide()
end)
b:SetScript("OnMouseDown", function() icon:SetVertexColor(0.75, 0.75, 0.75) end)
b:SetScript("OnMouseUp", function() icon:SetVertexColor(1, 1, 1) end)

-- Shows or hides the button from the setting.
function MB.Refresh()
    b:SetShown(LootwrightDB.minimapButton ~= false)
end

-- Saved variables are loaded by PLAYER_LOGIN: place the button where the player left it.
-- (A minimap button collector may move it afterwards; that's fine.)
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    place(LootwrightDB.minimapAngle)
    MB.Refresh()
end)
place(DEFAULT_ANGLE)
