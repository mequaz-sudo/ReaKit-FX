-- GainKit Plus -- feeds every GainKit in the project its track's name, colour and icon, and
-- keeps them current while it runs. GainKit draws them: the name as the meter's legend (a name
-- you typed on the meter still wins), the colour as a thin bar, the icon beside the name. The
-- master's GainKit gets the PROJECT's name (MASTER while the project is unsaved), and a GainKit
-- inside an FX container counts for its track. It also does what the free plugins' EMBED row asks:
-- shows that plugin in the mixer strip, in the track panel or in neither, and opens new copies of
-- the six there.
--
-- A background script: run it once to start, run it again to stop. It costs one pass over the
-- tracks every 0.3 s and writes only when something changed.
--
-- Protocol: the EON_GKPLUS band in the Swing_Media_Transfer shared-memory segment (declared in
-- .refs/gmem_regions_supplement.tsv): one 320-cell slot per track index, +0 GEN written LAST,
-- +1 colour (r*65536 + g*256 + b + 1; 0 = none), +2 name length, +3.. name (24 chars),
-- +27 icon path length, +28.. icon path (absolute, <= 259 chars). GainKit reads its own slot by
-- the track index REAPER gives it (get_host_placement()); the master, whose index is -1, reads
-- slot 512, after the tracks'. MIT, EON Studios, 2026.
local r = reaper
local BASE, STRIDE, MAXT = 31195136, 320, 512
local MASTER = 512
local NAME_MAX, PATH_MAX = 24, 259

-- A toggle: run it again to stop. set_action_options(1): a relaunch ends the running instance (its
-- atexit runs first, no task-control dialog) and the new launch runs (wiki 6, measured; REAPER's
-- flag 1 = terminate on relaunch, flag 2 = relaunch after), so the running instance stamps a heartbeat (EXT/alive) every tick, and
-- a launch that finds a fresh one, newer than the last stop request (EXT/stop), is the user's
-- second press: it writes the stop request and ends at once. The running instance sees the
-- request at its next tick and quits WITHOUT stamping again (REAPER terminates it anyway), so a
-- start right after a stop is a start, not a second stop. Its atexit zeroes the GENs and the
-- toggle state.
local EXT = "EON_GainKitPlus"
local _, _, sec, cmd = r.get_action_context()
local now0 = r.time_precise()
local hb = tonumber(r.GetExtState(EXT, "alive")) or 0
local st = tonumber(r.GetExtState(EXT, "stop")) or 0
if hb > st and now0 - hb < 1.0 then
  r.SetExtState(EXT, "stop", tostring(now0), false)
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
  return
end
if r.set_action_options then r.set_action_options(1) end
if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end

r.gmem_attach("Swing_Media_Transfer")

local last, gen = {}, {}

-- the JSFX prints 7-bit ASCII only; anything else (accents, symbols) is dropped, not mangled
local function fold(s) return (tostring(s or ""):gsub("[^\32-\126]", "")) end

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. The display name is the fallback on a REAPER without fx_ident.
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if ok and id ~= "" then return id:lower():find("channeltool_reakit", 1, true) ~= nil end
  local _, nm = r.TrackFX_GetFXName(tr, f, "")
  return nm:find("GainKit", 1, true) ~= nil
end

-- A GainKit anywhere on the track, FX containers included: REAPER 7 reaches a container's items
-- through its container_count / container_item.N (nested containers too). On a REAPER without
-- containers only the chain itself is searched.
local function has_gainkit(tr)
  local function walk(f)
    if is_gainkit(tr, f) then return true end
    local ok, n = r.TrackFX_GetNamedConfigParm(tr, f, "container_count")
    if ok then
      for i = 0, (tonumber(n) or 0) - 1 do
        local ok2, c = r.TrackFX_GetNamedConfigParm(tr, f, "container_item." .. i)
        if ok2 and tonumber(c) and walk(tonumber(c)) then return true end
      end
    end
    return false
  end
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    if walk(f) then return true end
  end
  return false
end

-- The master's name: the project's, without its extension; MASTER while it has never been saved.
local function project_name()
  local nm = (r.GetProjectName(0) or ""):gsub("%.[^.]*$", "")
  return nm ~= "" and nm or "MASTER"
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

