-- GainKit Plus -- feeds every GainKit in the project its track's name, colour and icon, and
-- keeps them current while it runs. GainKit draws them: the name as the meter's legend (a name
-- you typed on the meter still wins), the colour as a thin bar, the icon beside the name. The
-- master's GainKit gets the PROJECT's name (MASTER while the project is unsaved), and a GainKit
-- inside an FX container counts for its track. It also does what the free plugins' EMBED row asks:
-- shows that plugin in the mixer strip, in the track panel or in neither, and opens new copies of
-- the seven there; and what the long-view arrow on a GainKit's or a Filter's strip asks: swaps that
-- plugin for its tall copy, or back (LONG VIEW, below).
--
-- A background script: run it once to start, run it again to stop. It costs one pass over the
-- tracks every 0.3 s and writes only when something changed.
--
-- Protocol: the EON_GKPLUS band in the Swing_Media_Transfer shared-memory segment (declared in
-- .refs/gmem_regions_supplement.tsv): one 320-cell slot per track index, +0 GEN written LAST,
-- +1 colour (r*65536 + g*256 + b + 1; 0 = none), +2 name length, +3.. name (24 bytes, UTF-8),
-- +27 icon path length, +28.. icon path (absolute, <= 259 bytes). GainKit reads its own slot by
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
-- req_seen[idx]: the rename mailbox counter (slot +290) as last read. A GainKit that gets a name typed on its meter
-- writes the name into its slot (+291 length, +292.. bytes) and bumps the counter; rename_tick renames the TRACK
-- (one undo step), so the meter, the dock and REAPER hold ONE name (the user, 2026-10-07). The counter is taken as
-- read when a slot is first published in this run, so a request from before this run never fires.
local req_seen = {}
local REQ, REQLEN, REQNAME = 290, 291, 292
-- This run's GENs start past every earlier run's in this REAPER session. GainKit rereads a slot only
-- when the GEN (or its track) changed, and every run used to count from 1 again: a GainKit whose window
-- was closed while Plus stopped and started kept generation 1 from the old run, took the new run's 1
-- for the same data and showed an old colour or icon (outside audit 2026-10-02). A session counter,
-- not saved: the GainKits' caches and the shared memory both start empty with REAPER.
local run = math.floor(tonumber(r.GetExtState(EXT, "run")) or 0) + 1
r.SetExtState(EXT, "run", string.format("%d", run), false)
local GEN0 = run * 1000000000

-- The ReaKit FX dock opens again with REAPER (the user, 2026-10-03). GainKit Plus and the dock each stamp the
-- wall clock every few seconds, saved with REAPER's settings. GainKit Plus's first run in a REAPER session
-- compares last time's two stamps: the dock alive within 10 s of GainKit Plus's last stamp = it was open when
-- REAPER closed, so it opens again, a few seconds in (the project loaded first). Closing the dock with its tab
-- clears its stamp; one turned off with its action stays shut unless REAPER closed within 10 s of that.
local DOCK_EXT = "EON_ReaKitDock"
local DOCK_FILE = "ReaKit FX - Dock following the selected track.lua"
local dock_reopen_at
if run == 1 then
  local dw = tonumber(r.GetExtState(DOCK_EXT, "wall")) or 0
  local pw = tonumber(r.GetExtState(EXT, "wall")) or 0
  if dw > 0 and pw > 0 and dw >= pw - 10 then dock_reopen_at = now0 + 3 end
end
local function reopen_dock()
  if r.time_precise() - (tonumber(r.GetExtState(DOCK_EXT, "alive")) or 0) < 1.0 then return end   -- already up
  local _, me = r.get_action_context()
  local p = (me or ""):match("^(.*[/\\])")
  p = p and (p .. DOCK_FILE)
  if not (p and r.file_exists(p)) then return end
  local id = r.AddRemoveReaScript(true, 0, p, true)
  if id and id ~= 0 then r.Main_OnCommand(id, 0) end
end
local wall_t = 0

-- names and icon paths go as UTF-8 bytes, control bytes dropped. They were folded to printable ASCII,
-- so accents vanished from names and an icon in a folder with one never loaded, REAPER's own icons
-- included when the Windows user folder has one (outside audit, 2026-10-02).
local function clean(s) return (tostring(s or ""):gsub("[\0-\31\127]", "")) end   -- fixed bytes, not %c (locale-dependent)

