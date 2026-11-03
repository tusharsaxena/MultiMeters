-- tests/test_header_glyph_size.lua — every header glyph is drawn at one visual size (R6-MM2).
--
-- The owner's image 67 (Ka0sAddonsCommonTasks docs/2026-11-03-SMOKE_ROUND6/): the export button's
-- chat bubble read smaller than every other glyph in the strip. Every control's texture is the same
-- box (floor(controlSize * ART_SCALE)), so the difference is in the ART: the house icons reach their
-- own 64px edges, while Phosphor's chat-text carries a transparent margin around a 52 x 48 glyph.
-- What the eye compares is the INK, so this measures it: each control's TGA is read off disk, its
-- ink box (alpha above 16) taken inside the texcoords the texture was given, and scaled to the box
-- the texture was sized to. The export glyph has to come out the size of its neighbors' median.

local T = _G.MULTIMETERS_TEST
local test, assertEqual, assertTrue = T.test, T.assertEqual, T.assertTrue

local CURRENT = 1

-- ── a minimal TGA reader: 32 bpp, uncompressed (2) or run-length (10) ─────────────────────────

local function u16(s, i) return s:byte(i) + s:byte(i + 1) * 256 end

--- The alpha channel of a 32 bpp TGA as rows TOP-DOWN, with its width and height.
local function readAlpha(path)
    local fh = assert(io.open(path, "rb"), "cannot open " .. path)
    local s = fh:read("*a")
    fh:close()
    local idLen, cmapType, kind = s:byte(1), s:byte(2), s:byte(3)
    local w, h, bpp, desc = u16(s, 13), u16(s, 15), s:byte(17), s:byte(18)
    assert(bpp == 32, path .. " is not 32 bpp")
    assert(cmapType == 0, path .. " has a color map")
    local i, n, alpha = 19 + idLen, w * h, {}
    if kind == 2 then
        for p = 0, n - 1 do alpha[p] = s:byte(i + p * 4 + 3) end
    else
        assert(kind == 10, path .. ": TGA type " .. kind)
        local p = 0
        while p < n do
            local c = s:byte(i); i = i + 1
            local run = (c % 128) + 1
            if c >= 128 then
                local a = s:byte(i + 3); i = i + 4
                for _ = 1, run do alpha[p] = a; p = p + 1 end
            else
                for _ = 1, run do alpha[p] = s:byte(i + 3); i = i + 4; p = p + 1 end
            end
        end
    end
    local topDown = math.floor(desc / 32) % 2 == 1
    local rows = {}
    for y = 0, h - 1 do
        local src = topDown and y or (h - 1 - y)
        local row = {}
        for x = 0, w - 1 do row[x] = alpha[src * w + x] end
        rows[y] = row
    end
    return rows, w, h
end

--- The ink's width and height, in pixels of the image, inside the crop [l, r] x [t, b] (0..1).
local function inkIn(rows, w, h, l, r, t, b)
    local x0, x1, y0, y1 = math.floor(l * w + 0.5), math.floor(r * w + 0.5) - 1,
        math.floor(t * h + 0.5), math.floor(b * h + 0.5) - 1
    local minX, maxX, minY, maxY
    for y = math.max(0, y0), math.min(h - 1, y1) do
        for x = math.max(0, x0), math.min(w - 1, x1) do
            if rows[y][x] > 16 then
                minX = math.min(minX or x, x); maxX = math.max(maxX or x, x)
                minY = math.min(minY or y, y); maxY = math.max(maxY or y, y)
            end
        end
    end
    if not minX then return 0, 0, x1 - x0 + 1, y1 - y0 + 1 end
    return maxX - minX + 1, maxY - minY + 1, x1 - x0 + 1, y1 - y0 + 1
end

local ADDON_PREFIX = "Interface\\AddOns\\MultiMeters\\"

--- The on-disk file of an art path the button drew.
local function fileOf(path)
    assertTrue(path:sub(1, #ADDON_PREFIX) == ADDON_PREFIX, "not this addon's art: " .. path)
    local rel = path:sub(#ADDON_PREFIX + 1):gsub("\\", "/")
    if not rel:find("%.tga$") then rel = rel .. ".tga" end
    return T.root .. "/" .. rel
end

local cache = {}

--- The size of a control's glyph as DRAWN: the larger side of its ink, in screen pixels.
local function drawnGlyph(button)
    local tex = button.tex
    local file = fileOf(button.mmArt)
    cache[file] = cache[file] or { readAlpha(file) }
    local rows, w, h = cache[file][1], cache[file][2], cache[file][3]
    local tc = tex.__texCoord or { 0, 1, 0, 1 }
    local inkW, inkH, cropW, cropH = inkIn(rows, w, h, tc[1], tc[2], tc[3], tc[4])
    return math.max(tex.__w * inkW / cropW, tex.__h * inkH / cropH)
end

local function median(list)
    table.sort(list)
    local n = #list
    if n % 2 == 1 then return list[(n + 1) / 2] end
    return (list[n / 2] + list[n / 2 + 1]) / 2
end

local NEIGHBORS = { "close", "minimize", "lock", "settings", "segment", "reset" }

test("Header glyphs: the export bubble is drawn the size of its neighbors in every skin and size", function()
    -- red under: the export art drawn across its full texture, margin included (no crop), which
    -- puts its 52 px glyph in the box the 64 px house glyphs fill.
    local inst = T.load()
    local NS = inst.NS
    local Skin = inst.mocks.LibStub("LibKa0s-Skin-1.0")
    local cfg = NS.Database.GetWindows()[1]
    cfg.data.sessionType = CURRENT
    local window = NS.Window.New(cfg)
    window:RefreshVisibility()

    local checked = 0
    for _, def in ipairs(Skin:Skins()) do
        assertTrue(NS.SetByPath("skin.skin", def.key), "the skin " .. def.key .. " did not apply")
        for _, size in ipairs({ 10, 14, 18, 24, 32 }) do
            cfg.frame.controlSize = size
            NS.HeaderControls:Apply(window)
            local export = window.controls.export
            assertEqual(export.mmRung, "art", "the export control is not on its own art")
            local sizes = {}
            for _, key in ipairs(NEIGHBORS) do
                local b = window.controls[key]
                assertEqual(b.mmRung, "art", key .. " is not on its own art")
                sizes[#sizes + 1] = drawnGlyph(b)
            end
            local want, got = median(sizes), drawnGlyph(export)
            assertTrue(math.abs(got - want) <= 0.5,
                ("%s, controlSize %d: the export glyph is %.2f px against its neighbors' %.2f px")
                    :format(def.key, size, got, want))
            checked = checked + 1
        end
    end
    assertTrue(checked >= 9 * 5, "fewer skins than the library registers were checked")
end)

test("Header glyphs: a house icon keeps its full texture, so only the padded art is cropped", function()
    -- red under: a crop applied to every control, which would cut the house glyphs' edges.
    local inst = T.load()
    local NS = inst.NS
    local cfg = NS.Database.GetWindows()[1]
    local window = NS.Window.New(cfg)
    window:RefreshVisibility()
    NS.HeaderControls:Apply(window)
    for _, key in ipairs(NEIGHBORS) do
        local tc = window.controls[key].tex.__texCoord or { 0, 1, 0, 1 }
        assertEqual(table.concat(tc, ","), "0,1,0,1", key .. " is cropped")
    end
end)
