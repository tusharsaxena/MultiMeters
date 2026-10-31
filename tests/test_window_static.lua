-- tests/test_window_static.lua — the static source sweep over the window's refresh chain
-- (modules/Window.lua, Window_Frame.lua, Window_Render.lua). It sat at the foot of
-- tests/test_window.lua until MM-04's split took that suite to the 1500-line cap; the review moved
-- it here so the next edit to either file has room. The dynamic half of rule R3, which poisons the
-- cell getters and drives a refresh through them, stays in tests/test_window.lua.

local T = _G.MULTIMETERS_TEST

local test        = T.test
local assertEqual = T.assertEqual

test("modules/Window.lua reads geometry back off the anchor and nothing else", function()
    -- A static sweep beside the dynamic one: the dynamic case can only catch a
    -- read on a path it happened to drive, and this catches the line. Over the
    -- loop's three files since MM-04 peeled the frame and the draw out of it.
    local offenders = {}
    for _, rel in ipairs{ "modules/Window.lua", "modules/Window_Frame.lua",
                          "modules/Window_Render.lua" } do
        local fh = assert(io.open(T.root .. "/" .. rel, "r"))
        local n = 0
        for line in fh:lines() do
            n = n + 1
            if not line:match("^%s*%-%-") then
                local code = line:gsub("%s%-%-.*$", "")
                for _, getter in ipairs{ "GetWidth", "GetHeight", "GetLeft", "GetPoint" } do
                    local at = code:find(":" .. getter .. "%(")
                    if at and not code:find("self%.anchor:" .. getter) then
                        offenders[#offenders + 1] = rel .. ":" .. n
                    end
                end
            end
        end
        fh:close()
    end
    assertEqual(#offenders, 0,
        "geometry is read off something other than the anchor: "
        .. table.concat(offenders, ", "))
end)
