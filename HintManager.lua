--Credit: Thorny

require ('common');
local messageDat = require('messagedat');
local logger = require('logger')
local ilog, dlog = logger.info, logger.debug

local HintManager = {};
local messageHintCache = T{} -- zoneId -> { messageId -> hintType }

local element_mapping = T{
    [1] = 1,--fire
    [2] = 5,--ice
    [3] = 4,--wind
    [4] = 2,--earth
    [5] = 6,--thunder
    [6] = 3,--water
    [7] = 7,--light
    [8] = 8,--dark
}

local skill_mapping = T{
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


local resolvePatterns = T{

    { pattern = "The fiend appears vulnerable to (.-) elemental magic!.*",         proc = 'yellow', type = 'hint' },
    { pattern = "The fiend appears vulnerable to (.-) elemental weapon skills!.*", proc = 'red',    type = 'hint' },
    { pattern = "The fiend appears vulnerable to (.-) weapon skills!.*",           proc = 'blue',   type = 'hint' },  

    { pattern = "The fiend is unable to cast magic.",          proc = 'yellow', type = 'trigger'},
    { pattern = "The fiend is unable to use special attacks.", proc = 'blue',   type = 'trigger'},
    { pattern = "The fiend is frozen in its tracks.",          proc = 'red',    type = 'trigger'},
}

local zones = T{ 
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


local function FilterHints(zoneId)
    messageHintCache[zoneId] = messageDat.PreprocessZoneMessages(zoneId, function(msg)
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
end


function HintManager.Init()
    messageHintCache = T{}
    local zoneId = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if not zones[zoneId] then 
        return false
    end

    ilog('Detected Abyssea zone: %d, will begin tracking...', zoneId)

    if not messageHintCache[zoneId] then
        FilterHints(zoneId)
    end

    dlog('Successfully initialized hint manager for zone: %d', zoneId)
    return true
end

function HintManager.HandleZonePacket(e)
    messageHintCache = T{}

    local zoneId = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if not zones[zoneId] then return false end

    if not messageHintCache[zoneId] then
        FilterHints(zoneId)
    end
    return true

end

function HintManager.HandleRestMessagePacket(e)
    local zoneId = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if not zones[zoneId] then return nil end

    if not messageHintCache[zoneId] then
        FilterHints(zoneId)
    end

    dlog('Looking up message id: %s', e.messageId)

    local relativeId = bit.band(e.messageId, 0x7FFF)
    dlog('Relative message id: %s', relativeId)
    local proc = relativeId and messageHintCache[zoneId] and messageHintCache[zoneId][relativeId]
    if proc then
        dlog(proc)
    else
        dlog('No matching hint found for message id: %s', relativeId)
        return nil
    end

    if e.param then
        dlog('Parameter provided: %s', e.param)
    else
        dlog('No parameter provided for message')
        return nil
    end
        if proc.Type == 'hint' then
        local mapped = nil
        if proc.Proc == 'blue' then
            mapped = skill_mapping[e.param]
        elseif proc.Proc == 'red' or proc.Proc == 'yellow' then
            mapped = element_mapping[e.param]
        end
        if not mapped then
            dlog("Failed to resolve parameter (%s) for proc type %s", e.param, proc.Proc)
            return nil
        else
            dlog("Resolved parameter (%s) for proc type %s to %s", e.param, proc.Proc, mapped)
        end
        proc.Param = mapped
    end

    return proc
end

return HintManager