
local StaggerData = {}

StaggerData.elementByID = T{
    [1] = 'fire', [2] = 'earth', [3] = 'water', [4] = 'wind',
    [5] = 'ice', [6] = 'lightning', [7] = 'light', [8] = 'darkness'
}

StaggerData.daysByID = T{
    [1] = 'firesday', [2] = 'earthsday', [3] = 'watersday', [4] = 'windsday',
    [5] = 'iceday', [6] = 'lightningday', [7] = 'lightsday', [8] = 'darksday'
}

StaggerData.skillsByID = T{
    [1]  = 'hand-to-hand', [2]  = 'dagger', [3]  = 'sword', [4]  = 'great sword',
    [5]  = 'axe',          [6]  = 'great axe', [7]  = 'scythe', [8]  = 'polearm',
    [9]  = 'katana',       [10] = 'great katana', [11] = 'club', [12] = 'staff',
    [25] = 'archery',      [26] = 'marksmanship'
}

StaggerData.elementByName = T{}
for id, name in pairs(StaggerData.elementByID) do
    StaggerData.elementByName[name] = id
end

-- Yellow Stagger - Spells associated with the current day, the previous day, and the following day can trigger Yellow stagger. 
StaggerData.spellsByID = T{
    [21]  = { id = 21,  Name = "Holy",            element = 7, type = "White Magic" },
    [29]  = { id = 29,  Name = "Banish II",       element = 7, type = "White Magic" },
    [30]  = { id = 30,  Name = "Banish III",      element = 7, type = "White Magic" },
    [39]  = { id = 39,  Name = "Banishga II",     element = 7, type = "White Magic" },
    [112] = { id = 112, Name = "Flash",           element = 7, type = "White Magic" },
    [146] = { id = 146, Name = "Fire III",        element = 1, type = "Black Magic" },
    [147] = { id = 147, Name = "Fire IV",         element = 1, type = "Black Magic" },
    [151] = { id = 151, Name = "Blizzard III",    element = 5, type = "Black Magic" },
    [152] = { id = 152, Name = "Blizzard IV",     element = 5, type = "Black Magic" },
    [156] = { id = 156, Name = "Aero III",        element = 4, type = "Black Magic" },
    [157] = { id = 157, Name = "Aero IV",         element = 4, type = "Black Magic" },
    [161] = { id = 161, Name = "Stone III",       element = 2, type = "Black Magic" },
    [162] = { id = 162, Name = "Stone IV",        element = 2, type = "Black Magic" },
    [166] = { id = 166, Name = "Thunder III",     element = 6, type = "Black Magic" },
    [167] = { id = 167, Name = "Thunder IV",      element = 6, type = "Black Magic" },
    [171] = { id = 171, Name = "Water III",       element = 3, type = "Black Magic" },
    [172] = { id = 172, Name = "Water IV",        element = 3, type = "Black Magic" },
    [176] = { id = 176, Name = "Firaga III",      element = 1, type = "Black Magic" },
    [181] = { id = 181, Name = "Blizzaga III",    element = 5, type = "Black Magic" },
    [186] = { id = 186, Name = "Aeroga III",      element = 4, type = "Black Magic" },
    [191] = { id = 191, Name = "Stonega III",     element = 2, type = "Black Magic" },
    [196] = { id = 196, Name = "Thundaga III",    element = 6, type = "Black Magic" },
    [201] = { id = 201, Name = "Waterga III",     element = 3, type = "Black Magic" },
    [204] = { id = 204, Name = "Flare",           element = 1, type = "Black Magic" },
    [206] = { id = 206, Name = "Freeze",          element = 5, type = "Black Magic" },
    [208] = { id = 208, Name = "Tornado",         element = 4, type = "Black Magic" },
    [210] = { id = 210, Name = "Quake",           element = 2, type = "Black Magic" },
    [212] = { id = 212, Name = "Burst",           element = 6, type = "Black Magic" },
    [214] = { id = 214, Name = "Flood",           element = 3, type = "Black Magic" },
    [231] = { id = 231, Name = "Bio II",          element = 8, type = "Black Magic" },
    [245] = { id = 245, Name = "Drain",           element = 8, type = "Black Magic" },
    [247] = { id = 247, Name = "Aspir",           element = 8, type = "Black Magic" },
    [321] = { id = 321, Name = "Katon: Ni",       element = 1, type = "Ninjutsu" },
    [324] = { id = 324, Name = "Hyoton: Ni",      element = 5, type = "Ninjutsu" },
    [327] = { id = 327, Name = "Huton: Ni",       element = 4, type = "Ninjutsu" },
    [330] = { id = 330, Name = "Doton: Ni",       element = 2, type = "Ninjutsu" },
    [333] = { id = 333, Name = "Raiton: Ni",      element = 6, type = "Ninjutsu" },
    [336] = { id = 336, Name = "Suiton: Ni",      element = 3, type = "Ninjutsu" },
    [348] = { id = 348, Name = "Kurayami: Ni",    element = 8, type = "Ninjutsu" },
    [454] = { id = 454, Name = "Fire Threnody",   element = 3, type = "Song" },
    [455] = { id = 455, Name = "Ice Threnody",    element = 1, type = "Song" },
    [456] = { id = 456, Name = "Wind Threnody",   element = 5, type = "Song" },
    [457] = { id = 457, Name = "Earth Threnody",  element = 4, type = "Song" },
    [459] = { id = 459, Name = "Water Threnody",  element = 6, type = "Song" },
    [460] = { id = 460, Name = "Light Threnody",  element = 8, type = "Song" },
    [461] = { id = 461, Name = "Dark Threnody",   element = 7, type = "Song" },
    [515] = { id = 515, Name = "Maelstrom",       element = 3, type = "Blue Magic" },
    [531] = { id = 531, Name = "Ice Break",       element = 5, type = "Blue Magic" },
    [534] = { id = 534, Name = "Mysterious Light",element = 4, type = "Blue Magic" },
    [555] = { id = 555, Name = "Magnetite Cloud", element = 2, type = "Blue Magic" },
    [557] = { id = 557, Name = "Eyes On Me",      element = 8, type = "Blue Magic" },
    [565] = { id = 565, Name = "Radiant Breath",  element = 7, type = "Blue Magic" },
    [591] = { id = 591, Name = "Heat Breath",     element = 1, type = "Blue Magic" },
    [644] = { id = 644, Name = "Mind Blast",      element = 5, type = "Blue Magic" },
}

