; ==============================================================================
; TEST_GSU_MESH - SNES 65816 Host Harness
; Stages a synthetic 16x16 cutout hero texture sheet (`$71:0000`), 1-entry `.tab`
; (`$71:8000`), 16-color `.pal` (`$71:9010`), and 5-face `.msh` (`$71:9030`)
; into Game Pak RAM Bank $71 via `cpu_asset_loader.i` + `asset_source_rom.i`.
; ==============================================================================
.include "libSFX.i"
.include "../../gsu_iso/cpu_asset_loader.i"
.include "../../gsu_iso/asset_source_rom.i"

.import GSU_Code
.import GSU_SCENE_MODE

BANK71_MESH_ADDR = $9030

Main:
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
        memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__

        SFX_LOADER_INIT %00011101

        ; Stage sheet, .tab, .pal into $71 via TestMeshLevelDef
        SFX_LOAD_LEVEL TestMeshLevelDef

        ; Acquire GSU bus to stage .msh payload at $71:9030 and set GSU_SCENE_MODE = 1
        RW a8i16
        jsr     _sfx_acquire_gsu_bus
        RW a16
        lda     #.loword(TestMeshBin)
        sta     a:sfx_src_lo
        lda     #^TestMeshBin
        sta     a:sfx_src_hi
        lda     #(TestMeshBinEnd - TestMeshBin)
        sta     a:sfx_copy_size
        lda     #BANK71_MESH_ADDR
        sta     a:sfx_dst_addr
        jsr     sfx_asset_copy_to_bank71
        lda     #$0001
        sta     f:GSU_SCENE_MODE
        RW a8
        jsr     _sfx_release_gsu_bus

        jml     __MAIN_LOOP_RUN__

.segment "RODATA"
TestMeshLevelDef:
        .word   $0000
        def_rom_asset TestSheetBin, (TestSheetBinEnd - TestSheetBin)
        def_rom_asset TestSheetTab, (TestSheetTabEnd - TestSheetTab)
        def_rom_asset TestSheetPal, (TestSheetPalEnd - TestSheetPal)
        def_rom_asset TestDummyMap, (TestDummyMapEnd - TestDummyMap)

.segment "ROM5"
; 256x16 rows of 4bpp unpacked sheet (`u=0..15, v=0..15` cutout in top-left corner):
;   v=0..7:  u=0..7 -> 0 (transparent), u=8..15 -> 5 (hero top)
;   v=8..15: u=0..15 -> 6 (hero bottom)
TestSheetBin:
    .repeat 8
        .repeat 8
            .byte $00
        .endrep
        .repeat 8
            .byte $05
        .endrep
        .res 240, $00
    .endrep
    .repeat 8
        .repeat 16
            .byte $06
        .endrep
        .res 240, $00
    .endrep
TestSheetBinEnd:

TestSheetTab:
        .word   $5453           ; SFX_TAB_MAGIC ('S','T')
        .word   1               ; entry_count
        .word   256             ; atlas_width
        .word   8               ; stride_shift
        .word   $0000           ; atlas_offset
        .word   $00FF           ; u_mask
        .word   $7F00           ; v_mask_shifted
        .word   $7FFF           ; v_offset_mask
TestSheetTabEnd:

TestSheetPal:
        .word   $0000, $0001, $03E0, $7C00, $001F, $7FFF, $03FF, $4210
        .word   $0001, $0001, $0001, $0001, $0001, $0001, $0001, $0001
TestSheetPalEnd:

TestDummyMap:
        .byte   4, 4
        .word   0, 0, 0
TestDummyMapEnd:

