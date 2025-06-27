local stagger_data = require('staggertables');
local HintManager = require('hintmanager')
local logger = require('logger')
local dlog = logger.debug
local MobManager = {};
MobManager.waitingForCheck = false
MobManager.TrackedMobs = {};
MobManager.lastCheckAttempt = 0
local entMgr = AshitaCore:GetMemoryManager():GetEntity();
local zoneData = T{};
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


local function getValidSpellsByDay(day_index)
    local function safe_day_index(i)
        return ((i - 1) % 8) + 1
    end

    local result = T{}
    for _, i in ipairs({ 0, 1, 2 }) do
        local element_id = safe_day_index(day_index + i)
        local spells = stagger_data.spells_by_element[element_id]
        if spells then
            for _, spell in pairs(spells) do
                result[spell.id] = spell
            end
        end
    end

    return result
end

local function getValidWeaponSkillsByHour(hour)
    local category
    if (hour >= 6 and hour < 14) then
        category = 'piercing'
    elseif (hour >= 14 and hour < 22) then
        category = 'slashing'
    else
        category = 'blunt'
    end

    return stagger_data.ws_by_category[category] or T{}
end

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
local function GetIsMobByIndex(index)
	return (bit.band(AshitaCore:GetMemoryManager():GetEntity():GetSpawnFlags(index), 0x10) ~= 0);
end

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
local function GetIsValidMob(mobIdx)
	-- Check if we are valid, are above 0 hp, and are rendered
    local renderflags = AshitaCore:GetMemoryManager():GetEntity():GetRenderFlags0(mobIdx);
    if bit.band(renderflags, 0x200) ~= 0x200 or bit.band(renderflags, 0x4000) ~= 0 then
        return false;
    end
	return true;
end

--Credit: Thorny
local function GetTimeStamp()
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

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
local function GetPartyMemberIds()
	local partyMemberIds = T{};
	local party = AshitaCore:GetMemoryManager():GetParty();
	for i = 0, 17 do
		if (party:GetMemberIsActive(i) == 1) then
			table.insert(partyMemberIds, party:GetMemberServerId(i));
		end
	end
	return partyMemberIds;
end


local function CheckNM(index)
    if not index then return false end

    local ent_name = entMgr:GetName(index)
    if ent_name and zoneData and zoneData.Names then
        local resource = zoneData.Names[ent_name]
        if resource then
            return true
        end
    end

    return false
end

-- I guess I'll be a good boy and not use injections
local function SendEquipInspectPacket(index)
    local ent = GetEntity(index)
    if not ent then return end

    local id    = 0x00DD
    local size  = 0x06 -- 6 × 4 = 24 bytes
    local sync  = 0

    local serverId = ent.ServerId

    local packed = {}

    -- Header: ID + size packed into 2 bytes
    local packedIdSize = bit.bor(bit.band(id, 0x01FF), bit.lshift(size, 9))
    table.insert(packed, bit.band(packedIdSize, 0xFF))          -- Byte 1
    table.insert(packed, bit.rshift(packedIdSize, 8))           -- Byte 2
    table.insert(packed, bit.band(sync, 0xFF))                  -- Byte 3
    table.insert(packed, bit.rshift(sync, 8))                   -- Byte 4

    -- ServerId (UniqueNo) - 4 bytes
    for i = 0, 3 do
        table.insert(packed, bit.band(bit.rshift(serverId, i * 8), 0xFF))
    end

    -- ActIndex - 4 bytes
    for i = 0, 3 do
        table.insert(packed, bit.band(bit.rshift(index, i * 8), 0xFF))
    end

    -- Kind (0 = inspect)
    table.insert(packed, 0x00)

    -- Padding (3 bytes)
    table.insert(packed, 0x00)
    table.insert(packed, 0x00)
    table.insert(packed, 0x00)

    AshitaCore:GetPacketManager():AddOutgoingPacket(0xDD, packed)
	dlog("Sent inspect packet for ID: %d (Index: %d)", serverId, index)
end

local function initClaim(index, id, name)
    local ts = GetTimeStamp()
    local isNM = CheckNM(index)

    if not MobManager.TrackedMobs[index] then
        local base = {
            Id = id,
            Name = name,
            isNM = isNM,
        }

        if isNM then
            base.pulled = ts.time
            base.possible_spells = T(shallow_copy(getValidSpellsByDay(ts.DayIndex)))
            base.possible_physical_ws = T(shallow_copy(getValidWeaponSkillsByHour(ts.hour)))
            base.possible_elemental_ws = T(shallow_copy(stagger_data.ele_ws_by_id))
            base.proc_status = T{
                yellow = { triggered = false, hint = nil },
                blue   = { triggered = false, hint = nil },
                red    = { triggered = false, hint = nil },
            }
        else
            dlog("Non-NM %s somehow snuck his way into our tracked list.", name or 'Unknown')
        end

        MobManager.TrackedMobs[index] = base
    end
