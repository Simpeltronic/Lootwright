-- Lootwright Data.lua: the ONLY file that knows QuestieDB's data formats.
-- Everything else works with the plain tables returned here.
--   LibQuestieDB.Item.GetAllIds / .name / .npcDrops / .objectDrops / .vendors
--   LibQuestieDB.Npc.name / .minLevel / .maxLevel / .rank / .zoneID / .spawns / .friendlyToFaction
--   LibQuestieDB.Support.Get(...): drop tables, drop corrections, area -> uiMapID tables
-- QuestieDB is the only addon we need. We don't use Questie: its drop-rate rules are copied below
-- (Phase 6 dependency review, see ROADMAP.md).

local _, ns = ...
local Data = {}
ns.Data = Data

-- The QuestieDB contract version this code was written against (LibQuestieDB.RequireContract).
Data.CONTRACT = 4

local function lib()
    return _G.LibQuestieDB
end

local contractOk, contractMsg
-- Checks QuestieDB's contract once. Returns ok, message.
function Data.CheckContract()
    if contractOk ~= nil then return contractOk, contractMsg end
    local L = lib()
    if not L then
        contractOk, contractMsg = false, "QuestieDB is not loaded."
    elseif type(L.RequireContract) ~= "function" then
        contractOk = true -- older QuestieDB without the check; the API calls below are still guarded
    else
        local ok, a, b = pcall(L.RequireContract, Data.CONTRACT)
        contractOk = ok and a == true
        contractMsg = (not contractOk) and tostring(b or a) or nil
    end
    return contractOk, contractMsg
end

-- True when QuestieDB's API is usable.
function Data.Available()
    local L = lib()
    return L ~= nil and L.Item ~= nil and L.Npc ~= nil and (Data.CheckContract())
end

function Data.AllItemIds()
    return lib().Item.GetAllIds()
end

-- Which recipe makes an item (any profession): profession, recipe name; or nil. From LibLootwright.
function Data.CraftedBy(itemId)
    local lib = ns.Lib()
    if lib then return lib.CraftedBy(itemId) end
end

function Data.ItemName(itemId)
    return lib().Item.name(itemId)
end

local function countKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end
Data.CountKeys = countKeys

----------------------------------------------------------------------
-- Drop rates
----------------------------------------------------------------------

