# BG1 Sprite Mask Cutouts for Under-BG1 Hardware OAM Sprites

Status: accepted

In-world characters, hostile NPCs, and interactables (such as chests hidden behind tall Map Cells or Edge Panels) must be accurately occluded by 3D isometric terrain from every camera angle, while still enjoying full per-sprite SNES 4bpp palettes and zero-cost hardware animation. Because the SuperFX framebuffer occupies a single SNES `BG1` layer, placing OAM sprites *above* `BG1` breaks 3D occlusion, while software-blitting full-color billboards on the GSU constrains every entity to `BG1`'s shared 15-color terrain palette.

We decided to render in-world entities as hardware OAM sprites positioned **underneath** `BG1` (SNES Mode 1 OBJ priority 1 behind `BG1` priority 1; UI OAM sprites use priority 3 in front of `BG1`/`BG3`). During `gsu_iso_render` at `@step_4_unit_hook` (between floor terrain and front Edge Panels), the GSU fetches an exact **1-bit-per-pixel Sprite Mask** from a dedicated Mask ROM bank and punches transparent (`color 0`) pixels into the `BG1` framebuffer at the entity's projected `(sx, sy)` screen coordinates. Subsequent front Edge Panels and nearer Map Cells paint back over any occluded portion of the cutout.

## Consequences

- **Pixel-exact masks**: Sprite Masks must match the exact non-transparent silhouette of their corresponding 4bpp OAM tiles, so `sfx-studio` compiles PNG sprite sheets into both `.chr`/`.pal` and `.msk` together to prevent mask/sprite drift.
- **VBlank OAM latch**: Because `BG1` is double-buffered across two GSU render passes, the GSU writes each entity's projected `(sx, sy)` back to shared GSURAM during Pass 0, and the 65816 latches/DMAs OAM positions on the exact VBlank that flips `BG12NBA` so OAM sprites never lead or lag their `BG1` cutout by a frame.
- **Separate storage**: Sprite Masks live in a dedicated ROM bank accessible to the GSU via `ROMB`/`GETB` at any time, while 4bpp sprite tiles are loaded into VRAM by the 65816 independently.
