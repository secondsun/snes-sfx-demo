; ==============================================================================
; IsoEngine Map Grid Format, Painter's Traversal & Dirty Archetype Renderer
; ==============================================================================
.ifndef ::__ISO_MAP_GRID_DEFINED__
::__ISO_MAP_GRID_DEFINED__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"
.include "../common/control.i"
.include "../common/structs.i"
.include "../common/var.i"
.include "../common/util.i"

.include "../gsu_maths/gsu_iso_camera.i"
.include "triangle/cached_trap.i"
.include "triangle/compile_face_traps_def.i"
.include "triangle/compile_face_traps.i"
.include "triangle/draw_cached_trap.i"

; ==============================================================================
; Binary Map Structures (ca65)
; ==============================================================================

.struct map_header
    cols            .byte   ; +0: Grid width in cells (4..12)
    rows            .byte   ; +1: Grid depth in cells (4..12)
    origin_x        .word   ; +2: Screen X anchor for cell (0,0,h=0) (signed 16-bit)
    origin_z        .word   ; +4: Screen Y anchor for cell (0,0,h=0) (signed 16-bit)
    reserved        .word   ; +6: Alignment padding ($0000)
.endstruct

.struct map_cell
    base_height     .byte   ; +0: Lowest opaque floor height (1h = 16 world units = 14px)
    archetype_id    .byte   ; +1: [7:6] rot (0..3), [5:0] shape archetype (0..63)
    top_tex_id      .byte   ; +2: Top/cap surface texture ID
    skirt_tex_id    .byte   ; +3: Skirt/cliff/riser/riverbed texture ID
    panel_tex_id    .byte   ; +4: Edge panel / foliage cutout texture ID
    panel_flags     .byte   ; +5: [3:0] W/S/E/N mask, [4] 2h tall flag, [7:5] reserved
    drop_ns         .byte   ; +6: Baked North/South skirt drop in 1h units
    drop_ew         .byte   ; +7: Baked East/West skirt drop in 1h units
.endstruct

; Helper authoring macro for map_cell
.macro def_cell h, arch, top_tex, skirt_tex, panel_tex, pflags, drop_ns, drop_ew
    .byte h, arch, top_tex, skirt_tex, panel_tex, pflags, drop_ns, drop_ew
.endmacro

; Archetype IDs (bits [5:0] of archetype_id)
PRIM_FLAT              = 0

.ifndef ATLAS_STRIDE_SHIFT
ATLAS_STRIDE_SHIFT     = 6
.endif
PRIM_WEDGE_STRAIGHT    = 1
PRIM_WEDGE_STRAIGHT_2H = 2
PRIM_WEDGE_OUTER       = 3
PRIM_WEDGE_OUTER_2H    = 4
PRIM_WEDGE_INNER       = 5
PRIM_WEDGE_INNER_2H    = 6
PRIM_STAIRS            = 7
PRIM_LIQUID_SHALLOW    = 8
PRIM_LIQUID_DEEP       = 9
PRIM_PILLAR            = 10
PRIM_FOLIAGE_CROSS     = 11

; Rotation encodings for archetype_id bits [7:6]
ROT_0               = (0 << 6)
ROT_90              = (1 << 6)
ROT_180             = (2 << 6)
ROT_270             = (3 << 6)

; Edge Panel flags for panel_flags
PANEL_NONE          = $00
PANEL_N             = (1 << 0)  ; North edge (j - 1 boundary)
PANEL_E             = (1 << 1)  ; East edge  (i + 1 boundary)
PANEL_S             = (1 << 2)  ; South edge (j + 1 boundary)
PANEL_W             = (1 << 3)  ; West edge  (i - 1 boundary)
PANEL_TALL_2H       = (1 << 4)  ; 0 = 1h (16-unit) parapet, 1 = 2h (32-unit) facade

; ==============================================================================
; Pre-Compiled Archetype Trapezoid Cache Table
; ==============================================================================
.struct arch_traps_table
    flat_count      .word   ; +0:   Number of cached_traps for PRIM_FLAT (0..4)
    flat_traps      .res 4 * .sizeof(cached_trap) ; +2: 104 bytes
    skirt_ns_count  .word   ; +106: Number of cached_traps for ARCH_SKIRT_NS (0..4)
    skirt_ns_traps  .res 4 * .sizeof(cached_trap) ; +108: 104 bytes
    skirt_ew_count  .word   ; +212: Number of cached_traps for ARCH_SKIRT_EW (0..4)
    skirt_ew_traps  .res 4 * .sizeof(cached_trap) ; +214: 104 bytes
    bbox_xmin       .word   ; +318: Min X offset relative to anchor across corners
    bbox_xmax       .word   ; +320: Max X offset relative to anchor across corners
    bbox_ymin       .word   ; +322: Min Y offset relative to anchor across corners
    bbox_ymax       .word   ; +324: Max Y offset relative to anchor across corners
    arch_lut        .res 64 * 2 ; +326: 128 bytes (offsets for (archetype << 2) | rot)
    arch_buf        .res 8192   ; +454: storage buffer for compiled cached_traps
.endstruct

; ==============================================================================
; Dedicated GSURAM State & Working Frames
; ==============================================================================
.struct map_render_frame
    map_ptr         .word ; +0
    cam_ptr         .word ; +2
    basis_ptr       .word ; +4
    arch_traps_ptr  .word ; +6
    frame_half      .word ; +8
    debug_order_ptr .word ; +10
    debug_count     .word ; +12

    cols            .word ; +14
    rows            .word ; +16
    origin_x        .word ; +18
    origin_z        .word ; +20

    j_start         .word ; +22
    j_step          .word ; +24
    j_count         .word ; +26
    j_cur           .word ; +28
    j_rem           .word ; +30

    i_start         .word ; +32
    i_step          .word ; +34
    i_count         .word ; +36
    i_cur           .word ; +38
    i_rem           .word ; +40

    anchor_x        .word ; +42
    anchor_y        .word ; +44

    base_height     .word ; +46
    archetype_id    .word ; +48
    top_tex_id      .word ; +50
    skirt_tex_id    .word ; +52
    drop_ns         .word ; +54
    drop_ew         .word ; +56

    u_offset        .word ; +58
    v_offset        .word ; +60
    step_y          .word ; +62

    compile_out_ptr .word ; +64: current output pointer in arch_buf
    arch_trap_count .word ; +66: trap count for current shape
    elev_midpoints  .res 32 ; +68..+99: 8 points (MN, ME, MS, MW at +1h and +2h, 4 bytes each)
    v_ptrs          .res 24 ; +100..+123: B0..B3, E1_0..E1_3, E2_0..E2_3 (12 words)
    m_ptrs          .res 16 ; +124..+139: MB_W, MB_E, M1_W, M1_E, M2_W, M2_E (8 words)
    cur_rot         .word ; +140: current rotation (0..3)
    panel_tex_id    .word ; +142: panel/foliage cutout texture ID
    k_bot           .res 4 ; +144: center bottom point (x, y)
    k_top           .res 4 ; +148: center top point (x, y)
    cur_entry_ptr   .word ; +152: entry pointer for current shape
.endstruct

.segment "GSURAM"
.align 2
gsu_map_render_frame:   .res .sizeof(map_render_frame)
gsu_map_face_def:       .res .sizeof(face_def)

.segment "GSUCODE"

; ==============================================================================
; map_compile_quad_face
; Compiles a quad face into cached_traps at compile_out_ptr (+64).
; In:
;   r1 = v0_ptr
;   r2 = v1_ptr
;   r3 = v2_ptr
;   r4 = v3_ptr
;   r5 = uv_mode
;   r6 = tex_id
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function map_compile_quad_face v0_p, v1_p, v2_p, v3_p, uv_m, tex_i
    register v0_p = r1, v1_p = r2, v2_p = r3, v3_p = r4, uv_m = r5, tex_i = r6

    iwt r7, #gsu_map_face_def
    iwt r0, #(FACE_DEF_FLAG_QUAD | FACE_DEF_FLAG_PTRS)
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    from uv_m
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    from tex_i
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    iwt r0, #ATLAS_STRIDE_SHIFT
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7

    ; Read cos_yaw and sin_yaw from cam_ptr (gsu_map_render_frame + 0)
    iwt r8, #gsu_map_render_frame
    ldw (r8)
    inc r0
    inc r0
    move r8, r0
    ldw (r8)            ; sin_yaw
    move r9, r0
    inc r8
    inc r8
    ldw (r8)            ; cos_yaw
    from r0
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r9
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0
    from v0_p
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    ; V1
    from v1_p
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    ; V2
    from v2_p
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v2
    inc r7
    inc r7

    ; V3
    from v3_p
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Call compile_face_traps:
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r2, r0         ; r2 = compile_out_ptr
    iwt r1, #gsu_map_face_def
    call compile_face_traps r1, r2

    ; If r3 == 0 (culled): return
    with r3
    add #0
    beq @quad_done
    nop

    ; Add r3 to arch_trap_count (+66)
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    with r0
    add r3
    from r0
    stw (r7)

    ; Advance compile_out_ptr by r3 * 26:
    ; 26 = (r3 << 4) + (r3 << 3) + (r3 << 1)
    move r1, r3
    with r1
    add r1              ; r3 * 2
    move r2, r1         ; * 2
    with r1
    add r1              ; * 4
    with r1
    add r1              ; * 8
    move r4, r1         ; * 8
    with r1
    add r1              ; * 16
    with r1
    add r4              ; * 24
    with r1
    add r2              ; * 26
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    with r0
    add r1
    from r0
    stw (r7)            ; compile_out_ptr += r3 * 26

