-- GainKit Plus -- move every track's GainKit to the FIRST slot of its chain (the master's too),
-- so it stages the signal before anything else. Tracks without one are left alone (Insert on
-- selected tracks adds it first). One undo step. MIT, EON Studios, 2026.
local r = reaper
r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local moved = 0
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    local _, nm = r.TrackFX_GetFXName(tr, f, "")
    if nm:find("GainKit", 1, true) then
      if f > 0 then r.TrackFX_CopyToTrack(tr, f, tr, 0, true); moved = moved + 1 end   -- true = move
      break                                                                             -- the first GainKit only
    end
  end
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: GainKit first in every chain (" .. moved .. " moved)", -1)
