-- ReaKit FX - Dock Filter: Filter alone in its own docker tab, following the selected track (EON Studios,
-- 2026-10-31; the user: "I definitely want each plugin to have its own separate dock tab"). Run it again to close
-- the tab. The dock itself is "ReaKit FX - Dock following the selected track.lua", beside this file; this only
-- names the plugin. Windows only; needs js_ReaScriptAPI (ReaPack). EON Free Licence 1.0, EON Studios, 2026.
REAKIT_DOCK_ONLY = { key = "flt", title = "Filter" }
dofile((debug.getinfo(1, "S").source:match("^@(.*[\\/])") or "") .. "ReaKit FX - Dock following the selected track.lua")