@quad_done:
    return
endfunction

; ==============================================================================
; map_compile_tri_face
; Compiles a triangular face into cached_traps at compile_out_ptr (+64).
; In:
;   r1 = v0_ptr
;   r2 = v1_ptr
;   r3 = v2_ptr
;   r4 = uv_mode
;   r5 = tex_id
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function map_compile_tri_face v0_p, v1_p, v2_p, uv_m, tex_i
    register v0_p = r1, v1_p = r2, v2_p = r3, uv_m = r4, tex_i = r5

    iwt r7, #gsu_map_face_def
    iwt r0, #FACE_DEF_FLAG_PTRS
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    from uv_m
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    from tex_i
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    iwt r0, #ATLAS_STRIDE_SHIFT
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7
    ; Read cos_yaw and sin_yaw from cam_ptr (gsu_map_render_frame + 0)
    iwt r8, #gsu_map_render_frame
    ldw (r8)
    inc r0
    inc r0
    move r8, r0
    ldw (r8)            ; sin_yaw
    move r9, r0
    inc r8
    inc r8
    ldw (r8)            ; cos_yaw
    from r0
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r9
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0
    from v0_p
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    ; V1
    from v1_p
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    ; V2
    from v2_p
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; u2 = 0
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v2

    ; Call compile_face_traps:
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r2, r0         ; r2 = compile_out_ptr
    iwt r1, #gsu_map_face_def
    call compile_face_traps r1, r2

    ; If r3 == 0 (culled): return
    with r3
    add #0
    beq @tri_done
    nop

    ; Add r3 to arch_trap_count (+66)
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    with r0
    add r3
    from r0
    stw (r7)

    ; Advance compile_out_ptr by r3 * 26:
    move r1, r3
    with r1
    add r1              ; * 2
    move r2, r1
    with r1
    add r1              ; * 4
    with r1
    add r1              ; * 8
    move r4, r1         ; * 8
    with r1
    add r1              ; * 16
    with r1
    add r4              ; * 24
    with r1
    add r2              ; * 26
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    with r0
    add r1
    from r0
    stw (r7)            ; compile_out_ptr += r3 * 26

@tri_done:
    return
endfunction

; ==============================================================================
; Foliage Cutout Fin Helpers (PRIM_FOLIAGE_CROSS)
; Emits single 16x32 vertical fin with camera-facing winding & UV_MODE_WALL_*
; ==============================================================================
function compile_fin_n
    ; Read sin_yaw from cam_ptr (frame + 0) + 2
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @fin_n_west
    nop

    ; sin_yaw >= 0 (looking from East):
    ; V0 = K_top (+148), V1 = MN_top (+84), V2 = MN_bot (lat + 64), V3 = K_bot (+144)
    iwt r1, #gsu_map_render_frame + 148
    iwt r2, #gsu_map_render_frame + 84
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #64
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_map_render_frame + 144
    bra @fin_n_compile
    nop

@fin_n_west:
    ; sin_yaw < 0 (looking from West):
    ; V0 = MN_top (+84), V1 = K_top (+148), V2 = K_bot (+144), V3 = MN_bot (lat + 64)
    iwt r1, #gsu_map_render_frame + 84
    iwt r2, #gsu_map_render_frame + 148
    iwt r3, #gsu_map_render_frame + 144
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #64
    with r0
    add r6
    move r4, r0

@fin_n_compile:
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #2          ; panel_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6
    return
endfunction

function compile_fin_s
    ; Read sin_yaw from cam_ptr (frame + 0) + 2
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @fin_s_west
    nop

    ; sin_yaw >= 0 (looking from East):
    ; V0 = MS_top (+92), V1 = K_top (+148), V2 = K_bot (+144), V3 = MS_bot (lat + 72)
    iwt r1, #gsu_map_render_frame + 92
    iwt r2, #gsu_map_render_frame + 148
    iwt r3, #gsu_map_render_frame + 144
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #72
    with r0
    add r6
    move r4, r0
    bra @fin_s_compile
    nop

@fin_s_west:
    ; sin_yaw < 0 (looking from West):
    ; V0 = K_top (+148), V1 = MS_top (+92), V2 = MS_bot (lat + 72), V3 = K_bot (+144)
    iwt r1, #gsu_map_render_frame + 148
    iwt r2, #gsu_map_render_frame + 92
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #72
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_map_render_frame + 144

@fin_s_compile:
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #2          ; panel_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6
    return
endfunction

function compile_fin_e
    ; Read cos_yaw from cam_ptr (frame + 0) + 4
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @fin_e_north
    nop

    ; cos_yaw >= 0 (looking from South):
    ; V0 = K_top (+148), V1 = ME_top (+88), V2 = ME_bot (lat + 68), V3 = K_bot (+144)
    iwt r1, #gsu_map_render_frame + 148
    iwt r2, #gsu_map_render_frame + 88
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #68
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_map_render_frame + 144
    bra @fin_e_compile
    nop

@fin_e_north:
    ; cos_yaw < 0 (looking from North):
    ; V0 = ME_top (+88), V1 = K_top (+148), V2 = K_bot (+144), V3 = ME_bot (lat + 68)
    iwt r1, #gsu_map_render_frame + 88
    iwt r2, #gsu_map_render_frame + 148
    iwt r3, #gsu_map_render_frame + 144
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #68
    with r0
    add r6
    move r4, r0

@fin_e_compile:
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #2          ; panel_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6
    return
endfunction

function compile_fin_w
    ; Read cos_yaw from cam_ptr (frame + 0) + 4
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @fin_w_north
    nop

    ; cos_yaw >= 0 (looking from South):
    ; V0 = MW_top (+96), V1 = K_top (+148), V2 = K_bot (+144), V3 = MW_bot (lat + 76)
    iwt r1, #gsu_map_render_frame + 96
    iwt r2, #gsu_map_render_frame + 148
    iwt r3, #gsu_map_render_frame + 144
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #76
    with r0
    add r6
    move r4, r0
    bra @fin_w_compile
    nop

@fin_w_north:
    ; cos_yaw < 0 (looking from North):
    ; V0 = K_top (+148), V1 = MW_top (+96), V2 = MW_bot (lat + 76), V3 = K_bot (+144)
    iwt r1, #gsu_map_render_frame + 148
    iwt r2, #gsu_map_render_frame + 96
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #76
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_map_render_frame + 144

@fin_w_compile:
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #2          ; panel_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6
    return
endfunction

; ==============================================================================
; map_grid_compile_archetypes
; Compares cam_ptr->yaw with cached_yaw_ptr.
; When unchanged: returns 0 immediately (zero compilation cycles).
; When changed:
;   - Updates cached_yaw_ptr
;   - Updates basis_ptr (Sx, Sz, Sy)
;   - Populates lattice_ptr (LATTICE_V2)
;   - Computes archetype screen bounding box relative to anchor
;   - Compiles PRIM_FLAT, ARCH_SKIRT_NS, and ARCH_SKIRT_EW into arch_traps_ptr
;   - Returns 1 (dirty recompiled)
; ==============================================================================
function map_grid_compile_archetypes cam_ptr, basis_ptr, lattice_ptr, arch_traps_ptr, cached_yaw_ptr : recompiled_flag
    register cam_ptr = r1, basis_ptr = r2, lattice_ptr = r3, arch_traps_ptr = r4, cached_yaw_ptr = r5

    ; 1. Load current yaw from cam_ptr (+0)
    ldw (r1)            ; r0 = cur_yaw
    move r6, r0         ; r6 = cur_yaw

    ; 2. Compare against cached_yaw
    ldw (r5)            ; r0 = cached_yaw
    from r6
    sub r0
    bne @do_recompile
    nop

    ; Not dirty: zero compilation cycles!
    iwt r3, #0
    return

