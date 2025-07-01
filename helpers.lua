require('common');

AbysseaZones = T{ 
    [15]=true,      -- Abyssea - Konschtat ROM/23/80
    [45]=true,      -- Abyssea - Tahrongi ROM/23/110
    [132]=true,     -- Abyssea - La Theine ROM/24/69
    [215]=true,     -- Abyssea - Attohwa ROM/25/24
    [216]=true,     -- Abyssea - Misareaux ROM/25/25
    [217]=true,     -- Abyssea - Vunkerl ROM/25/26
    [218]=true,     -- Abyssea - Altepa ROM/25/27
    [253]=true,     -- Abyssea - Uleguerand ROM/25/62
    [254]=true,     -- Abyssea - Grauberg ROM/25/63
    [255]=true      -- Abyssea - Empyreal Paradox ROM/25/64
};

RestElementMapping = T{
    [1] = 1,--fire
    [2] = 5,--ice
    [3] = 4,--wind
    [4] = 2,--earth
    [5] = 6,--thunder
    [6] = 3,--water
    [7] = 7,--light
    [8] = 8,--dark
}

RestSkillMapping = T{
    [1] = 1,   -- hand-to-hand
    [2] = 2,   -- dagger
    [3] = 3,   -- sword
    [4] = 4,   -- great sword
    [5] = 5,   -- axe
    [6] = 6,   -- great axe
    [7] = 7,   -- scythe
    [8] = 8,   -- polearm
    [9] = 9,   -- katana
    [10] = 10, -- great katana
    [11] = 11, -- club
    [12] = 12, -- staff
    [13] = 25, -- archery
    [14] = 26  -- marksmanship
}

NotoriousMobsByID = T{}
NotoriousMobsByIndex = T{}
AbysseaProcMessages = T{} -- zoneId -> { messageId -> hintType }
PartyMembersByID = T{}


function IsAbysseaZone(zoneId)
    return AbysseaZones[zoneId] == true
end

--Credit: Thorny
function GetTimeStamp()
    local pointer = ashita.memory.read_uint32(addon.state.time + 0x34);
    local rawTime = ashita.memory.read_uint32(pointer + 0x0C) + 92514960;
    local timestamp = {};
	timestamp.time = rawTime
    timestamp.day = math.floor(rawTime / 3456);
    timestamp.hour = math.floor(rawTime / 144) % 24;
    timestamp.minute = math.floor((rawTime % 144) / 2.4);
	timestamp.DayIndex = ((timestamp.day - 1) % 8) + 1;
    return timestamp;
end

function Keys(tbl)
    local result = {}
    for k in pairs(tbl) do
        table.insert(result, k)
    end
    return result
end


function CachePartyMembers()
    PartyMembersByID = T{}
    local party = AshitaCore:GetMemoryManager():GetParty()
    if not party then return end

    for i = 0, 17 do
        if party:GetMemberIsActive(i) == 1 then
            local serverId = party:GetMemberServerId(i)
            if serverId and serverId > 0 then
                PartyMembersByID[serverId] = true
            end
        end
    end
end

function ShallowCopy(tbl)
    local copy = T{}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

function IntersectByKey(a, b)
    local result = T{}
    for k, v in pairs(a) do
        if b[k] then
            result[k] = v
        end
    end
    return result
end


