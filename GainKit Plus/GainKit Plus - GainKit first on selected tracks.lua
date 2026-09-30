-- GainKit Plus -- move the GainKit of every SELECTED track (the master too, when it is selected)
-- to the FIRST slot of its chain; "GainKit first in every chain" does the whole project. Tracks
-- without one are left alone, and so is a GainKit inside an FX container: it stays where the
-- container puts it. One undo step. MIT, EON Studios, 2026.
local r = reaper

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. The display name is the fallback on a REAPER without fx_ident.
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if ok and id ~= "" then return id:lower():find("channeltool_reakit", 1, true) ~= nil end
  local _, nm = r.TrackFX_GetFXName(tr, f, "")
  return nm:find("GainKit", 1, true) ~= nil
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local moved = 0
for i = 0, r.CountSelectedTracks2(0, true) - 1 do             -- true: the master counts when selected
  local tr = r.GetSelectedTrack2(0, i, true)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    if is_gainkit(tr, f) then
      if f > 0 then r.TrackFX_CopyToTrack(tr, f, tr, 0, true); moved = moved + 1 end   -- true = move
      break                                                                             -- the first GainKit only
    end
  end
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: GainKit first on the selected tracks (" .. moved .. " moved)", -1)