@do_recompile:
    ; Update cached_yaw
    from r6
    stw (r5)

    ; Save inputs in frame
    iwt r7, #gsu_map_render_frame
    from r1
    stw (r7)            ; frame.map_ptr (reused for cam_ptr)
    inc r7
    inc r7
    from r2
    stw (r7)            ; basis_ptr
    inc r7
    inc r7
    from r3
    stw (r7)            ; lattice_ptr
    inc r7
    inc r7
    from r4
    stw (r7)            ; arch_traps_ptr

    ; Compute basis vectors (Sx, Sz, Sy) into basis_ptr
    call iso_compute_basis r6, r2

    ; Populate 28-point canonical lattice into lattice_ptr
    iwt r7, #gsu_map_render_frame
    inc r7
    inc r7
    ldw (r7)            ; r2 = basis_ptr
    move r1, r0
    inc r7
    inc r7
    ldw (r7)            ; r3 = lattice_ptr
    move r2, r0
    call iso_populate_lattice r1, r2

    ; --------------------------------------------------------------------------
    ; 3. Compute Archetype Screen Bounding Box:
    ;    Corners relative to anchor:
    ;      C0 = (0, 0)
    ;      C1 = Sx
    ;      C2 = Sx + Sz
    ;      C3 = Sz
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame
    inc r7
    inc r7
    ldw (r7)            ; r0 = basis_ptr
    move r7, r0

    to r8
    ldw (r7)            ; r8 = Sx.x
    inc r7
    inc r7
    to r9
    ldw (r7)            ; r9 = Sx.y
    inc r7
    inc r7
    to r11
    ldw (r7)            ; r11 = Sz.x
    inc r7
    inc r7
    to r12
    ldw (r7)            ; r12 = Sz.y

    ; C2.x = Sx.x + Sz.x, C2.y = Sx.y + Sz.y
    move r14, r8
    with r14
    add r11             ; r14 = C2.x
    move r6, r9
    with r6
    add r12             ; r6 = C2.y

    ; 1. min_x = min(0, Sx.x, Sz.x, C2.x)
    iwt r1, #0
    from r8
    sub r1
    bge :+
    nop
    move r1, r8
:
    from r11
    sub r1
    bge :+
    nop
    move r1, r11
:
    from r14
    sub r1
    bge :+
    nop
    move r1, r14
:

    ; 2. max_x = max(0, Sx.x, Sz.x, C2.x)
    iwt r2, #0
    from r8
    sub r2
    blt :+
    nop
    move r2, r8
:
    from r11
    sub r2
    blt :+
    nop
    move r2, r11
:
    from r14
    sub r2
    blt :+
    nop
    move r2, r14
:

    ; 3. min_y = min(0, Sx.y, Sz.y, C2.y)
    iwt r3, #0
    from r9
    sub r3
    bge :+
    nop
    move r3, r9
:
    from r12
    sub r3
    bge :+
    nop
    move r3, r12
:
    from r6
    sub r3
    bge :+
    nop
    move r3, r6
:

    ; 4. max_y = max(0, Sx.y, Sz.y, C2.y)
    iwt r4, #0
    from r9
    sub r4
    blt :+
    nop
    move r4, r9
:
    from r12
    sub r4
    blt :+
    nop
    move r4, r12
:
    from r6
    sub r4
    blt :+
    nop
    move r4, r6
:

    ; Store all 4 bounding box offsets into arch_traps_ptr + bbox_xmin
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r5, #arch_traps_table::bbox_xmin
    with r0
    add r5
    move r7, r0
    from r1
    stw (r7)            ; bbox_xmin
    inc r7
    inc r7
    from r2
    stw (r7)            ; bbox_xmax
    inc r7
    inc r7
    iwt r0, #28
    with r3
    sub r0
    from r3
    stw (r7)            ; bbox_ymin (includes up to 2h elevation headroom)
    inc r7
    inc r7
    from r4
    stw (r7)            ; bbox_ymax

    ; --------------------------------------------------------------------------
    ; 4. Compile PRIM_FLAT (Horizontal 32x32 quad at y=0)
    ;    Vertices: C0, C1, C2, C3 (Clockwise)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame
    ldw (r7)            ; r0 = cam_ptr
    inc r0
    inc r0
    move r8, r0
    to r11
    ldw (r8)            ; r11 = sin_yaw
    inc r8
    inc r8
    to r12
    ldw (r8)            ; r12 = cos_yaw

    iwt r7, #gsu_map_render_frame + 4
    to r14
    ldw (r7)            ; r14 = lattice_ptr

    iwt r7, #gsu_map_face_def

    iwt r0, #(FACE_DEF_FLAG_QUAD | FACE_DEF_FLAG_PTRS)
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    iwt r0, #UV_MODE_HORIZONTAL
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    iwt r0, #ATLAS_STRIDE_SHIFT
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7
    from r12
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r11
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0: pointer to LATTICE_C0 (lattice_ptr + 0), u=0, v=0
    from r14
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    ; V1: pointer to LATTICE_C1 (lattice_ptr + 4), u=32<<8, v=0
    move r0, r14
    iwt r6, #4
    with r0
    add r6
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    ; V2: pointer to LATTICE_C2 (lattice_ptr + 8), u=32<<8, v=32<<6 ($0800)
    move r0, r14
    iwt r6, #8
    with r0
    add r6
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v2
    inc r7
    inc r7

    ; V3: pointer to LATTICE_C3 (lattice_ptr + 12), u=0, v=32<<6 ($0800)
    move r0, r14
    iwt r6, #12
    with r0
    add r6
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Compile PRIM_FLAT into arch_traps_ptr + flat_traps (+2)
    iwt r1, #gsu_map_face_def
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    inc r0
    inc r0
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    move r7, r0
    from r3
    stw (r7)            ; store flat_count (+0)

    ; --------------------------------------------------------------------------
    ; 5. Compile ARCH_SKIRT_NS (Vertical 1h Skirt)
    ;    uv_mode = UV_MODE_WALL_NS (1)
    ;    If cos_yaw >= 0: South face (C3 -> C2 -> SKIRT_C2 -> SKIRT_C3)
    ;    If cos_yaw < 0:  North face (C1 -> C0 -> SKIRT_C0 -> SKIRT_C1)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_face_def
    inc r7
    inc r7
    iwt r0, #UV_MODE_WALL_NS
    stw (r7)            ; uv_mode (+2)

    with r12
    add #0
    blt @skirt_north
    nop

    ; South Face: V0=C3(12), V1=C2(8), V2=SKIRT_C2(24), V3=SKIRT_C3(28)
    move r1, r14
    iwt r6, #12
    with r1
    add r6              ; C3
    move r2, r14
    iwt r6, #8
    with r2
    add r6              ; C2
    move r4, r14
    iwt r6, #24
    with r4
    add r6              ; SKIRT_C2
    move r5, r14
    iwt r6, #28
    with r5
    add r6              ; SKIRT_C3
    bra @skirt_ns_setup
    nop

@skirt_north:
    ; North Face: V0=C1(4), V1=C0(0), V2=SKIRT_C0(16), V3=SKIRT_C1(20)
    move r1, r14
    iwt r6, #4
    with r1
    add r6              ; C1
    move r2, r14        ; C0
    move r4, r14
    iwt r6, #16
    with r4
    add r6              ; SKIRT_C0
    move r5, r14
    iwt r6, #20
    with r5
    add r6              ; SKIRT_C1

@skirt_ns_setup:
    iwt r7, #gsu_map_face_def + 12 ; ptr -> v0
    from r1
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    from r2
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    from r4
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT) ; 1h = 16 texels
    stw (r7)            ; v2
    inc r7
    inc r7

    from r5
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Compile ARCH_SKIRT_NS into arch_traps_ptr + skirt_ns_traps (+108)
    iwt r1, #gsu_map_face_def
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r11, #108
    with r0
    add r11
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r11, #106
    with r0
    add r11
    move r7, r0
    from r3
    stw (r7)            ; store skirt_ns_count (+106)

    ; --------------------------------------------------------------------------
    ; 6. Compile ARCH_SKIRT_EW (Vertical 1h Skirt)
    ;    uv_mode = UV_MODE_WALL_EW (2)
    ;    If sin_yaw >= 0: East face (C2 -> C1 -> SKIRT_C1 -> SKIRT_C2)
    ;    If sin_yaw < 0:  West face (C0 -> C3 -> SKIRT_C3 -> SKIRT_C0)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_face_def
    inc r7
    inc r7
    iwt r0, #UV_MODE_WALL_EW
    stw (r7)            ; uv_mode (+2)

    with r11
    add #0
    blt @skirt_west
    nop

    ; East Face: V0=C2(8), V1=C1(4), V2=SKIRT_C1(20), V3=SKIRT_C2(24)
    move r1, r14
    iwt r6, #8
    with r1
    add r6              ; C2
    move r2, r14
    iwt r6, #4
    with r2
    add r6              ; C1
    move r4, r14
    iwt r6, #20
    with r4
    add r6              ; SKIRT_C1
    move r5, r14
    iwt r6, #24
    with r5
    add r6              ; SKIRT_C2
    bra @skirt_ew_setup
    nop

@skirt_west:
    ; West Face: V0=C0(0), V1=C3(12), V2=SKIRT_C3(28), V3=SKIRT_C0(16)
    move r1, r14        ; C0
    move r2, r14
    iwt r6, #12
    with r2
    add r6              ; C3
    move r4, r14
    iwt r6, #28
    with r4
    add r6              ; SKIRT_C3
    move r5, r14
    iwt r6, #16
    with r5
    add r6              ; SKIRT_C0

