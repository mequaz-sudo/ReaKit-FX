-- GainKit Plus -- every GainKit's key to STEREO (Format = Stereo; the M/S modes too), one undo
-- step. MIT, EON Studios, 2026.
local r = reaper
local function set_format(v)
  local n = 0
  for i = -1, r.CountTracks(0) - 1 do
    local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
    for f = 0, r.TrackFX_GetCount(tr) - 1 do
      local _, nm = r.TrackFX_GetFXName(tr, f, "")
      if nm:find("GainKit", 1, true) then
        for p = 0, r.TrackFX_GetNumParams(tr, f) - 1 do
          local _, pn = r.TrackFX_GetParamName(tr, f, p, "")
          if pn == "Format" then r.TrackFX_SetParam(tr, f, p, v); n = n + 1 end
        end
      end
    end
  end
  return n
end
r.Undo_BeginBlock()
local n = set_format(0)
r.Undo_EndBlock("GainKit Plus: all GainKits STEREO (" .. n .. ")", -1)
