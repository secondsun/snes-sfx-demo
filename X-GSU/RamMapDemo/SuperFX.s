; ==============================================================================
; RamMapDemo - Bank-$71 Isometric Level & Relocatable Atlas Showcase
;
; Demonstrates loading 7 Final Fantasy Tactics stages ported via `sfx-studio`
; (`level import-fft`) across 7 distinct 15-color Texture Atlases into Game Pak
; RAM Bank $71:
;   - Level 1 (`level1_orbonne`,  10x14): `ORBONNE_ATLAS`  (MAP056, id=0)
;   - Level 2 (`level2_zeakden`,   9x13): `ZEAKDEN_ATLAS`  (MAP049, id=1)
;   - Level 3 (`level3_igros`,    10x13): `IGROS_ATLAS`    (MAP001, id=2)
;   - Level 4 (`level4_sweegy`,   11x12): `SWEEGY_ATLAS`   (MAP074, id=3)
;   - Level 5 (`level5_araguay`,  12x10): `ARAGUAY_ATLAS`  (MAP080, id=4)
;   - Level 6 (`level6_riovanes`, 13x11): `RIOVANES_ATLAS` (MAP005, id=5)
;   - Level 7 (`level7_bervenia`, 10x12): `BERVENIA_ATLAS` (MAP075, id=6)
;
; Controls:
;   - SELECT: Next level (1 -> 2 -> ... -> 7 -> 1)
;   - START:  Previous level (7 -> 6 -> ... -> 1 -> 7)
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
.import GSU_SCENE_MODE

NUM_LEVELS = 7
BANK71_MESH_ADDR = $9030

.segment "ZEROPAGE"
VRAM_screen_select:     .res 1  ; 0 = VRAM_screen_1, 1 = VRAM_screen_2
SFX_buffer_position:    .res 1  ; 0 = left half [0..127], 1 = right half [128..255]

.segment "LORAM"
current_level_idx:      .res 1  ; Active level index (0..6)
                        .res 1  ; 16-bit write guard pad for headless input injection
pending_level_swap:     .res 1  ; Set on rising-edge SELECT/START in VBlank; handled in MAIN_LOOP
                        .res 1  ; 16-bit write guard pad before VBlankVector

.export current_level_idx, pending_level_swap

.segment "CODE"

; Stages LevelDefTable[current_level_idx] atlas/tab/pal into Bank $71, then either:
;   - stages LevelMeshTable[current_level_idx] -> $71:9030 and sets GSU_SCENE_MODE = 1 (if mesh size != 0)
;   - stages LevelDef.map_entry -> $71:8808 and sets GSU_SCENE_MODE = 0 (if mesh size == 0)
; Must be called with RW_forced a8i16 while GSU is stopped or idle.
load_demo_level:
        php
        RW_forced a8i16
        jsr     _sfx_acquire_gsu_bus

        RW a16
        lda     a:current_level_idx
        and     #$00FF
        asl
        tax
        lda     f:LevelDefTable, x
        sta     z:sfx_def_ptr
        RW a8
        lda     #^LevelDefTable
        sta     z:sfx_def_ptr + 2

        jsr     _sfx_stage_atlas_from_def_ptr

        ; Check LevelMeshTable[current_level_idx] (8 bytes per sfx_asset_entry)
        RW a16
        lda     a:current_level_idx
        and     #$00FF
        asl
        asl
        asl
        tax
        lda     f:LevelMeshTable + sfx_asset_entry::byte_size, x
        beq     @stage_iso_map

        ; Hybrid 3D Mesh level: stage .msh -> $71:9030 and set GSU_SCENE_MODE = 1
        txa
        clc
        adc     #.loword(LevelMeshTable)
        sta     z:sfx_def_ptr
        RW a8
        lda     #^LevelMeshTable
        sta     z:sfx_def_ptr + 2
        ldy     #$0000
        ldx     #BANK71_MESH_ADDR
        jsr     _sfx_copy_entry_at_y
        RW a16
        lda     #$0001
        sta     f:GSU_SCENE_MODE
        bra     @finish_demo_load

@stage_iso_map:
        ; MapGrid level: z:sfx_def_ptr still points to LevelDefTable[idx]
        ldy     #sfx_level_def::map_entry
        ldx     #BANK71_MAP_ADDR
        jsr     _sfx_copy_entry_at_y
        lda     #$0000
        sta     f:GSU_SCENE_MODE

@finish_demo_load:
        ldx     #SFX_LOAD_MODE_LEVEL
        stx     a:sfx_pending_load_mode
        RW a8
        jsr     _sfx_release_gsu_bus
        plp
        rts

