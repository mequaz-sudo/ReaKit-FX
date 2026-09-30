-- GainKit Plus -- GainKit LAST in the master's chain, so the mix gets a final VU after everything
-- else: the master's GainKit is moved to the end (the last one, when it has two), or GainKit is
-- added there when it has none. A GainKit inside an FX container counts as the master's and stays
-- where it is. One undo step. MIT, EON Studios, 2026.
local r = reaper
local NAMES = { "JS: EON: GainKit",                                  -- by its listed name, any install
                "ReaKit FX/FX/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx",   -- the ReaPack package's path
                "EON/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx" }          -- the EON install's path

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. The display name is the fallback on a REAPER without fx_ident.
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if ok and id ~= "" then return id:lower():find("channeltool_reakit", 1, true) ~= nil end
  local _, nm = r.TrackFX_GetFXName(tr, f, "")
  return nm:find("GainKit", 1, true) ~= nil
end

-- Every GainKit on a track, FX containers included: REAPER 7 reaches a container's items through
-- its container_count / container_item.N (nested containers too). On a REAPER without containers
-- only the chain itself is searched. fn(f) gets each GainKit's FX address.
local function each_gainkit(tr, fn)
  local function walk(f)
    if is_gainkit(tr, f) then fn(f) end
    local ok, n = r.TrackFX_GetNamedConfigParm(tr, f, "container_count")
    if ok then
      for i = 0, (tonumber(n) or 0) - 1 do
        local ok2, c = r.TrackFX_GetNamedConfigParm(tr, f, "container_item." .. i)
        if ok2 and tonumber(c) then walk(tonumber(c)) end
      end
    end
  end
  for f = 0, r.TrackFX_GetCount(tr) - 1 do walk(f) end
end

local m = r.GetMasterTrack(0)
local n = r.TrackFX_GetCount(m)
local top = -1
for f = 0, n - 1 do if is_gainkit(m, f) then top = f end end   -- the last one in the chain
local any = false
each_gainkit(m, function() any = true end)

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local what, missing = "already last", false
if top >= 0 then
  if top < n - 1 then r.TrackFX_CopyToTrack(m, top, m, n - 1, true); what = "moved last" end   -- true = move
elseif any then
  what = "inside an FX container, left there"
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
