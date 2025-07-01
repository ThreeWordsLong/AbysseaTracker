require('helpers')
local dats = require('ffxi.dats');
local messageDat = require('messagedat');
local log = require('logger');
local MobEntry = T{};
local zm = {};

local resolvePatterns = T{

    { pattern = "The fiend appears vulnerable to (.-) elemental magic!.*",         proc = 'yellow', type = 'hint' },
    { pattern = "The fiend appears vulnerable to (.-) elemental weapon skills!.*", proc = 'red',    type = 'hint' },
    { pattern = "The fiend appears vulnerable to (.-) weapon skills!.*",           proc = 'blue',   type = 'hint' },  

    { pattern = "The fiend is unable to cast magic.",          proc = 'yellow', type = 'trigger'},
    { pattern = "The fiend is unable to use special attacks.", proc = 'blue',   type = 'trigger'},
    { pattern = "The fiend is frozen in its tracks.",          proc = 'red',    type = 'trigger'},
}

function MobEntry:New(id, name)
    local mobEntry = {
        Id = id,
        Name = name,
        Index = bit.band(id, 0x7FF),
    };
    setmetatable(mobEntry, self);
    self.__index = self;
    return mobEntry;
end

local function normalizeName(str)
    return str:lower():gsub('%s+', ' '):gsub('[^%w ]', '')
end

local function loadZoneData(zoneId)
    local success, zoneData = pcall(require, string.format("data.%d", zoneId))
    if not success or type(zoneData) ~= "table" or not zoneData.Names then
        return nil -- Failed to load zone data
    end

    -- Normalize keys in-place for safer lookups
    local normalized = T{}
    for k, v in pairs(zoneData.Names) do
        local norm = normalizeName(k)
        normalized[norm] = v
        normalized[norm].Original = k  -- optional: store original for debugging/display
    end
    zoneData.NormalizedNames = normalized

    return zoneData
end

--[[
    Credit to atom0s for the bulk of this function, taken from watchdog.
]]--
local function LoadMobs(zid, sid)
    NotoriousMobsByID = T{}
    NotoriousMobsByIndex = T{}

    local file = dats.get_zone_npclist(zid, sid);
    if (file == nil or file:len() == 0) then
        log.error('Failed to determine zone entity DAT file for current zone. [zid: %d, sid: %d]', zid, sid);
        return false;
    end

    local f = io.open(file, 'rb');
    if (f == nil) then
        log.error('Failed to access zone entity DAT file for current zone. [zid: %d, sid: %d]', zid, sid);
        return false;
    end

    local size = f:seek('end');
    f:seek('set', 0);

    if (size == 0 or ((size - math.floor(size / 0x20) * 0x20) ~= 0)) then
        f:close();
        log.error('Failed to validate zone entity DAT file for current zone. [zid: %d, sid: %d]', zid, sid);
        return false;
    end

    -- Read in NM Names
    local trackedNames = loadZoneData(zid)
    if not trackedNames then
        log.error('Failed to load name table for current zone. [zid: %d, sid: %d]', zid, sid);
        f:close();
        return false;
    end

    log.debug('NMs for zone: %s %s', zid, trackedNames);

    for _ = 0, ((size / 0x20) - 0x01) do
        local data = f:read(0x20);
        local name, id = struct.unpack('c28L', data);
        name = name:trim('\0');

        if id > 0 and string.len(name) > 0 then
            local entry = MobEntry:New(id, name);
            local normName = normalizeName(name)
            if trackedNames.NormalizedNames[normName] then
                NotoriousMobsByID[id] = entry
                NotoriousMobsByIndex[entry.Index] = entry
            end
        end
    end

    f:close();
    return true;
end


local function LoadProcs(zoneId)
    messageDat.ClearCache()
    AbysseaProcMessages = T{}
    local success, result = pcall(function()
        return messageDat.PreprocessZoneMessages(zoneId, function(msg)
            local text = type(msg.Text) == 'string' and msg.Text or tostring(msg.Text)
            for _, entry in ipairs(resolvePatterns) do
                local matched = text:match(entry.pattern)
                if matched then
                    return {
                        Id = msg.Id,
                        Proc = entry.proc,
                        Type = entry.type,
                        Match = matched:lower(),
                        Text = text
                    }
                end
            end
            return nil
        end)
    end)

    if success and result then
        AbysseaProcMessages = result
    else
        log.error("Failed to load proc messages for zone %s", zoneId)
    end
end


zm.LoadMobs = LoadMobs
zm.LoadProcs = LoadProcs

return zm;
