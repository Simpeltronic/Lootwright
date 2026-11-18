-- Lootwright Arrow.lua: a small on-screen arrow + distance to a spawn.
-- Forever doesn't show the game's own waypoint arrow, so we draw one.
-- Maths in the player's map: x grows east, y grows south (0..1); the map's size in yards turns them
-- into yards. GetPlayerFacing is radians from north, counter-clockwise, and so is the bearing below,
-- so the arrow turns by bearing - facing.

local _, ns = ...
local Arrow = {}
ns.Arrow = Arrow

local PI = math.pi
local ARRIVE_YARDS = 10

-- pcall wrapper: returns the call's results, or nil if it errored.
local function try(fn, ...)
    if not fn then return nil end
    local r = { pcall(fn, ...) }
    if not r[1] then return nil end
    return unpack(r, 2)
end

-- The modern client returns "secret" values in restricted situations; treat them as unknown.
local function usable(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end

local function xy(p)
    if not p then return nil end
    if p.GetXY then return p:GetXY() end
    return p.x, p.y
end

-- dx, dy in yards (east, south) -> distance, bearing (radians from north, counter-clockwise)
function Arrow.Bearing(dx, dy)
    return math.sqrt(dx * dx + dy * dy), math.atan2(-dx, -dy)
end

-- Normalise an angle to -pi..pi.
local function wrap(a)
    while a > PI do a = a - 2 * PI end
    while a < -PI do a = a + 2 * PI end
    return a
end

-- Self-check: north is 0, east is -pi/2 (clockwise), west is +pi/2.
do
    local d, b = Arrow.Bearing(0, -10)
    assert(d == 10 and math.abs(b) < 1e-9)
    local _, e = Arrow.Bearing(5, 0)
    assert(math.abs(e + PI / 2) < 1e-9)
    local _, w = Arrow.Bearing(-5, 0)
    assert(math.abs(w - PI / 2) < 1e-9)
    assert(math.abs(wrap(3 * PI / 2) + PI / 2) < 1e-9)
end

-- A map's size in yards, from its corners in world space (world X runs north, world Y runs west).
local sizes = {}
local function mapSize(m)
    if sizes[m] then return sizes[m][1], sizes[m][2] end
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return nil end
    local _, a = try(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(0, 0))
    local _, b = try(C_Map.GetWorldPosFromMapPos, m, CreateVector2D(1, 1))
    local ax, ay = xy(a)
    local bx, by = xy(b)
    if not (usable(ax) and usable(bx)) then return nil end
    local w, h = math.abs(ay - by), math.abs(ax - bx)
    if w == 0 or h == 0 then return nil end
    sizes[m] = { w, h }
    return w, h
end

-- The continent uiMapID a map belongs to (walking up the map hierarchy), or nil.
local continents = {}
local function continentOf(m)
    if continents[m] ~= nil then return continents[m] or nil end
    local id, found = m, false
    for _ = 1, 10 do
        local info = try(C_Map.GetMapInfo, id)
        if not info then break end
        if info.mapType == (Enum.UIMapType and Enum.UIMapType.Continent or 2) then found = true; break end
        if not info.parentMapID or info.parentMapID == 0 then break end
        id = info.parentMapID
    end
    continents[m] = found and id or false
    return found and id or nil
end

-- The target's position in map m (0..1), or nil if it's on another continent.
local function targetIn(t, m)
    if t.mapId == m then return t.x, t.y end
    -- The world-position conversion returns nonsense across continents, so check first.
    local tc, pc = continentOf(t.mapId), continentOf(m)
    if not tc or tc ~= pc then return nil end
    if not (C_Map.GetWorldPosFromMapPos and C_Map.GetMapPosFromWorldPos) then return nil end
    local cont, world = try(C_Map.GetWorldPosFromMapPos, t.mapId, CreateVector2D(t.x, t.y))
    if not cont or not world then return nil end
    local got, pos = try(C_Map.GetMapPosFromWorldPos, cont, world, m)
    if got ~= m then return nil end
    return xy(pos)
end

----------------------------------------------------------------------
-- Frame
----------------------------------------------------------------------
local frame, target -- target = { mapId, x, y (0..1), name }

local function mapName(m)
    local info = try(C_Map.GetMapInfo, m)
    return info and info.name or ("map " .. m)
end

-- Like try, for calls with one result, without packing results into a table: tick() runs 20 times
-- a second, and try's table per call added up to ~60 throwaway tables a second.
local function try1(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if ok then return v end
end

local function tick()
    if not target then frame:Hide(); return end
    local m = usable(try1(C_Map.GetBestMapForUnit, "player"))
    local px, py
    if m then px, py = xy(try1(C_Map.GetPlayerMapPosition, m, "player")) end
    px, py = usable(px), usable(py)
    if px == 0 and py == 0 then px = nil end
    local tx, ty, w, h
    if m and px then tx, ty = targetIn(target, m) end
    if tx then w, h = mapSize(m) end

    if not (tx and w) then
        frame.arrow:SetVertexColor(0.5, 0.5, 0.5)
        frame.arrow:SetRotation(0)
        frame.dist:SetText("In " .. mapName(target.mapId))
        return
    end

    local dist, bearing = Arrow.Bearing((tx - px) * w, (ty - py) * h)
    local facing = usable(try1(GetPlayerFacing))
    if facing then
        local turn = wrap(bearing - facing)
        frame.arrow:SetRotation(turn)
        if math.abs(turn) < 0.35 then
            frame.arrow:SetVertexColor(0.25, 1, 0.25) -- heading the right way
        else
            frame.arrow:SetVertexColor(1, 0.82, 0)
        end
    else
        frame.arrow:SetVertexColor(0.5, 0.5, 0.5) -- facing unknown (e.g. restricted area)
        frame.arrow:SetRotation(0)
    end
    frame.dist:SetText(string.format("%d yd", math.floor(dist + 0.5)))
    if dist < ARRIVE_YARDS then
        ns.say("Arrived at " .. (target.name or "the waypoint") .. ".")
        Arrow.Clear()
    end
end

local function build()
    frame = CreateFrame("Button", "LootwrightArrow", UIParent)
    frame:Hide()
    frame:SetSize(110, 80)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:RegisterForClicks("RightButtonUp")

    frame.arrow = frame:CreateTexture(nil, "ARTWORK")
    frame.arrow:SetTexture("Interface\\Minimap\\MinimapArrow") -- points north at rotation 0
    frame.arrow:SetSize(42, 42)
    frame.arrow:SetPoint("TOP", 0, -2)

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.title:SetPoint("TOP", frame.arrow, "BOTTOM", 0, -2)
    frame.title:SetWidth(220)
    frame.dist = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.dist:SetPoint("TOP", frame.title, "BOTTOM", 0, -2)
    frame.dist:SetWidth(220)

    local pos = LootwrightDB.arrowPos
    if pos then
        frame:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
    else
        frame:SetPoint("TOP", UIParent, "TOP", 0, -180)
    end
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p, _, rp, x, y = self:GetPoint()
        LootwrightDB.arrowPos = { p, rp, x, y }
    end)
    frame:SetScript("OnClick", function() Arrow.Clear() end)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:AddLine(target and target.name or "Waypoint")
        GameTooltip:AddLine("Right-click to clear. Drag to move.", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, dt)
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        tick()
    end)
end

-- p = { mapId, x, y } with x, y in 0..1.
function Arrow.Set(p, name)
    if not frame then build() end
    target = { mapId = p.mapId, x = p.x, y = p.y, name = name }
    frame.title:SetText(name or "")
    frame:Show()
    tick()
end

function Arrow.Clear()
    target = nil
    if frame then frame:Hide() end
    if C_Map.ClearUserWaypoint then pcall(C_Map.ClearUserWaypoint) end
end