-- GainKit by its FILE: a GainKit renamed in the FX chain still counts, and another plugin with
-- "GainKit" in its name does not. A REAPER that cannot tell an FX's file finds none: these scripts
-- delete, bypass and move what they find, so they never guess from a name. The file NAME must match
-- exactly: a plugin called ChannelTool_ReaKit_v2.jsfx, or one in a folder named after GainKit's
-- file, is another plugin (outside audit, 2026-10-02).
local function is_gainkit(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  return ok and (id:match("[^/\\]+$") or ""):lower() == "channeltool_reakit.jsfx"
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
  icon = clean(icon)
  if icon == "" then return "" end
  if icon:match("^%a:[\\/]") or icon:match("^[\\/]") then return icon end
  local res = r.GetResourcePath()
  if icon:find("track_icons", 1, true) then return res .. "/Data/" .. icon end
  return res .. "/Data/track_icons/" .. icon
end

-- at most cap bytes, never ending inside a UTF-8 letter (a continuation byte is 10xxxxxx)
local function write_str(base, lenidx, chidx, s, cap)
  local n = math.min(#s, cap)
  while n > 0 and n < #s and s:byte(n + 1) >= 0x80 and s:byte(n + 1) < 0xC0 do n = n - 1 end
  r.gmem_write(base + lenidx, n)
  for i = 1, n do r.gmem_write(base + chidx + i - 1, s:byte(i)) end
end

local function publish(idx, tr, name)
  local base = BASE + idx * STRIDE
  if not name then name = select(2, r.GetTrackName(tr)) end
  name = clean(name)
  local col, packed = r.GetTrackColor(tr), 0
  if col ~= 0 then
    local rr, gg, bb = r.ColorFromNative(col)
    packed = rr * 65536 + gg * 256 + bb + 1          -- +1: black is a colour, 0 is "none"
  end
  local icon = icon_path(tr)
  local key = name .. "|" .. packed .. "|" .. icon
  if req_seen[idx] == nil then req_seen[idx] = r.gmem_read(base + REQ) end   -- first sight: as read, nothing old fires
  if last[idx] ~= key then
    last[idx] = key
    r.gmem_write(base + 1, packed)
    write_str(base, 2, 3, name, NAME_MAX)
    write_str(base, 27, 28, icon, PATH_MAX)
    gen[idx] = (gen[idx] or GEN0) + 1
    r.gmem_write(base, gen[idx])                       -- GEN last: the JSFX takes the slot whole
  end
end

local function clear(idx)
  if last[idx] then last[idx] = nil; req_seen[idx] = nil; r.gmem_write(BASE + idx * STRIDE, 0) end
end

-- A name typed on a GainKit's meter: its slot's counter moved -> the track takes the name (every defer, so it lands
-- within a frame or two; one gmem read per published slot). The master's slot is not a track: left alone.
local function rename_tick()
  for idx in pairs(last) do
    if idx < MASTER then
      local base = BASE + idx * STRIDE
      local c = r.gmem_read(base + REQ)
      if c ~= req_seen[idx] then
        req_seen[idx] = c
        local n, t = math.max(0, math.min(NAME_MAX, math.floor(r.gmem_read(base + REQLEN)))), {}
        for i = 0, n - 1 do
          local v = math.floor(r.gmem_read(base + REQNAME + i))
          if v >= 32 and v ~= 127 and v <= 255 then t[#t + 1] = string.char(v) end
        end
        local name, tr = clean(table.concat(t)), r.GetTrack(0, idx)
        if tr then
          local _, cur = r.GetTrackName(tr)
          if name ~= cur then
            r.Undo_BeginBlock()
            r.GetSetMediaTrackInfo_String(tr, "P_NAME", name, true)
            r.Undo_EndBlock("GainKit: track renamed " .. (name ~= "" and ("to " .. name) or "(cleared)"), -1)
            r.TrackList_AdjustWindows(false)
          end
        end
      end
    end
  end
end

-- EMBED: the THEME panel's EMBED row (MCP / TCP / OFF) in the free plugins. A JSFX cannot move its
-- own embed, so it asks here, in the EON_RKFX_EMBED band (declared in
-- .refs/gmem_regions_supplement.tsv): +8 mode (1 MCP, 2 TCP, 3 OFF), +9 track (get_host_placement:
-- 0-based, -1 master), +10 chain position (the API's own index, a container address inside one),
-- +11 flags (1 = take FX), +12 a counter bumped LAST. The plugin moves with REAPER's own "Show last
-- focused FX embedded UI in MCP / TCP" when it is the focused one (each toggles: into its panel, or
-- out of it when it is already there; measured 2026-10-01), else through the WAK line after its
-- FXID in the track chunk (field 2: TCP 1, MCP 2; that reloads the track). Then new copies of all
-- seven are set to open there (reaper-fxoptions.ini [defcfg]: bit 4 MCP, bit 2 TCP, neither = OFF;
-- REAPER reads it at every insert, and 6 would mean TCP). Published back: +0 a heartbeat (os.time,
-- the clock a JSFX's time() reads; 0 at exit), +1 that default (GainKit's line decides), +2 the
-- request served last, +3 the long view served (6: modes 4 DOCK and 5 / 6 LONG VIEW for GainKit;
-- 7: the Filter's too; each plugin offers its arrow only at the level it needs, so a Plus that would
-- mark its request served and do nothing shows no arrow; 0 at exit, and 0 from a Plus older than the
-- long view), +4 1 while a long-view swap waits for the transport to stop (LONG VIEW's writing()).
local EMB = 31365504
local SEVEN = { "ChannelTool_ReaKit.jsfx", "Saturation_ReaKit.jsfx", "3BandEQ_ReaKit.jsfx",
                "DDC_ReaKit.jsfx", "DeEsser_ReaKit.jsfx", "StereoWidth_ReaKit.jsfx",
                "Filter_ReaKit.jsfx" }                 -- the seventh (ReaKit FX 1.5.0, 2026-10-07)
local RES = r.GetResourcePath()
local OPT = RES .. "/reaper-fxoptions.ini"
local function slurp(p) local fh = io.open(p, "rb"); if not fh then return nil end; local s = fh:read("*a"); fh:close(); return s end
-- REAPER's settings file: its text, "" when there is none yet, nil when it is there but could not be
-- read (locked for a moment) -- then nothing is written, or every other plugin's line would go. A run
-- cut off between replace_file's two renames left the old file only as the spare: it goes back
-- first (read as missing, it was rebuilt from nothing and the spare removed); if it cannot, nil.
local function read_opt(p)
  local fh, _, code = io.open(p, "rb")
  if not fh and code == 2 then
    local bak = p .. ".reakitfx-bak"
    local spare = io.open(bak, "rb")
    if spare then
      spare:close()
      if not os.rename(bak, p) then return nil end
      fh, _, code = io.open(p, "rb")
    end
  end
  if not fh then return code == 2 and "" or nil end   -- 2: no such file
  local s = fh:read("*a"); fh:close()
  return s
end
-- the new text in without ever leaving no file: written beside it and read back, the old one moved
-- aside, the new one moved in, the old one put back when that fails. A spare already there is never
-- removed (outside audit, 2026-10-08): read_opt put a stranded one back when REAPER's file was gone,
-- so one still here sits beside a file REAPER has written since -- it may be the only full copy -- or
-- was left by a remove that failed. It moves to a name nothing uses and stays; the second return
-- value names it. (os.rename onto itself succeeds only for a path that is there, readable or not.)
-- The same as "ReaKit FX - Start with REAPER" (iniwrite_test.py runs both).
local function replace_file(p, text)
  local tmp, bak, keep = p .. ".reakitfx-tmp", p .. ".reakitfx-bak", nil
  if os.rename(bak, bak) then
    for i = 0, 99 do
      local n = ("%s.reakitfx-kept-%d-%d"):format(p, math.floor(os.time()), i)
      if not os.rename(n, n) then keep = n; break end
    end
    if not keep or not os.rename(bak, keep) then return false end
  end
  local fh = io.open(tmp, "wb")
  if not fh then return false, keep end
  local ok = fh:write(text) and true or false
  if not fh:close() then ok = false end
  if not ok or slurp(tmp) ~= text then os.remove(tmp); return false, keep end
  local had = os.rename(p, bak)
  if os.rename(tmp, p) then os.remove(bak); return true, keep end
  if had then os.rename(bak, p) end
  os.remove(tmp)
  return false, keep
end

-- the seven's paths as REAPER names them in [defcfg]: each one reaper-jsfx.ini lists, plus ReaPack's
-- place when it is not scanned yet; GainKit's first
local function six_paths()
  local paths, have = {}, {}
  local function put(p) if not have[p] then have[p] = true; paths[#paths + 1] = p end end
  local ini = slurp(RES .. "/reaper-jsfx.ini") or ""
  for _, f in ipairs(SEVEN) do
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

-- set the seven's [defcfg] lines to the place, every other bit and line kept
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

local function is_seven(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if not ok or id == "" then return false end
  local name = (id:match("[^/\\]+$") or ""):lower()   -- the file name, exactly (as is_gainkit)
  for _, s in ipairs(SEVEN) do if name == s:lower() then return true end end
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
  for ln in (ch .. "\n"):gmatch("(.-)\n") do
    local line = ln   -- a copy: Lua 5.5 will not let a loop assign its own variable
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
  if not tr or not is_seven(tr, pos) then return end
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

-- DOCK (mode 4): a double-click on one of the seven's names (rk_theme's rkth_dock_name; the user, 2026-10-03:
-- "swing i double click the logo it docks"). Its track and chain position become GUIDs for the ReaKit FX dock,
-- which takes it in, or pops it out when it is docked already; the dock is opened first when it is closed. The
-- request is written BEFORE the dock starts (its start leaves this one alone: it carries the time, and the dock
-- drops one older than 5 s). A track's own chain only (flags 0): the dock shows no take, input or container FX.
local function dock_request(ti, pos, fl)
  if fl ~= 0 then return end
  local tr
  if ti == -1 then tr = r.GetMasterTrack(0) elseif ti >= 0 then tr = r.GetTrack(0, ti) end
  if not tr or pos < 0 or pos >= r.TrackFX_GetCount(tr) then return end
  local fg = r.TrackFX_GetFXGUID(tr, pos)
  if not fg then return end
  r.SetExtState(DOCK_EXT, "show_req", r.GetTrackGUID(tr) .. "|" .. fg .. "|" .. string.format("%.3f", r.time_precise()), false)
  reopen_dock()                              -- returns at once when the dock is up
end

-- LONG VIEW (modes 5 and 6). REAPER sizes a strip by the plugin's @gfx shape, so a long strip is a second copy of the
-- plugin with a taller one, in a dot folder beside its own (Eon_JSFX/.tall/, made by the bundle's
-- .dev_tests/gk_tall_sync.py; REAPER's FX browser skips dot folders). The arrow on a GainKit's or a Filter's strip
-- asks: 5 = to the tall copy, 6 = back. The swap is the plugin's own saved block with its file pointed at the other
-- copy, loaded on a temporary track and moved into place (TrackFX_CopyToTrack), the original and the temporary track
-- deleted, all one undo step. What the block holds comes along -- settings and saved state, automation and its items,
-- modulation, MIDI learn, the name, wet, bypass, pins, oversampling, the mixer mark -- with the GUID, while the other
-- plugins keep running (rewriting the track's chunk in place would silence the track for ~130 ms). The user presets of
-- the copy left behind are merged into the other's file by name (REAPER files them by the plugin's path), and an open
-- window keeps its size. In a mixer strip, the long swap also grows the strip's effect area so the effects under the
-- plugin keep their room, and the short swap shrinks it back (FIT, below).
local NL = "\n"
-- The plugins with a long view, by their FILE (the exact name, as is_gainkit): the name for the undo point, the tall
-- copy's @gfx height over the short one's (FIT counts what a squeezed tall face lacks; the heights must match the
-- bundle's .dev_tests/gk_tall_sync.py, which writes the tall copies, and EON Floatter's TALL_GFX_H), and the kind its
-- hand-over publishes (rk_handoff.jsfx-inc: kind * 100 + its state layout's version, the plugin's rk_ho_init).
local LONG = { ["channeltool_reakit.jsfx"] = { name = "GainKit", k = 900 / 540, ho = 102 },
               ["filter_reakit.jsfx"]      = { name = "Filter",  k = 588 / 283, ho = 201 } }
local function long_kind(tr, f)                 -- the file name whole (its folders cut off), case-folded, looked up
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  return ok and LONG[(id:gsub("^.*[/\\]", "")):lower()] or nil
end
local function lines_of(s) local t = {}; for l in (s .. NL):gmatch("(.-)" .. NL) do t[#t + 1] = l end; return t end
local function esc(s) return (s:gsub("%p", "%%%0")) end
-- the plugin's block in a track chunk, by its GUID: from the line after the previous plugin's WAK (or the chain's head)
-- to its own WAK; j = its <JS line
local function fx_block(L, guid)
  local fi
  for i, l in ipairs(L) do if l:match("^%s*FXID%s+" .. esc(guid)) then fi = i; break end end
  if not fi then return end
  local i1
  for i = fi, #L do if L[i]:match("^%s*WAK%s") then i1 = i; break end end
  local j = fi
  while j > 1 and not L[j]:match("^%s*<JS%s") do j = j - 1 end
  if not i1 or not L[j]:match("^%s*<JS%s") then return end
  local i0 = j
  while i0 > 1 do
    local p = L[i0 - 1]
    if p:match("^%s*WAK%s") or p:match("^%s*DOCKED%s") or p:match("^%s*<FXCHAIN") or p:match("^%s*<CONTAINER")
       or p:match("^%s*SHOW%s") or p:match("^%s*LASTSEL%s") or p:match("^%s*CONTAINER_CFG") or p:match("^%s*>%s*$") then break end
    i0 = i0 - 1
  end
  return i0, i1, j
end
local function js_path(line)
  local rest = line:match("^%s*<JS%s+(.*)$") or ""
  return rest:match('^"([^"]*)"') or rest:match("^(%S+)")
end
local function set_js_path(line, newpath)
  local head, rest = line:match("^(%s*<JS%s+)(.*)$")
  local after = rest:match('^"[^"]*"(.*)$') or rest:match("^%S+(.*)$") or ""
  return head .. '"' .. newpath .. '"' .. after
end
-- the other copy, spelled as the <JS line spells this one: <dir>/FX/<file> <-> <dir>/.tall/<file>; nil when the
-- plugin is already the copy asked for
local function other_copy(path, to_tall)
  local dir, file = path:match("^(.-)([^/\\]+)$")
  local up, sub, sep = (dir or ""):match("^(.-)([^/\\]+)([/\\])$")
  if not sub then return nil end
  if (sub:lower() == ".tall") == to_tall then return nil end
  return up .. (to_tall and ".tall" or "FX") .. sep .. file
end
local function js_file(path)                  -- a <JS path on disk: relative to Effects unless it is absolute
  if path:match("^%a:[/\\]") or path:match("^[/\\]") then return path end
  return RES .. "/Effects/" .. path
end
-- the address of the plugin with this GUID whose file ends with this path (a copy and its swap share the GUID while
-- both are on the track; no path: any file); containers searched
local function find_fx(tr, guid, path)
  local tail, hit = path and path:gsub("\\", "/"):lower(), nil
  local function walk(f)
    if hit then return end
    if r.TrackFX_GetFXGUID(tr, f) == guid then
      local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
      id = ok and id:gsub("\\", "/"):lower() or ""
      if not tail or id:sub(-#tail) == tail then hit = f; return end
    end
    local ok, n = r.TrackFX_GetNamedConfigParm(tr, f, "container_count")
    if ok then
      for i = 0, (tonumber(n) or 0) - 1 do
        local ok2, c = r.TrackFX_GetNamedConfigParm(tr, f, "container_item." .. i)
        if ok2 and tonumber(c) then walk(tonumber(c)) end
      end
    end
  end
  for f = 0, r.TrackFX_GetCount(tr) - 1 do walk(f) end
  return hit
end
-- A user preset file (REAPER's ini: [General] with NbPresets=, then [Preset0] .. with Data= / Len= / Name=): its
-- [General] lines and its presets in order; nil when there is none. In order BY NUMBER: REAPER writes the sections
-- sorted as text ([Preset0], [Preset1], [Preset10], [Preset11], [Preset2] ..) and lists them by number, so a file of
-- eleven or more read in file order came out shuffled in the other copy's list (GainKit's 13 with its LOOK presets,
-- 2026-10-09: the long view listed Init, Pad -6 dB, Headphone cue, Master, Default look, Pad -12 dB ..).
local function read_presets(p)
  local txt = p and p ~= "" and slurp(p)
  if not txt then return nil end
  local gen, list, cur = {}, {}, nil
  for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
    local s = line:match("^%[(.-)%]%s*$")
    if s then
      cur = s == "General" and "general" or nil
      if s:match("^Preset%d+$") then cur = { lines = {}, n = tonumber(s:match("%d+")) }; list[#list + 1] = cur end
    elseif line:match("%S") then
      if cur == "general" then gen[#gen + 1] = line
      elseif cur then
        cur.lines[#cur.lines + 1] = line
        cur.name = line:match("^Name=(.*)$") or cur.name
      end
    end
  end
  table.sort(list, function(a, b) return a.n < b.n end)
  return gen, list
end
-- every preset of from_file that to_file has no preset of that name for, added to it (written beside and moved in)
local function merge_presets(from_file, to_file)
  if not to_file or to_file == "" or from_file == to_file then return end
  local sgen, src = read_presets(from_file)
  if not src or #src == 0 then return end
  local gen, dst = read_presets(to_file)
  gen, dst = gen or sgen, dst or {}           -- a file not there yet takes the other's [General] (its import stamp)
  local have, added = {}, 0
  for _, p in ipairs(dst) do if p.name then have[p.name] = true end end
  for _, p in ipairs(src) do
    if p.name and not have[p.name] then dst[#dst + 1] = p; have[p.name] = true; added = added + 1 end
  end
  if added == 0 then return end
  local out = { "[General]" }
  for _, l in ipairs(gen) do if not l:match("^NbPresets=") then out[#out + 1] = l end end
  out[#out + 1] = "NbPresets=" .. #dst
  for i, p in ipairs(dst) do
    out[#out + 1] = ""
    out[#out + 1] = ("[Preset%d]"):format(i - 1)
    for _, l in ipairs(p.lines) do out[#out + 1] = l end
  end
  replace_file(to_file, table.concat(out, "\r\n") .. "\r\n")
end
-- REAPER is writing automation on this track: playing or recording (not paused) with the track, or the global
-- override, in Touch, Write, Latch or Latch Preview. A swap then waits for the transport to stop: done while Write
-- wrote, the gain's envelope kept the OLD values for ~0.3 s from the swap on (gk_long_run.py case H, 2026-10-08).
local function writing(tr)
  local ps = r.GetPlayState()
  if ps & 5 == 0 or ps & 2 == 2 then return false end
  local m = r.GetGlobalAutomationOverride and r.GetGlobalAutomationOverride() or -1
  if m < 0 then m = r.GetMediaTrackInfo_Value(tr, "I_AUTOMODE") end
  return m >= 2 and m <= 5
end
-- The strip's room. A strip's effect area has a fixed height and its embedded faces fill it from the top, so a tall
-- copy would leave the effects under it only what was left. Around a long swap of a GainKit or a Filter shown in a
-- mixer strip on screen, that strip's effect area grows by the room the effects under it lost (F_MCP_FXSEND_SCALE, the
-- strip's own share for effects and sends: its fader gets that much shorter); the short swap puts the old value back, unless it
-- was changed since. All of it from REAPER's own map, never a theme's numbers: the strip windows (REAPERMCPDisplay)
-- and the strip by GetTrackFromPoint, as the ReaKit FX dock's SLOT finds them, then GetThingFromPoint down its middle
-- ("mcp.fxembed N" a face, "mcp.fxlist N fx:N" an effect's row; "mcp.fxlist N" alone is an empty slot), after a
-- forced repaint that lays the mixer out inside this tick. One trial step gives the px per unit, the value is set and
-- checked (one more step if short). The old and the set value ride in the track's P_EXT, inside the swap's undo
-- point, so an undo, a save and a reopen keep them with the strip. The strip's own value comes back only when no
-- tall copy is left in its chain: a second long plugin on it (GainKit or Filter) grows it further and keeps the first
-- old value; a long one deleted or moved away is noticed within a second (FIT.sweep; a frozen track waits for its
-- unfreeze). Sandbox: the bundle's .dev_tests/rk_vu_audit/gk_fxarea_run.py (REAPER's layout, box plugins), gk_fit_run.py
-- (this script, GainKit and a plugin under it) and fl_long_run.py (the Filter's).
local FIT = { KEY = "P_EXT:EON_GK_LONG_FIT", t = 0 }
function FIT.ok()
  return r.JS_Window_ArrayAllChild and r.JS_Window_ListAllTop and r.JS_Window_Update and r.JS_Window_InvalidateRect
     and r.GetThingFromPoint and r.GetTrackFromPoint and r.new_array and true or false
end
function FIT.displays()                         -- the mixer's strip windows on screen (docked: under the main window;
  local main = r.GetMainHwnd()                  -- floating: under a top-level window the main window owns)
  local roots, out = { main }, {}
  local _, tops = r.JS_Window_ListAllTop()
  for a in (tops or ""):gmatch("[^,]+") do
    local h = r.JS_Window_HandleFromAddress(tonumber(a))
    if h and h ~= main and r.JS_Window_IsVisible(h) and r.JS_Window_GetRelated(h, "OWNER") == main then roots[#roots + 1] = h end
  end
  for _, root in ipairs(roots) do
    local arr = r.new_array({}, 512)
    local got = r.JS_Window_ArrayAllChild(root, arr)        -- too small: a NEGATIVE count and nothing filled
    if got and got < 0 then arr = r.new_array({}, -got + 16); r.JS_Window_ArrayAllChild(root, arr) end
    for _, ad in ipairs(arr.table()) do
      local c = ad ~= 0 and r.JS_Window_HandleFromAddress(ad)
      if c and r.JS_Window_GetClassName(c) == "REAPERMCPDisplay" and r.JS_Window_IsVisible(c) then
        local _, L, T, R, B = r.JS_Window_GetRect(c)
        if R - L > 40 and B - T > 80 then out[#out + 1] = { h = c, L = L, T = T, R = R, B = B } end
      end
    end
  end
  return out
end
-- the track's strip, laid out now: its effect list down the strip's middle -- emb[N] / row[N] the px of effect N's
-- face / rows, bot the list's last pixel (screen y); nil when the mixer does not show the strip
function FIT.list(tr)
  if r.GetToggleCommandState(40078) ~= 1 then return end
  local ds = FIT.displays()
  for _, d in ipairs(ds) do r.JS_Window_InvalidateRect(d.h, 0, 0, d.R - d.L, d.B - d.T, true); r.JS_Window_Update(d.h) end
  for _, d in ipairs(ds) do
    -- a row the strip answers on: a track's fader row; the master's strip (its own window, titled "master") answers
    -- nothing across its meter, only higher up (measured 2026-10-08, gk_fit_master_probe.lua)
    for _, f in ipairs({ 0.72, 0.5, 0.9, 0.25, 0.1 }) do
      local y, x0, x1 = d.T + math.floor((d.B - d.T) * f), nil, nil
      for x = d.L + 1, d.R - 1, 2 do if r.GetTrackFromPoint(x, y) == tr then x0 = x0 or x; x1 = x end end
      if x0 then
        local x, L, past = math.floor((x0 + x1) / 2), { emb = {}, row = {} }, 0
        for yy = d.T, d.B do
          local t, info = r.GetThingFromPoint(x, yy)
          info = t == tr and info or ""
          local n = info:match("^mcp%.fxembed (%d+)")
          local m = info:match("^mcp%.fxlist (%d+) fx:")
          if n then L.emb[tonumber(n)] = (L.emb[tonumber(n)] or 0) + 1 end
          if m then L.row[tonumber(m)] = (L.row[tonumber(m)] or 0) + 1 end
          if info:find("^mcp%.fxembed") or info:find("^mcp%.fxlist") then L.bot, past = yy, 0
          elseif L.bot then past = past + 1; if past > 60 then break end end
        end
        return L.bot and L or nil
      end
    end
  end
end
function FIT.under(L, k)                        -- the px the effects after effect k have in the list
  local s = 0
  for i, h in pairs(L.emb) do if i > k then s = s + h end end
  for i, h in pairs(L.row) do if i > k then s = s + h end end
  return s
end
function FIT.set(tr, v) r.SetMediaTrackInfo_Value(tr, "F_MCP_FXSEND_SCALE", v); r.TrackList_AdjustWindows(false) end
-- after a long swap: grow the strip's area until the effects after effect k have the room they had (before = FIT.list
-- then); the old and the set value kept in the track's P_EXT. tall_k: the tall copy's @gfx height over the short one's
-- (LONG's k: GainKit 900 / 540, the Filter 588 / 283)
function FIT.grow(tr, k, before, tall_k)
  local now = FIT.list(tr)
  if not now then return end
  local need = FIT.under(before, k) - FIT.under(now, k)
  if need <= 1 then return end
  local s0 = r.GetMediaTrackInfo_Value(tr, "F_MCP_FXSEND_SCALE")
  local trial = math.min(1, s0 + 0.1)
  if trial - s0 < 0.005 then return end
  FIT.set(tr, trial)
  local t2 = FIT.list(tr)
  local per = t2 and (t2.bot - now.bot) / (trial - s0) or 0
  if per < 20 then FIT.set(tr, s0); return end              -- this theme does not grow the list with it: as it was
  -- the tall face itself squeezed (another tall face above it on the strip) takes the first of any new room: its full
  -- height is the short face's times tall_k (the two copies' @gfx), so count what it lacks too (without it, two long
  -- plugins on one strip stopped short and were put back)
  local nat = math.floor((before.emb[k] or 0) * (tall_k or 900 / 540) + 0.5)
  local function lacks(L) return math.max(0, nat - (L.emb[k] or 0) - 2) end
  local want, cur, short = math.min(1, s0 + (need + lacks(now)) / per), s0, need
  for _ = 1, 3 do                                            -- set, read back, and up to two more steps if short
    FIT.set(tr, want); cur = want
    local t3 = FIT.list(tr)
    if not t3 then short = need; break end
    short = FIT.under(before, k) - FIT.under(t3, k)
    if short <= 1 or want >= 1 then break end
    want = math.min(1, want + (short + lacks(t3)) / per)
  end
  -- all of the room or none: a strip that cannot grow that far (the master's, its meter keeps the height: 2026-10-08)
  -- keeps its fader and the squeeze, as it was
  if short > 2 then FIT.set(tr, s0); return end
  local old, set = FIT.rec(tr)                               -- grown already by another long plugin, and not changed
  if not (old and math.abs(s0 - set) < 1e-4) then old = s0 end   -- since: the strip's own value stays the one to restore
  r.GetSetMediaTrackInfo_String(tr, FIT.KEY, ("%.6f %.6f"):format(old, cur), true)
end
function FIT.rec(tr)                            -- the record: the strip's own value and the one set, or nil
  local ok, v = r.GetSetMediaTrackInfo_String(tr, FIT.KEY, "", false)
  local o, s = (ok and v or ""):match("^(%S+) (%S+)$")
  if tonumber(o) and tonumber(s) then return tonumber(o), tonumber(s) end
end
function FIT.tall_left(tr)                      -- a tall copy still in the chain (top level: only those grow a strip)
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
    if ok and id:gsub("\\", "/"):lower():find("/.tall/", 1, true) then return true end
  end
  return false
end
-- after a short swap (or a long plugin gone): the strip's own value back once no tall copy is left in its chain,
-- unless the strip's share was changed since it was set; the record removed then either way
function FIT.back(tr)
  local ok, v = r.GetSetMediaTrackInfo_String(tr, FIT.KEY, "", false)
  if not ok or v == "" or FIT.tall_left(tr) then return end
  local s0, set = FIT.rec(tr)
  if s0 and math.abs(r.GetMediaTrackInfo_Value(tr, "F_MCP_FXSEND_SCALE") - set) < 1e-4 then FIT.set(tr, s0) end
  r.GetSetMediaTrackInfo_String(tr, FIT.KEY, "", true)
end
-- once a second: a strip still grown whose long plugin was deleted or moved to another track gets its value back.
-- No undo point of its own. REAPER's undo puts back only what the undone step changed, so an undo of the delete
-- brings the long plugin back on a strip at its own value with no record (consistent: it squeezes as with the mixer
-- shut until its next long swap; measured 2026-10-08, gk_fit_sweep_probe.lua S2)
function FIT.sweep()
  for i = -1, r.CountTracks(0) - 1 do
    local tr = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
    local ok, v = r.GetSetMediaTrackInfo_String(tr, FIT.KEY, "", false)
    if ok and v ~= "" and not FIT.tall_left(tr) then
      local _, ch = r.GetTrackStateChunk(tr, "", false)      -- a frozen track keeps its plugins aside: not gone
      if not (ch or ""):find("\n%s*<FREEZE") then FIT.back(tr) end
    end
  end
end
local pend = {}                                -- the swaps that wait, by plugin GUID: { tg = its track's GUID, to_tall }
-- The seamless hand-over (rk_handoff.jsfx-inc): a new copy starts from rest, so a swap would click whenever the
-- plugin's cuts or gain are set. The plugin, armed by the swap's own request, writes its DSP state at the end of each
-- audio block into a slot of the EON_RKFX_HANDOFF band; the new copy takes it over at its first block, which follows
-- the old copy's last one exactly. So the swap waits until the slot is fresh: up to HO.WAIT (an engine that runs no
-- blocks publishes nothing; then the swap is done without it).
local HO = { BASE = 31367680, N = 16, STRIDE = 96, WAIT = 0.3, wait = {} }   -- wait: by plugin GUID, { tg, to_tall, t0 }
-- the slot of a fresh publish of this kind at this placement, not taken over yet (a copy swapped in a moment ago leaves
-- its predecessor's slot taken: a second ask waits for its own; a slot reserved and not yet written reads -1), or nil.
-- Flags not compared: a request's are the plugin's own, and a take's FX never gets here. The swap writes its go into
-- the slot (+11) right before it moves the new copy in: only that slot can be taken over, so a plugin the user inserts
-- at the same place while a swap waits takes nothing.
function HO.ready(ti, pos, kind)
  local now = r.time_precise()
  for i = 0, HO.N - 1 do
    local s = HO.BASE + i * HO.STRIDE
    if r.gmem_read(s) > 0 and r.gmem_read(s + 1) == kind and r.gmem_read(s + 2) == ti and r.gmem_read(s + 3) == pos
       and r.gmem_read(s + 8) == 0 and math.abs(now - r.gmem_read(s + 6)) < 0.25 then return s end
  end
end
local function swap_length(ti, pos, fl, to_tall)
  if fl % 2 == 1 then return end                                   -- a take's FX: not a strip
  local tr
  if ti == -1 then tr = r.GetMasterTrack(0) elseif ti >= 0 then tr = r.GetTrack(0, ti) end
  local kind = tr and long_kind(tr, pos)                           -- GainKit or the Filter (LONG), by its file
  if not kind then return end
  local guid = r.TrackFX_GetFXGUID(tr, pos)
  if guid and writing(tr) then                                     -- after the transport stops (pend_tick)
    pend[guid] = { tg = r.GetTrackGUID(tr), to_tall = to_tall }
    HO.wait[guid] = nil
    r.gmem_write(EMB + 4, 1)
    return
  end
  local hos = guid and HO.ready(ti, pos, kind.ho)                  -- the hand-over: its state published first (HO.tick)
  if guid and not hos then
    local w = HO.wait[guid]
    if not w then HO.wait[guid] = { tg = r.GetTrackGUID(tr), to_tall = to_tall, t0 = r.time_precise() }; return end
    if r.time_precise() - w.t0 < HO.WAIT then return end
  end
  if guid then HO.wait[guid] = nil end
  local ok, ch = r.GetTrackStateChunk(tr, "", false)
  if not guid or not ok or not ch then return end
  local L = lines_of(ch)
  local i0, i1, j = fx_block(L, guid)
  if not j then return end
  local path = js_path(L[j])
  local other = path and other_copy(path, to_tall)
  if not other or not r.file_exists(js_file(other)) then return end
  local blk = {}
  for i = i0, i1 do blk[#blk + 1] = (i == j) and set_js_path(L[i], other) or L[i] end
  local presets_from = r.TrackFX_GetUserPresetFilename(tr, pos, "")
  local rect                                                       -- an open window keeps its size
  local hw = r.TrackFX_GetOpen(tr, pos) and r.TrackFX_GetFloatingWindow(tr, pos)
  if hw and r.JS_Window_GetRect then
    local okr, wl, wt, wr, wb = r.JS_Window_GetRect(hw)
    if okr then rect = { wl, wt, wr - wl, wb - wt } end
  end
  local before = to_tall and FIT.ok() and FIT.list(tr) or nil     -- the strip as it is: the plugin's face in it, on screen
  if before and not before.emb[pos] then before = nil end
  r.Undo_BeginBlock()
  r.PreventUIRefresh(1)
  local n = r.CountTracks(0)
  r.InsertTrackAtIndex(n, false)
  local tmp, new = r.GetTrack(0, n), nil
  if tmp and r.SetTrackStateChunk(tmp, "<TRACK" .. NL .. "NAME __gainkit_swap" .. NL .. "<FXCHAIN" .. NL .. "SHOW 0" .. NL ..
       "LASTSEL 0" .. NL .. "DOCKED 0" .. NL .. table.concat(blk, NL) .. NL .. ">" .. NL .. ">", false)
     and r.TrackFX_GetCount(tmp) == 1 then
    -- the go: this swap's new copy may take that slot over (only within 0.25 s of it). Written HERE, once the copy is
    -- built on the temporary track: loading and compiling it takes ~0.33 s, so a go written before was stale on arrival
    if hos then r.gmem_write(hos + 11, r.time_precise()) end
    r.TrackFX_CopyToTrack(tmp, 0, tr, pos, true)
    new = find_fx(tr, guid, other)
    local old = new and find_fx(tr, guid, path)
    if old then r.TrackFX_Delete(tr, old); new = find_fx(tr, guid, other) end
  end
  if tmp then r.DeleteTrack(tmp) end
  r.PreventUIRefresh(-1)
  if new and to_tall and before then FIT.grow(tr, new, before, kind.k)   -- the strip's room, in the same undo point
  elseif new and not to_tall then FIT.back(tr) end
  r.Undo_EndBlock(kind.name .. (to_tall and ": long view" or ": short view"), -1)
  if not new then return end
  merge_presets(presets_from, r.TrackFX_GetUserPresetFilename(tr, new, ""))
  if rect then
    local nhw = r.TrackFX_GetFloatingWindow(tr, new)
    if nhw then r.JS_Window_SetPosition(nhw, rect[1], rect[2], rect[3], rect[4]) end
  end
end
-- the swaps that waited: each done once REAPER stops writing on its track, wherever the plugin is then (by its GUID:
-- a track or a plugin moved meanwhile is followed; one deleted drops its swap). +4 stays 1 while any waits, which keeps
-- the arrow that asked lit.
local function pend_tick()
  if next(pend) == nil then return end
  for fg, p in pairs(pend) do
    local tr
    for i = -1, r.CountTracks(0) - 1 do
      local t = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
      if r.GetTrackGUID(t) == p.tg then tr = t; break end
    end
    if not tr or not writing(tr) then
      pend[fg] = nil
      local pos = tr and find_fx(tr, fg)
      if pos then swap_length(tr == r.GetMasterTrack(0) and -1 or r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") - 1, pos, 0, p.to_tall) end
    end
  end
  if next(pend) == nil then r.gmem_write(EMB + 4, 0) end
end
-- the swaps that wait for the hand-over's publish: asked again every tick, wherever the plugin is (by its GUID; one
-- deleted drops its swap); swap_length does it once the state is published, or HO.WAIT after the ask without it
function HO.tick()
  if next(HO.wait) == nil then return end
  for fg, w in pairs(HO.wait) do
    local tr
    for i = -1, r.CountTracks(0) - 1 do
      local t = i < 0 and r.GetMasterTrack(0) or r.GetTrack(0, i)
      if r.GetTrackGUID(t) == w.tg then tr = t; break end
    end
    local pos = tr and find_fx(tr, fg)
    if not pos then HO.wait[fg] = nil
    else swap_length(tr == r.GetMasterTrack(0) and -1 or r.GetMediaTrackInfo_Value(tr, "IP_TRACKNUMBER") - 1, pos, 0, w.to_tall) end
  end
end

-- A copy of the seven at a path REAPER has no [defcfg] line for yet opens un-embedded. The start-up action set the
-- lines ONCE (its embed_defaults flag), for the paths it saw then; a reinstall or a moved folder later gives new
-- path names, and those never got the default (found 2026-10-07 on the user's machine: lines for an older folder
-- layout, none for the paths in use). So at every start each path of the seven that has not been seen before gets the
-- place the others already have (the first one with a line), MCP when none has one, and is remembered as seen
-- (ExtState embed_filled): a line the user later changes or removes stays as they left it.
do
  local function fill_new_paths()
    local list = six_paths()
    if #list == 0 then return end
    local seen = r.GetExtState("EON_ReaKitFX", "embed_filled")
    local function enc(p) return (p:gsub("%%", "%%25"):gsub("|", "%%7C")) end   -- a "|" in a Linux / macOS path
    local fresh = {}                                   -- must not make two paths one (outside review D, 2026-10-07)
    for _, p in ipairs(list) do if not seen:find("|" .. enc(p) .. "|", 1, true) then fresh[#fresh + 1] = p end end
    if #fresh == 0 then return end
    local function defcfg(txt)                         -- the first [defcfg]'s lines: REAPER reads that one only
      if txt:sub(1, 3) == "\239\187\191" then txt = txt:sub(4) end
      local has, in_def = {}, false
      for line in (txt .. "\n"):gmatch("(.-)\r?\n") do
        local s = line:match("^%[(.-)%]%s*$")
        if s then
          if in_def then break end
          in_def = (s == "defcfg")
        elseif in_def then
          local k, v = line:match("^(.-)=(%-?%d+)%s*$")
          if k then has[k] = tonumber(v) or 0 end
        end
      end
      return has
    end
    local txt = read_opt(OPT)
    if not txt then return end                         -- locked for a moment: the next start tries again
    local has = defcfg(txt)
    local mode = 1                                     -- MCP when none of the seven has a line yet
    for _, p in ipairs(list) do if has[p] then mode = place_of(has[p]); break end end
    local missing = {}
    for _, p in ipairs(fresh) do if not has[p] then missing[#missing + 1] = p end end
    if #missing > 0 then write_default(missing, mode) end
    local after = defcfg(read_opt(OPT) or "")         -- remember a path only once its line is really there, in the
    for _, p in ipairs(fresh) do                       -- section REAPER reads (outside review D, 2026-10-07)
      if has[p] or mode == 3 or after[p] then seen = seen .. (seen == "" and "|" or "") .. enc(p) .. "|" end
    end
    r.SetExtState("EON_ReaKitFX", "embed_filled", seen, true)
  end
  fill_new_paths()
end

local served = r.gmem_read(EMB + 12)       -- a request older than this run is not ours to serve
local hb_last, def_t, paths = 0, -10, nil
local function embed_tick(now)
  local t = os.time()
  if t ~= hb_last then hb_last = t; r.gmem_write(EMB, t); r.gmem_write(EMB + 3, 7) end   -- +3: the long view served (7: GainKit's and the Filter's)
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
    elseif mode == 4 then
      dock_request(math.floor(r.gmem_read(EMB + 9) + 0.5), math.floor(r.gmem_read(EMB + 10) + 0.5),
                   math.floor(r.gmem_read(EMB + 11) + 0.5))
    elseif mode == 5 or mode == 6 then
      swap_length(math.floor(r.gmem_read(EMB + 9) + 0.5), math.floor(r.gmem_read(EMB + 10) + 0.5),
                  math.floor(r.gmem_read(EMB + 11) + 0.5), mode == 5)
    end
    r.gmem_write(EMB + 2, g)
  end
  if now - def_t >= 5 then                  -- the default, again every 5 s (the FX browser can change it)
    def_t = now
    paths = paths or six_paths()
    local d = read_default(paths); if d then r.gmem_write(EMB + 1, d) end
  end
end

-- Past MAXT tracks a GainKit gets nothing from Plus (README: "serves the first 512 tracks"). Say so ONCE per project
-- per session, and only when a GainKit really sits past it; looked for at most every 10 s (outside audit 2026-10-07)
local over = { told = {}, t = -10 }
local function tick()
  local total = r.CountTracks(0)
  local n = math.min(total, MAXT)
  for i = 0, n - 1 do
    local tr = r.GetTrack(0, i)
    if has_gainkit(tr) then publish(i, tr) else clear(i) end
  end
  for i = n, MAXT - 1 do if last[i] then clear(i) end end
  local proj, now = tostring(r.EnumProjects(-1)), r.time_precise()
  if total > MAXT and not over.told[proj] and now - over.t >= 10 then
    over.t = now
    for i = MAXT, total - 1 do
      if has_gainkit(r.GetTrack(0, i)) then
        over.told[proj] = true
        r.ShowConsoleMsg(("GainKit Plus: this project has %d tracks. GainKit Plus gives the track colour and icon "
          .. "to the GainKits on the first %d tracks and the master only; the GainKit on track %d and any after it go "
          .. "without them.\n"):format(total, MAXT, i + 1))
        break
      end
    end
  end
  local m = r.GetMasterTrack(0)
  if has_gainkit(m) then publish(MASTER, m, project_name()) else clear(MASTER) end
end

local t_last = 0
local function loop()
  local now = r.time_precise()
  if (tonumber(r.GetExtState(EXT, "stop")) or 0) > now0 then return end   -- asked to stop: no stamp, atexit cleans up
  r.SetExtState(EXT, "alive", tostring(now), false)          -- the heartbeat a relaunch reads
  local wall = os.time()
  if wall - wall_t >= 5 then wall_t = wall; r.SetExtState(EXT, "wall", tostring(wall), true) end   -- the dock's reopen
  if dock_reopen_at and now >= dock_reopen_at then dock_reopen_at = nil; reopen_dock() end
  rename_tick()
  embed_tick(now)
  pend_tick()
  HO.tick()
  if now - t_last >= 0.3 then t_last = now; tick() end
  if now - FIT.t >= 1 then FIT.t = now; FIT.sweep() end
  r.defer(loop)
end

r.atexit(function()
  for i = 0, MASTER do if last[i] then r.gmem_write(BASE + i * STRIDE, 0) end end
  r.gmem_write(EMB, 0)                                         -- the EMBED row says NEEDS PLUS at once
  r.gmem_write(EMB + 3, 0)                                     -- and no strip offers the long view
  r.gmem_write(EMB + 4, 0)                                     -- nor shows a swap waiting
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end)
loop()
