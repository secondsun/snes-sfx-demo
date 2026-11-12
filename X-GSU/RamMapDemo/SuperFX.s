; ==============================================================================
; RamMapDemo - Bank-$71 Isometric Level & Relocatable Atlas Showcase
;
; Demonstrates loading 3 `sfx-studio`-authored isometric levels across 2 distinct
; Texture Atlases of different widths and palettes into Game Pak RAM Bank $71:
;   - Level 1 (`level1_courtyard`, 8x8):   `COURTYARD_ATLAS` (64x128, shift=6, id=0)
;   - Level 2 (`level2_garden`,    12x10): `COURTYARD_ATLAS` (resident id=0 cache hit!)
;   - Level 3 (`level3_citadel`,   16x16): `CITADEL_ATLAS`   (128x128, shift=7, id=1)
;
; Controls:
;   - SELECT: Cycle Level 1 -> Level 2 -> Level 3 -> Level 1
;   - L / R:  Orbit 3D isometric camera yaw (3 degrees/frame)
;   - D-Pad:  Pan camera focus across the map
;
; AssetSource Seam:
;   Currently includes `../gsu_iso/asset_source_rom.i` (`def_rom_asset`).
;   To stream from MSU-1 instead, swap `asset_source_rom.i` for
;   `../gsu_iso/asset_source_msu1.i` and use `def_msu_asset <offset32>, <size>`.
; ==============================================================================

.include "libSFX.i"
.include "pointers.s"
.include "CpuMacros.s"
.include "../gsu_iso/cpu_asset_loader.i"
.include "../gsu_iso/asset_source_rom.i"

.import GSU_Code
.import GSU_JOYPAD

NUM_LEVELS = 3

.segment "ZEROPAGE"
VRAM_screen_select:     .res 1  ; 0 = VRAM_screen_1, 1 = VRAM_screen_2
SFX_buffer_position:    .res 1  ; 0 = left half [0..127], 1 = right half [128..255]

.segment "LORAM"
current_level_idx:      .res 1  ; Active level index (0..2)
pending_level_swap:     .res 1  ; Set on rising-edge SELECT in VBlank; handled in MAIN_LOOP

.export current_level_idx, pending_level_swap

.segment "CODE"

; Long-call wrapper so `MAIN_LOOP` executing in LORAM ($00) can invoke
; `sfx_load_level` in cartridge ROM0 ($80) once GSU_SCMR has been released.
sfx_load_level_far:
        jsr     sfx_load_level
        rtl

Main:
        ; Copy WRAM-resident main loop and VBlank handler to LORAM
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__

        ; Clear VRAM double-buffers (including blank letterbox tile $0280) and upload BG1 tilemap
        VRAM_memset $0000, $B000, $00
        VRAM_memcpy VRAM_tilemap, Map, (Map_end - Map)

        ; Clear initial GSU joypad state and $70:8000 half-screen buffer while bus is free
        RW_push set:a16i16
        lda     #$0000
        sta     f:GSU_JOYPAD
        ldx     #$0000
@clr70: sta     f:screenbuffer, x
        inx
        inx
        cpx     #screenbuffer_len
        bcc     @clr70
        RW_pull

        ; Initialize Bank-$71 host loader and stage Level 1 (COURTYARD_ATLAS + 8x8 Courtyard)
        stz     a:current_level_idx
        stz     a:pending_level_swap
        SFX_LOADER_INIT SFX_DEFAULT_GSU_SCMR
        SFX_LOAD_LEVEL Level1Def

        ; Configure GSU hardware registers (PBR=$03, ROMBR=$04, SCBR=$20, SCMR=%00011101)
        initGSU_4bpp_160

        jml     __MAIN_LOOP_RUN__

