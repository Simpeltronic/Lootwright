-- ItemFinder UI.lua: search window. Left: search box + item list. Right: sources of the selected item.
-- Works only with the plain tables from Data.GetSources. Out of combat only.

local _, ns = ...
local UI = {}
ns.UI = UI

local frame, searchBox, statusText, itemBox, mobBox, zoneBox
local headerIcon, headerName, summaryText, headerButtons
local selectedId, currentMobs = nil, {}
local sortKey, sortAsc = "rate", false
local searchToken, searchTimer = 0, nil

local MAX_ITEMS = 200
local RANK_COLORS = { [1] = "ffd100", [2] = "c0c0c0", [3] = "ff4040", [4] = "c0c0c0" }

-- Column x offsets / widths in the mob list.
local COLS = {
    { key = "name",  label = "Mob",   x = 4,   w = 170, justify = "LEFT" },
    { key = "level", label = "Level", x = 176, w = 44,  justify = "CENTER" },
    { key = "zone",  label = "Zone",  x = 222, w = 150, justify = "LEFT" },
    { key = "rate",  label = "Drop",  x = 374, w = 60,  justify = "RIGHT" },
}

----------------------------------------------------------------------
-- Helpers
----------------------------------------------------------------------
local function makeList(parent, rowHeight, initializer)
    local box = CreateFrame("Frame", nil, parent, "WowScrollBoxList")
    local bar = CreateFrame("EventFrame", nil, parent, "MinimalScrollBar")
    bar:SetPoint("TOPLEFT", box, "TOPRIGHT", 4, 0)
    bar:SetPoint("BOTTOMLEFT", box, "BOTTOMRIGHT", 4, 0)
    local view = CreateScrollBoxListLinearView()
    view:SetElementExtent(rowHeight)
    view:SetElementInitializer("Button", initializer)
    ScrollUtil.InitScrollBoxListWithScrollBar(box, bar, view)
    return box
end

local function rowBase(button)
    button:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
    button.sel = button:CreateTexture(nil, "BACKGROUND")
    button.sel:SetAllPoints()
    button.sel:SetColorTexture(1, 1, 1, 0.12)
    button.sel:Hide()
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function levelValue(r)
    return (r.minLevel and r.minLevel > 0) and r.minLevel or nil
end
local SORT_VALUE = {
    name = function(r) return r.name end,
    level = levelValue,
    zone = function(r) return r.zone end,
    rate = function(r) return r.rate end,
}

-- Unknown values always sort last; ties break by name, then NPC ID.
local function compareMobs(a, b)
    local va, vb = SORT_VALUE[sortKey](a), SORT_VALUE[sortKey](b)
    if (va == nil) ~= (vb == nil) then return va ~= nil end
    if va ~= nil and va ~= vb then
        if sortAsc then return va < vb end
        return va > vb
    end
    if a.name ~= b.name then return a.name < b.name end
    return a.npcId < b.npcId
end

