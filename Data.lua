-- ItemFinder Data.lua: the ONLY file that knows QuestieDB / Questie data formats.
-- Everything else works with the plain tables returned here.
--   LibQuestieDB.Item.GetAllIds / .name / .npcDrops / .objectDrops / .vendors
--   LibQuestieDB.Npc.name / .minLevel / .maxLevel / .rank / .zoneID / .spawns
--   Drop rates (optional): Questie's QuestieDB.GetItemDroprate(itemId, npcId), else QuestieDB's drop tables.

local _, ns = ...
local Data = {}
ns.Data = Data

local function lib()
    return _G.LibQuestieDB
end

-- True when QuestieDB's API is usable.
function Data.Available()
    local L = lib()
    return L ~= nil and L.Item ~= nil and L.Npc ~= nil
end

function Data.AllItemIds()
    return lib().Item.GetAllIds()
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

-- Questie's drop-rate lookup (optional). Returns rate (percent) and source name, or nil.
local function questieRate(itemId, npcId)
    if not _G.QuestieLoader then return nil end
    local ok, QDB = pcall(function() return QuestieLoader:ImportModule("QuestieDB") end)
    if not ok or type(QDB) ~= "table" or type(QDB.GetItemDroprate) ~= "function" then return nil end
    local ok2, a, b = pcall(QDB.GetItemDroprate, itemId, npcId)
    if not ok2 or a == nil then return nil end
    if type(a) == "table" then return a[1], a[2] end
    return a, b
end

-- Drop tables ([itemId][npcId] = rate) shipped with QuestieDB; they cover ~2k quest-objective items.
-- Used when Item.npcDrops is empty (e.g. Linen Cloth). Prefer Questie's already-decoded copy.
local dropTables
local function getDropTables()
    if dropTables then return dropTables end
    dropTables = {}
    if _G.QuestieLoader then
        local ok, DDB = pcall(function() return QuestieLoader:ImportModule("DropDB") end)
        if ok and type(DDB) == "table" then
            if type(DDB.tableWowhead) == "table" then dropTables[#dropTables + 1] = DDB.tableWowhead end
            if type(DDB.tablePserver) == "table" then dropTables[#dropTables + 1] = DDB.tablePserver end
        end
    end
    if #dropTables == 0 then
        -- Questie not loaded: decode QuestieDB's raw string once (~570 KB, a short one-time hitch).
        local L = lib()
        local ok, sup = pcall(function() return L.Support.Get("QuestieClassicItemDrops") end)
        if ok and type(sup) == "table" then
            for _, field in ipairs({ "wowheadData", "cmangosData" }) do
                local fn = type(sup[field]) == "string" and loadstring(sup[field])
                local ok2, t = false, nil
                if fn then ok2, t = pcall(fn) end
                if ok2 and type(t) == "table" then dropTables[#dropTables + 1] = t end
            end
        end
    end
    return dropTables
end

local function fallbackNpcs(itemId)
    local seen, list = {}, {}
    for _, t in ipairs(getDropTables()) do
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

-- Rate straight from the drop tables, for when Questie's GetItemDroprate isn't available.
local function tableRate(itemId, npcId)
    for _, t in ipairs(getDropTables()) do
        local r = type(t[itemId]) == "table" and t[itemId][npcId]
        if type(r) == "number" and r >= 0 then return r, "questiedb" end
    end
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
Data.FewKills = fewKills -- exposed for the self-check below

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

-- Returns {
--   mobs = { { npcId, name, minLevel, maxLevel, rank, zone, zones, rate, source, fewKills }, ... },
--   fewKills = true when the rate looks like it comes from 10 or fewer kills.
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
    for _, npcId in ipairs(npcs) do
        local rate, src = questieRate(itemId, npcId)
        if rate == nil then rate, src = tableRate(itemId, npcId) end
        result.mobs[#result.mobs + 1] = {
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
        }
    end

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
    local s = { lib = L ~= nil, questie = _G.QuestieLoader ~= nil }
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
