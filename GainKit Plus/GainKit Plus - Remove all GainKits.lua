-- GainKit Plus -- take GainKit off every track and the master, FX containers included, after
-- asking once. One undo step: Undo puts every one of them back. MIT, EON Studios, 2026.
local r = reaper

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

local function first_gainkit(tr)
  local found
  each_gainkit(tr, function(f) if not found then found = f end end)
  return found
end

local tracks, total = {}, 0
for i = -1, r.CountTracks(0) - 1 do
  local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
  local c = 0
  each_gainkit(tr, function() c = c + 1 end)
  if c > 0 then tracks[#tracks + 1] = tr; total = total + c end
end
if total == 0 then r.MB("There is no GainKit in this project.", "GainKit Plus", 0); return end
local ask = "Remove all " .. total .. " GainKit" .. (total == 1 and "" or "s") .. " from this project?\n\nUndo puts them back."
if r.MB(ask, "GainKit Plus", 1) ~= 1 then return end            -- 1 = OK

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local removed = 0
for _, tr in ipairs(tracks) do
  for _ = 1, 1000 do                    -- one at a time: removing an FX renumbers the ones after it
    local f = first_gainkit(tr)
    if not f or not r.TrackFX_Delete(tr, f) then break end
    removed = removed + 1
  end
end
r.PreventUIRefresh(-1)
r.Undo_EndBlock("GainKit Plus: remove all GainKits (" .. removed .. ")", -1)
