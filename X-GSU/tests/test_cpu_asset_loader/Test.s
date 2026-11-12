; ==============================================================================
; TEST_CPU_ASSET_LOADER - 65816 Host Loader & Multi-Bank ROM AssetSource Suite
;
; Exercises on real 65816 hardware:
;   Phase 1: Full 32,768-byte ($8000) max-capacity atlas copy from $85:8000 ->
;            $71:0000..$71:7FFF, DB == $80 postcondition, lock release, CGRAM[1]
;   Phase 2: Resident `atlas_id` deduplication cache hit ($DEAD sentinel kept,
;            `sfx_atlas_load_count == 1`, while `.map` updates `$71:8808`)
;   Phase 3: Resident `atlas_id` cache miss (`atlas_id = 1` from $86:8000,
;            `sfx_atlas_load_count == 2`, CGRAM[1] updated to $7C1F)
;   Phase 4: `SFX_LOAD_MAP` map-only hot-swap (`GSU_LOAD_MODE == 2`,
;            `sfx_atlas_load_count == 2`), followed by live GSU import & render
; ==============================================================================
.include "libSFX.i"
.include "../../gsu_iso/cpu_asset_loader.i"
.include "../../gsu_iso/asset_source_rom.i"

.import GSU_Code
.import CPU_SNAP_P1, CPU_SNAP_P2, CPU_SNAP_P3, CPU_SNAP_P4

; Helper: Read PPU CGRAM color 1 into 16-bit C (assumes a8 on entry, leaves a16)
.macro READ_CGRAM_COLOR1
        RW_forced a8i16
        lda     #$01
        sta     CGADD
        lda     CGDATAREAD
        xba
        lda     CGDATAREAD
        and     #$7F
        xba
        RW a16
.endmac

Main:
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
        memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__

        SFX_LOADER_INIT %00011101

        ; ======================================================================
        ; Phase 1: Full 32,768-byte ($8000) atlas copy from $85:8000 -> $71:0000
        ; ======================================================================
        SFX_LOAD_LEVEL LevelDef_32K

        ; Immediately capture Data Bank `DB` and `sfx_gsu_load_lock` BEFORE any
        ; manual bus manipulation (proving MVN restored DB = $80!)
        RW a8i16
        phb
        pla
        xba
        lda     a:sfx_gsu_load_lock     ; high byte = DB ($80), low byte = lock ($00)
        stz     GSU_SCMR                ; release GSU bus to inspect $70/$71
        RW a16
        sta     f:CPU_SNAP_P1 + 8       ; [4]: $8000 = (DB << 8) | lock

        lda     f:$710000               ; [0]: first word of 32 KB atlas ($1122)
        sta     f:CPU_SNAP_P1 + 0
        lda     f:$714000               ; [1]: midpoint word ($3344)
        sta     f:CPU_SNAP_P1 + 2
        lda     f:$717FFE               ; [2]: exact final word at +32766 ($7788)
        sta     f:CPU_SNAP_P1 + 4

        READ_CGRAM_COLOR1               ; [3]: CGRAM[1] == $14A5
        sta     f:CPU_SNAP_P1 + 6

        lda     a:sfx_atlas_load_count  ; [5]: loads == 1
        sta     f:CPU_SNAP_P1 + 10

        ; ======================================================================
        ; Phase 2: Resident `atlas_id = 0` cache hit
        ; Write $DEAD sentinel to $71:0000 first; cache hit must NOT overwrite!
        ; ======================================================================
        lda     #$DEAD
        sta     f:$710000
        lda     #$0001
        sta     f:GSU_INIT_FLAG         ; simulate GSU initialized

        RW a8
        lda     #%00011101
        sta     GSU_SCMR

        SFX_LOAD_LEVEL LevelDef_SameAtlas

        RW a8
        stz     GSU_SCMR
        RW a16
        lda     a:sfx_atlas_load_count  ; [0]: loads == 1 (cache hit!)
        sta     f:CPU_SNAP_P2 + 0
        lda     f:$710000               ; [1]: still $DEAD (atlas skipped!)
        sta     f:CPU_SNAP_P2 + 2
        lda     f:$71880A               ; [2]: map origin_x updated to 111 ($006F)
        sta     f:CPU_SNAP_P2 + 4
        lda     f:GSU_LOAD_MODE         ; [3]: SFX_LOAD_MODE_LEVEL (1)
        sta     f:CPU_SNAP_P2 + 6
        lda     f:GSU_INIT_FLAG         ; [4]: reset to 0
        sta     f:CPU_SNAP_P2 + 8

        ; ======================================================================
        ; Phase 3: Resident `atlas_id = 1` cache miss from Bank $86
        ; ======================================================================
        lda     #$0001
        sta     f:GSU_INIT_FLAG

        RW a8
        lda     #%00011101
        sta     GSU_SCMR

        SFX_LOAD_LEVEL LevelDef_Atlas1

        RW a8
        stz     GSU_SCMR
        RW a16
        lda     a:sfx_atlas_load_count  ; [0]: loads == 2 (cache miss!)
        sta     f:CPU_SNAP_P3 + 0
        lda     a:sfx_resident_atlas_id ; [1]: resident_atlas_id == 1
        sta     f:CPU_SNAP_P3 + 2
        lda     f:$710000               ; [2]: overwritten with $0505 from Bank $86!
        sta     f:CPU_SNAP_P3 + 4
        READ_CGRAM_COLOR1               ; [3]: CGRAM[1] updated to $7C1F!
        sta     f:CPU_SNAP_P3 + 6
        lda     f:GSU_LOAD_MODE         ; [4]: SFX_LOAD_MODE_LEVEL (1)
        sta     f:CPU_SNAP_P3 + 8
        lda     f:GSU_INIT_FLAG         ; [5]: reset to 0
        sta     f:CPU_SNAP_P3 + 10

        ; ======================================================================
        ; Phase 4: `SFX_LOAD_MAP` map-only hot-swap (6x4 map, keeps Atlas1)
        ; ======================================================================
        lda     #$0001
        sta     f:GSU_INIT_FLAG

        RW a8
        lda     #%00011101
        sta     GSU_SCMR

        SFX_LOAD_MAP Map1B_Entry

        RW a8
        stz     GSU_SCMR
        RW a16
        lda     a:sfx_atlas_load_count  ; [0]: still 2!
        sta     f:CPU_SNAP_P4 + 0
        lda     f:GSU_LOAD_MODE         ; [1]: SFX_LOAD_MODE_MAP (2)
        sta     f:CPU_SNAP_P4 + 2
        lda     f:GSU_INIT_FLAG         ; [2]: reset to 0
        sta     f:CPU_SNAP_P4 + 4

        RW a8
        jml     __MAIN_LOOP_RUN__

