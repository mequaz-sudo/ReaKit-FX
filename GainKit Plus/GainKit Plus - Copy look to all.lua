-- GainKit Plus -- copy the LOOK of the selected track's GainKit to every GainKit in the project
-- (the master's too, and GainKits inside FX containers): the THEME panel's STRIP, NUMBERS, NAME,
-- FONT, VU COLOR, VALUE, METERS, VU DRAG, ST/MONO, NAME BAR and NATIVE rows, and the METER tab's 0 VU,
-- SPEED, HOLD, READOUT and PEAK LIGHT (2026-10-03: a 0 VU of -20 set on one GainKit goes to them all). Not
-- the VU face (it is kept inside each plugin's own saved state, out of a script's reach) and not the knob
-- style (it follows the suite theme). Gains, keys and names stay as they are. One undo step. MIT, EON Studios, 2026.
local r = reaper
local LOOK = { ["Strip view"] = true, ["Strip numbers"] = true, ["Name style"] = true, ["Name font"] = true,
               ["Meter colour"] = true, ["Gain number"] = true, ["VU meters"] = true, ["VU drag"] = true,
               ["Stereo key"] = true, ["Name bar"] = true, ["Native look"] = true,
               ["0 VU"] = true, ["VU speed"] = true, ["VU hold"] = true, ["VU readout"] = true, ["Peak light"] = true }

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

-- a parameter's name up to its note: "Strip view (internal; ...)" -> "Strip view"
local function key(pn) return (pn:match("^(.-)%s*%(") or pn) end

local src_tr, src_fx
for i = 0, r.CountSelectedTracks2(0, true) - 1 do             -- true: the master counts when selected
  local tr = r.GetSelectedTrack2(0, i, true)
  each_gainkit(tr, function(f) if not src_tr then src_tr, src_fx = tr, f end end)
  if src_tr then break end
end
if not src_tr then
  r.MB("Select a track whose GainKit has the look you want, then run this again.", "GainKit Plus", 0)
  return
end
local look = {}
for p = 0, r.TrackFX_GetNumParams(src_tr, src_fx) - 1 do
  local _, pn = r.TrackFX_GetParamName(src_tr, src_fx, p, "")
  if LOOK[key(pn)] then look[key(pn)] = (r.TrackFX_GetParam(src_tr, src_fx, p)) end
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local n = 0
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  each_gainkit(tr, function(f)
    if tr == src_tr and f == src_fx then return end
    for p = 0, r.TrackFX_GetNumParams(tr, f) - 1 do
      local _, pn = r.TrackFX_GetParamName(tr, f, p, "")
      local v = look[key(pn)]
      if v ~= nil then r.TrackFX_SetParam(tr, f, p, v) end
    end
    n = n + 1
  end)
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: copy the look to all GainKits (" .. n .. ")", -1)
