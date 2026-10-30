-- tests/test_settings_pin.lua
--
-- THE SET OF SETTINGS, PINNED (item 020, the 2026-10-24 settings-layout pass).
--
-- The layout pass moves, regroups and relabels rows: a row may change its tab
-- (`group`), its subsection (`subgroup`), its page (`page`), its label and its
-- tooltip. It may NOT change what is stored or what it is set to out of the box:
-- the path, the type, the shipped default, the slider range, the value set behind
-- a dropdown, and whether the row is hidden, session-only or inverted. Those are
-- the owner's rule for the pass ("do not change any settings, just change the
-- layout"), and this suite is that rule as a test.
--
-- The list below was taken from NS.Schema BEFORE the first layout edit, one line
-- per row, sorted, so a moved row compares equal and a dropped, added, re-keyed
-- or re-defaulted row does not. It deliberately leaves out everything the pass
-- is allowed to change: page, group, subgroup, startsLine, label and desc.
--
-- red under: renaming a stored path, changing a default or a range, dropping or
-- adding a row, or turning a visible row hidden while moving it.

local T = _G.MULTIMETERS_TEST
local NS = T.NS
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local function ser(v)
    if type(v) == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = tostring(k) end
        table.sort(keys)
        local parts = {}
        for _, k in ipairs(keys) do parts[#parts + 1] = k .. "=" .. ser(v[k]) end
        return "{" .. table.concat(parts, ",") .. "}"
    end
    return tostring(v)
end

local function valueKeys(values)
    if type(values) == "function" then values = values() end
    if type(values) ~= "table" then return "-" end
    local keys = {}
    for k in pairs(values) do keys[#keys + 1] = tostring(k) end
    table.sort(keys)
    return table.concat(keys, ",")
end

--- One row as the fields the layout pass must leave alone.
local function canon(row)
    return table.concat({
        tostring(row.path), tostring(row.type), ser(row.default), tostring(row.min), tostring(row.max),
        tostring(row.step), valueKeys(row.values), tostring(row.sessionOnly == true),
        tostring(row.hidden == true), tostring(row.invert == true),
    }, "|")
end

-- The media rows' value keys are the LibSharedMedia keys the harness holds, which the vendored
-- LibKa0s registers: they move at a re-vendor (v1.80.0 added the skin faces, the eight generated
-- bars and the Ka0s Glass border), never with a setting.
-- The eight skin.* rows (settings/Schema_Skin.lua, the 2026-10-29 skinning rollout's MM-01, and
-- skin.outline from the 2026-10-30 skin fonts run's MM-01, LibKa0s v1.82.0) are
-- new settings, added after the pin was taken; the skin row's value keys are the skins the vendored
-- LibKa0s-Skin-1.0 registers, so they move at a re-vendor too.
-- The ten "Use the skin's ..." companions (skinning-§6, the rollout's MM-03) are new settings too,
-- each pinned under the picker it governs: eight beside the HUD media pickers and the Quick style
-- meta pair, each default on (DECISIONS X3).
-- path|type|default|min|max|step|value keys|sessionOnly|hidden|invert
local PIN = {
    "data.mergePets|bool|false|nil|nil|nil|-|false|false|false",
    "data.throttle|number|0.25|0.05|2|0.05|-|false|false|false",
    "enabled|bool|true|nil|nil|nil|-|false|false|false",
    "export.channel|string|SELF|nil|nil|nil|GUILD,INSTANCE_CHAT,PARTY,RAID,SAY,SELF,TARGET,WHISPER|false|true|false",
    "export.lines|number|5|1|40|1|-|false|true|false",
    "export.metric|string|DamageDone|nil|nil|nil|-|false|true|false",
    "export.whisperTo|string||nil|nil|nil|-|false|true|false",
    "global.minimap.shown|bool|true|nil|nil|nil|-|false|false|false",
    "master.alpha|number|1|0|1|0.05|-|false|false|false",
    "master.locked|bool|false|nil|nil|nil|-|true|false|false",
    "master.scale|number|1|0.5|2|0.05|-|false|false|false",
    "master.visibility|string|always|nil|nil|nil|always,inCombat,never,outOfCombat|false|false|false",
    "statColors.Absorbs|color|{a=1,b=0.8,g=0.65,r=0.45}|nil|nil|nil|-|false|false|false",
    "statColors.AvoidableDamageTaken|color|{a=1,b=0.15,g=0.45,r=0.8}|nil|nil|nil|-|false|false|false",
    "statColors.DamageDone|color|{a=1,b=0.25,g=0.25,r=0.78}|nil|nil|nil|-|false|false|false",
    "statColors.DamageTaken|color|{a=1,b=0.75,g=0.78,r=0.25}|nil|nil|nil|-|false|false|false",
    "statColors.Deaths|color|{a=1,b=0.68,g=0.25,r=0.92}|nil|nil|nil|-|false|false|false",
    "statColors.Dispels|color|{a=1,b=0.8,g=0.45,r=0.55}|nil|nil|nil|-|false|false|false",
    "statColors.HealingDone|color|{a=1,b=0.35,g=0.7,r=0.25}|nil|nil|nil|-|false|false|false",
    "statColors.Interrupts|color|{a=1,b=0.2,g=0.65,r=0.85}|nil|nil|nil|-|false|false|false",
    "skin.font|string||nil|nil|nil|-|false|false|false",
    "skin.ignoreFonts|bool|false|nil|nil|nil|-|false|false|false",
    "skin.ignorePanel|bool|true|nil|nil|nil|-|false|false|false",
    "skin.outline|string|all|nil|nil|nil|all,hud,off|false|false|false",
    "skin.pickerSeen|bool|false|nil|nil|nil|-|false|false|false",
    "skin.skin|string|ka0s|nil|nil|nil|azeroth,contrast,ember,forever,glass,ka0s,midnight,obsidian,wow|false|false|false",
    "skin.source|string|ka0s|nil|nil|nil|eui,ka0s|false|false|false",
    "skin.texture|string||nil|nil|nil|-|false|false|false",
    "state.debugConsole|bool|false|nil|nil|nil|-|true|false|false",
    "state.testMode|bool|false|nil|nil|nil|-|true|false|false",
    "window.barTexture|string|Blizzard Raid Bar|nil|nil|nil|Ka0s Classic,Ka0s Default,Ka0s Forge,Ka0s Glass Bar,Ka0s Gradient,Ka0s Matte,Ka0s Overline 1,Ka0s Overline 2,Ka0s Overline 4,Ka0s Parchment,Ka0s Satin,Ka0s Solid,Ka0s Underline 1,Ka0s Underline 2,Ka0s Underline 4|false|false|false",
    "window.barTextureFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.bars.alpha|number|1|0|1|0.01|-|false|false|false",
    "window.bars.animate|bool|true|nil|nil|nil|-|false|false|false",
    "window.bars.bgAlpha|number|0.1|0|1|0.01|-|false|false|false",
    "window.bars.bgColorMode|string|class|nil|nil|nil|class,custom,none,stat|false|false|false",
    "window.bars.bgColor|color|{a=1,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.bars.borderColorMode|string|custom|nil|nil|nil|class,custom|false|false|false",
    "window.bars.borderColor|color|{a=1,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.bars.borderStyle|string|None|nil|nil|nil|Ka0s Glass|false|false|false",
    "window.bars.borderStyleFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.bars.borderThickness|number|1|1|8|1|-|false|false|false",
    "window.bars.border|bool|false|nil|nil|nil|-|false|false|false",
    "window.bars.colorMode|string|class|nil|nil|nil|class,custom,stat|false|false|false",
    "window.bars.customColor|color|{a=1,b=0.85,g=0.55,r=0.35}|nil|nil|nil|-|false|false|false",
    "window.bars.fillDirection|string|LEFT|nil|nil|nil|LEFT,RIGHT|false|false|false",
    "window.bars.texture|string|Blizzard Raid Bar|nil|nil|nil|Ka0s Classic,Ka0s Default,Ka0s Forge,Ka0s Glass Bar,Ka0s Gradient,Ka0s Matte,Ka0s Overline 1,Ka0s Overline 2,Ka0s Overline 4,Ka0s Parchment,Ka0s Satin,Ka0s Solid,Ka0s Underline 1,Ka0s Underline 2,Ka0s Underline 4|false|false|false",
    "window.bars.textureFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.colorMode|string|custom|nil|nil|nil|class,custom,stat|false|false|false",
    "window.columnHeader.bgColorMode|string|custom|nil|nil|nil|class,custom,stat|false|false|false",
    "window.columnHeader.bgColor|color|{a=0,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.columnHeader.colorMode|string|custom|nil|nil|nil|class,custom,stat|false|false|false",
    "window.columnHeader.color|color|{a=1,b=0,g=0.82,r=1}|nil|nil|nil|-|false|false|false",
    "window.columnHeader.font|string|Friz Quadrata TT|nil|nil|nil|JetBrains Mono,Ka0s Atkinson,Ka0s Atkinson Bold,Ka0s Bitter,Ka0s Bitter Bold,Ka0s Expressway,Ka0s Fira Sans Medium,Ka0s Fira Sans SemiBold,Ka0s Nunito,Ka0s Nunito SemiBold,Ka0s Philosopher,Ka0s Philosopher Bold,Ka0s Prototype,Ka0s Vollkorn,Ka0s Vollkorn Bold|false|false|false",
    "window.columnHeader.fontFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.columnHeader.outline|string|@skin|nil|nil|nil|@skin,MONOCHROME,NONE,OUTLINE,THICKOUTLINE|false|false|false",
    "window.columnHeader.shadow|bool|false|nil|nil|nil|-|false|false|false",
    "window.columnHeader.size|number|11|6|32|1|-|false|false|false",
    "window.columns|nil|nil|nil|nil|nil|-|false|true|false",
    "window.data.sessionID|number|0|nil|nil|nil|-|false|true|false",
    "window.data.sessionType|number|0|nil|nil|nil|-|false|true|false",
    "window.data.sortAscending|bool|false|nil|nil|nil|-|false|true|false",
    "window.data.sortColumn|string|DamageDone|nil|nil|nil|-|false|true|false",
    "window.data.sortMode|string|value|nil|nil|nil|-|false|true|false",
    "window.fontOutline|string|@skin|nil|nil|nil|@skin,MONOCHROME,NONE,OUTLINE,THICKOUTLINE|false|false|false",
    "window.font|string|Friz Quadrata TT|nil|nil|nil|JetBrains Mono,Ka0s Atkinson,Ka0s Atkinson Bold,Ka0s Bitter,Ka0s Bitter Bold,Ka0s Expressway,Ka0s Fira Sans Medium,Ka0s Fira Sans SemiBold,Ka0s Nunito,Ka0s Nunito SemiBold,Ka0s Philosopher,Ka0s Philosopher Bold,Ka0s Prototype,Ka0s Vollkorn,Ka0s Vollkorn Bold|false|false|false",
    "window.fontFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.alpha|number|1|0|1|0.01|-|false|false|false",
    "window.frame.backdropColorMode|string|skin|nil|nil|nil|class,custom,skin|false|false|false",
    "window.frame.backdropColor|color|{a=0.75,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.frame.borderColorMode|string|skin|nil|nil|nil|class,custom,skin|false|false|false",
    "window.frame.borderColor|color|{a=1,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.frame.borderSize|number|2|0|32|1|-|false|false|false",
    "window.frame.borderStyle|string|Blizzard Tooltip|nil|nil|nil|Ka0s Glass|false|false|false",
    "window.frame.clampToScreen|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.closeButton|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.controlAlpha|number|0.25|0|1|0.01|-|false|false|false",
    "window.frame.controlColorMode|string|skin|nil|nil|nil|class,custom,skin|false|false|false",
    "window.frame.controlColor|color|{a=1,b=0.72,g=0.7,r=0.7}|nil|nil|nil|-|false|false|false",
    "window.frame.controlHoverAlpha|number|1|0|1|0.01|-|false|false|false",
    "window.frame.controlHoverColorMode|string|skin|nil|nil|nil|class,custom,skin|false|false|false",
    "window.frame.controlHoverColor|color|{a=1,b=0,g=0.82,r=1}|nil|nil|nil|-|false|false|false",
    "window.frame.controlSize|number|18|10|32|1|-|false|false|false",
    "window.frame.height|number|228|60|900|10|-|false|false|false",
    "window.frame.hoverReveal|bool|false|nil|nil|nil|-|false|false|false",
    "window.frame.locked|bool|false|nil|nil|nil|-|false|false|false",
    "window.frame.minimized|bool|false|nil|nil|nil|-|false|true|false",
    "window.frame.padding|number|6|0|32|1|-|false|false|false",
    "window.frame.scale|number|1|0.5|2|0.05|-|false|false|false",
    "window.frame.showExport|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.showLock|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.showMinimize|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.showReset|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.showSegmentText|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.showSegment|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.showSettings|bool|true|nil|nil|nil|-|false|false|false",
    "window.frame.strata|string|MEDIUM|nil|nil|nil|DIALOG,HIGH,LOW,MEDIUM|false|false|false",
    "window.frame.width|number|694|160|1400|10|-|false|false|false",
    "window.header.align|string|LEFT|nil|nil|nil|CENTER,LEFT,RIGHT|false|false|false",
    "window.header.bgColorFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.header.bgColor|color|{a=0.5,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.header.colorMode|string|skin|nil|nil|nil|class,custom,skin|false|false|false",
    "window.header.color|color|{a=1,b=0,g=0.82,r=1}|nil|nil|nil|-|false|false|false",
    "window.header.dividerColorMode|string|skin|nil|nil|nil|class,custom,skin|false|false|false",
    "window.header.dividerColor|color|{a=0.85,b=0.5,g=0.5,r=0.5}|nil|nil|nil|-|false|false|false",
    "window.header.dividerThickness|number|1|1|8|1|-|false|false|false",
    "window.header.divider|bool|true|nil|nil|nil|-|false|false|false",
    "window.header.font|string|Friz Quadrata TT|nil|nil|nil|JetBrains Mono,Ka0s Atkinson,Ka0s Atkinson Bold,Ka0s Bitter,Ka0s Bitter Bold,Ka0s Expressway,Ka0s Fira Sans Medium,Ka0s Fira Sans SemiBold,Ka0s Nunito,Ka0s Nunito SemiBold,Ka0s Philosopher,Ka0s Philosopher Bold,Ka0s Prototype,Ka0s Vollkorn,Ka0s Vollkorn Bold|false|false|false",
    "window.header.fontFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.header.height|number|26|8|48|1|-|false|false|false",
    "window.header.outline|string|@skin|nil|nil|nil|@skin,MONOCHROME,NONE,OUTLINE,THICKOUTLINE|false|false|false",
    "window.header.shadow|bool|true|nil|nil|nil|-|false|false|false",
    "window.header.show|bool|true|nil|nil|nil|-|false|false|false",
    "window.header.size|number|12|6|32|1|-|false|false|false",
    "window.icons.position|string|LEFT|nil|nil|nil|LEFT,RIGHT|false|false|false",
    "window.icons.showIcon|bool|true|nil|nil|nil|-|false|false|false",
    "window.icons.size|number|14|8|32|1|-|false|false|false",
    "window.name|string|Multi Meters|nil|nil|nil|-|false|false|false",
    "window.rows.alternatingBackground|bool|false|nil|nil|nil|-|false|false|false",
    "window.rows.alwaysShowSelf|bool|true|nil|nil|nil|-|false|false|false",
    "window.rows.growthDirection|string|DOWN|nil|nil|nil|DOWN,UP|false|false|false",
    "window.rows.height|number|16|8|40|1|-|false|false|false",
    "window.rows.highlightSelf|bool|false|nil|nil|nil|-|false|false|false",
    "window.rows.maxRows|number|0|0|40|1|-|false|false|false",
    "window.rows.mouseoverHighlight|bool|true|nil|nil|nil|-|false|false|false",
    "window.rows.spacing|number|1|0|10|1|-|false|false|false",
    "window.text.alpha|number|1|0|1|0.01|-|false|false|false",
    "window.text.colorMode|string|custom|nil|nil|nil|class,custom,stat|false|false|false",
    "window.text.color|color|{a=1,b=1,g=1,r=1}|nil|nil|nil|-|false|false|false",
    "window.text.deathTimeFormat|string|clock|nil|nil|nil|ago,clock|false|false|false",
    "window.text.font|string|Friz Quadrata TT|nil|nil|nil|JetBrains Mono,Ka0s Atkinson,Ka0s Atkinson Bold,Ka0s Bitter,Ka0s Bitter Bold,Ka0s Expressway,Ka0s Fira Sans Medium,Ka0s Fira Sans SemiBold,Ka0s Nunito,Ka0s Nunito SemiBold,Ka0s Philosopher,Ka0s Philosopher Bold,Ka0s Prototype,Ka0s Vollkorn,Ka0s Vollkorn Bold|false|false|false",
    "window.text.fontFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.text.leftSlot|string|smart|nil|nil|nil|combined,none,percent,rate,smart,total|false|false|false",
    "window.text.maxNameLength|number|15|0|40|1|-|false|false|false",
    "window.text.numberFormat|string|abbreviated|nil|nil|nil|abbreviated,abbreviatedTwo,abbreviatedWhole,full|false|false|false",
    "window.text.outline|string|@skin|nil|nil|nil|@skin,MONOCHROME,NONE,OUTLINE,THICKOUTLINE|false|false|false",
    "window.text.rightSlot|string|none|nil|nil|nil|combined,none,percent,rate,smart,total|false|false|false",
    "window.text.shadow|bool|true|nil|nil|nil|-|false|false|false",
    "window.text.size|number|11|6|32|1|-|false|false|false",
    "window.tooltip.anchor|string|TOP|nil|nil|nil|BOTTOM,BOTTOMLEFT,BOTTOMRIGHT,LEFT,RIGHT,TOP,TOPLEFT,TOPRIGHT|false|false|false",
    "window.tooltip.barAlpha|number|0.85|0|1|0.01|-|false|false|false",
    "window.tooltip.barBgAlpha|number|0.1|0|1|0.01|-|false|false|false",
    "window.tooltip.barBgColorMode|string|custom|nil|nil|nil|class,custom,stat|false|false|false",
    "window.tooltip.barBgColor|color|{a=1,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.tooltip.barBorderColorMode|string|custom|nil|nil|nil|class,custom|false|false|false",
    "window.tooltip.barBorderColor|color|{a=1,b=0,g=0,r=0}|nil|nil|nil|-|false|false|false",
    "window.tooltip.barBorderSize|number|1|0|16|1|-|false|false|false",
    "window.tooltip.barBorderStyle|string|None|nil|nil|nil|Ka0s Glass|false|false|false",
    "window.tooltip.barBorderStyleFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.tooltip.barColorMode|string|class|nil|nil|nil|class,custom,stat|false|false|false",
    "window.tooltip.barColor|color|{a=1,b=0.6,g=0.6,r=0.6}|nil|nil|nil|-|false|false|false",
    "window.tooltip.barSpacing|number|1|0|12|1|-|false|false|false",
    "window.tooltip.barTexture|string|Blizzard Raid Bar|nil|nil|nil|Ka0s Classic,Ka0s Default,Ka0s Forge,Ka0s Glass Bar,Ka0s Gradient,Ka0s Matte,Ka0s Overline 1,Ka0s Overline 2,Ka0s Overline 4,Ka0s Parchment,Ka0s Satin,Ka0s Solid,Ka0s Underline 1,Ka0s Underline 2,Ka0s Underline 4|false|false|false",
    "window.tooltip.barTextureFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.tooltip.colorMode|string|custom|nil|nil|nil|class,custom,stat|false|false|false",
    "window.tooltip.fontOutline|string|@skin|nil|nil|nil|@skin,MONOCHROME,NONE,OUTLINE,THICKOUTLINE|false|false|false",
    "window.tooltip.fontShadow|bool|false|nil|nil|nil|-|false|false|false",
    "window.tooltip.fontSize|number|12|6|32|1|-|false|false|false",
    "window.tooltip.font|string|Friz Quadrata TT|nil|nil|nil|JetBrains Mono,Ka0s Atkinson,Ka0s Atkinson Bold,Ka0s Bitter,Ka0s Bitter Bold,Ka0s Expressway,Ka0s Fira Sans Medium,Ka0s Fira Sans SemiBold,Ka0s Nunito,Ka0s Nunito SemiBold,Ka0s Philosopher,Ka0s Philosopher Bold,Ka0s Prototype,Ka0s Vollkorn,Ka0s Vollkorn Bold|false|false|false",
    "window.tooltip.fontFromSkin|bool|true|nil|nil|nil|-|false|false|false",
    "window.tooltip.hideInCombat|bool|false|nil|nil|nil|-|false|false|false",
    "window.tooltip.maxSpells|number|10|0|30|1|-|false|false|false",
    "window.tooltip.maxTargets|number|3|1|10|1|-|false|false|false",
    "window.tooltip.offsetX|number|0|-400|400|1|-|false|false|false",
    "window.tooltip.offsetY|number|0|-400|400|1|-|false|false|false",
    "window.tooltip.scale|number|1|0.5|2|0.05|-|false|false|false",
    "window.tooltip.showAllStatsOnName|bool|true|nil|nil|nil|-|false|false|false",
    "window.tooltip.showDeathCaster|bool|true|nil|nil|nil|-|false|false|false",
    "window.tooltip.showDeathSpell|bool|false|nil|nil|nil|-|false|false|false",
    "window.tooltip.showSpells|bool|true|nil|nil|nil|-|false|false|false",
    "window.tooltip.showTargets|bool|false|nil|nil|nil|-|false|false|false",
    "window.tooltip.textColor|color|{a=1,b=1,g=1,r=1}|nil|nil|nil|-|false|false|false",
    "window.visibility.arena|bool|true|nil|nil|nil|-|false|false|false",
    "window.visibility.battleground|bool|true|nil|nil|nil|-|false|false|false",
    "window.visibility.delve|bool|true|nil|nil|nil|-|false|false|false",
    "window.visibility.dungeon|bool|true|nil|nil|nil|-|false|false|false",
    "window.visibility.hideInCombat|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideInHousing|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideInPetBattle|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideInVehicle|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideOnTaxi|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideOutOfCombat|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideWhenDead|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideWhenMounted|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideWhenSkyriding|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.hideWhenSolo|bool|false|nil|nil|nil|-|false|false|false",
    "window.visibility.raid|bool|true|nil|nil|nil|-|false|false|false",
    "window.visibility.scenario|bool|true|nil|nil|nil|-|false|false|false",
    "window.visibility.world|bool|true|nil|nil|nil|-|false|false|false",
}

local function current()
    local lines = {}
    for _, row in ipairs(NS.Schema) do lines[#lines + 1] = canon(row) end
    table.sort(lines)
    return lines
end

test("Settings pin: the schema holds exactly the pinned rows, keys and defaults unchanged", function()
    local have, want = {}, {}
    for _, l in ipairs(current()) do have[l] = (have[l] or 0) + 1 end
    for _, l in ipairs(PIN) do want[l] = (want[l] or 0) + 1 end
    local missing, extra = {}, {}
    for l, n in pairs(want) do if have[l] ~= n then missing[#missing + 1] = l end end
    for l, n in pairs(have) do if want[l] ~= n then extra[#extra + 1] = l end end
    table.sort(missing)
    table.sort(extra)
    assertEqual(#missing + #extra, 0,
        "settings drifted. Pinned but gone: " .. table.concat(missing, " ; ")
        .. " || new or changed: " .. table.concat(extra, " ; "))
end)

test("Settings pin: the row count is the pinned count", function()
    assertEqual(#NS.Schema, #PIN)
    assertTrue(#PIN > 0, "the pin is empty")
end)
