-- Lootwright Loot.lua: records your own loot, so Lootwright can show drop rates measured by you.
-- LootwrightDB.loot = { since = game build, mobs = { [npcId] = { n = corpses, e = empty ones, [itemId] = corpses it was on } } }
-- n counts looted corpses plus empty kills: when your target dies (your tap, not in a group) and
-- CanLootUnit says it has no loot, it counts as an empty corpse. Kills with loot you never take don't
-- count at all. Kills that weren't your target can't be seen as empty, so rates may still be a bit high.
-- Option recordLoot (nil = on). /if loot shows a summary, /if loot debug prints each recorded corpse.

local _, ns = ...
local Loot = {}
ns.Loot = Loot

local MIN_CORPSES = 20 -- fewer looted corpses say too little; same minimum as build_data.py's agreement check
Loot.MIN_CORPSES = MIN_CORPSES

local seen = {}  -- corpse GUIDs counted this session (re-opening, skinning and AoE loot count once)
local debug = false

local function plain(v)
    if v == nil or (issecretvalue and issecretvalue(v)) then return nil end
    return v
end

local function db()
    local l = LootwrightDB.loot
    if type(l) ~= "table" then
        l = { since = (GetBuildInfo()), mobs = {} }
        LootwrightDB.loot = l
    end
    return l
end

-- NPC ID from a creature GUID ("Creature-0-[server]-[instance]-[zone]-[npcId]-[spawn]"), else nil.
local function npcFromGuid(guid)
    if type(guid) ~= "string" then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return nil end
    return tonumber(id)
end

-- Pickpocketing opens loot on a living mob: that isn't a corpse.
local function isLivingTarget(guid)
    local ok, tguid = pcall(UnitGUID, "target")
    if not ok or plain(tguid) ~= guid then return false end
    local ok2, dead = pcall(UnitIsDead, "target")
    return ok2 and plain(dead) == false
end

-- Empty kills -----------------------------------------------------------------------------------
local pending = {} -- [guid] = true while we wait to see whether a dead target has loot
local EMPTY_CHECKS = { 1, 3 } -- seconds after death; loot can take a moment to appear

local told = {} -- [guid] = true once debug has said why a dead target was skipped

local function skip(guid, why)
    if debug and guid and not told[guid] then
        told[guid] = true
        ns.say("Loot: dead target not counted as empty: " .. why)
    end
end

-- true/false whether the corpse has loot for you, nil when unknown. On Forever CanLootUnit's first
-- value is true even on an empty corpse (checked on a Barrens giraffe); the second one, canLoot, is false then.
local function hasLoot(guid)
    if not CanLootUnit then return nil end
    local ok, _, can = pcall(CanLootUnit, guid)
    if not ok then return nil end
    return plain(can)
end

local emptied = {} -- [guid] = npcId for corpses counted as empty this session (undone if you loot them after all)

-- canLoot is also false when you're too far away to loot, so only trust it close up:
-- CheckInteractDistance index 3 is about 10 yards. Loot range is shorter, so a corpse 5-10 yards
-- away can still read empty; looting it later undoes the empty count (see onLootReady).
local function closeTo(guid)
    if plain(UnitGUID("target")) ~= guid then return false end
    local ok, near = pcall(CheckInteractDistance, "target", 3)
    return ok and plain(near) == true
end

local function countEmpty(guid)
    local npcId = npcFromGuid(guid)
    if not npcId or seen[guid] then return end
    seen[guid] = true
    emptied[guid] = npcId
    local m = db().mobs[npcId] or { n = 0 }
    db().mobs[npcId] = m
    m.n, m.e = m.n + 1, (m.e or 0) + 1
    if debug then ns.say(string.format("Loot: npc %d corpse #%d: empty kill", npcId, m.n)) end
end

