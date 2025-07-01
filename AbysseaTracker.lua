--[[
* PacketInspector - FFXI Ashita v4 Addon
* Author: Knautz
* License: GPLv3
* Description:  Helps players track and stagger triggers for Abyssea NMs.
]]

addon.name    = 'AbysseaTracker';
addon.author  = 'Knautz';
addon.version = '1.0';
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
    time = 0,
    running = false,
}

addon.settings = {
        hide = false,
}

addon.log_level = 2 -- Default log level (1 = DEBUG, 2 = INFO, 3 = WARNING, 4 = ERROR)

require('helpers')
local pm = require('PacketManager')
local log = require('logger')
local mm = require('MobManager');
local UI = require('UIManager');


--[[
* event: load
* desc : Event called when the addon is being loaded.
--]]
ashita.events.register('load', 'load_'..addon.name:lower(), function ()
    addon.state.time = ashita.memory.find('FFXiMain.dll', 0, 'B0015EC390518B4C24088D4424005068', 0, 0);
    if (addon.state.time == 0) then
        log.warning('Vanatime signature scan failed.');
    end
    addon.state.running = pm.Init();
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
        log.info('Tracking is now: %s', addon.state.running and "enabled" or "disabled")
        return
    elseif (not cmd or cmd == 'help') then
        log.help()
        return
    elseif cmd == 'debug' then
        addon.log_level = addon.log_level == 1 and 2 or 1 -- Toggle between DEBUG (1) and INFO (2)
        log.info("Debug logging is now %s.", addon.log_level == 1 and "enabled" or "disabled")
        return
    elseif cmd == 'test' then
        log.debug("Current Tracked Mobs:")
        for k, v in pairs(mm.TrackedMobs) do
            log.debug("Mob %s (Index: %s)", v.Name, v.Id)
        end
        log.debug("Printing Notorious Mobs By ID: %s", NotoriousMobsByID)
        log.debug("Printing Abyssea Proc Messages: %s", AbysseaProcMessages)
        log.debug("Printing Party Members By ID: %s", PartyMembersByID)
    else
        log.info("Unknown command: %s", cmd)
        log.help()
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
    UI.drawProcGUI()
    mm.Tick();
end);

ashita.events.register('packet_in', 'packet_in_at_cb', function (e)
    if (e.id == 0x00A) then
        if addon.state.running ~= pm.HandleZonePacket(e) then
            mm.HandleZonePacket()
            addon.state.running = not addon.state.running
            log.info('Tracking is now: %s', addon.state.running and "enabled" or "disabled")
        end
    elseif addon.state.running then
        if (e.id == 0x0DD) then
            pm.HandlePartyPacket();
        elseif (e.id == 0x28) then
            local actionPacket = pm.ParseActionPacket(e);
            if actionPacket then
                mm.HandleActionPacket(actionPacket);
            end
        elseif (e.id == 0x0E) then
            local mobUpdatePacket = pm.ParseMobUpdatePacket(e);
            mm.HandleMobUpdatePacket(mobUpdatePacket);
        elseif (e.id == 0x2A) then
            local msgPacket = pm.ParseRestMessagePacket(e)
            mm.HandleRestMessagePacket(msgPacket);
        elseif (e.id == 0x00A) then
            pm.HandleZonePacket(e);
        end
    end
end);



