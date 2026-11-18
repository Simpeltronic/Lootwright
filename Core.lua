-- ItemFinder v0.1.0 (Phase 2): init, slash command, saved-variables log, shared formatting.
-- Data access lives in Data.lua, the name index in Search.lua, the window in UI.lua.
--
-- Commands:
--   /if                 open / close the window (on the last used tab)
--   /if <text>          search items by name (substring), output in chat; shift-click an item to look it up
--   /if #<id>           show sources for an item ID in chat
--   /if tooltip         toggle the "Drops from" line on item tooltips
--   /if clear           remove ItemFinder's world map pins
--   /if prof            open the window on the Professions tab
--   /if farm            open the window on the Farm tab
--   /if status          check that QuestieDB is available and its contract matches
--   /if raw item <id>   dump raw fields for an item
--   /if raw npc <id>    dump raw fields for an NPC, including the spawn table layout

local _, ns = ...
local VERSION = "0.1.0"
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
ns.say = say

local function needLib()
    if ns.Data.Available() then return true end
    say("QuestieDB's API (LibQuestieDB) is not available. Is the QuestieDB addon enabled? Try /if status.")
    return false
end
ns.needLib = needLib

----------------------------------------------------------------------
-- Shared formatting (chat and UI)
----------------------------------------------------------------------
ns.RANKS = { [0] = "", [1] = "Elite", [2] = "Rare Elite", [3] = "Boss", [4] = "Rare" }

function ns.LevelText(lo, hi)
    if not lo or lo == 0 then return "?" end
    if not hi or hi == lo or hi == 0 then return tostring(lo) end
    return lo .. "-" .. hi
end

-- rate text; "*" marks a rate from very few kills.
function ns.RateText(rate, fewKills)
    if not rate then return "rate unknown" end
    return string.format("%.1f%%", rate) .. (fewKills and "*" or "")
end

-- 0 = real rate, 1 = rate from very few kills, 2 = unknown.
function ns.RateTier(r)
    if not r.rate then return 2 end
    return r.fewKills and 1 or 0
end

-- Highest rate first within each tier (real, few kills, unknown), then by name.
function ns.SortByRate(a, b)
    local ta, tb = ns.RateTier(a), ns.RateTier(b)
    if ta ~= tb then return ta < tb end
    if a.rate and a.rate ~= b.rate then return a.rate > b.rate end
    if a.name ~= b.name then return a.name < b.name end
    return a.npcId < b.npcId
end

----------------------------------------------------------------------
-- Chat output
----------------------------------------------------------------------
local MAX_NPCS = 25

