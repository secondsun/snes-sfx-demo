; ==============================================================================
; SuperFX.s - IsoRPGDemo 65816 Host (Epic #30 / Issue #38)
;
; Architecture (ADR 0005 & ADR 0006):
;   - 65816 owns gameplay state (`game_state.i`), input & camera focus routing
;     (`input_router.i`), BG3 UI (`snes_ui`), and under-BG1 hardware OAM.
;   - SuperFX GSU operates strictly as a pure 192x160 4bpp isometric renderer
;     consuming `GSU_SCENE_DESC` in Bank $70 and staged assets in Bank $71.
;   - VBlank Pipeline:
;       Pass 0 done: DMA $2800 B -> backbuffer + $0000, launch Pass 1.
;       Pass 1 done: DMA $1400 B -> backbuffer + $2800, flip BG12NBA,
;                    call `oam_latch_entities`, publish `GSU_SCENE_DESC`,
;                    launch Pass 0.
;       Every VBlank (60fps): `oam_vblank_flush` (544 B) + `bg3_vblank_flush`
;                    (2 KB only when `bg3_dirty != 0`).
; ==============================================================================

SNES_UI_WRAM_CODE = 1
.ifndef USE_DEMO_LEVEL_DATA
USE_DEMO_LEVEL_DATA = 1
.endif

.include "libSFX.i"
.include "pointers.s"
.include "CpuMacros.s"
.include "../gsu_iso/cpu_asset_loader.i"
.include "../gsu_iso/asset_source_rom.i"
.include "../gsu_iso/scene_descriptor.i"
.include "../snes_ui/ui_font_tiles.i"
.include "../snes_ui/bg3_ui.i"
.include "../snes_ui/side_menu.i"
.include "../snes_ui/status_bar.i"
.include "../snes_ui/oam_manager.i"
.ifdef USE_DEMO_LEVEL_DATA
.include "Data/sprites/demo_sprites.i"
.endif
.include "game_state.i"
.include "input_router.i"
.include "level_loader.i"
.include "battle_bfs.i"
.include "entity_sync.i"
.include "explore_move.i"
.include "interactables.i"
.include "npc_explore_ai.i"
.include "battle_core.i"
.include "npc_battle_ai.i"

.import GSU_Code
.import GSU_SCENE_DESC

; ------------------------------------------------------------------------------
; Zero-Page Pipeline & Sync State
; ------------------------------------------------------------------------------
.segment "ZEROPAGE"
VRAM_screen_select:     .res 1  ; 0 = write VRAM_screen_1, 1 = write VRAM_screen_2
SFX_buffer_position:    .res 1  ; 0=P0A, 1=P0B, 2=P0C, 3=P1A, 4=P1B
vblank_frame_tick:      .res 1  ; Incremented every VBlank for 60fps main-loop sync
last_frame_tick:        .res 1  ; Last processed vblank_frame_tick in MAIN_LOOP
pending_gsu_kick:       .res 1  ; 1 = main_loop must publish GSURAM descriptor & kick GSU Pass 0

.export VRAM_screen_select, SFX_buffer_position, vblank_frame_tick

; ==============================================================================
; ROM0 Boot & Bank-$71 Level / Sprite Asset Staging (`CODE`)
; ==============================================================================
.segment "CODE"

; ------------------------------------------------------------------------------
; load_rpg_level
; Stages Level0Def (atlas/tab/pal/map) into Bank $71 + CGRAM 0..15, uploads
; placeholder 4bpp OAM CHR/PAL from ROM_SPRITES into VRAM $C000 & CGRAM 128..255,
; and initializes `GSU_SCENE_DESC` in Bank $70.
; Must be called with GSU stopped and GSU_SCMR == 0.
; ------------------------------------------------------------------------------
load_rpg_level:
        php
        RW_forced a8i16

        ; Stage isometric level (atlas .bin, .tab, .pal -> CGRAM 0..15, .map -> $71:8808)
        SFX_LOAD_LEVEL Level0Def

        ; Acquire bus briefly to upload OAM sprites & clear GSU_SCENE_DESC
        jsr     _sfx_acquire_gsu_bus

        ; Upload 4bpp OAM CHR -> VRAM $C000 & OBJ Palettes -> CGRAM 128..255
.ifdef USE_DEMO_LEVEL_DATA
        ; Zero full 8 KB OBJ tile region so lower-half 16x16 rows 24..31 are transparent
        VRAM_memset  VRAM_UI_OBJ_TILES, $2000, $00
        ; Unpack 7 row-major 16x24 frames (6 tiles/frame) into 16-tile-wide SNES OBJ VRAM:
        ;   Frame f -> base tile T = f*2:
        ;     Row 0 (y= 0.. 7): T+$00, T+$01  (VRAM + $0000 + f*64)
        ;     Row 1 (y= 8..15): T+$10, T+$11  (VRAM + $0200 + f*64)
        ;     Row 2 (y=16..23): T+$20, T+$21  (VRAM + $0400 + f*64)
        ;     Row 3 (y=24..31): T+$30, T+$31  (already zeroed = transparent)
        .repeat DEMO_SPRITES_FRAME_COUNT, f
            VRAM_memcpy (VRAM_UI_OBJ_TILES + $0000 + (f * 64)), (DemoSpriteChr + (f * 192) +   0), 64
            VRAM_memcpy (VRAM_UI_OBJ_TILES + $0200 + (f * 64)), (DemoSpriteChr + (f * 192) +  64), 64
            VRAM_memcpy (VRAM_UI_OBJ_TILES + $0400 + (f * 64)), (DemoSpriteChr + (f * 192) + 128), 64
        .endrepeat
        ; Upload 4bpp floating damage popup digits ($E0..$ED: '0'-'9', '-', 'M', 'I', 'S')
        VRAM_memcpy  (VRAM_UI_OBJ_TILES + (OAM_TILE_DIGIT_0 * 32)), RpgDmgDigitTiles, (RpgDmgDigitTilesEnd - RpgDmgDigitTiles)
        ; Shared 16-color sprite palette -> OBJ Pal 0..3 (CGRAM 128..191)
        CGRAM_memcpy 128, DemoSpritePal, DEMO_SPRITES_PAL_BYTE_SIZE
        CGRAM_memcpy 144, DemoSpritePal, DEMO_SPRITES_PAL_BYTE_SIZE
        CGRAM_memcpy 160, DemoSpritePal, DEMO_SPRITES_PAL_BYTE_SIZE
        CGRAM_memcpy 176, DemoSpritePal, DEMO_SPRITES_PAL_BYTE_SIZE
        ; High-contrast UI/Damage palette -> OBJ Pal 6..7 (CGRAM 224..255)
        CGRAM_memcpy 224, RpgUiObjPalette, 32
        CGRAM_memcpy 240, RpgUiObjPalette, 32
.else
        VRAM_memcpy  VRAM_UI_OBJ_TILES, RpgObjTiles, (RpgObjTilesEnd - RpgObjTiles)
        CGRAM_memcpy 128, RpgObjPalettes, (RpgObjPalettesEnd - RpgObjPalettes)
.endif

        ; Zero-initialize GSU_SCENE_DESC (464 bytes) and $70:8000 half-screen buffer
        RW a16
        lda     #$0000
        ldx     #$0000
@clr_desc:
        sta     f:GSU_SCENE_DESC, x
        inx
        inx
        cpx     #GSU_SCENE_DESC_BYTES
        bcc     @clr_desc

        ldx     #$0000
@clr_fb:
        sta     f:screenbuffer, x
        inx
        inx
        cpx     #screenbuffer_pass0
        bcc     @clr_fb

        ; Parse .gmap gameplay layer & .map base heights into WRAM while GSU is stopped
        RW a8
        ldx     #.loword(Level0GmapBin)
        stx     z:lvl_gmap_ptr
        lda     #^Level0GmapBin
        sta     z:lvl_gmap_ptr + 2
        ldx     #.loword(Level0MapBin)
        stx     z:lvl_map_ptr
        lda     #^Level0MapBin
        sta     z:lvl_map_ptr + 2
        jsr     level_loader_load

        ; Release bus (restores GSU_SCMR, SFX_inidisp, clears sfx_gsu_load_lock)
        jsr     _sfx_release_gsu_bus
        plp
        rts

; Long-call trampoline so WRAM `MAIN_LOOP` can invoke `load_rpg_level` in ROM0.
load_rpg_level_far:
        jsr     load_rpg_level
        rtl

; ------------------------------------------------------------------------------
; Main - Cold Boot Entry Point
; ------------------------------------------------------------------------------
Main:
        ; Copy WRAM-resident main loop, UI modules, strings & VBlank to HIRAM ($7E)
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__

        ; Restore DBR = $80 after MVN (which leaves DBR = $7E) so MMIO & LORAM work!
        RW_forced a8i16
        lda     #$80
        pha
        plb

        ; Clear VRAM $0000..$8000 (both 192x160 BG1 buffers + blank tiles $3C00/$7C00)
        VRAM_memset $0000, $8000, $00

        ; Upload 192x160 Priority-1 BG1 tilemap to VRAM $E800
        VRAM_memcpy VRAM_tilemap, Map, (Map_end - Map)

        ; Clear CGRAM[0] backdrop to black and upload BG3 2bpp font/border tiles & palettes
        CGRAM_setcolor_rgb 0, 0, 0, 0
        UI_LOAD_FONT_AND_PALETTES

        ; Initialize Bank-$71 loader (WRAM UI/game subsystems initialize in Main2)
        SFX_LOADER_INIT SFX_DEFAULT_GSU_SCMR

        ; Configure GSU hardware registers (PBR=$03, ROMBR=$04, SCBR=$20)
        ; Do not start GSU (`gsuOn`) until player leaves Title Screen.
        initGSU_4bpp_160
        stz     GSU_SCMR

        jml     Main2

; ==============================================================================
; WRAM-Resident Main Loop (`MAIN_LOOP` -> HIRAM $7E)
; ==============================================================================
.segment "MAIN_LOOP"
Main2:
        RW_forced a8i16
        lda     #$80
        pha
        plb

        ; Initialize WRAM UI subsystems, camera router & state machine (draws Title)
        jsr     bg3_ui_init
        jsr     side_menu_init
        jsr     status_bar_init
        jsr     oam_mgr_init
        jsr     input_router_init
        jsr     game_state_init

        ; Mode 1 with BG3_PRIO_HIGH so BG3 UI overlays BG1 & under-BG1 OAM
        lda     #bgmode(BG_MODE_1, BG3_PRIO_HIGH, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE

        ; BG1: 192x160 top-left (BG1HOFS = 0, BG1VOFS = 0)
        lda     #bgsc(VRAM_tilemap, SC_SIZE_32X32)
        sta     BG1SC
        lda     #bg12nba(VRAM_screen_1, 0)
        sta     BG12NBA
        stz     BG1HOFS
        stz     BG1HOFS
        stz     BG1VOFS
        stz     BG1VOFS

        ; BG3: Font at $E000, Shadow-Flushed Tilemap at $F000
        lda     #bgsc(VRAM_BG3_MAP, SC_SIZE_32X32)
        sta     BG3SC
        lda     #bg34nba(VRAM_BG3_TILES, 0)
        sta     BG34NBA
        stz     BG3HOFS
        stz     BG3HOFS
        stz     BG3VOFS
        stz     BG3VOFS

        ; OBJ: 4bpp tiles at $C000, 8x8 / 16x16 sizes
        lda     #objsel(VRAM_UI_OBJ_TILES, OBJ_8x8_16x16, 0)
        sta     OBJSEL

        ; Enable BG1 + BG3 + OBJ on main screen
        lda     #tm(ON, OFF, ON, OFF, ON)
        sta     TM

        stz     z:VRAM_screen_select
        stz     z:SFX_buffer_position
        stz     z:vblank_frame_tick
        stz     z:last_frame_tick
        stz     z:pending_gsu_kick

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     z:SFX_inidisp

        VBL_set Vblank
        VBL_on

; ------------------------------------------------------------------------------
; 60fps Game Loop (synchronized to VBlank via `vblank_frame_tick`)
; ------------------------------------------------------------------------------
main_loop:
        RW_forced a8i16

        ; Wait for next VBlank tick
@wait_tick:
        lda     z:vblank_frame_tick
        cmp     z:last_frame_tick
        beq     @wait_tick
        sta     z:last_frame_tick

        ; Check if Title / Game Over requested Bank-$71 level staging
        lda     a:pending_level_load
        beq     @run_logic

        ; Wait for any in-flight GSU pass, release GSU bus, stage level from ROM0
@wait_gsu_load:
        gsuRunning
        bne     @wait_gsu_load
        lda     #$01
        sta     a:sfx_gsu_load_lock
        stz     GSU_SCMR

        jsl     load_rpg_level_far

        ; Sync Explore HUD stats, frame camera on player & publish initial scene descriptor
        jsr     game_state_refresh_explore_stats
        jsr     explore_snap_camera_to_player
        jsr     input_router_publish_descriptor
        jsr     entity_sync_publish_descriptor

        ; Reset 192x160 double-buffer pipeline to Pass 0 and launch GSU
        stz     z:SFX_buffer_position
        stz     z:VRAM_screen_select
        stz     z:pending_gsu_kick
        stz     a:pending_level_load
        lda     #$01
        sta     a:gsu_render_enabled
        gsuOn
        bra     main_loop

@run_logic:
        ; 60fps UI OAM rebuild (Tier 2 slots 32..127; preserves Tier 1 slots 0..31)
        jsr     oam_begin_frame
        jsr     oam_update_damage_popups

        ; Route global L/R camera snaps & SELECT focus toggle, then tick state machine
        jsr     input_router_tick
        jsr     game_state_tick

        ; If VBlank Pass 1B completed, publish updated Scene Render Descriptor in active
        ; display (zero VBlank overhead!) and kick next GSU Pass 0 frame
        lda     z:pending_gsu_kick
        beq     @no_kick
        lda     a:pending_level_load
        bne     @no_kick
        jsr     input_router_publish_descriptor
        jsr     entity_sync_publish_descriptor
        lda     #$00
        sta     f:GSU_FRAME_HALF
        stz     z:pending_gsu_kick
        gsuOn
@no_kick:
        bra     main_loop

; Long-call trampolines in `MAIN_LOOP` ($7E) for `VBLANK` ($00) NMI handler
entity_sync_latch_oam_far:
        jsr     entity_sync_latch_oam
        rtl
input_router_publish_descriptor_far:
        jsr     input_router_publish_descriptor
        rtl
entity_sync_publish_descriptor_far:
        jsr     entity_sync_publish_descriptor
        rtl
oam_vblank_flush_far:
        jsr     oam_vblank_flush
        rtl
bg3_vblank_flush_far:
        jsr     bg3_vblank_flush
        rtl

; ==============================================================================
; WRAM-Resident VBlank Handler (`VBLANK` -> LORAM)
; ==============================================================================
.segment "VBLANK"
Vblank:
        RW_forced a8i16
        lda     #$80
        pha
        plb

        ; Never touch GSU, VRAM, or OAM while main thread is staging Bank $71
        lda     a:sfx_gsu_load_lock
        beq     :+
        endVBlank
:
        ; Skip GSU BG1 pipeline on Title Screen / Game Over or while main_loop is publishing descriptor
        lda     a:gsu_render_enabled
        bne     :+
        brl     @vbl_flush_ui
:       lda     z:pending_gsu_kick
        beq     :+
        brl     @vbl_flush_ui
:
        ; Check if current GSU half-frame pass completed
        gsuRunning
        beq     :+
        brl     @vbl_flush_ui
:
        lda     z:VRAM_screen_select
        bne     @draw_screen2
        brl     @draw_screen1

; --- Backbuffer = VRAM_screen_2 ($4000) ---
; Pass 0 ($2800 B) split into 3 chunks ($0E00 + $0E00 + $0C00) and Pass 1 ($1400 B)
; split into 2 chunks ($0A00 + $0A00) so every VBlank stays strictly inside NTSC VBlank.
@draw_screen2:
        lda     z:SFX_buffer_position
        bne     :+
        brl     @screen2_pass0a
:       cmp     #$01
        bne     :+
        brl     @screen2_pass0b
:       cmp     #$02
        bne     :+
        brl     @screen2_pass0c
:       cmp     #$03
        bne     :+
        brl     @screen2_pass1a
:
        ; Pass 1B ($0600 B -> $4000 + $3600) + BG12NBA flip + OAM latch; defer descriptor publish to main_loop
        VRAM_memcpy (VRAM_screen_2 + screenbuffer_pass0 + $0E00), (screenbuffer + $0E00), $0600
        stz     z:SFX_buffer_position
        stz     z:VRAM_screen_select
        lda     #bg12nba(VRAM_screen_2, 0)
        sta     BG12NBA
        jsl     entity_sync_latch_oam_far   ; ADR 0005: exact BG12NBA-synced entity commit
        lda     #$01
        sta     z:pending_gsu_kick          ; main_loop publishes GSURAM descriptor & kicks GSU Pass 0
        brl     @vbl_flush_oam_only

@screen2_pass1a:
        ; Pass 1A ($0E00 B -> $4000 + $2800)
        VRAM_memcpy (VRAM_screen_2 + screenbuffer_pass0), screenbuffer, $0E00
        lda     #$04
        sta     z:SFX_buffer_position
        brl     @vbl_flush_oam_only

@screen2_pass0a:
        ; Pass 0A ($0E00 B -> $4000 + $0000)
        VRAM_memcpy VRAM_screen_2, screenbuffer, $0E00
        lda     #$01
        sta     z:SFX_buffer_position
        brl     @vbl_flush_oam_only

@screen2_pass0b:
        ; Pass 0B ($0E00 B -> $4000 + $0E00)
        VRAM_memcpy (VRAM_screen_2 + $0E00), (screenbuffer + $0E00), $0E00
        lda     #$02
        sta     z:SFX_buffer_position
        brl     @vbl_flush_oam_only

@screen2_pass0c:
        ; Pass 0C ($0C00 B -> $4000 + $1C00), then launch GSU Pass 1
        VRAM_memcpy (VRAM_screen_2 + $1C00), (screenbuffer + $1C00), $0C00
        lda     #$03
        sta     z:SFX_buffer_position
        lda     #$01
        sta     f:GSU_FRAME_HALF
        gsuOn
        brl     @vbl_flush_oam_only

; --- Backbuffer = VRAM_screen_1 ($0000) ---
@draw_screen1:
        lda     z:SFX_buffer_position
        bne     :+
        brl     @screen1_pass0a
:       cmp     #$01
        bne     :+
        brl     @screen1_pass0b
:       cmp     #$02
        bne     :+
        brl     @screen1_pass0c
:       cmp     #$03
        bne     :+
        brl     @screen1_pass1a
:
        ; Pass 1B ($0600 B -> $0000 + $3600) + BG12NBA flip + OAM latch; defer descriptor publish to main_loop
        VRAM_memcpy (VRAM_screen_1 + screenbuffer_pass0 + $0E00), (screenbuffer + $0E00), $0600
        stz     z:SFX_buffer_position
        lda     #$01
        sta     z:VRAM_screen_select
        lda     #bg12nba(VRAM_screen_1, 0)
        sta     BG12NBA
        jsl     entity_sync_latch_oam_far   ; ADR 0005: exact BG12NBA-synced entity commit
        lda     #$01
        sta     z:pending_gsu_kick          ; main_loop publishes GSURAM descriptor & kicks GSU Pass 0
        brl     @vbl_flush_oam_only

@screen1_pass1a:
        ; Pass 1A ($0E00 B -> $0000 + $2800)
        VRAM_memcpy (VRAM_screen_1 + screenbuffer_pass0), screenbuffer, $0E00
        lda     #$04
        sta     z:SFX_buffer_position
        brl     @vbl_flush_oam_only

@screen1_pass0a:
        ; Pass 0A ($0E00 B -> $0000 + $0000)
        VRAM_memcpy VRAM_screen_1, screenbuffer, $0E00
        lda     #$01
        sta     z:SFX_buffer_position
        brl     @vbl_flush_oam_only

@screen1_pass0b:
        ; Pass 0B ($0E00 B -> $0000 + $0E00)
        VRAM_memcpy (VRAM_screen_1 + $0E00), (screenbuffer + $0E00), $0E00
        lda     #$02
        sta     z:SFX_buffer_position
        brl     @vbl_flush_oam_only

@screen1_pass0c:
        ; Pass 0C ($0C00 B -> $0000 + $1C00), then launch GSU Pass 1
        VRAM_memcpy (VRAM_screen_1 + $1C00), (screenbuffer + $1C00), $0C00
        lda     #$03
        sta     z:SFX_buffer_position
        lda     #$01
        sta     f:GSU_FRAME_HALF
        gsuOn

; --- BG1-DMA VBlank: OAM only (max 3,584 B BG1 + 544 B OAM = 4,128 B << 5.4 KB NTSC budget) ---
@vbl_flush_oam_only:
        jsl     oam_vblank_flush_far    ; 544 B -> OAM
        inc     z:vblank_frame_tick
        endVBlank

; --- Non-BG1-DMA VBlank: OAM + Dirty-Flag BG3 (544 B + 2,048 B = 2,592 B) ---
@vbl_flush_ui:
        jsl     oam_vblank_flush_far    ; 544 B -> OAM
        jsl     bg3_vblank_flush_far    ; 2 KB -> BG3 map (only if bg3_dirty != 0)
        inc     z:vblank_frame_tick
        endVBlank

; ==============================================================================
; RODATA: 192x160 BG1 Tilemap & Level Descriptor Table (Bank $80)
; ==============================================================================
.segment "RODATA"
.include "backgroundMap.s"

; Level 0 (Placeholder Test Map until #41 lands: Fort Zeakden 9x13)
Level0Def:
        .word   $0000
        def_rom_asset Level0AtlasBin, (Level0AtlasBinEnd - Level0AtlasBin)
        def_rom_asset Level0AtlasTab, (Level0AtlasTabEnd - Level0AtlasTab)
        def_rom_asset Level0AtlasPal, 32
        def_rom_asset Level0MapBin,   (Level0MapBinEnd - Level0MapBin)

; ==============================================================================
; Bank $05 (`ROM_MASKS`): Dedicated 1-bit Sprite Masks (GSU ROMB = $05)
; ==============================================================================
.segment "ROM_MASKS"
.ifndef USE_DEMO_LEVEL_DATA
PlaceholderMask16x24:
        .byte $0F,$F0, $1F,$F8, $3F,$FC, $3F,$FC, $3F,$FC, $3F,$FC, $1F,$F8, $0F,$F0
        .byte $1F,$F8, $3F,$FC, $7F,$FE, $7F,$FE, $7F,$FE, $7F,$FE, $7F,$FE, $7F,$FE
        .byte $3F,$FC, $3F,$FC, $3F,$FC, $3F,$FC, $3F,$FC, $3F,$FC, $3C,$3C, $3C,$3C
PlaceholderMask16x24End:
.else
DemoSpriteMasks:    .incbin "Data/sprites/demo_sprites.msk"
DemoSpriteMasksEnd:
.endif

; ==============================================================================
; Bank $86 (`ROM_SPRITES`): Dedicated 4bpp OAM CHR & Palettes
; ==============================================================================
.segment "ROM_SPRITES"
.ifndef USE_DEMO_LEVEL_DATA
RpgObjTiles:
        .res 32, $00
RpgObjTilesEnd:
RpgObjPalettes:
        .res 256, $00
RpgObjPalettesEnd:
.else
DemoSpriteChr:      .incbin "Data/sprites/demo_sprites.chr"
DemoSpriteChrEnd:
DemoSpritePal:      .incbin "Data/sprites/demo_sprites.pal"
DemoSpritePalEnd:

; High-contrast UI / Damage Popup OBJ palette (0=transp, 1=outline/shadow, 2=gold, 3=white)
RpgUiObjPalette:
        .word $0000, $0842, $1BBF, $7FFF, $151E, $7F46, $02BF, $7FFF
        .word $0000, $0000, $0000, $0000, $0000, $0000, $0000, $0000

; Helper macro: emits one 4bpp 8x8 glyph (color 3 = fg, color 1 = 1px right/down drop shadow)
.macro _dmg_glyph r0, r1, r2, r3, r4, r5, r6, r7
        .byte (r0 | (r0 >> 1)), r0
        .byte (r1 | (r1 >> 1) | r0), r1
        .byte (r2 | (r2 >> 1) | r1), r2
        .byte (r3 | (r3 >> 1) | r2), r3
        .byte (r4 | (r4 >> 1) | r3), r4
        .byte (r5 | (r5 >> 1) | r4), r5
        .byte (r6 | (r6 >> 1) | r5), r6
        .byte (r7 | (r7 >> 1) | r6), r7
        .res 16, $00
.endmac

; 14 4bpp tiles for OAM_TILE_DIGIT_0..OAM_TILE_MISS_S ($E0..$ED)
RpgDmgDigitTiles:
        ; $E0: '0'
        _dmg_glyph %00111100, %01100110, %01101110, %01110110, %01100110, %01100110, %00111100, %00000000
        ; $E1: '1'
        _dmg_glyph %00011000, %00111000, %00011000, %00011000, %00011000, %00011000, %01111110, %00000000
        ; $E2: '2'
        _dmg_glyph %00111100, %01100110, %00000110, %00011100, %00110000, %01100000, %01111110, %00000000
        ; $E3: '3'
        _dmg_glyph %00111100, %01100110, %00000110, %00011100, %00000110, %01100110, %00111100, %00000000
        ; $E4: '4'
        _dmg_glyph %00001100, %00011100, %00111100, %01101100, %01111110, %00001100, %00001100, %00000000
        ; $E5: '5'
        _dmg_glyph %01111110, %01100000, %01111100, %00000110, %00000110, %01100110, %00111100, %00000000
        ; $E6: '6'
        _dmg_glyph %00111100, %01100000, %01111100, %01100110, %01100110, %01100110, %00111100, %00000000
        ; $E7: '7'
        _dmg_glyph %01111110, %00000110, %00001100, %00011000, %00110000, %00110000, %00110000, %00000000
        ; $E8: '8'
        _dmg_glyph %00111100, %01100110, %01100110, %00111100, %01100110, %01100110, %00111100, %00000000
        ; $E9: '9'
        _dmg_glyph %00111100, %01100110, %01100110, %00111110, %00000110, %00001100, %00111000, %00000000
        ; $EA: '-'
        _dmg_glyph %00000000, %00000000, %00000000, %01111110, %01111110, %00000000, %00000000, %00000000
        ; $EB: 'M'
        _dmg_glyph %01100110, %01111110, %01111110, %01101110, %01100110, %01100110, %01100110, %00000000
        ; $EC: 'I'
        _dmg_glyph %01111110, %00011000, %00011000, %00011000, %00011000, %00011000, %01111110, %00000000
        ; $ED: 'S'
        _dmg_glyph %00111100, %01100110, %01100000, %00111100, %00000110, %01100110, %00111100, %00000000
RpgDmgDigitTilesEnd:
.endif

; ==============================================================================
; Bank $87 (`ROM_LEVELS`): Level Metadata (.tab, .pal, .map, .gmap)
; ==============================================================================
.segment "ROM_LEVELS"
.ifndef USE_DEMO_LEVEL_DATA
Level0AtlasTab:     .incbin "../RamMapDemo/Data/ZEAKDEN_ATLAS.tab"
Level0AtlasTabEnd:
Level0AtlasPal:     .incbin "../RamMapDemo/Data/ZEAKDEN_ATLAS.pal"
Level0MapBin:       .incbin "../RamMapDemo/Data/level2_zeakden.map"
Level0MapBinEnd:
.include "fallback_gmap.i"
.else
Level0AtlasTab:     .incbin "Data/DEMO_ATLAS.tab"
Level0AtlasTabEnd:
Level0AtlasPal:     .incbin "Data/DEMO_ATLAS.pal"
Level0MapBin:       .incbin "Data/demo_level.map"
Level0MapBinEnd:
Level0GmapBin:      .incbin "Data/demo_level.gmap"
Level0GmapBinEnd:
.endif

; ==============================================================================
; Bank $88 (`ROM_ATLAS0`): Level 0 Texture Atlas (.bin, 16-32 KB)
; ==============================================================================
.segment "ROM_ATLAS0"
.ifndef USE_DEMO_LEVEL_DATA
Level0AtlasBin:     .incbin "../RamMapDemo/Data/ZEAKDEN_ATLAS.bin"
Level0AtlasBinEnd:
.else
Level0AtlasBin:     .incbin "Data/DEMO_ATLAS.bin"
Level0AtlasBinEnd:
.endif
