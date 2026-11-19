-- Lootwright FarmUI.lua: the Farm tab.
--   Recipe group: the crafted item (have / target, bar, Remove), then its materials indented below
--   (have / need, bar; vendor-only ones greyed out). Then single farm items (have / goal, Remove).
-- Clicking a row opens that item on the Search tab.

local _, ns = ...
local FarmUI = {}
ns.FarmUI = FarmUI

local page, list, emptyText

local function itemName(id)
    return ns.Data.ItemName(id) or (C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)) or ("item " .. id)
end

local READY = " |TInterface\\RaidFrame\\ReadyCheck-Ready:12:12|t" -- green check mark

local function setBar(bar, n, goal)
    if not goal or goal <= 0 then bar:Hide(); return end
    bar:SetMinMaxValues(0, goal)
    bar:SetValue(math.min(n, goal))
    if n >= goal then bar:SetStatusBarColor(0.25, 1, 0.25) else bar:SetStatusBarColor(0.25, 0.7, 0.25) end
    bar:Show()
end

local function initRow(button, d)
    if not button.name then
        ns.UI.RowBase(button)
        button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.name:SetWidth(230)
        button.name:SetJustifyH("LEFT")
        button.name:SetWordWrap(false)

        button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.count:SetPoint("LEFT", 254, 0)
        button.count:SetWidth(80)
        button.count:SetJustifyH("RIGHT")

        -- Bank count, between the bar and Remove: "(12 bank)".
        button.bank = button:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
        button.bank:SetPoint("LEFT", 570, 0)
        button.bank:SetWidth(58)
        button.bank:SetJustifyH("LEFT")
        button.bank:SetWordWrap(false)

        button.bar = CreateFrame("StatusBar", nil, button)
        button.bar:SetSize(220, 10)
        button.bar:SetPoint("LEFT", 344, 0)
        button.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8") -- flat bar, dark field guide look
        button.bar:SetHeight(6)
        local bg = button.bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.15, 0.17, 0.20, 1)

        button.remove = ns.Theme.Button(button, "Remove", 64, 18)
        button.remove:SetPoint("RIGHT", -6, 0)
        button.remove:SetScript("OnClick", function(self)
            local row = self:GetParent().data
            if row.kind == "recipe" then ns.Farm.RemoveRecipe(row.key) else ns.Farm.Toggle(row.id) end
            ns.UI.OnFarmChanged()
        end)

        button:SetScript("OnClick", function(self)
            if self.data.id then ns.UI.ShowItem(self.data.id) end
        end)
        button:SetScript("OnEnter", function(self)
            local row = self.data
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if row.id then GameTooltip:SetItemByID(row.id) else GameTooltip:AddLine(row.name) end
            if row.kind == "recipe" then
                if row.target then
                    GameTooltip:AddLine("Recipe goal: own " .. row.target .. " (" .. row.crafts .. " crafts"
                        .. ((row.owned or 0) > 0 and (" on top of the " .. row.owned .. " you had") or "") .. ")", 1, 1, 1)
                    GameTooltip:AddLine("Counts your bags and what you wear.", 0.7, 0.7, 0.7)
                else
                    GameTooltip:AddLine("This recipe makes no item to count. Remove it when you're done.", 1, 0.5, 0.25)
                end
                GameTooltip:AddLine("Its materials stay on the list until then.", 0.7, 0.7, 0.7)
            elseif row.kind == "mat" then
                if row.vendorOnly then
                    GameTooltip:AddLine("Sold by vendors only: buy it, it can't be farmed.", 1, 0.82, 0)
                end
                GameTooltip:AddLine("Needed for " .. row.recipe .. ": " .. row.need, 1, 1, 1)
                local prof, recipeName = ns.Data.CraftedBy(row.id)
                if prof and not row.vendorOnly then
                    GameTooltip:AddLine("Usually crafted: " .. prof .. " (" .. tostring(recipeName) .. ")."
                        .. " Mob drops are rare or few.", 0.443, 0.835, 1, true)
                end
                if row.crafted then
                    GameTooltip:AddLine("Crafted with " .. (row.subName or "a recipe")
                        .. ". Its materials are listed below while you still need more.", 0.75, 0.63, 0.38, true)
                end
            end
            local banked = row.id and ns.Farm.Bank(row.id) or 0
            if banked > 0 then
                GameTooltip:AddLine(banked .. " in your bank (not counted: take them out to use them)", 0.7, 0.7, 0.7)
            end
            if row.id then GameTooltip:AddLine("Click: show where it drops (Search tab)", 0.2, 1, 0.6) end
            GameTooltip:Show()
        end)
    end
    button.data = d
    local n = d.id and ns.Farm.Have(d.id) or 0
    local banked = d.id and ns.Farm.Bank(d.id) or 0
    button.bank:SetText(banked > 0 and ("(" .. banked .. " bank)") or "")

    button.name:ClearAllPoints()
    local indent = d.kind == "mat" and (8 + 20 * (d.depth or 1)) or 8
    button.name:SetPoint("LEFT", indent, 0)
    button.name:SetWidth(246 - indent)
    button.remove:SetShown(d.kind ~= "mat")

    if d.kind == "recipe" then
        button.name:SetText(d.name)
        button.name:SetTextColor(1, 0.82, 0)
        button.count:SetText(d.target and (n .. " / " .. d.target) or (d.crafts .. " crafts"))
        setBar(button.bar, n, d.target)
    elseif d.kind == "mat" then
        button.name:SetText(itemName(d.id) .. (d.crafted and " |cffc0a060(craft)|r" or ""))
        local mark = (d.need > 0 and n >= d.need) and READY or ""
        if d.vendorOnly then
            button.name:SetTextColor(0.5, 0.5, 0.5)
            button.count:SetText("|cff808080" .. n .. " / " .. d.need .. "|r" .. mark)
        elseif d.crafted or ns.Data.CraftedBy(d.id) then -- a recipe makes it: craft blue
            button.name:SetTextColor(ns.Theme.RGB(ns.Theme.C.craft))
            button.count:SetText(n .. " / " .. d.need .. mark)
        else
            button.name:SetTextColor(0.25, 1, 0.25)
            button.count:SetText(n .. " / " .. d.need .. mark)
        end
        setBar(button.bar, n, d.need)
    else
        button.name:SetText(itemName(d.id))
        button.name:SetTextColor(0.25, 1, 0.25)
        button.count:SetText(d.goal and (n .. " / " .. d.goal) or (n .. "  (no goal)"))
        setBar(button.bar, n, d.goal)
    end
