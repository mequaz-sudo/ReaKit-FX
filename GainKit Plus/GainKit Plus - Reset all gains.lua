-- GainKit Plus -- every GainKit's GAIN back to 0 dB (the master's too), one undo step. MIT, EON Studios, 2026.
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
local n = 0
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    if is_gainkit(tr, f) then
      for p = 0, r.TrackFX_GetNumParams(tr, f) - 1 do
        local _, pn = r.TrackFX_GetParamName(tr, f, p, "")
        if pn:sub(1, 4) == "Gain" then r.TrackFX_SetParam(tr, f, p, 0); n = n + 1 end
      end
    end
  end
end
r.Undo_EndBlock("GainKit Plus: reset all gains (" .. n .. ")", -1)
