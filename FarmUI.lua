-- ItemFinder FarmUI.lua: the Farm tab. One row per farm item: name, have/goal, a progress bar and a
-- Remove button. Clicking a row opens the item on the Search tab.

local _, ns = ...
local FarmUI = {}
ns.FarmUI = FarmUI

local page, list, emptyText

local function have(itemId)
    local ok, n = pcall(C_Item.GetItemCount, itemId)
    return (ok and type(n) == "number") and n or 0
end

local function initRow(button, d)
    if not button.name then
        ns.UI.RowBase(button)
        button.name = button:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
        button.name:SetPoint("LEFT", 8, 0)
        button.name:SetWidth(230)
        button.name:SetJustifyH("LEFT")
        button.name:SetWordWrap(false)
        button.name:SetTextColor(0.25, 1, 0.25)

        button.count = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        button.count:SetPoint("LEFT", 244, 0)
        button.count:SetWidth(70)
        button.count:SetJustifyH("RIGHT")

        button.bar = CreateFrame("StatusBar", nil, button)
        button.bar:SetSize(240, 10)
        button.bar:SetPoint("LEFT", 324, 0)
        button.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
        button.bar:SetStatusBarColor(0.25, 0.8, 0.25)
        local bg = button.bar:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.4)

        button.remove = CreateFrame("Button", nil, button, "UIPanelButtonTemplate")
        button.remove:SetSize(72, 20)
        button.remove:SetPoint("RIGHT", -6, 0)
        button.remove:SetText("Remove")
        button.remove:SetScript("OnClick", function(self)
            ns.Farm.Toggle(self:GetParent().itemId)
            ns.UI.OnFarmChanged()
        end)

        button:SetScript("OnClick", function(self) ns.UI.ShowItem(self.itemId) end)
        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetItemByID(self.itemId)
            GameTooltip:AddLine("Click: show where it drops (Search tab)", 0.2, 1, 0.6)
            GameTooltip:Show()
        end)
    end
    button.itemId = d.id
    local n = have(d.id)
    button.name:SetText(ns.Data.ItemName(d.id) or ("item " .. d.id))
    if d.goal then
        button.count:SetText(n .. " / " .. d.goal)
        button.bar:SetMinMaxValues(0, d.goal)
        button.bar:SetValue(math.min(n, d.goal))
        button.bar:Show()
    else
        button.count:SetText(n .. "  (no goal)")
        button.bar:Hide()
    end
end

function FarmUI.Build(parent)
    page = parent

    local head = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    head:SetPoint("TOPLEFT", 18, -32)
    head:SetText("Farm list")
    local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("LEFT", head, "RIGHT", 12, -1)
    hint:SetText("Counts are your bags. Items leave the list when their goal is reached.")

    list = ns.UI.MakeList(page, 26, initRow)
    list:SetPoint("TOPLEFT", 12, -58)
    list:SetPoint("BOTTOMRIGHT", -30, 12)

    emptyText = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    emptyText:SetPoint("TOP", 0, -90)
    emptyText:SetWidth(520)
    emptyText:SetText("Nothing to farm yet. Use the Farm button on the Search tab, "
        .. "or Farm materials on the Professions tab.")

    page:RegisterEvent("BAG_UPDATE_DELAYED")
    page:SetScript("OnEvent", function(self) if self:IsVisible() then FarmUI.Refresh() end end)
end

-- Rebuilds the rows (when the tab is shown, bags change, or the farm list changes).
function FarmUI.Refresh()
    if not (page and page:IsShown()) then return end
    local rows = {}
    for _, id in ipairs(ns.Farm.Ids()) do rows[#rows + 1] = { id = id, goal = ns.Farm.Goal(id) } end
    table.sort(rows, function(a, b)
        return (ns.Data.ItemName(a.id) or "") < (ns.Data.ItemName(b.id) or "")
    end)
    list:SetDataProvider(CreateDataProvider(rows))
    emptyText:SetShown(#rows == 0)
end