; Synthetic 5-face .msh (19 vertices, 5 faces)
; Projection at yaw=0: sx = 128 + x, sy = 80 + z/2 - 0.866*hy, depth = 0.875*z + 0.5*hy
TestMeshBin:
        .word   $4D53                   ; +0:  magic ('S','M')
        .word   19                      ; +2:  vertex_count
        .word   5                       ; +4:  face_count
        .word   0                       ; +6:  default_yaw = 0
        .word   80                      ; +8:  default_center_y = 80
        .word   BANK71_MESH_ADDR + 16   ; +10: verts_offset ($9040)
        .word   BANK71_MESH_ADDR + 16 + (19 * 6) ; +12: faces_offset
        .word   0                       ; +14: reserved

        ; Vertices (Q10.6: px * 64):
        ; 0..3: Seam Quad (x=-12..+12, hy=0, z=0..32) -> (116,80)-(140,80)-(140,96)-(116,96), depth=+7
        .word   .loword(-12 * 64), 0, 0
        .word   .loword( 12 * 64), 0, 0
        .word   .loword( 12 * 64), 0, 32 * 64
        .word   .loword(-12 * 64), 0, 32 * 64
        ; 4..6: Near Flat Tri (x=-6..+6, hy=19, z=40..56) -> (122,84)-(134,84)-(128,92), depth=+12..+14
        .word   .loword(-6 * 64), 19 * 64, 40 * 64
        .word   .loword( 6 * 64), 19 * 64, 40 * 64
        .word   0,                19 * 64, 56 * 64
        ; 7..10: Back-facing CCW Quad (x=-8..+8, hy=0, z=8..24), wound CCW
        .word   .loword(-8 * 64), 0,  8 * 64
        .word   .loword(-8 * 64), 0, 24 * 64
        .word   .loword( 8 * 64), 0, 24 * 64
        .word   .loword( 8 * 64), 0,  8 * 64
        ; 11..14: Flat Backplate behind Hero (x=-10..+10, hy=-18, z=32..68) -> (118,112)-(138,112)-(138,130)-(118,130), depth=+4..+12
        .word   .loword(-10 * 64), .loword(-18 * 64), 32 * 64
        .word   .loword( 10 * 64), .loword(-18 * 64), 32 * 64
        .word   .loword( 10 * 64), .loword(-18 * 64), 68 * 64
        .word   .loword(-10 * 64), .loword(-18 * 64), 68 * 64
        ; 15..18: Hero Textured Quad (x=-8..+8, hy=0, z=64..96) -> (120,112)-(136,112)-(136,128)-(120,128), depth=+14..+21
        .word   .loword(-8 * 64), 0, 64 * 64
        .word   .loword( 8 * 64), 0, 64 * 64
        .word   .loword( 8 * 64), 0, 96 * 64
TestMeshV18_fix:
        .word   .loword(-8 * 64), 0, 96 * 64
TestMeshVertsEnd:

        ; Faces (20 bytes each):
        ; Face 0: Flat Seam Quad, color=2 ($0102)
        .word   $0102, 0*4, 1*4, 2*4, 3*4, 0, 0, 0, 0, 0
        ; Face 1: Near Flat Tri, color=3 ($0003)
        .word   $0003, 4*4, 5*4, 6*4, 6*4, 0, 0, 0, 0, 0
        ; Face 2: CCW Culled Quad, color=4 ($0104)
        .word   $0104, 7*4, 8*4, 9*4, 10*4, 0, 0, 0, 0, 0
        ; Face 3: Flat Backplate behind Hero, color=7 ($0107)
        .word   $0107, 11*4, 12*4, 13*4, 14*4, 0, 0, 0, 0, 0
        ; Face 4: Hero Textured Quad, color/flags=$0300 (QUAD|TEX), U=0..15, V=0..15
        .word   $0300, 15*4, 16*4, 17*4, 18*4, $0000, $000F, $0F0F, $0F00, 0
TestMeshBinEnd:

.segment "MAIN_LOOP"
        RW a8i16
        ldx     #$C000
        lda     #$00
:       sta     $700000, x
        inx
        cpx     #$E800
        bne     :-

        lda     #$70
        sta     GSU_PBR
        lda     #$30
        sta     GSU_SCBR        ; $70:C000 framebuffer
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
