-- Lootwright UI.lua: search window. Left: search box + item list. Right: sources of the selected item.
-- Works only with the plain tables from Data.GetSources. Out of combat only.

local _, ns = ...
local UI = {}
ns.UI = UI

local frame, searchBox, statusText, itemBox, mobBox, zoneBox
local headerIcon, headerName, summaryText, headerButtons
local selectedId, currentMobs = nil, {}
local sortKey, sortAsc = "rate", false
local searchToken, searchTimer = 0, nil

local TABS = {
    { key = "search", label = "Search" },
    { key = "prof", label = "Professions" },
    { key = "farm", label = "Farm" },
}
local pages, tabButtons = {}, {}

local MAX_ITEMS = 200
local RANK_COLORS = { [1] = "ffd100", [2] = "c0c0c0", [3] = "ff4040", [4] = "c0c0c0" }

-- Column x offsets / widths in the mob list.
local COLS = {
    { key = "name",  label = "MOB",   x = 4,   w = 170, justify = "LEFT" },
    { key = "level", label = "LVL",   x = 176, w = 40,  justify = "LEFT" },
    { key = "zone",  label = "ZONE",  x = 218, w = 124, justify = "LEFT" },
    { key = "rate",  label = "DROP",  x = 346, w = 88,  justify = "LEFT" },
}
local BAR_W = 40 -- drop-rate bar inside the DROP column, the percentage to its right

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
    ns.Theme.StyleRow(button)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

UI.MakeList, UI.RowBase = makeList, rowBase -- shared with ProfUI.lua

local function levelValue(r)
    return (r.minLevel and r.minLevel > 0) and r.minLevel or nil
end
local SORT_VALUE = {
    name = function(r) return r.name end,
    level = levelValue,
    zone = function(r) return r.zone end,
    rate = function(r) return r.rate end,
}

local hereZone -- player's zone name, refreshed on each list refresh

-- Mobs in the player's zone first; then the chosen column. Unknown values always sort last;
-- ties break by name, then NPC ID.
local function compareMobs(a, b)
    if hereZone then
        local ia, ib = a.zone == hereZone, b.zone == hereZone
        if ia ~= ib then return ia end
    end
    if sortKey == "rate" then
        -- Real rates, then few-kill rates, then unknown, whatever the direction.
        local ta, tb = ns.RateTier(a), ns.RateTier(b)
        if ta ~= tb then return ta < tb end
    end
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
-- Filters (settings in LootwrightDB: showFriendly, nearLevel; both off by default)
----------------------------------------------------------------------
-- True when the mob is friendly to the player's faction (so it can't be attacked).
local function isFriendly(r)
    local f = UnitFactionGroup("player")
    local key = (f == "Alliance" and "A") or (f == "Horde" and "H") or nil
    return key ~= nil and type(r.friendly) == "string" and r.friendly:find(key, 1, true) ~= nil
end

local NEAR_LEVELS = 5
-- True when the mob's level range overlaps player level +/- NEAR_LEVELS. Unknown levels count as near.
local function isNearLevel(r)
    local lo = r.minLevel
    if not lo or lo == 0 then return true end
    local hi = (r.maxLevel and r.maxLevel > 0) and r.maxLevel or lo
    local pl = UnitLevel("player")
    return hi >= pl - NEAR_LEVELS and lo <= pl + NEAR_LEVELS
end

local function passesFilters(r)
    if not LootwrightDB.showFriendly and isFriendly(r) then return false end
    if LootwrightDB.nearLevel and not isNearLevel(r) then return false end
    return true
end

----------------------------------------------------------------------
-- Mob list
----------------------------------------------------------------------
local filterText -- "N hidden by filters"

