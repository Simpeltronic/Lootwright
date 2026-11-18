-- ItemFinder ProfUI.lua: Professions window. Left: profession switcher, recipe filter, recipe list.
-- Right: the selected recipe's materials (have / need for N crafts, where they come from) and a
-- button that puts the missing materials on the farm list with goals. Out of combat only.

local _, ns = ...
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
        button:SetScript("OnClick", function(self) ns.UI.ShowItem(self.itemId, frame) end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemId)
            GameTooltip:AddLine("Click: show where it drops", 0.2, 1, 0.6)
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
    profLabel:SetText(prof or "No professions saved")
    emptyText:SetShown(prof == nil)
    local filter = filterBox:GetText():lower()
    local rows = {}
    for _, rec in ipairs(prof and ns.Prof.Recipes(prof) or {}) do
        if filter == "" or rec.name:lower():find(filter, 1, true) then rows[#rows + 1] = rec end
    end
    recipeBox:SetDataProvider(CreateDataProvider(rows))
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
            recipeBox:ForEachFrame(function(b) b.sel:SetShown(b.recipe == selected) end)
            refreshMats()
        end)
        button:SetScript("OnEnter", function(self)
            if not self.recipe.itemId then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.recipe.itemId)
            GameTooltip:Show()
        end)
    end
    button.recipe = rec
    button.text:SetText(rec.name)
    button.sel:SetShown(rec == selected)
end

----------------------------------------------------------------------
-- Farm the missing materials
----------------------------------------------------------------------
local function farmMaterials()
    if not selected then return end
    local n = crafts()
    local added, done, bought = 0, 0, 0
    for _, rg in ipairs(selected.reagents) do
        local need = rg.count * n
        if vendorOnly(sources(rg.itemId)) then
            bought = bought + 1
        elseif have(rg.itemId) >= need then
            done = done + 1
        else
            ns.Farm.SetGoal(rg.itemId, need)
            added = added + 1
        end
    end
    ns.say(string.format("%s x%d: %d material(s) added to the farm list, %d already in your bags, %d from vendors.",
        selected.name, n, added, done, bought))
    if ns.UI.OnFarmChanged then ns.UI.OnFarmChanged() end
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
local function build()
    frame = CreateFrame("Frame", "ItemFinderProfFrame", UIParent, "BasicFrameTemplateWithInset")
    frame:Hide()
    frame:SetSize(600, 420)
    frame:SetPoint("CENTER", 40, -20)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true) -- comes to the front when clicked
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    tinsert(UISpecialFrames, "ItemFinderProfFrame")

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOP", 0, -5)
    title:SetText("ItemFinder - Professions")

    -- Profession switcher: < Name >
    local prev = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    prev:SetSize(24, 22)
    prev:SetPoint("TOPLEFT", 12, -30)
    prev:SetText("<")
    local nextB = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    nextB:SetSize(24, 22)
    nextB:SetPoint("TOPLEFT", 214, -30)
    nextB:SetText(">")
    profLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
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

    recipeBox = ns.UI.MakeList(frame, 18, initRecipeRow)
    recipeBox:SetPoint("TOPLEFT", 12, -84)
    recipeBox:SetPoint("BOTTOMLEFT", 12, 12)
    recipeBox:SetWidth(222)

    emptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    emptyText:SetPoint("TOPLEFT", 16, -90)
    emptyText:SetWidth(214)
    emptyText:SetJustifyH("LEFT")
    emptyText:SetText("Open each of your profession windows once. ItemFinder saves the recipes you know.")

    -- Right: materials
    recipeName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    recipeName:SetPoint("TOPLEFT", 260, -32)
    recipeName:SetPoint("RIGHT", frame, "RIGHT", -16, 0)
    recipeName:SetJustifyH("LEFT")
    recipeName:SetWordWrap(false)

    local craftsLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
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

    local farmB = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    farmB:SetSize(140, 22)
    farmB:SetPoint("LEFT", craftsBox, "RIGHT", 10, 0)
    farmB:SetText("Farm materials")
    farmB:SetScript("OnClick", farmMaterials)
    farmB:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine("Farm materials", 1, 1, 1)
        GameTooltip:AddLine("Adds every missing material to the farm list with a goal for this many crafts. "
            .. "Vendor-only materials are skipped.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    farmB:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local heads = { { "Material", 264 }, { "Have", 412 }, { "Source", 472 } }
    for _, h in ipairs(heads) do
        local fs = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        fs:SetPoint("TOPLEFT", h[2], -90)
        fs:SetText(h[1])
    end

    matBox = ns.UI.MakeList(frame, 18, initMatRow)
    matBox:SetPoint("TOPLEFT", 260, -106)
    matBox:SetPoint("BOTTOMRIGHT", -30, 12)

    frame:RegisterEvent("PLAYER_REGEN_DISABLED")
    frame:RegisterEvent("BAG_UPDATE_DELAYED")
    frame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_DISABLED" then self:Hide() else refreshMats() end
    end)
end

function ProfUI.Toggle()
    if InCombatLockdown() then ns.say("The window can't be opened in combat."); return end
    if not frame then build() end
    frame:SetShown(not frame:IsShown())
    if frame:IsShown() then
        refreshRecipes()
        refreshMats()
    end
end

-- Called by Prof.lua after a new scan.
function ProfUI.Refresh()
    if frame and frame:IsShown() then
        refreshRecipes()
        refreshMats()
    end
end
