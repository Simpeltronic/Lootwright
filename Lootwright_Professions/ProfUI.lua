-- Lootwright ProfUI.lua: the Professions tab. Left: profession switcher, recipe filter, recipe list.
-- Right: the selected recipe's materials (have / need for N crafts, where they come from) and a
-- button that puts the missing materials on the farm list with goals.

-- Part of the Lootwright_Professions sub-addon: joins Lootwright's namespace.
local ns = LootwrightNS
if not ns then return end
local ProfUI = {}
ns.ProfUI = ProfUI

local frame, profLabel, filterBox, recipeBox, matBox, recipeName, craftsBox, emptyText
local profs, profIndex = {}, 1
local selected -- recipe table

local srcCache = {} -- [itemId] = { mobs, objects, vendors }
local function sources(itemId)
    if srcCache[itemId] then return srcCache[itemId] end
    local ok, s = pcall(ns.Data.GetSources, itemId)
    local r = ok and { mobs = #s.mobs, objects = s.objects, vendors = s.vendors } or { mobs = 0, objects = 0, vendors = 0 }
    srcCache[itemId] = r
    return r
end

local function have(itemId)
    local ok, n = pcall(C_Item.GetItemCount, itemId)
    return (ok and type(n) == "number") and n or 0
end

local function crafts()
    local n = tonumber(craftsBox:GetText())
    return (n and n > 0) and math.floor(n) or 1
end

local function itemName(id)
    return ns.Data.ItemName(id) or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item " .. id)
end

-- Bought only from vendors: no mob drops and no objects.
local function vendorOnly(s) return s.vendors > 0 and s.mobs == 0 and s.objects == 0 end

----------------------------------------------------------------------
-- Materials
----------------------------------------------------------------------
local function refreshMats()
    if not matBox then return end -- text boxes fire while the frame is still being built
    local rows = {}
    if selected then
        for _, rg in ipairs(selected.reagents) do rows[#rows + 1] = rg end
        recipeName:SetText(selected.name)
    else
        recipeName:SetText("Select a recipe")
    end
    matBox:SetDataProvider(CreateDataProvider(rows))
end

local function initMatRow(button, rg)
    if not button.cells then
        ns.UI.RowBase(button)
        button.cells = {}
        local cols = { { 4, 140, "LEFT" }, { 148, 56, "CENTER" }, { 208, 96, "LEFT" } }
        for i, c in ipairs(cols) do
            local fs = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            fs:SetPoint("LEFT", c[1], 0)
            fs:SetWidth(c[2])
            fs:SetJustifyH(c[3])
            fs:SetWordWrap(false)
            button.cells[i] = fs
        end
        button:SetScript("OnClick", function(self) ns.UI.ShowItem(self.itemId) end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemId)
            GameTooltip:AddLine("Click: show where it drops (Search tab)", 0.2, 1, 0.6)
            GameTooltip:Show()
        end)
    end
    button.itemId = rg.itemId
    local need, n = rg.count * crafts(), have(rg.itemId)
    button.cells[1]:SetText(itemName(rg.itemId))
    button.cells[2]:SetText(n .. "/" .. need)
    if n >= need then button.cells[2]:SetTextColor(0.25, 1, 0.25) else button.cells[2]:SetTextColor(1, 0.5, 0.25) end
    local s, parts = sources(rg.itemId), {}
    if s.mobs > 0 then parts[#parts + 1] = s.mobs .. " mobs" end
    if s.objects > 0 then parts[#parts + 1] = s.objects .. " obj" end
    if s.vendors > 0 then parts[#parts + 1] = "vendor" end
    button.cells[3]:SetText(#parts > 0 and table.concat(parts, ", ") or "|cff999999unknown|r")
end

----------------------------------------------------------------------
-- Recipes
----------------------------------------------------------------------
local function refreshRecipes()
    if not recipeBox then return end
    profs = ns.Prof.List()
    if profIndex > #profs then profIndex = 1 end
    local prof = profs[profIndex]
    profLabel:SetText(prof and (ns.Prof.IsMine(prof) and prof or ("|cff999999" .. prof .. "|r")) or "No professions")
    emptyText:SetShown(prof == nil)
    local filter = filterBox:GetText():lower()
    local knownOnly = LootwrightDB.profKnownOnly == true
    local rows = {}
    for _, rec in ipairs(prof and ns.Prof.Recipes(prof) or {}) do
        if (filter == "" or rec.name:lower():find(filter, 1, true)) and (rec.known or not knownOnly) then
            rows[#rows + 1] = rec
        end
    end
    recipeBox:SetDataProvider(CreateDataProvider(rows))
end

local function sameRecipe(a, b)
    return a and b and a.name == b.name and a.id == b.id
end

local function learnText(learn)
    if learn == "t" then return "Trainer" end
    if learn == "a" then return "Learned automatically" end
    local id = tonumber(tostring(learn or ""):match("^i(%d+)"))
    if id then return "Recipe: " .. (ns.Data.ItemName(id) or ("item " .. id)) end
    return nil
end

local function initRecipeRow(button, rec)
    if not button.text then
        ns.UI.RowBase(button)
        button.text = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.text:SetPoint("LEFT", 4, 0)
        button.text:SetPoint("RIGHT", -4, 0)
        button.text:SetJustifyH("LEFT")
        button.text:SetWordWrap(false)
        button:SetScript("OnClick", function(self)
            selected = self.recipe
            recipeBox:ForEachFrame(function(b) b.sel:SetShown(sameRecipe(b.recipe, selected)) end)
            refreshMats()
        end)
        button:SetScript("OnEnter", function(self)
            local r = self.recipe
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if r.itemId then GameTooltip:SetItemByID(r.itemId) else GameTooltip:AddLine(r.name) end
            if r.known then
                GameTooltip:AddLine("You know this recipe", 0.25, 1, 0.25)
            else
                GameTooltip:AddLine("Not learned" .. (r.skill and (" - needs skill " .. r.skill) or ""), 1, 0.5, 0.25)
                local how = learnText(r.learn)
                if how then GameTooltip:AddLine(how, 1, 1, 1) end
            end
            if r.new then GameTooltip:AddLine("New in Forever", 0.4, 0.8, 1) end
            GameTooltip:AddLine("Recipe data from ForeverDB.net", 0.5, 0.5, 0.5)
            GameTooltip:Show()
        end)
    end
    button.recipe = rec
    local skill = rec.skill and (" |cff777777" .. rec.skill .. "|r") or ""
    button.text:SetText((rec.known and rec.name or ("|cff999999" .. rec.name .. "|r")) .. skill)
    button.sel:SetShown(sameRecipe(rec, selected))
end

----------------------------------------------------------------------
-- Farm the recipe: one group on the Farm tab, with every material as a sub-goal
----------------------------------------------------------------------
local function farmMaterials()
    if not selected then return end
    local n = crafts()
    ns.Farm.AddRecipe(selected, n,
        function(itemId) return vendorOnly(sources(itemId)) end,
        function(itemId) return (ns.Prof.RecipeFor(itemId, profs[profIndex])) end)
    local makes = math.max(1, tonumber(selected.makes) or 1)
    ns.say(string.format("Farming %s x%d: %d material(s) on the Farm tab%s.", selected.name, n, #selected.reagents,
        selected.itemId and (", done when your bags hold " .. n * makes) or ", remove it by hand when done"))
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
-- Builds the Professions tab into `parent` (a page of the main window, see UI.lua).
function ProfUI.Build(parent)
    frame = parent
    local T, C = ns.Theme, ns.Theme.C

    -- Profession switcher: < Name >
    local prev = T.Button(frame, "<", 24, 22)
    prev:SetPoint("TOPLEFT", 12, -30)
    local nextB = T.Button(frame, ">", 24, 22)
    nextB:SetPoint("TOPLEFT", 214, -30)
    profLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    profLabel:SetPoint("LEFT", prev, "RIGHT", 4, 0)
    profLabel:SetPoint("RIGHT", nextB, "LEFT", -4, 0)
    local function step(d)
        if #profs == 0 then return end
        profIndex = (profIndex - 1 + d) % #profs + 1
        selected = nil
        refreshRecipes()
        refreshMats()
    end
    prev:SetScript("OnClick", function() step(-1) end)
    nextB:SetScript("OnClick", function() step(1) end)

    filterBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    filterBox:SetSize(214, 20)
    filterBox:SetPoint("TOPLEFT", 18, -58)
    filterBox:SetAutoFocus(false)
    if filterBox.Instructions then filterBox.Instructions:SetText("Filter recipes") end
    filterBox:HookScript("OnTextChanged", function() refreshRecipes() end)
    filterBox:HookScript("OnEnterPressed", filterBox.ClearFocus)
    T.StyleEditBox(filterBox)

    local known = T.Pill(frame, "Known recipes only", "filter")
    known:SetPoint("TOPLEFT", 12, -82)
    known:SetOn(LootwrightDB.profKnownOnly == true)
    known:SetScript("OnClick", function(self)
        self:SetOn(not self.on)
        LootwrightDB.profKnownOnly = self.on
        refreshRecipes()
    end)

    local colLine = T.Line(frame, C.line)
    colLine:SetPoint("TOPLEFT", 250, 0)
    colLine:SetPoint("BOTTOMLEFT", 250, 0)
    colLine:SetWidth(1)

    recipeBox = ns.UI.MakeList(frame, 20, initRecipeRow)
    recipeBox:SetPoint("TOPLEFT", 12, -104)
    recipeBox:SetPoint("BOTTOMLEFT", 12, 12)
    recipeBox:SetWidth(222)

    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 16, -110)
    emptyText:SetWidth(214)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("Open each of your profession windows once. Lootwright saves the recipes you know.")

    -- Right: materials
    recipeName = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    recipeName:SetPoint("TOPLEFT", 260, -32)
    recipeName:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWordWrap(false)

    local craftsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    craftsLabel:SetPoint("TOPLEFT", 262, -64)
    craftsLabel:SetText("Crafts:")
    craftsBox = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    craftsBox:SetSize(58, 20)
    craftsBox:SetPoint("LEFT", craftsLabel, "RIGHT", 10, 0)
    craftsBox:SetAutoFocus(false)
    craftsBox:SetNumeric(true)
    craftsBox:SetMaxLetters(4)
    craftsBox:SetText("1")
    craftsBox:HookScript("OnTextChanged", function() refreshMats() end)
    craftsBox:HookScript("OnEnterPressed", craftsBox.ClearFocus)
    T.StyleEditBox(craftsBox)

    local farmB = T.Button(frame, "Farm recipe", 110, 22)
    farmB:SetPoint("LEFT", craftsBox, "RIGHT", 12, 0)
    farmB:SetScript("OnClick", farmMaterials)
    farmB:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Farm recipe", 1, 1, 1)
        GameTooltip:AddLine("Adds this recipe to the Farm tab with every material as a sub-goal for this many "
            .. "crafts. Vendor-only materials are listed greyed out. The recipe and its materials leave the list "
            .. "once your bags hold the crafted items.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    farmB:HookScript("OnLeave", function() GameTooltip:Hide() end)

    local heads = { { "MATERIAL", 264 }, { "HAVE", 412 }, { "SOURCE", 472 } }
    for _, h in ipairs(heads) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        fs:SetPoint("TOPLEFT", h[2], -90)
        fs:SetText(h[1])
    end

    local tableLine = T.Line(frame, C.line)
    tableLine:SetPoint("TOPLEFT", 260, -104)
    tableLine:SetPoint("TOPRIGHT", -14, -104)
    tableLine:SetHeight(1)

    matBox = ns.UI.MakeList(frame, 20, initMatRow)
    matBox:SetPoint("TOPLEFT", 260, -106)
    matBox:SetPoint("BOTTOMRIGHT", -30, 12)

    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:SetScript("OnEvent", function(self) if self:IsVisible() then refreshMats() end end)
end

-- Called when the tab is shown and by Prof.lua after a new scan.
function ProfUI.Refresh()
    if frame and frame:IsShown() then
        refreshRecipes()
        refreshMats()
    end
end
