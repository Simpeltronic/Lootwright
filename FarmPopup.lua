-- Lootwright FarmPopup.lua: "how many do you want?" popup, like splitting a stack in your bags.
-- Opened by the Farm button on the Search tab and by dropping an item on the farm tracker.
-- Type a number, use - / + or the mouse wheel, or pick a quick amount. Enter farms, Escape closes.
-- The goal is a bag count (same as Farm.SetGoal): "40" means farm until the bags hold 40.

local _, ns = ...
local Popup = {}
ns.FarmPopup = Popup

local T = ns.Theme
local frame, title, haveText, box, moreText, hint, stopB, noGoalB, recipeNote
local itemId
local recipe, recipeProf -- a recipe of yours that makes the item, or nil
local mode = "item"     -- "item" or "recipe"

local function have() return ns.Farm.Have(itemId) end

local function amount() return tonumber(box:GetText()) or 0 end

local function setAmount(n)
    n = math.max(0, math.min(99999, math.floor(n)))
    box:SetText(tostring(n))
end

-- "28 more" under the field, or a warning when the goal is already met.
local function update()
    if not itemId then return end
    local n, h = amount(), have()
    if n <= 0 then
        moreText:SetText(mode == "item" and "|cffc9a24aendless|r" or "")
    elseif n <= h then
        moreText:SetText("|cffff8040You already have " .. h .. "|r")
    elseif mode == "recipe" then
        local makes = math.max(1, tonumber(recipe.makes) or 1)
        moreText:SetText((n - h) .. " more = " .. math.ceil((n - h) / makes) .. " crafts")
    else
        moreText:SetText((n - h) .. " more")
    end
end

local function setMode(m)
    mode = recipe and m or "item"
    noGoalB:SetShown(mode == "item") -- a recipe group always has a goal
    update()
end

local function maxStack()
    local ok, s = pcall(C_Item.GetItemMaxStackSize, itemId)
    return (ok and type(s) == "number" and s > 1) and s or 20
end

local function confirm(withGoal)
    if not itemId then return end
    if withGoal then
        local n = amount()
        if n <= 0 and mode == "item" then return confirm(false) end -- empty goal box: farm without end
        if n <= have() then
            hint:SetText("|cffff8040Pick a number above what you already have, or leave it empty for endless.|r")
            return
        end
        if mode == "recipe" then
            local makes = math.max(1, tonumber(recipe.makes) or 1)
            ns.ProfUI.FarmRecipe(recipe, math.ceil((n - have()) / makes), recipeProf)
        else
            ns.Farm.SetGoal(itemId, n)
        end
    else
        ns.Farm.SetGoal(itemId, nil) -- endless: farm without a goal
    end
    frame:Hide()
    ns.UI.OnFarmChanged()
end

