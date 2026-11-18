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
-- Filters (settings in ItemFinderDB: showFriendly, nearLevel; both off by default)
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
    if not ItemFinderDB.showFriendly and isFriendly(r) then return false end
    if ItemFinderDB.nearLevel and not isNearLevel(r) then return false end
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
        button:SetScript("OnEnter", function(self)
            local m = self.mob
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:AddLine(m.name)
            GameTooltip:AddLine("NPC ID " .. m.npcId, 0.7, 0.7, 0.7)
            if m.zones > 1 then GameTooltip:AddLine("Spawns in " .. m.zones .. " zones", 1, 1, 1) end
            if m.fewKills then
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
    button.cells[4]:SetTextColor(rateColor(not r.fewKills and r.rate or nil)) -- few kills: grey
end

----------------------------------------------------------------------
-- Item selection
----------------------------------------------------------------------
local MAX_RECENT = 10

-- Recently selected item IDs, newest first, kept in SavedVariables.
local function recentList()
    ItemFinderDB.recent = ItemFinderDB.recent or {}
    return ItemFinderDB.recent
end

local function pushRecent(itemId)
    local list = recentList()
    for i = #list, 1, -1 do
        if list[i] == itemId then table.remove(list, i) end
    end
    table.insert(list, 1, itemId)
    for i = #list, MAX_RECENT + 1, -1 do list[i] = nil end
end

-- Favourite item IDs: ItemFinderDB.favorites[itemId] = true.
local function favorites()
    ItemFinderDB.favorites = ItemFinderDB.favorites or {}
    return ItemFinderDB.favorites
end

local favButton, farmButton, goalBox
local function updateFavButton()
    favButton:SetShown(selectedId ~= nil)
    favButton:SetText(selectedId and favorites()[selectedId] and "Unfavorite" or "Favorite")
    farmButton:SetShown(selectedId ~= nil)
    farmButton:SetText(selectedId and ns.Farm.Has(selectedId) and "Stop farm" or "Farm")
    goalBox:SetShown(selectedId ~= nil)
    if not goalBox:HasFocus() then
        local goal = selectedId and ns.Farm.Has(selectedId) and ns.Farm.Goal(selectedId)
        goalBox:SetText(goal and tostring(goal) or "")
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
    local g = itemGroup(data.id)
    local name = (g == 0 and ("|cff40ff40" .. data.name .. "|r")) or (g == 1 and ("|cffffd100" .. data.name .. "|r"))
        or data.name
    button.text:SetText(name .. " |cff777777#" .. data.id .. "|r")
    button.sel:SetShown(data.id == selectedId)
end

local function runSearch(text)
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
        statusText:SetText(#list > 0 and "Farm, favorites and recent items. Type 2+ letters to search."
            or "Type at least 2 letters, or shift-click an item.")
        return
    end
    if not ns.Search.IsBuilt() then statusText:SetText("Building item index...") end
    ns.Search.Find(text, function(ids, nExact)
        if token ~= searchToken then return end -- a newer search replaced this one
        -- Matching farm items, then favourites first, from all matches, not only the first MAX_ITEMS.
        local list = {}
        for group = 0, 2 do
            for _, id in ipairs(ids) do
                if group == 2 and #list >= MAX_ITEMS then break end
                if itemGroup(id) == group then list[#list + 1] = { id = id, name = ns.Search.Name(id) } end
            end
        end
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
    frame:Hide() -- new frames start shown; Toggle decides
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

    statusText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    statusText:SetPoint("TOPLEFT", searchBox, "BOTTOMLEFT", -4, -4)
    statusText:SetWidth(226)
    statusText:SetJustifyH("LEFT")

    itemBox = makeList(frame, 18, initItemRow)
    itemBox:SetPoint("TOPLEFT", 12, -72)
    itemBox:SetPoint("BOTTOMLEFT", 12, 12)
    itemBox:SetWidth(222)
    runSearch("") -- recent items

    -- Right: selected item
    headerIcon = frame:CreateTexture(nil, "ARTWORK")
    headerIcon:SetSize(28, 28)
    headerIcon:SetPoint("TOPLEFT", 260, -30)
    headerIcon:SetTexture(134400) -- question mark

    headerName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    headerName:SetPoint("TOPLEFT", headerIcon, "TOPRIGHT", 8, -1)
    headerName:SetPoint("RIGHT", frame, "RIGHT", -262, 0)
    headerName:SetJustifyH("LEFT")
    headerName:SetWordWrap(false)
    headerName:SetText("Search for an item")

    favButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    favButton:SetSize(90, 22)
    favButton:SetPoint("TOPRIGHT", -14, -30)
    favButton:SetScript("OnClick", function()
        if not selectedId then return end
        local favs = favorites()
        favs[selectedId] = not favs[selectedId] or nil
        updateFavButton()
        if #searchBox:GetText() < 2 then runSearch("") end -- refresh the favourites list
    end)

    farmButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    farmButton:SetSize(80, 22)
    farmButton:SetPoint("RIGHT", favButton, "LEFT", -4, 0)
    farmButton:SetScript("OnClick", function()
        if not selectedId then return end
        ns.Farm.Toggle(selectedId)
        updateFavButton()
        if #searchBox:GetText() < 2 then runSearch("") end
    end)
    farmButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Farm list", 1, 1, 1)
        GameTooltip:AddLine("Mobs that drop farm items get a \"Farm:\" line on their tooltip in the game.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    farmButton:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Goal: applied on Enter only (focus changes while switching items must not touch goals).
    goalBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    goalBox:SetSize(58, 20)
    goalBox:SetPoint("RIGHT", farmButton, "LEFT", -6, 0)
    goalBox:SetAutoFocus(false)
    goalBox:SetNumeric(true)
    goalBox:SetMaxLetters(5)
    if goalBox.Instructions then goalBox.Instructions:SetText("Goal") end
    goalBox:HookScript("OnEnterPressed", function(self)
        if selectedId then ns.Farm.SetGoal(selectedId, self:GetText()) end
        self:ClearFocus()
        updateFavButton()
        if #searchBox:GetText() < 2 then runSearch("") end
    end)
    goalBox:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Farm goal", 1, 1, 1)
        GameTooltip:AddLine("Type how many you want and press Enter. The item leaves the farm list "
            .. "once your bags hold that many. Empty + Enter removes the goal.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    goalBox:HookScript("OnLeave", function() GameTooltip:Hide() end)
    updateFavButton()

    summaryText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    summaryText:SetPoint("TOPLEFT", headerIcon, "BOTTOMRIGHT", 8, 10)
    summaryText:SetPoint("RIGHT", frame, "RIGHT", -196, 0) -- leave room for the Farm/Favorite buttons
    summaryText:SetJustifyH("LEFT")

    -- Same template as the item search box: InputBoxTemplate didn't take keyboard input on Forever.
    zoneBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    zoneBox:SetSize(160, 20)
    zoneBox:SetPoint("TOPLEFT", 266, -68)
    zoneBox:SetAutoFocus(false)
    if zoneBox.Instructions then zoneBox.Instructions:SetText("Filter by zone") end
    zoneBox:HookScript("OnTextChanged", function() if selectedId then refreshMobs() end end)
    zoneBox:HookScript("OnEnterPressed", zoneBox.ClearFocus)

    local clearPins = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    clearPins:SetSize(90, 22)
    clearPins:SetPoint("LEFT", zoneBox, "RIGHT", 12, 0)
    clearPins:SetText("Clear pins")
    clearPins:SetScript("OnClick", function() ns.Map.Clear() end)

    -- Filter checkboxes; own label font strings since template label keys differ between clients.
    local function makeCheck(label, key, tip, anchor)
        local cb = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
        cb:SetSize(22, 22)
        cb:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
        local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetPoint("LEFT", cb, "RIGHT", 0, 1)
        fs:SetText(label)
        cb:SetChecked(ItemFinderDB[key] == true)
        cb:SetScript("OnClick", function(self)
            ItemFinderDB[key] = self:GetChecked() and true or false
            UI.ClearTooltipCache()
            refreshMobs()
        end)
        cb:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:AddLine(tip, 1, 1, 1, true)
            GameTooltip:Show()
        end)
        cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return fs -- anchor the next control after the label
    end
    local nearLabel = makeCheck("Near lvl", "nearLevel",
        "Only mobs within " .. NEAR_LEVELS .. " levels of you.", clearPins)
    makeCheck("Friendly", "showFriendly",
        "Also show mobs friendly to your faction (you can't attack them).", nearLabel)

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
    foot:SetJustifyH("LEFT")
    foot:SetText("Rates: Questie / QuestieDB data. * = very few kills.")

    filterText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    filterText:SetPoint("BOTTOMRIGHT", -16, 12)
    filterText:SetJustifyH("RIGHT")

    refreshMobs()

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
        if ItemFinderDB.tooltip == false or InCombatLockdown() then return end
        if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then return end -- skip compare tooltips
        local id = type(data) == "table" and data.id
        if type(id) ~= "number" or not ns.Data.Available() then return end
        local text = tooltipText(id)
        if text then tooltip:AddLine("Drops from: " .. text, 0.4, 0.8, 1, true) end
    end)
end

-- Called by Farm.lua when a goal removes an item from the farm list.
function UI.OnFarmChanged()
    if not frame then return end
    updateFavButton()
    if #searchBox:GetText() < 2 then runSearch("") end
end

function UI.Toggle()
    if InCombatLockdown() then ns.say("The window can't be opened in combat."); return end
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then searchBox:SetFocus() end
end
