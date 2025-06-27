--[[
* PacketInspector - FFXI Ashita v4 Addon
* Author: Knautz
* License: GPLv3
* Description:  Helps players track and stagger triggers for Abyssea NMs.
]]

addon.name    = 'AbysseaTracker';
addon.author  = 'Knautz';
addon.version = '0.5';
addon.desc    = 'Helps players track and stagger triggers for Abyssea NMs';
addon.link    = 'https://ashitaxi.com/';

require('common')

addon.aliases = T{'/at', '/abysseatracker'}
addon.commands = T{
    ['Help'] = 'Prints out available commands.',
    ['Debug'] = 'Toggles debug logging.',
}
-- Initial addon state
addon.state = {
    settings = {
        debug = true, 
        hide = false,
    },
    verbose = 1,
    time = 0,
    running = false,
}

gSettings = addon.state.settings
gSettings.verbose = addon.state.settings.debug and 2 or 1

require('helpers')

local logger = require('logger')
local ilog, dlog = logger.info, logger.debug


local imgui = require('imgui');
local mm = require('MobManager');
local stagger_data = require('StaggerTables');

local function print_help()
    ilog("Usage: %s [command]", addon.aliases[1])
    ilog("Available commands:")
    for k,v in pairs(addon.commands) do
        ilog("  %s - %s", k, v)
    end
end

local function capitalize_words(str)
    return str:gsub("(%a)([%w%-]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local function resolve_hint_name(hint, procType)

    if not hint then
        return 'No Hint'
    elseif type(hint) == 'string' then
        return hint
    elseif type(hint) == 'number' then
        local mapped = 'Unknown Hint'
        if procType == 'yellow' or procType == 'red' then
            mapped = stagger_data.element_by_id[hint] or 'Unknown Element'
        elseif procType == 'blue' then
            mapped = stagger_data.skills_by_id[hint] or 'Unknown Skill'
        end
        return capitalize_words(mapped)
    end
    return 'Unhandled Hint Type'
end


local function drawProcGUI()

    -- First, check if there are any valid NMs
    local hasNM = false
    for _, mob in pairs(mm.TrackedMobs) do
        if mob.isNM then
            hasNM = true
            break
        end
    end

    if not hasNM then
        return -- Skip drawing entirely
    end

    if imgui.Begin('Abyssea Tracker##ProcGui', true) then

        for index, mob in pairs(mm.TrackedMobs) do
            if mob.isNM then
                imgui.Separator()
                imgui.TextColored({1.0, 1.0, 0.0, 1.0}, mob.Name or ('Mob ' .. tostring(index)))
                imgui.Separator()
                imgui.Columns(3, nil, true)

                for _, procType in ipairs({ 'yellow', 'blue', 'red' }) do
                    local proc = mob.proc_status[procType]
                    local color = proc.triggered and {0.5, 1.0, 0.5, 1.0} or {1.0, 0.5, 0.5, 1.0}
                    local label = nil
                    label = string.format('%s (%s)', procType:upper(), resolve_hint_name(proc.hint, procType))

                    imgui.TextColored(color, label)
                    imgui.Indent()

                    local list = procType == 'yellow' and mob.possible_spells
                            or procType == 'blue' and mob.possible_physical_ws
                            or procType == 'red' and mob.possible_elemental_ws

                    local grouped = T{}

                    if list ~= nil then

                        if procType == 'yellow' then
                            for _, spell in pairs(list) do
                                local element_name = stagger_data.element_by_id[spell.element] or 'Unknown'
                                local type_group = grouped[spell.type] or T{}
                                local element_group = type_group[element_name] or T{}
                                table.insert(element_group, spell)
                                type_group[element_name] = element_group
                                grouped[spell.type] = type_group
                            end

                            for spell_type, elements in pairs(grouped) do
                                imgui.TextColored({0.7, 0.9, 1.0, 1.0}, spell_type)
                                imgui.Indent()
                                for element_name, spells in pairs(elements) do
                                    table.sort(spells, function(a, b) return a.id < b.id end)
                                    imgui.TextColored({0.5, 1.0, 0.7, 1.0}, capitalize_words(element_name))
                                    imgui.Indent()
                                    for _, spell in ipairs(spells) do
                                        if spell and spell.Name then
                                            imgui.Text(spell.Name)
                                        else
                                            imgui.Text("Unknown Spell")
                                        end
                                    end
                                    imgui.Unindent()
                                end
                                imgui.Unindent()
                            end

                        elseif procType == 'blue' then
                            for _, ws in pairs(list) do
                                local skill_name = stagger_data.skills_by_id[ws.skill] or 'Unknown'
                                local groupKey = skill_name
                                grouped[groupKey] = grouped[groupKey] or T{}
                                table.insert(grouped[groupKey], ws)
                            end

                            for weapon, skills in pairs(grouped) do
                                table.sort(skills, function(a, b) return a.id < b.id end)
                                imgui.TextColored({0.5, 1.0, 0.8, 1.0}, capitalize_words(weapon))
                                imgui.Indent()
                                for _, ws in pairs(skills) do
                                    if ws and ws.Name then
                                        imgui.Text(ws.Name)
                                    else
                                        imgui.Text("Unknown WS")
                                    end
                                end
                                imgui.Unindent()
                            end

                        elseif procType == 'red' then
                            for _, ws in pairs(list) do
                                local weapon_name = stagger_data.skills_by_id[ws.skill] or 'Unknown'
                                local element_name = stagger_data.element_by_id[ws.element] or 'Unknown'

                                grouped[weapon_name] = grouped[weapon_name] or T{}
                                grouped[weapon_name][element_name] = grouped[weapon_name][element_name] or T{}
                                table.insert(grouped[weapon_name][element_name], ws)
                            end

                            for weapon_name, elements in pairs(grouped) do
                                imgui.TextColored({1.0, 0.8, 0.6, 1.0}, capitalize_words(weapon_name))
                                imgui.Indent()
                                for element_name, ws_group in pairs(elements) do
                                    table.sort(ws_group, function(a, b) return a.id < b.id end)
                                    imgui.TextColored({1.0, 0.6, 0.6, 1.0}, capitalize_words(element_name))
                                    imgui.Indent()
                                    for _, ws in pairs(ws_group) do
                                        if ws and ws.Name then
                                            imgui.Text(ws.Name)
                                        else
                                            imgui.Text("Unknown WS")
                                        end
                                    end
                                    imgui.Unindent()
                                end
                                imgui.Unindent()
                            end
                        end
                    end

                    imgui.Unindent()
                    imgui.NextColumn()
                end

                imgui.Columns(1)
            end
        end
    end
    imgui.End()


end

--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_'..addon.name:lower(), function ()
    addon.state.time = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0);
    if (addon.state.time == 0) then
        ilog('Vanatime signature scan failed.');
    end
    addon.state.running = mm.Init();
