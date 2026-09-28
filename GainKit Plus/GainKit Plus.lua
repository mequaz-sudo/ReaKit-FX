-- GainKit Plus -- feeds every GainKit in the project its track's name, colour and icon, and
-- keeps them current while it runs. GainKit draws them: the name as the meter's legend (a name
-- you typed on the meter still wins), the colour as a thin bar, the icon beside the name.
--
-- A background script: run it once to start, run it again to stop. It costs one pass over the
-- tracks every 0.3 s and writes only when something changed.
--
-- Protocol: the EON_GKPLUS band in the Swing_Media_Transfer shared-memory segment (declared in
-- .refs/gmem_regions_supplement.tsv): one 320-cell slot per track index, +0 GEN written LAST,
-- +1 colour (r*65536 + g*256 + b + 1; 0 = none), +2 name length, +3.. name (24 chars),
-- +27 icon path length, +28.. icon path (absolute, <= 259 chars). GainKit reads its own slot by
-- the track index REAPER gives it (get_host_placement()). MIT, EON Studios, 2026.
local r = reaper
local BASE, STRIDE, MAXT = 31195136, 320, 512
local NAME_MAX, PATH_MAX = 24, 259

-- A toggle: run it again to stop. set_action_options(1) makes a relaunch a clean RESTART, not a
-- stop (the running instance's atexit first, then this chunk, 2 ms apart - wiki 6, measured), so
-- the running instance stamps a heartbeat every tick and a fresh one here means the user pressed
-- the action while it ran: this launch is the "stop" and ends at once. The old instance's atexit
-- has already zeroed the GENs and the toggle state.
local EXT = "EON_GainKitPlus"
local _, _, sec, cmd = r.get_action_context()
local hb = tonumber(r.GetExtState(EXT, "alive")) or 0
if r.time_precise() - hb < 1.0 then
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
  r.SetExtState(EXT, "alive", "0", false)
  return
end
if r.set_action_options then r.set_action_options(1) end
if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end

r.gmem_attach("Swing_Media_Transfer")

local last, gen = {}, {}

-- the JSFX prints 7-bit ASCII only; anything else (accents, symbols) is dropped, not mangled
local function fold(s) return (tostring(s or ""):gsub("[^\32-\126]", "")) end

local function has_gainkit(tr)
  for i = 0, r.TrackFX_GetCount(tr) - 1 do
    local _, nm = r.TrackFX_GetFXName(tr, i, "")
    if nm:find("GainKit", 1, true) then return true end
  end
  return false
end

-- the icon as REAPER keeps it: a full path for a file you chose, a bare name for one of its own
local function icon_path(tr)
  local _, icon = r.GetSetMediaTrackInfo_String(tr, "P_ICON", "", false)
  icon = fold(icon)
  if icon == "" then return "" end
  if icon:match("^%a:[\\/]") or icon:match("^[\\/]") then return icon end
  local res = r.GetResourcePath()
  if icon:find("track_icons", 1, true) then return res .. "/Data/" .. icon end
  return res .. "/Data/track_icons/" .. icon
end

local function write_str(base, lenidx, chidx, s, cap)
  local n = math.min(#s, cap)
  r.gmem_write(base + lenidx, n)
  for i = 1, n do r.gmem_write(base + chidx + i - 1, s:byte(i)) end
end

local function publish(idx, tr)
  local base = BASE + idx * STRIDE
  local _, name = r.GetTrackName(tr)
  name = fold(name)
  local col, packed = r.GetTrackColor(tr), 0
  if col ~= 0 then
    local rr, gg, bb = r.ColorFromNative(col)
    packed = rr * 65536 + gg * 256 + bb + 1          -- +1: black is a colour, 0 is "none"
  end
  local icon = icon_path(tr)
  local key = name .. "|" .. packed .. "|" .. icon
  if last[idx] ~= key then
    last[idx] = key
    r.gmem_write(base + 1, packed)
    write_str(base, 2, 3, name, NAME_MAX)
    write_str(base, 27, 28, icon, PATH_MAX)
    gen[idx] = (gen[idx] or 0) + 1
    r.gmem_write(base, gen[idx])                       -- GEN last: the JSFX takes the slot whole
  end
end

local function clear(idx)
  if last[idx] then last[idx] = nil; r.gmem_write(BASE + idx * STRIDE, 0) end
end

local function tick()
  local n = math.min(r.CountTracks(0), MAXT)
  for i = 0, n - 1 do
    local tr = r.GetTrack(0, i)
    if has_gainkit(tr) then publish(i, tr) else clear(i) end
  end
  for i = n, MAXT - 1 do if last[i] then clear(i) end end
end

local t_last = 0
local function loop()
  local now = r.time_precise()
  r.SetExtState(EXT, "alive", tostring(now), false)          -- the heartbeat a relaunch reads
  if now - t_last >= 0.3 then t_last = now; tick() end
  r.defer(loop)
end

r.atexit(function()
  for i = 0, MAXT - 1 do if last[i] then r.gmem_write(BASE + i * STRIDE, 0) end end
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end)
loop()