; ------------------------------------------------------------------------------
; Level & Map Descriptors in RODATA ($80)
; ------------------------------------------------------------------------------
.segment "RODATA"
LevelDef_32K:
        .word   $0000                           ; atlas_id = 0
        def_rom_asset Atlas32K, $8000           ; full 32,768-byte max-capacity atlas!
        def_rom_asset Tab0,     (Tab0End - Tab0)
        def_rom_asset Pal0,     32
        def_rom_asset Map0,     (Map0End - Map0)

LevelDef_SameAtlas:
        .word   $0000                           ; atlas_id = 0 (cache hit!)
        def_rom_asset Atlas32K, $8000
        def_rom_asset Tab0,     (Tab0End - Tab0)
        def_rom_asset Pal0,     32
        def_rom_asset Map1A,    (Map1AEnd - Map1A)

LevelDef_Atlas1:
        .word   $0001                           ; atlas_id = 1 (cache miss!)
        def_rom_asset Atlas1,   (Atlas1End - Atlas1)
        def_rom_asset Tab1,     (Tab1End - Tab1)
        def_rom_asset Pal1,     32
        def_rom_asset Map1A,    (Map1AEnd - Map1A)

Map1B_Entry:
        def_rom_asset Map1B,    (Map1BEnd - Map1B)

; ------------------------------------------------------------------------------
; Bank $85: Exact 32,768-byte ($8000) Full-Capacity Atlas Payload
; ------------------------------------------------------------------------------
.segment "ROM5"
Atlas32K:
        .word   $1122                           ; +$0000
        .res    ($4000 - 2), $AA
        .word   $3344                           ; +$4000
        .res    ($3FFE - 2), $55
        .word   $7788                           ; +$7FFE (exact 32,768-byte end!)

; ------------------------------------------------------------------------------
; Bank $86: Second Atlas (64x32 = 2,048 bytes, filled with color index 5)
; ------------------------------------------------------------------------------
.segment "ROM6"
Atlas1:
        .res    2048, $05
Atlas1End:

; ------------------------------------------------------------------------------
; Bank $87: Relocatable `.tab`s, 32B `.pal`s, and `.map`s
; ------------------------------------------------------------------------------
.segment "ROM7"
Tab0:
        .word   $5453                           ; +0: "ST" magic
        .word   1                               ; +2: entry_count = 1
        .word   128                             ; +4: atlas_width = 128
        .word   7                               ; +6: stride_shift = 7
        ; Entry 0: offset 0, u_mask=31, v_mask_shift=(31<<7)=$0F80, v_offset_mask=$0FFF
        .word   $0000, 31, $0F80, $0FFF
Tab0End:

Pal0:
        .word   $0000, $14A5
        .res    28, $00

Map0:
        .byte   4, 4                            ; 4x4
        .word   128, 64, $0000                  ; origin_x = 128, origin_z = 64
        .res    (16 * 8), $00
Map0End:

Tab1:
        .word   $5453                           ; +0: "ST" magic
        .word   1                               ; +2: entry_count = 1
        .word   64                              ; +4: atlas_width = 64
        .word   6                               ; +6: stride_shift = 6
        ; Entry 0: offset 0, u_mask=31, v_mask_shift=(31<<6)=$07C0, v_offset_mask=$07FF
        .word   $0000, 31, $07C0, $07FF
Tab1End:

Pal1:
        .word   $0000, $7C1F
        .res    28, $00

Map1A:
        .byte   4, 4                            ; 4x4
        .word   111, 64, $0000                  ; origin_x = 111
        .res    (16 * 8), $00
Map1AEnd:

Map1B:
        .byte   6, 4                            ; 6x4 hot-swapped map!
        .word   128, 64, $BACE                  ; prebaked drops
        .res    (24 * 8), $00                   ; 24 PRIM_FLAT cells using tex_id 0 (color 5)
Map1BEnd:

; ------------------------------------------------------------------------------
; Main Loop (Launches GSU Verification)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"
        RW a8i16
        ldx     #$A000
        lda     #$00
:       sta     $700000, x
        inx
        cpx     #$C800
        bne     :-

        lda     #$70
        sta     GSU_PBR
        lda     #$28
        sta     GSU_SCBR        ; $70:A000 framebuffer
        lda     #%00011101
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR
        lda     #$04
        sta     GSU_ROMBR

        ldx     #.loword(GSU_Code)
        stx     GSU_R15

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        VBL_on

:       wai
        bra     :-
