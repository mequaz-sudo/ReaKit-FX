-- ReaKit FX - Mixer slot top: every mixer strip scrolls its effects back to the top (the first slot) (the same row on each), for a key or a
-- toolbar button (the user, 2026-11-05). The dock's MIXER SLOT button does the same, and they share where they are.
-- Needs js_ReaScriptAPI and the mixer open. EON Free Licence 1.0, EON Studios, 2026.
local dir = debug.getinfo(1, "S").source:sub(2):gsub("[^/" .. string.char(92) .. "]*$", "")   -- this file's folder
local SLOT = assert(loadfile(dir .. "ReaKit FX - Mixer slot.lua"))({ r = reaper })
SLOT.max = math.max(2, math.min(SLOT.longest(), 32))
SLOT.go(1)
reaper.defer(function() end)                             -- no undo point
