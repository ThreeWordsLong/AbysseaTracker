local ok, inspect_mod = pcall(require, 'inspect')
local inspect = ok and inspect_mod or function(t)
    return tostring(t)
end

local logger = {}

local function strip_metatables(t, seen)
    if type(t) ~= "table" then return t end
    if seen and seen[t] then return seen[t] end

    seen = seen or {}
    local copy = {}
    seen[t] = copy

    for k, v in pairs(t) do
        copy[strip_metatables(k, seen)] = strip_metatables(v, seen)
    end
    return copy
end

local function safe_format(fmt, ...)
    local args = {...}
    for i = 1, select('#', ...) do
        local val = args[i]
        local val_type = type(val)
        if val_type == "table" or val_type == "userdata" then
            args[i] = '\n'..inspect(strip_metatables(val))
        elseif type(val) ~= "string" then
            args[i] = tostring(val)
        end
    end
    return string.format(fmt, table.unpack(args))
end

local function make_level(level, color, required_verbosity)
    return function(fmt, ...)
        if (gSettings and gSettings.verbose or 0) < required_verbosity then return end

        local tag = addon.name or 'Addon'
        local color_code = string.char(0x1E, tonumber(color))  -- \30\{color}
        local reset_code = string.char(0x1E, 0x01)             -- \30\01

        local prefix = string.format('[%s%s - %s%s] ', color_code, tag, level:upper(), reset_code)

        local message
        local arg_count = select('#', ...)
        if arg_count == 0 then
            -- Still wrap through safe_format to handle tables or placeholders
            message = safe_format("%s", fmt)
        else
            message = safe_format(fmt, ...)
        end

        print(prefix .. message)
    end
end

-- Verbosity scale: 0=warn/error/info, 1=debug
logger.error = make_level('error', '4', 0)
logger.warn  = make_level('warn',  '3', 0)
logger.info  = make_level('info',  '5', 1)
logger.debug = make_level('debug', '2', 2)

return logger

