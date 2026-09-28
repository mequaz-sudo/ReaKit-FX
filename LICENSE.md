# ReaKit FX — licence

Five effects. **GainKit** is EON Studios' own code, gain staging on a VU, and is
released under the MIT licence (`LICENSE` at the root of this repository).

The other four, **Saturation**, **3-Band EQ**, **DDC** and **De-Esser**: their
sound is other people's code, released free with REAPER, and each plugin file
keeps its author's original header:

- **Saturation**, **3-Band EQ** and **DDC** (Digital Drum Compressor) — DSP by
  Michael Gruhn (LOSER), (C) 2006–2007.
- **De-Esser** — the LR2 crossover and peak compressor by Lubomir I. Ivanov
  (Liteon), (C) 2009.

Their terms, quoted from those headers:

> THE USE OF THE SOURCE CODE, EITHER PARTIALLY OR IN TOTAL, IS ONLY GRANTED,
> IF USED IN THE SENSE OF THE AUTHOR'S INTENTION, AND USED WITH
> ACKNOWLEDGEMENT OF THE AUTHOR.

They gave these away, so they are free here too, and both authors stay credited
in the plugins' own interfaces. EON Studios added the interfaces.

The libraries in `ReaKit/` are EON Studios code under the MIT licence — see
`LICENSE` at the root of this repository. They are the same files as the ReaKit
library package (`buttons_kbsg`, `knobs_kbsg`, `meters_kbsg`, `sliders_kbsg`,
`rk_vu`, `rk_theme`, `rk_gmem_link`, `rk_playstate`, `oversample_kbsg`,
`smooth_kbsg`, `utils_kbsg`); the style credits for them are in
`THIRD_PARTY_CREDITS.md`.
