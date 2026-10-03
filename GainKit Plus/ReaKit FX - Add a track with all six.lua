-- ReaKit FX -- add a track called "ReaKit FX" at the end of the project with all six free effects on
-- it (GainKit, 3-Band EQ, DDC, De-Esser, Saturation, Stereo Width, in that order) and their windows
-- open, laid out side by side over REAPER's window, so a new user sees all six at once (the user,
-- 2026-10-03: "one track with all the plugins floating"). One undo step. The start action offers it
-- once, at first setup (a switch in its summary window); run this any time for another one.
-- EON Floatter, when it runs, sizes each window as it opens; this only places them. Without
-- js_ReaScriptAPI the windows open where REAPER puts them. MIT, EON Studios, 2026.
local r = reaper

-- each by its listed name first (any install), then the ReaPack package's path, then the EON install's
local SIX = {
  { name = "GainKit",      file = "ChannelTool_ReaKit.jsfx", w = 350, h = 546 },
  { name = "3-Band EQ",    file = "3BandEQ_ReaKit.jsfx",     w = 418, h = 228 },
  { name = "DDC",          file = "DDC_ReaKit.jsfx",         w = 573, h = 319 },
  { name = "De-Esser",     file = "DeEsser_ReaKit.jsfx",     w = 465, h = 376 },
  { name = "Saturation",   file = "Saturation_ReaKit.jsfx",  w = 288, h = 506 },
  { name = "Stereo Width", file = "StereoWidth_ReaKit.jsfx", w = 291, h = 364 },
}
-- w, h: each window's designed canvas at 100 % (EON Floatter's SIZES); a window adds REAPER's frame,
-- title and preset bar, 16 x 66 at 100 % (wiki 6.7). The layout, in those outer sizes: GainKit and
-- Saturation (the tall two) on the left; DDC over the 3-Band EQ; the De-Esser over Stereo Width.
-- At 100 % that is 1740 x 872, which fits a 1080p screen; a smaller REAPER window overlaps them.
local SLOT = { [1] = { 0, 0 }, [5] = { 366, 0 }, [3] = { 670, 0 }, [2] = { 670, 385 }, [4] = { 1259, 0 }, [6] = { 1259, 442 } }
local LAYOUT_W, LAYOUT_H = 1740, 872

-- the file name alone, from a path with either slash
local function basename(path) return (path:gsub("^.*[/\\]", "")) end

local function add(tr, p)
  for _, n in ipairs({ "JS: EON: " .. p.name, "ReaKit FX/FX/Eon_JSFX/FX/" .. p.file, "EON/Eon_JSFX/FX/" .. p.file }) do
    local fx = r.TrackFX_AddByName(tr, n, false, -1)
    if fx >= 0 then
      local ok, id = r.TrackFX_GetNamedConfigParm(tr, fx, "fx_ident")
      -- the right FILE, not a namesake: its exact file name, whole (wiki 6.16)
      if not ok or basename(id):lower() == p.file:lower() then return fx end
      r.TrackFX_Delete(tr, fx)
    end
  end
  return -1
end

-- the display scale Floatter learned (1 if none) times its global dial: the windows' real sizes
local function scale()
  local s = tonumber(r.GetExtState("EON_FloatSize", "scale")) or 1
  local g = (tonumber(r.GetExtState("EON_FloatSize", "global")) or 100) / 100
  if s <= 0 then s = 1 end
  return s * math.min(math.max(g, 0.75), 1.5)
end

r.Undo_BeginBlock()
r.PreventUIRefresh(1)
local n = r.CountTracks(0)
r.InsertTrackAtIndex(n, true)
local tr = r.GetTrack(0, n)
r.GetSetMediaTrackInfo_String(tr, "P_NAME", "ReaKit FX", true)
local fxs, missed = {}, {}
for i, p in ipairs(SIX) do
  local fx = add(tr, p)
  if fx >= 0 then fxs[i] = fx else missed[#missed + 1] = p.name end
end
r.PreventUIRefresh(-1)
r.TrackList_AdjustWindows(false)

-- open and place the windows: left to right in the layout, centred on REAPER's window, squeezed
-- (overlapping) when it is narrower or shorter than the layout
local placed = 0
local main = r.GetMainHwnd()
local ok, L, T, R, B = false
if r.JS_Window_GetRect then ok, L, T, R, B = r.JS_Window_GetRect(main) end
local s = scale()
local fw, fh = LAYOUT_W * s, LAYOUT_H * s
local kx = (ok and (R - L) < fw + 40) and math.max((R - L - 40) / fw, 0.3) or 1
local ky = (ok and (B - T - 120) < fh) and math.max((B - T - 120) / fh, 0.3) or 1
local x0 = ok and (L + math.max(20, ((R - L) - fw * kx) / 2)) or 0
local y0 = ok and (T + 100) or 0
for i = 1, #SIX do
  local fx = fxs[i]
  if fx then
    r.TrackFX_Show(tr, fx, 3)
    local h = r.TrackFX_GetFloatingWindow(tr, fx)
    if h and ok and r.JS_Window_Move then
      r.JS_Window_Move(h, math.floor(x0 + SLOT[i][1] * s * kx + 0.5), math.floor(y0 + SLOT[i][2] * s * ky + 0.5))
      placed = placed + 1
    end
  end
end
r.Undo_EndBlock("ReaKit FX: add a track with all six", -1)

if #missed > 0 and r.GetExtState("EON_GainKitPlus", "quiet") ~= "1" then
  r.MB("Not found, so not added: " .. table.concat(missed, ", ") .. "." .. string.char(10, 10)
    .. "Install ReaKit FX from ReaPack, then run this again.", "ReaKit FX", 0)
end
