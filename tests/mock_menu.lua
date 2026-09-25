-- tests/mock_menu.lua — a headless stand-in for the client's context-menu API (11.0+), for the
-- LAUNCHER's options menu (LibKa0s-Launcher-1.0 minor 4, launcher-§2).
--
-- MODELED ON THE LIBRARY'S OWN FAKE, LibKa0s tests/mock_menu.lua at v1.58.0, and carried here
-- because that file is repo-local to LibKa0s and NOT in the kit: the library's version-4 document
-- ("Testing a host") tells a host suite that pins its menu entries to install its own, shaped on
-- that file. The body below is the library's, unchanged, so a case here reads the menu exactly as
-- the library's own suite does.
--
-- WHY A SIBLING AND NOT A BRANCH OF tests/wow_mock.lua. The builder already carries a MenuUtil for
-- the window header's segment selector (CreateTitle / CreateDivider / CreateButton), and it is on
-- notice under layout-§1's 1500-line cap. This one is installed per case, over that one, only by
-- tests/test_launchersetup.lua:
--
--     local menu = assert(loadfile(T.root .. "/tests/mock_menu.lua"))()(inst.mocks)
--
-- NOT a suite: tests/run.lua's SUITES list must not gain an entry for it.
--
-- `MenuUtil.CreateContextMenu(ownerRegion, generator)` hands the generator a root description:
-- `root:CreateTitle(text)` and `root:CreateCheckbox(text, isSelected, setSelected, data)`, the
-- second answering an element whose `SetEnabled(false)` grays the entry. Clicking an enabled
-- checkbox calls `setSelected(data)`, and what it returns is the menu's response.
--
-- FIDELITY. Two things the real API does that a convenient fake would not, and both matter:
--   * a disabled element is never clicked. `Click` refuses a grayed entry the way the client does,
--     so a case that wants to prove the library's own gate calls `ForceClick` and says so;
--   * `CreateContextMenu` runs the generator when the menu opens, once per open. A module that
--     cached state across opens would read stale here as it would in the client.

return function(mocks)
  local M = { menus = {}, opens = 0 }

  local RESPONSE = { Close = 1, Refresh = 2, Open = 3 }

  --- One opened menu: the owner it anchors to, its title and its entries in creation order.
  local function newRoot(owner)
    local menu = { owner = owner, titles = {}, entries = {} }
    local root = {}
    function root:CreateTitle(text)
      menu.titles[#menu.titles + 1] = text
      return {}
    end
    function root:CreateCheckbox(text, isSelected, setSelected, data)
      local entry = { text = text, isSelected = isSelected, setSelected = setSelected,
        data = data, enabled = true }
      local element = {}
      function element:SetEnabled(on) entry.enabled = on and true or false end
      function element:IsEnabled() return entry.enabled end
      menu.entries[#menu.entries + 1] = entry
      return element
    end

    --- The entries' texts, in order.
    function menu:Texts()
      local out = {}
      for i, e in ipairs(self.entries) do out[i] = e.text end
      return out
    end
    --- The entry whose text starts with `prefix`, or nil.
    function menu:Find(prefix)
      for _, e in ipairs(self.entries) do
        if e.text:sub(1, #prefix) == prefix then return e end
      end
    end
    --- Whether an entry draws checked, as the client asks it.
    function menu:Checked(prefix)
      local e = self:Find(prefix)
      return e and e.isSelected(e.data) and true or false
    end
    --- Click an entry as a player can: a grayed one does nothing and answers nil.
    function menu:Click(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      if not e.enabled then return nil end
      return e.setSelected(e.data)
    end
    --- Run an entry's handler regardless of its gray, to reach the module's own gate.
    function menu:ForceClick(prefix)
      local e = assert(self:Find(prefix), "no menu entry " .. prefix)
      return e.setSelected(e.data)
    end
    return root, menu
  end

  M.MenuUtil = {
    CreateContextMenu = function(owner, generator)
      if owner == nil then error("CreateContextMenu: an owner region is required", 2) end
      local root, menu = newRoot(owner)
      M.opens = M.opens + 1
      generator(owner, root)
      M.menus[#M.menus + 1] = menu
      M.last = menu
      return menu
    end,
  }

  --- Put the fake API in the environment, or take it away (`MenuUtil` absent, as on a client
  --- before 11.0 or one where the menu system failed to load).
  function M.install()
    mocks.MenuUtil = M.MenuUtil
    mocks.MenuResponse = RESPONSE
  end
  function M.remove()
    mocks.MenuUtil = nil
    mocks.MenuResponse = nil
  end
  function M.reset()
    M.menus, M.opens, M.last = {}, 0, nil
  end

  M.RESPONSE = RESPONSE
  M.install()
  return M
end
