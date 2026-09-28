-- GainKit Plus -- bypass every GainKit (the master's too), or enable them all again if any is
-- bypassed: hear the session with and without its gain staging. One undo step. MIT, EON Studios, 2026.
local r = reaper
local list = {}
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    local _, nm = r.TrackFX_GetFXName(tr, f, "")
    if nm:find("GainKit", 1, true) then list[#list + 1] = { tr, f } end
  end
end
local any_on = false
for _, e in ipairs(list) do if r.TrackFX_GetEnabled(e[1], e[2]) then any_on = true end end
r.Undo_BeginBlock()
for _, e in ipairs(list) do r.TrackFX_SetEnabled(e[1], e[2], not any_on) end
r.Undo_EndBlock(any_on and "GainKit Plus: bypass all GainKits" or "GainKit Plus: enable all GainKits", -1)
