-- Lootwright Tracker.lua: the farm tracker (off by default; the welcome window, Options or /if mini).
-- A small panel that stays on screen, like the quest tracker: recipe groups with their materials
-- indented, then single farm items, each with have/goal and a thin bar. Drag an item from your bags
-- onto it to farm it (the amount popup asks how many).
-- Header: drag to move, right-click to lock or unlock, the - / + button collapses it.
-- Settings: LootwrightDB.tracker (true = shown), trackerPos, trackerLocked, trackerCollapsed.
-- shortcut: rows are a fixed pool of MAX_ROWS; a longer list ends with "+N more". Raise it if needed.

local _, ns = ...
local Tracker = {}
ns.Tracker = Tracker

local T = ns.Theme
local WIDTH, ROW_H, HEAD_H, DROP_H, MAX_ROWS = 240, 18, 26, 26, 20
local READY = " |TInterface\\RaidFrame\\ReadyCheck-Ready:11:11|t"

local frame, header, countText, collapseB, dropZone, moreText
local rows = {}

local function itemName(id)
    return ns.Data.ItemName(id) or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item " .. id)
end

-- Drop handler: an item on the cursor opens the amount popup for it.
local function takeCursorItem()
    local kind, id = GetCursorInfo()
    if kind ~= "item" or not id then return end
    ClearCursor()
    ns.FarmPopup.Open(id, frame)
end

