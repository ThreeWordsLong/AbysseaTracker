local log = require('logger')
local imgui = require('imgui');
local pm = require('PacketManager')
local mm = require('MobManager');
local sd = require('StaggerTables');
local UI = T{}

local function capitalizeWords(str)
    return str:gsub("(%a)([%w%-]*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

local colors = {
    yellow = {1.0, 1.0, 0.0, 1.0},
    blue   = {0.3, 0.6, 1.0, 1.0},
    red    = {1.0, 0.4, 0.4, 1.0},
    gray = {0.4, 0.4, 0.4, 1.0},
    black = {0.0, 0.0, 0.0, 1.0},
    tan = {0.80, 0.65, 0.52, 1.0},
    green = {0.6, 1.0, 0.6, 1.0},
    lightBlue = {0.4, 0.8, 1.0, 1.0}, 
    pink = {1.0, 0.7, 1.0, 1.0},
    offWhite = {1.0, 1.0, 0.8, 1.0},
    purple = {0.6, 0.1, 0.6, 1.0},
    darkGray = {0.2, 0.2, 0.2, 1.0},
}

local element_color_map = {
    fire = colors.red,
    earth = colors.tan, -- Tan
    water = colors.blue,
    wind = colors.green,
    ice = colors.lightBlue,
    lightning = colors.pink,
    light = colors.offWhite,
    darkness = colors.purple,
}


local spellTypeColors = {
    ['Black Magic'] = colors.purple,
    ['White Magic'] = colors.offWhite,
    ['Ninjutsu']    = colors.green,
    ['Song']        = colors.lightBlue,
    ['Blue Magic']  = colors.blue,
}

local skillCategoryColors = {
    slashing = colors.red,
    blunt    = colors.tan,
    piercing = colors.lightBlue,
}




local function ColoredHeader(color, label)
    imgui.PushStyleColor(ImGuiCol_Header, color)
    if color == colors.yellow then
        imgui.PushStyleColor(ImGuiCol_Text, colors.gray)
    end
    local open = imgui.CollapsingHeader(label, imgui.TreeNodeFlags_DefaultOpen)
    imgui.PopStyleColor()
    return open
end


local function resolveHintName(hint, procType)
    if not hint then
        return 'No Hint'
    elseif type(hint) == 'string' then
        return hint
    elseif type(hint) == 'number' then
        local mapped = 'Unknown Hint'
        if procType == 'yellow' or procType == 'red' then
            mapped = sd.elementByID[hint] or 'Unknown Element'
        elseif procType == 'blue' then
            mapped = sd.skillsByID[hint] or 'Unknown Skill'
        end
        return capitalizeWords(mapped)
    end
    return 'Unhandled Hint Type'
end
local function drawRedProcs(mob)
    local hintLabel = resolveHintName(mob.procStatus.red.hint, 'red')
    if not ColoredHeader(colors.red, 'Red Procs: ' .. hintLabel) then return end


    local grouped = T{}
    for _, ws in pairs(mob.possibleEleWS or T{}) do
        if ws and ws.skill and ws.element and ws.Name then
            local skillEntry = sd.combatSkills[ws.skill]
            local wName = skillEntry and skillEntry.Name or 'Unknown'
            local eName = sd.elementByID[ws.element] or 'Unknown'
            grouped[wName] = grouped[wName] or T{}
            grouped[wName][eName] = grouped[wName][eName] or T{}
            table.insert(grouped[wName][eName], ws)
        end
    end

    if imgui.BeginTable("RedProcsTable", 3) then
        local sortedSkills = T{}
        for skill in pairs(grouped) do table.insert(sortedSkills, skill) end
        table.sort(sortedSkills, function(a, b) return a < b end)

        for _, skillName in pairs(sortedSkills) do
            imgui.TableNextColumn()
            imgui.TextColored({1.0, 0.8, 0.6, 1.0}, capitalizeWords(skillName))
            imgui.Indent()

            local elements = grouped[skillName]
            local sortedElements = T{}
            for e in pairs(elements) do table.insert(sortedElements, e) end
            table.sort(sortedElements, function(a, b) return a < b end)

            for _, eName in pairs(sortedElements) do
                local list = elements[eName]
                table.sort(list, function(a, b)
                    return (a and b and a.id and b.id and a.id < b.id) or false
                end)
                local elKey = type(eName) == 'string' and eName:lower() or tostring(eName)
                local elColor = element_color_map[elKey] or {1.0, 1.0, 1.0, 1.0}
                for _, ws in pairs(list) do
                    imgui.TextColored(elColor, ws.Name or "Unknown WS")
                end
            end

            imgui.Unindent()
        end

        imgui.EndTable()
    end
end

local function drawBlueProcs(mob)
    local hintLabel = resolveHintName(mob.procStatus.blue.hint, 'blue')
    if not ColoredHeader(colors.blue, 'Blue Procs: ' .. hintLabel) then return end


    -- Group by skill name only
    local grouped = T{}
    for _, ws in pairs(mob.possiblePhysWS or T{}) do
        local skill = sd.skillsByID[ws.skill] or 'Unknown'
        grouped[skill] = grouped[skill] or T{}
        table.insert(grouped[skill], ws)
    end

    -- Sort keys
    local sortedSkills = T{}
    for skillName in pairs(grouped) do table.insert(sortedSkills, skillName) end
    table.sort(sortedSkills, function(a, b) return a < b end)

    -- Render in 3-column ImGui table
    if imgui.BeginTable("BlueProcsTable", 3) then
        for _, skillName in pairs(sortedSkills) do
            imgui.TableNextColumn()
            imgui.TextColored({1.0, 0.8, 0.6, 1.0}, capitalizeWords(skillName))
            imgui.Indent()

            local entries = grouped[skillName]
            table.sort(entries, function(a, b)
                return (a and b and a.id and b.id and a.id < b.id) or false
            end)

            for _, ws in pairs(entries) do
                imgui.Text(ws.Name or "Unknown WS")
            end

            imgui.Unindent()
        end
        imgui.EndTable()
    end
end

local function drawYellowProcs(mob)
    local hintLabel = resolveHintName(mob.procStatus.yellow.hint, 'yellow')
    if not ColoredHeader(colors.yellow, 'Yellow Procs: ' .. hintLabel) then return end

    local grouped = T{}
    for _, spell in pairs(mob.possibleSpells or T{}) do
        grouped[spell.type] = grouped[spell.type] or T{}
        local element = sd.elementByID[spell.element] or 'Unknown'
        grouped[spell.type][element] = grouped[spell.type][element] or T{}
        table.insert(grouped[spell.type][element], spell)
    end

    if imgui.BeginTable("YellowProcsTable", 3) then
        local sortedTypes = T{}
        for t in pairs(grouped) do table.insert(sortedTypes, t) end
        table.sort(sortedTypes, function(a, b) return a < b end)

        for _, spellType in pairs(sortedTypes) do
            imgui.TableNextColumn()
            local color = spellTypeColors[spellType] or {1.0, 1.0, 1.0, 1.0}
            imgui.TextColored(color, capitalizeWords(spellType))
            imgui.Indent()

            local elements = grouped[spellType]
            local sortedElements = T{}
            for el in pairs(elements) do table.insert(sortedElements, el) end
            table.sort(sortedElements, function(a, b) return a < b end)

            for _, eName in pairs(sortedElements) do
                local list = elements[eName]
                table.sort(list, function(a, b)
                    return (a and b and a.id and b.id and a.id < b.id) or false
                end)
                local elKey = type(eName) == 'string' and eName:lower() or tostring(eName)
                local elColor = element_color_map[elKey] or {1.0, 1.0, 1.0, 1.0}
                for _, spell in pairs(list) do
                    imgui.TextColored(elColor, spell.Name or "Unknown Spell")
                end
            end

            imgui.Unindent()
        end

        imgui.EndTable()
    end
end

local function renderMobProcUI(mob)
    imgui.Separator()
    
    imgui.TextColored({1.0, 1.0, 0.0, 1.0}, "Status: " .. (mob.ts and "Claimed" or "Unclaimed"))

    local pulled = mob.ts
    local now = GetTimeStamp()
    local displayTS = pulled or now
    local pulledLabel = string.format('%02d:%02d', displayTS.hour, displayTS.minute)
    local dayIndex = displayTS.DayIndex or 1
    local dayElement = sd.daysByID[dayIndex] or 'Unknown'
    local pulledPrefix = pulled and "" or " (Unclaimed)"

    imgui.Text("Timestamp: ")
    imgui.SameLine()

    local dayColor = element_color_map[sd.elementByID[dayIndex]] or {1.0, 1.0, 1.0, 1.0}
    imgui.TextColored(dayColor, capitalizeWords(dayElement))
    imgui.SameLine()

    imgui.Text(string.format(" %s%s", pulledLabel, pulledPrefix))

    -- Element triplet: -1, 0, +1
    imgui.Text("Spells: ")
    imgui.SameLine()

    for i, offset in ipairs({0, 1, 2}) do
        local idx = ((dayIndex + offset - 1) % 8) + 1
        local el = sd.elementByID[idx] or 'Unknown'
        local elKey = type(el) == 'string' and el:lower() or tostring(el)
        local elColor = element_color_map[elKey] or {1.0, 1.0, 1.0, 1.0}

        imgui.TextColored(elColor, capitalizeWords(el))
        if i < 3 then
            imgui.SameLine()
            imgui.Text("-")
            imgui.SameLine()
        end
    end

    -- Skill categories
    local categoryMap = {}
    for _, ws in pairs(mob.possiblePhysWS or {}) do
        local skillEntry = sd.combatSkills[ws.skill]
        if skillEntry and skillEntry.category then
            categoryMap[skillEntry.category] = categoryMap[skillEntry.category] or {}

            -- Check for duplicate
            local exists = false
            local skillName = capitalizeWords(skillEntry.Name)
            for _, name in ipairs(categoryMap[skillEntry.category]) do
                if name == skillName then
                    exists = true
                    break
                end
            end

            if not exists then
                table.insert(categoryMap[skillEntry.category], skillName)
            end
        end
    end

local lines = {}
for category, skills in pairs(categoryMap) do
    table.sort(skills)
    local label = capitalizeWords(category)
    table.insert(lines, { label = label, skills = table.concat(skills, ", "), category = category })
end

if #lines > 0 then
    imgui.Text("Weapon Skill Category: ")
    imgui.SameLine()
    for i, line in ipairs(lines) do
        local color = skillCategoryColors[line.category] or colors.gray
        imgui.PushTextWrapPos()
        imgui.TextColored(color, line.label)
        imgui.PopTextWrapPos()
        imgui.TextWrapped(string.format(" (%s)", line.skills))
        if i < #lines then
            imgui.SameLine()
            imgui.Text("; ")
            imgui.SameLine()
        end
    end
else
    imgui.Text("Weapon Skill Category: None")
end

    imgui.Separator()

    -- Proc sections
    drawYellowProcs(mob)
    drawBlueProcs(mob)
    drawRedProcs(mob)
end


function UI.drawProcGUI()
    if next(mm.TrackedMobs) == nil then return end
    if imgui.Begin('Abyssea Tracker##ProcGui', true) then
        if imgui.BeginTabBar('NM Tracker Tabs') then
            for index, mob in pairs(mm.TrackedMobs) do
                local label = string.format('%s##MobTab%s', mob.Name or 'Mob', index)
                if imgui.BeginTabItem(label) then
                    renderMobProcUI(mob)
                    imgui.EndTabItem()
                end
            end
            imgui.EndTabBar()
        end
        imgui.End()
    end
end

return UI
