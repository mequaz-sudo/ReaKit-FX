-- ReaKit FX -- start everything with REAPER, in one press. Puts GainKit Plus into
-- Scripts/__startup.lua (the same as running "GainKit Plus - Start with REAPER") when it is not
-- there yet, and starts EON Floatter once when it has not registered itself yet -- Floatter
-- writes its own start-up block on its first run. Running this again changes nothing: each
-- part is skipped when it is already in place. One message says what was done. MIT, EON
-- Studios, 2026.
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
local t0, n = r.time_precise(), 0
local function settle()
  n = n + 1
  if need_plus and r.time_precise() - t0 < 1.0 then return r.defer(settle) end
  if need_plus and not plus_alive() and exists(PLUS) then
    local ok, c = pcall(r.AddRemoveReaScript, true, 0, PLUS, true)
    if ok and c and c > 0 then r.Main_OnCommand(c, 0) end
  end
  if r.GetExtState("EON_GainKitPlus", "quiet") ~= "1" then r.MB(table.concat(done, string.char(10)), "ReaKit FX", 0) end
end
settle()
