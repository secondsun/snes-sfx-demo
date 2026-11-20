# `snes_ui` — Reusable 65816 SNES UI & Under-`BG1` Hardware OAM Library

Reusable `ca65` / `libSFX` 65816 presentation modules for `IsoRPGDemo` (Epic #30, Issues #36 & #37) and future SuperFX hybrid demos. Designed for **ADR 0005** (under-`BG1` hardware OAM revealed through GSU 1-bit Sprite Mask cutouts) and **ADR 0006** (65816 gameplay/UI owner + GSU pure `192×160` renderer).

## Modules

| File | Responsibility |
|---|---|
| `ui_font_tiles.i` | 96 × 2bpp 8×8 tiles (`$00` transparent, `$01` solid fill, `$02..$09` 9-slice RPG window borders, `$0A..$0F` cursor/heart/sword/shield/boots/star icons, `$10..$14` dividers/bars, `$20..$5F` direct-mapped ASCII) + 4 distinct 2bpp palettes (`UI_PAL_ACTIVE`, `UI_PAL_UNFOCUS`, `UI_PAL_DISABLED`, `UI_PAL_ALERT`) + `UI_LOAD_FONT_AND_PALETTES`. |
| `bg3_ui.i` | 2 KB WRAM shadow tilemap (`bg3_tilemap_buf` in `HIRAM`) + `bg3_dirty` flag + inline DMA `bg3_vblank_flush`, plus `bg3_ui_init`, `ui_put_tile`, `ui_clear_rect`, `ui_fill_rect`, `ui_draw_box`, `ui_print_str`, `ui_print_u8`, `ui_print_u8_2d`. |
| `side_menu.i` | Vertical RPG menu widget for the 64 px right panel (`cols 24..31`, `rows 0..19`): up to 6 items, `enabled` bitmask, `focused` border/cursor styling, D-pad Up/Down + `A`/`B` handling (`side_menu_update`), and `side_menu_get_cursor_xy` for Priority 3 OAM cursor tracking. |
| `status_bar.i` | Bottom 64 px bar (`cols 0..31`, `rows 20..27`): Mode/Turn header, Player `HP xx/xx` (auto-alert at low HP), `MP x/x`, and a 2-line scrolling message log (`ui_set_message`, `ui_set_messages`). |
| `oam_manager.i` | 544-byte WRAM shadow OAM (`oam_shadow_buf`) + pending entity latch (`oam_pending_entities`) synced to the exact `BG12NBA` flip VBlank (`oam_latch_entities`), `16×24` under-`BG1` Priority 1 metasprites clipped to `[0..191]×[0..159]`, 60fps Priority 3 UI sprites, and floating damage popups (`-6`, `MISS`). |

> **GSU Bus Safety**: Define `SNES_UI_WRAM_CODE = 1` before `.include` to place all runtime subroutines in `.segment "MAIN_LOOP"` (WRAM) so they execute safely while the SuperFX GSU owns the ROM/RAM buses (`GSU_SCMR.RON=1`). All shadow buffers live in `.segment "HIRAM"` (`$7E:2000..$7E:FFFF`) and are accessed via 24-bit `f:` addressing.

---

## VRAM Allocation Contract (64 KB SNES VRAM)

Fits cleanly outside double-buffered `192×160` 4bpp `BG1` (`$3C00` bytes/buffer = 15,360 B) **and** remains compatible with legacy `256×160` `RamMapDemo`-style `$0000/$6000` layouts:

| Byte Address | Word Address | Size | Region | PPU Register |
|---|---|---|---|---|
| `$0000..$3BFF` | `$0000..$1DFF` | 15,360 B | `BG1` Double-Buffer 0 (`192×160` 4bpp; blank tile `$3C00`) | `BG12NBA = bg12nba($0000, 0)` |
| `$4000..$7BFF` | `$2000..$3DFF` | 15,360 B | `BG1` Double-Buffer 1 (`192×160` 4bpp; blank tile `$7C00`) | `BG12NBA = bg12nba($4000, 0)` |
| `$8000..$BFFF` | `$4000..$5FFF` | 16,384 B | Free / Optional extended OBJ or BG2 tiles | — |
| `$C000..$DFFF` | `$6000..$6FFF` | 8,192 B | **OBJ Name Table 0** (`VRAM_UI_OBJ_TILES`, 256 4bpp 8×8 tiles) | `OBSEL = objsel($C000, OBJ_8X8_16X16, 0)` |
| `$E000..$E7FF` | `$7000..$73FF` | 2,048 B | **`BG3` Font & 9-Slice Window Tiles** (`VRAM_BG3_TILES`, 96 tiles = 1,536 B used) | `BG34NBA = bg34nba($E000, 0)` |
| `$E800..$EFFF` | `$7400..$77FF` | 2,048 B | `BG1` 32×32 Tilemap | `BG1SC = bgsc($E800, SC_SIZE_32X32)` |
| `$F000..$F7FF` | `$7800..$7BFF` | 2,048 B | **`BG3` 32×32 Shadow-Flushed Tilemap** (`VRAM_BG3_MAP`) | `BG3SC = bgsc($F000, SC_SIZE_32X32)` |
| `$F800..$FFFF` | `$7C00..$7FFF` | 2,048 B | Free / Reserved | — |

---

## CGRAM Allocation Contract (SNES Mode 1)

| CGRAM Indices | Layer / Palette | Usage |
|---|---|---|
| `0..15` | `BG1` Pal 0 (4bpp) | SuperFX 3D terrain texture atlas (15 colors + transparent 0) |
| `16..19` | **`BG3` Pal 4** (`UI_PAL_ACTIVE`) | Focused RPG window border & bright white text |
| `20..23` | **`BG3` Pal 5** (`UI_PAL_UNFOCUS`) | Unfocused / dimmed window border & muted text |
| `24..27` | **`BG3` Pal 6** (`UI_PAL_DISABLED`) | Disabled / greyed-out menu item text |
| `28..31` | **`BG3` Pal 7** (`UI_PAL_ALERT`) | Highlighted / selected / alert / low-HP text |
| `128..143` | **OBJ Pal 0** (`OAM_PAL_PLAYER`) | Player character sprite |
| `144..159` | **OBJ Pal 1** (`OAM_PAL_ENEMY_A`) | Hostile NPC archetype A |
| `160..175` | **OBJ Pal 2** (`OAM_PAL_ENEMY_B`) | Hostile NPC archetype B / Boss |
| `176..191` | **OBJ Pal 3** (`OAM_PAL_PROP`) | Interactables (chests, levers, shrines) |
| `192..207` | **OBJ Pal 4** (`OAM_PAL_FX`) | Spell / hit VFX |
| `208..223` | **OBJ Pal 5** (`OAM_PAL_RESERVED`) | Extra entity palette |
| `224..239` | **OBJ Pal 6** (`OAM_PAL_UI_CUR`) | Side Menu Priority 3 cursor & turn badges |
| `240..255` | **OBJ Pal 7** (`OAM_PAL_UI_DMG`) | Floating damage numbers (`-6`, `MISS`) |

---

## OAM Slot & Priority Contract

- **Slots `0..31`** (`OAM_PRIO_1_UNDER_BG1 = $10`, large `16×16`): Up to 16 `16×24` in-world entities (upper `16×16` at `(sx, sy)` with `base_tile`, lower `16×8/16×16` at `(sx, sy+16)` with `base_tile + $20`). Clipped to `X ∈ [-15..191], Y ∈ [-23..159]` (lower half clipped if `sy+16 >= 160` so feet never enter the bottom bar). **Only committed when `oam_latch_entities` runs on the `BG12NBA` flip VBlank.**
- **Slots `32..127`** (`OAM_PRIO_3_OVER_UI = $30`, `8×8` or `16×16`): 60fps UI sprites (Side Menu cursor, turn badges, floating damage popups). Rebuilt every frame via `oam_begin_frame` → `oam_push_ui_sprite` / `oam_update_damage_popups`.

---

## NTSC VBlank DMA Budget

NTSC VBlank provides ~38 scanlines (~6.2 KB safe DMA budget with ~165 bytes/scanline):
- `BG1` Pass 1 (`64×160` 4bpp): **5,120 B** (~31 scanlines) — or split across Pass 0 (`10,240 B` -> `5,120 B` chunks if needed)
- `oam_vblank_flush`: **544 B** (~3.3 scanlines, every frame)
- `bg3_vblank_flush`: **2,048 B** (~12.4 scanlines, **only when `bg3_dirty != 0`**; skipped on steady-state frames and easily deferred to non-`BG1`-DMA frames if `BG1` uses the full VBlank!)

---

## Minimal Integration Pattern

```asm
SNES_UI_WRAM_CODE = 1
.include "libSFX.i"
.include "../snes_ui/ui_font_tiles.i"
.include "../snes_ui/bg3_ui.i"
.include "../snes_ui/side_menu.i"
.include "../snes_ui/status_bar.i"
.include "../snes_ui/oam_manager.i"

; --- Boot (forced blank, before gsuOn) ---
        UI_LOAD_FONT_AND_PALETTES
        jsr     bg3_ui_init
        jsr     side_menu_init
        jsr     status_bar_init
        jsr     oam_mgr_init

        lda     #bgmode(BG_MODE_1, BG3_PRIO_HIGH, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #bgsc(VRAM_BG3_MAP, SC_SIZE_32X32)
        sta     BG3SC
        lda     #bg34nba(VRAM_BG3_TILES, 0)
        sta     BG34NBA
        lda     #objsel(VRAM_UI_OBJ_TILES, OBJ_8X8_16X16, 0)
        sta     OBSEL
        lda     #tm(ON, OFF, ON, OFF, ON)  ; BG1 + BG3 + OBJ
        sta     TM

; --- VBlank ---
        ; On Pass 1 completion (exact BG12NBA flip):
        sta     BG12NBA
        jsr     oam_latch_entities         ; ADR 0005: zero-desync entity commit
        ; Every VBlank (60fps):
        jsr     oam_vblank_flush           ; 544 B inline DMA
        jsr     bg3_vblank_flush           ; 2 KB inline DMA (only if bg3_dirty != 0)
```