local function refreshMobs()
    hereZone = GetRealZoneText()
    if hereZone == "" then hereZone = nil end
    local filter = zoneBox and zoneBox:GetText():lower() or ""
    local rows, hidden = {}, 0
    for _, r in ipairs(currentMobs) do
        if (filter == "" or r.zone:lower():find(filter, 1, true)) and passesFilters(r) then
            rows[#rows + 1] = r
        else
            hidden = hidden + 1
        end
    end
    table.sort(rows, compareMobs)
    mobBox:SetDataProvider(CreateDataProvider(rows))
    filterText:SetText(hidden > 0 and (hidden .. " hidden by filters") or "")
    for _, b in ipairs(headerButtons) do
        b.text:SetText(b.col.label .. (b.col.key == sortKey and (sortAsc and " ^" or " v") or ""))
    end
end

-- Same colours the game uses for mob difficulty (grey / green / yellow / orange / red).
local function levelColor(level)
    local fn = _G.GetCreatureDifficultyColor or _G.GetQuestDifficultyColor
    if not level or not fn then return 1, 1, 1 end
    local c = fn(level)
    if type(c) ~= "table" then return 1, 1, 1 end
    return c.r, c.g, c.b
end

local function rateColor(rate)
    if not rate then return 0.6, 0.6, 0.6 end
    if rate >= 25 then return 0.25, 1, 0.25 end
    if rate >= 5 then return 1, 0.82, 0 end
    return 1, 0.5, 0.25
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
        -- Drop-rate bar: a dark track and a coloured fill; the percentage moves right of it.
        local x = COLS[4].x
        button.track = button:CreateTexture(nil, "ARTWORK")
        button.track:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.track:SetVertexColor(0.15, 0.17, 0.20)
        button.track:SetSize(BAR_W, 5)
        button.track:SetPoint("LEFT", x, 0)
        button.fill = button:CreateTexture(nil, "OVERLAY")
        button.fill:SetTexture("Interface\\Buttons\\WHITE8x8")
        button.fill:SetHeight(5)
        button.fill:SetPoint("LEFT", button.track, "LEFT")
        button.cells[4]:ClearAllPoints()
        button.cells[4]:SetPoint("LEFT", x + BAR_W + 6, 0)
        button.cells[4]:SetWidth(COLS[4].w - BAR_W - 6)
        button:SetScript("OnEnter", function(self)
            local m = self.mob
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.name)
            GameTooltip:AddLine("NPC ID " .. m.npcId, 0.7, 0.7, 0.7)
            if m.zones > 1 then GameTooltip:AddLine("Spawns in " .. m.zones .. " zones", 1, 1, 1) end
            if m.kills and m.kills > 0 then
                GameTooltip:AddLine("Measured in Forever over " .. m.kills .. " kills (ForeverDB.net)",
                    m.fewKills and 1 or 0.7, m.fewKills and 0.5 or 0.7, m.fewKills and 0.25 or 0.7)
            elseif m.fewKills then
                GameTooltip:AddLine("* Rate from very few kills (10 or fewer), unreliable", 1, 0.5, 0.25)
            elseif m.rate then
                GameTooltip:AddLine("Drop rate from " .. (m.source or "?") .. " data", 0.7, 0.7, 0.7)
            else
                GameTooltip:AddLine("No drop rate in the database", 0.7, 0.7, 0.7)
            end
            -- Other farm items this mob drops.
            for _, e in ipairs(ns.Farm.ForNpc(m.npcId) or {}) do
                if e.itemId ~= selectedId then GameTooltip:AddLine("Farm: " .. ns.Farm.Line(e), 0.25, 1, 0.25) end
            end
            GameTooltip:AddLine("Click: show spawns on the world map", 0.2, 1, 0.6)
            GameTooltip:Show()
        end)
        button:SetScript("OnClick", function(self) ns.Map.ShowMob(self.mob) end)
    end
    button.mob = r
    local rank = ns.RANKS[r.rank] or ""
    local name = r.name
    if rank ~= "" then name = name .. " |cff" .. (RANK_COLORS[r.rank] or "ffffff") .. "(" .. rank .. ")|r" end
    button.cells[1]:SetText(name)
    button.cells[2]:SetText(ns.LevelText(r.minLevel, r.maxLevel))
    button.cells[2]:SetTextColor(levelColor(levelValue(r)))
    local zone = r.zone == hereZone and ("|cff40ff40" .. r.zone .. "|r") or r.zone
    button.cells[3]:SetText(zone .. (r.zones > 1 and (" |cff999999+" .. (r.zones - 1) .. "|r") or ""))
    button.cells[4]:SetText(r.rate and ns.RateText(r.rate, r.fewKills) or "?")
    local cr, cg, cb = rateColor(not r.fewKills and r.rate or nil) -- few kills: grey
    button.cells[4]:SetTextColor(cr, cg, cb)
    if r.rate and r.rate > 0 then
        button.fill:SetWidth(math.max(1, BAR_W * math.min(r.rate, 100) / 100))
        button.fill:SetVertexColor(cr, cg, cb)
        button.fill:Show()
    else
        button.fill:Hide()
    end