; ==============================================================================
; WRAM-Resident Main Loop (executes in LORAM while GSU owns ROM/RAM buses)
; ==============================================================================
.segment "MAIN_LOOP"
Main2:
        RW_forced a8i16
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #bgsc(VRAM_tilemap, SC_SIZE_32X32)
        sta     BG1SC

        lda     #bg12nba(VRAM_screen_1, 0)
        sta     BG12NBA

        lda     #tm(ON, OFF, OFF, OFF, OFF)
        sta     TM

        lda     #<(-$20)
        sta     BG1VOFS
        lda     #>(-$20)
        sta     BG1VOFS
        stz     BG1HOFS
        stz     BG1HOFS

        stz     z:VRAM_screen_select
        stz     z:SFX_buffer_position

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     z:SFX_inidisp

        VBL_set Vblank
        gsuOn
        VBL_on

infinite_loop:
        RW_forced a8i16
        lda     a:pending_level_swap
        beq     infinite_loop

        ; Wait for GSU to complete any in-flight pass before releasing GSU_SCMR
@wait_gsu_done:
        gsuRunning
        bne     @wait_gsu_done

        ; Lock VBlank GSU dispatch and release GSU ROM/RAM bus so 65816 can
        ; read LevelDefTable and execute `sfx_load_level_far` from ROM0 ($80).
        lda     #$01
        sta     a:sfx_gsu_load_lock
        stz     GSU_SCMR

        ; Cycle current_level_idx: 0 -> 1 -> 2 -> 0
        lda     a:current_level_idx
        inc
        cmp     #NUM_LEVELS
        bcc     :+
        lda     #$00
:       sta     a:current_level_idx

        RW a16
        and     #$00FF
        asl
        tax
        lda     f:LevelDefTable, x
        tax                             ; X = 16-bit offset of target sfx_level_def
        RW a8
        lda     #$80                    ; A = bank $80 (RODATA)
        jsl     sfx_load_level_far

        ; Reset half-frame pipeline to Pass 0 and launch GSU import + Pass 0 render
        stz     z:SFX_buffer_position
        stz     a:pending_level_swap
        gsuOn
        bra     infinite_loop

; ==============================================================================
; WRAM-Resident VBlank Handler
; ==============================================================================
.segment "VBLANK"
Vblank:
        RW_forced a8i16
        lda     #$80
        pha
        plb

        ; Never touch GSU or VRAM while the 65816 main thread is staging Bank $71
        lda     a:sfx_gsu_load_lock
        beq     :+
        endVBlank
:
        ; Check rising-edge SELECT button (bit 5 of high byte, JOY_SELECT = $2000)
        lda     z:SFX_joy1trig + 1
        and     #>JOY_SELECT
        beq     :+
        lda     #$01
        sta     a:pending_level_swap
:

        ; If a level swap is pending, let the main loop take over cleanly
        lda     a:pending_level_swap
        beq     :+
        endVBlank
:
        ; Wait until current GSU half-frame pass finishes
        gsuRunning
        beq     :+
        endVBlank
:
        ; Forward held joypad state (L/R yaw, D-Pad pan) to GSU
        RW a16
        lda     z:SFX_joy1cont
        sta     f:GSU_JOYPAD
        RW a8

        lda     z:VRAM_screen_select
        bne     drawScreen2
        jmp     drawScreen1

drawScreen2:
        lda     z:SFX_buffer_position
        beq     @copyStart2
        VRAM_memcpy (VRAM_screen_2 + screenbuffer_len), screenbuffer, screenbuffer_len
        stz     z:SFX_buffer_position
        lda     #$00
        sta     f:GSU_FRAME_HALF
        stz     z:VRAM_screen_select
        lda     #bg12nba(VRAM_screen_2, 0)
        sta     BG12NBA
        gsuOn
        endVBlank
@copyStart2:
        VRAM_memcpy VRAM_screen_2, screenbuffer, screenbuffer_len
        lda     #$01
        sta     z:SFX_buffer_position
        sta     f:GSU_FRAME_HALF
        gsuOn
        endVBlank

drawScreen1:
        lda     z:SFX_buffer_position
        bne     @copyHalf1
        VRAM_memcpy VRAM_screen_1, screenbuffer, screenbuffer_len
        lda     #$01
        sta     z:SFX_buffer_position
        sta     f:GSU_FRAME_HALF
        gsuOn
        endVBlank
