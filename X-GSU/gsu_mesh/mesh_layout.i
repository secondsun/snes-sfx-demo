; ==============================================================================
; mesh_layout.i - Bank-$71 Hybrid 3D Mesh Layout & Working GSURAM Buffers
;
; Shares Bank-$71 texture sheet ($71:0000), `.tab` ($71:8000), and `.pal` ($71:9010)
; with `gsu_iso`, and stages `.msh` hybrid vertex/face payloads at `$71:9030`:
;   - `$71:9030 .. $71:903F`: 16-byte `sfx_mesh_header`
;   - `$71:9040 ..`: `vertex_count * 6` bytes `(xQ106, yQ106, zQ106)` signed words
;   - `faces_offset`: `face_count * 20` bytes `mesh_face_entry` descriptors
; ==============================================================================

.ifndef __GSU_MESH_LAYOUT_DEFINED__
__GSU_MESH_LAYOUT_DEFINED__ = 1

.include "../IsoEngine/triangle/cached_trap.i"
.include "../IsoEngine/triangle/compile_face_traps_def.i"

BANK71_MESH_ADDR        = $9030     ; Starts at BANK71_FREE_ADDR ($71:9030)
SFX_MESH_MAGIC          = $4D53     ; Little-endian 'S','M' ($53, $4D)
SFX_MGRID_MAGIC         = $474D     ; Little-endian 'M','G' ($4D, $47) — companion tactical floor grid at $71:8808
SFX_MGRID_VOID_Y        = $8000     ; Sentinel floor Y indicating impassable/void cell

MESH_MAX_VERTS          = 640
MESH_MAX_FACES          = 640
MESH_OT_BUCKETS         = 256
MESH_MAX_HIGHLIGHTS     = 64
MESH_OT_HL_BASE         = MESH_MAX_FACES                        ; 640..703 = tactical highlights
MESH_OT_ENT_BASE        = (MESH_OT_HL_BASE + MESH_MAX_HIGHLIGHTS) ; 704..711 = entity sprite mask cutouts
MESH_OT_TOTAL_NODES     = (MESH_OT_ENT_BASE + 8)                ; 712 unified OT nodes

MESH_FACE_FLAG_QUAD     = $0100     ; Bit 8: 4-vertex quad (else 3-vertex tri)
MESH_FACE_FLAG_TEX      = $0200     ; Bit 9: Hero-textured via Bank-$71 sheet (else flat color [7:0])

; Companion tactical floor height grid staged at BANK71_MAP_ADDR ($71:8808)
; Copied into Bank-$70 `MAP_BUF` on `gsu_mesh_import_bank71` when magic == SFX_MGRID_MAGIC.
; Followed immediately by `cols * rows` signed Q10.6 floor Y words (`$8000` = void).
.struct sfx_mesh_grid_header
    magic               .word       ; +0:  SFX_MGRID_MAGIC ($474D)
    cols                .byte       ; +2:  Grid width (4..16)
    rows                .byte       ; +3:  Grid depth (4..16)
    origin_x_q106       .word       ; +4:  World X Q10.6 of cell (0,0) corner (signed)
    origin_z_q106       .word       ; +6:  World Z Q10.6 of cell (0,0) corner (signed)
    cell_step_q106      .word       ; +8:  Cell world width/depth in Q10.6 (default 2048 = 32px)
    hl_palette_packed   .word       ; +10: 0 = defaults (12/13/14), else (cur<<8)|(atk<<4)|move
.endstruct

.struct sfx_mesh_header
    magic               .word       ; +0:  SFX_MESH_MAGIC ($4D53)
    vertex_count        .word       ; +2:  1..640
    face_count          .word       ; +4:  1..640
    default_yaw         .word       ; +6:  Initial yaw index (0..119)
    default_center_y    .word       ; +8:  Initial camera center_y (typically 80)
    verts_offset        .word       ; +10: Bank-$71 offset of vertex table ($9040)
    faces_offset        .word       ; +12: Bank-$71 offset of face table
    reserved            .word       ; +14: 0
.endstruct

.struct mesh_face_entry
    flags_color         .word       ; +0:  [9]=TEX, [8]=QUAD, [7:0]=flat palette slot (1..15)
    v0_off              .word       ; +2:  vertex_idx[0] * 4 (byte offset into MESH_PROJ_VERTS)
    v1_off              .word       ; +4:  vertex_idx[1] * 4
    v2_off              .word       ; +6:  vertex_idx[2] * 4
    v3_off              .word       ; +8:  vertex_idx[3] * 4 (same as v2_off for tris)
    uv0                 .word       ; +10: (v << 8) | u inside 256x128 sheet
    uv1                 .word       ; +12: (v << 8) | u
    uv2                 .word       ; +14: (v << 8) | u
    uv3                 .word       ; +16: (v << 8) | u
    reserved            .word       ; +18: 0
.endstruct

; Compact 12-byte scanline trapezoid for flat-shaded polygons
.struct flat_trap
    dy_start            .word       ; +0: Screen Y offset from anchor_y (signed)
    line_count          .word       ; +2: Scanline count (>= 1)
    xL_start            .word       ; +4: Initial left edge X in Q8.8 (signed)
    xR_start            .word       ; +6: Initial right edge X in Q8.8 (signed)
    dxL_dy              .word       ; +8: Left edge slope dxL/dy in Q8.8 (signed)
    dxR_dy              .word       ; +10: Right edge slope dxR/dy in Q8.8 (signed)
.endstruct

.segment "GSURAM"
.align 2
GSU_SCENE_MODE:         .res 2      ; 0 = gsu_iso MapGrid, 1 = gsu_mesh 3D hybrid mesh
.export GSU_SCENE_MODE

MESH_HDR_CACHE:         .tag sfx_mesh_header
.export MESH_HDR_CACHE
MESH_PROJ_VERTS:        .res (MESH_MAX_VERTS * 4)   ; Packed (sx.w, sy.w) per vertex
.export MESH_PROJ_VERTS
MESH_VERT_DEPTH:        .res (MESH_MAX_VERTS * 2)   ; Signed integer depth per vertex
.export MESH_VERT_DEPTH
MESH_OT_HEADS:          .res (MESH_OT_BUCKETS * 2)  ; 256-bucket OT head indices ($FFFF = empty)
.export MESH_OT_HEADS
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
MESH_OT_NEXT:           .res (MESH_OT_TOTAL_NODES * 2) ; Next node index per OT node ($FFFF = end)
.else
MESH_OT_NEXT:           .res (MESH_MAX_FACES * 2)      ; Next face index per OT node ($FFFF = end)
.endif
.export MESH_OT_NEXT
MESH_FACE_HALFMASK:     .res MESH_MAX_FACES            ; Bit 0 = overlaps Pass 0, Bit 1 = overlaps Pass 1
.export MESH_FACE_HALFMASK

MESH_HAS_GRID:          .res 2      ; Non-zero when companion sfx_mesh_grid loaded into MAP_BUF
.export MESH_HAS_GRID
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
MESH_ACTIVE_DESC_PTR:   .res 2      ; Active gsu_scene_descriptor pointer in Bank $70
MESH_HL_COLOR_MOVE:     .res 2      ; BG1 palette slot for Move cell highlight
MESH_HL_COLOR_ATTACK:   .res 2      ; BG1 palette slot for Attack cell highlight
MESH_HL_COLOR_CURSOR:   .res 2      ; BG1 palette slot for Cursor cell highlight
.export MESH_ACTIVE_DESC_PTR, MESH_HL_COLOR_MOVE, MESH_HL_COLOR_ATTACK, MESH_HL_COLOR_CURSOR
MESH_ENT_SX:            .res (8 * 2)                  ; Projected top-left X per entity slot
MESH_ENT_SY:            .res (8 * 2)                  ; Projected top-left Y per entity slot
MESH_ENT_SLOT_PTR:      .res (8 * 2)                  ; Pointer to desc->entities[slot]
MESH_HL_POOL:           .res (MESH_MAX_HIGHLIGHTS * 6) ; Active highlight entries: (cx.w, cy.w, color.w)
MESH_HL_COUNT:          .res 2      ; Active highlight count this frame (0..64)
MESH_HL_TRAPS:          .res (4 * .sizeof(flat_trap)) ; Pre-compiled flat cell diamond traps (rel 0,0)
MESH_HL_TRAP_COUNT:     .res 2      ; Number of compiled highlight traps (0..4)
MESH_HL_HALF_SPAN_X:    .res 2      ; |Hx_x| + |Hz_x| + 2 for half-screen highlight culling
MESH_PROJ_OUT_SX:       .res 2      ; Scratch output from _gsu_mesh_project_pt
MESH_PROJ_OUT_SY:       .res 2      ; Scratch output from _gsu_mesh_project_pt
MESH_PROJ_OUT_BUCKET:   .res 2      ; Scratch output from _gsu_mesh_project_pt (0..255)
MESH_INS_COLS:          .res 2
MESH_INS_ROWS:          .res 2
MESH_INS_OX:            .res 2
MESH_INS_OZ:            .res 2
MESH_INS_STEP:          .res 2
MESH_INS_HALF_STEP:     .res 2
MESH_INS_IDX:           .res 2
MESH_INS_COL:           .res 2
MESH_INS_ROW:           .res 2
MESH_INS_CNT:           .res 2
MESH_INS_PTR:           .res 2
MESH_INS_HL_PTR:        .res 2
MESH_INS_GRID_PTR:      .res 2
.endif

MESH_TMP_FLAT_TRAPS:    .res (4 * .sizeof(flat_trap))
MESH_TMP_TEX_TRAPS:     .res (4 * .sizeof(cached_trap))
MESH_TMP_FACEDEF:       .res .sizeof(face_def)
MESH_TRI_PTS:           .res 12     ; 6 words: x0, y0, x1, y1, x2, y2
MESH_CUR_FRAME_HALF:    .res 2
MESH_FACE_FLAGS:        .res 2
MESH_FACE_X0:           .res 2
MESH_FACE_Y0:           .res 2
MESH_FACE_X1:           .res 2
MESH_FACE_Y1:           .res 2
MESH_FACE_X2:           .res 2
MESH_FACE_Y2:           .res 2
MESH_FACE_X3:           .res 2
MESH_FACE_Y3:           .res 2
MESH_FACE_BASE_X:       .res 2
MESH_FACE_BASE_Y:       .res 2
MESH_FACE_UV0:          .res 2
MESH_FACE_UV1:          .res 2
MESH_FACE_UV2:          .res 2
MESH_FACE_UV3:          .res 2
MESH_CUR_FACE_IDX:      .res 2
MESH_CUR_FACE_PTR:      .res 2
MESH_CUR_BUCKET:        .res 2
MESH_CUR_NEXT_FACE:     .res 2
MESH_CUR_COLOR:         .res 2
MESH_TRAP_PTR:          .res 2
MESH_TRAP_REM:          .res 2
MESH_U0_Q88:            .res 2
MESH_V0_Q88:            .res 2
MESH_BLD_VERT_REM:      .res 2
MESH_BLD_FACE_REM:      .res 2

.endif ; __GSU_MESH_LAYOUT_DEFINED__