end

----------------------------------------------------------------------
-- Item selection
----------------------------------------------------------------------
local MAX_RECENT = 10

-- Recently selected item IDs, newest first, kept in SavedVariables.
local function recentList()
    LootwrightDB.recent = LootwrightDB.recent or {}
    return LootwrightDB.recent
end

local function pushRecent(itemId)
    local list = recentList()
    for i = #list, 1, -1 do
        if list[i] == itemId then table.remove(list, i) end
    end
    table.insert(list, 1, itemId)
    for i = #list, MAX_RECENT + 1, -1 do list[i] = nil end
end

-- Favourite item IDs: LootwrightDB.favorites[itemId] = true.
local function favorites()
    LootwrightDB.favorites = LootwrightDB.favorites or {}
    return LootwrightDB.favorites
end

local favButton, farmButton
local function updateFavButton()
    favButton:SetShown(selectedId ~= nil)
    favButton:SetText(selectedId and favorites()[selectedId] and "Unfavorite" or "Favorite")
    farmButton:SetShown(selectedId ~= nil)
    -- "Farming 12/40" for items on the list (click to change the goal or stop), else "Farm...".
    if selectedId and ns.Farm.IsSingle(selectedId) then
        local goal = ns.Farm.Goal(selectedId)
        farmButton:SetText("Farming " .. ns.Farm.Have(selectedId) .. (goal and ("/" .. goal) or ""))
    else
        farmButton:SetText("Farm...")
    end
end

-- Item-list order: farm items (green), then favourites (gold), then the rest.
local function itemGroup(id)
    if ns.Farm.Has(id) then return 0 end
    if favorites()[id] then return 1 end
    return 2
end