end


local function apply_hint(currentMob, proc, param)

    if not param or type(param) ~= 'number' or param < 1 then
        return
    end

    local current, pool

    if not currentMob then
       dlog("No current mob provided for apply_hint")
        return
    elseif not proc then
       dlog("No proc type provided for apply_hint")
        return
    end
   dlog("Applying Hint to Mob: %s", currentMob.Name or 'Unknown')

    if proc == 'yellow' then
        current = currentMob.possible_spells
        pool = stagger_data.spells_by_element and stagger_data.spells_by_element[param]
    elseif proc == 'blue' then
        current = currentMob.possible_physical_ws
        pool = stagger_data.phys_ws_by_skill and stagger_data.phys_ws_by_skill[param]
    elseif proc == 'red' then
        current = currentMob.possible_elemental_ws
        pool = stagger_data.ele_ws_by_element and stagger_data.ele_ws_by_element[param]
    else
       dlog("Unknown proc type: %s", tostring(proc))
        return
    end 


    if not current or type(current) ~= 'table' then
       dlog("No valid current spells for proc %s on mob %s", proc, currentMob.Name or 'Unknown')
        return
    end

    if not pool or type(pool) ~= 'table' then
       dlog("No valid spell pool for element ID %s", tostring(param))
        return
    end

    local function update_possible_set(mob, proc, new_set)
        if proc == 'yellow' then
            mob.possible_spells = new_set
        elseif proc == 'blue' then
            mob.possible_physical_ws = new_set
        elseif proc == 'red' then
            mob.possible_elemental_ws = new_set
        else
            dlog("Unknown proc type: %s", tostring(proc))
        end
    end

    update_possible_set(currentMob, proc, intersect_by_key(pool, current))

    dlog("Applied %s proc hint %s to %s", proc, param, currentMob.Name or 'Unknown')
end

local function parse_trigger(currentMob, proc)
    local status = currentMob.proc_status[proc]
    if not status.triggered then
        status.triggered = true
        status.hint = "Triggered"
        if proc == 'yellow' then
            currentMob.possible_spells = T{}
        elseif proc == 'blue' then
            currentMob.possible_physical_ws = T{}
        elseif proc == 'red' then
            currentMob.possible_elemental_ws = T{}
        end
        dlog("Triggered %s proc.", proc)
    end
end

local function parse_hint(currentMob, hint)
    if not currentMob or not currentMob.proc_status or not hint or not hint.Proc or not hint.Param then
        dlog("Invalid hint or mob passed to parse_hint")
        return
    end

    local temp_hint = T(shallow_copy(hint))

    local proc = temp_hint.Proc:lower()
    local param = temp_hint.Param

    local status = currentMob.proc_status[proc]
    if not status or status.triggered or status.hint then
        dlog("Skipping hint, already triggered or applied.")
        return
    end
    

    status.hint = param
    dlog("Applying %s hint (%s) to %s", proc, tostring(param), currentMob.Name or 'Unknown')
    apply_hint(currentMob, proc, param)
end

-- Adopted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
-- If a mob performs an action on us or a party member add it to the list
MobManager.HandleActionPacket = function(e)
    if not e then return end

    local partyMemberIds = GetPartyMemberIds()

    -- Case 1: Mob acts on a party member
    if GetIsMobByIndex(e.ActorIndex) and GetIsValidMob(e.ActorIndex) and CheckNM(e.ActorIndex) and not MobManager.TrackedMobs[e.ActorIndex] then
        for i = 0, #e.Targets do
            local target = e.Targets[i]
            if target and partyMemberIds:contains(target.Id) then
                initClaim(e.ActorIndex, e.ActorId, e.Name)
            end
        end

    -- Case 2: Party member uses action (Magic or WS)
    elseif e.Type == 4 or e.Type == 3 then
        if partyMemberIds:contains(e.ActorId) then
            for i = 0, #e.Targets do
                local target = e.Targets[i]
                if target and target.Id and target.Index and GetIsMobByIndex(target.Index) and GetIsValidMob(target.Index) and CheckNM(target.Index) then
                    initClaim(target.Index, target.Id, target.Name)

                    local mob = MobManager.TrackedMobs[target.Index]
                    if not mob or not mob.isNM then return end

                    local battle_result = target.Actions and target.Actions[1] or nil
                    if battle_result and battle_result.Miss == 0 then
                        local ws_id = e.Param

                        if e.Type == 4 and mob.possible_spells[ws_id] then
                            mob.possible_spells[ws_id] = nil
                            dlog("Removed possible spell ID %d", ws_id)

                        elseif e.Type == 3 then
                            local is_phys = stagger_data.phys_ws_by_id[ws_id]
                            local is_elem = stagger_data.ele_ws_by_id[ws_id]

                            if is_phys and mob.possible_physical_ws[ws_id] then
                                mob.possible_physical_ws[ws_id] = nil
                                dlog("Removed possible physical WS ID %d", ws_id)

                            elseif is_elem and mob.possible_elemental_ws[ws_id] then
                                mob.possible_elemental_ws[ws_id] = nil
                                dlog("Removed possible elemental WS ID %d", ws_id)

                            else
                                dlog("ID %d not found in remaining set", ws_id)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
