require('common')
require('helpers')
local log = require('logger');
local zm = require('ZoneManager')
local pm = {}

--Credit: Thorny
--[[
* Parses the given action packet.
*
* @param {userdata} packet - The packet data to parse.
* @return {table} The parsed action packet.
--]]
function pm.ParseActionPacket(e)
    log.debug("Action Packet Detected.")
    local bitData;
    local bitOffset;
    local maxLength = e.size * 8;
    local function UnpackBits(length)
        if ((bitOffset + length) >= maxLength) then
            maxLength = 0; -- Using this as a flag since any malformed fields mean the data is trash anyway.
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local actionPacket = T{};
    local relevantPacket = false;
    bitData = e.data_raw;
    bitOffset = 40;
    actionPacket.ActorId = UnpackBits(32);
    actionPacket.IsNM = false

    if NotoriousMobsByID[actionPacket.ActorId] then
        actionPacket.Name = NotoriousMobsByID[actionPacket.ActorId].Name or 'Unknown';
        actionPacket.ActorIndex = NotoriousMobsByID[actionPacket.ActorId].Index or 0;
        actionPacket.IsNM = true;
        relevantPacket = true;
    elseif not PartyMembersByID[actionPacket.ActorId] then
        return nil; -- Not a party member or NM, ignore this packet
    end

    local targetCount = UnpackBits(6);
    bitOffset = bitOffset + 4; -- Skip unknown 4 bits
    actionPacket.Type = UnpackBits(4);
    actionPacket.Param = UnpackBits(32);
    actionPacket.Recast = UnpackBits(32);
    actionPacket.Targets = T{}

    for i = 1, targetCount do
        local target = T{}
        local relevantTarget = false

        target.Id = UnpackBits(32)

        if not actionPacket.IsNM then
            if NotoriousMobsByID[target.Id] then
                target.Index = NotoriousMobsByID[target.Id].Index or 0
                target.Name = NotoriousMobsByID[target.Id].Name or 'Unknown'
                relevantPacket = true
                relevantTarget = true
            end
        else
            target.Name = 'Unknown'
            target.Index = 0
            if PartyMembersByID[target.Id] then
                relevantTarget = true
            end
        end

        local actionCount = UnpackBits(4)
        if actionCount == 0 then
            goto continue
        end

        target.Actions = T{}
        for j = 1, actionCount do
            local action = T{}
            action.Miss     = UnpackBits(3)
            action.Kind     = UnpackBits(2)
            action.Sub_Kind = UnpackBits(12)
            action.Info     = UnpackBits(5)
            action.Scale    = UnpackBits(5)
            action.Param    = UnpackBits(17)
            action.Message  = UnpackBits(10)
            action.Flags    = UnpackBits(31)

            if UnpackBits(1) == 1 then
                action.AdditionalEffect = {
                    Damage  = UnpackBits(10),
                    Param   = UnpackBits(17),
                    Message = UnpackBits(10)
                }
            end

            if UnpackBits(1) == 1 then
                action.SpikesEffect = {
                    Damage  = UnpackBits(10),
                    Param   = UnpackBits(14),
                    Message = UnpackBits(10)
                }
            end

            if relevantTarget then
                target.Actions:append(action)
            end
        end

        if relevantTarget then
            actionPacket.Targets:append(target)
        end

        ::continue::
    end

    if (maxLength ~= 0) and (#actionPacket.Targets > 0) and relevantPacket then
        log.debug("Relevant Action Packet Detected.")
        return actionPacket
    end
    return nil
end

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
function pm.ParseMobUpdatePacket(e)
	if (e.id == 0x00E) then
		local mobPacket = T{};
		mobPacket.ActorId = struct.unpack('L', e.data, 0x04 + 1);
        if NotoriousMobsByID[mobPacket.ActorId] then
            mobPacket.Name = NotoriousMobsByID[mobPacket.ActorId].Name or 'Unknown';
            mobPacket.ActorIndex = struct.unpack('H', e.data, 0x08 + 1);
            mobPacket.updateFlags = struct.unpack('B', e.data, 0x0A + 1);
            if (bit.band(mobPacket.updateFlags, 0x02) == 0x02) then
                mobPacket.newClaimId = struct.unpack('L', e.data, 0x2C + 1);
            end
            return mobPacket;
        else
            return nil
        end
	end
end


function pm.ParseRestMessagePacket(e)
    if e.id ~= 0x2A then return nil end

    local bitData = e.data
    local actorId = struct.unpack('I4', bitData, 0x04 + 1)
    local messageId = struct.unpack('H', bitData, 0x1A + 1)
    local param = struct.unpack('i4', bitData, 0x08 + 1)
    local relativeId = bit.band(messageId, 0x7FFF)

    local mob = NotoriousMobsByID[actorId]
    if not mob then return nil end

    if next(AbysseaProcMessages) == nil then
        log.wdebug('Attempting to parse Rest Message Packet while AbysseaProcMessages is empty')
        return nil
    end

    local proc = AbysseaProcMessages[relativeId]
    if not proc then return nil end

    local packet = {
        ActorIndex = mob.Index or 0,
        ActorId   = actorId,
        messageId = messageId,
        Type      = proc.Type,
        Proc      = proc.Proc:lower(),
        Name      = mob.Name or 'Unknown',
    }

    -- Only attempt to map param if it's a hint-type
    if proc.Type == 'hint' then
        if not param then
            log.debug('No parameter provided for message')
            return nil
        else
            log.debug('Parameter provided: %s', param)
        end

        if proc.Proc == 'blue' then
            packet.Param = RestSkillMapping[param]
        elseif proc.Proc == 'red' or proc.Proc == 'yellow' then
            packet.Param = RestElementMapping[param]
        end

        if not packet.Param then
            log.debug("Failed to resolve parameter (%s) for proc type %s", param, proc.Proc)
            return nil
        else
            log.debug("Resolved parameter (%s) for proc type %s to %s", param, proc.Proc, packet.Param)
        end
    end

    return packet
end


function pm.HandlePartyPacket()
    CachePartyMembers()
end

function pm.HandleZonePacket(e)
    local zone = struct.unpack('H', e.data, 0x30 + 1);;
    local subZone = struct.unpack('H', e.data, 0x9E + 1);
    NotoriousMobsByID = T{}
    NotoriousMobsByIndex = T{}
    CachePartyMembers()
    if IsAbysseaZone(zone) then
        zm.LoadMobs(zone, subZone)
        zm.LoadProcs(zone)
        return true
    end
    return false
end

function pm.Init()
    CachePartyMembers()
    local zoneId = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if IsAbysseaZone(zoneId) then
        log.info('Detected Abyssea zone: %d, will begin tracking...', zoneId)
        zm.LoadMobs(zoneId, 0)
        zm.LoadProcs(zoneId)
        return true
    else
        log.info('Not in an Abyssea zone, skipping initialization.')
        return false
    end
end

return pm