-- Red Stagger - caused by using specific elemental weapon skills
StaggerData.eleWSByID = T{
    [20]  = { id = 20,  Name = "Cyclone",          element = 4, skill = 2  },
    [22]  = { id = 22,  Name = "Energy Drain",     element = 8, skill = 2  },
    [34]  = { id = 34,  Name = "Red Lotus Blade",  element = 1, skill = 3  },
    [37]  = { id = 37,  Name = "Seraph Blade",     element = 7, skill = 3  },
    [51]  = { id = 51,  Name = "Freezebite",       element = 5, skill = 4  },
    [98]  = { id = 98,  Name = "Shadow of Death",  element = 8, skill = 7  },
    [114] = { id = 114, Name = "Raiden Thrust",    element = 6, skill = 8  },
    [133] = { id = 133, Name = "Blade: Ei",        element = 8, skill = 9  },
    [148] = { id = 148, Name = "Tachi: Jinpu",     element = 4, skill = 10 },
    [149] = { id = 149, Name = "Tachi: Koki",      element = 7, skill = 10 },
    [161] = { id = 161, Name = "Seraph Strike",    element = 7, skill = 11 },
    [178] = { id = 178, Name = "Earth Crusher",    element = 2, skill = 12 },
    [180] = { id = 180, Name = "Sunburst",         element = 7, skill = 12 },
}   

