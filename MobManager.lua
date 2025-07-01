
local log = require('logger')
local sd = require('staggertables');
local MobManager = {};
MobManager.TrackedMobs = {};

local function getValidSpellsByDay(day_index)
    local function safe_day_index(i)
        return ((i - 1) % 8) + 1
    end

    local result = T{}
    for _, i in ipairs({ 0, 1, 2 }) do
        local element_id = safe_day_index(day_index + i)
        local spells = sd.spellsByElement[element_id]
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

    return sd.physWSByCategory[category] or T{}
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



local function initClaim(index, id, name, ts)
    if MobManager.TrackedMobs[index] then return end
    local base = {
        Id = id,
        Name = name,
        possibleSpells = T(ShallowCopy(getValidSpellsByDay(ts.DayIndex))),
        possiblePhysWS = T(ShallowCopy(getValidWeaponSkillsByHour(ts.hour))),
        possibleEleWS = T(ShallowCopy(sd.eleWSByID)),
        procStatus = T{
            yellow = { triggered = false, hint = nil },
            blue   = { triggered = false, hint = nil },
            red    = { triggered = false, hint = nil },
        }
    }
    if index ~= 'Target' then
        base.ts = ts
    end
    MobManager.TrackedMobs[index] = base
    log.debug("Initialized claim for mob: %s (Index: %s)", name, index)
end


local function applyHint(currentMob, proc, param)

    if not param or type(param) ~= 'number' or param < 1 then
        return
    end

    local current, pool

    if not currentMob then
       log.wdebug("No current mob provided for applyHint")
        return
    elseif not proc then
       log.wdebug("No proc type provided for applyHint")
        return
    end
   log.debug("Applying Hint to Mob: %s", currentMob.Name or 'Unknown')

    if proc == 'yellow' then
        current = currentMob.possibleSpells
        pool = sd.spellsByElement and sd.spellsByElement[param]
    elseif proc == 'blue' then
        current = currentMob.possiblePhysWS
        pool = sd.physWSBySkill and sd.physWSBySkill[param]
    elseif proc == 'red' then
        current = currentMob.possibleEleWS
        pool = sd.eleWSByElement and sd.eleWSByElement[param]
    else
       log.wdebug("Unknown proc type: %s", tostring(proc))
        return
    end 

    log.debug("Hint Pool IDs: %s", table.concat(T(Keys(pool)), ", "))
    log.debug("Current Set IDs: %s", table.concat(T(Keys(current)), ", "))



    if not current or type(current) ~= 'table' then
       log.wdebug("No valid current spells for proc %s on mob %s", proc, currentMob.Name or 'Unknown')
        return
    end

    if not pool or type(pool) ~= 'table' then
       log.wdebug("No valid spell pool for element ID %s", tostring(param))
        return
    end

    local function updatePossibleSet(mob, proc, new_set)
        if proc == 'yellow' then
            mob.possibleSpells = new_set
        elseif proc == 'blue' then
            mob.possiblePhysWS = new_set
        elseif proc == 'red' then
            mob.possibleEleWS = new_set
        else
            log.wdebug("Unknown proc type: %s", tostring(proc))
        end
    end

    updatePossibleSet(currentMob, proc, IntersectByKey(pool, current))

    log.debug("Applied %s proc hint %s to %s", proc, param, currentMob.Name or 'Unknown')
end

local function parseTrigger(currentMob, proc)
    local status = currentMob.procStatus[proc]
    if not status.triggered then
        status.triggered = true
        status.hint = "Triggered"
        if proc == 'yellow' then
            currentMob.possibleSpells = T{}
        elseif proc == 'blue' then
            currentMob.possiblePhysWS = T{}
        elseif proc == 'red' then
            currentMob.possibleEleWS = T{}
        end
        log.debug("Triggered %s proc.", proc)
    end
end

local function parseHint(currentMob, hint)
    if not currentMob or not currentMob.procStatus or not hint or not hint.Proc or not hint.Param then
        log.wdebug("Invalid hint or mob passed to parseHint")
        return
    end

    local temp_hint = T(ShallowCopy(hint))

    local proc = temp_hint.Proc:lower()
    local param = temp_hint.Param

    local status = currentMob.procStatus[proc]
    if not status or status.triggered or status.hint then
        log.debug("Skipping hint, already triggered or applied.")
        return
    end
    

    status.hint = param
    log.debug("Applying %s hint (%s) to %s", proc, tostring(param), currentMob.Name or 'Unknown')
    applyHint(currentMob, proc, param)