@skirt_ew_setup:
    iwt r7, #gsu_map_face_def + 12 ; ptr -> v0
    from r1
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    from r2
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    from r4
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v2
    inc r7
    inc r7

    from r5
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Compile ARCH_SKIRT_EW into arch_traps_ptr + skirt_ew_traps (+214)
    iwt r1, #gsu_map_face_def
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r11, #214
    with r0
    add r11
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r11, #212
    with r0
    add r11
    move r7, r0
    from r3
    stw (r7)            ; store skirt_ew_count (+212)

    ; --------------------------------------------------------------------------
    ; 7. Initialize Dynamic Archetype Lookup Table (arch_lut at +326):
    ; --------------------------------------------------------------------------
    ; Offset 0..3: PRIM_FLAT (all rotations point to flat_count at offset 0)
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r1, #326
    with r0
    add r1
    move r7, r0         ; r7 = &arch_lut[0]
    iwt r0, #0
    stw (r7)            ; lut[0] = 0 (PRIM_FLAT rot 0)
    inc r7
    inc r7
    stw (r7)            ; lut[1] = 0 (rot 1)
    inc r7
    inc r7
    stw (r7)            ; lut[2] = 0 (rot 2)
    inc r7
    inc r7
    stw (r7)            ; lut[3] = 0 (rot 3)
    inc r7
    inc r7

    ; Initialize remaining 60 entries (4..63) to 0 (default: 0 traps)
    iwt r12, #60
@init_lut_loop:
    iwt r0, #0
    stw (r7)
    inc r7
    inc r7
    dec r12
    bne @init_lut_loop
    nop

    ; Initialize compile_out_ptr (+64) = arch_traps_ptr + arch_traps_table::arch_buf
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r1, #arch_traps_table::arch_buf
    with r0
    add r1
    move r1, r0
    iwt r7, #gsu_map_render_frame + 64
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; 8. Precompute Elevated Midpoints at +1h and +2h in frame (+68):
    ;    MN (64), ME (68), MS (72), MW (76) in lattice_ptr (frame + 4)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r11, r0        ; r11 = lattice_ptr
    iwt r0, #64
    with r11
    add r0              ; r11 = &lattice_ptr[16] (MN)

    iwt r12, #0         ; k = 0..3
@elev_mid_loop:
    ; Read M_k.x
    ldw (r11)
    move r1, r0         ; r1 = x
    inc r11
    inc r11
    ; Read M_k.y
    ldw (r11)
    move r2, r0         ; r2 = y
    inc r11
    inc r11

    ; k * 4:
    move r3, r12
    with r3
    add r3
    with r3
    add r3              ; r3 = k * 4

    ; Store M_k at +1h (x, y - 14) in frame + 68 + k * 4:
    iwt r7, #gsu_map_render_frame + 68
    with r7
    add r3
    from r1
    stw (r7)            ; x
    inc r7
    inc r7
    move r0, r2
    iwt r6, #14
    with r0
    sub r6              ; y - 14
    from r0
    stw (r7)            ; y - 14

    ; Store M_k at +2h (x, y - 28) in frame + 84 + k * 4:
    iwt r7, #gsu_map_render_frame + 84
    with r7
    add r3
    from r1
    stw (r7)            ; x
    inc r7
    inc r7
    move r0, r2
    iwt r6, #28
    with r0
    sub r6              ; y - 28
    from r0
    stw (r7)            ; y - 28

    inc r12
    iwt r0, #4
    from r12
    sub r0
    blt @elev_mid_loop
    nop

    ; --------------------------------------------------------------------------
    ; 9. Compile Wedge & Stair Archetypes across Rotations R = 0..3:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + 140
    iwt r0, #0
    from r0
    stw (r7)            ; frame::cur_rot = 0

@rot_compile_loop:
    ; Load lattice_ptr from frame + 4
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r14, r0        ; r14 = lattice_ptr

    ; Read R from frame + 140
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    move r12, r0        ; r12 = R (0..3)

    ; Setup corner vertex pointers in frame::v_ptrs (+100..+123):
    ; For corner k in 0..3:
    ;   ik = (k + R) & 3
    ;   B_k  = lattice_ptr + ik * 4
    ;   E1_k = lattice_ptr + (ik + 8) * 4
    ;   E2_k = lattice_ptr + (ik + 12) * 4
    iwt r9, #0          ; k = 0..3
@corner_setup_loop:
    from r9
    add r12
    move r8, r0
    iwt r6, #3
    with r8
    and r6              ; r8 = ik = (k + R) & 3

    ; ik * 4:
    with r8
    add r8
    with r8
    add r8              ; r8 = ik * 4

    ; B_k = lattice_ptr + ik * 4:
    move r1, r14
    with r1
    add r8              ; r1 = &B_k

    ; E1_k = B_k + 32 (8 * 4):
    move r2, r1
    iwt r0, #32
    with r2
    add r0              ; r2 = &E1_k

    ; E2_k = B_k + 48 (12 * 4):
    move r3, r1
    iwt r0, #48
    with r3
    add r0              ; r3 = &E2_k

    ; Store in frame::v_ptrs:
    ; B_k at +100 + k * 2:
    move r6, r9
    with r6
    add r6              ; k * 2
    iwt r7, #gsu_map_render_frame + 100
    with r7
    add r6
    from r1
    stw (r7)            ; &B_k

    ; E1_k at +108 + k * 2:
    iwt r7, #gsu_map_render_frame + 108
    with r7
    add r6
    from r2
    stw (r7)            ; &E1_k

    ; E2_k at +116 + k * 2:
    iwt r7, #gsu_map_render_frame + 116
    with r7
    add r6
    from r3
    stw (r7)            ; &E2_k

    inc r9
    iwt r0, #4
    from r9
    sub r0
    blt @corner_setup_loop
    nop

    ; Setup midpoint pointers for PRIM_STAIRS in frame::m_ptrs (+124..+139):
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    move r12, r0

    ; mW:
    move r0, r12
    iwt r6, #3
    with r0
    add r6
    iwt r6, #3
    with r0
    and r6              ; r0 = mW = (R + 3) & 3
    with r0
    add r0
    with r0
    add r0              ; r0 = mW * 4
    move r8, r0         ; r8 = mW * 4

    ; mE:
    move r0, r12
    inc r0
    iwt r6, #3
    with r0
    and r6              ; r0 = mE = (R + 1) & 3
    with r0
    add r0
    with r0
    add r0              ; r0 = mE * 4
    move r9, r0         ; r9 = mE * 4

    ; MB_W = lattice_ptr + 64 + mW * 4
    move r1, r14
    iwt r0, #64
    with r1
    add r0
    with r1
    add r8
    iwt r7, #gsu_map_render_frame + 124
    from r1
    stw (r7)            ; MB_W (+124)

    ; MB_E = lattice_ptr + 64 + mE * 4
    move r1, r14
    iwt r0, #64
    with r1
    add r0
    with r1
    add r9
    inc r7
    inc r7
    from r1
    stw (r7)            ; MB_E (+126)

    ; M1_W = frame + 68 + mW * 4
    iwt r1, #gsu_map_render_frame + 68
    with r1
    add r8
    inc r7
    inc r7
    from r1
    stw (r7)            ; M1_W (+128)

    ; M1_E = frame + 68 + mE * 4
    iwt r1, #gsu_map_render_frame + 68
    with r1
    add r9
    inc r7
    inc r7
    from r1
    stw (r7)            ; M1_E (+130)

    ; M2_W = frame + 84 + mW * 4
    iwt r1, #gsu_map_render_frame + 84
    with r1
    add r8
    inc r7
    inc r7
    from r1
    stw (r7)            ; M2_W (+132)

    ; M2_E = frame + 84 + mE * 4
    iwt r1, #gsu_map_render_frame + 84
    with r1
    add r9
    inc r7
    inc r7
    from r1
    stw (r7)            ; M2_E (+134)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_STRAIGHT (1h: arch=1) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (1 << 2) | R = 4 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    with r0
    add r0
    move r9, r0         ; r9 = lut byte offset for arch 1

    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = entry_ptr
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)            ; cur_entry_ptr = entry_ptr

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0         ; r2 = entry_offset

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)            ; arch_lut[(1 << 2) | R] = entry_offset

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Face 1: Top sloped quad: E1_0, E1_1, B_2, B_3
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0         ; E1_0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0         ; E1_1
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r3, r0         ; B_2
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; B_3
    iwt r5, #UV_MODE_SLOPE
    iwt r6, #0          ; top_tex
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Face 2: Back quad: E1_1, E1_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 110
    ldw (r7)
    move r1, r0         ; E1_1
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r2, r0         ; E1_0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0         ; B_0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; B_1
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1          ; skirt_tex
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Face 3: Left cheek tri: E1_0, B_0, B_3
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0         ; E1_0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r2, r0         ; B_0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0         ; B_3
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1          ; skirt_tex
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Face 4: Right cheek tri: E1_1, B_2, B_1
    iwt r7, #gsu_map_render_frame + 110
    ldw (r7)
    move r1, r0         ; E1_1
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r2, r0         ; B_2
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r3, r0         ; B_1
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1          ; skirt_tex
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count at (entry_ptr):
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_STRAIGHT_2H (2h: arch=2) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (2 << 2) | R = 8 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #8
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Top sloped quad: E2_0, E2_1, B_2, B_3
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_SLOPE
    iwt r6, #0
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back quad: E2_1, E2_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Left cheek tri: E2_0, B_0, B_3
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Right cheek tri: E2_1, B_2, B_1
    iwt r7, #gsu_map_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_OUTER (1h: arch=3) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (3 << 2) | R = 12 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #12
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (sloped): E1_0, B_1, B_3
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (low base): B_1, B_2, B_3
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 1: E1_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r2, r0
    inc r7
    inc r7
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_NS
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 2: E1_0, B_3, B_0
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_OUTER_2H (2h: arch=4) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (4 << 2) | R = 16 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #16
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (sloped): E2_0, B_1, B_3
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (low base): B_1, B_2, B_3
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 1: E2_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r2, r0
    inc r7
    inc r7
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_NS
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 2: E2_0, B_3, B_0
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_INNER (1h: arch=5) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (5 << 2) | R = 20 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #20
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (high horizontal): E1_0, E1_1, E1_3
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 114
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (sloped down): E1_1, B_2, E1_3
    iwt r7, #gsu_map_render_frame + 110
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 114
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Back wall 1: E1_1, E1_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 110
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back wall 2: E1_0, E1_3, B_3, B_0
    iwt r7, #gsu_map_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 114
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_INNER_2H (2h: arch=6) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (6 << 2) | R = 24 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #24
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (high horizontal): E2_0, E2_1, E2_3
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 122
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (sloped down): E2_1, B_2, E2_3
    iwt r7, #gsu_map_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 122
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; Back wall 1: E2_1, E2_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back wall 2: E2_0, E2_3, B_3, B_0
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 122
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_STAIRS (arch=7) for rotation R:
    ; --------------------------------------------------------------------------
    ; lut index = (7 << 2) | R = 28 + R
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    iwt r6, #28
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Step 1 Lower Tread (+1h): M1_W, M1_E, E1_2, E1_3
    iwt r7, #gsu_map_render_frame + 128
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 112
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Riser 1 (0 to +1h): E1_3, E1_2, B_2, B_3
    iwt r7, #gsu_map_render_frame + 114
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 112
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Step 2 Upper Tread (+2h): E2_0, E2_1, M2_E, M2_W
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 134
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_map_render_frame + 132
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Riser 2 (+1h to +2h): M2_W, M2_E, M1_E, M1_W
    iwt r7, #gsu_map_render_frame + 132
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 130
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_map_render_frame + 128
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back Wall (0 to +2h): E2_1, E2_0, B_0, B_1
    iwt r7, #gsu_map_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; West Cheek Lower Tri: M1_W, B_3, MB_W
    iwt r7, #gsu_map_render_frame + 128
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 106
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 124
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; West Cheek Upper Quad: E2_0, M2_W, MB_W, B_0
    iwt r7, #gsu_map_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 132
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 124
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_map_render_frame + 100
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; East Cheek Lower Tri: M1_E, MB_E, B_2
    iwt r7, #gsu_map_render_frame + 130
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 126
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 104
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call map_compile_tri_face r1, r2, r3, r4, r5

    ; East Cheek Upper Quad: E2_1, B_1, MB_E, M2_E
    iwt r7, #gsu_map_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 126
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_map_render_frame + 134
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_STAIRS:
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

    ; Next rotation R = R + 1
    iwt r7, #gsu_map_render_frame + 140
    ldw (r7)
    inc r0
    from r0
    stw (r7)
    iwt r6, #4
    from r0
    sub r6
    blt @rot_loop_cont
    nop
    iwt r13, #@compile_universal_archetypes
    jmp r13
    nop
