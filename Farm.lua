-- Lootwright Farm.lua: the farm list (what you're gathering now) and the mob-tooltip line
-- "Farm: Linen Cloth 43.7% (have 4/15) for Linen Bag" on mobs that drop it.
-- Unlike favorites, this affects the game world, so keep the list short.
--
-- Two kinds of entries:
--   single items   LootwrightDB.farm = { [itemId] = true | { goal = n } }. With a goal, the item
--                  leaves the list once the bags hold that many.
--   recipe groups  LootwrightDB.farmRecipes = { [key] = { name, itemId, makes, crafts, target,
--                  reagents = { { itemId, count, vendorOnly, sub }, ... } } }. The group (and its
--                  materials) leaves the list once the bags hold `target` of the crafted item;
--                  materials never leave on their own. target = owned + crafts x makes, where owned
--                  is what you had (bags and equipped) when you added it. A recipe that makes no item
--                  stays until removed by hand.
--                  A crafted material has sub = { name, makes, reagents = {...} } (same shape, up to
--                  MAX_DEPTH levels), so Bolt of Linen Cloth lists the Linen Cloth it's made from.
--                  Needs are live: each level asks only for what's still missing above it.

local _, ns = ...
local Farm = {}
ns.Farm = Farm

local MAX_DEPTH = 3 -- recipe, material, material of a crafted material

local index    -- [npcId] = { { itemId, rate, fewKills }, ... }
local matIndex -- [itemId] = { farmable = bool } for every material at any depth
-- Both are rebuilt when the farm list changes.

local function list()
    LootwrightDB.farm = LootwrightDB.farm or {}
    return LootwrightDB.farm
end

local function recipes()
    LootwrightDB.farmRecipes = LootwrightDB.farmRecipes or {}
    return LootwrightDB.farmRecipes
end

-- Live needs depend on bag counts and the list. Many places ask for them on each bag change (goals,
-- ready notices, map skulls, tracker, Farm tab) and on every mob-tooltip refresh, so each recipe's
-- rows and each item's need are worked out once and kept until the bags or the list change.
local rowsCache = {} -- [recipe table] = Farm.Rows result
local needCache = {} -- [itemId] = { need, names }

-- Every change to the farm list goes through here, so the map's farm skulls are refreshed here too
-- (they once missed goals set through the amount popup). Cheap: the map only rebuilds when the set of
-- wanted items actually changed.
local function changed()
    index, matIndex = nil, nil
    wipe(rowsCache)
    wipe(needCache)
    if ns.Map and ns.Map.RefreshFarmPins then ns.Map.RefreshFarmPins() end
end

-- BAG_UPDATE fires before the BAG_UPDATE_DELAYED that every handler listens to, so clearing here
-- means all of them see fresh numbers, computed once.
local invalidator = CreateFrame("Frame")
invalidator:RegisterEvent("BAG_UPDATE")
invalidator:SetScript("OnEvent", function()
    wipe(rowsCache)
    wipe(needCache)
end)

local function have(itemId)
    local ok, n = pcall(C_Item.GetItemCount, itemId)
    return (ok and type(n) == "number") and n or 0
end
Farm.Have = have

-- How many are in your bank (shown only; goals count bags and equipped). The game knows the bank
-- once you've opened it this session, so this can be 0 until then.
-- Max stack size of an item, or nil when it doesn't stack (endless farm rows fill per stack).
function Farm.StackSize(itemId)
    local ok, s = pcall(C_Item.GetItemMaxStackSize, itemId)
    if not (ok and type(s) == "number") then
        -- Fallback: the 8th value of GetItemInfo is the stack size (nil until the item is cached).
        local info = C_Item.GetItemInfo or GetItemInfo
        ok, s = pcall(function() return select(8, info(itemId)) end)
    end
    return (ok and type(s) == "number" and s > 1) and s or nil
end

function Farm.Bank(itemId)
    local ok, all = pcall(C_Item.GetItemCount, itemId, true)
    if not ok or type(all) ~= "number" then return 0 end
    return math.max(0, all - have(itemId))
end

-- Crafts still to do for a level: (wanted - in bags) / per craft, rounded up, never below 0.
local function craftsLeft(wanted, itemId, makes)
    local missing = wanted - (itemId and have(itemId) or 0)
    if missing <= 0 then return 0 end
    return math.ceil(missing / math.max(1, makes or 1))
end

-- Flattens one recipe group into rows with live needs:
-- { depth (1 = material, 2 = its material...), itemId, need, vendorOnly, crafted, via (recipe name) }.
-- A crafted material's own materials only appear while some of it is still missing.
-- The result is cached and shared: callers must only read it.
function Farm.Rows(r)
    if rowsCache[r] then return rowsCache[r] end
    local rows = {}
    local function walk(reagents, crafts, depth, via)
        for _, rg in ipairs(reagents or {}) do
            local need = rg.count * crafts
            rows[#rows + 1] = { depth = depth, itemId = rg.itemId, need = need, vendorOnly = rg.vendorOnly,
                crafted = rg.sub ~= nil, via = via, subName = rg.sub and rg.sub.name }
            if rg.sub then
                local sub = craftsLeft(need, rg.itemId, rg.sub.makes)
                if sub > 0 then walk(rg.sub.reagents, sub, depth + 1, rg.sub.name) end
            end
        end
    end
    -- Top level: materials for the crafts still to do (the full count if the recipe makes no item).
    local crafts = r.itemId and r.target and craftsLeft(r.target, r.itemId, r.makes) or r.crafts
    walk(r.reagents, crafts, 1, r.name)
    rowsCache[r] = rows
    return rows
end

local function materials()
    if matIndex then return matIndex end
    matIndex = {}
    local function walk(reagents)
        for _, rg in ipairs(reagents or {}) do
            local m = matIndex[rg.itemId] or { farmable = false }
            matIndex[rg.itemId] = m
            if not rg.vendorOnly then m.farmable = true end
            if rg.sub then walk(rg.sub.reagents) end
        end
    end
    for _, r in pairs(recipes()) do walk(r.reagents) end
    return matIndex
end

-- True when the item is on the farm list in any way (single item or recipe material).
function Farm.Has(itemId) return list()[itemId] ~= nil or materials()[itemId] ~= nil end

-- True when the item is on the list as a single item (what the Farm button toggles).
function Farm.IsSingle(itemId) return list()[itemId] ~= nil end

function Farm.Toggle(itemId)
    local l = list()
    l[itemId] = (not l[itemId]) or nil
    changed()
end

-- Goal count for a single farm item, or nil.
function Farm.Goal(itemId)
    local v = list()[itemId]
    return type(v) == "table" and v.goal or nil
end

-- What the farm list needs of an item: total need (recipe materials summed, else the single goal)
-- and the names of the recipes it's for.
-- (live; 0 means every recipe that uses it has enough).
function Farm.Need(itemId)
    local c = needCache[itemId]
    if c then return c[1], c[2] end
    local names, need, used = {}, 0, false
    if materials()[itemId] then
        for _, r in pairs(recipes()) do
            for _, row in ipairs(Farm.Rows(r)) do
                if row.itemId == itemId then
                    used = true
                    need = need + row.need
                    names[#names + 1] = row.via
                end
            end
        end
    end
    if not used then need = Farm.Goal(itemId) end
    needCache[itemId] = { need, names } -- names is shared: callers only read it
    return need, names
end

local function notify()
    changed() -- also refreshes the map's farm skulls
    if ns.UI.OnFarmChanged then ns.UI.OnFarmChanged() end
end

local function announce(msg)
    ns.say(msg)
    if UIErrorsFrame and LootwrightDB.farmAlerts ~= false then UIErrorsFrame:AddMessage(msg, 0.25, 1, 0.25) end
end

-- Sub-goals: announce a material the moment it becomes ready (have >= need), and a recipe the
-- moment all its top-level materials are ready. State is kept in memory only, and the first time a
-- row is seen (login, a new recipe) it's just recorded, so nothing fires for what was already ready.
local readyState = {} -- [recipeKey .. ":" .. depth .. ":" .. itemId] or [recipeKey .. ":all"] = bool

local function checkSubGoals()
    for key, r in pairs(recipes()) do
        local allReady, anyTop = true, false
        for _, row in ipairs(Farm.Rows(r)) do
            local ready = row.need > 0 and have(row.itemId) >= row.need
            local k = key .. ":" .. row.depth .. ":" .. row.itemId
            if ready and readyState[k] == false then
                announce(r.name .. ": " .. (ns.Data.ItemName(row.itemId) or ("item " .. row.itemId))
                    .. " ready (" .. have(row.itemId) .. "/" .. row.need .. ").")
            end
            readyState[k] = ready
            if row.depth == 1 then
                anyTop = true
                if not ready then allReady = false end
            end
        end
        local k = key .. ":all"
        local all = anyTop and allReady
        if all and readyState[k] == false then
            announce(r.name .. ": all materials ready. Craft it!")
        end
        readyState[k] = all
    end
end

-- Removes single items and recipe groups whose goal is reached. Returns true if anything changed.
local function checkGoals()
    local any = false
    for itemId, v in pairs(list()) do
        if type(v) == "table" and v.goal then
            local n = have(itemId)
            if n >= v.goal then
                list()[itemId] = nil
                any = true
                announce("Farm goal reached: " .. (ns.Data.ItemName(itemId) or ("item " .. itemId))
                    .. " " .. n .. "/" .. v.goal .. ". Removed from the farm list.")
            end
        end
    end
    for key, r in pairs(recipes()) do
        if r.itemId and r.target and have(r.itemId) >= r.target then
            recipes()[key] = nil
            any = true
            announce("Recipe goal reached: " .. r.name .. " " .. have(r.itemId) .. "/" .. r.target
                .. ". Removed it and its materials from the farm list.")
        end
    end
    if any then notify() end
    checkSubGoals()
    return any
end

-- Sets or clears (n = nil or 0) a single item's goal; farms the item if it wasn't yet.
function Farm.SetGoal(itemId, n)
    n = tonumber(n)
    list()[itemId] = (n and n > 0) and { goal = math.floor(n) } or true
    changed()
    checkGoals()
end

-- Adds (or replaces) a recipe group. rec = { id, name, itemId, makes, reagents = { { itemId, count } } };
-- isVendorOnly(itemId) marks materials only sold by vendors; recipeFor(itemId) returns the recipe that
-- makes a material (or nil), so crafted materials get their own materials as a sub-level.
function Farm.AddRecipe(rec, crafts, isVendorOnly, recipeFor)
    crafts = math.max(1, math.floor(tonumber(crafts) or 1))
    local makes = math.max(1, tonumber(rec.makes) or 1)
    local function copy(reagents, depth, seen)
        local out = {}
        for _, rg in ipairs(reagents or {}) do
            local vendorOnly = isVendorOnly and isVendorOnly(rg.itemId) or nil
            local e = { itemId = rg.itemId, count = rg.count, vendorOnly = vendorOnly }
            -- Expand crafted materials (not vendor-bought ones, no loops, limited depth).
            local sub = not vendorOnly and depth < MAX_DEPTH and not seen[rg.itemId] and recipeFor and recipeFor(rg.itemId)
            if sub and sub.reagents and #sub.reagents > 0 then
                seen[rg.itemId] = true
                e.sub = { name = sub.name, makes = math.max(1, tonumber(sub.makes) or 1),
                    reagents = copy(sub.reagents, depth + 1, seen) }
                seen[rg.itemId] = nil
            end
            out[#out + 1] = e
        end
        return out
    end
    local key = rec.id and ("r" .. rec.id) or rec.name
    -- The goal is on top of what you own now (bags and equipped, as GetItemCount counts), so a bag
    -- or armour piece you already wear doesn't finish the goal the moment you add it.
    local owned = rec.itemId and have(rec.itemId) or 0
    recipes()[key] = { name = rec.name, itemId = rec.itemId, makes = makes, crafts = crafts, owned = owned,
        target = rec.itemId and owned + crafts * makes or nil,
        reagents = copy(rec.reagents, 1, rec.itemId and { [rec.itemId] = true } or {}) }
    notify()
    checkGoals()
end

function Farm.RemoveRecipe(key)
    recipes()[key] = nil
    notify()
end

-- Recipe groups as a sorted list of { key, name, itemId, target, crafts, rows } (rows: Farm.Rows).
function Farm.RecipeList()
    local t = {}
    for key, r in pairs(recipes()) do
        t[#t + 1] = { key = key, name = r.name, itemId = r.itemId, target = r.target, crafts = r.crafts, owned = r.owned,
            rows = Farm.Rows(r) }
    end
    table.sort(t, function(a, b) return a.name < b.name end)
    return t
end

-- Items to show on the map: single farm items, plus farmable recipe materials still needed.
-- Returns { [itemId] = true }.
function Farm.WantedItems()
    local t = {}
    for id in pairs(list()) do t[id] = true end
    for id, m in pairs(materials()) do
        if m.farmable and (Farm.Need(id) or 0) > 0 then t[id] = true end
    end
    return t
end

-- Single farm item IDs, sorted.
function Farm.Ids()
    local t = {}
    for id in pairs(list()) do t[#t + 1] = id end
    table.sort(t)
    return t
end

local function build()
    index = {}
    if not ns.Data.Available() then return end
    local ids = {}
    for itemId in pairs(list()) do ids[itemId] = true end
    for itemId, m in pairs(materials()) do
        if m.farmable then ids[itemId] = true end -- vendor-only materials get no mob lines
    end
    for itemId in pairs(ids) do
        local ok, src = pcall(ns.Data.GetSources, itemId)
        if ok then
            for _, m in ipairs(src.mobs) do
                local e = index[m.npcId] or {}
                index[m.npcId] = e
                e[#e + 1] = { itemId = itemId, rate = m.rate, fewKills = m.fewKills, rough = m.rough }
            end
        end
    end
end

-- Farm items this NPC drops, or nil.
function Farm.ForNpc(npcId)
    if not index then build() end
    return index[npcId]
end

-- "Linen Cloth 43.7% (have 4/15) for Linen Bag"
function Farm.Line(e)
    local name = ns.Data.ItemName(e.itemId) or ("item " .. e.itemId)
    local rate = e.rate and (" " .. ns.RateText(e.rate, e.fewKills, e.rough)) or " rate ?"
    local need, forNames = Farm.Need(e.itemId)
    local line = name .. rate .. " (have " .. have(e.itemId) .. (need and ("/" .. need) or "") .. ")"
    if #forNames > 0 then line = line .. " for " .. table.concat(forNames, ", ") end
    return line
end

-- Bag changes: check goals (BAG_UPDATE_DELAYED fires once after a batch of bag changes).
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("BAG_UPDATE_DELAYED")
watcher:SetScript("OnEvent", function()
    if next(list()) or next(recipes()) then
        checkGoals()
        -- A material can stop being needed without the list changing (e.g. the bolts are made).
        if ns.Map and ns.Map.RefreshFarmPins then ns.Map.RefreshFarmPins() end
    end
end)

-- NPC ID from a creature GUID ("Creature-0-server-instance-zone-NPCID-spawn"), or nil.
local function npcIdFromGuid(guid)
    if type(guid) ~= "string" or (issecretvalue and issecretvalue(guid)) then return nil end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" and kind ~= "Vehicle" then return nil end
    return tonumber(id)
end

if TooltipDataProcessor and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip, data)
        -- Out of combat only: unit data can be restricted during fights.
        if tooltip ~= GameTooltip or InCombatLockdown() or LootwrightDB.farmTooltip == false then return end
        if not (next(list()) or next(recipes())) then return end
        local guid = type(data) == "table" and data.guid
        if not guid then
            local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
            if ok and unit then guid = UnitGUID(unit) end
        end
        local npcId = npcIdFromGuid(guid)
        local entries = npcId and Farm.ForNpc(npcId)
        if not entries then return end
        for _, e in ipairs(entries) do
            -- Skip recipe materials no recipe still needs (e.g. cloth once the bolts are made).
            if Farm.IsSingle(e.itemId) or (Farm.Need(e.itemId) or 0) > 0 then
                tooltip:AddLine("Farm: " .. Farm.Line(e), 0.25, 1, 0.25)
            end
        end
    end)
end