local function build()
    local C = T.C
    frame = CreateFrame("Frame", "LootwrightFarmPopup", UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(260, 150)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    T.Backdrop(frame, C.bg, C.muted, 0.98)
    tinsert(UISpecialFrames, "LootwrightFarmPopup") -- Escape closes it

    title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    title:SetPoint("TOPLEFT", 10, -9)
    title:SetPoint("RIGHT", -28, 0)
    title:SetJustifyH("LEFT")
    title:SetWordWrap(false)
    local close = CreateFrame("Button", nil, frame)
    close:SetSize(20, 20)
    close:SetPoint("TOPRIGHT", -4, -4)
    local x = close:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    x:SetPoint("CENTER")
    x:SetText("×")
    x:SetTextColor(T.RGB(C.muted))
    close:SetScript("OnClick", function() frame:Hide() end)
    local line = T.Line(frame, C.line)
    line:SetPoint("TOPLEFT", 1, -28)
    line:SetPoint("TOPRIGHT", -1, -28)
    line:SetHeight(1)

    haveText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    haveText:SetPoint("TOPLEFT", 10, -38)

    local goalLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    goalLabel:SetPoint("TOPLEFT", 10, -62)
    goalLabel:SetText("Goal")
    local minus = T.Button(frame, "-", 22, 22)
    minus:SetPoint("LEFT", goalLabel, "RIGHT", 10, 0)
    -- SearchBoxTemplate: the edit box that takes typing on Forever (InputBoxTemplate didn't).
    box = CreateFrame("EditBox", nil, frame, "SearchBoxTemplate")
    box:SetSize(54, 20)
    box:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    box:SetAutoFocus(false)
    box:SetNumeric(true)
    box:SetMaxLetters(5)
    box:SetJustifyH("CENTER")
    if box.searchIcon then box.searchIcon:Hide() end
    if box.clearButton then box.clearButton:Hide() end
    T.StyleEditBox(box)
    local plus = T.Button(frame, "+", 22, 22)
    plus:SetPoint("LEFT", box, "RIGHT", 4, 0)
    moreText = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    moreText:SetPoint("LEFT", plus, "RIGHT", 8, 0)

    minus:SetScript("OnClick", function() setAmount(amount() - 1) end)
    plus:SetScript("OnClick", function() setAmount(amount() + 1) end)
    box:HookScript("OnTextChanged", function() hint:SetText(""); update() end)
    box:HookScript("OnEnterPressed", function() confirm(true) end)
    box:HookScript("OnEscapePressed", function() frame:Hide() end)
    box:EnableMouseWheel(true)
    box:SetScript("OnMouseWheel", function(_, delta) setAmount(amount() + delta * (IsShiftKeyDown() and 10 or 1)) end)

    -- Quick amounts: relative to what's in the bags, so "+20" means 20 more than you have.
    local quick = {
        { "+10", function() return have() + 10 end },
        { "+20", function() return have() + 20 end },
        { "1 stack", function() return have() + maxStack() end },
        { "2 stacks", function() return have() + 2 * maxStack() end },
    }
    local prev
    for _, q in ipairs(quick) do
        local p = T.Pill(frame, q[1], "filter")
        if prev then p:SetPoint("LEFT", prev, "RIGHT", 4, 0) else p:SetPoint("TOPLEFT", 10, -84) end
        p:SetScript("OnClick", function() setAmount(q[2]()) end)
        prev = p
    end

    -- Craftable by you: Farm adds the recipe (materials as a group), no choice (user's call).
    recipeNote = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    recipeNote:SetPoint("TOPLEFT", 10, -110)
    recipeNote:SetTextColor(T.RGB(T.C.craft))

    hint = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", 10, -106)
    hint:SetPoint("RIGHT", -10, 0)
    hint:SetJustifyH("LEFT")

    local farmB = T.Button(frame, "Farm", 60, 22)
    farmB:SetPoint("BOTTOMLEFT", 10, 10)
    farmB:SetBackdropColor(T.RGB(C.greenDim))
    farmB:SetBackdropBorderColor(T.RGB(C.greenEdge))
    farmB:GetFontString():SetTextColor(T.RGB(C.green))
    farmB:SetScript("OnClick", function() confirm(true) end)
    noGoalB = T.Button(frame, "Endless", 64, 22)
    noGoalB:SetPoint("LEFT", farmB, "RIGHT", 6, 0)
    noGoalB:SetScript("OnClick", function() confirm(false) end)
    stopB = T.Button(frame, "Stop farming", 90, 22)
    stopB:SetPoint("BOTTOMRIGHT", -10, 10)
    stopB:SetScript("OnClick", function()
        if itemId and ns.Farm.IsSingle(itemId) then ns.Farm.Toggle(itemId) end
        frame:Hide()
        ns.UI.OnFarmChanged()
    end)
end

-- Opens the popup for an item, next to `anchor` (a frame) if given.
function Popup.Open(id, anchor)
    if InCombatLockdown() then ns.say("Farm goals can't be changed in combat."); return end
    if not id then return end
    if not frame then build() end
    itemId = id
    title:SetText("Farm " .. (ns.Data.ItemName(id) or ("item " .. id)))
    haveText:SetText("You have |cffffffff" .. have() .. "|r in your bags")
    hint:SetText("")
    local current = ns.Farm.IsSingle(id) and ns.Farm.Goal(id)
    setAmount(current or (have() + 20))
    stopB:SetShown(ns.Farm.IsSingle(id))
    -- A recipe of a profession you have that makes it (Prof.RecipeFor only looks at yours).
    recipe, recipeProf = nil, nil
    if ns.Prof and ns.ProfUI then
        local ok, r, p = pcall(ns.Prof.RecipeFor, id)
        if ok and r and r.reagents and #r.reagents > 0 then recipe, recipeProf = r, p end
    end
    recipeNote:SetShown(recipe ~= nil)
    if recipe then
        recipeNote:SetText("Farms the recipe (" .. tostring(recipeProf) .. "): its materials go on the Farm tab")
        hint:SetPoint("TOPLEFT", 10, -128)
        frame:SetHeight(170)
    else
        hint:SetPoint("TOPLEFT", 10, -106)
        frame:SetHeight(150)
    end
    setMode(recipe and "recipe" or "item")
    frame:ClearAllPoints()
    if anchor then
        frame:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -4)
    else
        frame:SetPoint("CENTER")
    end
    frame:Show()
    frame:Raise()
    box:SetFocus()
    box:HighlightText()
    update()
end
