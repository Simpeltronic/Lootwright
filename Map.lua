-- Lootwright Map.lua: world map pins: the hunted item's icon, round, on a light disc with a dark rim
-- (brass for the clicked mob, green for farm spawns; user's choice "D3", docs/design-brief/pins). Two sets:
--   the selected mob's spawns (click a mob row; "Clear pins" removes them), and
--   farm pins: every mob that drops something on the farm list (single items and materials still
--   needed), kept up to date as the list and bags change. /if farmpins turns them off.
-- Same mechanism as HereBeDragons-Pins (used by Questie on this client): a Lua-built pin pool
-- registered in WorldMapFrame.pinPools plus a MapCanvas data provider. No XML template needed.
-- shortcut: world map only, no minimap pins; add them if players ask for pins while not looking at the map.

local _, ns = ...
local Map = {}
ns.Map = Map

local TEMPLATE = "LootwrightWorldMapPin"
local DISC_TARGET = ns.Theme.MEDIA .. "disc_target" -- light brass disc, clicked mob (via MEDIA so package.py ships it)
local DISC_FARM = ns.Theme.MEDIA .. "disc_farm"     -- light green disc, farm spawns
local ROUND_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask" -- the game's own circle mask
local FALLBACK_ICON = 134400 -- question mark, when the item has no icon yet

local pins = {}   -- { { mapId, x, y }, ... } for the current mob
local mob         -- the mob row table the pins belong to
local mobItem     -- the item searched when that mob was clicked (its icon goes in the pins)
local farmPins = {} -- { { mapId, x, y, mob = { name, minLevel, maxLevel, farmItems } }, ... }
local provider

local pinMixin -- built on first use, once MapCanvasPinMixin is surely loaded

local missing  -- defined with the farm pins below; the tooltip uses it too

local function setup()
    if provider then return true end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
    if not (WorldMapFrame and WorldMapFrame.pinPools and MapCanvasDataProviderMixin and MapCanvasPinMixin) then
        return false
    end

    pinMixin = CreateFromMixins(MapCanvasPinMixin)
    function pinMixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetScalingLimits(1, 1.0, 1.2)
    end
    function pinMixin:OnAcquired(p, m)
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetPosition(p.x, p.y)
        self.point, self.mob = p, m
        -- Farm pins are smaller; a group shows how many spawns it holds. The item icon fills the
        -- disc underneath, the item icon on top (round, 40/64 of the pin; square 34/64 without a mask).
        local size = p.small and 12 or 14
        self:SetSize(size, size)
        self.disc:SetTexture(p.small and DISC_FARM or DISC_TARGET)
        local inset = size * (self.mask and 12 or 15) / 64
        self.icon:ClearAllPoints()
        self.icon:SetPoint("TOPLEFT", self, "TOPLEFT", inset, -inset)
        self.icon:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", -inset, inset)
        local itemId = p.itemId or (not p.small and mobItem) or nil
        self.icon:SetTexture(itemId and C_Item.GetItemIconByID(itemId) or FALLBACK_ICON)
        if p.extra and p.extra > 0 then
            self.badge:SetText("+" .. p.extra)
            self.badge:Show()
        else
            self.badge:Hide()
        end
        if p.count and p.count > 1 then
            self.countText:SetText(p.count)
            self.countText:Show()
        else
            self.countText:Hide()
        end
    end
    -- Click: set the game's own waypoint (arrow + distance) on this spawn.
    function pinMixin:OnMouseDown(button)
        if button ~= "LeftButton" or not self.point then return end
        Map.SetWaypoint(self.point, self.mob)
    end
    function pinMixin:OnReleased() self.mob = nil end
    -- The map canvas owns OnEnter/OnLeave and calls these instead.
    function pinMixin:OnMouseEnter()
        local m = self.mob
        if not m then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if m.group then
            -- A group of farm spawns: each mob kind with its spawn count here.
            GameTooltip:AddLine(m.count .. " spawns here")
            for _, g in ipairs(m.group) do
                GameTooltip:AddDoubleLine(g.name .. (g.count > 1 and (" x" .. g.count) or ""),
                    "L" .. ns.LevelText(g.minLevel, g.maxLevel), 1, 1, 1, 0.8, 0.8, 0.8)
            end
        else
            GameTooltip:AddLine(m.name)
            GameTooltip:AddLine("Level " .. ns.LevelText(m.minLevel, m.maxLevel), 1, 1, 1)
        end
        for _, id in ipairs(m.farmIds or {}) do
            local icon = C_Item.GetItemIconByID(id) or FALLBACK_ICON
            local left = missing(id)
            GameTooltip:AddLine("|T" .. icon .. ":0|t " .. (ns.Data.ItemName(id) or ("item " .. id))
                .. (left > 0 and ("  |cffaaaaaa(need " .. left .. ")|r") or ""), 0.25, 1, 0.25)
        end
        GameTooltip:AddLine("Click: set waypoint", 0.2, 1, 0.6)
        GameTooltip:Show()
    end
    function pinMixin:OnMouseLeave() GameTooltip:Hide() end
    pinMixin.SetPassThroughButtons = function() end -- avoids an in-combat error (as in HereBeDragons)

    local pool
    if CreateUnsecuredRegionPoolInstance then
        pool = CreateUnsecuredRegionPoolInstance(TEMPLATE)
    else
        pool = CreateFramePool("FRAME")
    end
    pool.parent = WorldMapFrame:GetCanvas()
    pool.createFunc = function()
        local f = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
        f:SetSize(14, 14)
        f.disc = f:CreateTexture(nil, "ARTWORK")
        f.disc:SetAllPoints()
        f.icon = f:CreateTexture(nil, "OVERLAY")
        f.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- trim the icon's own border
        -- Round icon via a mask texture; if this client lacks masks, the icon stays square (smaller).
        if f.CreateMaskTexture then
            local ok, mask = pcall(f.CreateMaskTexture, f)
            if ok and mask then
                mask:SetTexture(ROUND_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                mask:SetAllPoints(f.icon)
                f.icon:AddMaskTexture(mask)
                f.mask = mask
            end
        end

        -- The spawn count sits right of the pin, not on top of the icon.
        f.countText = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        f.countText:SetPoint("LEFT", f, "RIGHT", 1, 0)
        f.countText:Hide()
        -- "+N" at the top-left edge: more farm items drop here than the one in the icon.
        f.badge = f:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        f.badge:SetPoint("BOTTOMRIGHT", f, "TOPLEFT", 4, -4)
        f.badge:SetTextColor(0.941, 0.835, 0.549)
        f.badge:Hide()
        f:EnableMouse(true) -- hover goes through pinMixin:OnMouseEnter/Leave; the map asserts on own OnEnter scripts
        -- OnMouseDown as a script is fine (RareScanner's pins do the same on this client).
        f:SetScript("OnMouseDown", function(self, button) self:OnMouseDown(button) end)
        return Mixin(f, pinMixin)
    end
    pool.resetFunc = function(_, pin)
        pin:Hide()
        pin:ClearAllPoints()
        pin:OnReleased()
        pin.pinTemplate = nil
        pin.owningMap = nil
    end
    pool.creationFunc = pool.createFunc -- pre-11.x names
    pool.resetterFunc = pool.resetFunc
    WorldMapFrame.pinPools[TEMPLATE] = pool

    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        if LootwrightDB.mapPins == false then return end -- hidden with the map checkbox or Options
        local mapId = self:GetMap():GetMapID()
        for _, p in ipairs(pins) do
            if p.mapId == mapId then self:GetMap():AcquirePin(TEMPLATE, p, mob) end
        end
        for _, p in ipairs(farmPins) do
            if p.mapId == mapId then self:GetMap():AcquirePin(TEMPLATE, p, p.mob) end
        end
    end
    WorldMapFrame:AddDataProvider(provider)

    -- A "Lootwright" checkbox in the map's bottom-right corner (left of the help button; bottom-left
    -- held other addons' cursor coordinates) shows or hides our pins.
    local host = WorldMapFrame.ScrollContainer or WorldMapFrame
    local cb = CreateFrame("CheckButton", "LootwrightMapToggle", host, "UICheckButtonTemplate")
    cb:SetSize(22, 22)
    cb:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -40, 4)
    cb:SetFrameLevel(host:GetFrameLevel() + 20)
    local label = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("RIGHT", cb, "LEFT", 0, 1)
    label:SetText("Lootwright")
    cb:SetChecked(LootwrightDB.mapPins ~= false)
    cb:SetScript("OnClick", function(self)
        LootwrightDB.mapPins = self:GetChecked() and true or false
        provider:RefreshAllData()
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("Show Lootwright's pins on the map")
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    Map.toggle = cb
    return true
end

-- Show pins for one mob (a row from Data.GetSources) and open the world map on its main zone.
function Map.ShowMob(m, itemId)
    if InCombatLockdown() then ns.say("Map pins can't be changed in combat."); return end
    if not setup() then ns.say("The world map isn't available."); return end
    local list, mainMap = ns.Data.GetSpawns(m.npcId)
    if #list == 0 then
        ns.say("No map positions for " .. m.name .. " (it may only spawn inside an instance).")
        return
    end
    pins, mob, mobItem = list, m, itemId
    if OpenWorldMap then
        OpenWorldMap(mainMap)
    else
        ShowUIPanel(WorldMapFrame)
        WorldMapFrame:SetMapID(mainMap)
    end
    provider:RefreshAllData()
end

-- Our own arrow (Forever shows no arrow for the game's waypoint), plus the game's map marker when
-- available (same calls RareScanner uses). p = { mapId, x, y } (0..1).
function Map.SetWaypoint(p, m)
    if LootwrightDB.arrow ~= false then ns.Arrow.Set(p, m and m.name) end
    if C_Map.SetUserWaypoint and UiMapPoint and C_SuperTrack
        and (not C_Map.CanSetUserWaypointOnMap or C_Map.CanSetUserWaypointOnMap(p.mapId)) then
        pcall(function()
            C_Map.ClearUserWaypoint()
            C_Map.SetUserWaypoint(UiMapPoint.CreateFromCoordinates(p.mapId, p.x, p.y))
            C_SuperTrack.SetSuperTrackedUserWaypoint(true)
        end)
    end
    ns.say(string.format("Waypoint set: %s at %.1f, %.1f", m and m.name or "spawn", p.x * 100, p.y * 100))
end

function Map.Clear()
    pins, mob, mobItem = {}, nil, nil
    if provider then provider:RemoveAllData() end
end

----------------------------------------------------------------------
-- Farm pins
----------------------------------------------------------------------
local srcCache, spawnCache = {}, {} -- per item / per NPC; the data doesn't change in a session

-- How many of an item you still need (0 for endless items or when you have enough).
missing = function(itemId)
    return math.max(0, (ns.Farm.Need(itemId) or 0) - ns.Farm.Have(itemId))
end
local GROUP_CELL = 0.04             -- farm spawns closer than 4% of the map share one pin
local farmSig                       -- the wanted-items set the pins were built for

local function isFriendly(f)
    local fac = UnitFactionGroup("player")
    local k = (fac == "Alliance" and "A") or (fac == "Horde" and "H") or nil
    return k ~= nil and type(f) == "string" and f:find(k, 1, true) ~= nil
end

-- Rebuilds the farm pins if the wanted items changed (cheap to call often). force = rebuild anyway.
function Map.RefreshFarmPins(force)
    if not ns.Data.Available() then return end
    local wanted = LootwrightDB.farmPins ~= false and ns.Farm.WantedItems() or {}
    local ids = {}
    for id in pairs(wanted) do ids[#ids + 1] = id end
    table.sort(ids)
    local sig = table.concat(ids, ",")
    if sig == farmSig and not force then return end
    farmSig = sig

    local byNpc = {} -- npcId -> { mob = row, items = { names } }
    for _, id in ipairs(ids) do
        local src = srcCache[id]
        if not src then
            local ok, s = pcall(ns.Data.GetSources, id)
            src = ok and s or { mobs = {} }
            srcCache[id] = src
        end
        for _, m in ipairs(src.mobs) do
            if not isFriendly(m.friendly) and not m.notSeen then -- can't attack friendly ones; notSeen: your loot says no
                local e = byNpc[m.npcId] or { mob = m, items = {} }
                byNpc[m.npcId] = e
                e.items[#e.items + 1] = ns.Data.ItemName(id) or ("item " .. id)
                e.ids = e.ids or {}
                e.ids[#e.ids + 1] = id
            end
        end
    end

    -- Group spawns: one pin per grid cell per map, at the cell's average position.
    -- shortcut: a fixed grid (not zoom-aware); a zoom-aware grouping would need re-grouping on zoom.
    local cells, order = {}, {}
    for npcId, e in pairs(byNpc) do
        local sp = spawnCache[npcId]
        if not sp then
            sp = ns.Data.GetSpawns(npcId)
            spawnCache[npcId] = sp
        end
        for _, p in ipairs(sp) do
            local k = p.mapId .. ":" .. math.floor(p.x / GROUP_CELL) .. ":" .. math.floor(p.y / GROUP_CELL)
            local c = cells[k]
            if not c then
                c = { mapId = p.mapId, sx = 0, sy = 0, n = 0, kinds = {}, kindOrder = {}, items = {}, itemSeen = {},
                    ids = {}, idSeen = {} }
                cells[k] = c
                order[#order + 1] = k
            end
            c.sx, c.sy, c.n = c.sx + p.x, c.sy + p.y, c.n + 1
            local kind = c.kinds[npcId]
            if not kind then
                kind = { name = e.mob.name, minLevel = e.mob.minLevel, maxLevel = e.mob.maxLevel, count = 0 }
                c.kinds[npcId] = kind
                c.kindOrder[#c.kindOrder + 1] = kind
            end
            kind.count = kind.count + 1
            for _, it in ipairs(e.items) do
                if not c.itemSeen[it] then c.itemSeen[it] = true; c.items[#c.items + 1] = it end
            end
            for _, id in ipairs(e.ids) do
                if not c.idSeen[id] then c.idSeen[id] = true; c.ids[#c.ids + 1] = id end
            end
        end
    end

    farmPins = {}
    for _, k in ipairs(order) do
        local c = cells[k]
        table.sort(c.kindOrder, function(a, b) return a.count > b.count end)
        -- Several farm items here: the icon shows the one you still need most, a "+N" badge the rest.
        -- shortcut: the order is set when the pins are rebuilt (farm list changes), not on every bag change.
        table.sort(c.ids, function(a, b) return missing(a) > missing(b) end)
        local mobInfo
        if c.n == 1 then
            local only = c.kindOrder[1]
            mobInfo = { name = only.name, minLevel = only.minLevel, maxLevel = only.maxLevel, farmIds = c.ids }
        else
            mobInfo = { name = c.kindOrder[1].name, group = c.kindOrder, count = c.n, farmIds = c.ids }
        end
        farmPins[#farmPins + 1] = { mapId = c.mapId, x = c.sx / c.n, y = c.sy / c.n, small = true, count = c.n,
            itemId = c.ids[1], extra = #c.ids - 1, mob = mobInfo }
    end
    if setup() and WorldMapFrame:IsShown() then provider:RefreshAllData() end
end

-- Build the farm pins once the game (and QuestieDB) is ready.
local loginFrame = CreateFrame("Frame")
loginFrame:RegisterEvent("PLAYER_LOGIN")
loginFrame:SetScript("OnEvent", function()
    C_Timer.After(2, function()
        setup() -- the provider must exist so the pins show when the map opens
        Map.RefreshFarmPins(true)
    end)
end)