local function showItem(itemId)
    if not needLib() then return end
    local name = ns.Data.ItemName(itemId) or ("item " .. itemId)
    local link = select(2, C_Item.GetItemInfo(itemId)) or name
    say("Sources for " .. link .. " (id " .. itemId .. "):")

    local src = ns.Data.GetSources(itemId)
    local rows = src.mobs
    if #rows == 0 then
        say("  No mob drops recorded.")
    else
        if src.fromDropTable then say("  (mob list from QuestieDB's quest-item drop table)") end
        table.sort(rows, ns.SortByRate)
        say("  " .. #rows .. " mob(s) drop it" .. (#rows > MAX_NPCS and (" (showing " .. MAX_NPCS .. ")") or "") .. ":")
        for i = 1, math.min(#rows, MAX_NPCS) do
            local r = rows[i]
            local rank = ns.RANKS[r.rank] or ""
            say(string.format("  %s%s  L%s  %s%s  -  %s%s",
                r.name, rank ~= "" and (" (" .. rank .. ")") or "",
                ns.LevelText(r.minLevel, r.maxLevel), r.zone,
                r.zones > 1 and (" +" .. (r.zones - 1) .. " more zone(s)") or "",
                ns.RateText(r.rate, r.fewKills), r.source and (" [" .. r.source .. "]") or ""))
        end
    end
    for _, r in ipairs(rows) do
        if r.fewKills then say("  * rate from very few kills, unreliable") break end
    end
    if src.objects > 0 then say("  Also found in " .. src.objects .. " object(s) (chests, nodes).") end
    if src.vendors > 0 then say("  Sold by " .. src.vendors .. " vendor(s).") end
end

local function search(text)
    ns.Search.Find(text, function(ids, nExact)
        if nExact >= 1 then
            -- Several items can share a name; show them all if few, else the lowest IDs.
            for i = 1, math.min(nExact, 3) do showItem(ids[i]) end
            if nExact > 3 then say(nExact .. " items share that name; showing 3. Use /if #<id> for others.") end
        elseif #ids == 0 then
            say('No item found matching "' .. text .. '".')
        elseif #ids == 1 then
            showItem(ids[1])
        else
            say(#ids .. ' matches for "' .. text .. '" (showing up to 15). Use /if #<id> or shift-click one:')
            for i = 1, math.min(#ids, 15) do
                say(string.format("  #%d  %s", ids[i], ns.Search.Name(ids[i])))
            end
        end
    end)
end

----------------------------------------------------------------------
-- Debug helpers
----------------------------------------------------------------------
local function describe(v)
    local tv = type(v)
    if tv == "table" then return "table[" .. ns.Data.CountKeys(v) .. "]" end
    if tv == "string" then return '"' .. v .. '"' end
    return tostring(v)
end

local function dumpTable(t, indent, depth)
    local shown = 0
    for k, v in pairs(t) do
        say(indent .. "[" .. tostring(k) .. "] = " .. describe(v))
        if type(v) == "table" and depth > 1 then dumpTable(v, indent .. "  ", depth - 1) end
        shown = shown + 1
        if shown >= 8 then say(indent .. "..."); break end
    end
end

local function cmdStatus()
    local s = ns.Data.Status()
    say("LibQuestieDB: " .. (s.lib and "found" or "NOT found"))
    if s.lib then
        say("  contractVersion=" .. tostring(s.contractVersion) .. " readMode=" .. tostring(s.readMode) ..
            " addon=" .. tostring(s.addonName))
        say("  Item API: " .. tostring(s.itemApi) .. "  Npc API: " .. tostring(s.npcApi))
        if s.itemCount then say("  item IDs: " .. s.itemCount) end
    end
    say("  contract: needs " .. s.contractWanted .. ", " .. (s.contractOk and "OK" or ("FAILED: " .. tostring(s.contractMsg))))
    say("Item name index: " .. (ns.Search.IsBuilt() and "built" or "not built yet"))
end

local function cmdRaw(kind, id)
    if not needLib() then return end
    id = tonumber(id)
    if kind == "item" and id then
        local r = ns.Data.RawItem(id)
        say("item " .. id .. ": name=" .. describe(r.name))
        say("  npcDrops = " .. describe(r.npcDrops))
        if type(r.npcDrops) == "table" then dumpTable(r.npcDrops, "    ", 1) end
        say("  objectDrops = " .. describe(r.objectDrops))
        say("  vendors = " .. describe(r.vendors))
    elseif kind == "npc" and id then
        local r = ns.Data.RawNpc(id)
        say("npc " .. id .. ": name=" .. describe(r.name) .. " lvl=" .. describe(r.minLevel) .. "-" ..
            describe(r.maxLevel) .. " rank=" .. describe(r.rank) .. " zoneID=" .. describe(r.zoneID))
        say("  spawns = " .. describe(r.spawns))
        if type(r.spawns) == "table" then dumpTable(r.spawns, "    ", 2) end
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

    if input == "" then ns.UI.Toggle(); return end
    if lower == "help" then
        say("/if  (window)  |  /if <item name>  |  /if #<id>  |  /if tooltip (toggle)  |  /if clear (map pins)  |  /if prof  |  /if farm  |  /if status  |  /if raw item|npc <id>")
        return
    end
    if lower == "prof" then ns.UI.ShowTab("prof"); return end
    if lower == "farm" then ns.UI.ShowTab("farm"); return end
    if lower == "clear" then ns.Map.Clear(); say("Map pins cleared."); return end
    if lower == "tooltip" then
        ItemFinderDB.tooltip = ItemFinderDB.tooltip == false -- nil (default) counts as on
        say("Tooltip \"Drops from\" line: " .. (ItemFinderDB.tooltip and "on" or "off"))
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
    say("v" .. VERSION .. " loaded. Type /if to open the window, /if help for commands.")
    -- A QuestieDB update that breaks the API we use should say so, not fail silently.
    local ok, msg = ns.Data.CheckContract()
    if not ok then say("|cffff4040" .. tostring(msg) .. "|r ItemFinder can't read its data until this is fixed.") end
end)
