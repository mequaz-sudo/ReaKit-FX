# ReaKit FX — licence

Eight effects. **GainKit** (gain staging on a VU), **Stereo Width** (a mid/side width
control), **Filter** (a high-pass and a low-pass) and **Quezy** (a parametric EQ) are EON
Studios' own code, under the **EON Free Licence 1.0** (`LICENSE-EON-FREE.md`): use them
free in any work; don't sell, redistribute or reuse their code. So are the **GainKit
Plus** and ReaKit FX scripts, **EON Floatter**, the templates and the track icons.
Versions released before 2026-11-04 keep the MIT licence they came with.

Quezy's band engine and gestures follow Justin Johnson's ReEQ (MIT), and its matched
filters follow Yuriy Ivantsov's maps (MIT); those parts keep their authors' MIT notices,
printed in `Quezy_ReaKit.jsfx`, `rk_svf.jsfx-inc` and `rk_svf_match.jsfx-inc`.

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
`LICENSE` at the root of this repository — except Quezy's own `qz_*` files, `qz_face`,
`qz_engine` and the generated `qz_rec_*` band records (EON Free Licence 1.0). `rk_svf` and
`rk_spectrum` are ports of Justin
Johnson's MIT includes and keep his notice. Five of them are also published in the
ReaKit library package (`buttons_kbsg`, `knobs_kbsg`, `meters_kbsg`,
`sliders_kbsg`, `rk_vu`); the others ship only here (`rk_theme`,
`rk_gmem_link`, `rk_playstate`, `rk_curve`, `rk_drawer`, `rk_handoff`, `rk_srf`,
`rk_menu`, `rk_knob_ring`, `rk_svf`, `rk_svf_match`, `rk_spectrum`,
`oversample_kbsg`, `smooth_kbsg`, `utils_kbsg`; `knobs_kbsg` comes in four parts).
The style credits for them are in `THIRD_PARTY_CREDITS.md`.
