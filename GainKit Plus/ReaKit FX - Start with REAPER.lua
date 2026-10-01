-- ReaKit FX -- start everything with REAPER, in one press. Puts GainKit Plus into
-- Scripts/__startup.lua (the same as running "GainKit Plus - Start with REAPER") when it is not
-- there yet, and starts EON Floatter once when it has not registered itself yet -- Floatter
-- writes its own start-up block on its first run. Running this again changes nothing: each
-- part is skipped when it is already in place. Once, it also offers to raise REAPER's meter
-- refresh to 120 a second, so the plugin faces in the mixer strips answer quicker (next start).
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
