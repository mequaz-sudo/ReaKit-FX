-- GainKit Plus -- start it with REAPER. Run once: GainKit Plus goes into Scripts/__startup.lua (the
-- file REAPER runs at start-up) and starts now; run again: it comes out. The toolbar button shows
-- the state. Nothing else in __startup.lua is touched: the block sits between two marker lines and
-- is added or removed whole; a file that held only the block is deleted. At start-up the block
-- registers GainKit Plus.lua as an action (a no-op when it already is one) and runs it by its
-- command id, so it runs on the real action path: its toggle lights and running the action stops
-- it as usual. MIT, EON Studios, 2026.
local r = reaper
local _, own, sec, cmd = r.get_action_context()
local sep = own:find("\\", 1, true) and "\\" or "/"
local dir = own:match("^(.*)[\\/]") or "."
local PLUS = dir .. sep .. "GainKit Plus.lua"
local STARTUP = r.GetResourcePath() .. sep .. "Scripts" .. sep .. "__startup.lua"
local OPEN  = "-- >>> GainKit Plus: start with REAPER (the action of the same name adds and removes this block) >>>"
local CLOSE = "-- <<< GainKit Plus <<<"

local function read(p) local fh = io.open(p, "rb"); if not fh then return nil end; local s = fh:read("*a"); fh:close(); return s end
local function write(p, s) local fh = io.open(p, "wb"); if not fh then return false end; fh:write(s); fh:close(); return true end

local function block()
  return table.concat({
    OPEN,
    "do",
    "  local plus, me = [[" .. PLUS .. "]], [[" .. own .. "]]",
    "  local ok, c = pcall(reaper.AddRemoveReaScript, true, 0, plus, true)",
    "  if ok and c and c > 0 then reaper.Main_OnCommand(c, 0) end",
    "  local ok2, c2 = pcall(reaper.AddRemoveReaScript, true, 0, me, true)",
    "  if ok2 and c2 and c2 > 0 then reaper.SetToggleCommandState(0, c2, 1); reaper.RefreshToolbar2(0, c2) end",
    "end",
    CLOSE,
    "" }, "\n")
end

-- GainKit Plus running now? -- so "start now" never stops it. Its toggle state goes on at its start
-- and off in its atexit; when REAPER has no state for the action yet (-1), its heartbeat decides,
-- read the way the script itself reads it: fresh, and newer than the last stop request.
local function plus_running(c)
  local ts = r.GetToggleCommandState(c)
  if ts == 1 then return true end
  if ts == 0 then return false end
  local hb = tonumber(r.GetExtState("EON_GainKitPlus", "alive")) or 0
  local st = tonumber(r.GetExtState("EON_GainKitPlus", "stop")) or 0
  return hb > st and r.time_precise() - hb < 1.0
end

local s = read(STARTUP) or ""
local a = s:find(OPEN, 1, true)
local on, ok
if a then
  local b = s:find(CLOSE, a, true)
  local e = b and (s:find("\n", b, true) or #s) or #s          -- through the end of the CLOSE line
  local out = s:sub(1, a - 1) .. s:sub(e + 1)
  if out:match("^%s*$") then os.remove(STARTUP); ok = true else ok = write(STARTUP, out) end
  on = false
else
  local out = s
  if #out > 0 and out:sub(-1) ~= "\n" then out = out .. "\n" end
  ok = write(STARTUP, out .. block())
  on = true
  if ok then
    local okc, c = pcall(r.AddRemoveReaScript, true, 0, PLUS, true)
    if okc and c and c > 0 and not plus_running(c) then r.Main_OnCommand(c, 0) end
  end
end

if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, on and 1 or 0); r.RefreshToolbar2(sec, cmd) end
-- the one dialog this action shows; a probe sets EON_GainKitPlus/quiet and gets none (a modal box
-- from an action run by Main_OnCommand blocks the caller)
if r.GetExtState("EON_GainKitPlus", "quiet") == "1" then return end
if not ok then
  r.MB("Could not write " .. STARTUP, "GainKit Plus", 0)
elseif on then
  r.MB("GainKit Plus starts with REAPER from now on (and is running now). Run this action again to take it out of Scripts/__startup.lua.", "GainKit Plus", 0)
else
  r.MB("GainKit Plus no longer starts with REAPER. The copy running now keeps running until you stop it.", "GainKit Plus", 0)
end
