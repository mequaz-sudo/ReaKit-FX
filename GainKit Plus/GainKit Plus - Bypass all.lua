-- GainKit Plus -- bypass every GainKit (the master's too, and GainKits inside FX containers); run
-- it again, with all of them bypassed, and it enables them all: hear the session with and without
-- its gain staging. Some on and some bypassed counts as on, so from a mix it bypasses them all.
-- One undo step. MIT, EON Studios, 2026.
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

local list = {}
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  each_gainkit(tr, function(f) list[#list + 1] = { tr, f } end)
end
local any_on = false
for _, e in ipairs(list) do if r.TrackFX_GetEnabled(e[1], e[2]) then any_on = true end end
r.Undo_BeginBlock()
for _, e in ipairs(list) do r.TrackFX_SetEnabled(e[1], e[2], not any_on) end
r.Undo_EndBlock(any_on and "GainKit Plus: bypass all GainKits" or "GainKit Plus: enable all GainKits", -1)
