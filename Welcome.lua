-- Lootwright Welcome.lua: the first-start window and the share reminder.
-- Welcome (once, LootwrightDB.welcomed; again with /if welcome): what Lootwright does, and two
-- opt-ins, both off until ticked: the farm tracker (LootwrightDB.tracker) and recording your loot
-- (LootwrightDB.recordLoot). Reminder (players who opted in): at login, once you've counted
-- REMIND_EVERY corpses since your last share, a small window offers /if share.

local _, ns = ...
local Welcome = {}
ns.Welcome = Welcome

local T = ns.Theme
local REMIND_EVERY = 100 -- new corpses since the last share (or the last "Later")

-- A themed dialog: title, close x, line. Returns the frame.
local function dialog(name, w, h, titleText)
    local C = T.C
    local f = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    f:Hide()
    f:SetSize(w, h)
    f:SetPoint("CENTER", 0, 80)
    f:SetFrameStrata("DIALOG")
    f:SetClampedToScreen(true)
    f:EnableMouse(true)
    T.Backdrop(f, C.bg, C.muted, 0.98)
    tinsert(UISpecialFrames, name) -- Escape closes it
    local emblem = f:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture(T.MEDIA .. "emblem_32")
    emblem:SetSize(20, 20)
    emblem:SetPoint("TOPLEFT", 8, -5)
    local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", emblem, "RIGHT", 6, 0)
    title:SetText(titleText)
    local close = CreateFrame("Button", nil, f)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    x:SetPoint("CENTER")
    x:SetText("×")
    x:SetTextColor(T.RGB(C.muted))
    close:SetScript("OnClick", function() f:Hide() end)
    local line = T.Line(f, C.line)
    line:SetPoint("TOPLEFT", 1, -30)
    line:SetPoint("TOPRIGHT", -1, -30)
    line:SetHeight(1)
    return f
end

local function text(parent, template, w)
    local fs = parent:CreateFontString(nil, "OVERLAY", template)
    fs:SetWidth(w)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end

-- Welcome ---------------------------------------------------------------------------------------------
local welcome, trackerCB, lootCB

-- A tick box with a bold label and a grey line under it.
local function choice(parent, anchor, label, sub)
    local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    cb:SetSize(24, 24)
    cb:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -12)
    local l = text(parent, "GameFontHighlight", 330)
    l:SetPoint("TOPLEFT", cb, "TOPRIGHT", 4, -4)
    l:SetText(label)
    local s = text(parent, "GameFontDisableSmall", 330)
    s:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3)
    s:SetText(sub)
    cb.bottom = s -- the next choice anchors under the grey line
    return cb
end

local function buildWelcome()
    welcome = dialog("LootwrightWelcome", 400, 330, "Welcome to Lootwright")
    local intro = text(welcome, "GameFontHighlightSmall", 372)
    intro:SetPoint("TOPLEFT", 14, -42)
    intro:SetText("Search any item (|cffffffff/if|r or the minimap button) to see which mobs drop it, where, "
        .. "at what level and how often. Farm it with map skulls, goals and recipes.\n\nTwo things are off until you turn them on:")

    trackerCB = choice(welcome, intro, "Show the farm tracker",
        "A small on-screen panel with your farm list and progress bars. Drag items from your bags onto it to farm them.")
    lootCB = choice(welcome, trackerCB.bottom, "Help improve drop rates",
        "Count what you loot, on this PC only, for real Forever drop rates. Share it with /if share when you like; "
        .. "Lootwright reminds you now and then. No names or positions.")
    lootCB:ClearAllPoints()
    lootCB:SetPoint("TOPLEFT", trackerCB.bottom, "BOTTOMLEFT", -28, -10)

    local foot = text(welcome, "GameFontDisableSmall", 372)
    foot:SetPoint("BOTTOMLEFT", 14, 44)
    foot:SetText("Change these any time in /if options.")

    local done = T.Button(welcome, "Done", 80, 22)
    done:SetPoint("BOTTOMRIGHT", -12, 12)
    done:SetBackdropColor(T.RGB(T.C.greenDim))
    done:SetBackdropBorderColor(T.RGB(T.C.greenEdge))
    done:GetFontString():SetTextColor(T.RGB(T.C.green))
    done:SetScript("OnClick", function()
        LootwrightDB.tracker = trackerCB:GetChecked() and true or false
        LootwrightDB.recordLoot = lootCB:GetChecked() and true or false
        ns.Tracker.Refresh()
        if LootwrightDB.recordLoot then
            ns.say("Thank you! Lootwright now counts your loot. /if share shares it, /if options turns it off.")
        end
        welcome:Hide()
    end)
    -- Closing without Done (x or Escape) still counts as seen; nothing is turned on.
    welcome:SetScript("OnHide", function() LootwrightDB.welcomed = true end)
end

function Welcome.Show()
    if InCombatLockdown() then ns.say("The welcome window can't open in combat."); return end
    if not welcome then buildWelcome() end
    trackerCB:SetChecked(LootwrightDB.tracker == true)
    lootCB:SetChecked(LootwrightDB.recordLoot == true)
    welcome:Show()
end

-- Share reminder -----------------------------------------------------------------------------------
local reminder, reminderText

local function buildReminder()
    reminder = dialog("LootwrightShareReminder", 340, 128, "Share your loot data?")
    reminderText = text(reminder, "GameFontHighlightSmall", 312)
    reminderText:SetPoint("TOPLEFT", 14, -42)
    local share = T.Button(reminder, "Share now", 90, 22)
    share:SetPoint("BOTTOMRIGHT", -12, 12)
    share:SetBackdropColor(T.RGB(T.C.greenDim))
    share:SetBackdropBorderColor(T.RGB(T.C.greenEdge))
    share:GetFontString():SetTextColor(T.RGB(T.C.green))
    share:SetScript("OnClick", function() reminder:Hide(); ns.Loot.ShowExport() end)
    local later = T.Button(reminder, "Later", 70, 22)
    later:SetPoint("RIGHT", share, "LEFT", -6, 0)
    later:SetScript("OnClick", function()
        LootwrightDB.loot.sharedN = ns.Loot.Total() -- ask again after another REMIND_EVERY corpses
        reminder:Hide()
    end)
end

local function remind()
    if LootwrightDB.recordLoot ~= true or not ns.Loot or type(LootwrightDB.loot) ~= "table" then return end
    local new = ns.Loot.Total() - (LootwrightDB.loot.sharedN or 0)
    if new < REMIND_EVERY or InCombatLockdown() then return end
    if not reminder then buildReminder() end
    reminderText:SetText("You've counted " .. new .. " corpses since you last shared. Sharing them helps work out "
        .. "real Forever drop rates for everyone. It takes a minute: copy, paste into the form, done.")
    reminder:Show()
end

function Welcome.OnLogin()
    -- A little after login, so the window doesn't fight the loading screen.
    C_Timer.After(3, function()
        if not LootwrightDB.welcomed then Welcome.Show() else remind() end
    end)
end