@rot_loop_cont:
    iwt r13, #@rot_compile_loop
    jmp r13
    nop

@compile_universal_archetypes:

    ; ==========================================================================
    ; 10. Compile PRIM_LIQUID_SHALLOW (arch=8):
    ; ==========================================================================
    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = entry_ptr
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)            ; cur_entry_ptr = entry_ptr

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0         ; r2 = entry_offset

    ; Store entry_offset in arch_lut for all 4 rotations (A=8: 8 * 4 * 2 = 64)
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 8 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Submerged Riverbed Quad at y=0 (C0, C1, C2, C3, uv_mode=0, tex_id=1 [skirt_tex_id])
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r1, r0         ; C0 (lattice_ptr + 0)
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; C1 (lattice_ptr + 4)
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; C2 (lattice_ptr + 8)
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; C3 (lattice_ptr + 12)
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #1          ; skirt_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Translucent Water Surface Quad at +1h (ELEV1_C0..C3, uv_mode=0, tex_id=0 [top_tex_id])
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #32         ; LATTICE_ELEV1_C0 = 8 * 4 = 32
    with r0
    add r6
    move r1, r0         ; ELEV1_C0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; ELEV1_C1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; ELEV1_C2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; ELEV1_C3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_LIQUID_SHALLOW:
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0         ; r1 = trap_count
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 8 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0         ; r2 = entry_offset
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)            ; store trap count at entry_ptr

    ; ==========================================================================
    ; 11. Compile PRIM_LIQUID_DEEP (arch=9):
    ; ==========================================================================
    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = entry_ptr
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)            ; cur_entry_ptr = entry_ptr

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0         ; r2 = entry_offset

    ; Store entry_offset in arch_lut for all 4 rotations (A=9: 9 * 4 * 2 = 72)
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 9 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Submerged Riverbed Quad at y=0 (C0, C1, C2, C3, uv_mode=0, tex_id=1 [skirt_tex_id])
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r1, r0         ; C0 (lattice_ptr + 0)
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; C1 (lattice_ptr + 4)
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; C2 (lattice_ptr + 8)
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; C3 (lattice_ptr + 12)
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #1          ; skirt_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Translucent Water Surface Quad at +2h (ELEV2_C0..C3, uv_mode=0, tex_id=0 [top_tex_id])
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #48         ; LATTICE_ELEV2_C0 = 12 * 4 = 48
    with r0
    add r6
    move r1, r0         ; ELEV2_C0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; ELEV2_C1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; ELEV2_C2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; ELEV2_C3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_LIQUID_DEEP:
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 9 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)

    ; ==========================================================================
    ; 12. Compile PRIM_PILLAR (arch=10):
    ; ==========================================================================
    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; Store entry_offset in arch_lut for all 4 rotations (A=10: 10 * 4 * 2 = 80)
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 10 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; 1. Floor Quad at y=0 (C0, C1, C2, C3, uv_mode=0, tex_id=0 [top_tex_id])
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r1, r0         ; C0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; C1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; C2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; C3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; 2. Camera-Facing NS Column Wall:
    ; P0 = lat + 80 (20*4), P1 = +84, P2 = +88, P3 = +92
    ; T0 = lat + 96 (24*4), T1 = +100, T2 = +104, T3 = +108
    ; Read cos_yaw from cam_ptr (frame + 0) + 4
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; r0 = cos_yaw
    with r0
    add #0
    blt @pillar_wall_north
    nop

    ; South Wall: T3(108), T2(104), P2(88), P3(92)
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #108
    with r0
    add r6
    move r1, r0         ; T3
    move r0, r14
    iwt r6, #104
    with r0
    add r6
    move r2, r0         ; T2
    move r0, r14
    iwt r6, #88
    with r0
    add r6
    move r3, r0         ; P2
    move r0, r14
    iwt r6, #92
    with r0
    add r6
    move r4, r0         ; P3
    bra @pillar_ns_wall_done
    nop

@pillar_wall_north:
    ; North Wall: T1(100), T0(96), P0(80), P1(84)
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #100
    with r0
    add r6
    move r1, r0         ; T1
    move r0, r14
    iwt r6, #96
    with r0
    add r6
    move r2, r0         ; T0
    move r0, r14
    iwt r6, #80
    with r0
    add r6
    move r3, r0         ; P0
    move r0, r14
    iwt r6, #84
    with r0
    add r6
    move r4, r0         ; P1

@pillar_ns_wall_done:
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1          ; skirt_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; 3. Camera-Facing EW Column Wall:
    ; Read sin_yaw from cam_ptr (frame + 0) + 2
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; r0 = sin_yaw
    with r0
    add #0
    blt @pillar_wall_west
    nop

    ; East Wall: T2(104), T1(100), P1(84), P2(88)
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #104
    with r0
    add r6
    move r1, r0         ; T2
    move r0, r14
    iwt r6, #100
    with r0
    add r6
    move r2, r0         ; T1
    move r0, r14
    iwt r6, #84
    with r0
    add r6
    move r3, r0         ; P1
    move r0, r14
    iwt r6, #88
    with r0
    add r6
    move r4, r0         ; P2
    bra @pillar_ew_wall_done
    nop

@pillar_wall_west:
    ; West Wall: T0(96), T3(108), P3(92), P0(80)
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #96
    with r0
    add r6
    move r1, r0         ; T0
    move r0, r14
    iwt r6, #108
    with r0
    add r6
    move r2, r0         ; T3
    move r0, r14
    iwt r6, #92
    with r0
    add r6
    move r3, r0         ; P3
    move r0, r14
    iwt r6, #80
    with r0
    add r6
    move r4, r0         ; P0

