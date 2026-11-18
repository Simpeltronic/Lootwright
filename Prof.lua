-- ItemFinder Prof.lua: reads the open profession window and saves the known recipes and their
-- materials, per character, in ItemFinderDB.prof[<name-realm>][<profession>] = { recipes = {...} }.
-- recipe = { name, itemId (crafted item, may be nil), reagents = { { itemId, count }, ... } }
-- Forever's profession window may use the modern (C_TradeSkillUI) or the classic (GetTradeSkill*)
-- functions; we try modern first, then classic, and log which one worked.
-- shortcut: no classic "craft" window (old Enchanting UI); add GetCraft* if Enchanting shows nothing.

local _, ns = ...
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
                local rec = { name = info.name or s.name or ("recipe " .. id), itemId = s.outputItemID, reagents = {} }
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
            local rec = { name = rn, itemId = itemIdFromLink(try(GetTradeSkillItemLink, i)), reagents = {} }
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

local function scan()
    if InCombatLockdown() then return end
    local name, recipes, api = scanModern()
    if not name then name, recipes, api = scanClassic() end
    if not name or #recipes == 0 then return end
    table.sort(recipes, function(a, b) return a.name < b.name end)
    store()[name] = { recipes = recipes, scanned = time() }
    if reported[name] ~= #recipes then
        reported[name] = #recipes
        ns.say("Saved " .. #recipes .. " " .. name .. " recipes (" .. api .. " profession API).")
        if ns.ProfUI and ns.ProfUI.Refresh then ns.ProfUI.Refresh() end
    end
end

-- Profession names saved for this character, sorted.
function Prof.List()
    local t = {}
    for name in pairs(store()) do t[#t + 1] = name end
    table.sort(t)
    return t
end

function Prof.Recipes(name)
    local p = store()[name]
    return p and p.recipes or {}
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
