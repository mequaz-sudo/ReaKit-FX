-- GainKit Plus -- GainKit LAST in the master's chain, so the mix gets a final VU after everything
-- else: the master's GainKit is moved to the end (the last one, when it has two), or GainKit is
-- added there when it has none at the top level. A GainKit inside an FX container stays where it
-- is and does not count: it sits before whatever follows the container, so the mix gets a new one
-- at the end (outside audit, 2026-09-30). One undo step. MIT, EON Studios, 2026.
local r = reaper
local NAMES = { "JS: EON: GainKit",                                  -- by its listed name, any install
                "ReaKit FX/FX/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx",   -- the ReaPack package's path
                "EON/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx" }          -- the EON install's path

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. A REAPER that cannot tell an FX's file finds none: these scripts
-- delete, bypass and move what they find, so they never guess from a name. The file NAME must match
-- exactly: a plugin called ChannelTool_ReaKit_v2.jsfx, or one in a folder named after GainKit's
-- file, is another plugin (outside audit, 2026-10-02).
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  return ok and (id:match("[^/\\]+$") or ""):lower() == "channeltool_reakit.jsfx"
end

local m = r.GetMasterTrack(0)
local n = r.TrackFX_GetCount(m)
local top = -1
for f = 0, n - 1 do if is_gainkit(m, f) then top = f end end   -- the last one in the chain

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local what, missing = "already last", false
if top >= 0 then
  if top < n - 1 then r.TrackFX_CopyToTrack(m, top, m, n - 1, true); what = "moved last" end   -- true = move
else
  local fx = -1
  for _, nm in ipairs(NAMES) do
    if fx < 0 then fx = r.TrackFX_AddByName(m, nm, false, -1) end   -- -1 = a new one, at the end
  end
  if fx >= 0 then what = "added last" else missing = true; what = "not found" end
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: GainKit last on the master (" .. what .. ")", -1)
if missing then r.MB("GainKit was not found on this machine. Install ReaKit FX from ReaPack.", "GainKit Plus", 0) end