@pillar_ew_wall_done:
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1          ; skirt_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; 4. Column Top Cap (16x16) at +2h: T0(96), T1(100), T2(104), T3(108)
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #96
    with r0
    add r6
    move r1, r0         ; T0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; T1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; T2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; T3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_PILLAR:
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 10 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)

    ; ==========================================================================
    ; 13. Compile PRIM_FOLIAGE_CROSS (arch=11):
    ; ==========================================================================
    ; Precompute Center points K_bot and K_top:
    ; K_bot.x = MN.x + MW.x
    ; K_bot.y = MN.y + MW.y
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #64
    with r0
    add r6
    move r8, r0         ; &MN
    ldw (r8)            ; MN.x
    move r1, r0
    inc r8
    inc r8
    ldw (r8)            ; MN.y
    move r2, r0

    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    iwt r6, #76
    with r0
    add r6
    move r8, r0         ; &MW
    ldw (r8)            ; MW.x
    with r1
    add r0              ; r1 = K_bot.x = MN.x + MW.x
    inc r8
    inc r8
    ldw (r8)            ; MW.y
    with r2
    add r0              ; r2 = K_bot.y = MN.y + MW.y

    ; Store K_bot at frame + 144
    iwt r7, #gsu_map_render_frame + 144
    from r1
    stw (r7)            ; K_bot.x
    inc r7
    inc r7
    from r2
    stw (r7)            ; K_bot.y

    ; Store K_top at frame + 148: (K_bot.x, K_bot.y - 28)
    inc r7
    inc r7
    from r1
    stw (r7)            ; K_top.x
    inc r7
    inc r7
    move r0, r2
    iwt r6, #28
    with r0
    sub r6
    from r0
    stw (r7)            ; K_top.y

    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_map_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_map_render_frame + 152
    from r8
    stw (r7)

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; Store entry_offset in arch_lut for all 4 rotations (A=11: 11 * 4 * 2 = 88)
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 11 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_map_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_map_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; 1. Floor Quad at y=0 (C0, C1, C2, C3, uv_mode=0, tex_id=0 [top_tex_id])
    iwt r7, #gsu_map_render_frame + 4
    ldw (r7)
    move r1, r0         ; C0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; C1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; C2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; C3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call map_compile_quad_face r1, r2, r3, r4, r5, r6

    ; 2. Emit 4 fins in Yaw-Quadrant Back-to-Front order:
    ; (The 2 receding fins first, then the 2 camera-facing fins)
    ; Step A: Receding NS fin (Fin_N if cos_yaw >= 0, else Fin_S)
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @foliage_fin_step_a_alt
    nop
    call compile_fin_n
    bra @foliage_fin_step_a_done
    nop
@foliage_fin_step_a_alt:
    call compile_fin_s
@foliage_fin_step_a_done:

    ; Step B: Receding EW fin (Fin_W if sin_yaw >= 0, else Fin_E)
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @foliage_fin_step_b_alt
    nop
    call compile_fin_w
    bra @foliage_fin_step_b_done
    nop
@foliage_fin_step_b_alt:
    call compile_fin_e
@foliage_fin_step_b_done:

    ; Step C: Camera-facing NS fin (Fin_S if cos_yaw >= 0, else Fin_N)
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @foliage_fin_step_c_alt
    nop
    call compile_fin_s
    bra @foliage_fin_step_c_done
    nop
@foliage_fin_step_c_alt:
    call compile_fin_n
@foliage_fin_step_c_done:

    ; Step D: Camera-facing EW fin (Fin_E if sin_yaw >= 0, else Fin_W)
    iwt r7, #gsu_map_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @foliage_fin_step_d_alt
    nop
    call compile_fin_e
    bra @foliage_fin_step_d_done
    nop
@foliage_fin_step_d_alt:
    call compile_fin_w
@foliage_fin_step_d_done:

    ; Store trap count for PRIM_FOLIAGE_CROSS:
    iwt r7, #gsu_map_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 11 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)

@rot_compile_done:
    ; Restore ROMBR to bank 4 for texture atlas
    ibt r0, #4
    romb

    ; Return 1 (recompiled)
    iwt r3, #1
    return
endfunction

; ==============================================================================
; map_grid_render
; Renders the Map Grid in back-to-front yaw-quadrant Painter's order,
; performing per-cell bounding box culling against active Frame Half and screen bounds.
; ==============================================================================
function map_grid_render map_ptr, cam_ptr, basis_ptr, arch_traps_ptr, frame_half, debug_order_ptr
    register map_ptr = r1, cam_ptr = r2, basis_ptr = r3, arch_traps_ptr = r4, frame_half = r5, debug_order_ptr = r6

    ; Ensure ROMBR is bank 4 for texture atlas and TEXTURE_TABLE
    ibt r0, #4
    romb

    iwt r7, #gsu_map_render_frame

    ; Store function arguments in frame
    from map_ptr
    stw (r7)            ; frame.map_ptr (+0)
    inc r7
    inc r7
    from cam_ptr
    stw (r7)            ; frame.cam_ptr (+2)
    inc r7
    inc r7
    from basis_ptr
    stw (r7)            ; frame.basis_ptr (+4)
    inc r7
    inc r7
    from arch_traps_ptr
    stw (r7)            ; frame.arch_traps_ptr (+6)
    inc r7
    inc r7
    from frame_half
    stw (r7)            ; frame.frame_half (+8)
    inc r7
    inc r7
    from debug_order_ptr
    stw (r7)            ; frame.debug_order_ptr (+10)
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; frame.debug_count (+12) = 0

    ; 1. Read header fields: cols (+0), rows (+1), origin_x (+2), origin_z (+4)
    move r7, map_ptr
    ldb (r7)
    move r8, r0         ; r8 = cols
    inc r7
    ldb (r7)
    move r9, r0         ; r9 = rows
    inc r7
    ldw (r7)
    move r11, r0        ; r11 = origin_x
    inc r7
    inc r7
    ldw (r7)
    move r12, r0        ; r12 = origin_z

    ; Store cols, rows, origin_x, origin_z in frame
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)
    inc r7
    inc r7
    from r12
    stw (r7)

    ; 2. Determine Yaw Quadrant loop directions from cos_yaw (+4) and sin_yaw (+2)
    move r7, cam_ptr         ; cam_ptr
    inc r7
    inc r7
    to r11
    ldw (r7)            ; r11 = sin_yaw
    inc r7
    inc r7
    to r12
    ldw (r7)            ; r12 = cos_yaw

    ; Determine j loop parameters (North/South depth axis):
    ; If cos_yaw >= 0: j goes 0 .. rows-1 (start=0, step=1)
    ; If cos_yaw < 0:  j goes rows-1 .. 0 (start=rows-1, step=-1)
    with r12
    add #0
    blt @j_decreasing
    nop
    iwt r8, #0          ; j_start = 0
    iwt r9, #1          ; j_step = 1
    bra @j_done
    nop
@j_decreasing:
    iwt r7, #gsu_map_render_frame + map_render_frame::rows
    ldw (r7)
    dec r0
    move r8, r0         ; j_start = rows - 1
    iwt r9, #$FFFF      ; j_step = -1
@j_done:
    iwt r7, #gsu_map_render_frame + map_render_frame::rows
    ldw (r7)
    move r14, r0        ; r14 = j_count = rows

    iwt r7, #gsu_map_render_frame + map_render_frame::j_start
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)
    inc r7
    inc r7
    from r14
    stw (r7)           ; j_count = rows

    ; Determine i loop parameters (East/West width axis):
    ; If sin_yaw >= 0: i goes 0 .. cols-1 (start=0, step=1)
    ; If sin_yaw < 0:  i goes cols-1 .. 0 (start=cols-1, step=-1)
    with r11
    add #0
    blt @i_decreasing
    nop
    iwt r8, #0          ; i_start = 0
    iwt r9, #1          ; i_step = 1
    bra @i_done
    nop
@i_decreasing:
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    ldw (r7)
    dec r0
    move r8, r0         ; i_start = cols - 1
    iwt r9, #$FFFF      ; i_step = -1
@i_done:
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    ldw (r7)
    move r11, r0        ; r11 = i_count = cols

    iwt r7, #gsu_map_render_frame + map_render_frame::i_start
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)           ; i_count = cols

    ; --------------------------------------------------------------------------
    ; 3. Outer J Loop (Rows)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::j_start
    ldw (r7)
    move r9, r0         ; r9 = j_cur = j_start
    inc r7
    inc r7
    inc r7
    inc r7
    ldw (r7)
    move r11, r0        ; r11 = j_rem = j_count

@j_loop_top:
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)            ; save j_rem

    ; --------------------------------------------------------------------------
    ; 4. Inner I Loop (Cols)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::i_start
    ldw (r7)
    move r12, r0        ; r12 = i_cur = i_start
    inc r7
    inc r7
    inc r7
    inc r7
    ldw (r7)
    move r14, r0        ; r14 = i_rem = i_count

