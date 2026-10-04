-- ReaKit FX -- a docker tab that shows the selected track's ReaKit FX, whole and live, and follows your selection
-- (the user, 2026-10-03: "a meter that is docked follows the track selection would be dope", "keep the last one
-- and show the whole gainkit", then a PIN, reopening with REAPER, "the same ... dock for the other five effects",
-- and "Will a wide dock show all the plugins? Or as many can fit?"). A bar across the top: the track's name, a
-- button for each effect (GainKit, 3-Band EQ, DDC, De-Esser, Saturation, Stereo Width; the ones the track does
-- not have are dim: right-click one to add it to the track), STRIP, PIN (stay on this track, the master say,
-- whatever you click) and TABS (REAPER's docker tabs off or on).
-- STRIP off: the chosen effect fills the dock. Click a track without it and the dock keeps the last; a track with
-- two shows the first.
-- STRIP on: every one of the six on the track, side by side in chain order, like a channel strip; as many as fit
-- at a usable width, the rest a click away (< and >, an effect's button, or the wheel over the bar). Click a track
-- with none of them and the dock keeps the last. Effects inside an FX container are not shown.
-- Open a docked effect's own window (its strip, the FX chain) and the dock steps aside for it until it closes.
-- Double-click an effect's name in its own window (GainKit Plus running): the dock opens on its track with it;
-- double-click the name of a docked one: it pops out into its own window.
-- Run the action again to close the dock; on a toolbar the button lights while it runs. GainKit Plus, when it
-- starts with REAPER, opens the dock again if it was open when REAPER closed.
--
-- How: REAPER floats the effect, this script takes the float's drawing surface (the "jsfx_gfx" child window,
-- the plugin itself without REAPER's preset bar) into its own dockable window and hides the empty float; in a
-- strip, one float and one surface per effect. Every way out hands a surface back to a float, at its exact place,
-- BEFORE anything else: a REAPER window moved outside its tree is never taken back by REAPER (EON Swing Dock's
-- lesson, 2026-08-25). The same mechanism as EON Swing Dock, written for the six. Windows only; needs
-- js_ReaScriptAPI (ReaPack). MIT, EON Studios, 2026.
local r = reaper
local TITLE = "ReaKit FX Dock"         -- the docker tab's label; also how the script finds its own window
local EXT = "EON_ReaKitDock"
local W0, H0 = 350, 572                -- the size when not docked: GainKit's window and the bar
local WAIT_TICKS = 30                  -- how long to wait for REAPER to make a float and its surface
local GAP = 3                          -- STRIP: the line between two effects, at 100 %

if not r.GetOS():match("^Win") then
  r.MB("The ReaKit FX dock works on Windows only.", "ReaKit FX", 0)
  return
end
if not r.APIExists("JS_Window_SetParent") then
  r.MB("The ReaKit FX dock needs the js_ReaScriptAPI extension.\n\n" ..
       "Extensions > ReaPack > Browse packages > js_ReaScriptAPI, install it, restart REAPER.", "ReaKit FX", 0)
  return
end

-- The six, each by its FILE, the exact name, as every GainKit Plus action finds GainKit (wiki 6.16). w = its own
-- window's width (the plugin's @gfx line; Saturation and Stereo Width: the width their header fits on one line,
-- seen 2026-10-03: narrower, THEME drops onto the knob row); minw = the least STRIP gives it before it moves one
-- off the dock (3-Band EQ 250: at 226 its three crossover labels ran into each other, seen in the release
-- pictures); src = the file as it is spelled on disk (a right-click adds one).
local KINDS = {
  { key = "gk",  name = "GainKit",      long = "GAINKIT",  short = "GK",  file = "channeltool_reakit.jsfx", w = 450, minw = 230, src = "ChannelTool_ReaKit.jsfx" },
  { key = "eq3", name = "3-Band EQ",    long = "3-BAND",   short = "EQ",  file = "3bandeq_reakit.jsfx",     w = 460, minw = 250, src = "3BandEQ_ReaKit.jsfx" },
  { key = "ddc", name = "DDC",          long = "DDC",      short = "DDC", file = "ddc_reakit.jsfx",         w = 600, minw = 260, src = "DDC_ReaKit.jsfx" },
  { key = "des", name = "De-Esser",     long = "DE-ESSER", short = "DE",  file = "deesser_reakit.jsfx",     w = 540, minw = 240, src = "DeEsser_ReaKit.jsfx" },
  { key = "sat", name = "Saturation",   long = "SAT",      short = "SAT", file = "saturation_reakit.jsfx",  w = 280, minw = 260, src = "Saturation_ReaKit.jsfx" },
  { key = "wid", name = "Stereo Width", long = "WIDTH",    short = "W",   file = "stereowidth_reakit.jsfx", w = 300, minw = 280, src = "StereoWidth_ReaKit.jsfx" },
}
local kind = 1
for i, k in ipairs(KINDS) do if k.key == r.GetExtState(EXT, "kind") then kind = i end end
local strip = r.GetExtState(EXT, "strip") == "1"

local function basename(p) return (p:gsub("^.*[/\\]", "")) end
local function kind_of(tr, f)
  local ok, id = r.TrackFX_GetNamedConfigParm(tr, f, "fx_ident")
  if not ok then return nil end
  local b = basename(id):lower()
  for k, v in ipairs(KINDS) do if v.file == b then return k end end
end
local function first_of(tr, k)
  if not tr then return nil end
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    if kind_of(tr, f) == (k or kind) then return f end
  end
end
-- What the dock shows of a track, in chain order: { { fg, fx, kind }, ... }. STRIP off: the first of the chosen
-- effect, or the copy last asked for on that track by a double-click on its name (prefer, by track GUID). STRIP
-- on: every one of the six. The track's own chain only: an effect inside a container is not shown.
local prefer = {}
local function wanted(tr)
  local out = {}
  if not tr then return out end
  local pick
  local want_fg = not strip and prefer[r.GetTrackGUID(tr)]
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    local k = kind_of(tr, f)
    if k and (strip or k == kind) then
      local e = { fg = r.TrackFX_GetFXGUID(tr, f), fx = f, kind = k }
      if strip then out[#out + 1] = e
      elseif e.fg == want_fg then pick = e; break
      elseif not pick then pick = e; if not want_fg then break end end
    end
  end
  if pick then out[1] = pick end
  return out
end

-- a track and an FX are kept by GUID (a MediaTrack pointer or an FX index can move, wiki 6.2 / 6.9), in the
-- project they came from; the last pointer is tried first and the project searched only when it fails
local function track_by_guid(proj, g, hint)
  if not g or not r.ValidatePtr(proj, "ReaProject*") then return nil end   -- its project tab may be closed
  if hint and r.ValidatePtr2(proj, hint, "MediaTrack*") and r.GetTrackGUID(hint) == g then return hint end
  local m = r.GetMasterTrack(proj)
  if r.GetTrackGUID(m) == g then return m end
  for i = 0, r.CountTracks(proj) - 1 do
    local tr = r.GetTrack(proj, i)
    if r.GetTrackGUID(tr) == g then return tr end
  end
end
local function fx_by_guid(tr, g, hint)
  if not (tr and g) then return nil end
  if hint and r.TrackFX_GetFXGUID(tr, hint) == g then return hint end
  for f = 0, r.TrackFX_GetCount(tr) - 1 do
    if r.TrackFX_GetFXGUID(tr, f) == g then return f end
  end
end

-- the float's drawing surface: its child of class "jsfx_gfx"
local function find_canvas(float_hwnd)
  local ok, list = r.JS_Window_ListAllChild(float_hwnd)
  if not ok or not list or list == "" then return nil end
  for addr in list:gmatch("[^,]+") do
    local h = r.JS_Window_HandleFromAddress(tonumber(addr))
    if h and r.JS_Window_GetClassName(h) == "jsfx_gfx" then return h end
  end
end

-- A trace for tests: SetExtState("EON_ReaKitDock", "debug", "1") and the dock appends its steps to
-- %TEMP%\reakit_dock_trace.txt. Off (the default): nothing is written.
local function dbg(msg)
  if r.GetExtState(EXT, "debug") ~= "1" then return end
  local fh = io.open((os.getenv("TEMP") or ".") .. "\\reakit_dock_trace.txt", "a")
  if fh then fh:write(string.format("%.3f %s\n", r.time_precise(), msg)); fh:close() end
end

-- ── state ────────────────────────────────────────────────────────────────────────────────────────
local dock                             -- this script's own window
local cur = nil                        -- the track the dock shows: { proj, tg, tr, name, list = wanted(it) }
-- The effects on view, left to right, one record each: { proj, tg, fg, tr, fx, kind, name, x, y, w, h } and
-- then either its surface (wrapper, canvas, home, wait), or away = true (open in the user's own window), or
-- retry = a time (its float never came: try again then), or gone = true (deleted: dropped at the next sweep).
local slots = {}
local first = 1                        -- STRIP: the list's first effect on view
local more_left, more_right = false, false
local on_view = {}                     -- STRIP: the kinds on view (their buttons light)
local last_sel_g = false               -- the followed track's GUID last tick (false = never looked)
local scan_cool = 0
local chain_t = 0                      -- when the shown track's chain was last looked at (0 = look now)
local recheck_t = 0                    -- when the followed track was last looked at while the dock shows another
-- What the dock let go of in each project tab the user went away from, by project: { cur, first, held }. One per
-- tab (2026-10-03, dockfix_probe.lua: a single slot was overwritten by the second tab, and coming back to the
-- first, the windows REAPER shows again there stayed open as windows).
local tabs_left = {}
local note = nil                       -- why the dock is empty, when it is: "No De-Esser on Vocal."
local pin = r.GetExtState(EXT, "pin")  -- "" = follow the selection; "MASTER" or a track's GUID = stay on it
local BAR = 26                         -- the bar's height at 100 %; times the display scale below
local sc = 1

local function where(rec)
  local tr = track_by_guid(rec.proj, rec.tg, rec.tr)
  local fx = tr and fx_by_guid(tr, rec.fg, rec.fx)
  rec.tr, rec.fx = tr, fx
  return tr, fx
end
local function track_name(tr)
  if tr == r.GetMasterTrack(0) then return "MASTER" end
  local _, nm = r.GetTrackName(tr)
  return nm
end
local function label(rec) return rec.name .. ":" .. KINDS[rec.kind].short end
local bar_rows = 1                     -- 2 when the dock is too narrow for one row (draw_bar decides)
local function bar_h() return math.floor(BAR * sc + 0.5) * bar_rows end

-- Put a surface back in its float, where it came from. True when it landed.
local function give_back(rec, wrapper)
  if not (rec.canvas and wrapper and r.JS_Window_IsWindow(rec.canvas) and r.JS_Window_IsWindow(wrapper)) then return false end
  r.JS_Window_SetParent(rec.canvas, wrapper)
  if rec.home then
    r.JS_Window_Move(rec.canvas, rec.home.x, rec.home.y)
    r.JS_Window_Resize(rec.canvas, rec.home.w, rec.home.h)
  end
  return true
end

-- An effect moved to ANOTHER track keeps its instance, its GUID and its surface; REAPER opens its window on the new
-- track, empty (measured 2026-10-03, dockedge_probe.lua: the surface stayed in the dock). Found anywhere in its
-- project by its GUID, so the surface goes back to it there.
local function fx_anywhere(proj, fg)
  if not r.ValidatePtr(proj, "ReaProject*") then return nil end
  local m = r.GetMasterTrack(proj)
  local f = fx_by_guid(m, fg)
  if f then return m, f end
  for i = 0, r.CountTracks(proj) - 1 do
    local tr = r.GetTrack(proj, i)
    f = fx_by_guid(tr, fg)
    if f then return tr, f end
  end
end

-- Let go of one effect: its surface back in a float first, then the float hidden and closed. One that is open in
-- the user's own window stays there.
local function release(rec)
  if rec.away then return end
  local tr, fx = where(rec)
  if not (tr and fx) and rec.canvas and r.JS_Window_IsWindow(rec.canvas) then
    tr, fx = fx_anywhere(rec.proj, rec.fg)
    if tr then dbg("release " .. label(rec) .. ": moved to another track, handed back there") end
  end
  dbg("release " .. label(rec) .. " canvas " .. tostring(rec.canvas) .. " lives " .. tostring(rec.canvas and r.JS_Window_IsWindow(rec.canvas)))
  if rec.canvas and r.JS_Window_IsWindow(rec.canvas) then
    local w = rec.wrapper
    if tr and fx then
      local fw = r.TrackFX_GetFloatingWindow(tr, fx)
      if fw then w = fw end            -- REAPER may have rebuilt the float
      if not (w and r.JS_Window_IsWindow(w)) then
        -- REAPER closed the float itself (another project tab: REAPER puts a background project's windows
        -- away; measured 2026-10-03) while the surface lives here. A new float to give it back to, so it is
        -- never left behind: left here, that effect's next window opens empty.
        r.TrackFX_Show(tr, fx, 3)
        w = r.TrackFX_GetFloatingWindow(tr, fx)
        dbg("release: float gone, a new one " .. tostring(w))
      end
    end
    give_back(rec, w)
    if w and r.JS_Window_IsWindow(w) then r.JS_Window_Show(w, "HIDE") end
  end
  if tr and fx then r.TrackFX_Show(tr, fx, 2) end
  rec.canvas, rec.wrapper = nil, nil
end
local function release_all()
  for _, s in ipairs(slots) do release(s) end
  slots = {}
end
-- drop the deleted ones; the shown track's chain is looked at again on the next tick
local function sweep()
  local kept = {}
  for _, s in ipairs(slots) do if not s.gone then kept[#kept + 1] = s end end
  if #kept ~= #slots then chain_t = 0 end
  slots = kept
end

-- A surface fills its place in the dock (the layout below sets x, y, w, h).
local function fit(rec)
  if not (rec.canvas and rec.w and rec.w >= 2 and rec.h >= 2) then return end
  local key = rec.x .. " " .. rec.y .. " " .. rec.w .. " " .. rec.h
  if key == rec.shown then return end
  r.JS_Window_Move(rec.canvas, rec.x, rec.y)
  r.JS_Window_Resize(rec.canvas, rec.w, rec.h)
  r.JS_Window_InvalidateRect(rec.canvas, 0, 0, rec.w, rec.h, true)
  rec.shown = key
end

-- Its float never came, or came without a surface: let go, and try again in a while (1, 2, 4, 8 s).
local function retry_later(rec, why)
  dbg("capture " .. label(rec) .. ": " .. why .. ", gave up")
  release(rec)
  rec.tries = (rec.tries or 0) + 1
  rec.retry = r.time_precise() + math.min(8, 2 ^ (rec.tries - 1))
end

-- Take the float's surface once it exists. The float is hidden the moment it is found, so it is not seen.
local function capture(rec)
  local tr, fx = where(rec)
  if not (tr and fx) then dbg("capture: target gone"); release(rec); rec.gone = true; return end
  if not rec.wrapper then
    rec.wrapper = r.TrackFX_GetFloatingWindow(tr, fx)
    if not rec.wrapper then
      rec.wait = rec.wait - 1
      if rec.wait <= 0 then retry_later(rec, "no float") end
      return
    end
    dbg("capture: float " .. tostring(rec.wrapper))
    r.JS_Window_Show(rec.wrapper, "HIDE")
  end
  if not rec.canvas then
    local c = find_canvas(rec.wrapper)
    if not c then
      rec.wait = rec.wait - 1
      if rec.wait <= 0 then retry_later(rec, "no surface") end
      return
    end
    dbg("capture: surface " .. tostring(c))
    local ok, L, T, R, B = r.JS_Window_GetRect(c)   -- its home, saved before it moves
    if ok then
      local x, y = r.JS_Window_ScreenToClient(rec.wrapper, L, T)
      rec.home = { x = x, y = y, w = R - L, h = B - T }
    end
    rec.canvas, rec.tries, rec.shown = c, 0, nil
    r.JS_Window_SetParent(c, dock)
  end
  fit(rec)
end

-- force: take it even when its own window is open (back on a project tab, below)
local function take(rec, force)
  local tr, fx = where(rec)
  if not (tr and fx) then rec.gone = true; return end
  rec.retry = nil
  -- already open in its own window or the FX chain: the user is looking at it there, so it stays there
  local fw = r.TrackFX_GetFloatingWindow(tr, fx)
  if not force and ((fw and r.JS_Window_IsVisible(fw)) or r.TrackFX_GetChainVisible(tr) == fx) then
    rec.away = true
    dbg("acquire " .. label(rec) .. ": open elsewhere, left there")
    return
  end
  rec.away = nil
  rec.wrapper, rec.canvas, rec.home, rec.shown = nil, nil, nil, nil
  rec.wait = WAIT_TICKS
  dbg("acquire " .. label(rec) .. " fx " .. fx)
  r.TrackFX_Show(tr, fx, 3)
  capture(rec)                         -- the float usually exists at once: hidden before it is drawn
end

-- The user opened a held effect somewhere else (its float shown, or the FX chain on it), or REAPER closed its
-- float (a click on the strip toggles the window, the strip's house rule). Opened elsewhere: the surface goes
-- back where the user is looking and its place in the dock says so. Closed by REAPER: it opens again as its own
-- window, with its surface (below). Either way, once that window closes the dock takes it back.
local function watch_held(rec)
  local tr, fx = where(rec)
  if not (tr and fx) then release(rec); rec.gone = true; return end
  if not rec.canvas then capture(rec); return end
  local fw = r.TrackFX_GetFloatingWindow(tr, fx)
  local chain = r.TrackFX_GetChainVisible(tr) == fx
  if fw and fw ~= rec.wrapper and not (rec.wrapper and r.JS_Window_IsWindow(rec.wrapper)) then rec.wrapper = fw end
  local float_shown = fw and r.JS_Window_IsVisible(fw)
  if float_shown or chain then
    if not fw then r.TrackFX_Show(tr, fx, 3); fw = r.TrackFX_GetFloatingWindow(tr, fx) end
    give_back(rec, fw)
    if chain and not float_shown then r.TrackFX_Show(tr, fx, 2) end   -- the chain re-hosts it
    rec.away, rec.canvas, rec.wrapper = true, nil, nil
    dbg("away: " .. label(rec) .. (chain and " (chain)" or " (its window)"))
    return
  end
  if not fw or not r.JS_Window_IsWindow(rec.canvas) then
    local surface_lives = r.JS_Window_IsWindow(rec.canvas)
    dbg("held float gone: " .. label(rec) .. " fw " .. tostring(fw) .. " surface lives " .. tostring(surface_lives)
      .. " wrapper lives " .. tostring(rec.wrapper and r.JS_Window_IsWindow(rec.wrapper)))
    if not fw and surface_lives then
      -- REAPER closed the hidden float (a click on the strip toggles the window, and REAPER counts a
      -- docked effect's float as open). REAPER keeps the plugin's one surface alive and makes no new one for
      -- a new float (measured 2026-10-03: a re-float came up without it), so the surface must go to a new
      -- float, not be left here. The click meant "open the window": it opens, with the surface, and the dock
      -- steps aside; the next click on the strip closes it and the dock takes it back.
      r.TrackFX_Show(tr, fx, 3)
      local nw = r.TrackFX_GetFloatingWindow(tr, fx)
      if nw and give_back(rec, nw) then
        rec.away, rec.canvas, rec.wrapper = true, nil, nil
        dbg("away: " .. label(rec) .. " (the float was closed: opened again, with its surface)")
        return
      end
    end
    -- the surface is gone too (the dock window went first, or REAPER made a new view): take it afresh
    rec.canvas, rec.wrapper = nil, nil
    take(rec)
  end
end

-- Back from its own window: once that window has closed (and the chain is not on it), the dock takes it again.
local function watch_away(rec)
  local tr, fx = where(rec)
  if not (tr and fx) then rec.gone = true; return end
  local fw = r.TrackFX_GetFloatingWindow(tr, fx)
  if not (fw and r.JS_Window_IsVisible(fw)) and r.TrackFX_GetChainVisible(tr) ~= fx then take(rec) end
end

local function watch(rec)
  if rec.retry then
    if r.time_precise() >= rec.retry then take(rec) end
  elseif rec.away then watch_away(rec)
  else watch_held(rec) end
end

-- The track the dock follows: the pinned one, or the selected one (the master counts).
local function pinned_track()
  if pin == "MASTER" then return r.GetMasterTrack(0) end
  return track_by_guid(r.EnumProjects(-1), pin, nil)
end
local function followed()
  if pin ~= "" then
    local tr = pinned_track()
    if tr then return tr end
    pin = ""                                             -- its track is gone, or another project: follow again
    r.SetExtState(EXT, "pin", "", true)
  end
  return r.GetSelectedTrack2(0, 0, true)
end

local function show_track(tr, list)
  local proj, g = r.EnumProjects(-1), r.GetTrackGUID(tr)
  if not (cur and cur.tg == g and cur.proj == proj) then first = 1 end
  cur = { proj = proj, tg = g, tr = tr, name = track_name(tr), list = list }
  note = nil
end
local function none_note(tr)
  release_all(); cur = nil
  note = string.format("No %s on %s.", strip and "ReaKit FX" or KINDS[kind].name, tr and track_name(tr) or "the selected track")
end

-- force: the effect or the pin changed, so look again even when the followed track did not change
local function follow(force)
  local tr = followed()
  local g = tr and r.GetTrackGUID(tr) or ""
  local now = r.time_precise()
  if g ~= last_sel_g or force then
    last_sel_g, recheck_t = g, now
    local list = wanted(tr)
    if #list > 0 then
      show_track(tr, list)
    elseif force or pin ~= "" or note then
      -- the effect switched (or the dock is pinned, or already says why it is empty) and this track has none
      -- of it: nothing to keep, say so
      none_note(tr)
    end
    -- following, and the selected track has none of it: keep the last one
  elseif tr and (note or (cur and cur.tg ~= g)) and now - recheck_t >= 0.5 then
    -- the dock says why it is empty, or keeps the last track because this one had none: one added here since
    -- shows without a click elsewhere (2026-10-03, dockfix_probe.lua: it waited for a reselect)
    recheck_t = now
    local list = wanted(tr)
    if #list > 0 then show_track(tr, list) end
  end
  if not cur and not note and pin == "" then
    if scan_cool > 0 then scan_cool = scan_cool - 1; return end
    scan_cool = 30                                       -- showing nothing: look about once a second
    dbg("holding nothing: scan")
    local cands = {}
    if tr then cands[1] = tr end
    cands[#cands + 1] = r.GetMasterTrack(0)
    for i = 0, r.CountTracks(0) - 1 do cands[#cands + 1] = r.GetTrack(0, i) end
    for _, t in ipairs(cands) do
      local list = wanted(t)
      if #list > 0 then show_track(t, list); return end
    end
  end
end

-- The shown track's chain, about twice a second: an effect added, moved or deleted there shows at once.
local function check_chain()
  if not cur then return end
  local now = r.time_precise()
  if now - chain_t < 0.5 then return end
  chain_t = now
  local tr = track_by_guid(cur.proj, cur.tg, cur.tr)
  if not tr then dbg("its track is gone"); release_all(); cur = nil; last_sel_g = false; return end
  cur.tr, cur.name = tr, track_name(tr)
  local list = wanted(tr)
  local same = #list == #cur.list
  for i = 1, #list do
    if not same then break end
    same = list[i].fg == cur.list[i].fg
  end
  if same then return end
  dbg("its chain changed: " .. #cur.list .. " -> " .. #list)
  if #list > 0 then cur.list = list
  elseif pin ~= "" then none_note(tr)
  else release_all(); cur = nil end
end

-- ── a double-click on an effect's name (rk_theme's rkth_dock_name, served by GainKit Plus) ──────────
-- The user (2026-10-03): "swing i double click the logo it docks. can we get that same functionality?"
local force_fg = nil                   -- taken even from its own window, by the next layout
-- Docked here: out to its own window. Closing that window brings it back, as for any window the user opens.
local function pop_out(s)
  local tr, fx = where(s)
  if not (tr and fx) then return end
  local w = r.TrackFX_GetFloatingWindow(tr, fx)
  if not (w and r.JS_Window_IsWindow(w)) then r.TrackFX_Show(tr, fx, 3); w = r.TrackFX_GetFloatingWindow(tr, fx) end
  if give_back(s, w) then
    r.JS_Window_Show(w, "SHOW")                          -- the float the dock had hidden, the plugin in it again
    s.away, s.canvas, s.wrapper = true, nil, nil
    dbg("pop out: " .. label(s))
  end
end
-- Not docked: its track in the dock, that effect on view, taken out of its own window (where the double-click
-- was). The dock goes on following from there: a pin moves to its track, else its track is selected (as EON
-- Swing's logo does). In the FX chain the chain keeps it (the dock's rule for the chain), its place says so.
-- req = "track GUID|FX GUID|time"; one older than 5 s (left from a run that ended) is dropped.
local function show_req(req)
  local tg, fg, t = req:match("^([^|]+)|([^|]+)|(.+)$")
  t = tonumber(t)
  if not (tg and fg and t) or r.time_precise() - t > 5 then dbg("show_req: stale or bad " .. req); return end
  local tr = track_by_guid(r.EnumProjects(-1), tg, nil)
  local fx = tr and fx_by_guid(tr, fg, nil)
  local k = fx and kind_of(tr, fx)
  if not k then dbg("show_req: not in this project"); return end
  for _, s in ipairs(slots) do
    if s.fg == fg and s.canvas then pop_out(s); return end
  end
  if k ~= kind then kind = k; r.SetExtState(EXT, "kind", KINDS[k].key, true) end   -- STRIP off later: this one
  prefer[tg] = fg
  local master = tr == r.GetMasterTrack(0)
  if pin ~= "" then
    pin = master and "MASTER" or tg
    r.SetExtState(EXT, "pin", pin, true)
  else
    -- exactly its track selected, by the API (an action could add an undo point): every selected track off, the
    -- master too (the dock follows a selected master FIRST: left on, it would win over this track; the audit)
    for i = r.CountSelectedTracks(0) - 1, 0, -1 do r.SetTrackSelected(r.GetSelectedTrack(0, i), false) end
    r.SetTrackSelected(r.GetMasterTrack(0), false)
    r.SetTrackSelected(tr, true)
  end
  last_sel_g = tg
  local list = wanted(tr)
  show_track(tr, list)
  for i, e in ipairs(list) do if e.fg == fg then first = i end end   -- on view (a strip steps back at its end)
  force_fg = fg
  for _, s in ipairs(slots) do
    if s.fg == fg and s.away then take(s, true) end      -- on view already, in its own window: back in
  end
  dbg("show_req: " .. track_name(tr) .. ":" .. KINDS[k].short)
end

-- Where each effect goes, then the dock takes the new ones and lets go of the ones that left. STRIP off: the
-- first fills the dock. STRIP on: from the first on view, as many as fit at their least widths; the room left
-- over goes to each in proportion to how far it can grow, up to its own window's width, and past that in
-- proportion to its width, so the strip always fills the dock. Scrolled to the end with room to spare, it steps
-- back so no room is wasted.
local function layout()
  local ok, w, h = r.JS_Window_GetClientSize(dock)
  if not ok then return end
  local b = bar_h()
  local list = cur and cur.list or {}
  local want = {}
  on_view, more_left, more_right = {}, false, false
  if #list > 0 and w >= 2 and h >= b + 2 then
    if not strip then
      want[1] = { e = list[1], x = 0, w = w }
    else
      local gap = math.max(1, math.floor(GAP * sc + 0.5))
      local function minw(e) return math.floor(KINDS[e.kind].minw * sc + 0.5) end
      local function fits_from(s)
        local n, used = 0, 0
        for i = s, #list do
          local need = minw(list[i]) + (n > 0 and gap or 0)
          if n > 0 and used + need > w then break end
          n, used = n + 1, used + need
        end
        return n
      end
      first = math.max(1, math.min(first, #list))
      while first > 1 and first - 1 + fits_from(first - 1) - 1 >= #list do first = first - 1 end
      local n = fits_from(first)
      local last = first + n - 1
      more_left, more_right = first > 1, last < #list
      local room = w - gap * (n - 1)
      local smin, snat = 0, 0
      for i = first, last do smin = smin + minw(list[i]); snat = snat + KINDS[list[i].kind].w * sc end
      local x = 0
      for i = first, last do
        local e = list[i]
        local mn, nat = minw(e), KINDS[e.kind].w * sc
        local cw
        if room <= smin then cw = mn
        elseif room <= snat then cw = mn + (nat - mn) * (room - smin) / (snat - smin)
        else cw = nat * room / snat end
        cw = i == last and w - x or math.floor(cw + 0.5)
        want[#want + 1] = { e = e, x = x, w = math.max(2, cw) }
        x = x + cw + gap
        on_view[e.kind] = true
      end
    end
  end
  local have = {}
  for _, s in ipairs(slots) do have[s.fg] = s end
  local new, fresh = {}, {}
  for _, v in ipairs(want) do
    local s = have[v.e.fg]
    if s then
      have[v.e.fg] = nil
    else
      s = { proj = cur.proj, tg = cur.tg, tr = cur.tr, fg = v.e.fg, fx = v.e.fx, kind = v.e.kind, name = cur.name }
      fresh[#fresh + 1] = s
    end
    s.x, s.y, s.w, s.h = v.x, b, v.w, h - b
    new[#new + 1] = s
  end
  for _, s in pairs(have) do release(s) end
  slots = new
  for _, s in ipairs(fresh) do take(s, s.fg == force_fg) end
  force_fg = nil
  for _, s in ipairs(slots) do fit(s) end
end

-- ── REAPER's docker tabs (the user: "maybe an action to turn them on and off") ───────────────────────
-- REAPER's own option, "Dockers: Compact when small and single tab" (the preference dockcompactsingle): a
-- docker holding one window shows a thin edge instead of its tab bar while it is smaller than
-- dock_mini_tab_size. Off here = compact on with that size raised past any screen, so every docker with one
-- window loses its tabs; a docker holding two keeps them (they switch between the two). It is REAPER-wide.
-- Measured 2026-10-03 (tabs_probe.lua, tabs2_probe.lua): it takes effect when the dockers are laid out again;
-- set_config_var_string REFUSES dockcompactsingle (returns 0, the value stays), so the switch is flipped with
-- REAPER's own action and only read here; dock_mini_tab_size it does set. Showing the tabs again puts back what
-- the user had: the switch as it was, and the size limit.
local COMPACT_NAME = "dockers: compact when small and single tab"
local compact_cmd
local function cfg_num(name)
  local ok, v = r.get_config_var_string(name)
  return ok and tonumber(v) or nil
end
local function compact_on() return (cfg_num("dockcompactsingle") or 0) ~= 0 end
-- The action: 41691 in REAPER 7.81 when its name says so, or, in a translated REAPER (its name is not English
-- there: the audit, 2026-10-03), when it is an on/off action whose state is the preference's own; else the English
-- name anywhere in the list (another REAPER numbering). 0 = none.
local function compact_action()
  if compact_cmd then return compact_cmd end
  local t = r.kbd_getTextFromCmd(41691, 0)
  local st = r.GetToggleCommandState(41691)
  if (t and t:lower() == COMPACT_NAME) or (st >= 0 and (st == 1) == compact_on()) then compact_cmd = 41691; return 41691 end
  for i = 40000, 70000 do
    t = r.kbd_getTextFromCmd(i, 0)
    if t and t:lower() == COMPACT_NAME then compact_cmd = i; return i end
  end
  compact_cmd = 0
  return 0
end
-- Flip the preference through its action, and check that it flipped: an action that turns out to be another
-- one is run again (put back) and never used again.
local function flip_compact()
  local cmd = compact_action()
  if cmd == 0 then return false end
  local before = compact_on()
  r.Main_OnCommand(cmd, 0)
  if compact_on() ~= before then return true end
  r.Main_OnCommand(cmd, 0)
  compact_cmd = 0
  dbg("tabs: action " .. cmd .. " did not flip dockcompactsingle: put back, not used again")
  return false
end
local function tabs_hidden()
  return compact_on() and (cfg_num("dock_mini_tab_size") or 0) >= 4000
end
local function set_tabs_hidden(on)
  if not r.set_config_var_string or compact_action() == 0 then return end   -- an older REAPER: nothing to do
  local compact = compact_on()
  if on then
    local size = cfg_num("dock_mini_tab_size")
    if size and size < 4000 then r.SetExtState(EXT, "mini_tab_size_was", tostring(size), true) end
    r.SetExtState(EXT, "compact_was", compact and "1" or "0", true)
    r.set_config_var_string("dock_mini_tab_size", "4000", 1)
    if not compact then flip_compact() end
  else
    if compact and r.GetExtState(EXT, "compact_was") == "0" then flip_compact() end
    local was = tonumber(r.GetExtState(EXT, "mini_tab_size_was")) or 200      -- REAPER's own default
    r.set_config_var_string("dock_mini_tab_size", tostring(math.min(was, 3999)), 1)
  end
  r.DockWindowRefresh()
  dbg("tabs hidden: " .. tostring(on) .. " -> " .. tostring(tabs_hidden()) .. " (compact " ..
    tostring(cfg_num("dockcompactsingle")) .. ", size " .. tostring(cfg_num("dock_mini_tab_size")) .. ")")
end

-- ── the bar ──────────────────────────────────────────────────────────────────────────────────────
local hits = {}                        -- this frame's buttons: { x0, x1, y0, y1, act }
local has_cache, has_key, has_t = {}, "", 0
-- which of the six the shown track has (the dim buttons), looked up about twice a second
local function kinds_on(tr)
  local key = tr and (r.GetTrackGUID(tr) .. r.TrackFX_GetCount(tr)) or ""
  local now = r.time_precise()
  if key ~= has_key or now - has_t > 0.5 then
    has_key, has_t = key, now
    for k = 1, #KINDS do has_cache[k] = tr and first_of(tr, k) ~= nil or false end
  end
  return has_cache
end

local function shown_track()
  if cur then return track_by_guid(cur.proj, cur.tg, cur.tr) end
  return followed()
end

-- One row when everything fits (long labels, then short); two rows in a narrow dock (seen 2026-10-03: a
-- 255 px dock cut TABS off and dropped the name): the six on top, the track's name with the rest under.
-- STRIP on: the six light for the ones on view, and < > appear when the track has more than fit.
local function draw_bar()
  local w = gfx.w
  local fs = math.max(9, math.floor(11 * sc + 0.5))
  gfx.setfont(1, "Arial", fs, string.byte("b"))
  local pad, gap = math.floor(7 * sc), math.floor(3 * sc)
  local nx = math.floor(8 * sc)
  local th = select(2, gfx.measurestr("Hg"))
  local function width(labels)
    local t = 0
    for _, s in ipairs(labels) do t = t + gfx.measurestr(type(s) == "table" and s[1] or s) + 2 * pad + gap end
    return t
  end
  local pinned, hidden = pin ~= "", tabs_hidden()
  local function right_set(tabs_label)                   -- { label, act, lit, dim }
    local t = {}
    if strip and (more_left or more_right) then
      t[#t + 1] = { "<", "left", false, not more_left }
      t[#t + 1] = { ">", "right", false, not more_right }
    end
    t[#t + 1] = { "STRIP", "strip", strip, false }
    t[#t + 1] = { "PIN", "pin", pinned, false }
    t[#t + 1] = { tabs_label, "tabs", false, false }
    return t
  end
  local right_long, right_short = right_set(hidden and "SHOW TABS" or "HIDE TABS"), right_set("TABS")
  local long, short = {}, {}
  for k = 1, #KINDS do long[k], short[k] = KINDS[k].long, KINDS[k].short end
  local labels, right = long, right_long
  local rows = 1
  if width(right) + width(labels) + 60 * sc > w then
    labels, right = short, right_short
    if width(right) + width(labels) + nx + 4 * sc > w then
      rows = 2                                           -- each row gets its long labels back where they fit
      labels = width(long) + nx <= w and long or short
      right = width(right_long) + nx + 40 * sc <= w and right_long or right_short
    end
  end
  bar_rows = rows
  local row = math.floor(BAR * sc + 0.5)
  local b = bar_h()
  gfx.set(0.11, 0.12, 0.14, 1); gfx.rect(0, 0, w, b, 1)
  gfx.set(0.25, 0.27, 0.31, 1); gfx.line(0, b - 1, w, b - 1)
  hits = {}
  local function chip(x, y, text, lit, dim, act)
    local cw = gfx.measurestr(text) + 2 * pad
    local y0, ch = y + math.floor(4 * sc), row - math.floor(8 * sc)
    if lit then gfx.set(0.84, 0.44, 0.14, 1); gfx.rect(x, y0, cw, ch, 1) end
    if lit then gfx.set(0.08, 0.08, 0.09, 1) elseif dim then gfx.set(0.38, 0.40, 0.44, 1) else gfx.set(0.80, 0.82, 0.86, 1) end
    gfx.x, gfx.y = x + pad, y0 + (ch - th) / 2
    gfx.drawstr(text)
    hits[#hits + 1] = { x, x + cw, y, y + row, act }
    return x + cw + gap
  end
  local tr = shown_track()
  local name = tr and track_name(tr) or ""
  local function name_at(y, room)                        -- the name, cut with ".." to its room; false if none
    if room <= 20 * sc or name == "" then return false end
    local s = name
    while gfx.measurestr(s) > room and #s > 1 do s = s:sub(1, -2) end
    if s ~= name then s = s:sub(1, math.max(1, #s - 2)) .. ".." end
    gfx.set(0.92, 0.93, 0.95, 1)
    gfx.x, gfx.y = nx, y + (row - th) / 2
    gfx.drawstr(s)
    return true
  end
  local on = kinds_on(tr)
  local function lit(k) if strip then return on_view[k] == true end; return k == kind end
  local rw = width(right)
  local x
  if rows == 1 then
    local room = w - rw - width(labels) - nx - math.floor(8 * sc)
    x = nx + (name_at(0, room) and room or 0) + math.floor(4 * sc)
    for k = 1, #KINDS do x = chip(x, 0, labels[k], lit(k), not on[k], "kind" .. k) end
    x = math.max(x, w - rw)
    for _, c in ipairs(right) do x = chip(x, 0, c[1], c[3], c[4], c[2]) end
  else
    x = nx - pad
    for k = 1, #KINDS do x = chip(x, 0, labels[k], lit(k), not on[k], "kind" .. k) end
    name_at(row, w - rw - nx - math.floor(8 * sc))
    x = math.max(nx, w - rw)
    for _, c in ipairs(right) do x = chip(x, row, c[1], c[3], c[4], c[2]) end
  end
end

-- STRIP on: an effect's button brings its first one on view
local function scroll_to(k)
  if not cur then return end
  for i, e in ipairs(cur.list) do
    if e.kind == k then
      for _, s in ipairs(slots) do if s.fg == e.fg then return end end
      first = i
      return
    end
  end
end
local function scroll(d)
  if not (strip and cur) then return end
  if d < 0 and more_left then first = first - 1 elseif d > 0 and more_right then first = first + 1 end
end

local function set_kind(k)
  if strip then
    if k ~= kind then kind = k; r.SetExtState(EXT, "kind", KINDS[k].key, true) end
    scroll_to(k)
    return
  end
  if k == kind then return end
  kind = k
  r.SetExtState(EXT, "kind", KINDS[k].key, true)
  follow(true)
end
-- STRIP on or off: the same track, the other way
local function set_strip(on)
  if on == strip then return end
  strip = on
  r.SetExtState(EXT, "strip", on and "1" or "0", true)
  first = 1
  local tr = cur and track_by_guid(cur.proj, cur.tg, cur.tr)
  if not tr then follow(true); return end
  local list = wanted(tr)
  if #list > 0 then show_track(tr, list) else none_note(tr) end
end
local function set_pin(on)
  if on then
    local tr = shown_track()
    if not tr then return end
    pin = tr == r.GetMasterTrack(0) and "MASTER" or r.GetTrackGUID(tr)
  else
    pin = ""
  end
  r.SetExtState(EXT, "pin", pin, true)
  last_sel_g = false
  follow(true)
end

-- Right-click a dim effect button (the shown track has none of it): add it to that track (the user, 2026-10-03:
-- "when the track does not have the fx can we right click add it"). Found as "Add a track with all six" finds
-- them: by its listed name (any install), then the ReaPack package's path, then the EON install's; the right FILE
-- only, a namesake is taken out again. GainKit goes first in the chain (where the GainKit Plus actions put it),
-- the others at the end. Then it is the effect shown (STRIP off), or brought on view (STRIP on).
local function add_kind(k)
  local tr = shown_track()
  if not tr or first_of(tr, k) then return end
  r.Undo_BeginBlock()
  local fx = -1
  for _, n in ipairs({ "JS: EON: " .. KINDS[k].name, "ReaKit FX/FX/Eon_JSFX/FX/" .. KINDS[k].src, "EON/Eon_JSFX/FX/" .. KINDS[k].src }) do
    fx = r.TrackFX_AddByName(tr, n, false, k == 1 and -1000 or -1)   -- -1000 = position 0; -1 = a new one at the end
    if fx >= 0 then
      if kind_of(tr, fx) == k then break end
      r.TrackFX_Delete(tr, fx); fx = -1
    end
  end
  r.Undo_EndBlock("ReaKit FX dock: add " .. KINDS[k].name .. " to " .. track_name(tr), -1)
  if fx < 0 then dbg("add " .. KINDS[k].name .. ": not found"); return end
  dbg("added " .. KINDS[k].name .. " to " .. track_name(tr) .. " at " .. fx)
  if k ~= kind then kind = k; r.SetExtState(EXT, "kind", KINDS[k].key, true) end
  local fg = r.TrackFX_GetFXGUID(tr, fx)
  local list = wanted(tr)
  show_track(tr, list)
  for i, e in ipairs(list) do if e.fg == fg then first = i end end
  has_key = ""                                           -- the buttons look again at once
end

local last_cap = 0
local function bar_mouse()
  local cap = gfx.mouse_cap
  local down = (cap & 1) == 1 and (last_cap & 1) == 0
  local rdown = (cap & 2) == 2 and (last_cap & 2) == 0
  last_cap = cap
  local wheel = gfx.mouse_wheel
  gfx.mouse_wheel = 0
  local in_bar = gfx.mouse_x >= 0 and gfx.mouse_x < gfx.w and gfx.mouse_y >= 0 and gfx.mouse_y < bar_h()
  if wheel ~= 0 and in_bar then scroll(wheel > 0 and -1 or 1) end
  if not (down or rdown) or not in_bar then return end
  for _, h in ipairs(hits) do
    if gfx.mouse_x >= h[1] and gfx.mouse_x < h[2] and gfx.mouse_y >= h[3] and gfx.mouse_y < h[4] then
      local a = h[5]
      if rdown then
        if a:sub(1, 4) == "kind" then add_kind(tonumber(a:sub(5))) end   -- does nothing when the track has it
      elseif a == "pin" then set_pin(pin == "")
      elseif a == "tabs" then set_tabs_hidden(not tabs_hidden())
      elseif a == "strip" then set_strip(not strip)
      elseif a == "left" then scroll(-1)
      elseif a == "right" then scroll(1)
      else set_kind(tonumber(a:sub(5))) end
      return
    end
  end
end

-- lines of text centred in a box, the first brighter; the short set when the long one will not fit
local function text_in(x, y, w, h, long, short)
  local fs = math.floor(15 * sc + 0.5)
  gfx.setfont(1, "Arial", fs)
  local room = w - 16 * sc
  local function widest(t)
    local m = 0
    for _, s in ipairs(t) do m = math.max(m, gfx.measurestr(s)) end
    return m
  end
  local lines = long
  if short and widest(long) > room then lines = short end
  while fs > 9 and widest(lines) > room do fs = fs - 1; gfx.setfont(1, "Arial", fs) end
  local lh, sp = gfx.texth, math.floor(6 * sc)
  local ty = y + (h - (#lines * lh + (#lines - 1) * sp)) / 2
  for i, s in ipairs(lines) do
    if i == 1 then gfx.set(0.85, 0.87, 0.90, 1) else gfx.set(0.60, 0.63, 0.68, 1) end
    gfx.x, gfx.y = x + math.max(8 * sc, (w - gfx.measurestr(s)) / 2), ty
    gfx.drawstr(s, 0, x + w, y + h)                     -- clipped to its box
    ty = ty + lh + sp
  end
end

-- the dock's own face under the bar: the lines between effects, and the words where one is not on view
local function draw_body()
  local b = bar_h()
  gfx.set(0.09, 0.09, 0.10, 1); gfx.rect(0, b, gfx.w, gfx.h - b, 1)   -- a held surface covers its own place
  if #slots == 0 then
    gfx.set(0.16, 0.17, 0.19, 1); gfx.rect(0, b, gfx.w, gfx.h - b, 1)
    local what = strip and "ReaKit FX" or KINDS[kind].name
    local l1, l2
    if note then
      l1 = note
      l2 = strip and "Right-click an effect above to add it here." or "Right-click its button above to add it here."
      if pin ~= "" then l2 = l2 .. " Or unpin." else l2 = l2 .. " Or select another track." end
    elseif not cur then
      l1, l2 = "Select a track with " .. what .. " on it.", "The dock shows " .. (strip and "them" or "it") .. ", and follows your selection."
    end
    if l1 then text_in(0, b, gfx.w, gfx.h - b, { l1, l2 }) end
    return
  end
  for _, s in ipairs(slots) do
    if not s.canvas then
      gfx.set(0.16, 0.17, 0.19, 1); gfx.rect(s.x, s.y, s.w, s.h, 1)
      if s.away then
        local nm = KINDS[s.kind].name
        text_in(s.x, s.y, s.w, s.h, { s.name .. ": " .. nm .. " is open in its own window.", "Close that window to bring it back here." },
                { nm .. " is open", "in its own window.", "Close it to bring", "it back here." })
      end
    end
  end
end

-- for tests: what the dock holds, left to right ("track GUID|FX GUID", comma between), and the strip's view
local pub_held, pub_view = nil, nil
local function publish()
  local t = {}
  for _, s in ipairs(slots) do if s.canvas then t[#t + 1] = s.tg .. "|" .. s.fg end end
  local v = table.concat(t, ",")
  if v ~= pub_held then pub_held = v; r.SetExtState(EXT, "held", v, false) end
  v = string.format("%d %d %d", first, #slots, cur and #cur.list or 0)   -- first on view, on view, on the track
  if v ~= pub_view then pub_view = v; r.SetExtState(EXT, "view", v, false) end
end

-- ── open with REAPER again ────────────────────────────────────────────────────────────────────────
-- Every few seconds the dock stamps the wall clock (saved with REAPER's settings); GainKit Plus, starting with
-- REAPER, compares it with its own stamp and opens the dock again when both were alive at the end. A close by
-- the user (the tab's X) clears the stamp at once.
local wall_t = 0
local function stamp_wall()
  local now = os.time()
  if now - wall_t >= 5 then wall_t = now; r.SetExtState(EXT, "wall", tostring(now), true) end
end

local saved = false
local function save_dock()
  if saved then return end
  saved = true
  r.SetExtState(EXT, "dockstate", tostring(gfx.dock(-1)), true)   -- after gfx.quit the query is garbage
end

local function quit()
  pcall(save_dock)
  release_all()
  r.SetExtState(EXT, "held", "", false)
  r.SetExtState(EXT, "view", "", false)
  r.SetExtState(EXT, "alive", "", false)
  pcall(function() r.set_action_options(8) end)                    -- the toolbar button goes dark
end
local function closed_by_user()
  r.SetExtState(EXT, "wall", "0", true)                            -- not open again with REAPER
end

local function loop()
  r.SetExtState(EXT, "alive", tostring(r.time_precise()), false)   -- for GainKit Plus: the dock is up now
  stamp_wall()
  sc = math.max(1, gfx.ext_retina or 1)
  -- another project tab: let go properly (the floats closed, in THEIR project) and follow this one's selection
  local here = r.EnumProjects(-1)
  if cur and cur.proj ~= here then
    dbg("project changed")
    local held = {}
    for _, s in ipairs(slots) do
      if s.canvas then held[#held + 1] = { tg = s.tg, fg = s.fg, kind = s.kind, name = s.name } end
    end
    tabs_left[cur.proj] = #held > 0 and { cur = cur, first = first, held = held } or nil
    for p in pairs(tabs_left) do                                    -- tabs closed since: forget them
      if not r.ValidatePtr(p, "ReaProject*") then tabs_left[p] = nil end
    end
    release_all(); cur = nil; note = nil; last_sel_g = false
  end
  -- back on a tab it went away from: REAPER shows that project's windows again, the ones the dock closed too
  -- (measured 2026-10-03), so the dock takes them straight back rather than leave them open
  local t = tabs_left[here]
  if t and #slots == 0 then
    tabs_left[here] = nil
    dbg("back on the tab: " .. #t.held)
    cur, first = t.cur, t.first
    for _, h in ipairs(t.held) do
      local rec = { proj = here, tg = h.tg, fg = h.fg, kind = h.kind, name = h.name }
      take(rec, true)
      if not rec.gone then slots[#slots + 1] = rec end
    end
  end
  -- requests from other scripts and from the tests (the bar's buttons do the same)
  if r.GetExtState(EXT, "close") == "1" then
    r.SetExtState(EXT, "close", "", false)
    closed_by_user(); quit(); gfx.quit(); return
  end
  local req = r.GetExtState(EXT, "kind_req")
  if req ~= "" then
    r.SetExtState(EXT, "kind_req", "", false)
    for k, v in ipairs(KINDS) do if v.key == req then set_kind(k) end end
  end
  req = r.GetExtState(EXT, "pin_req")
  if req ~= "" then r.SetExtState(EXT, "pin_req", "", false); set_pin(req == "1") end
  req = r.GetExtState(EXT, "tabs_req")
  if req ~= "" then r.SetExtState(EXT, "tabs_req", "", false); set_tabs_hidden(req == "1") end
  req = r.GetExtState(EXT, "strip_req")
  if req ~= "" then r.SetExtState(EXT, "strip_req", "", false); set_strip(req == "1") end
  req = r.GetExtState(EXT, "scroll_req")
  if req ~= "" then r.SetExtState(EXT, "scroll_req", "", false); scroll(tonumber(req) or 0) end
  req = r.GetExtState(EXT, "add_req")                              -- tests: the right-click on an effect button
  if req ~= "" then
    r.SetExtState(EXT, "add_req", "", false)
    for k, v in ipairs(KINDS) do if v.key == req then add_kind(k) end end
  end
  req = r.GetExtState(EXT, "show_req")                             -- GainKit Plus: a double-click on a name
  if req ~= "" then r.SetExtState(EXT, "show_req", "", false); show_req(req) end

  for _, s in ipairs(slots) do watch(s) end
  sweep()
  follow(false)
  check_chain()
  draw_bar()
  bar_mouse()
  layout()
  sweep()
  draw_body()
  publish()
  gfx.update()
  if gfx.getchar() >= 0 then r.defer(loop) else closed_by_user(); quit() end
end

-- This script's own window: one titled TITLE inside THIS REAPER (docked: under its main window; floating: owned
-- by it). A search of every window by its title alone can find another REAPER's dock (two REAPERs running, a main
-- and a portable: the audit, 2026-10-03), and this one would then move plugins into that window.
local MAIN = r.GetMainHwnd()
local function in_this_reaper(h)
  local p = h
  for _ = 1, 32 do
    if p == MAIN then return true end
    local up = r.JS_Window_GetParent(p)                -- a child's parent; a top-level popup's owner
    if not up then break end
    p = up
  end
  return p == MAIN or r.JS_Window_GetRelated(p, "OWNER") == MAIN
end
local function find_own_window()
  local _, list = r.JS_Window_ListFind(TITLE, true)
  local all = {}
  for a in (list or ""):gmatch("[^,]+") do
    local h = r.JS_Window_HandleFromAddress(tonumber(a))
    if h then
      if in_this_reaper(h) then dbg("own window " .. tostring(h) .. ": this REAPER's"); return h end
      all[#all + 1] = h
    end
  end
  dbg("own window: " .. #all .. " titled so, none under this REAPER")
  if #all == 1 then return all[1] end                  -- one alone (a floating window with no owner): no doubt
end

local dockstate = tonumber(r.GetExtState(EXT, "dockstate")) or 1    -- docked, in the first docker
gfx.ext_retina = 1                                                  -- sizes in real pixels; the scale comes back here
gfx.init(TITLE, W0, H0, dockstate)
gfx.update()
dock = find_own_window()
if not dock then
  r.MB("The ReaKit FX dock could not find its own window. Run the action again.", "ReaKit FX", 0)
  gfx.quit()
  return
end
-- The dock window never paints over the plugins it holds (WS_CLIPCHILDREN): it redraws every frame (cleared,
-- then the bar), and without this its blit covered a plugin until the plugin drew again (2026-10-03: a
-- docked GainKit came out black under a two-row bar while it was drawing ~38 frames a second).
local style = r.JS_Window_GetLong(dock, "STYLE")
if style then r.JS_Window_SetLong(dock, "STYLE", math.floor(style) | 0x02000000) end
pcall(function() r.set_action_options(1 | 4) end)                   -- run again = close it; the button lights
for _, k in ipairs({ "close", "kind_req", "pin_req", "tabs_req", "strip_req", "scroll_req", "add_req" }) do
  r.SetExtState(EXT, k, "", false)                                  -- old requests must not reach this run
end
r.atexit(quit)
loop()