local function selectItem(itemId)
    selectedId = itemId
    pushRecent(itemId)
    updateFavButton()
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
        note = "  |cff999999(quest-item drop table)|r" -- short: the summary has one line
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
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(18, 18)
        button.icon:SetPoint("LEFT", 2, 0)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's built-in border
        button.tag = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        button.tag:SetPoint("RIGHT", -4, 0)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.text:SetPoint("LEFT", button.icon, "RIGHT", 6, 0)
        button.text:SetPoint("RIGHT", button.tag, "LEFT", -4, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetWordWrap(false)
        button:SetScript("OnClick", function(self) selectItem(self.itemId) end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemId)
            local uses = UI.UsedInRecipes(self.itemId)
            if uses > 0 then GameTooltip:AddLine("Used in " .. uses .. " recipe(s)", 0.4, 0.8, 1) end
            GameTooltip:AddLine("Item ID " .. self.itemId, 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
    end
    button.itemId, button.data = data.id, data
    button.icon:SetTexture(C_Item.GetItemIconByID(data.id) or 134400)
    local g = itemGroup(data.id)
    local name = (g == 0 and ("|cff4fd36a" .. data.name .. "|r")) or (g == 1 and ("|cffffd100" .. data.name .. "|r"))
        or data.name
    button.text:SetText(name)
    -- Reagents show how many recipes use them: the addon's main selling point, so it's on every row.
    local uses = UI.UsedInRecipes(data.id)
    button.tag:SetText(uses > 0 and tostring(uses) or "")
    button.sel:SetShown(data.id == selectedId)
end

-- Search filters. Every item has exactly one kind (reagent, quest, gear, other); Dungeon is a separate
-- box about where it drops. Settings LootwrightDB.hideReagent / hideQuest / hideGear / hideOther /
-- hideDungeon are all off by default, so every box starts ticked: ticked = shown (user's rule).
-- GetItemInfoInstant answers from the client's item table, so it works for items never seen.
local IC = Enum.ItemClass or {}
local QUEST_CLASS, WEAPON_CLASS, ARMOR_CLASS = IC.Questitem or 12, IC.Weapon or 2, IC.Armor or 4
local TRADE_CLASS, REAGENT_CLASS = IC.Tradegoods or 7, IC.Reagent or 5

local function hasDungeonData()
    local gen = ns.GetGen()
    return gen ~= nil and gen.bossLoot ~= nil
end

-- [itemId] = number of ForeverDB recipes that use it, built once.
local recipeUses
local function usedInRecipes(id)
    if not recipeUses then
        recipeUses = {}
        local gen = ns.GetGen()
        for _, rows in pairs(gen and gen.recipes or {}) do
            for _, r in ipairs(rows) do
                for rid in tostring(r[6] or ""):gmatch("(%d+):") do
                    rid = tonumber(rid)
                    recipeUses[rid] = (recipeUses[rid] or 0) + 1
                end
            end
        end
    end
    return recipeUses[id] or 0
end
UI.UsedInRecipes = usedInRecipes

-- "reagent", "quest", "gear" or "other"; checked in that order.
local function itemKind(id)
    if usedInRecipes(id) > 0 then return "reagent" end
    local classID = select(6, C_Item.GetItemInfoInstant(id))
    if classID == TRADE_CLASS or classID == REAGENT_CLASS then return "reagent" end
    if classID == QUEST_CLASS then return "quest" end
    if classID == WEAPON_CLASS or classID == ARMOR_CLASS then return "gear" end
    return "other"
end

local HIDE_KEY = { reagent = "hideReagent", quest = "hideQuest", gear = "hideGear", other = "hideOther" }

local function itemPassesFilters(id)
    local db = LootwrightDB
    if db.hideReagent or db.hideQuest or db.hideGear or db.hideOther then
        if db[HIDE_KEY[itemKind(id)]] then return false end
    end
    if db.hideDungeon and hasDungeonData() and ns.GetGen().bossLoot[id] then return false end
    return true
end

-- After a farm/favourite change: rebuild the empty-search list, or recolour the visible result rows
-- (rows are coloured when drawn, so they'd keep the old green/gold otherwise).
local runSearch
local function refreshItemRows()
    if #searchBox:GetText() < 2 then
        runSearch("")
    else
        itemBox:ForEachFrame(function(b) if b.data then initItemRow(b, b.data) end end)
    end
end

function runSearch(text)
    text = (text or ""):match("^%s*(.-)%s*$")
    searchToken = searchToken + 1
    local token = searchToken
    if not ns.Data.Available() then
        statusText:SetText("|cffff4040QuestieDB is not available.|r")
        return
    end
    if #text < 2 then
        -- Empty search: farm items (green), favourites (gold), each by name; then recent items.
        local list, seen = {}, {}
        local function add(id)
            if seen[id] then return end
            seen[id] = true
            list[#list + 1] = { id = id, name = ns.Data.ItemName(id) or ("item " .. id) }
        end
        for _, id in ipairs(ns.Farm.Ids()) do add(id) end
        for id in pairs(favorites()) do add(id) end
        table.sort(list, function(a, b)
            local ga, gb = itemGroup(a.id), itemGroup(b.id)
            if ga ~= gb then return ga < gb end
            return a.name < b.name
        end)
        for _, id in ipairs(recentList()) do add(id) end
        itemBox:SetDataProvider(CreateDataProvider(list))
        statusText:SetText(#list > 0 and "Farm, favorites and recent items" or "Type 2+ letters, or shift-click an item")
        return
    end
    if not ns.Search.IsBuilt() then statusText:SetText("Building item index...") end
    ns.Search.Find(text, function(all, allExact)
        if token ~= searchToken then return end -- a newer search replaced this one
        -- Search filters, over all matches; exact-name matches stay first.
        local ids, nExact = {}, 0
        for i, id in ipairs(all) do
            if itemPassesFilters(id) then
                ids[#ids + 1] = id
                if i <= allExact then nExact = nExact + 1 end
            end
        end
        local hidden = #all - #ids
        -- Matching farm items, then favourites first, from all matches, not only the first MAX_ITEMS.
        local list = {}
        for group = 0, 2 do
            for _, id in ipairs(ids) do
                if group == 2 and #list >= MAX_ITEMS then break end
                if itemGroup(id) == group then list[#list + 1] = { id = id, name = ns.Search.Name(id) } end
            end
        end
        itemBox:SetDataProvider(CreateDataProvider(list))
        -- Kept short: the status line has one line of room above the filter pills.
        local hiddenText = hidden > 0 and (", " .. hidden .. " hidden") or ""
        if #ids == 0 then
            statusText:SetText("No matches" .. hiddenText)
        else
            statusText:SetText(#ids .. " matches" .. (#ids > MAX_ITEMS and (", " .. MAX_ITEMS .. " shown") or "") .. hiddenText)
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
    local T, C = ns.Theme, ns.Theme.C
    frame = CreateFrame("Frame", "LootwrightFrame", UIParent, "BackdropTemplate")
    frame:Hide() -- new frames start shown; Toggle decides
    frame:SetSize(720, 466) -- 26 px taller than before: the header is taller than the old title bar
    frame:SetPoint("CENTER")
    T.Backdrop(frame, C.bg, C.line, 0.97)
    frame:SetFrameStrata("HIGH")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "LootwrightFrame") -- Escape closes it

    -- Header: emblem, name and tagline; tab pills, Options and close on the right; a brass line
    -- under the emblem as the one warm accent.
    local emblem = frame:CreateTexture(nil, "ARTWORK")
    emblem:SetSize(34, 34)
    emblem:SetPoint("TOPLEFT", 12, -8)
    emblem:SetTexture(T.MEDIA .. "emblem")
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", emblem, "TOPRIGHT", 8, -2)
    title:SetTextColor(T.RGB(C.white))
    title:SetText("Lootwright")
    local tagline = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    tagline:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 1, -2)
    tagline:SetText("Find any item. Farm what you need.")
    local headLine = T.Line(frame, C.line)
    headLine:SetPoint("TOPLEFT", 1, -50)
    headLine:SetPoint("TOPRIGHT", -1, -50)
    headLine:SetHeight(1)

    local close = CreateFrame("Button", nil, frame)
    close:SetSize(22, 22)
    close:SetPoint("TOPRIGHT", -8, -14)
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    x:SetPoint("CENTER")
    x:SetText("×")
    x:SetTextColor(T.RGB(C.muted))
    close:SetScript("OnEnter", function() x:SetTextColor(T.RGB(C.white)) end)
    close:SetScript("OnLeave", function() x:SetTextColor(T.RGB(C.muted)) end)
    close:SetScript("OnClick", function() frame:Hide() end)

    local optB = T.Button(frame, "Options", 64, 20)
    optB:SetPoint("RIGHT", close, "LEFT", -8, 0)
    optB:SetScript("OnClick", function() ns.Options.Open() end)

    -- One page per tab, below the header. Page content keeps its old offsets: the pages simply
    -- start 26 px lower than before, which the taller frame makes up for.
    for _, t in ipairs(TABS) do
        local pg = CreateFrame("Frame", nil, frame)
        pg:SetPoint("TOPLEFT", 0, -26)
        pg:SetPoint("BOTTOMRIGHT", 0, 0)
        pg:Hide()
        pages[t.key] = pg
    end
    local page = pages.search

    -- Header text tabs (design choice B): bigger text, the active one white with a brass underline
    -- sitting on the header line. Left to right from x = 300.
    local prevTab
    for _, t in ipairs(TABS) do
        local b = T.TextTab(frame, t.label)
        if prevTab then
            b:SetPoint("BOTTOMLEFT", prevTab, "BOTTOMRIGHT", 20, 0)
        else
            b:SetPoint("BOTTOMLEFT", frame, "TOPLEFT", 300, -50)
        end
        b:SetScript("OnClick", function() UI.ShowTab(t.key) end)
        tabButtons[t.key] = b
        prevTab = b
    end

    -- Left: search
    searchBox = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
    searchBox:SetSize(214, 20)
    searchBox:SetPoint("TOPLEFT", 18, -32)
    searchBox:SetAutoFocus(false)
    searchBox:HookScript("OnTextChanged", function(self, userInput)
        -- The clear (x) button sets "" without userInput; still show the recent list then.
        if not userInput and self:GetText() ~= "" then return end
        if searchTimer then searchTimer:Cancel() end
        searchTimer = C_Timer.NewTimer(0.3, function() runSearch(self:GetText()) end)
    end)
    searchBox:HookScript("OnEnterPressed", function(self)
        if searchTimer then searchTimer:Cancel() end
        runSearch(self:GetText())
        self:ClearFocus()
    end)
    T.StyleEditBox(searchBox)

    statusText = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -4)
    statusText:SetWidth(226)
    statusText:SetJustifyH("LEFT")
    statusText:SetWordWrap(false) -- one line only; a second line would run into the filter pills

    -- Search filter pills: a pill that is on means that kind of item is shown (user's rule: turning
    -- one on only ever adds items). All start on. Settings are the hide* keys, so on = not hidden.
    local function filterPill(label, key, tip, anchor, top)
        local p = T.Pill(page, label, "filter")
        if anchor then p:SetPoint("LEFT", anchor, "RIGHT", 4, 0) else p:SetPoint("TOPLEFT", 12, top) end
        p:SetOn(LootwrightDB[key] ~= true)
        p:SetScript("OnClick", function(self)
            LootwrightDB[key] = self.on -- was on (shown): now hidden, and the other way round
            self:SetOn(not self.on)
            runSearch(searchBox:GetText())
        end)
        p:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        p:HookScript("OnLeave", function() GameTooltip:Hide() end)
        return p
    end
    -- Row 1: what the item is. Row 2: the rest, and where it drops.
    local reagentPill = filterPill("Reagents", "hideReagent",
        "Show crafting materials: anything used in a recipe, plus trade goods (cloth, leather, herbs, ore, meat...).",
        nil, -70)
    local questPill = filterPill("Quest", "hideQuest", "Show quest items.", reagentPill)
    filterPill("Gear", "hideGear", "Show equipment (weapons and armor).", questPill)
    local otherPill = filterPill("Other", "hideOther", "Show everything else: potions, food, containers, junk...",
        nil, -92)
    local dungeonPill = filterPill("Dungeon", "hideDungeon",
        "Show items that dungeon or raid bosses drop (ForeverDB boss loot; normal dungeon mobs aren't covered).",
        otherPill)
    if not hasDungeonData() then dungeonPill:Hide() end -- needs Lootwright_Data

    itemBox = makeList(page, 22, initItemRow)
    itemBox:SetPoint("TOPLEFT", 12, -116)
    itemBox:SetPoint("BOTTOMLEFT", 12, 12)
    itemBox:SetWidth(222)
    runSearch("") -- recent items

    -- Right: selected item
    headerIcon = page:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(28, 28)
    headerIcon:SetPoint("TOPLEFT", 260, -30)
    headerIcon:SetTexture(134400) -- question mark

    headerName = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    headerName:SetPoint("TOPLEFT", headerIcon, "TOPRIGHT", 8, -1)
    headerName:SetPoint("RIGHT", frame, "RIGHT", -216, 0) -- clear of the Farm and Favorite buttons
    headerName:SetJustifyH("LEFT")
    headerName:SetWordWrap(false)
    headerName:SetText("Search for an item")

    favButton = T.Button(page, "Favorite", 84, 22)
    favButton:SetPoint("TOPRIGHT", -14, -30)
    favButton:SetScript("OnClick", function()
        if not selectedId then return end
        local favs = favorites()
        favs[selectedId] = not favs[selectedId] or nil
        updateFavButton()
        refreshItemRows()
    end)

    farmButton = T.Button(page, "Farm...", 104, 22)
    farmButton:SetPoint("RIGHT", favButton, "LEFT", -6, 0)
    -- Opens the amount popup (FarmPopup.lua), where you set the goal, farm with no goal, or stop.
    farmButton:SetScript("OnClick", function(self)
        if selectedId then ns.FarmPopup.Open(selectedId, self) end
    end)
    farmButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Farm list", 1, 1, 1)
        GameTooltip:AddLine("Choose how many you want. Mobs that drop it get a \"Farm:\" line on their "
            .. "tooltip and a skull on the map until your bags hold that many.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    farmButton:HookScript("OnLeave", function() GameTooltip:Hide() end)
    updateFavButton()

    summaryText = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    summaryText:SetPoint("TOPLEFT", headerIcon, "BOTTOMRIGHT", 8, 10)
    summaryText:SetPoint("RIGHT", frame, "RIGHT", -216, 0) -- leave room for the Farm/Favorite buttons
    summaryText:SetJustifyH("LEFT")
    summaryText:SetWordWrap(false) -- one line: a wrapped summary ran into the zone filter below it

    -- Same template as the item search box: InputBoxTemplate didn't take keyboard input on Forever.
    zoneBox = CreateFrame("EditBox", nil, page, "SearchBoxTemplate")
    zoneBox:SetSize(160, 20)
    zoneBox:SetPoint("TOPLEFT", 266, -68)
    zoneBox:SetAutoFocus(false)
    if zoneBox.Instructions then zoneBox.Instructions:SetText("Filter by zone") end
    zoneBox:HookScript("OnTextChanged", function() if selectedId then refreshMobs() end end)
    zoneBox:HookScript("OnEnterPressed", zoneBox.ClearFocus)
    T.StyleEditBox(zoneBox)

    local clearPins = T.Button(page, "Clear pins", 76, 20)
    clearPins:SetPoint("LEFT", zoneBox, "RIGHT", 10, 0)
    clearPins:SetScript("OnClick", function() ns.Map.Clear() end)

    -- Mob filter pills (on = the filter is active; these narrow the mob list, unlike the item pills).
    local function mobPill(label, key, tip, anchor)
        local p = T.Pill(page, label, "filter")
        p:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
        p:SetOn(LootwrightDB[key] == true)
        p:SetScript("OnClick", function(self)
            self:SetOn(not self.on)
            LootwrightDB[key] = self.on
            UI.ClearTooltipCache()
            refreshMobs()
        end)
        p:HookScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        p:HookScript("OnLeave", function() GameTooltip:Hide() end)
        return p
    end
    local nearPill = mobPill("Near lvl", "nearLevel", "Only mobs within " .. NEAR_LEVELS .. " levels of you.", clearPins)
    mobPill("Friendly", "showFriendly", "Also show mobs friendly to your faction (you can't attack them).", nearPill)

    -- Column headers (click to sort)
    headerButtons = {}
    for _, col in ipairs(COLS) do
        local b = CreateFrame("Button", nil, page)
        b:SetSize(col.w, 16)
        b:SetPoint("TOPLEFT", 256 + col.x, -94)
        b.col = col
        b.text = b:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        b.text:SetAllPoints()
        b.text:SetJustifyH(col.justify)
        b:SetHighlightTexture("Interface\\Buttons\\WHITE8x8", "ADD")
        b:GetHighlightTexture():SetVertexColor(1, 1, 1, 0.05)
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

    local tableLine = T.Line(page, C.line)
    tableLine:SetPoint("TOPLEFT", 256, -110)
    tableLine:SetPoint("TOPRIGHT", -14, -110)
    tableLine:SetHeight(1)
    local colLine = T.Line(page, C.line) -- between the item list and the item details
    colLine:SetPoint("TOPLEFT", 250, 0)
    colLine:SetPoint("BOTTOMLEFT", 250, 0)
    colLine:SetWidth(1)

    mobBox = makeList(page, 20, initMobRow)
    mobBox:SetPoint("TOPLEFT", 256, -112)
    mobBox:SetPoint("BOTTOMRIGHT", -30, 30)

    local foot = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    foot:SetPoint("BOTTOMLEFT", 260, 12)
    foot:SetJustifyH("LEFT")
    foot:SetText("Rates: QuestieDB and ForeverDB.net data. * = very few kills.")

    filterText = page:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterText:SetPoint("BOTTOMRIGHT", -16, 12)
    filterText:SetJustifyH("RIGHT")

    refreshMobs()

    -- The Professions tab comes from the optional Lootwright_Professions sub-addon.
    if ns.ProfUI then
        ns.ProfUI.Build(pages.prof)
    else
        tabButtons.prof:Hide()
        tabButtons.farm:ClearAllPoints()
        tabButtons.farm:SetPoint("BOTTOMLEFT", tabButtons.search, "BOTTOMRIGHT", 20, 0)
    end
    ns.FarmUI.Build(pages.farm)

    -- Shift-click hooks (the name moved between client versions; hook whichever exists).
    if ChatFrameUtil and ChatFrameUtil.InsertLink then hooksecurefunc(ChatFrameUtil, "InsertLink", onInsertLink) end
    if ChatEdit_InsertLink then hooksecurefunc("ChatEdit_InsertLink", onInsertLink) end

    -- Keep the window out of combat.
    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:SetScript("OnEvent", function(self) self:Hide() end)
end

----------------------------------------------------------------------
-- Item tooltip line: "Drops from: A 45.0%, B 30.0%, C +12 more"
----------------------------------------------------------------------
local tipCache = {} -- [itemId] = text, or false when no mobs drop it

local function tooltipText(itemId)
    if tipCache[itemId] ~= nil then return tipCache[itemId] end
    local ok, src = pcall(ns.Data.GetSources, itemId)
    if not ok then return nil end -- don't cache errors
    local mobs = {}
    for _, m in ipairs(src.mobs) do
        if passesFilters(m) then mobs[#mobs + 1] = m end
    end
    table.sort(mobs, ns.SortByRate)
    local parts = {}
    for i = 1, math.min(3, #mobs) do
        local m = mobs[i]
        parts[i] = m.name .. (m.rate and (" " .. ns.RateText(m.rate, m.fewKills)) or "")
    end
    local text = #parts > 0 and (table.concat(parts, ", ") .. (#mobs > 3 and (" +" .. (#mobs - 3) .. " more") or ""))
    tipCache[itemId] = text or false
    return text
end

function UI.ClearTooltipCache() wipe(tipCache) end

if TooltipDataProcessor and Enum.TooltipDataType then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip, data)
        if LootwrightDB.tooltip == false or InCombatLockdown() then return end
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end -- skip compare tooltips
        local id = type(data) == "table" and data.id
        if type(id) ~= "number" or not ns.Data.Available() then return end
        local text = tooltipText(id)
        if text then tooltip:AddLine("Drops from: " .. text, 0.4, 0.8, 1, true) end
    end)
end

-- Shows one tab ("search", "prof" or "farm") and remembers it. Opens the window if needed.
function UI.ShowTab(key)
    if InCombatLockdown() then ns.say("The window can't be opened in combat."); return end
    if not frame then build() end
    if not pages[key] or (key == "prof" and not ns.ProfUI) then key = "search" end
    for k, pg in pairs(pages) do pg:SetShown(k == key) end
    for k, b in pairs(tabButtons) do b:SetOn(k == key) end
    LootwrightDB.tab = key
    frame:Show()
    if key == "prof" then ns.ProfUI.Refresh()
    elseif key == "farm" then ns.FarmUI.Refresh()
    else searchBox:SetFocus() end
end

-- Switches to the Search tab on one item (used by the Professions and Farm tabs).
function UI.ShowItem(itemId)
    if InCombatLockdown() then return end
    UI.ShowTab("search")
    searchBox:ClearFocus()
    local name = ns.Data.ItemName(itemId) or ""
    searchBox:SetText(name)
    runSearch(name)
    selectItem(itemId)
end

-- Called by Farm.lua when a goal removes an item from the farm list.
function UI.OnFarmChanged()
    if ns.Tracker then ns.Tracker.Refresh() end
    if not frame then return end
    updateFavButton()
    refreshItemRows()
    ns.FarmUI.Refresh()
end

-- /if: open on the last used tab, or close.
function UI.Toggle()
    if frame and frame:IsShown() then frame:Hide(); return end
    UI.ShowTab(LootwrightDB.tab or "search")
end
