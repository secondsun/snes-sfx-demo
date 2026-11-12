; ==============================================================================
; TEST_CPU_MSU1_LOADER - End-to-End 65816 MSU-1 Storage AssetSource Test Suite
;
; Drop-in swap verification: includes `cpu_asset_loader.i` + `asset_source_msu1.i`
; (with ZERO embedded `.incbin` assets in `Test.sfc`!) and streams all `.bin`,
; `.tab`, `.pal`, and `.map` payloads out of `Test.msu` past the 64 KB boundary
; ($00012000+) into Game Pak RAM Bank `$71` + PPU CGRAM.
; ==============================================================================
.include "libSFX.i"
.include "../../gsu_iso/cpu_asset_loader.i"
.include "../../gsu_iso/asset_source_msu1.i"

.import GSU_Code
.import MSU_SNAP_P1, MSU_SNAP_P2, MSU_SNAP_P3

; Helper: Read PPU CGRAM color 2 into 16-bit C (assumes a8 on entry, leaves a16)
.macro READ_CGRAM_COLOR2
        RW_forced a8i16
        lda     #$02
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
        ; Phase 1: `sfx_msu1_detect` ("S-MSU1" @ $2002..$2007) + 32-bit Seek >64KB
        ; ======================================================================
        RW a8i16
        jsr     sfx_msu1_detect
        lda     #$00
        rol                             ; A = 1 if Carry Set (detected), 0 if absent
        pha                             ; save detect flag on stack

        SFX_LOAD_LEVEL MsuStudioLevelDef

        ; Capture DB & lock immediately after MSU-1 2-step DMA transfer
        RW a8i16
        phb
        pla
        xba
        lda     a:sfx_gsu_load_lock
        stz     GSU_SCMR
        RW a16
        sta     f:MSU_SNAP_P1 + 2       ; [1]: (DB << 8) | lock == $8000

        RW a8
        pla                             ; pop detect flag
        RW a16
        and     #$00FF
        sta     f:MSU_SNAP_P1 + 0       ; [0]: detect == 1

        lda     f:$718000               ; [2]: .tab magic at $71:8000 == $5453
        sta     f:MSU_SNAP_P1 + 4
        lda     f:$719014               ; [3]: .pal[2] at $71:9014 == $2247
        sta     f:MSU_SNAP_P1 + 6
        READ_CGRAM_COLOR2               ; [4]: PPU CGRAM[2] == $2247
        sta     f:MSU_SNAP_P1 + 8
        lda     a:sfx_atlas_load_count  ; [5]: loads == 1
        sta     f:MSU_SNAP_P1 + 10

        ; ======================================================================
        ; Phase 2: Resident `atlas_id = 0` Cache Hit + `SFX_LOAD_MAP` Stream
        ; ======================================================================
        lda     #$DEAD
        sta     f:$710000

        RW a8
        lda     #%00011101
        sta     GSU_SCMR

        SFX_LOAD_LEVEL MsuStudioLevelDef ; cache hit on atlas_id = 0!
        SFX_LOAD_MAP   MsuMap4x4Entry    ; hot-swap 4x4 map from $00016A00!

        RW a8
        stz     GSU_SCMR
        RW a16
        lda     a:sfx_atlas_load_count  ; [0]: still 1!
        sta     f:MSU_SNAP_P2 + 0
        lda     f:$710000               ; [1]: still $DEAD!
        sta     f:MSU_SNAP_P2 + 2
        lda     f:$718808               ; [2]: dims == $0404 (4x4)
        sta     f:MSU_SNAP_P2 + 4
        lda     f:$71880A               ; [3]: origin_x == 96
        sta     f:MSU_SNAP_P2 + 6
        lda     f:GSU_LOAD_MODE         ; [4]: SFX_LOAD_MODE_MAP (2)
        sta     f:MSU_SNAP_P2 + 8

        ; ======================================================================
        ; Phase 3: Switch to Second MSU-1 Atlas ($00016000), then Restore Studio
        ; ======================================================================
        RW a8
        lda     #%00011101
        sta     GSU_SCMR

        SFX_LOAD_LEVEL MsuSecondLevelDef ; cache miss -> atlas_id = 1 ($00016000)

        RW a8
        stz     GSU_SCMR
        RW a16
        lda     a:sfx_atlas_load_count  ; [0]: loads == 2
        sta     f:MSU_SNAP_P3 + 0
        lda     f:$710000               ; [1]: $0B0B from $00016000
        sta     f:MSU_SNAP_P3 + 2
        READ_CGRAM_COLOR2               ; [2]: CGRAM[2] == $5AD6
        sta     f:MSU_SNAP_P3 + 4

        RW a8
        lda     #%00011101
        sta     GSU_SCMR

        ; Reload Studio level (atlas_id = 0) from $00012000+ for GSU Case 4 render!
        SFX_LOAD_LEVEL MsuStudioLevelDef

        RW a8
        stz     GSU_SCMR
        RW a16
        lda     a:sfx_atlas_load_count  ; [3]: loads == 3
        sta     f:MSU_SNAP_P3 + 6
        READ_CGRAM_COLOR2               ; [4]: CGRAM[2] restored to $2247
        sta     f:MSU_SNAP_P3 + 8

        RW a8
        jml     __MAIN_LOOP_RUN__

; ------------------------------------------------------------------------------
; MSU-1 32-Bit Byte-Offset Asset Descriptors (`def_msu_asset`)
; ------------------------------------------------------------------------------
.segment "RODATA"
MsuStudioLevelDef:
        .word   $0000                           ; atlas_id = 0
        def_msu_asset $00012000, 8192           ; ROUNDTRIP_ATLAS.bin (> 64 KB!)
        def_msu_asset $00014000, 56             ; ROUNDTRIP_ATLAS.tab
        def_msu_asset $00014100, 32             ; ROUNDTRIP_ATLAS.pal
        def_msu_asset $00014200, 520            ; roundtrip_map.map

MsuSecondLevelDef:
        .word   $0001                           ; atlas_id = 1
        def_msu_asset $00016000, 2048           ; Atlas1 (.bin)
        def_msu_asset $00016800, 16             ; Tab1 (.tab)
        def_msu_asset $00016900, 32             ; Pal1 (.pal)
        def_msu_asset $00016A00, 136            ; Map1 (.map, 4x4)

MsuMap4x4Entry:
        def_msu_asset $00016A00, 136

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
