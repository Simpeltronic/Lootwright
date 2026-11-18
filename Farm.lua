-- ItemFinder Farm.lua: the farm list (materials you're gathering now) and the mob-tooltip line
-- "Farm: Linen Cloth 43.7% (have 12)" on mobs that drop them. Unlike favorites, this affects the
-- game world, so keep the list short.
-- Saved as ItemFinderDB.farm = { [itemId] = true }.

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

-- "Linen Cloth 43.7% (have 12)"
function Farm.Line(e)
    local name = ns.Data.ItemName(e.itemId) or ("item " .. e.itemId)
    local ok, have = pcall(C_Item.GetItemCount, e.itemId)
    local rate = e.rate and (" " .. ns.RateText(e.rate, e.fewKills)) or " rate ?"
    return name .. rate .. " (have " .. ((ok and have) or 0) .. ")"
end

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