local function makeRow(i)
    local r = CreateFrame("Button", nil, frame)
    r:SetHeight(ROW_H)
    r:SetPoint("TOPLEFT", 0, -(HEAD_H + 4 + (i - 1) * ROW_H))
    r:SetPoint("RIGHT")
    r:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
    r:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(14, 14)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.count:SetPoint("RIGHT", -8, 1)
    r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 5, 1)
    r.name:SetPoint("RIGHT", r.count, "LEFT", -4, 0)
    r.name:SetJustifyH("LEFT")
    r.name:SetWordWrap(false)
    r.track = r:CreateTexture(nil, "ARTWORK")
    r.track:SetTexture("Interface\\Buttons\\WHITE8x8")
    r.track:SetVertexColor(0.15, 0.17, 0.20)
    r.track:SetHeight(2)
    r.track:SetPoint("BOTTOMLEFT", r.name, "BOTTOMLEFT", 0, -3)
    r.track:SetPoint("RIGHT", -8, 0)
    r.fill = r:CreateTexture(nil, "OVERLAY")
    r.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
    r.fill:SetHeight(2)
    r.fill:SetPoint("LEFT", r.track, "LEFT")
    -- What the bank can still cover, in a lighter green right after the bag fill.
    r.bankFill = r:CreateTexture(nil, "OVERLAY")
    r.bankFill:SetColorTexture(0.62, 0.9, 0.62, 1)
    r.bankFill:SetPoint("TOP", r.fill)
    r.bankFill:SetPoint("BOTTOM", r.fill)
    r:SetScript("OnClick", function(self)
        if self.itemId and not InCombatLockdown() then ns.UI.ShowItem(self.itemId) end
    end)
    r:SetScript("OnEnter", function(self)
        if not self.itemId then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetItemByID(self.itemId)
        local banked = ns.Farm.Bank(self.itemId)
        if banked > 0 then GameTooltip:AddLine(banked .. " in your bank (not counted: take them out to use them)", 0.7, 0.7, 0.7) end
        GameTooltip:AddLine("Click: show where it drops", 0.2, 1, 0.6)
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:RegisterForDrag("LeftButton")
    r:SetScript("OnReceiveDrag", takeCursorItem)
    rows[i] = r
    return r
end

-- line = { itemId, label, color {r,g,b}, have, goal, depth, ready }
local function fillRow(r, line)
    r.itemId = line.itemId
    r.icon:ClearAllPoints()
    r.icon:SetPoint("LEFT", 8 + 14 * (line.depth or 0), 0)
    r.icon:SetTexture(line.itemId and C_Item.GetItemIconByID(line.itemId) or 134400)
    r.name:SetText(line.label)
    r.name:SetTextColor(T.RGB(line.color))
    local goal = line.goal
    -- "1(2)/3", as on the Farm tab: the bank part is only what it can still cover of the goal.
    local banked = line.itemId and ns.Farm.Bank(line.itemId) or 0
    local fromBank = goal and math.min(banked, math.max(0, goal - line.have)) or banked
    r.count:SetText(line.have .. (fromBank > 0 and ("|cff7d8cad(" .. fromBank .. ")|r") or "")
        .. (goal and ("/" .. goal) or "") .. ((goal and line.have >= goal) and READY or ""))
    r.count:SetTextColor(T.RGB(T.C.muted))
    if line.done then
        -- Goal reached: gold label, count and full bar; stays until removed on the Farm tab.
        r.name:SetTextColor(T.RGB(T.C.brass))
        r.count:SetText("|cffc9a24a" .. line.have .. (goal and ("/" .. goal) or "") .. "|r" .. READY)
        goal, fromBank = 1, 0
        line = { have = 1, depth = line.depth, done = true }
    elseif not goal and line.endless then
        -- Endless: "32 · 1 stack", and the bar fills toward the next full stack, then starts over.
        local stack = ns.Farm.StackSize(line.itemId)
        local full = stack and math.floor(line.have / stack) or 0
        if full > 0 then r.count:SetText(line.have .. " · " .. full .. (full == 1 and " stack" or " stacks")) end
        goal, fromBank = stack, 0
        line = { have = stack and (line.have % stack) or 0, depth = line.depth }
    end
    if goal and goal > 0 then
        r.track:Show()
        r.fill:SetShown(line.have > 0)
        -- Track width from the layout constants (GetWidth is 0 before the first layout pass):
        -- the row is WIDTH wide; the track runs from the name's left edge to 8 px from the right.
        local w = WIDTH - 8 - (8 + 14 * (line.depth or 0) + 14 + 5)
        r.fill:SetWidth(math.max(1, w * math.min(line.have, goal) / goal))
        r.fill:SetVertexColor(T.RGB(line.done and T.C.brass or (line.have >= goal and T.C.green or T.C.greenEdge)))
        if fromBank > 0 then
            r.bankFill:ClearAllPoints()
            r.bankFill:SetPoint("TOP", r.track)
            r.bankFill:SetPoint("BOTTOM", r.track)
            r.bankFill:SetPoint("LEFT", r.track, "LEFT", w * line.have / goal, 0)
            r.bankFill:SetWidth(math.max(1, w * fromBank / goal))
            r.bankFill:Show()
        else
            r.bankFill:Hide()
        end
    else
        r.track:Hide()
        r.fill:Hide()
        r.bankFill:Hide()
    end
    r:Show()
end

-- The tracker's lines: recipe groups (crafted item, then materials indented), then single items.
local function collect()
    local C, lines = T.C, {}
    for _, rec in ipairs(ns.Farm.RecipeList()) do
        lines[#lines + 1] = { itemId = rec.itemId, label = rec.name, color = rec.done and C.brass or C.yellow, done = rec.done,
            have = rec.itemId and ns.Farm.Have(rec.itemId) or 0, goal = rec.target, depth = 0 }
        for _, m in ipairs(rec.rows or {}) do
            lines[#lines + 1] = { itemId = m.itemId, label = itemName(m.itemId),
                color = m.vendorOnly and C.muted or ((m.crafted or ns.Data.CraftedBy(m.itemId)) and C.craft) or C.green, have = ns.Farm.Have(m.itemId), goal = m.need, depth = m.depth }
        end
    end
    local singles = ns.Farm.Ids()
    table.sort(singles, function(a, b) return itemName(a) < itemName(b) end)
    for _, id in ipairs(singles) do
        lines[#lines + 1] = { itemId = id, label = itemName(id), color = ns.Data.CraftedBy(id) and C.craft or C.green, have = ns.Farm.Have(id),
            goal = ns.Farm.Goal(id), endless = not ns.Farm.Goal(id), done = ns.Farm.Done(id), depth = 0 }
    end
    return lines
end

local function savePos()
    local p, _, rp, x, y = frame:GetPoint()
    LootwrightDB.trackerPos = { p, rp, x, y }
end

local function build()
    local C = T.C
    frame = CreateFrame("Frame", "LootwrightTracker", UIParent, "BackdropTemplate")
    frame:SetSize(WIDTH, HEAD_H + DROP_H)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    T.Backdrop(frame, C.bg, C.line, 0.85)
    frame:SetScript("OnReceiveDrag", takeCursorItem)
    local pos = LootwrightDB.trackerPos
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
    end

    header = CreateFrame("Button", nil, frame)
    header:SetPoint("TOPLEFT")
    header:SetPoint("TOPRIGHT")
    header:SetHeight(HEAD_H)
    header:RegisterForDrag("LeftButton")
    header:RegisterForClicks("RightButtonUp")
    header:SetScript("OnDragStart", function() if not LootwrightDB.trackerLocked then frame:StartMoving() end end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); savePos() end)
    header:SetScript("OnClick", function()
        LootwrightDB.trackerLocked = not LootwrightDB.trackerLocked
        ns.say("Farm tracker " .. (LootwrightDB.trackerLocked and "locked." or "unlocked: drag the header to move it."))
    end)
    header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Farm tracker")
        GameTooltip:AddLine("Drag an item from your bags onto it to farm it.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine(LootwrightDB.trackerLocked and "Right-click: unlock" or "Drag: move   Right-click: lock",
            0.2, 1, 0.6)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local emblem = header:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(18, 18)
    emblem:SetPoint("LEFT", 6, 0)
    emblem:SetTexture(T.MEDIA .. "emblem")
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("LEFT", emblem, "RIGHT", 6, 0)
    title:SetText("Farming")
    collapseB = CreateFrame("Button", nil, header)
    collapseB:SetSize(18, 18)
    collapseB:SetPoint("RIGHT", -4, 0)
    collapseB.text = collapseB:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    collapseB.text:SetPoint("CENTER")
    collapseB:SetScript("OnClick", function()
        LootwrightDB.trackerCollapsed = not LootwrightDB.trackerCollapsed
        Tracker.Refresh()
    end)
    countText = header:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("RIGHT", collapseB, "LEFT", -4, 0)
    local line = T.Line(frame, C.line)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 1, 0)
    line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -1, 0)
    line:SetHeight(1)
    header.line = line

    moreText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moreText:SetPoint("LEFT", 10, 0)

    dropZone = CreateFrame("Button", nil, frame, "BackdropTemplate")
    dropZone:SetHeight(DROP_H - 6)
    dropZone:SetPoint("BOTTOMLEFT", 6, 6)
    dropZone:SetPoint("BOTTOMRIGHT", -6, 6)
    T.Backdrop(dropZone, nil, C.line)
    local dt = dropZone:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    dt:SetPoint("CENTER")
    dt:SetText("Drop an item here to farm it")
    dropZone:SetScript("OnReceiveDrag", takeCursorItem)
    dropZone:SetScript("OnClick", takeCursorItem) -- clicking with an item on the cursor drops it too
    dropZone:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(T.RGB(C.muted)) end)
    dropZone:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(T.RGB(C.line)) end)
