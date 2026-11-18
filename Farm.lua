-- ItemFinder Farm.lua: the farm list (materials you're gathering now) and the mob-tooltip line
-- "Farm: Linen Cloth 43.7% (have 12)" on mobs that drop them. Unlike favorites, this affects the
-- game world, so keep the list short.
-- Saved as ItemFinderDB.farm = { [itemId] = true | { goal = n } }. With a goal, the item leaves the
-- list by itself once the bags hold that many.

local _, ns = ...
local Farm = {}
ns.Farm = Farm

local index -- [npcId] = { { itemId, rate, fewKills }, ... }; rebuilt when the list changes

local function list()
    ItemFinderDB.farm = ItemFinderDB.farm or {}
    return ItemFinderDB.farm
end

function Farm.Has(itemId) return list()[itemId] ~= nil end

function Farm.Toggle(itemId)
    local l = list()
    l[itemId] = (not l[itemId]) or nil
    index = nil
end

-- Goal count for a farm item, or nil.
function Farm.Goal(itemId)
    local v = list()[itemId]
    return type(v) == "table" and v.goal or nil
end

local function have(itemId)
    local ok, n = pcall(C_Item.GetItemCount, itemId)
    return (ok and type(n) == "number") and n or 0
end

-- Removes farm items whose goal is reached. Returns true if anything changed.
local function checkGoals()
    local changed = false
    for itemId, v in pairs(list()) do
        if type(v) == "table" and v.goal then
            local n = have(itemId)
            if n >= v.goal then
                list()[itemId] = nil
                changed = true
                local name = ns.Data.ItemName(itemId) or ("item " .. itemId)
                local msg = "Farm goal reached: " .. name .. " " .. n .. "/" .. v.goal .. ". Removed from the farm list."
                ns.say(msg)
                if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 0.25, 1, 0.25) end
            end
        end
    end
    if changed then
        index = nil
        if ns.UI.OnFarmChanged then ns.UI.OnFarmChanged() end
    end
    return changed
end

-- Sets or clears (n = nil or 0) the goal; farms the item if it wasn't yet.
function Farm.SetGoal(itemId, n)
    n = tonumber(n)
    list()[itemId] = (n and n > 0) and { goal = math.floor(n) } or true
    index = nil
    checkGoals()
end

function Farm.Ids()
    local t = {}
    for id in pairs(list()) do t[#t + 1] = id end
    table.sort(t)
    return t
end

local function build()
    index = {}
    if not ns.Data.Available() then return end
    for itemId in pairs(list()) do
        local ok, src = pcall(ns.Data.GetSources, itemId)
        if ok then
            for _, m in ipairs(src.mobs) do
                local e = index[m.npcId] or {}
                index[m.npcId] = e
                e[#e + 1] = { itemId = itemId, rate = m.rate, fewKills = m.fewKills }
            end
        end
    end
end

-- Farm items this NPC drops, or nil.
function Farm.ForNpc(npcId)
    if not index then build() end
    return index[npcId]
end

-- "Linen Cloth 43.7% (have 12)" or, with a goal, "(have 12/40)"
function Farm.Line(e)
    local name = ns.Data.ItemName(e.itemId) or ("item " .. e.itemId)
    local rate = e.rate and (" " .. ns.RateText(e.rate, e.fewKills)) or " rate ?"
    local goal = Farm.Goal(e.itemId)
    return name .. rate .. " (have " .. have(e.itemId) .. (goal and ("/" .. goal) or "") .. ")"
end

-- Bag changes: check goals (BAG_UPDATE_DELAYED fires once after a batch of bag changes).
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("BAG_UPDATE_DELAYED")
watcher:SetScript("OnEvent", function()
    if next(list()) then checkGoals() end
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
        if tooltip ~= GameTooltip or InCombatLockdown() or not next(list()) then return end
        local guid = type(data) == "table" and data.guid
        if not guid then
            local ok, _, unit = pcall(tooltip.GetUnit, tooltip)
            if ok and unit then guid = UnitGUID(unit) end
        end
        local npcId = npcIdFromGuid(guid)
        local entries = npcId and Farm.ForNpc(npcId)
        if not entries then return end
        for _, e in ipairs(entries) do
            tooltip:AddLine("Farm: " .. Farm.Line(e), 0.25, 1, 0.25)
        end
    end)
end