-- Blue Stagger - The in-game time of day (when the NM was claimed or force-spawned) determines which weapon type is eligible: 06:00 to 14:00 — Piercing weapon skills, 14:00 to 22:00 — Slashing weapon skills, 22:00 to 06:00 — Blunt weapon skills
StaggerData.physWSByID = T{
    [5]   = { id = 5,   Name = "Raging Fists",     skill = 1 },
    [6]   = { id = 6,   Name = "Spinning Attack",  skill = 1 },
    [7]   = { id = 7,   Name = "Howling Fist",     skill = 1 },
    [8]   = { id = 8,   Name = "Dragon Kick",      skill = 1 },
    [9]   = { id = 9,   Name = "Asuran Fists",     skill = 1 },
    [18]  = { id = 18,  Name = "Shadowstitch",     skill = 2 },
    [23]  = { id = 23,  Name = "Dancing Edge",     skill = 2 },
    [24]  = { id = 24,  Name = "Shark Bite",       skill = 2 },
    [25]  = { id = 25,  Name = "Evisceration",     skill = 2 },
    [40]  = { id = 40,  Name = "Vorpal Blade",     skill = 3 },
    [41]  = { id = 41,  Name = "Swift Blade",      skill = 3 },
    [42]  = { id = 42,  Name = "Savage Blade",     skill = 3 },
    [55]  = { id = 55,  Name = "Spinning Slash",   skill = 4 },
    [56]  = { id = 56,  Name = "Ground Strike",    skill = 4 },
    [71]  = { id = 71,  Name = "Mistral Axe",      skill = 5 },
    [72]  = { id = 72,  Name = "Decimation",       skill = 5 },
    [87]  = { id = 87,  Name = "Full Break",       skill = 6 },
    [88]  = { id = 88,  Name = "Steel Cyclone",    skill = 6 },
    [103] = { id = 103, Name = "Cross Reaper",     skill = 7 },
    [104] = { id = 104, Name = "Spiral Hell",      skill = 7 },
    [118] = { id = 118, Name = "Skewer",           skill = 8 },
    [119] = { id = 119, Name = "Wheeling Thrust",  skill = 8 },
    [120] = { id = 120, Name = "Impulse Drive",    skill = 8 },
    [135] = { id = 135, Name = "Blade: Ten",       skill = 9 },
    [136] = { id = 136, Name = "Blade: Ku",        skill = 9 },
    [151] = { id = 151, Name = "Tachi: Gekko",     skill = 10 },
    [152] = { id = 152, Name = "Tachi: Kasha",     skill = 10 },
    [165] = { id = 165, Name = "Skullbreaker",     skill = 11 },
    [166] = { id = 166, Name = "True Strike",      skill = 11 },
    [167] = { id = 167, Name = "Judgment",         skill = 11 },
    [168] = { id = 168, Name = "Hexa Strike",      skill = 11 },
    [169] = { id = 169, Name = "Black Halo",       skill = 11 },
    [176] = { id = 176, Name = "Heavy Swing",      skill = 12 },
    [181] = { id = 181, Name = "Shell Crusher",    skill = 12 },
    [182] = { id = 182, Name = "Full Swing",       skill = 12 },
    [183] = { id = 183, Name = "Spirit Taker",     skill = 12 },
    [184] = { id = 184, Name = "Retribution",      skill = 12 },
    [196] = { id = 196, Name = "Sidewinder",       skill = 25 },
    [197] = { id = 197, Name = "Blast Arrow",      skill = 25 },
    [198] = { id = 198, Name = "Arching Arrow",    skill = 25 },
    [199] = { id = 199, Name = "Empyreal Arrow",   skill = 25 },
    [212] = { id = 212, Name = "Slug Shot",        skill = 26 },
    [213] = { id = 213, Name = "Blast Shot",       skill = 26 },
    [214] = { id = 214, Name = "Heavy Shot",       skill = 26 },
    [215] = { id = 215, Name = "Detonator",        skill = 26 },
}

StaggerData.combatSkills = T{
    [1]  = { id = 1,  Name = "hand-to-hand", category = "blunt" },
    [2]  = { id = 2,  Name = "dagger",        category = "piercing" },
    [3]  = { id = 3,  Name = "sword",         category = "slashing" },
    [4]  = { id = 4,  Name = "great sword",   category = "slashing" },
    [5]  = { id = 5,  Name = "axe",           category = "slashing" },
    [6]  = { id = 6,  Name = "great axe",     category = "slashing" },
    [7]  = { id = 7,  Name = "scythe",        category = "slashing" },
    [8]  = { id = 8,  Name = "polearm",       category = "piercing" },
    [9]  = { id = 9,  Name = "katana",        category = "slashing" },
    [10] = { id = 10, Name = "great katana",  category = "slashing" },
    [11] = { id = 11, Name = "club",          category = "blunt" },
    [12] = { id = 12, Name = "staff",         category = "blunt" },
    [25] = { id = 25, Name = "archery",       category = "piercing" },
    [26] = { id = 26, Name = "marksmanship",  category = "piercing" },
}


for _, ws in pairs(StaggerData.physWSByID) do
    local skill_id = ws.skill
    local skill_data = StaggerData.combatSkills[skill_id]
    if skill_data then
        ws.category = skill_data.category
    end
end

StaggerData.physWSByCategory = T{}
StaggerData.physWSBySkill = T{}

for id, ws in pairs(StaggerData.physWSByID) do
    local category = ws.category
    if category then
        StaggerData.physWSByCategory[category] = StaggerData.physWSByCategory[category] or T{}
        StaggerData.physWSByCategory[category][id] = ws
    end

    local skill_id = ws.skill
    if skill_id then
        StaggerData.physWSBySkill[skill_id] = StaggerData.physWSBySkill[skill_id] or T{}
        StaggerData.physWSBySkill[skill_id][id] = ws
    end
    
end

StaggerData.spellsByElement = T{}

for id, spell in pairs(StaggerData.spellsByID) do
    local element_id = spell.element
    if element_id then
        StaggerData.spellsByElement[element_id] = StaggerData.spellsByElement[element_id] or T{}
        StaggerData.spellsByElement[element_id][id] = spell
    end
end

StaggerData.eleWSByElement = T{}

for id, ws in pairs(StaggerData.eleWSByID) do
    local element_id = ws.element
    if element_id then
        StaggerData.eleWSByElement[element_id] = StaggerData.eleWSByElement[element_id] or T{}
        StaggerData.eleWSByElement[element_id][id] = ws
    end
end

return StaggerData