----------------------------------------------------------------------
-- Mob list
----------------------------------------------------------------------
local function refreshMobs()
    local filter = zoneBox and zoneBox:GetText():lower() or ""
    local rows = {}
    for _, r in ipairs(currentMobs) do
        if filter == "" or r.zone:lower():find(filter, 1, true) then rows[#rows + 1] = r end
    end
    table.sort(rows, compareMobs)
    mobBox:SetDataProvider(CreateDataProvider(rows))
    for _, b in ipairs(headerButtons) do
        b.text:SetText(b.col.label .. (b.col.key == sortKey and (sortAsc and " ^" or " v") or ""))
    end
end

local function initMobRow(button, r)
    if not button.cells then
        rowBase(button)
        button.cells = {}
        for i, col in ipairs(COLS) do
            local fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", col.x, 0)
            fs:SetWidth(col.w)
            fs:SetJustifyH(col.justify)
            fs:SetWordWrap(false)
            button.cells[i] = fs
        end
        button:SetScript("OnEnter", function(self)
            local m = self.mob
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.name)
            GameTooltip:AddLine("NPC ID " .. m.npcId, 0.7, 0.7, 0.7)
            if m.zones > 1 then GameTooltip:AddLine("Spawns in " .. m.zones .. " zones", 1, 1, 1) end
            if m.rate then
                GameTooltip:AddLine("Drop rate from " .. (m.source or "?") .. " data", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("No drop rate in the database", 0.7, 0.7, 0.7)
            end
            GameTooltip:Show()
        end)
    end
    button.mob = r
    local rank = ns.RANKS[r.rank] or ""
    local name = r.name
    if rank ~= "" then name = name .. " |cff" .. (RANK_COLORS[r.rank] or "ffffff") .. "(" .. rank .. ")|r" end
    button.cells[1]:SetText(name)
    button.cells[2]:SetText(ns.LevelText(r.minLevel, r.maxLevel))
    button.cells[3]:SetText(r.zone .. (r.zones > 1 and (" |cff999999+" .. (r.zones - 1) .. "|r") or ""))
    button.cells[4]:SetText(r.rate and ns.RateText(r.rate) or "|cff999999?|r")
end

----------------------------------------------------------------------
-- Item selection
----------------------------------------------------------------------
local function selectItem(itemId)
    selectedId = itemId
    itemBox:ForEachFrame(function(b) b.sel:SetShown(b.itemId == selectedId) end)

    local name = ns.Data.ItemName(itemId) or ("item " .. itemId)
    headerIcon:SetTexture(C_Item.GetItemIconByID(itemId) or 134400)
    headerName:SetText(name)
    -- Colour by quality once the client has the item cached.
    Item:CreateFromItemID(itemId):ContinueOnItemLoad(function()
        if selectedId ~= itemId then return end
        local link = select(2, C_Item.GetItemInfo(itemId))
        if link then headerName:SetText(link) end
    end)

    local src = ns.Data.GetSources(itemId)
    currentMobs = src.mobs
    local parts = { #src.mobs .. " mob(s)" }
    if src.objects > 0 then parts[#parts + 1] = src.objects .. " object(s)" end
    if src.vendors > 0 then parts[#parts + 1] = src.vendors .. " vendor(s)" end
    local note = ""
    if #src.mobs == 0 then
        note = "  |cff999999No mob drops recorded.|r"
    elseif src.fromDropTable then
        note = "  |cff999999(mob list from QuestieDB's quest-item drop table)|r"
    end
    summaryText:SetText("ID " .. itemId .. "  -  " .. table.concat(parts, ", ") .. note)
    refreshMobs()
end

----------------------------------------------------------------------
-- Search
----------------------------------------------------------------------
local function initItemRow(button, data)
    if not button.text then
        rowBase(button)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetPoint("LEFT", 4, 0)
        button.text:SetPoint("RIGHT", -4, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetWordWrap(false)
        button:SetScript("OnClick", function(self) selectItem(self.itemId) end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemId)
            GameTooltip:Show()
        end)
    end
    button.itemId = data.id
    button.text:SetText(data.name .. " |cff777777#" .. data.id .. "|r")
    button.sel:SetShown(data.id == selectedId)
end

local function runSearch(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    searchToken = searchToken + 1
    local token = searchToken
    if #text < 2 then
        itemBox:SetDataProvider(CreateDataProvider({}))
        statusText:SetText("Type at least 2 letters, or shift-click an item.")
        return
    end
    if not ns.Data.Available() then
        statusText:SetText("|cffff4040QuestieDB is not available.|r")
        return
    end
    if not ns.Search.IsBuilt() then statusText:SetText("Building item index...") end
    ns.Search.Find(text, function(ids, nExact)
        if token ~= searchToken then return end -- a newer search replaced this one
        local list = {}
        for i = 1, math.min(#ids, MAX_ITEMS) do list[i] = { id = ids[i], name = ns.Search.Name(ids[i]) } end
        itemBox:SetDataProvider(CreateDataProvider(list))
        if #ids == 0 then
            statusText:SetText("No items match.")
        else
            statusText:SetText(#ids .. " match(es)" .. (#ids > MAX_ITEMS and (", showing " .. MAX_ITEMS) or ""))
        end
        if nExact >= 1 or #ids == 1 then selectItem(ids[1]) end
    end)
end

-- Shift-clicking an item while the search box has focus looks it up directly.
local function onInsertLink(link)
    if not (frame and frame:IsShown() and searchBox:HasFocus() and type(link) == "string") then return end
    local id = tonumber(link:match("|Hitem:(%d+)"))
    if not id then return end
    searchBox:SetText(ns.Data.ItemName(id) or "")
    searchBox:ClearFocus()
    runSearch(searchBox:GetText())
    selectItem(id)
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
local function build()
    frame = CreateFrame("Frame", "ItemFinderFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:SetSize(720, 440)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ItemFinderFrame") -- Escape closes it

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("ItemFinder")

    -- Left: search
    searchBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    searchBox:SetSize(214, 20)
    searchBox:SetPoint("TOPLEFT", 18, -32)
    searchBox:SetAutoFocus(false)
    searchBox:HookScript("OnTextChanged", function(self, userInput)
        if not userInput then return end
        if searchTimer then searchTimer:Cancel() end
        searchTimer = C_Timer.NewTimer(0.3, function() runSearch(self:GetText()) end)
    end)
    searchBox:HookScript("OnEnterPressed", function(self)
        if searchTimer then searchTimer:Cancel() end
        runSearch(self:GetText())
        self:ClearFocus()
    end)

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -4)
    statusText:SetWidth(226)
    statusText:SetJustifyH("LEFT")
    statusText:SetText("Type at least 2 letters, or shift-click an item.")

    itemBox = makeList(frame, 18, initItemRow)
    itemBox:SetPoint("TOPLEFT", 12, -72)
    itemBox:SetPoint("BOTTOMLEFT", 12, 12)
    itemBox:SetWidth(222)

    -- Right: selected item
    headerIcon = frame:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(28, 28)
    headerIcon:SetPoint("TOPLEFT", 260, -30)
    headerIcon:SetTexture(134400) -- question mark

    headerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerName:SetPoint("TOPLEFT", headerIcon, "TOPRIGHT", 8, -1)
    headerName:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    headerName:SetJustifyH("LEFT")
    headerName:SetText("Search for an item")

    summaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summaryText:SetPoint("TOPLEFT", headerIcon, "BOTTOMRIGHT", 8, 10)
    summaryText:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    summaryText:SetJustifyH("LEFT")

    -- Same template as the item search box: InputBoxTemplate didn't take keyboard input on Forever.
    zoneBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    zoneBox:SetSize(160, 20)
    zoneBox:SetPoint("TOPLEFT", 266, -68)
    zoneBox:SetAutoFocus(false)
    if zoneBox.Instructions then zoneBox.Instructions:SetText("Filter by zone") end
    zoneBox:HookScript("OnTextChanged", function() if selectedId then refreshMobs() end end)
    zoneBox:HookScript("OnEnterPressed", zoneBox.ClearFocus)

    -- Column headers (click to sort)
    headerButtons = {}
    for _, col in ipairs(COLS) do
        local b = CreateFrame("Button", nil, frame)
        b:SetSize(col.w, 16)
        b:SetPoint("TOPLEFT", 256 + col.x, -94)
        b.col = col
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        b.text:SetAllPoints()
        b.text:SetJustifyH(col.justify)
        b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
        b:SetScript("OnClick", function()
            if sortKey == col.key then
                sortAsc = not sortAsc
            else
                sortKey, sortAsc = col.key, col.key ~= "rate" -- rate: highest first; others: A-Z / low-high
            end
            refreshMobs()
        end)
        headerButtons[#headerButtons + 1] = b
    end

    mobBox = makeList(frame, 18, initMobRow)
    mobBox:SetPoint("TOPLEFT", 256, -112)
    mobBox:SetPoint("BOTTOMRIGHT", -30, 30)

    local foot = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 260, 12)
    foot:SetPoint("BOTTOMRIGHT", -16, 12)
    foot:SetJustifyH("LEFT")
    foot:SetText("Drop rates from Questie / QuestieDB data. Most non-quest items have no known rate.")

    refreshMobs()

    -- Shift-click hooks (the name moved between client versions; hook whichever exists).
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink) end
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", onInsertLink) end

    -- Keep the window out of combat.
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(self) self:Hide() end)
end

function UI.Toggle()
    if InCombatLockdown() then ns.say("The window can't be opened in combat."); return end
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then searchBox:SetFocus() end
end
