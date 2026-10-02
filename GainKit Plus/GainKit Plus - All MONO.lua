-- GainKit Plus -- every GainKit's key to MONO (Format = Mono; GainKits inside FX containers too),
-- one undo step. MIT, EON Studios, 2026.
local r = reaper

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. A REAPER that cannot tell an FX's file finds none: these scripts
-- delete, bypass and move what they find, so they never guess from a name. The file NAME must match
-- exactly: a plugin called ChannelTool_ReaKit_v2.jsfx, or one in a folder named after GainKit's
-- file, is another plugin (outside audit, 2026-10-02).
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  return ok and (id:match("[^/\\]+$") or ""):lower() == "channeltool_reakit.jsfx"
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

local function set_format(v)
  local n = 0
  for i = -1, r.CountTracks(0) - 1 do
    local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
    each_gainkit(tr, function(f)
      for p = 0, r.TrackFX_GetNumParams(tr, f) - 1 do
        local _, pn = r.TrackFX_GetParamName(tr, f, p, "")
        if pn == "Format" then r.TrackFX_SetParam(tr, f, p, v); n = n + 1 end
      end
    end)
  end
  return n
end
r.Undo_BeginBlock()
local n = set_format(1)
r.Undo_EndBlock("GainKit Plus: all GainKits MONO (" .. n .. ")", -1)