end

-- Adopted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
-- If a mob performs an action on us or a party member add it to the list
MobManager.HandleActionPacket = function(e)
    if not e then return end

    log.debug("MobManager Handling Action Packet")
    -- Case 1: NM acts on party member
    if e.IsNM == true then
        log.debug("Action Packet is for a Notorious Monster")
        if GetIsValidMob(e.ActorIndex) and not MobManager.TrackedMobs[e.ActorIndex] then
            initClaim(e.ActorIndex, e.ActorId, e.Name, GetTimeStamp())
        end

    -- Case 2: Party member acts using WS or Spell
    elseif e.Type == 3 or e.Type == 4 then
        if PartyMembersByID[e.ActorId] then
            for _, target in pairs(e.Targets) do
                if target and target.Id and target.Index and GetIsValidMob(target.Index) then
                    initClaim(target.Index, target.Id, target.Name, GetTimeStamp())

                    local mob = MobManager.TrackedMobs[target.Index]
                    if not mob then
                        return
                    end

                    local result = target.Actions and target.Actions[1]
                    if result and result.Miss == 0 then
                        local ws_id = e.Param

                        if e.Type == 4 then -- magic (yellow)
                            if mob.possibleSpells[ws_id] then
                                mob.possibleSpells[ws_id] = nil
                                log.debug("Removed possible spell ID %d", ws_id)
                            end

                        elseif e.Type == 3 then -- WS (blue or red)
                            local is_phys = sd.physWSByID[ws_id]
                            local is_elem = sd.eleWSByID[ws_id]

                            if is_phys and mob.possiblePhysWS[ws_id] then
                                mob.possiblePhysWS[ws_id] = nil
                                log.debug("Removed possible physical WS ID %d", ws_id)

                            elseif is_elem and mob.possibleEleWS[ws_id] then
                                mob.possibleEleWS[ws_id] = nil
                                log.debug("Removed possible elemental WS ID %d", ws_id)

                            else
                                log.debug("ID %d not found in remaining WS sets", ws_id)
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
	if not e or not e.newClaimId or not GetIsValidMob(e.ActorIndex) or MobManager.TrackedMobs[e.ActorIndex] then
        return
    end

    if PartyMembersByID[e.newClaimId] then
        initClaim(e.ActorIndex, e.ActorId, e.Name, GetTimeStamp())
    end
end

-- Lifted from HXUI by from Team HXUI (Tirem, Shuu, colorglut, RheaCloud)
MobManager.HandleZonePacket = function()
	MobManager.TrackedMobs = T{};
end

MobManager.HandleRestMessagePacket = function(e)
    if e then
        local actorIndex = e.ActorIndex
        if not actorIndex then
            log.wdebug("Missing ActorIndex in packet.")
            return
        end

        if not (GetIsMobByIndex(actorIndex) and GetIsValidMob(actorIndex)) then 
            return 
        end

        initClaim(actorIndex, e.ActorId, e.Name, GetTimeStamp())

        local currentMob = MobManager.TrackedMobs[actorIndex]
        if not currentMob or not currentMob.procStatus then return end

        local proc = e.Proc
        if e.Type == 'trigger' then
            parseTrigger(currentMob, proc)
        elseif e.Type == 'hint' then
            parseHint(currentMob, e)
        end
    end
end

MobManager.Tick = function()

    for k, v in pairs(MobManager.TrackedMobs) do
        if k ~= 'Target' then
            local ent = GetEntity(k)
            -- Remove if the entity no longer exists or is no longer a valid mob
            if (ent == nil or not GetIsValidMob(k)) then
                log.debug("Removing stale mob [%s] (Index: %d) from claimed targets", v.Name or 'Unknown', k)
                MobManager.TrackedMobs[k] = nil
                

            end
        end
    end

    local targetMgr = AshitaCore:GetMemoryManager():GetTarget();
    local index = targetMgr:GetTargetIndex(targetMgr:GetIsSubTargetActive());
    if (index == 0) then
        MobManager.TrackedMobs['Target'] = nil;
        return
    end
    local target = NotoriousMobsByIndex[index]
    if target and MobManager.TrackedMobs[index] == nil then
        if MobManager.TrackedMobs['Target'] == nil then
            initClaim('Target', target.Id, target.Name, GetTimeStamp())
        end
    else
        MobManager.TrackedMobs['Target'] = nil;
    end


end

return MobManager;