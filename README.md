# ReaKit FX

Five free effects for REAPER with EON Studios interfaces, drawn by the
[ReaKit](https://github.com/mequaz-sudo/ReaKit) library: Saturation, 3-Band EQ and DDC by
LOSER, a De-Esser built on Liteon's, and GainKit, EON's own gain-staging plugin. Every face is
code, no image files, so it scales to any size and renders at full resolution on HiDPI.

![ReaKit FX](screenshots/session/cover_ssl.png)

*A session on the suite's SSL theme with GainKit Plus running. Every channel and bus starts with
GainKit: the track's name on a band in the track's colour, the VU over the GAIN knob, and the
STEREO / MONO key. 4-Band EQ from the EON suite sits under it; the master runs GainKit and 3-Band
EQ, its name typed. Click a strip's empty space to open the window, click the strip again to close
it; drag the meter to set the gain.*

## The plugins

### GainKit

![GainKit](screenshots/session/gainkit.png)

![GainKit's strip faces on the Light theme](screenshots/session/gainkit_faces_light.png)

*GainKit in the mixer on the Light theme, GainKit Plus running. The five channels show the VU over
the GAIN knob, the meter in the track's colour and the name on top. Three of the buses show the VU
alone: the STEREO / MONO key under the name and, on two of them, the gain under the meter. Drums
shows the VU over the knob. Under GainKit: 4-Band EQ from the EON suite.*

Gain staging on a VU. An analog VU meter (the ReaKit meter: 300 ms to 99 %, 1.2 % overshoot, 20
faces), one GAIN knob and a STEREO / MONO key. In the mixer strip it shows the VU over the knob,
the VU alone, or the knob alone, with numerals or ticks only, and the VU grows flatter as you drag
the strip wider. The VU alone keeps its own STEREO / MONO key under the name, shows the gain as a
tint of the meter's face (up from the middle for a boost, down for a cut), and prints the value
under the meter while you set it, or all the time. Click the middle of the window's meter face and
type, and the name is printed on the meter like a legend and on top of the strip, in every view:
as a plain row, on a band in the track's colour, or not at all. The high-pass, low-pass, trims and
M/S modes it used to show are still there as parameters, so old projects sound the same.

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
  from GainKit Plus, which serves the first 512 tracks.
- **Insert on selected tracks** — GainKit first in the chain of every selected track that has
  none.
- **GainKit first in every chain** — moves the GainKit a track already has to the top of its
  chain, the master's too.
- **GainKit first on selected tracks** — the same, for the selected tracks only.
- **GainKit last on the master** — moves the master's GainKit to the end of its chain, or adds
  one there, so the mix gets a final VU after everything else.
- **Copy look to all** — the look of the selected track's GainKit (what the strip shows, the name
  row and its font, the meter's colour, VALUE, NAME BAR, NATIVE) on every GainKit at once.
- **Reset all gains** — every GainKit's GAIN back to 0 dB.
- **All MONO** / **All STEREO** — every GainKit's key at once.
- **Bypass all** — every GainKit off; run it again and they are all on.
- **Remove all GainKits** — takes GainKit off every track after asking once; Undo puts them back.
- **Start with REAPER** — GainKit Plus starts with REAPER from now on (it goes into
  `Scripts/__startup.lua`, nothing else there is touched); run it again to take it out.

The actions and the names reach a GainKit inside an FX container too.

In the mixer strip the meter itself is the gain control: drag it up or down (Ctrl fine, Shift
finer), the wheel steps it, double-click or right-click returns it to 0 dB, and the value shows
under the VU alone while you set it and a moment after. The rest of the strip still opens the
window with a click. The THEME panel's FONT row picks the face the name is printed in, on the
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

## Across the plugins

- **Embeds** — every plugin has a face for the mixer strip and the track panel, sized from the
  slot it is given.
- **THEME panel** — GainKit, Saturation, 3-Band EQ and De-Esser have a THEME toggle in the header:
  a colour theme, a knob style (21 of them), the name bar over the mixer-strip embed, and NATIVE,
  which opts an instance out of theming. GainKit's panel also picks the VU's face, what the strip
  shows, the name's row (ROW, BAND or OFF) and its FONT, the meter's colour (FACE or TRACK) and
  when the VU alone prints the gain (TOUCH or ALWAYS), and has LOCK, which freezes that instance's
  look while the rest follows the theme. DDC has no panel of its own; its colours and knobs follow
  the suite's theme.

  ![GainKit's strips on four themes](screenshots/session/strips_four_themes.png)

  *GainKit's strips on the Light, SSL, Dark and EON themes: the colours and the knob follow the
  theme, the name bands keep the track's colour.*

  ![The embedded strips on eight REAPER themes](screenshots/session/strips_eight_themes.png)

  *The same session's strips on eight REAPER themes and knob styles: GainKit, the suite's 4-Band EQ
  and Stereo Width on every track, its compressors on the buses, drawn to fit whatever the theme
  gives them.*

  ![Twenty themes](screenshots/session/twenty_themes.png)

  *Twenty of them at a glance.*
- **Link groups** — the gear in the header of those four puts an instance in a group; instances
  in the same group move together.
- **The mouse** — drag a knob, Ctrl for fine, Shift for finer, the wheel steps it, double-click
  resets it, right-click returns it to its default.

## Install (ReaPack)

Extensions > ReaPack > Import repositories, paste:

```
https://raw.githubusercontent.com/mequaz-sudo/ReaKit-FX/main/index.xml
```

Then install **ReaKit FX** from the browser, and **GainKit Plus** for the scripts. The plugins appear in REAPER's FX list as
`JS: EON: GainKit`, `JS: EON: Saturation`, `JS: EON: 3-Band EQ`, `JS: EON: DDC` and
`JS: EON: De-Esser`.

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