end

function FarmUI.Build(parent)
    page = parent

    local head = page:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    head:SetPoint("TOPLEFT", 18, -32)
    head:SetText("Farm list")
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", head, "RIGHT", 12, -1)
    hint:SetText("Counts are your bags. Recipes stay until you have the crafted items.")

    list = ns.UI.MakeList(page, 24, initRow)
    list:SetPoint("TOPLEFT", 12, -58)
    list:SetPoint("BOTTOMRIGHT", -30, 12)

    emptyText = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -90)
    emptyText:SetWidth(520)
    emptyText:SetText("Nothing to farm yet. Use the Farm button on the Search tab, "
        .. "or Farm recipe on the Professions tab.")

    page:RegisterEvent("BAG_UPDATE_DELAYED")
    for _, ev in ipairs({ "BANKFRAME_OPENED", "PLAYERBANKSLOTS_CHANGED" }) do
        pcall(page.RegisterEvent, page, ev) -- an unknown event name would error
    end
    page:SetScript("OnEvent", function(self) if self:IsVisible() then FarmUI.Refresh() end end)
end

-- Rebuilds the rows (when the tab is shown, bags change, or the farm list changes).
function FarmUI.Refresh()
    if not (page and page:IsShown()) then return end
    local rows = {}
    for _, r in ipairs(ns.Farm.RecipeList()) do
        rows[#rows + 1] = { kind = "recipe", key = r.key, name = r.name, id = r.itemId, target = r.target, crafts = r.crafts, owned = r.owned }
        for _, m in ipairs(r.rows or {}) do
            rows[#rows + 1] = { kind = "mat", id = m.itemId, need = m.need, vendorOnly = m.vendorOnly,
                depth = m.depth, crafted = m.crafted, subName = m.subName, recipe = m.via }
        end
    end
    local singles = {}
    for _, id in ipairs(ns.Farm.Ids()) do singles[#singles + 1] = { kind = "item", id = id, goal = ns.Farm.Goal(id) } end
    table.sort(singles, function(a, b) return itemName(a.id) < itemName(b.id) end)
    for _, s in ipairs(singles) do rows[#rows + 1] = s end
    list:SetDataProvider(CreateDataProvider(rows))
    emptyText:SetShown(#rows == 0)
end
