-- Quezy helper -- lets Quezy dock and float without GainKit Plus (the user, 2026-11-02: "give it its own helper like
-- gumbo"). A double-click on Quezy's logo comes here through shared memory; the helper hands that Quezy to its own
-- dock tab ("Quezy - Dock"), starting the tab first when it is closed, or the tab floats it out when it holds it
-- already (and closes, Gumbo's way). With GainKit Plus running and no helper, Plus does the same.
--
-- A background script: run it once to start, run it again to stop. Idle it reads two shared-memory cells per pass.
-- Protocol: the EON_QUEZY_HELPER band in the Swing_Media_Transfer segment (.refs/gmem_regions_supplement.tsv):
--   +0 the helper's heartbeat (os.time(), every pass; 0 when it stops)   +2 track, +3 chain position, +4 flags
--   +5 a counter Quezy bumps LAST on every double-click (qz_face.jsfx-inc, qzg_dock_name)
-- EON Free Licence 1.0, EON Studios, 2026.
local r = reaper
local _, own, sec, cmd = r.get_action_context()
local dir = own:match("^(.*)[\\/]") or "."

-- A toggle, GainKit Plus's and Gumbo's way: a launch that finds a fresh heartbeat newer than the last stop request is
-- the user's second press: it asks the running copy to stop and ends at once.
local EXT = "EON_QuezyHelper"
local now0 = r.time_precise()
local alive = tonumber(r.GetExtState(EXT, "alive")) or 0
local stop = tonumber(r.GetExtState(EXT, "stop")) or 0
if alive > stop and now0 - alive < 1.0 then
  r.SetExtState(EXT, "stop", tostring(now0), false)
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
  return
end
if r.set_action_options then r.set_action_options(1) end
if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 1); r.RefreshToolbar2(sec, cmd) end

r.gmem_attach("Swing_Media_Transfer")
local B = 31374310
local function gr(i) return r.gmem_read(B + i) end

-- DOCK: the request names the track and the chain position; the tab's EXT gets the dock's own show request (the same
-- one GainKit Plus writes); the tab is started first when it is closed (its start leaves a request younger than 5 s
-- alone). A track's own chain only (flags 0). A double-click from before this run is not acted on.
local DX = "EON_ReaKitDock_qzy"
local seen = gr(5)
local function dock_tick()
  local seq = gr(5)
  if seq == seen then return end
  seen = seq
  local ti, pos, fl = math.floor(gr(2) + 0.5), math.floor(gr(3) + 0.5), math.floor(gr(4) + 0.5)
  if fl ~= 0 then return end
  local tr = ti == -1 and r.GetMasterTrack(0) or (ti >= 0 and r.GetTrack(0, ti) or nil)
  if not tr or pos < 0 or pos >= r.TrackFX_GetCount(tr) then return end
  local fg = r.TrackFX_GetFXGUID(tr, pos)
  if not fg then return end
  local req = r.GetTrackGUID(tr) .. "|" .. fg .. "|" .. string.format("%.3f", r.time_precise())
  -- a Quezy the full ReaKit FX dock holds is that dock's to float (the Codex review, 2026-11-04)
  if r.time_precise() - (tonumber(r.GetExtState("EON_ReaKitDock", "alive")) or 0) < 1.0 and
     (("," .. r.GetExtState("EON_ReaKitDock", "held") .. ","):find("|" .. fg .. ",", 1, true)) then
    r.SetExtState("EON_ReaKitDock", "show_req", req, false); return
  end
  r.SetExtState(DX, "show_req", req, false)
  if r.time_precise() - (tonumber(r.GetExtState(DX, "alive")) or 0) < 1.0 then return end   -- the tab is up: it takes it
  -- the released copy sits beside the ReaKit FX dock actions (GainKit Plus's folder), whose "Dock Quezy" is the same tab
  local p = dir .. "/ReaKit FX - Dock Quezy.lua"
  if not r.file_exists(p) then p = dir .. "/Quezy - Dock.lua" end
  if not r.file_exists(p) then return end
  local id = r.AddRemoveReaScript(true, 0, p, true)
  if id and id ~= 0 then r.Main_OnCommand(id, 0) end
end

local function loop()
  local now = r.time_precise()
  if (tonumber(r.GetExtState(EXT, "stop")) or 0) > now0 then return end   -- asked to stop: atexit cleans up
  r.SetExtState(EXT, "alive", tostring(now), false)
  r.gmem_write(B, os.time())                             -- Quezy: a helper is here
  dock_tick()
  r.defer(loop)
end

r.atexit(function()
  r.gmem_write(B, 0)
  if sec and cmd and cmd > 0 then r.SetToggleCommandState(sec, cmd, 0); r.RefreshToolbar2(sec, cmd) end
end)
loop()