local function checkEmpty(guid, step)
    if seen[guid] then pending[guid] = nil return end -- looted meanwhile
    local has = hasLoot(guid)
    if has == true then pending[guid] = nil return end -- has loot: counted when you open it
    if has == nil then pending[guid] = nil; skip(guid, "CanLootUnit gave no answer") return end
    if not closeTo(guid) then pending[guid] = nil; skip(guid, "too far away to tell (target it within 10 yards)") return end
    if EMPTY_CHECKS[step + 1] then
        C_Timer.After(EMPTY_CHECKS[step + 1] - EMPTY_CHECKS[step], function() checkEmpty(guid, step + 1) end)
    else
        pending[guid] = nil
        countEmpty(guid)
    end
end

-- Runs when the target's health changes, its flags change, you change target or combat ends: the
-- dead flag can come after the last health event, and some values are hidden during combat.
local function onTargetCheck()
    if LootwrightDB.recordLoot == false then return end
    local guid = plain(UnitGUID("target"))
    if not guid or pending[guid] or seen[guid] or not npcFromGuid(guid) then return end
    -- The game clears your target when it dies, so catch the death on the last health update
    -- (health 0, the dead flag may come later); re-targeting the corpse runs this again too.
    if plain(UnitIsDead("target")) ~= true and plain(UnitHealth("target")) ~= 0 then return end
    if IsInGroup() then return skip(guid, "in a group") end -- the loot may not be yours
    local denied = plain(UnitIsTapDenied("target"))
    if denied == nil then return skip(guid, "tap state hidden (in combat?)") end
    if denied then return skip(guid, "tapped by someone else") end
    if not CanLootUnit then return skip(guid, "CanLootUnit is missing") end
    pending[guid] = true
    C_Timer.After(EMPTY_CHECKS[1], function() checkEmpty(guid, 1) end)
end