-- QuestieDB ships three drop tables, all [itemId][npcId] = rate (percent), covering ~2k quest items:
--   wowhead     Wowhead's crowd-sourced rates
--   cmangos     CMaNGOS rates, only for quest-only drops
--   corrections QuestieDB's manual fixes (Era); a negative value points at one of the other tables
-- Rule (same as Questie's DropDB): correction, then cmangos, then wowhead.
local drops -- { wowhead = t, cmangos = t, corrections = t }, decoded once (~570 KB, a short hitch)

local function decode(src)
    local fn = type(src) == "string" and loadstring(src)
    if not fn then return nil end
    local ok, t = pcall(fn)
    return ok and type(t) == "table" and t or nil
end

local function getDrops()
    if drops then return drops end
    drops = {}
    local L = lib()
    local ok, sup = pcall(function() return L.Support.Get("QuestieClassicItemDrops") end)
    if ok and type(sup) == "table" then
        drops.wowhead = decode(sup.wowheadData)
        drops.cmangos = decode(sup.cmangosData)
    end
    local ok2, cor = pcall(function() return L.Support.Get("QuestieItemDropCorrections") end)
    if ok2 and type(cor) == "table" and type(cor.Era) == "table" then drops.corrections = cor.Era end
    return drops
end

local function cell(t, itemId, npcId)
    local r = t and type(t[itemId]) == "table" and t[itemId][npcId]
    return type(r) == "number" and r or nil
end

-- Returns rate (percent) and source ("questie", "cmangos" or "wowhead"), or nil.
local function dropRate(itemId, npcId)
    local d = getDrops()
    local keys = lib().Enum and lib().Enum.dropCorrectionKeys or {}
    local WOWHEAD, PSERVER = keys.WOWHEAD or -1, keys.PSERVER or -2
    local c = cell(d.corrections, itemId, npcId)
    if c then
        if c >= 0 then return c, "questie" end
        -- A reference correction picks the table; if that table has no value, fall through.
        if c == WOWHEAD and cell(d.wowhead, itemId, npcId) then return cell(d.wowhead, itemId, npcId), "wowhead" end
        if c == PSERVER and cell(d.cmangos, itemId, npcId) then return cell(d.cmangos, itemId, npcId), "cmangos" end
    end
    local p = cell(d.cmangos, itemId, npcId)
    if p and p >= 0 then return p, "cmangos" end
    local w = cell(d.wowhead, itemId, npcId)
    if w and w >= 0 then return w, "wowhead" end
    return nil
end

local function fallbackNpcs(itemId)
    local seen, list = {}, {}
    local d = getDrops()
    for _, t in ipairs({ d.wowhead or {}, d.cmangos or {} }) do
        if type(t[itemId]) == "table" then
            for npcId in pairs(t[itemId]) do
                -- Skip NPCs QuestieDB doesn't know (the Wowhead data includes Season of Discovery IDs).
                if type(npcId) == "number" and npcId > 0 and not seen[npcId] and lib().Npc.name(npcId) then
                    seen[npcId] = true
                    list[#list + 1] = npcId
                end
            end
        end
    end
    return list
end

-- Wowhead rates carry 4 decimals and no sample size. A rate from n kills is an exact fraction
-- k/n (100, 50, 33.3333, 25 ...), so an exact fraction with n <= 10 means "very few kills".
-- Checked on QuestieDB's data: flags ~10% of Wowhead rates, incl. every 100% on Linen Cloth.
local function fewKills(rate, source)
    if source ~= "wowhead" or type(rate) ~= "number" then return false end
    for n = 1, 10 do
        local k = rate * n / 100
        if math.abs(k - math.floor(k + 0.5)) < 0.001 then return true end
    end
    return false
end

-- Self-check (runs once at load; cheap).
assert(fewKills(100, "wowhead") and fewKills(33.3333, "wowhead") and fewKills(75, "wowhead"))
assert(not fewKills(97.9381, "wowhead") and not fewKills(43.7355, "wowhead") and not fewKills(100, "cmangos"))

----------------------------------------------------------------------
-- Zones
----------------------------------------------------------------------
local function zoneName(areaId)
    if not areaId then return "?" end
    local ok, name = pcall(C_Map.GetAreaInfo, areaId)
    if ok and name and name ~= "" then return name end
    return "area " .. tostring(areaId)
end

----------------------------------------------------------------------
-- Sources
----------------------------------------------------------------------

-- Dungeon boss loot for one item (LibLootwright.BossLoot): { [npcId] = { rate, kills, measured } }, or nil.
local function bossLoot(itemId)
    local lib = ns.Lib()
    return lib and lib.BossLoot(itemId)
end

-- CMaNGOS per-mob rates for one item (LibLootwright.MobRates): { [npcId] = pct }, or nil.
local function mobRates(itemId)
    local lib = ns.Lib()
    return lib and lib.MobRates(itemId)
end

-- Players' shared loot (LibLootwright.CommunityRates): { [npcId] = { k, n } } for mobs with 20+ corpses, or nil.
local function communityRates(itemId)
    local lib = ns.Lib()
    return lib and lib.CommunityRates and lib.CommunityRates(itemId)
end

-- A community rate is measured in Forever by many players, so it beats every other rate except a
-- ForeverDB boss rate measured over more kills.
local function applyCommunity(row, c)
    if not c then return end
    if row.source == "foreverdb" and (row.kills or 0) >= c.n then return end
    row.rate, row.source, row.rough, row.fewKills, row.kills = 100 * c.k / c.n, "community", false, false, nil
    row.commK, row.commN = c.k, c.n
end

-- A plain mob row from QuestieDB, with no rate yet.
local function npcRow(L, npcId)
    return {
        npcId = npcId,
        name = L.Npc.name(npcId) or ("npc " .. npcId),
        minLevel = L.Npc.minLevel(npcId),
        maxLevel = L.Npc.maxLevel(npcId),
        rank = L.Npc.rank(npcId) or 0,
        zone = zoneName(L.Npc.zoneID(npcId)),
        zones = countKeys(L.Npc.spawns(npcId)),
        friendly = L.Npc.friendlyToFaction(npcId),
        fewKills = false,
    }
end

-- Your own loot (Loot.lua) judges the row once you've looted enough corpses of this mob:
--   item seen: your measured rate replaces an unknown or rough one (source "you");
--   never seen and the shown rate is above what your corpses allow: notSeen (grey, sorted last).
-- Same 95% range test as build_data.py's agreement check.
-- Never added to community rates (your shared kills are already in them): a community rate isn't
-- unknown or rough, so your counts only replace rates where the community has too few corpses.
local function applyOwnLoot(row, itemId)
    if not ns.Loot or ns.Loot.IsQuestItem(itemId) then return end -- quest items are never recorded: 0 means nothing
    local k, n = ns.Loot.Get(row.npcId, itemId)
    if not k or n < ns.Loot.MIN_CORPSES then return end
    row.ownK, row.ownN = k, n
    if k > 0 then
        if row.rate == nil or row.rough then
            row.rate, row.source, row.rough, row.fewKills, row.kills = 100 * k / n, "you", false, false, nil
        end
    elseif row.rate then
        local _, hi = ns.Loot.Range(0, n)
        if row.rate > hi then row.notSeen = true end
    end
end

-- Applies a boss-loot entry to a mob row. A rate measured in Forever wins over QuestieDB's;
-- ForeverDB's Classic-data rate only fills an unknown one.
local function applyBossLoot(row, b)
    if not b or not b.rate then return end
    if b.measured then
        row.rate, row.source, row.kills = b.rate, "foreverdb", b.kills
        row.fewKills = b.kills > 0 and b.kills <= 10
    elseif row.rate == nil then
        row.rate, row.source, row.fewKills = b.rate, "cmangos", false
    end
end

-- Returns {
--   mobs = { { npcId, name, minLevel, maxLevel, rank, zone, zones, rate, source, fewKills, kills }, ... },
--   kills = number of looted kills a ForeverDB-measured rate is based on (source "foreverdb"), else nil.
--   fewKills = true when the rate looks like it comes from 10 or fewer kills.
--   friendly = player factions the mob is friendly to: "A", "H", "AH" or nil.
--   fromDropTable = true if the mob list came from the drop-table fallback,
--   objects = count, vendors = count }
-- rank: 0 normal, 1 elite, 2 rare elite, 3 boss, 4 rare. rate is nil when unknown.
function Data.GetSources(itemId)
    local L = lib()
    local result = { mobs = {}, objects = 0, vendors = 0 }

    local npcs = L.Item.npcDrops(itemId)
    if type(npcs) ~= "table" or #npcs == 0 then
        npcs = fallbackNpcs(itemId)
        result.fromDropTable = #npcs > 0
    end
    local boss = bossLoot(itemId) or {}
    local cm = mobRates(itemId) or {}
    local comm = communityRates(itemId) or {}
    local seen = {}
    for _, npcId in ipairs(npcs) do
        local rate, src = dropRate(itemId, npcId)
        local row = {
            npcId = npcId,
            name = L.Npc.name(npcId) or ("npc " .. npcId),
            minLevel = L.Npc.minLevel(npcId),
            maxLevel = L.Npc.maxLevel(npcId),
            rank = L.Npc.rank(npcId) or 0,
            zone = zoneName(L.Npc.zoneID(npcId)),
            zones = countKeys(L.Npc.spawns(npcId)),
            rate = rate,
            source = src,
            fewKills = fewKills(rate, src),
            friendly = L.Npc.friendlyToFaction(npcId), -- "A", "H", "AH" or nil
        }
        applyBossLoot(row, boss[npcId])
        if row.rate == nil and cm[npcId] then -- fills unknown rates only
            -- rough: CMaNGOS matched only 38% of rates measured in Forever (build_data.py agreement check)
            row.rate, row.source, row.fewKills, row.rough = cm[npcId], "cmangos", false, true
        end
        applyCommunity(row, comm[npcId])
        seen[npcId] = true
        result.mobs[#result.mobs + 1] = row
    end

    -- Bosses ForeverDB has for this item that QuestieDB's list lacks.
    for npcId, b in pairs(boss) do
        if not seen[npcId] then
            local lib = ns.Lib()
            local info = lib and { lib.Boss(npcId) } or {} -- name, instance, levels
            local lo, hi = tostring(info[3] or ""):match("(%d+)%-?(%d*)")
            local qzone = L.Npc.zoneID(npcId)
            local row = {
                npcId = npcId,
                name = L.Npc.name(npcId) or info[1] or ("npc " .. npcId),
                minLevel = L.Npc.minLevel(npcId) or tonumber(lo),
                maxLevel = L.Npc.maxLevel(npcId) or tonumber(hi ~= "" and hi or lo),
                rank = L.Npc.rank(npcId) or 3,
                zone = (qzone and zoneName(qzone)) or info[2] or "?",
                zones = countKeys(L.Npc.spawns(npcId)),
                friendly = L.Npc.friendlyToFaction(npcId),
                fewKills = false,
            }
            applyBossLoot(row, b)
            applyCommunity(row, comm[npcId])
            seen[npcId] = true
            result.mobs[#result.mobs + 1] = row
        end
    end

    -- Mobs only CMaNGOS lists (QuestieDB's lists miss many, e.g. cloth stops at ~200 mobs).
    -- Only NPCs QuestieDB knows, so every row has a name, level, zone and spawns.
    for npcId, pct in pairs(cm) do
        if not seen[npcId] and L.Npc.name(npcId) then
            local row = npcRow(L, npcId)
            row.rate, row.source, row.rough, row.cmOnly = pct, "cmangos", true, true
            applyCommunity(row, comm[npcId])
            seen[npcId] = true
            result.mobs[#result.mobs + 1] = row
        end
    end

    -- Mobs players' shared loot shows dropping it that no source lists.
    for npcId, c in pairs(comm) do
        if not seen[npcId] and L.Npc.name(npcId) then
            local row = npcRow(L, npcId)
            applyCommunity(row, c)
            seen[npcId] = true
            result.mobs[#result.mobs + 1] = row
        end
    end

    -- Mobs your own loot shows dropping it that no source lists.
    for npcId in pairs(ns.Loot and ns.Loot.MobsWith(itemId) or {}) do
        if not seen[npcId] and L.Npc.name(npcId) then
            seen[npcId] = true
            result.mobs[#result.mobs + 1] = npcRow(L, npcId)
        end
    end

    for _, row in ipairs(result.mobs) do applyOwnLoot(row, itemId) end

    local objs = L.Item.objectDrops(itemId)
    if type(objs) == "table" then result.objects = #objs end
    local vend = L.Item.vendors(itemId)
    if type(vend) == "table" then result.vendors = #vend end
    return result
end

----------------------------------------------------------------------
-- Spawns (for map pins)
----------------------------------------------------------------------
-- QuestieDB's area ID -> uiMapID tables are Lua source strings in the ZoneDB support module.
local areaToMap
local function getAreaToMap()
    if areaToMap then return areaToMap end
    areaToMap = {}
    local ok, zdb = pcall(function() return lib().Support.Get("ZoneDB") end)
    local priv = ok and type(zdb) == "table" and zdb.private
    if type(priv) == "table" then
        -- Overrides are applied last so they win.
        for _, field in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
            local fn = type(priv[field]) == "string" and loadstring(priv[field])
            local ok2, t = false, nil
            if fn then ok2, t = pcall(fn) end
            if ok2 and type(t) == "table" then
                for area, map in pairs(t) do areaToMap[area] = map end
            end
        end
    end
    return areaToMap
end

-- Returns spawns as { { mapId = uiMapID, x = 0..1, y = 0..1 }, ... } and the uiMapID to open first.
-- Spawn layout: { [areaId] = { {x, y, phase?}, ... } } with x/y in percent; (-1,-1) means inside an instance.
function Data.GetSpawns(npcId)
    local L = lib()
    local spawns = L.Npc.spawns(npcId)
    local map = getAreaToMap()
    local list, mainMap = {}, nil
    if type(spawns) ~= "table" then return list end
    for areaId, points in pairs(spawns) do
        local mapId = map[areaId]
        if mapId and mapId > 0 and type(points) == "table" then
            for _, p in ipairs(points) do
                local x, y = p[1], p[2]
                if type(x) == "number" and type(y) == "number" and x >= 0 and y >= 0 then
                    list[#list + 1] = { mapId = mapId, x = x / 100, y = y / 100 }
                end
            end
        end
    end
    local zoneMap = map[L.Npc.zoneID(npcId) or 0]
    for _, s in ipairs(list) do
        if s.mapId == zoneMap then mainMap = zoneMap; break end
    end
    mainMap = mainMap or (list[1] and list[1].mapId)
    return list, mainMap
end

----------------------------------------------------------------------
-- Debug access (used by /if status and /if raw)
----------------------------------------------------------------------
function Data.Status()
    local L = lib()
    local ok, msg = Data.CheckContract()
    local s = { lib = L ~= nil, contractOk = ok, contractMsg = msg, contractWanted = Data.CONTRACT }
    if L then
        s.contractVersion, s.readMode, s.addonName = L.contractVersion, L.readMode, L.addonName
        s.itemApi, s.npcApi = L.Item ~= nil, L.Npc ~= nil
        if L.Item and L.Item.GetAllIds then s.itemCount = #L.Item.GetAllIds() end
    end
    return s
end

function Data.RawItem(id)
    local L = lib()
    return { name = L.Item.name(id), npcDrops = L.Item.npcDrops(id),
             objectDrops = L.Item.objectDrops(id), vendors = L.Item.vendors(id) }
end

function Data.RawNpc(id)
    local L = lib()
    return { name = L.Npc.name(id), minLevel = L.Npc.minLevel(id), maxLevel = L.Npc.maxLevel(id),
             rank = L.Npc.rank(id), zoneID = L.Npc.zoneID(id), spawns = L.Npc.spawns(id) }
end