@i_loop_top:
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    from r12
    stw (r7)
    inc r7
    inc r7
    from r14
    stw (r7)            ; save i_rem

    ; --------------------------------------------------------------------------
    ; 5. Read Map Cell Record at (j * cols + i) << 3
    ; --------------------------------------------------------------------------
    move r6, r9         ; mul_b = j_cur
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    ldw (r7)            ; r0 = cols
    to r8
    lmult               ; r4_reg = j * cols
    from r12            ; add i_cur
    to r8
    add r4
    ; index << 3:
    with r8
    add r8
    with r8
    add r8
    with r8
    add r8              ; r8 = (j * cols + i) << 3

    ; cell_ptr = map_ptr + 8 + r8
    iwt r7, #gsu_map_render_frame + map_render_frame::map_ptr
    ldw (r7)
    with r0
    add #8
    with r0
    add r8
    move r7, r0         ; r7 = cell_ptr

    ; Read cell fields:
    ; base_height (+0)
    ldb (r7)
    iwt r11, #gsu_map_render_frame + map_render_frame::base_height
    stw (r11)

    ; archetype_id (+1)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; top_tex_id (+2)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; skirt_tex_id (+3)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; panel_tex_id (+4)
    inc r7
    ldb (r7)
    iwt r8, #gsu_map_render_frame + map_render_frame::panel_tex_id
    stw (r8)

    ; panel_flags (+5) [skip to +6]
    inc r7
    inc r7

    ; drop_ns (+6)
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; drop_ew (+7)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; --------------------------------------------------------------------------
    ; 6. Calculate 2D Screen Anchor(i, j, base_height):
    ;    Anchor.x = origin_x + i * Sx.x + j * Sz.x
    ;    Anchor.y = origin_z + i * Sx.y + j * Sz.y + base_height * (-14)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::origin_x
    to r1
    ldw (r7)            ; r1 = anchor_x
    inc r7
    inc r7
    to r2
    ldw (r7)            ; r2 = anchor_y

    iwt r7, #gsu_map_render_frame + map_render_frame::basis_ptr
    ldw (r7)
    move r7, r0         ; r7 = basis_ptr

    ; + i * Sx:
    move r6, r12        ; mul_b = i_cur
    ldw (r7)            ; r0 = Sx.x
    to r8
    lmult
    with r1
    add r4
    inc r7
    inc r7
    ldw (r7)            ; r0 = Sx.y
    to r8
    lmult
    with r2
    add r4

    ; + j * Sz:
    inc r7
    inc r7
    move r6, r9         ; mul_b = j_cur
    ldw (r7)            ; r0 = Sz.x
    to r8
    lmult
    with r1
    add r4
    inc r7
    inc r7
    ldw (r7)            ; r0 = Sz.y
    to r8
    lmult
    with r2
    add r4

    ; + base_height * (-14):
    iwt r7, #gsu_map_render_frame + map_render_frame::base_height
    ldw (r7)
    move r6, r0         ; mul_b = base_height
    iwt r0, #$FFF2      ; -14 ($FFF2)
    to r8
    lmult
    with r2
    add r4

    ; Save anchor_x and anchor_y in frame
    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)

    ; --------------------------------------------------------------------------
    ; 7. Per-Cell Bounding-Box Culling:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #318
    with r0
    add r11
    move r7, r0         ; r7 = arch_traps_ptr + bbox_xmin

    ; cell_xmin = anchor_x + bbox_xmin (+318)
    ldw (r7)            ; r0 = bbox_xmin
    with r0
    add r1              ; r0 = bbox_xmin + anchor_x
    move r3, r0         ; r3 = xmin

    ; cell_xmax = anchor_x + bbox_xmax (+320)
    inc r7
    inc r7
    ldw (r7)            ; r0 = bbox_xmax
    with r0
    add r1              ; r0 = bbox_xmax + anchor_x
    move r4, r0         ; r4 = xmax

    ; cell_ymin = anchor_y + bbox_ymin (+322)
    inc r7
    inc r7
    ldw (r7)            ; r0 = bbox_ymin
    with r0
    add r2              ; r0 = bbox_ymin + anchor_y
    move r5, r0         ; r5 = ymin

    ; max_drop = max(drop_ns, drop_ew)
    iwt r8, #gsu_map_render_frame + map_render_frame::drop_ns
    to r6
    ldw (r8)            ; r6 = max_drop
    inc r8
    inc r8
    to r14
    ldw (r8)            ; r14 = drop_ew
    from r14
    sub r6
    blt @skip_max_drop
    nop
    move r6, r14
@skip_max_drop:
    ; drop_px = max_drop * 14 = (max_drop << 4) - (max_drop << 1)
    move r8, r6
    with r8
    add r8              ; r8 = max_drop * 2
    move r14, r8
    with r8
    add r8              ; * 4
    with r8
    add r8              ; * 8
    with r8
    add r8              ; * 16
    with r8
    sub r14             ; * 14

    ; cell_ymax = anchor_y + bbox_ymax (+324) + drop_px
    inc r7
    inc r7
    ldw (r7)            ; r0 = bbox_ymax
    with r0
    add r2
    with r0
    add r8
    move r6, r0         ; r6 = ymax

    ; --- Vertical Screen Culling [0, 160) ---
    ; If ymax < 0: cull
    with r6
    add #0
    blt :+
    nop
    bra @vert_y_ok
    nop
:
    iwt r13, #@cull_cell
    jmp r13
    nop

@vert_y_ok:
    ; If ymin >= 160: cull
    iwt r14, #160
    from r5
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    ; --- Horizontal Frame Half Culling ---
    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    with r0
    add #0
    bmi @cell_visible
    nop
    bne @check_half_1
    nop

    ; Pass 0 (Half 0): screen X in [0, 128)
    ; If xmax < 0: cull
    with r4
    add #0
    blt :+
    nop
    bra @pass0_xmax_ok
    nop
:
    iwt r13, #@cull_cell
    jmp r13
    nop

@pass0_xmax_ok:
    ; If xmin >= 128: cull
    iwt r14, #128
    from r3
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    iwt r13, #@cell_visible
    jmp r13
    nop

@check_half_1:
    ; Pass 1 (Half 1): screen X in [128, 256)
    ; If xmax < 128: cull
    iwt r14, #128
    from r4
    sub r14
    bge :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    ; If xmin >= 256: cull
    iwt r14, #256
    from r3
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:

@cell_visible:
    ; --------------------------------------------------------------------------
    ; 8. Optional Trace Recording for Traversal & Culling Verification
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::debug_order_ptr
    ldw (r7)
    with r0
    add #0
    beq @do_stamping
    nop
    move r11, r0        ; r11 = debug_order_ptr

    ; Write (i_cur << 8) | j_cur to debug_order_ptr
    from r12
    to r14
    swap
    iwt r7, #$00FF
    from r9
    to r8
    and r7
    with r14
    or r8
    from r14
    stw (r11)
    inc r11
    inc r11
    iwt r7, #gsu_map_render_frame + map_render_frame::debug_order_ptr
    from r11
    stw (r7)           ; update debug_order_ptr in frame

    ; Increment debug_count (+12)
    inc r7
    inc r7
    ldw (r7)
    inc r0
    stw (r7)

    ; When debug_order_ptr is non-zero, skip trapezoid stamping for pure traversal tests
    iwt r13, #@cull_cell
    jmp r13
    nop

@do_stamping:
    ; --------------------------------------------------------------------------
    ; 9. Intra-Cell Stamping:
    ;    Step 1: Exposed Cell Skirts (drop_ns and drop_ew)
    ;    Step 3: Shape Archetype (PRIM_FLAT)
    ; --------------------------------------------------------------------------

    ; --- 9A: Stamp ARCH_SKIRT_NS (drop_ns steps) ---
    iwt r7, #gsu_map_render_frame + map_render_frame::drop_ns
    ldw (r7)
    with r0
    add #0
    bne @skirt_ns_drop_ok
    nop
    iwt r13, #@skirt_ns_done
    jmp r13
    nop
@skirt_ns_drop_ok:
    move r8, r0         ; r8 = drop_ns

    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #106
    with r0
    add r11             ; skirt_ns_count
    move r7, r0
    ldw (r7)
    with r0
    add #0
    bne @skirt_ns_count_ok
    nop
    iwt r13, #@skirt_ns_done
    jmp r13
    nop
@skirt_ns_count_ok:
    move r9, r0         ; r9 = skirt_ns_count

    ; U offset for NS skirt = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    ldw (r7)
    swap                ; r0 = i_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    with r0
    add r0              ; << 12
    with r0
    add r0              ; << 13
    move r5, r0         ; r5 = u_offset in Q8.8

    ; Skirt texture ID
    iwt r7, #gsu_map_render_frame + map_render_frame::skirt_tex_id
    to r11
    ldw (r7)            ; r11 = skirt_tex_id

    ; Loop over vertical steps s = 0 .. drop_ns - 1
    iwt r12, #0         ; r12 = s = 0
@ns_step_loop:
    ; step_y = anchor_y + s * 14
    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_y
    ldw (r7)
    move r4, r0         ; r4 = anchor_y
    from r12
    to r14
    add r12             ; s * 2
    move r7, r14
    with r14
    add r14
    with r14
    add r14
    with r14
    add r14             ; s * 16
    with r14
    sub r7              ; s * 14
    with r4
    add r14             ; r4 = anchor_y + s * 14

    ; v_offset = (s * 16) << ATLAS_STRIDE_SHIFT = s << 10:
    move r0, r12
    swap                ; s << 8
    with r0
    add r0              ; s << 9
    with r0
    add r0              ; s << 10
    move r6, r0         ; r6 = v_offset

    ; Stamp each cached_trap in skirt_ns_traps:
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r2, #108
    with r0
    add r2
    move r1, r0         ; r1 = skirt_ns_traps

    move r14, r9        ; r14 = trap counter