; Long-call wrapper so `MAIN_LOOP` executing in LORAM ($00) can invoke
; `load_demo_level` in cartridge ROM0 ($80) once GSU_SCMR has been released.
load_demo_level_far:
        jsr     load_demo_level
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

        ; Initialize Bank-$71 host loader and stage LevelDefTable[current_level_idx]
        ; (BootVector already zeroed LORAM, so current_level_idx defaults to 0 while
        ; preserving headless Mesen `inputs` overrides injected at Main).
        SFX_LOADER_INIT SFX_DEFAULT_GSU_SCMR
        RW_push set:a8i16
        lda     a:current_level_idx
        cmp     #NUM_LEVELS
        bcc     :+
        lda     #$00
        sta     a:current_level_idx
:       jsr     load_demo_level
        RW_pull

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

        ; Cycle current_level_idx forward (pending_level_swap > 0) or backward (< 0)
        lda     a:pending_level_swap
        bmi     @prev_level
        lda     a:current_level_idx
        inc
        cmp     #NUM_LEVELS
        bcc     @store_idx
        lda     #$00
        bra     @store_idx
@prev_level:
        lda     a:current_level_idx
        bne     :+
        lda     #NUM_LEVELS
:       dec
@store_idx:
        sta     a:current_level_idx
        jsl     load_demo_level_far

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
        ; Check rising-edge SELECT (next level) and START (previous level)
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_SELECT
        beq     :+
        lda     #$01
        sta     a:pending_level_swap
        bra     @check_swap
:       bit     #>JOY_START
        beq     @check_swap
        lda     #$FF
        sta     a:pending_level_swap
@check_swap:

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
        .word   .loword(Level4Def)
        .word   .loword(Level5Def)
        .word   .loword(Level6Def)
        .word   .loword(Level7Def)

LevelMeshTable:
        def_rom_asset Level1MeshBin,    (Level1MeshBinEnd - Level1MeshBin)
        .word   0, 0, 0, 0
        .word   0, 0, 0, 0
        .word   0, 0, 0, 0
        .word   0, 0, 0, 0
        .word   0, 0, 0, 0
        .word   0, 0, 0, 0

; Level 1: Orbonne Monastery (MAP056, Hybrid 3D Mesh)
Level1Def:
        .word   $0000
        def_rom_asset OrbonneMeshBin,    (OrbonneMeshBinEnd - OrbonneMeshBin)
        def_rom_asset OrbonneMeshTab,    (OrbonneMeshTabEnd - OrbonneMeshTab)
        def_rom_asset OrbonneMeshPal,    32
        .word   0, 0, 0, 0

; Level 2: Fort Zeakden (MAP049, 9x13)
Level2Def:
        .word   $0001
        def_rom_asset ZeakdenAtlasBin,   (ZeakdenAtlasBinEnd - ZeakdenAtlasBin)
        def_rom_asset ZeakdenAtlasTab,   (ZeakdenAtlasTabEnd - ZeakdenAtlasTab)
        def_rom_asset ZeakdenAtlasPal,   32
        def_rom_asset Level2MapBin,      (Level2MapBinEnd - Level2MapBin)

; Level 3: Main Gate of Igros Castle (MAP001, 10x13)
Level3Def:
        .word   $0002
        def_rom_asset IgrosAtlasBin,     (IgrosAtlasBinEnd - IgrosAtlasBin)
        def_rom_asset IgrosAtlasTab,     (IgrosAtlasTabEnd - IgrosAtlasTab)
        def_rom_asset IgrosAtlasPal,     32
        def_rom_asset Level3MapBin,      (Level3MapBinEnd - Level3MapBin)

; Level 4: Sweegy Woods (MAP074, 11x12)
Level4Def:
        .word   $0003
        def_rom_asset SweegyAtlasBin,    (SweegyAtlasBinEnd - SweegyAtlasBin)
        def_rom_asset SweegyAtlasTab,    (SweegyAtlasTabEnd - SweegyAtlasTab)
        def_rom_asset SweegyAtlasPal,    32
        def_rom_asset Level4MapBin,      (Level4MapBinEnd - Level4MapBin)

; Level 5: Araguay Woods (MAP080, 12x10)
Level5Def:
        .word   $0004
        def_rom_asset AraguayAtlasBin,   (AraguayAtlasBinEnd - AraguayAtlasBin)
        def_rom_asset AraguayAtlasTab,   (AraguayAtlasTabEnd - AraguayAtlasTab)
        def_rom_asset AraguayAtlasPal,   32
        def_rom_asset Level5MapBin,      (Level5MapBinEnd - Level5MapBin)

