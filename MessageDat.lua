--Credit: Thorny

local dats = require('ffxi.dats');
local ffi = require('ffi');
local cache = false;
local messageDatData = {};

local function LoadMessageDatByPath(datPath)
    local dat = io.open(datPath, 'rb');
    if not dat then return; end

    local realSize = dat:seek('end');
    dat:seek('set');
    local datSize = struct.unpack('L', dat:read(4)) - 0x10000000;
    if (datSize ~= realSize - 4) then return; end
    
    local buffer;
    if (math.fmod(datSize, 4) == 0) then
        buffer = ffi.new("uint32_t[?]", datSize/4)
        dat:seek('set', 4);
        ffi.copy(buffer, dat:read(datSize), datSize);
        dat:close();
        for i = 0,datSize/4 do
            buffer[i] = bit.bxor(buffer[i], 0x80808080);
        end
    else
        buffer = ffi.new("uint8_t[?]", datSize)
        dat:seek('set', 4);
        ffi.copy(buffer, dat:read(datSize), datSize)
        dat:close()
        for i = 0,datSize do
            buffer[i] = bit.bxor(buffer[i], 0x80);
        end
    end
    
    local data = ffi.string(buffer, datSize);
    local start = struct.unpack('L', data, 1) - 4;
    local offsets = T{};
    for i = 0,start,4 do
        offsets:append(struct.unpack('L', data, i+1));
    end
    offsets:append(datSize);
    
    local outputTable = {};
    for i = 1, #offsets - 1 do
        local startPosition = offsets[i];
        local length = offsets[i + 1] - offsets[i];
        if length > 0 then
            local id = i - 1;
            local text = struct.unpack(string.format('c%d', length), data, startPosition + 1);
            outputTable[id] = { Id = id, Text = text };
        end
    end
    return outputTable;
end

local function LoadMessageDat(zone)
    if cache == false then
        messageDatData = {};
    end

    local datId;
    if (zone < 256) then
        datId = zone + 6420;
    elseif (zone < 1000) then
        datId = zone + 85335;
    else
        datId = zone + 67511;
    end
    if not datId then return false; end

    local datPath = dats.get_file_path(datId);
    if not datPath then return false; end
    
    local output = LoadMessageDatByPath(datPath);
    if (output == nil) then return false; end

    messageDatData[zone] = output;
    return true;
end

local function GetZoneMessage(self, zoneId, messageId)
    if messageDatData[zoneId] == nil then
        if not LoadMessageDat(zoneId) then
            return;
        end
    end

    local message = messageDatData[zoneId][bit.band(messageId, 0x7FFF)];
    if message then
        return message;
    end
end

local function DumpToFile(self, zoneId, fileName)
    local buffer = T{};

    for i = 1,0x7FFF do
        local msg = GetZoneMessage(self, zoneId, i);
        if msg then
            buffer:append(msg);
        end
    end

    local outFile = io.open(fileName, 'w');
    if outFile then
        for _,entry in ipairs(buffer) do
            outFile:write(string.format('%u = %q\n\n', entry.Id, entry.Text));
        end
        outFile:close();
    end
end

local function PreprocessZoneMessages(zoneId, filterFn)
    if not messageDatData[zoneId] then
        if not LoadMessageDat(zoneId) then return nil end
    end

    local results = T{}
    for id, msg in pairs(messageDatData[zoneId]) do
        local safeId = bit.band(id, 0x7FFF)
        local mapped = filterFn(msg, safeId)
        if mapped ~= nil then
            results[safeId] = mapped
        end
    end

    return results
end



local exports = {
    DumpToFile = DumpToFile,
    GetZoneMessage = GetZoneMessage,
    LoadMessageDat = LoadMessageDat,
    PreprocessZoneMessages = PreprocessZoneMessages,
};


return exports;