@copyHalf1:
        VRAM_memcpy (VRAM_screen_1 + screenbuffer_len), screenbuffer, screenbuffer_len
        stz     z:SFX_buffer_position
        lda     #$00
        sta     f:GSU_FRAME_HALF
        lda     #$01
        sta     z:VRAM_screen_select
        lda     #bg12nba(VRAM_screen_1, 0)
        sta     BG12NBA
        gsuOn
        endVBlank

; ==============================================================================
; Level Descriptors & BG1 Tilemap in RODATA ($80)
; ==============================================================================
.segment "RODATA"
.include "backgroundMap.s"

LevelDefTable:
        .word   .loword(Level1Def)
        .word   .loword(Level2Def)
        .word   .loword(Level3Def)

; Level 1: 8x8 Royal Courtyard on COURTYARD_ATLAS (64x128, stride_shift=6, atlas_id=0)
Level1Def:
        .word   $0000
        def_rom_asset CourtyardAtlasBin, (CourtyardAtlasBinEnd - CourtyardAtlasBin)
        def_rom_asset CourtyardAtlasTab, (CourtyardAtlasTabEnd - CourtyardAtlasTab)
        def_rom_asset CourtyardAtlasPal, 32
        def_rom_asset Level1MapBin,      (Level1MapBinEnd - Level1MapBin)

; Level 2: 12x10 Hanging Canal Gardens on COURTYARD_ATLAS (resident atlas_id=0 cache hit!)
Level2Def:
        .word   $0000
        def_rom_asset CourtyardAtlasBin, (CourtyardAtlasBinEnd - CourtyardAtlasBin)
        def_rom_asset CourtyardAtlasTab, (CourtyardAtlasTabEnd - CourtyardAtlasTab)
        def_rom_asset CourtyardAtlasPal, 32
        def_rom_asset Level2MapBin,      (Level2MapBinEnd - Level2MapBin)

; Level 3: 16x16 Volcanic Citadel on CITADEL_ATLAS (128x128, stride_shift=7, atlas_id=1)
Level3Def:
        .word   $0001
        def_rom_asset CitadelAtlasBin,   (CitadelAtlasBinEnd - CitadelAtlasBin)
        def_rom_asset CitadelAtlasTab,   (CitadelAtlasTabEnd - CitadelAtlasTab)
        def_rom_asset CitadelAtlasPal,   32
        def_rom_asset Level3MapBin,      (Level3MapBinEnd - Level3MapBin)

; ==============================================================================
; Bank $85: Courtyard Atlas (64x128 = 8,192 B) + Level 1 (8x8) & Level 2 (12x10)
; ==============================================================================
.segment "ROM5"
CourtyardAtlasBin:
        .incbin "Data/COURTYARD_ATLAS.bin"
CourtyardAtlasBinEnd:

CourtyardAtlasTab:
        .incbin "Data/COURTYARD_ATLAS.tab"
CourtyardAtlasTabEnd:

CourtyardAtlasPal:
        .incbin "Data/COURTYARD_ATLAS.pal"

Level1MapBin:
        .incbin "Data/level1_courtyard.map"
Level1MapBinEnd:

Level2MapBin:
        .incbin "Data/level2_garden.map"
Level2MapBinEnd:

; ==============================================================================
; Bank $86: Citadel Atlas (128x128 = 16,384 B) + Level 3 (16x16 = 2,056 B)
; ==============================================================================
.segment "ROM6"
CitadelAtlasBin:
        .incbin "Data/CITADEL_ATLAS.bin"
CitadelAtlasBinEnd:

CitadelAtlasTab:
        .incbin "Data/CITADEL_ATLAS.tab"
CitadelAtlasTabEnd:

CitadelAtlasPal:
        .incbin "Data/CITADEL_ATLAS.pal"

Level3MapBin:
        .incbin "Data/level3_citadel.map"
Level3MapBinEnd:
