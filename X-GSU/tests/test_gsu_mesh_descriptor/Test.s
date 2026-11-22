; ==============================================================================
; TEST_GSU_MESH_DESCRIPTOR - SNES 65816 Host Harness
; Stages a synthetic 2x2 floor + occluding wall `.msh` (`$71:9030`), companion
; `sfx_mesh_grid` (`$71:8808`), and 1-bit Sprite Mask (Bank $04) to verify
; `gsu_mesh_render_from_descriptor` in 192x160 viewport mode.
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

        ; Stage sheet, .tab, .pal, and companion sfx_mesh_grid (into $71:8808)
        SFX_LOAD_LEVEL TestMeshDescLevelDef

        ; Stage .msh payload at $71:9030 and set GSU_SCENE_MODE = 1
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
TestMeshDescLevelDef:
        .word   $0000
        def_rom_asset TestSheetBin, (TestSheetBinEnd - TestSheetBin)
        def_rom_asset TestSheetTab, (TestSheetTabEnd - TestSheetTab)
        def_rom_asset TestSheetPal, (TestSheetPalEnd - TestSheetPal)
        def_rom_asset TestMeshGrid, (TestMeshGridEnd - TestMeshGrid)

; Solid 16x24 1-bit Sprite Mask in Bank $04 (`GSUDATA`, readable via ROMB=$04)
.segment "GSUDATA"
TestSolidMask16x24:
.export TestSolidMask16x24
        .res 48, $FF
TestSolidMask16x24End:

.segment "ROM5"
TestSheetBin:
        .res 512, $05
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
        .word   $0001, $0001, $0001, $0001, $7C00, $001F, $03FF, $7FFF
TestSheetPalEnd:

; Companion 2x2 sfx_mesh_grid (`$71:8808`):
;   cols=2, rows=2, origin_x=-16*64, origin_z=0, step=32*64 (2048)
;   Cell centers at yaw=0 (center_x=96, center_y=80):
;     (0,0): x=0,  z=16, y=0 -> floor_cx=96,  floor_cy=88, bucket=128+3=131
;     (1,0): x=32, z=16, y=0 -> floor_cx=128, floor_cy=88, bucket=128+3=131
;     (0,1): x=0,  z=48, y=0 -> floor_cx=96,  floor_cy=104, bucket=128+10=138
;     (1,1): x=32, z=48, y=0 -> floor_cx=128, floor_cy=104, bucket=128+10=138
TestMeshGrid:
        .word   $474D                   ; +0: SFX_MGRID_MAGIC ('M','G')
        .byte   2, 2                    ; +2: cols=2, rows=2
        .word   .loword(-16 * 64)       ; +4: origin_x_q106 (-1024)
        .word   0                       ; +6: origin_z_q106 (0)
        .word   32 * 64                 ; +8: cell_step_q106 (2048)
        .word   0                       ; +10: reserved
        .word   0, 0, 0, 0              ; +12: 4 cell floor heights y=0
TestMeshGridEnd:

; Synthetic 3-face .msh (12 vertices, 3 faces):
;   Face 0: Floor Quad covering both cells (0,1) and (1,1) + (0,0) and (1,0), color=2
;           x=-24..+56, y=0, z=0..72 -> sx=72..152, sy=80..116, avg bucket ~ 135 (Wait: make floor at y=0, z=0..64 -> depth avg=7 -> bucket 135; split per-row!)
;   Better: 2 floor quads (row 0 z=0..32 -> avg depth 3 -> bucket 131; row 1 z=32..64 -> avg depth 10 -> bucket 138),
;           1 tall nearer wall quad in front of cell (0,0) at z=32, y=0..48 -> depth avg = 13 -> bucket 141 (> entity(0,0) bucket 133!), color=3
;           1 wide right-clip quad at x=80..120 (sx=176..216 in 192px viewport!), y=0, z=0..32, color=5
TestMeshBin:
        .word   $4D53                   ; +0:  magic ('S','M')
        .word   16                      ; +2:  vertex_count
        .word   4                       ; +4:  face_count
        .word   0                       ; +6:  default_yaw = 0
        .word   80                      ; +8:  default_center_y = 80
        .word   BANK71_MESH_ADDR + 16   ; +10: verts_offset
        .word   BANK71_MESH_ADDR + 16 + (16 * 6) ; +12: faces_offset
        .word   0                       ; +14: reserved

        ; 0..3: Row-0 Floor (x=-16..+48, y=0, z=0..32) -> sx=80..144, sy=80..96, bucket=131
        .word   .loword(-16 * 64), 0, 0
        .word   .loword( 48 * 64), 0, 0
        .word   .loword( 48 * 64), 0, 32 * 64
        .word   .loword(-16 * 64), 0, 32 * 64

        ; 4..7: Row-1 Floor (x=-16..+48, y=0, z=32..64) -> sx=80..144, sy=96..112, bucket=138
        .word   .loword(-16 * 64), 0, 32 * 64
        .word   .loword( 48 * 64), 0, 32 * 64
        .word   .loword( 48 * 64), 0, 64 * 64
        .word   .loword(-16 * 64), 0, 64 * 64

        ; 8..11: Nearer Occluding Wall in front of cell (0,0) (x=-12..+12, y=0..48, z=36)
        ;        At yaw=0, center_x=96, center_y=80:
        ;        top y=48 -> sy = 80 + 18 - 41 = 57; bottom y=0 -> sy = 98; sx = 84..108
        ;        depth(y=0,z=36)=+7, depth(y=48,z=36)=+13 -> avg bucket = 138 >> entity(0,0) bucket 133!
        .word   .loword(-12 * 64), 48 * 64, 36 * 64
        .word   .loword( 12 * 64), 48 * 64, 36 * 64
        .word   .loword( 12 * 64), 0,       36 * 64
        .word   .loword(-12 * 64), 0,       36 * 64

        ; 12..15: Right-Edge 192px Clip Test Quad (x=84..116, y=0, z=0..32) -> sx=180..212 (Pass 1 local 52..84)
        .word   .loword( 84 * 64), 0, 0
        .word   .loword(116 * 64), 0, 0
        .word   .loword(116 * 64), 0, 32 * 64
        .word   .loword( 84 * 64), 0, 32 * 64

        ; Faces (20B each):
        .word   $0102,  0*4,  1*4,  2*4,  3*4, 0, 0, 0, 0, 0    ; Face 0: Row-0 Floor (color 2)
        .word   $0102,  4*4,  5*4,  6*4,  7*4, 0, 0, 0, 0, 0    ; Face 1: Row-1 Floor (color 2)
        .word   $0103,  8*4,  9*4, 10*4, 11*4, 0, 0, 0, 0, 0    ; Face 2: Nearer Occluding Wall (color 3)
        .word   $0105, 12*4, 13*4, 14*4, 15*4, 0, 0, 0, 0, 0    ; Face 3: Right-Edge 192px Clip Quad (color 5)
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
        lda     #%10100000
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
