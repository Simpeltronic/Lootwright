-- ItemFinder Map.lua: world map pins for the selected mob's spawns.
-- Same mechanism as HereBeDragons-Pins (used by Questie on this client): a Lua-built pin pool
-- registered in WorldMapFrame.pinPools plus a MapCanvas data provider. No XML template needed.
-- shortcut: world map only, no minimap pins and no clustering; add them if pins get crowded.

local _, ns = ...
local Map = {}
ns.Map = Map

local TEMPLATE = "ItemFinderWorldMapPin"
local ICON = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" -- skull

local pins = {}   -- { { mapId, x, y }, ... } for the current mob
local mob         -- the mob row table the pins belong to
local provider

local pinMixin -- built on first use, once MapCanvasPinMixin is surely loaded

local function setup()
    if provider then return true end
    if not WorldMapFrame and C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_WorldMap") end
    if not (WorldMapFrame and WorldMapFrame.pinPools and MapCanvasDataProviderMixin and MapCanvasPinMixin) then
        return false
    end

    pinMixin = CreateFromMixins(MapCanvasPinMixin)
    function pinMixin:OnLoad()
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetScalingLimits(1, 1.0, 1.2)
    end
    function pinMixin:OnAcquired(x, y, m)
        self:UseFrameLevelType("PIN_FRAME_LEVEL_AREA_POI")
        self:SetPosition(x, y)
        self.mob = m
    end
    function pinMixin:OnReleased() self.mob = nil end
    -- The map canvas owns OnEnter/OnLeave and calls these instead.
    function pinMixin:OnMouseEnter()
        local m = self.mob
        if not m then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(m.name)
        GameTooltip:AddLine("Level " .. ns.LevelText(m.minLevel, m.maxLevel), 1, 1, 1)
        GameTooltip:AddLine("ItemFinder", 0.2, 1, 0.6)
        GameTooltip:Show()
    end
    function pinMixin:OnMouseLeave() GameTooltip:Hide() end
    pinMixin.SetPassThroughButtons = function() end -- avoids an in-combat error (as in HereBeDragons)

    local pool
    if CreateUnsecuredRegionPoolInstance then
        pool = CreateUnsecuredRegionPoolInstance(TEMPLATE)
    else
        pool = CreateFramePool("FRAME")
    end
    pool.parent = WorldMapFrame:GetCanvas()
    pool.createFunc = function()
        local f = CreateFrame("Frame", nil, WorldMapFrame:GetCanvas())
        f:SetSize(14, 14)
        local tex = f:CreateTexture(nil, "OVERLAY")
        tex:SetAllPoints()
        tex:SetTexture(ICON)
        f:EnableMouse(true) -- hover goes through pinMixin:OnMouseEnter/Leave; the map asserts on own OnEnter scripts
        return Mixin(f, pinMixin)
    end
    pool.resetFunc = function(_, pin)
        pin:Hide()
        pin:ClearAllPoints()
        pin:OnReleased()
        pin.pinTemplate = nil
        pin.owningMap = nil
    end
    pool.creationFunc = pool.createFunc -- pre-11.x names
    pool.resetterFunc = pool.resetFunc
    WorldMapFrame.pinPools[TEMPLATE] = pool

    provider = CreateFromMixins(MapCanvasDataProviderMixin)
    function provider:RemoveAllData()
        self:GetMap():RemoveAllPinsByTemplate(TEMPLATE)
    end
    function provider:RefreshAllData()
        self:RemoveAllData()
        local mapId = self:GetMap():GetMapID()
        for _, p in ipairs(pins) do
            if p.mapId == mapId then self:GetMap():AcquirePin(TEMPLATE, p.x, p.y, mob) end
        end
    end
    WorldMapFrame:AddDataProvider(provider)
    return true
end

-- Show pins for one mob (a row from Data.GetSources) and open the world map on its main zone.
function Map.ShowMob(m)
    if InCombatLockdown() then ns.say("Map pins can't be changed in combat."); return end
    if not setup() then ns.say("The world map isn't available."); return end
    local list, mainMap = ns.Data.GetSpawns(m.npcId)
    if #list == 0 then
        ns.say("No map positions for " .. m.name .. " (it may only spawn inside an instance).")
        return
    end
    pins, mob = list, m
    if OpenWorldMap then
        OpenWorldMap(mainMap)
    else
        ShowUIPanel(WorldMapFrame)
        WorldMapFrame:SetMapID(mainMap)
    end
    provider:RefreshAllData()
end

function Map.Clear()
    pins, mob = {}, nil
    if provider then provider:RemoveAllData() end
end

function Map.HasPins()
    return #pins > 0
end
