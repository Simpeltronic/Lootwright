-- ItemFinder Search.lua: item name index (built once, in chunks so the game doesn't freeze) and search.

local _, ns = ...
local Search = {}
ns.Search = Search

local nameIndex          -- [itemId] = name
local building = false
local waiting = {}

-- Calls callback once the index exists. Builds it on first use.
function Search.WithIndex(callback)
    if nameIndex then callback(); return end
    waiting[#waiting + 1] = callback
    if building then return end
    building = true
    local Data = ns.Data
    local ids = Data.AllItemIds()
    local total = #ids
    local tmp, i = {}, 1
    ns.say("Building item name index (" .. total .. " items, one time)...")
    local function step()
        local stop = math.min(i + 1999, total)
        for j = i, stop do
            local id = ids[j]
            local nm = Data.ItemName(id)
            if nm and nm ~= "" then tmp[id] = nm end
        end
        i = stop + 1
        if i <= total then
            C_Timer.After(0, step)
        else
            nameIndex, building = tmp, false
            local cbs = waiting
            waiting = {}
            for _, cb in ipairs(cbs) do cb() end
        end
    end
    step()
end

function Search.IsBuilt()
    return nameIndex ~= nil
end

function Search.Name(itemId)
    return nameIndex and nameIndex[itemId]
end

-- Calls callback(ids, exactCount): exact name matches first (by ID), then partial matches
-- (shortest name first). Case-insensitive substring match.
function Search.Find(text, callback)
    Search.WithIndex(function()
        local needle = text:lower()
        local exact, partial = {}, {}
        for id, nm in pairs(nameIndex) do
            local l = nm:lower()
            if l == needle then
                exact[#exact + 1] = id
            elseif l:find(needle, 1, true) then
                partial[#partial + 1] = id
            end
        end
        table.sort(exact)
        table.sort(partial, function(a, b)
            local na, nb = nameIndex[a], nameIndex[b]
            if #na ~= #nb then return #na < #nb end
            return a < b
        end)
        local nExact = #exact
        for _, id in ipairs(partial) do exact[#exact + 1] = id end
        callback(exact, nExact)
    end)
end
