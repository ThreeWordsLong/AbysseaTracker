local chat = require('chat')
local serpent = require('logger_serpent')

local log = {}

local LEVELS = { DEBUG = 1, INFO = 2, WARNING = 3, ERROR = 4}
local COLORS = {
    [LEVELS.DEBUG]   = chat.success,
    [LEVELS.INFO]    = chat.message,
    [LEVELS.WARNING] = chat.warning,
    [LEVELS.ERROR]   = chat.critical
}
local LABELS = {
    [LEVELS.DEBUG]   = 'DEBUG',
    [LEVELS.INFO]    = 'INFO',
    [LEVELS.WARNING] = 'WARNING',
    [LEVELS.ERROR]   = 'ERROR'
}

local BODY_COLORS = {
    [LEVELS.DEBUG]   = function(s) return chat.color1(80, s) end,
    [LEVELS.INFO]    = chat.message,
    [LEVELS.WARNING] = function(s) return chat.color1(85, s) end,
    [LEVELS.ERROR]   = chat.error
}

local MAX_DEPTH = 5

local function key_color(depth, str)
    local colors = {2, 6, 69, 5, 68}
    return chat.color1(colors[(depth - 1) % #colors + 1], str)
end

local function value_color(val)
    local t = type(val)
    if t == 'string' then return chat.color1(69, val)    -- Yellow
    elseif t == 'number' then return chat.color1(6, tostring(val))                -- Cyan
    elseif t == 'boolean' then return chat.color1(5, tostring(val))               -- Magenta
    else return chat.color1(68, tostring(val))                                    -- Red/fallback
    end
end

local function formatter(tag, head, body, tail, level)
    -- Color keys inside the body
    local colored_body = body:gsub("([%w_]+)%s*=%s*", function(key)
        return key_color(level, key) .. " = "
    end)

    return head .. colored_body .. tail
end

local function stringify_table(val, depth)
    return '\n' .. serpent.block(val, {
        indent = '  ',
        sortkeys = true,
        comment = false,
        maxlevel = MAX_DEPTH,
        nocode = true,
        custom = formatter
    })
end

local function stringify_table_for_file(val)
    return '\n' .. serpent.block(val, {
        indent = '  ',
        sortkeys = true,
        comment = false,
        nocode = true
    })
end

local function color_by_type(val, depth)
    local t = type(val)
    if t == 'table' then
        return stringify_table(val, depth or 1)
    else
        return value_color(val)
    end
end

local function apply_colored_format(fmt, args, body_color)
    local out = {}
    local arg_index = 1
    local has_match = false

    for text, placeholder in fmt:gmatch("([^%%]*)()%%[sdq]") do
        has_match = true
        table.insert(out, body_color(text))
        table.insert(out, args[arg_index] or '')
        arg_index = arg_index + 1
    end

    if has_match then
        -- Add any remaining text after the last format
        local remainder = fmt:match(".*%%[sdq](.*)$")
        if remainder then
            table.insert(out, body_color(remainder))
        end
    else
        -- No format placeholders? Just color the whole message.
        table.insert(out, body_color(fmt))
    end

    return table.concat(out)
end


local function format_msg(level, ...)
    local nargs = select('#', ...)
    local args = {}
    for i = 1, nargs do
        args[i] = select(i, ...)
    end

    if nargs == 1 and type(args[1]) ~= "string" then
        args = { '%s', args[1] }
        nargs = 2
    end

    local fmt = args[1]
    table.remove(args, 1)
    nargs = nargs - 1

    for i = 1, nargs do
        if args[i] == nil then
            args[i] = chat.color1(67, 'nil')
        else
            args[i] = color_by_type(args[i])
        end
    end

    return apply_colored_format(fmt, args, BODY_COLORS[level])
end

local round = function(x, increment)
  increment = increment or 1
  x = x / increment
  return (x > 0 and math.floor(x + .5) or math.ceil(x - .5)) * increment
end


local _tostring = tostring

local tostring = function(...)
  local t = {}
  for i = 1, select('#', ...) do
    local x = select(i, ...)
    if type(x) == "number" then
      x = round(x, .01)
    end
    t[#t + 1] = _tostring(x)
  end
  return table.concat(t, " ")
end

local function stringify_userdata(val, depth, seen)
    depth = depth or 1
    seen = seen or setmetatable({}, { __mode = "k" })

    if val == nil then
        return ''
    end

    local t = type(val)
    if t ~= 'userdata' then
        if t == 'table' then
            return serpent.block(val, {
                indent = '  ',
                sortkeys = true,
                comment = false,
                nocode = true
            })
        else
            return tostring(val)
        end
    end

    if depth > MAX_DEPTH then
        return '<max depth reached>'
    end

    if seen[val] then
        return '<circular reference>'
    end
    seen[val] = true

    local mt = debug.getmetatable(val)
    if not mt then
        return tostring(val)  -- fallback if no metatable
    end

    -- Build a shadow table of metatable contents
    local out = {}
    for k, v in pairs(mt) do
        local key = tostring(k)
        if type(v) == 'userdata' then
            out[key] = stringify_userdata(v, depth + 1, seen)
        elseif type(v) == 'table' then
            out[key] = serpent.block(v, { indent = '  ', sortkeys = true, comment = false, nocode = true })
        else
            out[key] = tostring(v)
        end
    end

    return serpent.block(out, {
        indent = '  ',
        sortkeys = true,
        comment = false,
        nocode = true
    })
end


local function format_msg_for_file(...)
    local nargs = select('#', ...)
    local args = {}
    for i = 1, nargs do
        args[i] = select(i, ...)
    end

    if nargs == 1 and type(args[1]) ~= "string" then
        args = { '%s', args[1] }
        nargs = 2
    end

    local fmt = args[1]
    table.remove(args, 1)
    nargs = nargs - 1

    for i = 1, nargs do
        if args[i] == nil then
            args[i] = 'nil'
        elseif type(args[i]) == "table" then
            args[i] = stringify_table_for_file(args[i])
        elseif type(args[i]) == "userdata" then
            args[i] = stringify_userdata(args[i])
        else 
            args[i] = tostring(args[i])
        end
    end

    return string.format(fmt, table.unpack(args))
end


local function should_log(level)
    return (addon.log_level or 0) <= level
end

local function log_chat(level, ...)
    -- Support special WDEBUG mode
    local effective_level = level
    if level == 'WDEBUG' then
        effective_level = LEVELS.WARNING
        if not should_log(LEVELS.DEBUG) then return end
    elseif type(level) == 'string' then
        if not should_log(LEVELS.DEBUG) then return end
        effective_level = LEVELS.DEBUG
    else
        if not should_log(level) then return end
    end

    local msg = format_msg(effective_level, ...)

    -- Format output
    if level == 'WDEBUG' then
        print(chat.header(addon.name) ..
              chat.success('[DEBUG]') ..
              COLORS[LEVELS.WARNING](string.format('[%s] %s', LABELS[LEVELS.WARNING], msg)))
    elseif effective_level == LEVELS.INFO then
        print(chat.header(addon.name) .. COLORS[effective_level](msg))
    else
        print(chat.header(addon.name) ..
              COLORS[effective_level](string.format('[%s] %s', LABELS[effective_level], msg)))
    end
end


local d = os.date('*t')
local fname = ('%s_%.4u.%.2u.%.2u.%d%d%d.log'):format(addon.name, d.year, d.month, d.day, d.hour, d.min, d.sec)

local function log_file(...)
    local msg = format_msg_for_file(...)
    local info = debug.getinfo(2, "Sl")
    local lineinfo = info.short_src .. ":" .. info.currentline
    local log_dir = addon.path:append('\\logs\\')
    if not ashita.fs.exists(log_dir) then
        ashita.fs.create_dir(log_dir)
    end
    local path = ('%s/%s'):format(log_dir, fname)
    local f = io.open(path, 'a')
    if f then
        local ts = os.date('[%H:%M:%S]')
        f:write(ts ..' '..lineinfo .. ' > ' .. msg .. '\n')
        f:close()
    end
end

function log.help(commands)
    commands = commands or addon.commands or {}
    if not next(commands) then
        log.info("No commands available for %s.", addon.name)
        return
    end

    local alias = (addon.aliases and addon.aliases[1]) or ("/" .. addon.name)

    print(
        chat.header(addon.name) .. 
        chat.message("Usage: ") ..
        chat.success((string.format('%s', alias)) ..
        chat.color1(71, " [command]"))
    )
    log.info("Available commands:")

    -- Sort keys alphabetically
    local keys = {}
    for k in pairs(commands) do table.insert(keys, tostring(k)) end
    table.sort(keys)

    -- Print each command with its description
    for _, cmd in ipairs(keys) do
        local desc = commands[cmd] or ""
        local colored_cmd = chat.color1(71, cmd)
        local colored_desc = chat.message(desc)
        print(chat.header(addon.name) .. string.format("  %s: %s", colored_cmd, colored_desc))

    end
end

-- Attach log levels
log.debug   = function(...) log_chat(LEVELS.DEBUG, ...) end
log.info    = function(...) log_chat(LEVELS.INFO, ...) end
log.warning = function(...) log_chat(LEVELS.WARNING, ...) end
log.error   = function(...) log_chat(LEVELS.ERROR, ...) end
log.wdebug  = function(...) log_chat('WDEBUG', ...) end
log.file    = log_file

return log