local function publish(idx, tr, name)
  local base = BASE + idx * STRIDE
  if not name then name = select(2, r.GetTrackName(tr)) end
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

-- EMBED: the THEME panel's EMBED row (MCP / TCP / OFF) in the free plugins. A JSFX cannot move its
-- own embed, so it asks here, in the EON_RKFX_EMBED band (declared in
-- .refs/gmem_regions_supplement.tsv): +8 mode (1 MCP, 2 TCP, 3 OFF), +9 track (get_host_placement:
-- 0-based, -1 master), +10 chain position (the API's own index, a container address inside one),
-- +11 flags (1 = take FX), +12 a counter bumped LAST. The plugin moves with REAPER's own "Show last
-- focused FX embedded UI in MCP / TCP" when it is the focused one (each toggles: into its panel, or
-- out of it when it is already there; measured 2026-10-01), else through the WAK line after its
-- FXID in the track chunk (field 2: TCP 1, MCP 2; that reloads the track). Then new copies of all
-- six are set to open there (reaper-fxoptions.ini [defcfg]: bit 4 MCP, bit 2 TCP, neither = OFF;
-- REAPER reads it at every insert, and 6 would mean TCP). Published back: +0 a heartbeat (os.time,
-- the clock a JSFX's time() reads; 0 at exit), +1 that default (GainKit's line decides), +2 the
-- request served last.
local EMB = 31365504
local SIX = { "ChannelTool_ReaKit.jsfx", "Saturation_ReaKit.jsfx", "3BandEQ_ReaKit.jsfx",
              "DDC_ReaKit.jsfx", "DeEsser_ReaKit.jsfx", "StereoWidth_ReaKit.jsfx" }
local RES = r.GetResourcePath()
local OPT = RES .. "/reaper-fxoptions.ini"
local function slurp(p) local fh = io.open(p, "rb"); if not fh then return nil end; local s = fh:read("*a"); fh:close(); return s end
-- REAPER's settings file: its text, "" when there is none yet, nil when it is there but could not be
-- read (locked for a moment) -- then nothing is written, or every other plugin's line would go
local function read_opt(p)
  local fh, _, code = io.open(p, "rb")
  if not fh then return code == 2 and "" or nil end   -- 2: no such file
  local s = fh:read("*a"); fh:close()
  return s
end
-- the new text in without ever leaving no file: written beside it, the old one moved aside, the new
-- one moved in, the old one put back when that fails
local function replace_file(p, text)
  local tmp, bak = p .. ".reakitfx-tmp", p .. ".reakitfx-bak"
  local fh = io.open(tmp, "wb")
  if not fh then return false end
  local ok = fh:write(text) and true or false
  if not fh:close() then ok = false end
  if not ok then os.remove(tmp); return false end
  os.remove(bak)
  local had = os.rename(p, bak)
  if os.rename(tmp, p) then os.remove(bak); return true end
  if had then os.rename(bak, p) end
  os.remove(tmp)
  return false
end

