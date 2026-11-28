-- LibLootwright: Lootwright's own data as a library other addons can use (Lootwright uses it too).
--
-- Add `## Dependencies: Lootwright_Data` (or OptionalDeps) to your TOC; it's load-on-demand, so a
-- dependency loads it with your addon. Then check the contract and read through the functions below:
--
--   if LibLootwright and LibLootwright.RequireContract(1) then ... end
--
-- Contract 1 (functions keep these names, arguments and return shapes while the number stays 1):
--   LibLootwright.Contract                 1
--   LibLootwright.DataVersion              ForeverDB data version the file was built from
--   LibLootwright.RequireContract(n)       true if this library offers contract n, else false + message
--   LibLootwright.MobRates(itemId)         { [npcId] = percent } from CMaNGOS classic-db (Classic 1.12,
--                                          drops of 1% and up, rough for Forever), or nil
--   LibLootwright.CommunityRates(itemId)   { [npcId] = { k = corpses with the item, n = looted corpses } } from
--                                          Lootwright players' shared loot in Forever (mobs with 20+ corpses;
--                                          open data, CC BY 4.0, credit "Lootwright players"), or nil
--   LibLootwright.CommunityItemCount()     number of items with community rates
--   LibLootwright.Contributors()           { "nickname", ... } of players who shared loot (may be empty)
--   LibLootwright.BossLoot(itemId)         { [npcId] = { rate = percent or nil, kills = n, measured = bool } }
--                                          dungeon and raid bosses; measured = rate measured in Forever
--                                          (ForeverDB.net, over `kills` kills), else Classic data; or nil
--   LibLootwright.Boss(npcId)              name, instance name, instance levels ("17-24"), or nil
--   LibLootwright.CraftedBy(itemId)        profession, recipe name of a recipe that makes the item, or nil
--   LibLootwright.Professions()            { "Alchemy", "Blacksmithing", ... }
-- LibLootwright.data is the raw table behind these; its layout may change between versions.
--
-- Licences: ForeverDB data is GPL-3.0 with an attribution term: show "Data from ForeverDB.net
-- (https://foreverdb.net)" where your addon lists its sources. CMaNGOS data is GPL-3.0.

local Lib = LibLootwright
if not Lib or not Lib.data then return end -- GeneratedData.lua didn't load

local data = Lib.data
Lib.Contract = 1
Lib.DataVersion = data.version

function Lib.RequireContract(n)
    if n == Lib.Contract then return true end
    return false, "LibLootwright offers contract " .. Lib.Contract .. ", not " .. tostring(n)
end

function Lib.MobRates(itemId)
    local s = data.mobRates and data.mobRates[itemId]
    if type(s) ~= "string" then return nil end
    local t = {}
    for npc, pct in s:gmatch("(%d+):([%d.]+)") do t[tonumber(npc)] = tonumber(pct) end
    return t
end

-- Added to contract 1 in Lootwright 0.14.0 (new function, nothing else changed).
function Lib.CommunityRates(itemId)
    local s = data.communityRates and data.communityRates[itemId]
    if type(s) ~= "string" then return nil end
    local t = {}
    for npc, k, n in s:gmatch("(%d+):(%d+):(%d+)") do t[tonumber(npc)] = { k = tonumber(k), n = tonumber(n) } end
    return t
end

-- Added to contract 1 in Lootwright 0.15.3: how many items have community rates.
function Lib.CommunityItemCount()
    local n = 0
    for _ in pairs(data.communityRates or {}) do n = n + 1 end
    return n
end

-- Added to contract 1 in Lootwright 0.15.3: nicknames of players who shared loot (a copy).
function Lib.Contributors()
    local t = {}
    for i, name in ipairs(data.thanks or {}) do t[i] = name end
    return t
end

function Lib.BossLoot(itemId)
    local s = data.bossLoot and data.bossLoot[itemId]
    if type(s) ~= "string" then return nil end
    local t = {}
    for npc, pct, kills, src in s:gmatch("(%d+):([%d.]+):(%d+):(%a)") do
        pct = tonumber(pct)
        t[tonumber(npc)] = { rate = (pct and pct > 0) and pct or nil, kills = tonumber(kills) or 0, measured = src == "f" }
    end
    return t
end

function Lib.Boss(npcId)
    local b = data.bosses and data.bosses[npcId]
    if not b then return nil end
    return b[1], b[2], b[3]
end

local craftIndex -- [itemId] = { profession, recipe name }, built on first use
function Lib.CraftedBy(itemId)
    if not craftIndex then
        craftIndex = {}
        for prof, list in pairs(data.recipes or {}) do
            for _, r in ipairs(list) do
                if type(r[4]) == "number" and not craftIndex[r[4]] then craftIndex[r[4]] = { prof, r[2] } end
            end
        end
    end
    local c = craftIndex[itemId]
    if c then return c[1], c[2] end
end

function Lib.Professions()
    local t = {}
    for prof in pairs(data.recipes or {}) do t[#t + 1] = prof end
    table.sort(t)
    return t
end
