-- ItemFinder Prof.lua: reads the open profession window and saves the known recipes and their
-- materials, per character, in ItemFinderDB.prof[<name-realm>][<profession>] = { recipes = {...} }.
-- recipe = { name, itemId (crafted item, may be nil), reagents = { { itemId, count }, ... } }
-- Forever's profession window may use the modern (C_TradeSkillUI) or the classic (GetTradeSkill*)
-- functions; we try modern first, then classic, and log which one worked.
-- shortcut: no classic "craft" window (old Enchanting UI); add GetCraft* if Enchanting shows nothing.

-- Part of the ItemFinder_Professions sub-addon: joins ItemFinder's namespace.
local ns = ItemFinderNS
if not ns then return end
local Prof = {}
ns.Prof = Prof

local function try(fn, ...)
    if not fn then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    return unpack(r, 2)
end

local function itemIdFromLink(link)
    return type(link) == "string" and tonumber(link:match("item:(%d+)")) or nil
end

local function store()
    ItemFinderDB.prof = ItemFinderDB.prof or {}
    local key = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    ItemFinderDB.prof[key] = ItemFinderDB.prof[key] or {}
    return ItemFinderDB.prof[key]
end

local function scanModern()
    local T = C_TradeSkillUI
    if not (T and T.GetAllRecipeIDs and T.GetRecipeSchematic) then return nil end
    local ids = try(T.GetAllRecipeIDs)
    if type(ids) ~= "table" or #ids == 0 then return nil end

    local name
    local base = try(T.GetBaseProfessionInfo)
    if type(base) == "table" then name = base.professionName end
    if not name then
        local r = { try(T.GetTradeSkillLine) }
        name = type(r[1]) == "table" and r[1].professionName or r[2]
    end
    if type(name) ~= "string" or name == "" then return nil end

    local BASIC = Enum.CraftingReagentType and Enum.CraftingReagentType.Basic
    local recipes = {}
    for _, id in ipairs(ids) do
        local info = try(T.GetRecipeInfo, id)
        if info and info.learned ~= false then
            local s = try(T.GetRecipeSchematic, id, false)
            if type(s) == "table" then
                local rec = { id = id, name = info.name or s.name or ("recipe " .. id), itemId = s.outputItemID, reagents = {} }
                for _, slot in ipairs(s.reagentSlotSchematics or {}) do
                    local rg = slot.reagents and slot.reagents[1]
                    if rg and rg.itemID and (not BASIC or slot.reagentType == nil or slot.reagentType == BASIC) then
                        rec.reagents[#rec.reagents + 1] = { itemId = rg.itemID, count = slot.quantityRequired or 1 }
                    end
                end
                recipes[#recipes + 1] = rec
            end
        end
    end
    return name, recipes, "modern"
end

local function scanClassic()
    if not (GetNumTradeSkills and GetTradeSkillInfo and GetTradeSkillLine) then return nil end
    local name = try(GetTradeSkillLine)
    local n = try(GetNumTradeSkills) or 0
    if type(name) ~= "string" or name == "" or name == "UNKNOWN" or n == 0 then return nil end
    local recipes = {}
    for i = 1, n do
        local rn, rtype = try(GetTradeSkillInfo, i)
        if rn and rtype ~= "header" and rtype ~= "subheader" then
            local link = GetTradeSkillRecipeLink and try(GetTradeSkillRecipeLink, i)
            local rec = { id = type(link) == "string" and tonumber(link:match("enchant:(%d+)") or link:match("spell:(%d+)")),
                name = rn, itemId = itemIdFromLink(try(GetTradeSkillItemLink, i)), reagents = {} }
            for j = 1, (try(GetTradeSkillNumReagents, i) or 0) do
                local _, _, count = try(GetTradeSkillReagentInfo, i, j)
                local id = itemIdFromLink(try(GetTradeSkillReagentItemLink, i, j))
                if id then rec.reagents[#rec.reagents + 1] = { itemId = id, count = count or 1 } end
            end
            recipes[#recipes + 1] = rec
        end
    end
    return name, recipes, "classic"
end

local reported = {} -- [profession] = recipe count already reported this session
local makers        -- [itemId] = recipes that make it (Prof.RecipeFor); nil = rebuild

local function scan()
    if InCombatLockdown() then return end
    local name, recipes, api = scanModern()
    if not name then name, recipes, api = scanClassic() end
    if not name or #recipes == 0 then return end
    table.sort(recipes, function(a, b) return a.name < b.name end)
    store()[name] = { recipes = recipes, scanned = time() }
    makers = nil
    if reported[name] ~= #recipes then
        reported[name] = #recipes
        ns.say("Saved " .. #recipes .. " " .. name .. " recipes (" .. api .. " profession API).")
        if ns.ProfUI and ns.ProfUI.Refresh then ns.ProfUI.Refresh() end
    end
end

-- Professions: this character's (scanned) first, then the rest from ForeverDB's recipe list.
function Prof.List()
    local mine, other, seen = {}, {}, {}
    for name in pairs(store()) do mine[#mine + 1] = name; seen[name] = true end
    local gen = ns.GetGen()
    for name in pairs(gen and gen.recipes or {}) do
        if not seen[name] then other[#other + 1] = name end
    end
    table.sort(mine)
    table.sort(other)
    for _, n in ipairs(other) do mine[#mine + 1] = n end
    return mine
end

function Prof.IsMine(name) return store()[name] ~= nil end

local function parseReagents(s)
    local t = {}
    for id, n in tostring(s or ""):gmatch("(%d+):(%d+)") do
        t[#t + 1] = { itemId = tonumber(id), count = tonumber(n) }
    end
    return t
end

-- All recipes of a profession: ForeverDB's full list (GeneratedData.lua) with known = true for the
-- ones this character has (matched by spell ID, else by name), plus scanned recipes ForeverDB lacks.
-- recipe = { name, itemId, reagents, known, skill, learn ("t" trainer, "a" automatic, "i<item>" recipe), new }
function Prof.Recipes(name)
    local scanned = store()[name] and store()[name].recipes or {}
    local all = ns.GetGen()
    local gen = all and all.recipes and all.recipes[name]
    if not gen then
        for _, r in ipairs(scanned) do r.known = true end
        return scanned
    end
    local byId, byName = {}, {}
    for _, r in ipairs(scanned) do
        if r.id then byId[r.id] = r end
        byName[r.name] = r
    end
    local list, used = {}, {}
    for _, g in ipairs(gen) do
        local mine = byId[g[1]] or byName[g[2]]
        if mine then used[mine] = true end
        list[#list + 1] = {
            id = g[1], name = g[2], skill = g[3], itemId = g[4], makes = g[5], learn = g[7], new = g[8] == 1,
            reagents = mine and #mine.reagents > 0 and mine.reagents or parseReagents(g[6]),
            known = mine ~= nil,
        }
    end
    for _, r in ipairs(scanned) do
        if not used[r] then
            r.known = true
            list[#list + 1] = r
        end
    end
    -- By skill needed, like the trainer list; then by name.
    table.sort(list, function(a, b)
        local sa, sb = a.skill or 0, b.skill or 0
        if sa ~= sb then return sa < sb end
        return a.name < b.name
    end)
    return list
end

-- The recipe that makes an item, or nil. Prefers (in order) a known recipe in preferProf, any recipe
-- in preferProf, any known recipe, any recipe. Index built on first use; reset after each scan.
function Prof.RecipeFor(itemId, preferProf)
    if not makers then
        makers = {}
        for _, prof in ipairs(Prof.List()) do
            for _, r in ipairs(Prof.Recipes(prof)) do
                if r.itemId then
                    local t = makers[r.itemId] or {}
                    makers[r.itemId] = t
                    t[#t + 1] = { prof = prof, recipe = r }
                end
            end
        end
    end
    local best, bestScore
    for _, c in ipairs(makers[itemId] or {}) do
        local score = (c.prof == preferProf and 2 or 0) + (c.recipe.known and 1 or 0)
        if not bestScore or score > bestScore then best, bestScore = c, score end
    end
    return best and best.recipe, best and best.prof
end

-- Rescan shortly after profession events (they fire in bursts). Unknown event names error on
-- RegisterEvent, so each is registered in a pcall.
local pending = false
local f = CreateFrame("Frame")
for _, ev in ipairs({ "TRADE_SKILL_SHOW", "TRADE_SKILL_LIST_UPDATE", "TRADE_SKILL_DATA_SOURCE_CHANGED" }) do
    pcall(f.RegisterEvent, f, ev)
end
f:SetScript("OnEvent", function()
    if pending then return end
    pending = true
    C_Timer.After(0.5, function()
        pending = false
        scan()
    end)
end)
