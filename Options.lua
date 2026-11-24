-- Lootwright Options.lua: the panel in the game's Options > AddOns list (also /if options).
-- Each feature toggle is LootwrightDB[key]; nil (default) means on, false means off.
-- Sub-addons are switched in the AddOns list; this panel only shows whether they're on.

local _, ns = ...
local Options = {}
ns.Options = Options

local TOGGLES = {
    { key = "tooltip", label = "\"Drops from\" line on item tooltips",
      tip = "Item tooltips list the top 3 mobs that drop the item.",
      onChange = function() ns.UI.ClearTooltipCache() end },
    { key = "farmTooltip", label = "\"Farm:\" line on mob tooltips",
      tip = "Mobs that drop something on your farm list say so on their tooltip." },
    { key = "farmPins", label = "Pins mobs on Map that drops your items",
      tip = "Grouped pins on every mob that drops a farm item or a material you still need.",
      onChange = function() ns.Map.RefreshFarmPins(true) end },
    { key = "arrow", label = "Waypoint arrow when you click a Lootwright Pin",
      tip = "Shows an arrow and distance to the spawn. The map marker is set either way." },
    { key = "farmAlerts", label = "Farm updates displayed on screen",
      tip = "Goal reached, material ready and \"craft it\" messages. They always go to chat." },
    { key = "minimapButton", label = "Minimap button",
      tip = "The Lootwright emblem on the minimap. Left-click opens the window, right-click opens these options.",
      onChange = function() ns.MinimapButton.Refresh() end },
    { key = "mapPins", label = "Lootwright pins on the world map",
      tip = "Pins for the mob you clicked and for farm spawns. Also the \"Lootwright\" checkbox on the map itself.",
      onChange = function()
          if ns.Map.toggle then ns.Map.toggle:SetChecked(LootwrightDB.mapPins ~= false) end
          ns.Map.RefreshFarmPins(true)
      end },
    { key = "mapToggle", label = "\"Lootwright\" checkbox on the world map",
      tip = "The small checkbox in the map's bottom-right corner that shows or hides Lootwright's pins. "
          .. "Hide it if it covers something; the pins option above still works.",
      onChange = function()
          if ns.Map.toggle then ns.Map.toggle:SetShown(LootwrightDB.mapToggle ~= false) end
      end },
    -- Off by default (defaultOff): only true turns it on.
    { key = "recordLoot", label = "Help improve drop rates: record my loot", defaultOff = true,
      tip = "Counts the corpses you loot and what was on them, on this PC only, so mob tooltips show your own drop rate. "
          .. "Share it with /if share; Lootwright reminds you now and then. No names or positions." },
    { key = "tracker", label = "Display Farm Tracker on HUD", defaultOff = true,
      tip = "A small panel that shows your farm list all the time. Drag an item from your bags onto it to farm it. "
          .. "Also /if mini.",
      onChange = function() ns.Tracker.Refresh() end },
}

-- Default-on toggles are on unless set to false; default-off toggles only when set to true.
-- (Features read LootwrightDB[key] directly with the same rule.)
local function isChecked(t)
    if t.defaultOff then return LootwrightDB[t.key] == true end
    return LootwrightDB[t.key] ~= false
end

local SUBADDONS = {
    { name = "Lootwright_Data", label = "Lootwright - Data", what = "recipes, boss loot (ForeverDB.net) and mob drop rates (CMaNGOS)" },
    { name = "Lootwright_Professions", label = "Lootwright - Professions", what = "the Professions tab" },
}

local function subAddonState(name)
    if C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(name) then return "on" end
    local ok, state = pcall(C_AddOns.GetAddOnEnableState, name, UnitName("player"))
    if ok and type(state) == "number" and state > 0 then return "on (loads when needed)" end
    local ok2, exists = pcall(C_AddOns.DoesAddOnExist, name)
    if ok2 and exists == false then return "not installed" end
    return "off"
end

local panel, checks, subLines, category

local function refresh()
    for _, cb in ipairs(checks) do cb:SetChecked(isChecked(cb.toggle)) end
    for _, l in ipairs(subLines) do
        l.fs:SetText(l.sub.label .. ": |cffffffff" .. subAddonState(l.sub.name) .. "|r  |cff999999(" .. l.sub.what .. ")|r")
    end
end

local function build()
    panel = CreateFrame("Frame")
    panel.name = "Lootwright"
    checks, subLines = {}, {}

    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Lootwright")
    local sub = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetText("Switch off what you don't use.")

    local prev = sub
    for i, t in ipairs(TOGGLES) do
        local cb = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
        cb:SetSize(24, 24)
        cb:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", i == 1 and -2 or 0, i == 1 and -14 or -6)
        cb.key, cb.toggle = t.key, t
        local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        fs:SetPoint("LEFT", cb, "RIGHT", 4, 1)
        fs:SetText(t.label)
        cb:SetScript("OnClick", function(self)
            LootwrightDB[t.key] = self:GetChecked() and true or false
            if t.onChange then t.onChange() end
        end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(t.label, 1, 1, 1)
            GameTooltip:AddLine(t.tip, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        checks[#checks + 1] = cb
        prev = cb
    end

    local head = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    head:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 2, -24)
    head:SetText("Parts")
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
    hint:SetText("Turn these on or off in the AddOns list on the character screen, then /reload.")
    prev = hint
    for _, s in ipairs(SUBADDONS) do
        local fs = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -8)
        subLines[#subLines + 1] = { fs = fs, sub = s }
        prev = fs
    end

    panel:SetScript("OnShow", refresh)

    if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
        category = Settings.RegisterCanvasLayoutCategory(panel, "Lootwright")
        Settings.RegisterAddOnCategory(category)
    elseif InterfaceOptions_AddCategory then
        InterfaceOptions_AddCategory(panel)
    end
end

function Options.Open()
    if not panel then build() end
    if category and Settings and Settings.OpenToCategory then
        local ok = pcall(Settings.OpenToCategory, category:GetID())
        if ok then return end
        pcall(Settings.OpenToCategory, category)
    elseif InterfaceOptionsFrame_OpenToCategory then
        InterfaceOptionsFrame_OpenToCategory(panel)
    end
end

-- Register the panel once saved variables are loaded.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function() if not panel then build() end end)