; Level 6: Roof of Riovanes Castle (MAP005, 13x11)
Level6Def:
        .word   $0005
        def_rom_asset RiovanesAtlasBin,  (RiovanesAtlasBinEnd - RiovanesAtlasBin)
        def_rom_asset RiovanesAtlasTab,  (RiovanesAtlasTabEnd - RiovanesAtlasTab)
        def_rom_asset RiovanesAtlasPal,  32
        def_rom_asset Level6MapBin,      (Level6MapBinEnd - Level6MapBin)

; Level 7: Bervenia Volcano (MAP075, 10x12)
Level7Def:
        .word   $0006
        def_rom_asset BerveniaAtlasBin,  (BerveniaAtlasBinEnd - BerveniaAtlasBin)
        def_rom_asset BerveniaAtlasTab,  (BerveniaAtlasTabEnd - BerveniaAtlasTab)
        def_rom_asset BerveniaAtlasPal,  32
        def_rom_asset Level7MapBin,      (Level7MapBinEnd - Level7MapBin)

; ==============================================================================
; Bank $85: All 7 Relocatable Texture Tables, Palettes & Map Grids (~11 KB)
; ==============================================================================
.segment "ROM5"
OrbonneMeshTab:     .incbin "Data/ORBONNE_MESH.tab"
OrbonneMeshTabEnd:
OrbonneMeshPal:     .incbin "Data/ORBONNE_MESH.pal"

ZeakdenAtlasTab:    .incbin "Data/ZEAKDEN_ATLAS.tab"
ZeakdenAtlasTabEnd:
ZeakdenAtlasPal:    .incbin "Data/ZEAKDEN_ATLAS.pal"
Level2MapBin:       .incbin "Data/level2_zeakden.map"
Level2MapBinEnd:

IgrosAtlasTab:      .incbin "Data/IGROS_ATLAS.tab"
IgrosAtlasTabEnd:
IgrosAtlasPal:      .incbin "Data/IGROS_ATLAS.pal"
Level3MapBin:       .incbin "Data/level3_igros.map"
Level3MapBinEnd:

SweegyAtlasTab:     .incbin "Data/SWEEGY_ATLAS.tab"
SweegyAtlasTabEnd:
SweegyAtlasPal:     .incbin "Data/SWEEGY_ATLAS.pal"
Level4MapBin:       .incbin "Data/level4_sweegy.map"
Level4MapBinEnd:

AraguayAtlasTab:    .incbin "Data/ARAGUAY_ATLAS.tab"
AraguayAtlasTabEnd:
AraguayAtlasPal:    .incbin "Data/ARAGUAY_ATLAS.pal"
Level5MapBin:       .incbin "Data/level5_araguay.map"
Level5MapBinEnd:

RiovanesAtlasTab:   .incbin "Data/RIOVANES_ATLAS.tab"
RiovanesAtlasTabEnd:
RiovanesAtlasPal:   .incbin "Data/RIOVANES_ATLAS.pal"
Level6MapBin:       .incbin "Data/level6_riovanes.map"
Level6MapBinEnd:

BerveniaAtlasTab:   .incbin "Data/BERVENIA_ATLAS.tab"
BerveniaAtlasTabEnd:
BerveniaAtlasPal:   .incbin "Data/BERVENIA_ATLAS.pal"
Level7MapBin:       .incbin "Data/level7_bervenia.map"
Level7MapBinEnd:

; ==============================================================================
; Dedicated 32 KB Banks ($86..$8C): Texture Atlases 1..7 (<= 32,768 B each)
; ==============================================================================
.segment "ROM6"
OrbonneMeshBin:     .incbin "Data/ORBONNE_MESH.bin"
OrbonneMeshBinEnd:

.segment "ROM7"
ZeakdenAtlasBin:    .incbin "Data/ZEAKDEN_ATLAS.bin"
ZeakdenAtlasBinEnd:

.segment "ROM8"
IgrosAtlasBin:      .incbin "Data/IGROS_ATLAS.bin"
IgrosAtlasBinEnd:

.segment "ROM9"
SweegyAtlasBin:     .incbin "Data/SWEEGY_ATLAS.bin"
SweegyAtlasBinEnd:

.segment "ROM10"
AraguayAtlasBin:    .incbin "Data/ARAGUAY_ATLAS.bin"
AraguayAtlasBinEnd:

.segment "ROM11"
RiovanesAtlasBin:   .incbin "Data/RIOVANES_ATLAS.bin"
RiovanesAtlasBinEnd:

.segment "ROM12"
BerveniaAtlasBin:   .incbin "Data/BERVENIA_ATLAS.bin"
BerveniaAtlasBinEnd:

.segment "ROM13"
Level1MeshBin:      .incbin "Data/level1_orbonne.msh"
Level1MeshBinEnd:
