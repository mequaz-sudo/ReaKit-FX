# ReaKit FX — licence

Seven effects. **GainKit** (gain staging on a VU), **Stereo Width** (a mid/side width
control) and **Filter** (a high-pass and a low-pass) are EON Studios' own code, released
under the MIT licence (`LICENSE` at the root of this repository). So are the **GainKit
Plus** scripts, **EON Floatter**, the templates and the track icons.

The other four, **Saturation**, **3-Band EQ**, **DDC** and **De-Esser**: their
sound is other people's code, released free with REAPER, and each plugin file
keeps its author's original header, word for word:

- **Saturation**, **3-Band EQ** and **DDC** (Digital Drum Compressor) — DSP by
  Michael Gruhn (LOSER), (C) 2006–2007.
- **De-Esser** — the LR2 crossover and peak compressor by Lubomir I. Ivanov
  (Liteon), (C) 2009, with Linkwitz-Riley filters by T. Lossius (the ttblue
  project).

Their terms, quoted from those headers:

> THE USE OF THE SOURCE CODE, EITHER PARTIALLY OR IN TOTAL, IS ONLY GRANTED,
> IF USED IN THE SENSE OF THE AUTHOR'S INTENTION, AND USED WITH
> ACKNOWLEDGEMENT OF THE AUTHOR.

Liteon's header adds: *"Released under GPL: <http://www.gnu.org/licenses/>."* The
De-Esser is therefore under the GNU General Public License here too, as he
released it: its source is the plugin file itself, and you may share and change
it under the GPL's terms. The GPL's full text is beside the plugin,
`Eon_JSFX/FX/DeEsser_ReaKit.GPL-3.0.md`. His header names no version, and the GPL
then lets anyone choose any version ever published; the copy here is version 3.

They gave these away, so they are free here too, and both authors stay credited
in the plugins' own interfaces. EON Studios added the interfaces.

The libraries in `ReaKit/` are EON Studios code under the MIT licence — see
`LICENSE` at the root of this repository. Five of them are also published in the
ReaKit library package (`buttons_kbsg`, `knobs_kbsg`, `meters_kbsg`,
`sliders_kbsg`, `rk_vu`); the other eight ship only here (`rk_theme`,
`rk_gmem_link`, `rk_playstate`, `rk_curve`, `rk_drawer`, `oversample_kbsg`,
`smooth_kbsg`, `utils_kbsg`).
The style credits for them are in `THIRD_PARTY_CREDITS.md`.
