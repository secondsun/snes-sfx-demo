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

MESH_MAX_VERTS          = 640
MESH_MAX_FACES          = 640
MESH_OT_BUCKETS         = 256

MESH_FACE_FLAG_QUAD     = $0100     ; Bit 8: 4-vertex quad (else 3-vertex tri)
MESH_FACE_FLAG_TEX      = $0200     ; Bit 9: Hero-textured via Bank-$71 sheet (else flat color [7:0])

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
MESH_OT_NEXT:           .res (MESH_MAX_FACES * 2)   ; Next face index per OT node ($FFFF = end)
.export MESH_OT_NEXT

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