@ns_trap_loop:
    ; Set trap tex_id (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r11
    stw (r7)

    gsu_stack_push r14
    gsu_stack_push r1
    gsu_stack_push r12
    gsu_stack_push r11
    gsu_stack_push r9
    gsu_stack_push r8
    gsu_stack_push r6
    gsu_stack_push r5
    gsu_stack_push r4

    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x

    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    call draw_cached_trap r1, r3, r4, r5, r6, r7

    gsu_stack_pop r4
    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r8
    gsu_stack_pop r9
    gsu_stack_pop r11
    gsu_stack_pop r12
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    bne @ns_trap_loop
    nop

    inc r12
    from r12
    sub r8
    bge @skirt_ns_done
    nop
    iwt r13, #@ns_step_loop
    jmp r13
    nop

@skirt_ns_done:

    ; --- 9B: Stamp ARCH_SKIRT_EW (drop_ew steps) ---
    iwt r7, #gsu_map_render_frame + map_render_frame::drop_ew
    ldw (r7)
    with r0
    add #0
    bne @skirt_ew_drop_ok
    nop
    iwt r13, #@skirt_ew_done
    jmp r13
    nop
@skirt_ew_drop_ok:
    move r8, r0         ; r8 = drop_ew

    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #212
    with r0
    add r11             ; skirt_ew_count
    move r7, r0
    ldw (r7)
    with r0
    add #0
    bne @skirt_ew_count_ok
    nop
    iwt r13, #@skirt_ew_done
    jmp r13
    nop
@skirt_ew_count_ok:
    move r9, r0         ; r9 = skirt_ew_count

    ; U offset for EW skirt = (j_cur * 32) << 8 = j_cur << 13:
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    swap                ; r0 = j_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    with r0
    add r0              ; << 12
    with r0
    add r0              ; << 13
    move r5, r0         ; r5 = u_offset in Q8.8

    ; Skirt texture ID
    iwt r7, #gsu_map_render_frame + map_render_frame::skirt_tex_id
    to r11
    ldw (r7)            ; r11 = skirt_tex_id

    ; Loop over vertical steps s = 0 .. drop_ew - 1
    iwt r12, #0         ; r12 = s = 0
@ew_step_loop:
    ; step_y = anchor_y + s * 14
    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_y
    ldw (r7)
    move r4, r0         ; r4 = anchor_y
    from r12
    to r14
    add r12             ; s * 2
    move r7, r14
    with r14
    add r14
    with r14
    add r14
    with r14
    add r14             ; s * 16
    with r14
    sub r7              ; s * 14
    with r4
    add r14             ; r4 = anchor_y + s * 14

    ; v_offset = (s * 16) << ATLAS_STRIDE_SHIFT = s << 10:
    move r0, r12
    swap                ; s << 8
    with r0
    add r0              ; s << 9
    with r0
    add r0              ; s << 10
    move r6, r0         ; r6 = v_offset

    ; Stamp each cached_trap in skirt_ew_traps:
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r2, #214
    with r0
    add r2
    move r1, r0         ; r1 = skirt_ew_traps

    move r14, r9
@ew_trap_loop:
    ; Set trap tex_id (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r11
    stw (r7)

    gsu_stack_push r14
    gsu_stack_push r1
    gsu_stack_push r12
    gsu_stack_push r11
    gsu_stack_push r9
    gsu_stack_push r8
    gsu_stack_push r6
    gsu_stack_push r5
    gsu_stack_push r4

    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x

    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    call draw_cached_trap r1, r3, r4, r5, r6, r7

    gsu_stack_pop r4
    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r8
    gsu_stack_pop r9
    gsu_stack_pop r11
    gsu_stack_pop r12
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    bne @ew_trap_loop
    nop

    inc r12
    from r12
    sub r8
    bge @skirt_ew_done
    nop
    iwt r13, #@ew_step_loop
    jmp r13
    nop

@skirt_ew_done:

    ; --- 9C: Stamp Archetype (Top Cap & Faces) ---
    iwt r7, #gsu_map_render_frame + map_render_frame::archetype_id
    ldw (r7)
    move r8, r0         ; r8 = archetype_id

    ; base archetype A = r8 & $1F
    move r1, r8
    iwt r2, #$001F
    with r1
    and r2              ; r1 = A
    with r1
    add r1
    with r1
    add r1              ; r1 = A << 2

    ; rot R = (r8 >> 6) & 3
    move r0, r8
    with r0
    add r0
    with r0
    add r0
    swap
    iwt r2, #3
    with r0
    and r2              ; r0 = R

    with r1
    add r0              ; r1 = lut_index = (A << 2) | R
    with r1
    add r1              ; r1 = lut_byte_offset = lut_index * 2

    ; Check bounds: lut_byte_offset < 128 (64 entries * 2)
    iwt r0, #128
    from r1
    sub r0
    blt @arch_lut_bounds_ok
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
@arch_lut_bounds_ok:

    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r2, #326        ; offset of arch_lut
    with r0
    add r2
    with r0
    add r1
    move r7, r0
    ldw (r7)
    move r2, r0         ; r2 = entry_offset from arch_traps_ptr

    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    with r0
    add r2
    move r1, r0         ; r1 = &arch_traps_ptr[entry_offset] = ptr to trap_count
    ldw (r1)
    move r9, r0         ; r9 = trap_count
    with r9
    add #0
    bne @arch_trap_count_ok
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
@arch_trap_count_ok:

    ; Pointer to first cached_trap
    inc r1
    inc r1              ; r1 = &first cached_trap

    ; u_offset = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    ldw (r7)
    swap                ; r0 = i_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    with r0
    add r0              ; << 12
    with r0
    add r0              ; << 13
    move r5, r0         ; r5 = u_offset in Q8.8

    ; v_offset = (j_cur * 32) << ATLAS_STRIDE_SHIFT = j_cur << 11:
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    swap                ; r0 = j_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    move r6, r0         ; r6 = v_offset

    ; Load cell top_tex_id and skirt_tex_id
    iwt r7, #gsu_map_render_frame + map_render_frame::top_tex_id
    to r11
    ldw (r7)            ; r11 = top_tex_id
    iwt r7, #gsu_map_render_frame + map_render_frame::skirt_tex_id
    to r12
    ldw (r7)            ; r12 = skirt_tex_id

    move r14, r9
@archetype_trap_loop:
    ; Read compiled surface type (+24) from current cached_trap (r1 + 24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    ldw (r7)
    move r8, r0         ; r8 = original template surface type (0 = top, 1 = skirt, 2 = panel)
    with r8
    add #0
    beq @use_top_tex
    nop
    with r8
    sub #1
    beq @use_skirt_tex
    nop
    ; r8 == 2: substitute panel_tex_id
    iwt r2, #gsu_map_render_frame + map_render_frame::panel_tex_id
    ldw (r2)
    stw (r7)
    bra @tex_applied
    nop
@use_skirt_tex:
    from r12
    stw (r7)            ; substitute skirt_tex_id
    bra @tex_applied
    nop
@use_top_tex:
    from r11
    stw (r7)            ; substitute top_tex_id
@tex_applied:

    gsu_stack_push r14
    gsu_stack_push r8
    gsu_stack_push r1
    gsu_stack_push r12
    gsu_stack_push r11
    gsu_stack_push r9
    gsu_stack_push r6
    gsu_stack_push r5

    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; anchor_y

    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    call draw_cached_trap r1, r3, r4, r5, r6, r7

    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r9
    gsu_stack_pop r11
    gsu_stack_pop r12
    gsu_stack_pop r1
    gsu_stack_pop r8
    gsu_stack_pop r14

    ; Restore original template surface type (r8) to trap (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r8
    stw (r7)

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    beq @cull_cell
    nop
    iwt r13, #@archetype_trap_loop
    jmp r13
    nop

@cull_cell:
    ; --------------------------------------------------------------------------
    ; 10. Advance I Loop
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::i_rem
    ldw (r7)
    dec r0
    beq @i_loop_done
    nop
    move r14, r0        ; r14 = new i_rem

    ; Advance i_cur += i_step
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    ldw (r7)
    move r12, r0
    iwt r7, #gsu_map_render_frame + map_render_frame::i_step
    ldw (r7)
    with r12
    add r0

    ; Reload j_cur into r9 for next i_loop_top
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    move r9, r0

    iwt r13, #@i_loop_top
    jmp r13
    nop

@i_loop_done:
    ; --------------------------------------------------------------------------
    ; 11. Advance J Loop
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::j_rem
    ldw (r7)
    dec r0
    beq @render_done
    nop
    move r11, r0        ; r11 = new j_rem

    ; Advance j_cur += j_step
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    move r9, r0
    iwt r7, #gsu_map_render_frame + map_render_frame::j_step
    ldw (r7)
    with r9
    add r0

    iwt r13, #@j_loop_top
    jmp r13
    nop

@render_done:
    return
endfunction

.endif ; ::__ISO_MAP_GRID_DEFINED__