local function onLootReady()
    if LootwrightDB.recordLoot == false then return end
    local ok, n = pcall(GetNumLootItems)
    n = ok and plain(n) or 0
    local corpses = {} -- [guid] = { [itemId] = true }
    for slot = 1, n do
        local link = plain(GetLootSlotLink(slot))
        local itemId = link and tonumber(link:match("|Hitem:(%d+)"))
        if itemId then
            local _, _, _, _, _, classId = C_Item.GetItemInfoInstant(itemId)
            if classId == 12 then itemId = nil end -- quest items drop only while on the quest
        end
        local src = { pcall(GetLootSourceInfo, slot) }
        if src[1] then
            for i = 2, #src, 2 do -- guid, quantity, guid, quantity, ...
                local guid = plain(src[i])
                local undo = guid and emptied[guid]
                if undo then -- counted as empty, but it had loot after all
                    local m = db().mobs[undo]
                    m.n, m.e = m.n - 1, m.e - 1
                    emptied[guid], seen[guid] = nil, nil
                    if debug then ns.say("Loot: npc " .. undo .. " wasn't empty after all, empty count undone") end
                end
                if guid and not seen[guid] and npcFromGuid(guid) then
                    local c = corpses[guid] or {}
                    corpses[guid] = c
                    if itemId then c[itemId] = true end
                end
            end
        end
    end
    local mobs = db().mobs
    for guid, items in pairs(corpses) do
        if not isLivingTarget(guid) then
            seen[guid] = true
            local npcId = npcFromGuid(guid)
            local m = mobs[npcId] or { n = 0 }
            mobs[npcId] = m
            m.n = m.n + 1
            local names = {}
            for itemId in pairs(items) do
                m[itemId] = (m[itemId] or 0) + 1
                if debug then names[#names + 1] = ns.Data.ItemName(itemId) or tostring(itemId) end
            end
            if debug then
                ns.say(string.format("Loot: npc %d corpse #%d: %s", npcId, m.n,
                    #names > 0 and table.concat(names, ", ") or "no items counted"))
            end
        end
    end
end

-- 95% range (percent) for something seen k times in n corpses (Wilson score interval).
function Loot.Range(k, n)
    local z = 1.96
    local p, d = k / n, 1 + z * z / n
    local mid = (p + z * z / (2 * n)) / d
    local half = z * math.sqrt(p * (1 - p) / n + z * z / (4 * n * n)) / d
    return math.max(0, mid - half) * 100, math.min(1, mid + half) * 100
end
do
    local lo, hi = Loot.Range(5, 10)
    assert(lo < 50 and hi > 50 and Loot.Range(0, 30) == 0)
end

-- Your count for one mob and item: corpses it was on, looted corpses. nil when you've looted none.
function Loot.Get(npcId, itemId)
    local l = LootwrightDB.loot
    local m = type(l) == "table" and l.mobs and l.mobs[npcId]
    if not m or not m.n or m.n == 0 then return nil end
    return m[itemId] or 0, m.n
end

-- Tooltip line for a mob row, e.g. "You: 9 of 40 corpses (22.5%, likely 12-38%)", or nil.
-- inside: true/false when the source rate fits your range (enough corpses), else nil.
function Loot.Line(npcId, itemId, sourceRate)
    local k, n = Loot.Get(npcId, itemId)
    if not k then return nil end
    local line = string.format("You: %d of %d corpses", k, n)
    if n < MIN_CORPSES then return line .. string.format(" (rate shows after %d)", MIN_CORPSES), nil end
    local lo, hi = Loot.Range(k, n)
    line = line .. string.format(" (%.1f%%, likely %.0f-%.0f%%)", 100 * k / n, lo, hi)
    local inside
    if sourceRate then inside = sourceRate >= lo and sourceRate <= hi end
    return line, inside
end

local function show(v)
    if issecretvalue and issecretvalue(v) then return "hidden" end
    return tostring(v)
end

-- /if loot target: what the game says about your target, to see why an empty kill isn't counted.
local function inspectTarget()
    local ok, guid = pcall(UnitGUID, "target")
    local g = ok and plain(guid)
    local okL, has, can = false, nil, nil
    if g and CanLootUnit then okL, has, can = pcall(CanLootUnit, g) end
    ns.say(string.format("Target: guid=%s npc=%s dead=%s tapDenied=%s inGroup=%s CanLootUnit=%s -> %s, %s; counted=%s",
        ok and show(guid) or "error", tostring(npcFromGuid(g)), show(UnitIsDead("target")), show(UnitIsTapDenied("target")),
        tostring(IsInGroup()), CanLootUnit and "exists" or "missing", okL and show(has) or "-", okL and show(can) or "-",
        tostring(g and seen[g] or false)))
end

function Loot.Command(arg)
    if arg == "target" then return inspectTarget() end
    if arg == "debug" then
        debug = not debug
        ns.say("Loot recording debug: " .. (debug and "on (each recorded corpse is printed)" or "off"))
        return
    end
    local l = db()
    local kinds, corpses, enough = 0, 0, 0
    for _, m in pairs(l.mobs) do
        kinds, corpses = kinds + 1, corpses + (m.n or 0)
        if (m.n or 0) >= MIN_CORPSES then enough = enough + 1 end
    end
    local empty = 0
    for _, m in pairs(l.mobs) do empty = empty + (m.e or 0) end
    ns.say(string.format("Your loot: %d corpses (%d of them empty kills) from %d mob kinds since build %s; %d kinds with %d+ corpses. Recording is %s.",
        corpses, empty, kinds, tostring(l.since), enough, MIN_CORPSES, LootwrightDB.recordLoot == false and "off" or "on"))
end

local f = CreateFrame("Frame")
f:RegisterEvent("LOOT_READY")
f:RegisterUnitEvent("UNIT_HEALTH", "target")
f:RegisterUnitEvent("UNIT_FLAGS", "target")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_REGEN_ENABLED")
f:SetScript("OnEvent", function(_, event)
    local ok, err = pcall(event == "LOOT_READY" and onLootReady or onTargetCheck)
    if not ok and debug then ns.say("Loot recording error: " .. tostring(err)) end
end)
