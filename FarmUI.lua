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

-- Bar: what's in your bags in green, then what the bank can cover in a lighter green.
local BAR_W = 220
local function setBar(bar, n, goal, fromBank)
    if not goal or goal <= 0 then bar:Hide(); return end
    bar:SetMinMaxValues(0, goal)
    bar:SetValue(math.min(n, goal))
    if n >= goal then bar:SetStatusBarColor(0.25, 1, 0.25) else bar:SetStatusBarColor(0.25, 0.7, 0.25) end
    if not bar.bankFill then
        bar.bankFill = bar:CreateTexture(nil, "ARTWORK", nil, 1)
        bar.bankFill:SetPoint("TOP")
        bar.bankFill:SetPoint("BOTTOM")
    end
    fromBank = fromBank or 0
    if fromBank > 0 and n < goal then
        -- Light gold when the bank completes the goal (you have enough, it's in the bank), else light green.
        if n + fromBank >= goal then bar.bankFill:SetColorTexture(0.941, 0.835, 0.549, 1)
        else bar.bankFill:SetColorTexture(0.62, 0.9, 0.62, 1) end
        bar.bankFill:SetPoint("LEFT", bar, "LEFT", BAR_W * n / goal, 0)
        bar.bankFill:SetWidth(math.max(1, BAR_W * fromBank / goal))
        bar.bankFill:Show()
    else
        bar.bankFill:Hide()
    end
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

        button.bar = CreateFrame("StatusBar", nil, button)
        button.bar:SetSize(BAR_W, 10)
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
    -- "1(2) / 3": bags and equipped, then (in slate blue) what the bank can still cover of the goal,
    -- so 1 in bags + 10 in bank for 3 shows 1(2) / 3. The tooltip has the full bank count.
    local goal = (d.kind == "recipe" and d.target) or (d.kind == "mat" and d.need) or d.goal
    local fromBank = goal and math.min(banked, math.max(0, goal - n)) or banked
    local bankDone = goal and fromBank > 0 and n + fromBank >= goal -- the bank completes the goal
    local bank = fromBank > 0 and ((bankDone and "|cfff0d58c(" or "|cff7d8cad(") .. fromBank .. ")|r") or ""

    button.name:ClearAllPoints()
    local indent = d.kind == "mat" and (8 + 20 * (d.depth or 1)) or 8
    button.name:SetPoint("LEFT", indent, 0)
    button.name:SetWidth(246 - indent)
    button.remove:SetShown(d.kind ~= "mat")

    if d.kind == "recipe" then
        button.name:SetText(d.name)
        button.name:SetTextColor(1, 0.82, 0)
        button.count:SetText(d.target and (n .. bank .. " / " .. d.target) or (d.crafts .. " crafts"))
        setBar(button.bar, n, d.target, fromBank)
    elseif d.kind == "mat" then
        button.name:SetText(itemName(d.id) .. (d.crafted and " |cffc0a060(craft)|r" or ""))
        local mark = (d.need > 0 and n >= d.need) and READY or ""
        if d.vendorOnly then
            button.name:SetTextColor(0.5, 0.5, 0.5)
            button.count:SetText("|cff808080" .. n .. "|r" .. bank .. "|cff808080 / " .. d.need .. "|r" .. mark)
        elseif d.crafted or ns.Data.CraftedBy(d.id) then -- a recipe makes it: craft blue
            button.name:SetTextColor(ns.Theme.RGB(ns.Theme.C.craft))
            button.count:SetText(n .. bank .. " / " .. d.need .. mark)
        else
            button.name:SetTextColor(0.25, 1, 0.25)
            button.count:SetText(n .. bank .. " / " .. d.need .. mark)
        end
        setBar(button.bar, n, d.need, fromBank)
    else
        button.name:SetText(itemName(d.id))
        if ns.Data.CraftedBy(d.id) then -- same colours as materials: crafted blue, else green
            button.name:SetTextColor(ns.Theme.RGB(ns.Theme.C.craft))
        else
            button.name:SetTextColor(0.25, 1, 0.25)
        end
        if d.goal then
            button.count:SetText(n .. bank .. " / " .. d.goal)
            setBar(button.bar, n, d.goal, fromBank)
        else
            -- Endless: "32 · 1 stack", and the bar fills toward the next full stack, then starts over.
            local stack = ns.Farm.StackSize(d.id)
            local full = stack and math.floor(n / stack) or 0
            button.count:SetText(n .. bank .. (full > 0 and ("|cff8a93a3 · " .. full .. (full == 1 and " stack" or " stacks") .. "|r") or ""))
            setBar(button.bar, stack and (n % stack) or 0, stack)
        end
    end
    -- Goal reached: gold name, count and full bar; the row stays until the player removes it.
    if d.done then
        button.name:SetText(button.name:GetText() .. READY)
        button.name:SetTextColor(ns.Theme.RGB(ns.Theme.C.brass))
        button.count:SetText("|cffc9a24a" .. n .. " / " .. (d.target or d.goal or n) .. "|r")
        button.bar:SetMinMaxValues(0, 1)
        button.bar:SetValue(1)
        button.bar:SetStatusBarColor(ns.Theme.RGB(ns.Theme.C.brass))
        if button.bar.bankFill then button.bar.bankFill:Hide() end
        button.bar:Show()
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
        rows[#rows + 1] = { kind = "recipe", key = r.key, name = r.name, id = r.itemId, target = r.target, crafts = r.crafts, owned = r.owned, done = r.done }
        for _, m in ipairs(r.rows or {}) do
            rows[#rows + 1] = { kind = "mat", id = m.itemId, need = m.need, vendorOnly = m.vendorOnly,
                depth = m.depth, crafted = m.crafted, subName = m.subName, recipe = m.via }
        end
    end
    local singles = {}
    for _, id in ipairs(ns.Farm.Ids()) do singles[#singles + 1] = { kind = "item", id = id, goal = ns.Farm.Goal(id), done = ns.Farm.Done(id) } end
    table.sort(singles, function(a, b) return itemName(a.id) < itemName(b.id) end)
    for _, s in ipairs(singles) do rows[#rows + 1] = s end
    list:SetDataProvider(CreateDataProvider(rows))
    emptyText:SetShown(#rows == 0)
end
