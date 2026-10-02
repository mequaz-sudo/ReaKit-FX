-- GainKit Plus -- every GainKit's GAIN back to 0 dB (the master's too, and GainKits inside FX
-- containers), one undo step. Only the GAIN: "Gain number" (the THEME panel's VALUE row) is left
-- alone. MIT, EON Studios, 2026.
local r = reaper

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. A REAPER that cannot tell an FX's file finds none: these scripts
-- delete, bypass and move what they find, so they never guess from a name.
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  return ok and id:lower():find("channeltool_reakit", 1, true) ~= nil
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

r.Undo_BeginBlock()
local n = 0
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  each_gainkit(tr, function(f)
    for p = 0, r.TrackFX_GetNumParams(tr, f) - 1 do
      local _, pn = r.TrackFX_GetParamName(tr, f, p, "")
      if pn == "Gain (dB)" then r.TrackFX_SetParam(tr, f, p, 0); n = n + 1; break end   -- by its whole name
    end
  end)
end
r.Undo_EndBlock("GainKit Plus: reset all gains (" .. n .. ")", -1)