end);


--[[
* event: command
* desc : Event called when the addon is processing a command.
--]]
ashita.events.register('command', 'command_' .. addon.name:lower(), function (e)
    local args = e.command:args()
    
    if (#args == 0 or not addon.aliases:contains(args[1]:lower())) then
        return
    end

    local cmd = args[2] and args[2]:lower()
    if not cmd then
        addon.state.running = not addon.state.running
        ilog('Tracking is now: %s', addon.state.running and "enabled" or "disabled")
        return
    elseif (not cmd or cmd == 'help') then
        print_help()
        return
    elseif cmd == 'debug' then
        addon.state.settings.debug = not addon.state.settings.debug
        ilog("Debug logging is now: %s", addon.state.settings.debug and "enabled" or "disabled")
        return
    else
        log("Unknown command: %s", cmd)
        print_help()
        return
    end
end)


--[[
* event: d3d_present
* desc : Event called when the Direct3D device is presenting a scene.
--]]
ashita.events.register('d3d_present', 'd3d_'..addon.name:lower(), function ()
    if not addon.state.running then
        return;
    end
    mm.Tick();
    drawProcGUI()
end);

ashita.events.register('packet_out', 'packet_out_at_cb', function (e)
    if (e.id == 0x0C) then
        if addon.state.running ~= mm.HandleZonePacket(e) then
            addon.state.running = not addon.state.running
            ilog('Tracking is now: %s', addon.state.running and "enabled" or "disabled")
        end
    end

end);



ashita.events.register('packet_in', 'packet_in_at_cb', function (e)
    if not addon.state.running then
        return;
    elseif (e.id == 0x28) then
		local actionPacket = ParseActionPacket(e);
		if actionPacket then
            mm.HandleActionPacket(actionPacket);
		end
	elseif (e.id == 0x0E) then
		local mobUpdatePacket = ParseMobUpdatePacket(e);
        mm.HandleMobUpdatePacket(mobUpdatePacket);
    elseif (e.id == 0x29) then
        local msgPacket = ParseBattleMessagePacket(e)
        if msgPacket and mm.HandleBattleMessagePacket(msgPacket) == true then
            e.blocked = true
        end
	elseif (e.id == 0x2A) then
        local msgPacket = ParseRestMessagePacket(e)
        mm.HandleRestMessagePacket(msgPacket);
    end
end);