-- if a mob updates its claimid to be us or a party member add it to the list
MobManager.HandleMobUpdatePacket = function(e)
	if not e or not e.newClaimId or not GetIsValidMob(e.ActorIndex) or not CheckNM(e.ActorIndex) or MobManager.TrackedMobs[e.ActorIndex] then
        return
    end

    local partyMemberIds = GetPartyMemberIds()
    if partyMemberIds:contains(e.newClaimId) then
        initClaim(e.ActorIndex, e.ActorId, e.Name)
    end
end

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
MobManager.HandleZonePacket = function(e)
	-- Empty all our claimed targets on zone
	MobManager.TrackedMobs = T{};
    local zoneId = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if not zones[zoneId] then 
        return false
    end
    local status, data = pcall(require, string.format("data.%d", zoneId))
    if status and type(data) == "table" then
        zoneData = data
    else
        zoneData = T{}
        dlog("Failed to load zone data for zone ID %d", zoneId)
    end
	return HintManager.HandleZonePacket(e);
end

MobManager.Init = function()
    MobManager.TrackedMobs = T{}
    MobManager.waitingForCheck = false
    MobManager.lastCheckAttempt = 0

    local zoneId = AshitaCore:GetMemoryManager():GetParty():GetMemberZone(0)
    if zones[zoneId] then
        local moduleName = string.format("data.%d", zoneId)
        package.loaded[moduleName] = nil
        local ok, data = pcall(require, moduleName)
        zoneData = ok and data or T{}
    end

    return HintManager.Init()
end



MobManager.HandleRestMessagePacket = function(e)
    local actorIndex = e.ActorIndex
    if not actorIndex then
        dlog("Missing ActorIndex in packet.")
        return
    end

    if not (GetIsMobByIndex(actorIndex) and GetIsValidMob(actorIndex) and CheckNM(actorIndex)) then 
        return 
    end

    initClaim(actorIndex, e.ActorId, e.Name)

    local currentMob = MobManager.TrackedMobs[actorIndex]
    if not currentMob or not currentMob.proc_status or currentMob.isNM == false then return end

    local hint = HintManager.HandleRestMessagePacket(e)
    if not hint then return end

    local proc = hint.Proc:lower()
    if hint.Type == 'trigger' then
        parse_trigger(currentMob, proc)
    elseif hint.Type == 'hint' then
        parse_hint(currentMob, hint)
    end
end



-- I guess I'll be a good boy and not use injections
MobManager.HandleBattleMessagePacket = function(p)
    -- if not MobManager.waitingForCheck then
	-- 	return false
	-- end
	-- local target = p.ActIndexTar
    -- local mob = MobManager.TrackedMobs[target]
    -- if not mob then return end
    -- local msgId = p.MessageNum
    -- if msgId >= 170 and msgId <= 180 then
	-- 	MobManager.waitingForCheck = false
    --     mob.isNM = false
	-- 	return true
    -- elseif msgId == 249 then
	-- 	MobManager.waitingForCheck = false
    --     mob.isNM = true
	-- 	return true
    -- end
	return false
end

MobManager.Tick = function()
    local now = os.clock()
    local checkCooldown = 2.0

    for k, v in pairs(MobManager.TrackedMobs) do
        local ent = GetEntity(k)

        -- Remove if the entity no longer exists or is no longer a valid mob
        if (ent == nil or not GetIsValidMob(k)) then
			dlog("Removing stale mob [%s] (Index: %d) from claimed targets", v.Name or 'Unknown', k)
            MobManager.TrackedMobs[k] = nil
            

        -- -- If we haven't classified this mob yet, issue a global-throttled /check
        -- elseif v.isNM == nil and (now - MobManager.lastCheckAttempt > checkCooldown) and not MobManager.waitingForCheck then
		-- 	SendEquipInspectPacket(k)
		-- 	MobManager.waitingForCheck = true
        --     MobManager.lastCheckAttempt = now
        --     break  -- Only check one mob per tick to respect the global throttle
		-- elseif MobManager.waitingForCheck and (now - MobManager.lastCheckAttempt > checkCooldown + 3) then
		-- 	dlog("Clearing stale check wait state.")
		-- 	MobManager.waitingForCheck = false
		-- end
        end
    end
end

return MobManager;