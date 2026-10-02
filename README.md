# ReaKit FX

Six free effects for REAPER with EON Studios interfaces, drawn by the
[ReaKit](https://github.com/mequaz-sudo/ReaKit) library: Saturation, 3-Band EQ and DDC by
LOSER, a De-Esser built on Liteon's, and EON's own GainKit and Stereo Width. Every face is
code, no image files, so it scales to any size and renders at full resolution on HiDPI.

![The six free effects in every mixer strip, on the EON theme](screenshots/session/session_eon.png)

*The six, embedded, on every channel of a session, on a REAPER with nothing but this package
installed: GainKit on top (the track's name and colour from GainKit Plus), Saturation, the 3-Band
EQ, DDC with its gain-reduction bar, and Stereo Width at the bottom; the De-Esser sits on the two
vocal tracks. This is the EON theme, the look a fresh install opens on. Click a strip's empty
space to open a plugin's window, click the strip again to close it.*

![ReaKit FX](screenshots/session/cover_ssl.png)

*A session on the suite's SSL theme with GainKit Plus running. Every channel and bus starts with
GainKit: the track's name on a band in the track's colour, the VU over the GAIN knob, and the
STEREO / MONO key. 4-Band EQ from the EON suite sits under it; the master runs GainKit and 3-Band
EQ, its name typed. Click a strip's empty space to open the window, click the strip again to close
it; with VU DRAG on, drag the meter to set the gain.*

## The plugins

![The six windows on the Light theme](screenshots/session/six_windows_light.png)

*The six windows on the Light theme.*

### GainKit

![GainKit](screenshots/session/gainkit.png)

![GainKit's strip faces on the Light theme](screenshots/session/gainkit_faces_light.png)

*GainKit in the mixer on the Light theme, GainKit Plus running. The five channels show the VU over
the GAIN knob, the meter in the track's colour and the name on top. Three of the buses show the VU
alone: the STEREO / MONO key under the name and, on two of them, the gain under the meter. Drums
shows the VU over the knob. Under GainKit: 4-Band EQ from the EON suite.*

Gain staging on a VU. An analog VU meter (the ReaKit meter: 300 ms to 99 %, 1.2 % overshoot, 20
faces), one GAIN knob and a STEREO / MONO key. The needle reads the louder side, so a sound panned
hard to one side reads at its real level; METERS = TWO shows a meter for each side instead, in the
window (with a trim knob for each side) and in the strip. In the mixer strip it shows the VU over
the knob, the VU alone, or the knob alone, with numerals or ticks only, and the VU grows flatter as
you drag the strip wider. The VU alone keeps its own STEREO / MONO key under the name (ST/MONO
hides it; MONO then shows as a small cyan dot) and prints the value under the meter while you set
it, or all the time. Click the middle of the window's meter face and
type, and the name is printed on the meter like a legend and on top of the strip, in every view:
as a plain row, on a band in the track's colour, or not at all. The high-pass, low-pass, trims and
M/S modes it used to show are still there as parameters, so old projects sound the same.

![GainKit with METERS on ONE and on TWO](screenshots/session/gainkit_one_two.png)

![Mixer strips with two meters each, in the track's colour](screenshots/session/strips_two_meters.png)

*METERS on ONE and on TWO: a meter for each side, with a trim knob under each in the window, and
two meters in every strip and on the master, here in the track's colour.*

#### GainKit Plus

Actions that come with GainKit (install **GainKit Plus** from the same repository; they appear
in the Actions list as `Script: GainKit Plus…`):

- **GainKit Plus** — run it once and every GainKit in the project shows its track's name on top
  of the strip and as the meter's legend, the track's colour along the top of the strip or as the
  name's band (and under the window's header), and the track's icon in the window's header; the
  meter can take the colour too. The master's GainKit shows the project's name. A name typed on
  the meter still wins. Run it again to stop; put it on a toolbar and the button lights while it
  runs. On REAPER 7.81 and later every GainKit reads its track's name from REAPER itself, so
  the name needs no script there; the colour, the icon and the master's project name still come
  from GainKit Plus, which serves the first 512 tracks. It also carries out the THEME panel's EMBED
  row: it moves the plugin and sets where new copies of the six open.
- **Insert on selected tracks** — GainKit first in the chain of every selected track that has
  none, opened embedded in the mixer strip.
- **GainKit first in every chain** — moves the GainKit a track already has to the top of its
  chain, the master's too.
- **GainKit first on selected tracks** — the same, for the selected tracks only.
- **GainKit last on the master** — moves the master's GainKit to the end of its chain, or adds
  one there, so the mix gets a final VU after everything else.
- **Copy look to all** — the look of the selected track's GainKit (what the strip shows, the name
  row and its font, the meter's colour, VALUE, METERS, VU DRAG, ST/MONO, NAME BAR, NATIVE) on every
  GainKit at once.
- **Reset all gains** — every GainKit's GAIN back to 0 dB.
- **All MONO** / **All STEREO** — every GainKit's key at once.
- **Bypass all** — every GainKit off; run it again and they are all on.
- **Remove all GainKits** — takes GainKit off every track after asking once; Undo puts them back.
- **Start with REAPER** — GainKit Plus starts with REAPER from now on (it goes into
  `Scripts/__startup.lua`, nothing else there is touched); run it again to take it out.
- **ReaKit FX - Start with REAPER** — one press for everything: GainKit Plus into the start-up
  file, and EON Floatter started once so it registers itself. Once, it sets the six to open
  embedded in the mixer strip (REAPER's own default for new instances; other plugins' defaults are
  left as they are). The first time, it also offers to
  raise REAPER's meter refresh to 120 a second so the mixer strips answer quicker (from the next
  start). Run it again and nothing changes.

The actions and the names reach a GainKit inside an FX container too.

![The same strips with GainKit Plus off, then on](screenshots/session/plus_off_on.png)

*Plus off (top) and on (bottom), on REAPER 7.81: the names are there either way, from REAPER
itself; Plus adds the track's colour on the name band and the meter, the icon in the window's
header, and the project's name on the master.*

With the THEME panel's VU DRAG on, the meter in the mixer strip is the gain control: drag it up or
down (Ctrl fine, Shift finer), the wheel steps it, double-click returns it to 0 dB, the VU alone
shows the gain as a tint of the meter's face (up from the middle for a boost, down for a cut), and
the value shows under it while you set it and a moment after. VU DRAG is off by default: the meter
then only reads, and a click on it opens the window like the rest of the strip. The THEME panel's FONT row picks the face the name is printed in, on the
window's meter and on top of the strip.

![The same session on the EON theme, GainKit Plus running](screenshots/session/session_eon.png)

*The same session on the EON theme. The channels and buses take their names and colours from
their tracks, through GainKit Plus; the master's name is typed.*

### Saturation

![Saturation](screenshots/session/saturation.png)

LOSER's saturation: one DRIVE knob, a transfer display that shows what the drive is doing to the
signal, and an output meter. The LED bypasses it.

### 3-Band EQ

![3-Band EQ](screenshots/session/3bandeq.png)

LOSER's three-band equalizer: low, mid and high gain with the two crossover frequencies, an output
level, and a switch per band. The standalone window draws everything at one scale, so a wider
window gets bigger knobs, not more empty space.

### DDC

![DDC](screenshots/session/ddc.png)

LOSER's Digital Drum Compressor: threshold, ratio, attack, hold and release, knee, mix, a
sidechain high-pass, stereo link, lookahead, RMS or peak detection, feed-forward, feedback or an
external sidechain, auto makeup, oversampling, and a gain-reduction meter.

### De-Esser

![De-Esser](screenshots/session/deesser.png)

Built on Liteon's de-esser: threshold, frequency, bandwidth, ratio and lookahead, a fast time
setting, a band-pass target instead of the broadband one, and a switch to monitor the sidechain.
The display shows the band it is listening to.

### Stereo Width

![Stereo Width](screenshots/session/stereowidth.png)

One knob, 0 to 200 %: mono at the left end, the recorded width in the middle, wider to the right.
It scales the side signal and leaves the middle alone, so the centre of the mix never moves. A
correlation meter under the knob shows how the two channels agree. In a mixer strip it is the
WIDTH knob at the bottom of the channel.

## Across the plugins

- **Embeds** — every plugin has a face for the mixer strip and the track panel, sized from the
  slot it is given. The THEME panel's EMBED row (MCP / TCP / OFF) moves a plugin between the mixer
  strip, the track panel and neither, and sets where new copies of all six open; GainKit Plus does
  the moving, and the row says NEEDS PLUS while it is not running.
- **THEME panel** — all six have a THEME toggle in the header: a colour theme, a knob style (21 of
  them), the name bar over the mixer-strip embed, EMBED, and NATIVE, each plugin in its own original
  colours. Three colour themes are built in and work on their own: **EON**, **Dark** and **Light**.
  Pick one, or NATIVE, on any of the six and all six follow, open or closed, and the choice comes
  back with the project: opening a project wears the theme it was saved with. Eleven more
  (SSL, Neve, API, Tube, Ableton, FL Studio, Pro Tools, PT Light, and three that copy your REAPER
  theme) appear in the list when EON Swing is installed, whose bridge paints them and keeps the
  whole suite in step.

  ![The session on the Dark theme](screenshots/session/session_dark.png)

  ![The session on the Light theme](screenshots/session/session_light.png)

  *The same session on Dark and on Light (EON is at the top of this page), on a machine without
  Swing.*

  ![The six windows on the EON theme](screenshots/session/six_windows_eon.png)

  ![The six windows on the Dark theme](screenshots/session/six_windows_dark.png)

  ![The six windows on the Light theme](screenshots/session/six_windows_light.png)

  *The six windows on the three built-in themes.*

  GainKit's panel also picks the VU's face, what the strip shows, the name's row (ROW, BAND or
  OFF) and its FONT, the meter's colour (FACE or TRACK), when the VU alone prints the gain (TOUCH
  or ALWAYS), one needle or two meters (METERS), whether the strip's meter sets the gain (VU DRAG)
  and whether the strip shows its STEREO / MONO key (ST/MONO), and has LOCK, which freezes that
  instance's look while the rest follows the theme. It has two pages: LOOK (the theme, the knob,
  the VU's face and colour, METERS, LOCK) and STRIP (everything about the mixer strip), and a line
  at the bottom says what the row under the mouse does.

  ![GainKit's THEME panel: the LOOK page at METERS, the STRIP page at VU DRAG](screenshots/session/gainkit_theme_panel.png)

  **With EON Swing** — its bridge paints the other eleven themes and keeps the whole suite in step:

  ![GainKit's strips on four themes](screenshots/session/strips_four_themes.png)

  *GainKit's strips on the Light, SSL, Dark and EON themes: the colours and the knob follow the
  theme, the name bands keep the track's colour.*

  ![The embedded strips on eight REAPER themes](screenshots/session/strips_eight_themes.png)

  *The same session's strips on eight REAPER themes and knob styles: GainKit, the suite's 4-Band EQ
  and Stereo Width on every track, its compressors on the buses, drawn to fit whatever the theme
  gives them.*

  ![Twenty themes](screenshots/session/twenty_themes.png)

  *Twenty of them at a glance.*

  ![The free strip in the Dark Ableton knob style](screenshots/session/free_strip_dark_ableton.png)

  *The same session with the knobs in the Dark Ableton style: the strip goes quiet and the
  values stay readable.*
- **Link groups** — the gear in the header of those five puts an instance in a group; instances
  in the same group move together. A plugin joining a group takes its settings only from members
  still running, so a group whose plugins are gone starts from the newcomer's own.
- **The mouse** — drag a knob, Ctrl for fine, Shift for finer, the wheel steps it, double-click
  resets it, right-click returns it to its default.
- **Snappier strips** — REAPER redraws an embedded strip at its meter rate, 30 a second out of the
  box. Set Preferences > Appearance > Track meter settings > Meter update frequency to 120 (the
  Start with REAPER action offers this once) and the knobs in the mixer and the track panel answer
  quicker. A strip nothing is changing on skips its redraw, so a big session stays quick.

## Install (ReaPack)

Extensions > ReaPack > Import repositories, paste:

```
https://raw.githubusercontent.com/mequaz-sudo/ReaKit-FX/main/index.xml
```

Then install **ReaKit FX** from the browser, **GainKit Plus** for the scripts, and **EON Floatter**
so every window opens at its designed size. Run the action **ReaKit FX - Start with REAPER** once
and both scripts are on from every launch. The plugins appear in REAPER's FX list as
`JS: EON: GainKit`, `JS: EON: Saturation`, `JS: EON: 3-Band EQ`, `JS: EON: DDC`,
`JS: EON: De-Esser` and `JS: EON: Stereo Width`.

**EON Floatter** ships here too (the same file as in the ReaKit library; having both is harmless,
only one ever runs). The action above starts it, or run it once yourself from the action list; it stays on: every EON window opens at
its designed size, any JSFX window can be captured at a size of your own, and one dial scales them
all. It needs js_ReaScriptAPI, and its panel needs ReaImGui, both from ReaTeam Extensions.

These effects used to ship from the ReaKit repository as "ReaKit Free FX". If you installed them
there, ReaPack now lists that package as obsolete: uninstall it and install this one.

## Licence

Saturation, 3-Band EQ and DDC keep their DSP author's terms, Michael Gruhn (LOSER); the De-Esser's
crossover and detector are Lubomir I. Ivanov's (Liteon), under the GPL as he released it. Each
plugin file carries its author's original header, word for word. GainKit and the GainKit Plus
scripts are EON Studios' own code, MIT, and so are the `ReaKit/` includes. The full text is in
[LICENSE.md](LICENSE.md).

## Building on it

The `ReaKit/` folder holds the ReaKit files the plugins import (`import ../../ReaKit/<file>`);
the ones the ReaKit library also publishes are the same as its 1.7.1 release. Nothing else is
needed: install the package and the plugins compile. To write your own, start from the
[ReaKit](https://github.com/mequaz-sudo/ReaKit) repository's showcase and Starter.

*Every picture here is a screenshot of a working session, on the SSL, Light, Dark and EON themes,
cropped and never painted over: every pixel is the plugin drawing itself.*
