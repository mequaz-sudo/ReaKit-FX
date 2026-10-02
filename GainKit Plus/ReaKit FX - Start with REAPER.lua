-- ReaKit FX -- start everything with REAPER, in one press. Puts GainKit Plus into
-- Scripts/__startup.lua (the same as running "GainKit Plus - Start with REAPER") when it is not
-- there yet, and starts EON Floatter once when it has not registered itself yet -- Floatter
-- writes its own start-up block on its first run. Running this again changes nothing: each
-- part is skipped when it is already in place. Once, it sets the six to open embedded in the
-- mixer strip (REAPER's own per-plugin default), and offers to raise REAPER's meter refresh to
-- 120 a second, so the plugin faces in the mixer strips answer quicker (next start).
-- One message says what was done. MIT, EON Studios, 2026.
local r = reaper
local _, own = r.get_action_context()
local sep = own:find("\\", 1, true) and "\\" or "/"
local dir = own:match("^(.*)[\\/]") or "."
local res = r.GetResourcePath()
local STARTUP = res .. sep .. "Scripts" .. sep .. "__startup.lua"
local PLUS_SETUP = dir .. sep .. "GainKit Plus - Start with REAPER.lua"
local PLUS = dir .. sep .. "GainKit Plus.lua"
local FLOATTERS = {                                   -- wherever ReaPack put it
  res .. sep .. "Scripts" .. sep .. "ReaKit FX" .. sep .. "EON Floatter" .. sep .. "EON_Floatter.lua",
  res .. sep .. "Scripts" .. sep .. "ReaKit" .. sep .. "Floatter" .. sep .. "EON_Floatter.lua",
}

local function read(p) local fh = io.open(p, "rb"); if not fh then return nil end; local s = fh:read("*a"); fh:close(); return s end
local function exists(p) local fh = io.open(p, "r"); if fh then fh:close(); return true end; return false end
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
local startup = read(STARTUP) or ""
local done = {}
local need_plus = false

-- 1. GainKit Plus: its action is a toggle, so only run it when its block is absent
if startup:find("GainKit Plus: start with REAPER", 1, true) then
  done[#done + 1] = "GainKit Plus already starts with REAPER."
elseif not exists(PLUS_SETUP) then
  done[#done + 1] = "GainKit Plus - Start with REAPER.lua was not found beside this script."
else
  local was_quiet = r.GetExtState("EON_GainKitPlus", "quiet")
  r.SetExtState("EON_GainKitPlus", "quiet", "1", false)          -- no dialog from it; ours below
  local ok, c = pcall(r.AddRemoveReaScript, true, 0, PLUS_SETUP, true)
  if ok and c and c > 0 then r.Main_OnCommand(c, 0) end
  if was_quiet == "1" then r.SetExtState("EON_GainKitPlus", "quiet", "1", false) else r.DeleteExtState("EON_GainKitPlus", "quiet", false) end
  startup = read(STARTUP) or ""
  done[#done + 1] = startup:find("GainKit Plus: start with REAPER", 1, true)
    and "GainKit Plus starts with REAPER from now on (and is running now)."
    or "GainKit Plus could not be added to Scripts/__startup.lua."
  need_plus = true   -- the setup starts Plus itself, but not when it is launched from a launched action: checked below
end

-- 1b. The six open embedded in the mixer strip, the way REAPER does it for any plugin: its FX
-- browser's "Default settings for new instances > Show embedded UI in MCP" is bit 4 of the
-- plugin's line in reaper-fxoptions.ini [defcfg], and REAPER reads that file at every insert
-- (measured, 2026-10-01). Each install path REAPER lists for the six (reaper-jsfx.ini) gets the
-- bit, the line's other bits kept. Once: a plugin the user later sets back stays as they set it.
local FREE6 = { "ChannelTool_ReaKit.jsfx", "Saturation_ReaKit.jsfx", "3BandEQ_ReaKit.jsfx",
                "DDC_ReaKit.jsfx", "DeEsser_ReaKit.jsfx", "StereoWidth_ReaKit.jsfx" }
local function embed_defaults()
  if r.GetExtState("EON_ReaKitFX", "embed_defaults") == "1" then return nil end
  local paths, have = {}, {}
  for p in (read(res .. sep .. "reaper-jsfx.ini") or ""):gmatch('NAME%s+"?([^"\r\n]-%.jsfx)"?%s') do
    for _, f in ipairs(FREE6) do
      if (p == f or p:sub(-(#f + 1)) == "/" .. f) and not have[p] then have[p] = true; paths[#paths + 1] = p end
    end
  end
  for _, f in ipairs(FREE6) do                         -- ReaPack's place, if not scanned yet
    local p = "ReaKit FX/FX/Eon_JSFX/FX/" .. f
    if not have[p] and exists(res .. sep .. "Effects" .. sep .. p:gsub("/", sep)) then have[p] = true; paths[#paths + 1] = p end
  end
  if #paths == 0 then return "The ReaKit FX were not found, so they were not set to open in the mixer strip." end
  local opt = res .. sep .. "reaper-fxoptions.ini"
  local txt = read_opt(opt)
  if not txt then return "reaper-fxoptions.ini could not be read just now, so the ReaKit FX were not set to open in the mixer strip; run this again." end
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
  local changed = 0
  for _, p in ipairs(paths) do
    local found = false
    for i = sec_at + 1, #lines do
      if lines[i]:match("^%[") then break end
      local k, v = lines[i]:match("^(.-)=(%-?%d+)%s*$")
      if k == p then
        found = true
        local n = tonumber(v) or 0
        -- MCP: bit 4 on and bit 2 (TCP) off -- with both REAPER uses TCP; the other bits kept
        local n2 = n - (math.floor(n / 2) % 2) * 2 + (math.floor(n / 4) % 2 == 0 and 4 or 0)
        if n2 ~= n then lines[i] = p .. "=" .. n2; changed = changed + 1 end
      end
    end
    if not found then table.insert(lines, sec_end + 1, p .. "=4"); sec_end = sec_end + 1; changed = changed + 1 end
  end
  if changed > 0 and not replace_file(opt, bom .. table.concat(lines, nl) .. nl) then
    return "reaper-fxoptions.ini could not be replaced, so the ReaKit FX were not set to open in the mixer strip; run this again."
  end
  r.SetExtState("EON_ReaKitFX", "embed_defaults", "1", true)
  return "New copies of the six ReaKit FX open embedded in the mixer strip (REAPER's own setting per plugin: FX browser, right-click, Default settings for new instances)."
end
local emsg = embed_defaults()
if emsg then done[#done + 1] = emsg end

-- 2. EON Floatter: registers itself in the start-up file on its first run
if startup:find("-- EON:EON_Floatter BEGIN", 1, true) then
  done[#done + 1] = "EON Floatter already starts with REAPER."
else
  local fl
  for _, p in ipairs(FLOATTERS) do if exists(p) then fl = p; break end end
  if not fl then
    done[#done + 1] = "EON Floatter is not installed (ReaPack: EON Floatter, from the ReaKit FX repository)."
  else
    local ok, c = pcall(r.AddRemoveReaScript, true, 0, fl, true)
    if ok and c and c > 0 then r.Main_OnCommand(c, 0) end
    done[#done + 1] = "EON Floatter is running and starts with REAPER from now on."
  end
end

-- Plus running? Its heartbeat (EXT alive, stamped every tick while it runs) is the sign; a
-- launch from here is one level shallower than the setup's own, which REAPER drops when this
-- action was itself launched by another script. Checked after a short wait, then the one
-- dialog; a probe sets EON_GainKitPlus/quiet and gets none (a modal box from an action run by
-- Main_OnCommand blocks the caller).
local function plus_alive()
  local hb = tonumber(r.GetExtState("EON_GainKitPlus", "alive")) or 0
  local st = tonumber(r.GetExtState("EON_GainKitPlus", "stop")) or 0
  return hb > st and r.time_precise() - hb < 1.0
end
-- 3. Faster mixer strips: REAPER redraws its meters and every plugin face in a strip at its meter
-- rate (Preferences > Appearance > Track meter settings), 30 a second out of the box. Asked ONCE,
-- only raised, never lowered: 120 took a 23-track mixer's strips from 27 to 55 redraws a second
-- (2026-10-01). Written to reaper.ini; REAPER applies it at its next start. A probe answers
-- through EON_ReaKitFX/test_rate ("yes"/"no") instead of the dialog.
local RATE = 120
local NL = string.char(10)
local function meter_rate()
  if not (r.get_config_var_string and r.set_config_var_string) then return end   -- older REAPER
  if r.GetExtState("EON_ReaKitFX", "rate_asked") == "1" then return end
  local ok, cur = r.get_config_var_string("vuupdfreq")
  cur = ok and tonumber(cur) or 30
  if cur >= RATE then r.SetExtState("EON_ReaKitFX", "rate_asked", "1", true); return end
  local yes
  if r.GetExtState("EON_GainKitPlus", "quiet") == "1" then
    local t = r.GetExtState("EON_ReaKitFX", "test_rate")
    if t == "" then return end   -- quiet and no test answer: ask next time instead
    yes = (t == "yes")
  else
    yes = r.MB("Make the mixer strips redraw faster?" .. NL .. NL
      .. "This raises REAPER's meter refresh from " .. math.floor(cur) .. " to " .. RATE
      .. " times a second, so the plugin faces in the mixer and the track panel answer quicker."
      .. " It takes effect the next time REAPER starts." .. NL .. NL
      .. "You can change it any time in Preferences > Appearance > Track meter settings.",
      "ReaKit FX", 4) == 6
  end
  r.SetExtState("EON_ReaKitFX", "rate_asked", "1", true)
  if yes then
    local res = r.set_config_var_string("vuupdfreq", tostring(RATE), 1)
    done[#done + 1] = (res and res > 0)
      and ("Mixer strips redraw " .. RATE .. " times a second from the next start of REAPER.")
      or "REAPER did not take the faster meter refresh; set it in Preferences > Appearance > Track meter settings."
  end
end

local t0, n = r.time_precise(), 0
local function settle()
  n = n + 1
  if need_plus and r.time_precise() - t0 < 1.0 then return r.defer(settle) end
  if need_plus and not plus_alive() and exists(PLUS) then
    local ok, c = pcall(r.AddRemoveReaScript, true, 0, PLUS, true)
    if ok and c and c > 0 then r.Main_OnCommand(c, 0) end
  end
  meter_rate()
  if r.GetExtState("EON_GainKitPlus", "quiet") ~= "1" then r.MB(table.concat(done, NL), "ReaKit FX", 0) end
end
settle()
