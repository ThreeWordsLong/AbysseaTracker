require('common');

local function getEntityFromId(id)
    if id and id > 0 then
        for x = 0, 2302 do
            local e = GetEntity(x);
            if (e and e.ServerId and e.ServerId == id) then
                return {["Name"] = e.Name or 'Unknown', ["Index"] = x};
            end
        end
    end
    return {["Name"] = 'Unknown', ["Index"] = 0};
end

function shallow_copy(tbl)
    local copy = T{}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

function intersect_by_key(a, b)
    local result = T{}
    for k, v in pairs(a) do
        if b[k] then
            result[k] = v
        end
    end
    return result
end

--Credit: Thorny
--[[
* Parses the given action packet.
*
* @param {userdata} packet - The packet data to parse.
* @return {table} The parsed action packet.
--]]


function ParseActionPacket(e)
   local bitData;
    local bitOffset;
    local maxLength = e.size * 8;
    local function UnpackBits(length)
        if ((bitOffset + length) >= maxLength) then
            maxLength = 0; --Using this as a flag since any malformed fields mean the data is trash anyway.
            return 0;
        end
        local value = ashita.bits.unpack_be(bitData, 0, bitOffset, length);
        bitOffset = bitOffset + length;
        return value;
    end

    local actionPacket = T{};
    bitData = e.data_raw;
    bitOffset = 40;
    actionPacket.ActorId = UnpackBits(32);
    local ent = getEntityFromId(actionPacket.ActorId) or {}
    actionPacket.Name = ent.Name or 'Unknown'
    actionPacket.ActorIndex = ent.Index or 0
    local targetCount = UnpackBits(6);
    --Unknown 4 bits
    bitOffset = bitOffset + 4;
    actionPacket.Type = UnpackBits(4);
    actionPacket.Param = UnpackBits(32);

    actionPacket.Recast = UnpackBits(32);

        actionPacket.Targets = T{}
        if (targetCount > 0) then
            for i = 1, targetCount do
                local target = T{}
                target.Id = UnpackBits(32)
                local target_ent = getEntityFromId(target.Id) or {}
                target.Name = target_ent.Name or 'Unknown'
                target.Index = target_ent.Index or 0

                local actionCount = UnpackBits(4)
                if (actionCount == 0) then
                    break;
                else
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

                    
                    local hasAdditionalEffect = (UnpackBits(1) == 1);
                    if hasAdditionalEffect then
                        local additionalEffect = {};
                        additionalEffect.Damage = UnpackBits(10);
                        additionalEffect.Param = UnpackBits(17);
                        additionalEffect.Message = UnpackBits(10);
                        action.AdditionalEffect = additionalEffect;
                    end

                    local hasSpikesEffect = (UnpackBits(1) == 1);
                    if hasSpikesEffect then
                        local spikesEffect = {};
                        spikesEffect.Damage = UnpackBits(10);
                        spikesEffect.Param = UnpackBits(14);
                        spikesEffect.Message = UnpackBits(10);
                        action.SpikesEffect = spikesEffect;
                    end

                    target.Actions:append(action);
                end
            end
            actionPacket.Targets:append(target);
        end
    end

    if  (maxLength ~= 0) and (#actionPacket.Targets > 0) then
        return actionPacket;
    end
end



-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
function ParseMobUpdatePacket(e)
	if (e.id == 0x00E) then
		local mobPacket = T{};
		mobPacket.ActorId = struct.unpack('L', e.data, 0x04 + 1);
		mobPacket.ActorIndex = struct.unpack('H', e.data, 0x08 + 1);
		mobPacket.updateFlags = struct.unpack('B', e.data, 0x0A + 1);
		if (bit.band(mobPacket.updateFlags, 0x02) == 0x02) then
			mobPacket.newClaimId = struct.unpack('L', e.data, 0x2C + 1);
		end
        local ent = GetEntity(mobPacket.ActorIndex);
        if ent then
            mobPacket.Name = ent.Name or 'Unknown';
        end
		return mobPacket;
	end
end

function ParseBattleMessagePacket(e)
    if e.id ~= 0x0029 then return nil end

    local bitData = e.data
    local idAndSize = struct.unpack('H', bitData, 0x00 + 1) -- First 2 bytes
    local id   = bit.band(idAndSize, 0x01FF)                -- Lower 9 bits
    local size = bit.rshift(bit.band(idAndSize, 0xFE00), 9) -- Upper 7 bits

    local sync = struct.unpack('H', bitData, 0x02 + 1)

    local p = {
        id           = id,
        size         = size,
        sync         = sync,
        UniqueNoCas  = struct.unpack('L', bitData, 0x04 + 1),
        UniqueNoTar  = struct.unpack('L', bitData, 0x08 + 1),
        Data         = struct.unpack('L', bitData, 0x0C + 1),
        Data2        = struct.unpack('L', bitData, 0x10 + 1),
        ActIndexCas  = struct.unpack('H', bitData, 0x14 + 1),
        ActIndexTar  = struct.unpack('H', bitData, 0x16 + 1),
        MessageNum   = struct.unpack('H', bitData, 0x18 + 1),
        Type         = struct.unpack('B', bitData, 0x1A + 1),
        padding00    = struct.unpack('B', bitData, 0x1B + 1),
    }

    return p
end

function ParseRestMessagePacket(e)
    if e.id ~= 0x2A then return nil end

    local bitData = e.data
    local idAndSize = struct.unpack('H', bitData, 0x00 + 1)
    local id   = bit.band(idAndSize, 0x01FF)
    local size = bit.rshift(bit.band(idAndSize, 0xFE00), 9)
    local sync = struct.unpack('H', bitData, 0x02 + 1)

    local p = {
        id          = id,
        size        = size,
        sync        = sync,
        ActorId     = struct.unpack('I4', bitData, 0x04 + 1),
        num         = {
            struct.unpack('i4', bitData, 0x08 + 1),
            struct.unpack('i4', bitData, 0x0C + 1),
            struct.unpack('i4', bitData, 0x10 + 1),
            struct.unpack('i4', bitData, 0x14 + 1)
        },
        ActIndex    = struct.unpack('H', bitData, 0x18 + 1), -- Seemingly not always sent
        messageId   = struct.unpack('H', bitData, 0x1A + 1),
        targetIndex = struct.unpack('H', bitData, 0x1C + 1),
        targetName  = struct.unpack('c32', bitData, 0x1E + 1):match("^[^%z]*") or nil
    }

    local ent = getEntityFromId(p.ActorId) or {}
    p.Name = ent.Name or 'Unknown'
    p.ActorIndex = ent.Index or 0
    p.param = p.num[1]

    return p
end



