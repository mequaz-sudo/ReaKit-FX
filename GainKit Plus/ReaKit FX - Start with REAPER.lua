-- ReaKit FX -- start everything with REAPER, in one press. Puts GainKit Plus into
-- Scripts/__startup.lua (the same as running "GainKit Plus - Start with REAPER") when it is not
-- there yet, and starts EON Floatter once when it has not registered itself yet -- Floatter
-- writes its own start-up block on its first run. Running this again changes nothing: each
-- part is skipped when it is already in place. Once, it sets the six to open embedded in the
-- mixer strip (REAPER's own per-plugin default), and offers to raise REAPER's meter refresh to
-- 120 a second, so the plugin faces in the mixer strips answer quicker (next start).
-- One small window in the ReaKit look says what was done and carries that offer as a switch
-- (the plain message box without ReaImGui). MIT, EON Studios, 2026.
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
-- what the summary says, one line each: ok = a check mark, not ok = something for the user to do
local done = {}
local function say(ok, text, tip) done[#done + 1] = { ok = ok, text = text, tip = tip } end
local need_plus = false

-- 1. GainKit Plus: its action is a toggle, so only run it when its block is absent
if startup:find("GainKit Plus: start with REAPER", 1, true) then
  say(true, "GainKit Plus starts with REAPER")
elseif not exists(PLUS_SETUP) then
  say(false, "GainKit Plus is missing a file. Reinstall GainKit Plus from ReaPack, then run this again.")
else
  local was_quiet = r.GetExtState("EON_GainKitPlus", "quiet")
  r.SetExtState("EON_GainKitPlus", "quiet", "1", false)          -- no dialog from it; ours below
  local ok, c = pcall(r.AddRemoveReaScript, true, 0, PLUS_SETUP, true)
  if ok and c and c > 0 then r.Main_OnCommand(c, 0) end
  if was_quiet == "1" then r.SetExtState("EON_GainKitPlus", "quiet", "1", false) else r.DeleteExtState("EON_GainKitPlus", "quiet", false) end
  startup = read(STARTUP) or ""
  if startup:find("GainKit Plus: start with REAPER", 1, true) then
    say(true, "GainKit Plus is on and starts with REAPER")
  else
    say(false, "GainKit Plus couldn't be set to start with REAPER. Run this again.")
  end
  need_plus = true   -- the setup starts Plus itself, but not when it is launched from a launched action: checked below
end

-- 1b. The six open embedded in the mixer strip, the way REAPER does it for any plugin: its FX
-- browser's "Default settings for new instances > Show embedded UI in MCP" is bit 4 of the
-- plugin's line in reaper-fxoptions.ini [defcfg], and REAPER reads that file at every insert
-- (measured, 2026-10-01). Each install path REAPER lists for the six (reaper-jsfx.ini) gets the
-- bit, the line's other bits kept. Once: a plugin the user later sets back stays as they set it.
local FREE6 = { "ChannelTool_ReaKit.jsfx", "Saturation_ReaKit.jsfx", "3BandEQ_ReaKit.jsfx",
                "DDC_ReaKit.jsfx", "DeEsser_ReaKit.jsfx", "StereoWidth_ReaKit.jsfx" }
local BUSY = "REAPER was busy, so the six effects weren't set to open in the mixer strip. Run this again."
-- returns ok, the line to show (nil, nil when it was done on an earlier run)
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
  if #paths == 0 then return false, "The six effects weren't found. Install ReaKit FX from ReaPack, then run this again." end
  local opt = res .. sep .. "reaper-fxoptions.ini"
  local txt = read_opt(opt)
  if not txt then return false, BUSY end              -- reaper-fxoptions.ini locked for a moment
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
  if changed > 0 and not replace_file(opt, bom .. table.concat(lines, nl) .. nl) then return false, BUSY end
  r.SetExtState("EON_ReaKitFX", "embed_defaults", "1", true)
  -- REAPER's own setting per plugin: the line stays plain, its tooltip says where to change it
  return true, "The six effects open right in the mixer strip",
    "REAPER's own setting for each plugin: right-click it in the FX browser, then Default settings for new instances."
end
local eok, emsg, etip = embed_defaults()
if emsg then say(eok, emsg, etip) end

-- 2. EON Floatter: registers itself in the start-up file on its first run
local need_floatter = false
local fl                                              -- Floatter's script, when installed
if startup:find("-- EON:EON_Floatter BEGIN", 1, true) then
  say(true, "EON Floatter starts with REAPER")
else
  for _, p in ipairs(FLOATTERS) do if exists(p) then fl = p; break end end
  if not fl then
    say(false, "EON Floatter isn't installed. Install it from ReaPack, then run this again.")
  else
    local ok, c = pcall(r.AddRemoveReaScript, true, 0, fl, true)
    if ok and c and c > 0 then
      -- a quiet launch: Floatter turns on and registers itself with no panel (the user, 2026-10-02:
      -- "turn the startup action on without opening floatter"). Any launch_src word other than
      -- "user" / "setup" is quiet in every Floatter that reads it; "setup" (1.0.3's open-then-close
      -- peek) is no longer sent. Without js_ReaScriptAPI it prints one console line and stops, and
      -- the summary says so.
      r.SetExtState("EON_Floatter", "launch_src", "reakitfx:" .. r.time_precise(), false)
      r.Main_OnCommand(c, 0)
      need_floatter = true   -- what to say waits for its heartbeat (settle, below)
    else
      say(false, "EON Floatter couldn't be started. Run EON Floatter from the action list.")
    end
  end
end

-- Plus running? Its heartbeat (EXT alive, stamped every tick while it runs) is the sign; a
-- launch from here is one level shallower than the setup's own, which REAPER drops when this
-- action was itself launched by another script. Checked after a short wait, then the summary;
-- a probe sets EON_GainKitPlus/quiet and gets none.
local function plus_alive()
  local hb = tonumber(r.GetExtState("EON_GainKitPlus", "alive")) or 0
  local st = tonumber(r.GetExtState("EON_GainKitPlus", "stop")) or 0
  return hb > st and r.time_precise() - hb < 1.0
end
-- 3. Faster mixer strips: REAPER redraws its meters and every plugin face in a strip at its meter
-- rate (Preferences > Appearance > Track meter settings), 30 a second out of the box. Offered ONCE,
-- only raised, never lowered: 120 took a 23-track mixer's strips from 27 to 55 redraws a second
-- (2026-10-01). Written to reaper.ini; REAPER applies it at its next start. A probe answers
-- through EON_ReaKitFX/test_rate ("yes"/"no") instead of the summary's switch.
local RATE = 120
local NL = string.char(10)
-- the meter rate now when the offer is due; nil on an older REAPER, once offered, or at RATE already
local function rate_offer()
  if not (r.get_config_var_string and r.set_config_var_string) then return nil end   -- older REAPER
  if r.GetExtState("EON_ReaKitFX", "rate_asked") == "1" then return nil end
  local ok, cur = r.get_config_var_string("vuupdfreq")
  cur = ok and tonumber(cur) or 30
  if cur >= RATE then r.SetExtState("EON_ReaKitFX", "rate_asked", "1", true); return nil end
  return cur
end
-- the answer: offered once either way; only a yes writes, and a write REAPER refuses says where
local function rate_answer(yes)
  r.SetExtState("EON_ReaKitFX", "rate_asked", "1", true)
  if not yes then return end
  local res = r.set_config_var_string("vuupdfreq", tostring(RATE), 1)
  if not (res == true or (type(res) == "number" and res > 0)) and r.GetExtState("EON_GainKitPlus", "quiet") ~= "1" then
    r.MB("REAPER didn't take the faster mixer setting. You can set it in Preferences > Appearance > Track meter settings.",
         "ReaKit FX", 0)
  end
end

-- Floatter launched? Its heartbeat (EON_Floatter/alive_t, every tick) says it runs; its block in
-- the start-up file says it starts with REAPER. Launched quietly it stops at once without
-- js_ReaScriptAPI (one console line), and a user who switched "starts with REAPER" off keeps it
-- off: the summary says what is true (outside review, 2026-10-02: it used to say "running" always).
-- Returns true when it runs.
local function floatter_says()
  local hb = tonumber(r.GetExtState("EON_Floatter", "alive_t")) or 0
  if r.time_precise() - hb > 1.0 then
    say(false, "EON Floatter didn't start: it needs js_ReaScriptAPI. Install that from ReaPack, restart REAPER, then run this again.")
    return false
  end
  if (read(STARTUP) or ""):find("-- EON:EON_Floatter BEGIN", 1, true) then
    say(true, "EON Floatter is on and starts with REAPER")
  else
    say(false, "EON Floatter is on, but won't start with REAPER. Open EON Floatter from the action list and switch on \"starts with REAPER\".")
  end
  return true
end

-- The EON plugins already in this project, counted the way Floatter's "Set them now" counts them
-- (W.instances: a size in its table, or one the user kept). Its embed entry returns L and SIZES
-- before anything of it runs (EON_FLOATTER_EMBED, as its probes use it). 0 when that fails.
local function eon_in_project(path)
  EON_FLOATTER_EMBED = true
  local ok, mod = pcall(dofile, path)
  EON_FLOATTER_EMBED = nil
  if not ok or type(mod) ~= "table" or type(mod.L) ~= "table" or type(mod.SIZES) ~= "table" then return 0 end
  local L, SIZES, n = mod.L, mod.SIZES, 0
  local function scan(tr)
    if not tr then return end
    for fx = 0, r.TrackFX_GetCount(tr) - 1 do
      local key = L.fx_key(tr, fx)
      if SIZES[key] or (L.get_capture and L.get_capture(key)) or (L.get_legacy and L.get_legacy(key)) then n = n + 1 end
    end
  end
  scan(r.GetMasterTrack(0))
  for i = 0, r.CountTracks(0) - 1 do scan(r.GetTrack(0, i)) end
  return n
end

-- The quiet launch shows no panel, so nobody sees Floatter's welcome card and its "Set them now":
-- this does it for them (the user, 2026-10-02: "that should happen automatically after install, to
-- make it seamless"). Floatter's own request "apply_project" runs that same pass (W.quiet_pass:
-- every EON plugin in the project to its size, closed floats opened invisibly for a moment) on its
-- next tick; the card is marked seen, its question answered.
local function floatter_size_project()
  local n = fl and eon_in_project(fl) or 0
  r.SetExtState("EON_Floatter", "welcomed_v1", "1", true)
  if n == 0 then return end
  r.SetExtState("EON_Floatter", "req", "apply_project", false)
  say(true, n == 1 and "The EON plugin in this project is set to its designed size"
    or ("The %d EON plugins in this project are set to their designed sizes"):format(n))
end

-- 4. The summary: one small window in the ReaKit look (Floatter's palette: dark slate, EON blue,
-- the orange mark). A check mark per line done, an amber mark per line the user has to act on,
-- the faster-mixer offer as a switch (on to start with); OK or Enter finishes and answers the
-- offer. Not modal: Floatter and GainKit Plus keep running behind it (the old
-- message box held every script's loop). Without ReaImGui, or if the window fails: the plain
-- message box, the offer as its Yes / No. (The user, 2026-10-02: "too wordy", "too techy",
-- "needs some gui polish".)
local P = {
  bg = 0x161F28FF, raised = 0x1C2732FF, line = 0x283644FF, line2 = 0x34465AFF, text = 0xDBE3EAFF,
  muted = 0x8B95A1FF, dim = 0x5B6773FF, accent = 0x3A86D0FF, accent_lo = 0x2A6FB0FF,
  accent_hi = 0x4D9AE6FF, accent_dn = 0x1E5A94FF, brand = 0xE8532AFF, ok = 0x58C858FF,
  warn = 0xE6B84FFF, warn_ink = 0x1A1408FF, white = 0xFFFFFFFF,
}
local all_ok = true
local function plain_box(cur)
  local t = {}
  for _, d in ipairs(done) do t[#t + 1] = (d.ok and "" or "(!) ") .. d.text end
  local msg = table.concat(t, NL)
  if cur then
    rate_answer(r.MB(msg .. NL .. NL .. "Make the mixer strips faster? Plugin faces in the mixer move more smoothly"
      .. " from the next time REAPER starts.", "ReaKit FX", 4) == 6)
  else
    r.MB(msg, "ReaKit FX", 0)
  end
end

local function window(cur)
  if not r.ImGui_GetBuiltinPath then return false end
  local okl, ImGui = pcall(function()
    package.path = r.ImGui_GetBuiltinPath() .. "/?.lua;" .. package.path
    return require("imgui")("0.10")
  end)
  if not okl or type(ImGui) ~= "table" then return false end
  local ctx = ImGui.CreateContext("ReaKit FX")
  local function font(flags)
    local okf, f = pcall(ImGui.CreateFont, "sans-serif", flags)
    if okf and f and pcall(ImGui.Attach, ctx, f) then return f end
  end
  local bold, body = font(ImGui.FontFlags_Bold), font(nil)
  local fast, W = true, 360                           -- the offer starts on; the text column's width
  local FLAGS = ImGui.WindowFlags_NoTitleBar | ImGui.WindowFlags_NoCollapse | ImGui.WindowFlags_NoResize
    | ImGui.WindowFlags_AlwaysAutoResize | ImGui.WindowFlags_NoDocking | ImGui.WindowFlags_NoSavedSettings
    | (rawget(ImGui, "WindowFlags_TopMost") or 0)
  local COLS = {
    { ImGui.Col_WindowBg, P.bg }, { ImGui.Col_Border, P.line2 }, { ImGui.Col_Text, P.text },
    { ImGui.Col_PopupBg, P.raised }, { ImGui.Col_Separator, P.line }, { ImGui.Col_Button, P.accent_lo },
    { ImGui.Col_ButtonHovered, P.accent }, { ImGui.Col_ButtonActive, P.accent_dn },
  }
  local VARS = {
    { ImGui.StyleVar_WindowRounding, 6 }, { ImGui.StyleVar_FrameRounding, 4 },
    { ImGui.StyleVar_WindowBorderSize, 1 }, { ImGui.StyleVar_WindowPadding, 22, 18 },
    { ImGui.StyleVar_ItemSpacing, 8, 9 }, { ImGui.StyleVar_FramePadding, 10, 6 },
  }

  local function row_mark(dl, x, y, lh, ok)          -- a check mark, or an amber "!" disc
    local cy = y + lh / 2
    if ok then
      ImGui.DrawList_AddLine(dl, x + 2, cy, x + 6, cy + 4, P.ok, 2)
      ImGui.DrawList_AddLine(dl, x + 6, cy + 4, x + 14, cy - 5, P.ok, 2)
    else
      ImGui.DrawList_AddCircleFilled(dl, x + 8, cy, 8, P.warn)
      local ew, eh = ImGui.CalcTextSize(ctx, "!")
      ImGui.DrawList_AddText(dl, x + 8 - ew / 2, cy - eh / 2, P.warn_ink, "!")
    end
  end

  local function draw()
    local finish, open = false, true
    for _, c in ipairs(COLS) do ImGui.PushStyleColor(ctx, c[1], c[2]) end
    for _, v in ipairs(VARS) do ImGui.PushStyleVar(ctx, v[1], v[2], v[3]) end
    local cx, cy = ImGui.Viewport_GetCenter(ImGui.GetMainViewport(ctx))
    ImGui.SetNextWindowPos(ctx, cx, cy, ImGui.Cond_Appearing, 0.5, 0.5)
    local visible
    visible, open = ImGui.Begin(ctx, "ReaKit FX###reakitfx_summary", true, FLAGS)
    if visible then
      local dl = ImGui.GetWindowDrawList(ctx)
      if body then ImGui.PushFont(ctx, body, 15) end
      -- the title: the orange mark, then one bold line
      local x, y = ImGui.GetCursorScreenPos(ctx)
      if bold then ImGui.PushFont(ctx, bold, 19) end
      local th = ImGui.GetTextLineHeight(ctx)
      ImGui.DrawList_AddCircleFilled(dl, x + 5, y + th / 2 + 1, 5, P.brand)
      ImGui.SetCursorScreenPos(ctx, x + 18, y)
      ImGui.Text(ctx, all_ok and "ReaKit FX is ready" or "ReaKit FX is almost ready")
      if bold then ImGui.PopFont(ctx) end
      ImGui.Dummy(ctx, W, 0)                          -- holds the window at the column's width
      ImGui.Separator(ctx)
      ImGui.Dummy(ctx, 0, 2)
      for _, d in ipairs(done) do
        local ix, iy = ImGui.GetCursorScreenPos(ctx)
        row_mark(dl, ix, iy, ImGui.GetTextLineHeight(ctx), d.ok)
        ImGui.SetCursorScreenPos(ctx, ix + 26, iy)
        ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + W - 26)
        ImGui.Text(ctx, d.text)
        ImGui.PopTextWrapPos(ctx)
        if d.tip and ImGui.IsItemHovered(ctx) then ImGui.SetTooltip(ctx, d.tip) end
      end
      if cur then                                     -- the offer: a switch, its name, one quiet line
        ImGui.Dummy(ctx, 0, 2)
        ImGui.Separator(ctx)
        ImGui.Dummy(ctx, 0, 2)
        local sx, sy = ImGui.GetCursorScreenPos(ctx)
        local lh = ImGui.GetTextLineHeight(ctx)
        local sw, sh = 34, 18
        if ImGui.InvisibleButton(ctx, "##fast", W, math.max(sh, lh)) then fast = not fast end
        local hov = ImGui.IsItemHovered(ctx)
        if hov then
          ImGui.SetTooltip(ctx, ("REAPER's meter refresh, from %d to %d times a second. You can change it any time"
            .. " in Preferences > Appearance > Track meter settings."):format(math.floor(cur), RATE))
        end
        local track = fast and (hov and P.accent_hi or P.accent) or (hov and P.dim or P.line2)
        ImGui.DrawList_AddRectFilled(dl, sx, sy, sx + sw, sy + sh, track, sh / 2)
        ImGui.DrawList_AddCircleFilled(dl, fast and (sx + sw - 9) or (sx + 9), sy + sh / 2, 7, P.white)
        ImGui.DrawList_AddText(dl, sx + sw + 10, sy + (sh - lh) / 2, P.text, "Faster mixer strips")
        ImGui.SetCursorScreenPos(ctx, sx + sw + 10, sy + sh + 4)
        ImGui.PushTextWrapPos(ctx, ImGui.GetCursorPosX(ctx) + W - sw - 10)
        ImGui.TextColored(ctx, P.muted, "Plugin faces in the mixer move more smoothly.")
        ImGui.PopTextWrapPos(ctx)
      end
      ImGui.Dummy(ctx, 0, 4)
      -- the one thing left to do, right above OK, while the offer is on (the user, 2026-10-02: the
      -- grey "next time REAPER starts" was too easy to miss). The line is always reserved, so the
      -- window does not jump when the switch moves.
      if cur then
        if fast then
          ImGui.TextColored(ctx, P.warn, "Restart REAPER to get the faster mixer strips")
        else
          ImGui.Dummy(ctx, 0, ImGui.GetTextLineHeight(ctx))
        end
      end
      local bw = 96
      ImGui.SetCursorPosX(ctx, ImGui.GetCursorPosX(ctx) + W - bw)
      ImGui.PushStyleColor(ctx, ImGui.Col_Text, P.white)
      if ImGui.Button(ctx, "OK", bw, 0) then finish = true end
      ImGui.PopStyleColor(ctx, 1)
      -- Enter as OK. No Esc: it never reached the window in the test REAPER, keyboard capture and
      -- keyboard navigation tried (2026-10-02), so the window does not promise it
      if ImGui.IsKeyPressed(ctx, ImGui.Key_Enter) or ImGui.IsKeyPressed(ctx, ImGui.Key_KeypadEnter) then finish = true end
      if body then ImGui.PopFont(ctx) end
      ImGui.End(ctx)
    end
    ImGui.PopStyleVar(ctx, #VARS)
    ImGui.PopStyleColor(ctx, #COLS)
    return finish, open
  end

  local function frame()
    if not ImGui.ValidatePtr(ctx, "ImGui_Context*") then return plain_box(cur) end
    local ok, finish, open = pcall(draw)
    if not ok then
      r.ShowConsoleMsg("[ReaKit FX] the summary window failed (" .. tostring(finish) .. "); the plain box instead." .. NL)
      return plain_box(cur)
    end
    if finish then
      if cur then rate_answer(fast) end
      return
    end
    if open then r.defer(frame) end                   -- (no close box: OK / Enter end it)
  end
  frame()
  return true
end

local t0 = r.time_precise()
local function settle()
  if (need_plus or need_floatter) and r.time_precise() - t0 < 1.0 then return r.defer(settle) end
  if need_plus and not plus_alive() and exists(PLUS) then
    local ok, c = pcall(r.AddRemoveReaScript, true, 0, PLUS, true)
    if ok and c and c > 0 then r.Main_OnCommand(c, 0) end
  end
  if need_floatter and floatter_says() then floatter_size_project() end
  for _, d in ipairs(done) do all_ok = all_ok and d.ok end
  local cur = rate_offer()
  if r.GetExtState("EON_GainKitPlus", "quiet") == "1" then          -- a probe: no window
    if cur then
      local t = r.GetExtState("EON_ReaKitFX", "test_rate")
      if t ~= "" then rate_answer(t == "yes") end                    -- no test answer: offered next time
    end
    return
  end
  if not window(cur) then plain_box(cur) end
end
settle()