end

-- Redraws the tracker (on farm changes, bag changes and when the setting changes).
function Tracker.Refresh()
    if LootwrightDB.tracker ~= true then
        if frame then frame:Hide() end
        return
    end
    if not ns.Data.Available() then return end
    if not frame then build() end
    local lines = collect()
    countText:SetText(#lines > 0 and tostring(#lines) or "")
    local collapsed = LootwrightDB.trackerCollapsed == true
    collapseB.text:SetText(collapsed and "+" or "-")
    local shown = collapsed and 0 or math.min(#lines, MAX_ROWS)
    for i = 1, shown do fillRow(rows[i] or makeRow(i), lines[i]) end
    for i = shown + 1, #rows do rows[i]:Hide() end
    local extra = (not collapsed and #lines > MAX_ROWS) and (#lines - MAX_ROWS) or 0
    moreText:SetShown(extra > 0)
    local h = HEAD_H
    if not collapsed then
        h = h + 4 + shown * ROW_H
        if extra > 0 then
            moreText:ClearAllPoints()
            moreText:SetPoint("TOPLEFT", 10, -h - 2)
            moreText:SetText("+" .. extra .. " more on the Farm tab")
            h = h + 16
        end
        h = h + DROP_H + 4
    end
    dropZone:SetShown(not collapsed)
    header.line:SetShown(not collapsed)
    frame:SetHeight(h)
    frame:Show()
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("BAG_UPDATE_DELAYED")
for _, ev in ipairs({ "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED" }) do
    pcall(f.RegisterEvent, f, ev) -- bank counts; an unknown event name would error
end
f:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        C_Timer.After(1, Tracker.Refresh) -- after QuestieDB is ready
    elseif frame and frame:IsShown() then
        Tracker.Refresh()
    end
end)
