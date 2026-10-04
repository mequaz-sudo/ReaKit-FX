-- ReaKit FX -- REAPER's docker tabs off, or on again (the user, 2026-10-03: "the tabs at the bottom of dockers
-- ... maybe an action to turn them on and off"). Off: every docker holding ONE window shows a thin edge
-- instead of its tab bar; a docker holding two or more keeps its tabs (they switch between the windows).
-- REAPER's own option underneath, "Dockers: Compact when small and single tab" (the preference
-- dockcompactsingle), with its size limit (dock_mini_tab_size) raised past any screen so "small" is always
-- true; on again puts back what was there before (the option as it was, the limit). It is REAPER-wide, not
-- only the ReaKit FX dock, and it stays as set after a restart. The ReaKit FX dock's TABS button does the same
-- (the two share their notes, in "EON_ReaKitDock"). On a toolbar the button lights while the tabs are off.
-- Measured 2026-10-03 (tabs2_probe.lua): a script cannot set dockcompactsingle (set_config_var_string returns 0),
-- so the option is flipped with REAPER's action and only read here. MIT, EON Studios, 2026.
local r = reaper
local EXT = "EON_ReaKitDock"

local COMPACT_NAME = "dockers: compact when small and single tab"
local function cfg_num(name)
  local ok, v = r.get_config_var_string(name)
  return ok and tonumber(v) or nil
end
local function compact_on() return (cfg_num("dockcompactsingle") or 0) ~= 0 end
-- The action: 41691 in REAPER 7.81 when its name says so, or, in a translated REAPER (its name is not English
-- there: the audit, 2026-10-03), when it is an on/off action whose state is the preference's own; else the English
-- name anywhere in the list (another REAPER numbering). 0 = none.
local function compact_action()
  local t = r.kbd_getTextFromCmd(41691, 0)
  local st = r.GetToggleCommandState(41691)
  if (t and t:lower() == COMPACT_NAME) or (st >= 0 and (st == 1) == compact_on()) then return 41691 end
  for i = 40000, 70000 do
    t = r.kbd_getTextFromCmd(i, 0)
    if t and t:lower() == COMPACT_NAME then return i end
  end
  return 0
end
local function tabs_hidden()
  return compact_on() and (cfg_num("dock_mini_tab_size") or 0) >= 4000
end

local cmd_compact = r.set_config_var_string and compact_action() or 0
if cmd_compact == 0 then
  r.MB("This REAPER cannot change that setting from a script. Update REAPER, then run this again.", "ReaKit FX", 0)
  return
end
-- Flip the preference through its action and check that it flipped; an action that turns out to be another one
-- is run again (put back).
local function flip_compact()
  local before = compact_on()
  r.Main_OnCommand(cmd_compact, 0)
  if compact_on() ~= before then return true end
  r.Main_OnCommand(cmd_compact, 0)
  return false
end

local compact = compact_on()
local ok = true
if not tabs_hidden() then
  local size = cfg_num("dock_mini_tab_size")
  if size and size < 4000 then r.SetExtState(EXT, "mini_tab_size_was", tostring(size), true) end
  r.SetExtState(EXT, "compact_was", compact and "1" or "0", true)
  r.set_config_var_string("dock_mini_tab_size", "4000", 1)
  if not compact then ok = flip_compact() end
else
  if compact and r.GetExtState(EXT, "compact_was") == "0" then ok = flip_compact() end
  local was = tonumber(r.GetExtState(EXT, "mini_tab_size_was")) or 200      -- REAPER's own default
  r.set_config_var_string("dock_mini_tab_size", tostring(math.min(was, 3999)), 1)
end
r.DockWindowRefresh()                  -- measured 2026-10-03: the dockers show it once they are laid out again
if not ok then
  r.MB("REAPER's \"Dockers: Compact when small and single tab\" could not be switched from here.\n\n" ..
       "Run that action from REAPER's Actions list instead.", "ReaKit FX", 0)
end

local _, _, sec, cmd = r.get_action_context()
if sec and cmd and cmd > 0 then
  r.SetToggleCommandState(sec, cmd, tabs_hidden() and 1 or 0)
  r.RefreshToolbar2(sec, cmd)
end
