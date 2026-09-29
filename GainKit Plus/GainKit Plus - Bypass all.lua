-- GainKit Plus -- bypass every GainKit (the master's too); run it again, with all of them
-- bypassed, and it enables them all: hear the session with and without its gain staging. Some on
-- and some bypassed counts as on, so from a mix it bypasses them all. One undo step.
-- MIT, EON Studios, 2026.
local r = reaper

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. The display name is the fallback on a REAPER without fx_ident.
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if ok and id ~= "" then return id:lower():find("channeltool_reakit", 1, true) ~= nil end
  local _, nm = r.TrackFX_GetFXName(tr, f, "")
  return nm:find("GainKit", 1, true) ~= nil
end

local list = {}
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    if is_gainkit(tr, f) then list[#list + 1] = { tr, f } end
  end
end
local any_on = false
for _, e in ipairs(list) do if r.TrackFX_GetEnabled(e[1], e[2]) then any_on = true end end
r.Undo_BeginBlock()
for _, e in ipairs(list) do r.TrackFX_SetEnabled(e[1], e[2], not any_on) end
r.Undo_EndBlock(any_on and "GainKit Plus: bypass all GainKits" or "GainKit Plus: enable all GainKits", -1)
