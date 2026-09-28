-- GainKit Plus -- put GainKit first in the chain of every selected track that has none.
-- One undo step. MIT, EON Studios, 2026.
local r = reaper
local NAMES = { "JS: EON: GainKit",                                  -- by its listed name, any install
                "ReaKit FX/FX/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx",   -- the ReaPack package's path
                "EON/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx" }          -- the EON install's path

local function has_gainkit(tr)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    local _, nm = r.TrackFX_GetFXName(tr, f, "")
    if nm:find("GainKit", 1, true) then return true end
  end
  return false
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local added, missed = 0, 0
for i = 0, r.CountSelectedTracks(0) - 1 do
  local tr = r.GetSelectedTrack(0, i)
  if not has_gainkit(tr) then
    local fx = -1
    for _, n in ipairs(NAMES) do
      if fx < 0 then fx = r.TrackFX_AddByName(tr, n, false, -1000) end   -- -1000 = position 0, first
    end
    if fx >= 0 then added = added + 1 else missed = missed + 1 end
  end
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: GainKit on the selected tracks", -1)
if missed > 0 then r.MB("GainKit was not found on this machine (" .. missed .. " track(s) left without it). Install ReaKit FX from ReaPack.", "GainKit Plus", 0) end
