; ==============================================================================
; IsoEngine Face Definitions, Structs & Working Frame Constants
; ==============================================================================
.ifndef ::__COMPILE_FACE_TRAPS_DEF_DEFINED__
::__COMPILE_FACE_TRAPS_DEF_DEFINED__ = 1

.include "libSFX.i"
.include "../../common/structs.i"
.include "cached_trap.i"

; ==============================================================================
; Face Definition Flags & Constants
; ==============================================================================
FACE_DEF_FLAG_TRI       = $0000     ; 3-vertex triangle
FACE_DEF_FLAG_QUAD      = $0001     ; 4-vertex coplanar quad
FACE_DEF_FLAG_PTRS      = $0002     ; Vertices supply pointers to vector2 (xPos, yPos)
                                    ; If clear, vertices supply integer coordinates directly

UV_MODE_HORIZONTAL      = 0         ; Mode 0: Flat horizontal surface (top cap)
UV_MODE_WALL_NS         = 1         ; Mode 1: Vertical North/South face (skirt/panel)
UV_MODE_WALL_EW         = 2         ; Mode 2: Vertical East/West face (skirt/panel)
UV_MODE_SLOPE           = 3         ; Mode 3: Sloped faces (wedges, ramps, roofs)

; Structure for vertex data inside face_def (8 bytes = 4 words per vertex)
.struct face_vertex
    x_or_ptr    .word   ; Screen X (signed pixel) OR pointer to vector2
    y_val       .word   ; Screen Y (signed pixel) [unused if FACE_DEF_FLAG_PTRS]
    u           .word   ; U texture coordinate in Q8.8
    v           .word   ; V texture coordinate in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)
.endstruct

; Complete Face Definition Structure (44 bytes = 22 words)
.struct face_def
    flags        .word   ; +0:  FACE_DEF_FLAG_*
    uv_mode      .word   ; +2:  UV_MODE_* (0 = horiz, 1..3 = vertical/slope)
    tex_id       .word   ; +4:  Texture ID into TEXTURE_TABLE
    stride_shift .word   ; +6:  ATLAS_STRIDE_SHIFT (e.g. 6 for 64-wide atlas)
    cos_yaw      .word   ; +8:  Camera cos_yaw in Q2.14 ($4000 = 1.0)
    sin_yaw      .word   ; +10: Camera sin_yaw in Q2.14 ($4000 = 1.0)
    v0           .tag face_vertex ; +12: Vertex 0
    v1           .tag face_vertex ; +20: Vertex 1
    v2           .tag face_vertex ; +28: Vertex 2
    v3           .tag face_vertex ; +36: Vertex 3 (used if flags & FACE_DEF_FLAG_QUAD)
.endstruct

; Stack-allocated compiler working frame (86 bytes = 43 words)
.struct compile_frame
    flags        .word ; +0
    uv_mode      .word ; +2
    tex_id       .word ; +4
    stride_shift .word ; +6
    cos_yaw      .word ; +8
    sin_yaw      .word ; +10
    du_dx        .word ; +12: Q8.8
    dv_dx        .word ; +14: Q(16-S).S
    curr_out_ptr .word ; +16: destination cached_trap pointer
    trap_count   .word ; +18: number of emitted trapezoids
    tri_index    .word ; +20: 0 = first triangle, 1 = second triangle

    ; Unpacked input vertices V0..V3:
    v0_x         .word ; +22
    v0_y         .word ; +24
    v0_u         .word ; +26
    v0_v         .word ; +28

    v1_x         .word ; +30
    v1_y         .word ; +32
    v1_u         .word ; +34
    v1_v         .word ; +36

    v2_x         .word ; +38
    v2_y         .word ; +40
    v2_u         .word ; +42
    v2_v         .word ; +44

    v3_x         .word ; +46
    v3_y         .word ; +48
    v3_u         .word ; +50
    v3_v         .word ; +52

    ; Current triangle vertices (sorted Y0 <= Y1 <= Y2):
    t0_x         .word ; +54
    t0_y         .word ; +56
    t0_u         .word ; +58
    t0_v         .word ; +60

    t1_x         .word ; +62
    t1_y         .word ; +64
    t1_u         .word ; +66
    t1_v         .word ; +68

    t2_x         .word ; +70
    t2_y         .word ; +72
    t2_u         .word ; +74
    t2_v         .word ; +76

    ; Split point M on long edge T0-T2 at scanline Y1:
    m_x          .word ; +78
    m_u          .word ; +80
    m_v          .word ; +82

    is_t1_left   .word ; +84: 1 if T1 is left of M, 0 if T1 is right of M

    ; Caller return flags:
    sort_ret_flag  .word ; +86: 0 = mode_123, 1 = process_triangle
    split_ret_flag .word ; +88: 0 = mode_123, 1 = process_triangle
    half_index     .word ; +90: 0 = top half, 1 = bottom half
.endstruct

.segment "GSURAM"
.align 2
gsu_compile_frame: .res .sizeof(compile_frame)

; Helper macro: puts address of (gsu_compile_frame + off) into dest register
.macro frame_ptr off, dest
    iwt dest, #gsu_compile_frame + off
.endmacro

.endif ; ::__COMPILE_FACE_TRAPS_DEF_DEFINED__
