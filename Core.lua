-- ItemFinder v0.0.2 (Phase 1, prototype)
-- Data source: QuestieDB's public API (global LibQuestieDB):
--   LibQuestieDB.Item.GetAllIds / .name / .npcDrops
--   LibQuestieDB.Npc.name / .minLevel / .maxLevel / .rank / .zoneID / .spawns
-- Drop rates (optional): Questie's DropDB, via QuestieDB.GetItemDroprate(itemId, npcId).
-- Questie only has rates for quest items, so most items will show "?" for now (see ROADMAP Phase 6).
--
-- Commands:
--   /if <text>          search items by name (substring); shift-click an item to look it up directly
--   /if #<id>           show sources for an item ID
--   /if status          check that QuestieDB / Questie are available
--   /if raw item <id>   dump raw fields for an item
--   /if raw npc <id>    dump raw fields for an NPC, including the spawn table layout

local ADDON = ...
ItemFinderDB = ItemFinderDB or {}

local function say(msg)
    msg = tostring(msg)
    print("|cff33ff99ItemFinder|r " .. msg)
    -- Mirror output into SavedVariables so it can be read from disk after /reload.
    -- Read ItemFinderDB at call time: the saved table replaces the global after this file runs.
    local log = ItemFinderDB.log or {}
    ItemFinderDB.log = log
    log[#log + 1] = date("%H:%M:%S ") .. msg
    if #log > 500 then table.remove(log, 1) end
end

local function lib()
    return _G.LibQuestieDB
end

local function needLib()
    local L = lib()
    if not L or not L.Item or not L.Npc then
        say("QuestieDB's API (LibQuestieDB) is not available. Is the QuestieDB addon enabled? Try /if status.")
        return nil
    end
    return L
end

-- Questie's drop-rate lookup (optional). Returns rate (number, percent) and source name, or nil.
local function dropRate(itemId, npcId)
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

local RANKS ={ [0] = "", [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }

local function zoneName(areaId)
    if not areaId then return "?" end
    local ok, name = pcall(C_Map.GetAreaInfo, areaId)
    if ok and name and name ~= "" then return name end
    return "area " .. tostring(areaId)
end

local function levelText(lo, hi)
    if not lo or lo == 0 then return "L?" end
    if not hi or hi == lo or hi == 0 then return "L" .. lo end
    return "L" .. lo .. "-" .. hi
end

local function countKeys(t)
    local n = 0
    if type(t) == "table" then for _ in pairs(t) do n = n + 1 end end
    return n
end

----------------------------------------------------------------------
-- Name index (built once, in chunks so the game doesn't freeze)
----------------------------------------------------------------------
local nameIndex          -- [itemId] = name
local building = false
local waiting = {}

local function withIndex(callback)
    if nameIndex then callback(); return end
    waiting[#waiting + 1] = callback
    if building then return end
    local L = needLib()
    if not L then waiting = {}; return end
    building = true
    local ids = L.Item.GetAllIds()
    local total = #ids
    local tmp, i = {}, 1
    say("Building item name index (" .. total .. " items, one time)...")
    local function step()
        local stop = math.min(i + 1999, total)
        for j = i, stop do
            local id = ids[j]
            local nm = L.Item.name(id)
            if nm and nm ~= "" then tmp[id] = nm end
        end
        i = stop + 1
        if i <= total then
            C_Timer.After(0, step)
        else
            nameIndex, building = tmp, false
            local cbs = waiting
            waiting = {}
            for _, cb in ipairs(cbs) do cb() end
        end
    end
    step()
end

----------------------------------------------------------------------
-- Showing an item's sources
----------------------------------------------------------------------
local MAX_NPCS = 25

local function showItem(itemId)
    local L = needLib()
    if not L then return end
    local name = L.Item.name(itemId) or ("item " .. itemId)
    local link = select(2, C_Item.GetItemInfo(itemId)) or name
    say("Sources for " .. link .. " (id " .. itemId .. "):")

    local npcs = L.Item.npcDrops(itemId)
    if type(npcs) ~= "table" or #npcs == 0 then
        npcs = fallbackNpcs(itemId)
        if #npcs > 0 then say("  (mob list from QuestieDB's quest-item drop table)") end
    end
    local rows = {}
    if type(npcs) == "table" then
        for _, npcId in ipairs(npcs) do
            local rate, src = dropRate(itemId, npcId)
            if rate == nil then rate, src = tableRate(itemId, npcId) end
            rows[#rows + 1] = {
                id = npcId,
                name = L.Npc.name(npcId) or ("npc " .. npcId),
                lo = L.Npc.minLevel(npcId), hi = L.Npc.maxLevel(npcId),
                rank = L.Npc.rank(npcId),
                zone = L.Npc.zoneID(npcId),
                zones = countKeys(L.Npc.spawns(npcId)),
                rate = rate, src = src,
            }
        end
    end

    if #rows == 0 then
        say("  No mob drops recorded.")
    else
        table.sort(rows, function(a, b)
            if (a.rate ~= nil) ~= (b.rate ~= nil) then return a.rate ~= nil end
            if a.rate and b.rate and a.rate ~= b.rate then return a.rate > b.rate end
            if a.name ~= b.name then return a.name < b.name end
            return a.id < b.id
        end)
        say("  " .. #rows .. " mob(s) drop it" .. (#rows > MAX_NPCS and (" (showing " .. MAX_NPCS .. ")") or "") .. ":")
        for i = 1, math.min(#rows, MAX_NPCS) do
            local r = rows[i]
            local rank = RANKS[r.rank or 0] or ""
            local rate = r.rate and (string.format("%.1f%%", r.rate) .. (r.src and (" [" .. r.src .. "]") or "")) or "rate ?"
            say(string.format("  %s%s  %s  %s%s  -  %s",
                r.name, rank ~= "" and (" (" .. rank .. ")") or "",
                levelText(r.lo, r.hi), zoneName(r.zone),
                r.zones > 1 and (" +" .. (r.zones - 1) .. " more zone(s)") or "",
                rate))
        end
    end

    local objs = L.Item.objectDrops(itemId)
    if type(objs) == "table" and #objs > 0 then
        say("  Also found in " .. #objs .. " object(s) (chests, nodes).")
    end
    local vend = L.Item.vendors(itemId)
    if type(vend) == "table" and #vend > 0 then
        say("  Sold by " .. #vend .. " vendor(s).")
    end
end

----------------------------------------------------------------------
-- Search
----------------------------------------------------------------------
local function search(text)
    withIndex(function()
        local needle = text:lower()
        local exact, partial = {}, {}
        for id, nm in pairs(nameIndex) do
            local l = nm:lower()
            if l == needle then
                exact[#exact + 1] = id
            elseif l:find(needle, 1, true) then
                partial[#partial + 1] = id
            end
        end
        table.sort(exact)
        table.sort(partial, function(a, b)
            local na, nb = nameIndex[a], nameIndex[b]
            if #na ~= #nb then return #na < #nb end
            return a < b
        end)

        if #exact >= 1 then
            -- Several items can share a name; show them all if few, else the lowest ID.
            for i = 1, math.min(#exact, 3) do showItem(exact[i]) end
            if #exact > 3 then say(#exact .. " items share that name; showing 3. Use /if #<id> for others.") end
            return
        end
        if #partial == 0 then
            say('No item found matching "' .. text .. '".')
        elseif #partial == 1 then
            showItem(partial[1])
        else
            say(#partial .. ' matches for "' .. text .. '" (showing up to 15). Use /if #<id> or shift-click one:')
            for i = 1, math.min(#partial, 15) do
                say(string.format("  #%d  %s", partial[i], nameIndex[partial[i]]))
            end
        end
    end)
end

----------------------------------------------------------------------
-- Debug helpers
----------------------------------------------------------------------
local function describe(v)
    local tv = type(v)
    if tv == "table" then return "table[" .. countKeys(v) .. "]" end
    if tv == "string" then return '"' .. v .. '"' end
    return tostring(v)
end

local function dumpTable(t, indent, depth)
    indent = indent or "  "
    local shown = 0
    for k, v in pairs(t) do
        say(indent .. "[" .. tostring(k) .. "] = " .. describe(v))
        if type(v) == "table" and depth > 1 then dumpTable(v, indent .. "  ", depth - 1) end
        shown = shown + 1
        if shown >= 8 then say(indent .. "..."); break end
    end
end

local function cmdStatus()
    local L = lib()
    say("LibQuestieDB: " .. (L and "found" or "NOT found"))
    if L then
        say("  contractVersion=" .. tostring(L.contractVersion) .. " readMode=" .. tostring(L.readMode) ..
            " addon=" .. tostring(L.addonName))
        say("  Item API: " .. tostring(L.Item ~= nil) .. "  Npc API: " .. tostring(L.Npc ~= nil))
        if L.Item and L.Item.GetAllIds then say("  item IDs: " .. #L.Item.GetAllIds()) end
    end
    say("QuestieLoader (Questie): " .. (_G.QuestieLoader and "found" or "not found") .. " (needed only for drop rates)")
    say("Item name index: " .. (nameIndex and "built" or "not built yet"))
end

local function cmdRaw(kind, id)
    local L = needLib()
    if not L then return end
    id = tonumber(id)
    if not id then say("Usage: /if raw item <id>   or   /if raw npc <id>"); return end
    if kind == "item" then
        say("item " .. id .. ": name=" .. describe(L.Item.name(id)))
        local nd = L.Item.npcDrops(id)
        say("  npcDrops = " .. describe(nd))
        if type(nd) == "table" then dumpTable(nd, "    ", 1) end
        say("  objectDrops = " .. describe(L.Item.objectDrops(id)))
        say("  vendors = " .. describe(L.Item.vendors(id)))
    elseif kind == "npc" then
        say("npc " .. id .. ": name=" .. describe(L.Npc.name(id)) .. " lvl=" ..
            describe(L.Npc.minLevel(id)) .. "-" .. describe(L.Npc.maxLevel(id)) ..
            " rank=" .. describe(L.Npc.rank(id)) .. " zoneID=" .. describe(L.Npc.zoneID(id)))
        local sp = L.Npc.spawns(id)
        say("  spawns = " .. describe(sp))
        if type(sp) == "table" then dumpTable(sp, "    ", 2) end
    else
        say("Usage: /if raw item <id>   or   /if raw npc <id>")
    end
end

----------------------------------------------------------------------
-- Slash command
----------------------------------------------------------------------
SLASH_ITEMFINDER1 = "/if"
SLASH_ITEMFINDER2 = "/itemfinder"
SlashCmdList["ITEMFINDER"] = function(input)
    input = (input or ""):match("^%s*(.-)%s*$")
    local lower = input:lower()

    if input == "" then
        say("Usage: /if <item name>  |  /if #<id>  |  /if status  |  /if raw item|npc <id>")
        return
    end
    if lower == "status" then cmdStatus(); return end

    local rawKind, rawId = lower:match("^raw%s+(%a+)%s+(%d+)$")
    if lower:sub(1, 3) == "raw" then cmdRaw(rawKind, rawId); return end

    -- Shift-clicked item link
    local linkId = input:match("|Hitem:(%d+)")
    if linkId then showItem(tonumber(linkId)); return end

    local idText = input:match("^#(%d+)$")
    if idText then showItem(tonumber(idText)); return end

    if not needLib() then return end
    search(input)
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    say("v0.0.2 loaded. Type /if <item name> or /if status.")
end)
