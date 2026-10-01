-- GainKit Plus -- put GainKit first in the chain of every selected track that has none (a GainKit
-- inside an FX container counts as one), embedded in the mixer strip. One undo step. MIT, EON
-- Studios, 2026.
local r = reaper
local NAMES = { "JS: EON: GainKit",                                  -- by its listed name, any install
                "ReaKit FX/FX/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx",   -- the ReaPack package's path
                "EON/Eon_JSFX/FX/ChannelTool_ReaKit.jsfx" }          -- the EON install's path

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. The display name is the fallback on a REAPER without fx_ident.
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if ok and id ~= "" then return id:lower():find("channeltool_reakit", 1, true) ~= nil end
  local _, nm = r.TrackFX_GetFXName(tr, f, "")
  return nm:find("GainKit", 1, true) ~= nil
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

local function has_gainkit(tr)
  local found = false
  each_gainkit(tr, function() found = true end)
  return found
end

-- Open it embedded in the mixer strip, the house default: REAPER keeps that as bit 2 of the second
-- field of the WAK line after the plugin's FXID in the track chunk (there is no API for it).
local function embed_mcp(tr, guid)
  local ok, chunk = r.GetTrackStateChunk(tr, "", false)
  if not ok or not chunk or not guid then return end
  local out, hit, done = {}, false, false
  for line in (chunk .. "\n"):gmatch("(.-)\n") do
    if not done then
      if line:match("^%s*FXID%s") then hit = line:find(guid, 1, true) ~= nil
      elseif hit then
        local w = line:match("^%s*WAK%s+%-?%d+%s+(%d+)")
        if w then
          local v = tonumber(w) or 0
          if math.floor(v / 2) % 2 == 0 then
            line = (line:gsub("^(%s*WAK%s+%-?%d+%s+)(%d+)", "%1" .. (v + 2), 1))
            done = true
          else
            return   -- already embedded
          end
        end
      end
    end
    out[#out + 1] = line
  end
  if done then r.SetTrackStateChunk(tr, table.concat(out, "\n"), false) end
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local added, missed = 0, 0
for i = 0, r.CountSelectedTracks(0) - 1 do
  local tr = r.GetSelectedTrack(0, i)
  if not has_gainkit(tr) then
    local fx = -1
    for _, n in ipairs(NAMES) do
      if fx < 0 then fx = r.TrackFX_AddByName(tr, n, false, -1000) end   -- -1000 = position 0, first
    end
    if fx >= 0 then added = added + 1; embed_mcp(tr, r.TrackFX_GetFXGUID(tr, fx)) else missed = missed + 1 end
  end
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: GainKit on the selected tracks", -1)
if missed > 0 then r.MB("GainKit was not found on this machine (" .. missed .. " track(s) left without it). Install ReaKit FX from ReaPack.", "GainKit Plus", 0) end