-- the six's paths as REAPER names them in [defcfg]: each one reaper-jsfx.ini lists, plus ReaPack's
-- place when it is not scanned yet; GainKit's first
local function six_paths()
  local paths, have = {}, {}
  local function put(p) if not have[p] then have[p] = true; paths[#paths + 1] = p end end
  local ini = slurp(RES .. "/reaper-jsfx.ini") or ""
  for _, f in ipairs(SIX) do
    for p in ini:gmatch('NAME%s+"?([^"\r\n]-%.jsfx)"?%s') do
      if p == f or p:sub(-(#f + 1)) == "/" .. f then put(p) end
    end
    local rp = "ReaKit FX/FX/Eon_JSFX/FX/" .. f
    if slurp(RES .. "/Effects/" .. rp) then put(rp) end
  end
  return paths
end

-- [defcfg] value -> 1 MCP, 2 TCP, 3 OFF
local function place_of(v) return math.floor(v / 2) % 2 == 1 and 2 or math.floor(v / 4) % 2 == 1 and 1 or 3 end

local function read_default(paths)                -- nil: the file could not be read this time
  if #paths == 0 then return 0 end
  local txt, in_def = read_opt(OPT), false
  if not txt then return nil end
  if txt:sub(1, 3) == "\239\187\191" then txt = txt:sub(4) end
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local s = line:match("^%[(.-)%]%s*$")
    if s then
      if in_def then break end                       -- REAPER reads the first [defcfg] only
      in_def = (s == "defcfg")
    elseif in_def then
      local k, v = line:match("^(.-)=(%-?%d+)%s*$")
      if k == paths[1] then return place_of(tonumber(v) or 0) end
    end
  end
  return 3
end

-- set the six's [defcfg] lines to the place, every other bit and line kept
local function write_default(paths, mode)
  if #paths == 0 then return end
  local add = mode == 1 and 4 or mode == 2 and 2 or 0
  local txt = read_opt(OPT)
  if not txt then return end
  local bom = txt:sub(1, 3) == "\239\187\191" and "\239\187\191" or ""   -- kept, not parsed as text
  txt = txt:sub(#bom + 1)
  local nl = txt:find("\r\n", 1, true) and "\r\n" or (txt == "" and "\r\n" or "\n")
  local lines, sec_at, sec_end, first = {}, nil, nil, false
  for line in ((txt == "" and "" or txt .. (txt:sub(-1) == "\n" and "" or "\n"))):gmatch("(.-)\r?\n") do
    lines[#lines + 1] = line
    local s = line:match("^%[(.-)%]%s*$")
    if s then first = (s == "defcfg" and not sec_at); if first then sec_at = #lines end   -- REAPER reads the first [defcfg] only
    elseif first and line:match("%S") then sec_end = #lines end
  end
  if not sec_at then lines[#lines + 1] = "[defcfg]"; sec_at = #lines end
  sec_end = sec_end or sec_at
  local changed = false
  for _, p in ipairs(paths) do
    local found = false
    for i = sec_at + 1, #lines do
      if lines[i]:match("^%[") then break end
      local k, v = lines[i]:match("^(.-)=(%-?%d+)%s*$")
      if k == p then
        found = true
        local n = tonumber(v) or 0
        local n2 = n - (math.floor(n / 4) % 2) * 4 - (math.floor(n / 2) % 2) * 2 + add
        if n2 ~= n then lines[i] = p .. "=" .. n2; changed = true end
      end
    end
    if not found and add > 0 then table.insert(lines, sec_end + 1, p .. "=" .. add); sec_end = sec_end + 1; changed = true end
  end
  if changed and not replace_file(OPT, bom .. table.concat(lines, nl) .. nl) then return end
  -- the start-up action's one-time MCP default must not undo a place picked here
  r.SetExtState("EON_ReaKitFX", "embed_defaults", "1", true)
end

local function is_six(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if not ok or id == "" then return false end
  id = id:lower()
  for _, s in ipairs(SIX) do if id:find(s:lower(), 1, true) then return true end end
  return false
end

-- the embed bits after the plugin's FXID (TCP 1, MCP 2), and their rewrite
local function wak2(tr, guid)
  local _, ch = r.GetTrackStateChunk(tr, "", false)
  local hit = false
  for line in ((ch or "") .. "\n"):gmatch("(.-)\n") do
    if line:match("^%s*FXID%s") then hit = line:find(guid, 1, true) ~= nil
    elseif hit then local w = line:match("^%s*WAK%s+%-?%d+%s+(%d+)"); if w then return tonumber(w) end end
  end
end
local function set_wak2(tr, guid, want)
  local ok, ch = r.GetTrackStateChunk(tr, "", false)
  if not ok or not ch then return end
  local out, hit, done = {}, false, false
  for line in (ch .. "\n"):gmatch("(.-)\n") do
    if not done then
      if line:match("^%s*FXID%s") then hit = line:find(guid, 1, true) ~= nil
      elseif hit then
        local w = line:match("^%s*WAK%s+%-?%d+%s+(%d+)")
        if w then
          local v = tonumber(w) or 0
          line = (line:gsub("^(%s*WAK%s+%-?%d+%s+)(%d+)", "%1" .. (v - v % 4 + want), 1))
          done = true
        end
      end
    end
    out[#out + 1] = line
  end
  if done then r.SetTrackStateChunk(tr, table.concat(out, "\n"), false) end
end

-- REAPER's two actions, by name (their ids, 42372 / 42335 on 7.81, when a translation renames them)
local act
local function actions()
  if act then return act end
  act = { mcp = 42372, tcp = 42335 }
  local sec = r.SectionFromUniqueID(0)
  for i = 0, 100000 do
    local id, nm = r.kbd_enumerateActions(sec, i)
    if not id or id == 0 then break end
    if nm == "FX: Show last focused FX embedded UI in MCP" then act.mcp = id end
    if nm == "FX: Show last focused FX embedded UI in TCP" then act.tcp = id end
  end
  return act
end

local function move(ti, pos, mode)
  local tr = ti == -1 and r.GetMasterTrack(0) or r.GetTrack(0, ti)
  if not tr or not is_six(tr, pos) then return end
  -- the row is in the plugin's own (floating) window, so the plugin that asked has it open: a
  -- plugin that took its place before this ran (a tab switch, a move) is left alone (the outside
  -- review, round 2)
  if not r.TrackFX_GetOpen(tr, pos) then return end
  local guid = r.TrackFX_GetFXGUID(tr, pos)
  local cur = guid and wak2(tr, guid)
  if not cur then return end
  local want = mode == 1 and 2 or mode == 2 and 1 or 0
  if cur % 4 == want then return end
  r.Undo_BeginBlock()
  if r.GetTouchedOrFocusedFX then
    local rv, ftr, fitem, _, ffx = r.GetTouchedOrFocusedFX(1)
    if rv and ftr == ti and fitem == -1 and ffx == pos then
      local a = actions()
      for _ = 1, 2 do
        local c = (wak2(tr, guid) or 0) % 4
        if c == want then break end
        -- into the wanted panel, or out of the one it is in
        r.Main_OnCommand(want == 2 and a.mcp or want == 1 and a.tcp or (c % 2 == 1 and a.tcp or a.mcp), 0)
      end
    end
  end
  if (wak2(tr, guid) or 0) % 4 ~= want then set_wak2(tr, guid, want) end
  r.Undo_EndBlock("ReaKit FX: embed " .. (mode == 1 and "in the mixer" or mode == 2 and "in the track panel" or "off"), -1)
end

local served = r.gmem_read(EMB + 12)       -- a request older than this run is not ours to serve
local hb_last, def_t, paths = 0, -10, nil
local function embed_tick(now)
  local t = os.time()
  if t ~= hb_last then hb_last = t; r.gmem_write(EMB, t) end
  local g = r.gmem_read(EMB + 12)
  if g ~= served then
    served = g
    local mode = math.floor(r.gmem_read(EMB + 8) + 0.5)
    if mode >= 1 and mode <= 3 then
      local fl = math.floor(r.gmem_read(EMB + 11) + 0.5)
      if fl % 2 == 0 then move(math.floor(r.gmem_read(EMB + 9) + 0.5), math.floor(r.gmem_read(EMB + 10) + 0.5), mode) end
      paths = six_paths()
      write_default(paths, mode)
      def_t = now
      local d = read_default(paths); if d then r.gmem_write(EMB + 1, d) end   -- before the answer: no flicker
    end
    r.gmem_write(EMB + 2, g)
  end
  if now - def_t >= 5 then                  -- the default, again every 5 s (the FX browser can change it)
    def_t = now
    paths = paths or six_paths()
    local d = read_default(paths); if d then r.gmem_write(EMB + 1, d) end
  end
end

local function tick()
  local n = math.min(r.CountTracks(0), MAXT)
  for i = 0, n - 1 do
    local tr = r.GetTrack(0, i)
    if has_gainkit(tr) then publish(i, tr) else clear(i) end
  end
  for i = n, MAXT - 1 do if last[i] then clear(i) end end
  local m = r.GetMasterTrack(0)
  if has_gainkit(m) then publish(MASTER, m, project_name()) else clear(MASTER) end
end

local t_last = 0
local function loop()
  local now = r.time_precise()
  if (tonumber(r.GetExtState(EXT, "stop")) or 0) > now0 then return end   -- asked to stop: no stamp, atexit cleans up
  r.SetExtState(EXT, "alive", tostring(now), false)          -- the heartbeat a relaunch reads
  embed_tick(now)
  if now - t_last >= 0.3 then t_last = now; tick() end
  r.defer(loop)
end

r.atexit(function()
  for i = 0, MASTER do if last[i] then r.gmem_write(BASE + i * STRIDE, 0) end end
  r.gmem_write(EMB, 0)                                         -- the EMBED row says NEEDS PLUS at once
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end)
loop()
