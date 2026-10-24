; ==============================================================================
; IsoEngine Face-to-Scanline Trapezoid Compiler & Affine Gradient Solver
; Transforms 2D projected Faces (triangles & coplanar quads) into cached_traps
; ==============================================================================
.ifndef ::__COMPILE_FACE_TRAPS_DEFINED__
::__COMPILE_FACE_TRAPS_DEFINED__ = 1

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/control.i"
.include "../../common/util.i"
.include "../../common/structs.i"
.include "../../gsu_maths/gsu_recip.i"
.include "compile_face_traps_def.i"

.segment "GSUCODE"

; ==============================================================================
; compile_face_traps
; Compiles a 2D projected Face (triangle or coplanar quad) into 0..4 cached_traps.
;
; In:
;   face_def_ptr  = r1: Pointer to face_def struct in GSURAM/ROM
;   out_traps_ptr = r2: Destination pointer to cached_trap array in GSURAM
;
; Out:
;   r0 / r3       = num_traps_emitted (0 if culled or degenerate)
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r12, r13, r14
; ==============================================================================
function compile_face_traps face_def_ptr, out_traps_ptr : num_traps_emitted
    register face_def_ptr = r1, out_traps_ptr = r2, num_traps_emitted = r3

    ; --------------------------------------------------------------------------
    ; 1. Initialize working frame:
    ; --------------------------------------------------------------------------
    ; Save out_traps_ptr and trap_count = 0 in frame
    frame_ptr compile_frame::curr_out_ptr, r7
    from out_traps_ptr
    stw (r7)            ; curr_out_ptr = out_traps_ptr

    frame_ptr compile_frame::trap_count, r7
    iwt r0, #0
    stw (r7)            ; trap_count = 0

    ; --------------------------------------------------------------------------
    ; 2. Read header fields from face_def_ptr into frame:
    ;    flags (+0), uv_mode (+2), tex_id (+4), stride_shift (+6),
    ;    cos_yaw (+8), sin_yaw (+10)
    ; --------------------------------------------------------------------------
    frame_ptr 0, r8
    ldw (face_def_ptr)         ; r0 = flags
    stw (r8)            ; frame.flags = flags

    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)         ; r0 = uv_mode
    stw (r8)            ; frame.uv_mode = uv_mode

    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)         ; r0 = tex_id
    stw (r8)            ; frame.tex_id = tex_id

    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)         ; r0 = stride_shift
    stw (r8)            ; frame.stride_shift = stride_shift

    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)         ; r0 = cos_yaw
    stw (r8)            ; frame.cos_yaw = cos_yaw

    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)         ; r0 = sin_yaw
    stw (r8)            ; frame.sin_yaw = sin_yaw

    ; --------------------------------------------------------------------------
    ; 3. Unpack Vertices V0, V1, V2 (and V3 if quad):
    ;    Check flags bit 1 (FACE_DEF_FLAG_PTRS)
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::flags, r8
    ldw (r8)            ; r0 = flags
    iwt r5, #FACE_DEF_FLAG_PTRS
    from r0
    and r5
    beq @do_unpack_direct
    nop
    iwt r13, #@unpack_ptrs
    jmp r13
    nop

@do_unpack_direct:
    ; --- Direct Coordinates Unpacking ---
    ; V0:
    frame_ptr compile_frame::v0_x, r8
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> v0.x_or_ptr
    ldw (face_def_ptr)
    stw (r8)            ; v0_x
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v0_y
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v0_u
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v0_v

    ; V1:
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v1_x
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v1_y
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v1_u
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v1_v

    ; V2:
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v2_x
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v2_y
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v2_u
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v2_v

    ; V3 (if quad):
    frame_ptr compile_frame::flags, r7
    ldw (r7)            ; r0 = flags
    iwt r5, #FACE_DEF_FLAG_QUAD
    from r0
    and r5
    bne @do_unpack_direct_v3
    nop
    iwt r13, #@unpack_done
    jmp r13
    nop
@do_unpack_direct_v3:

    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v3_x
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v3_y
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v3_u
    inc face_def_ptr
    inc face_def_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v3_v
    iwt r13, #@unpack_done
    jmp r13
    nop

@unpack_ptrs:
    ; --- Pointer-Based Unpacking ---
    ; V0:
    frame_ptr compile_frame::v0_x, r8
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> v0.x_or_ptr
    ldw (face_def_ptr)         ; r0 = ptr to vector2
    move r7, r0         ; r7 = ptr
    ldw (r7)            ; x
    stw (r8)            ; v0_x
    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)            ; y
    stw (r8)            ; v0_y
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> pad/y
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> u0
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v0_u
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> v0
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v0_v

    ; V1:
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> v1.x_or_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    move r7, r0
    ldw (r7)
    stw (r8)            ; v1_x
    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)
    stw (r8)            ; v1_y
    inc face_def_ptr
    inc face_def_ptr           ; pad
    inc face_def_ptr
    inc face_def_ptr           ; u1
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v1_u
    inc face_def_ptr
    inc face_def_ptr           ; v1
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v1_v

    ; V2:
    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> v2.x_or_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    move r7, r0
    ldw (r7)
    stw (r8)            ; v2_x
    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)
    stw (r8)            ; v2_y
    inc face_def_ptr
    inc face_def_ptr           ; pad
    inc face_def_ptr
    inc face_def_ptr           ; u2
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v2_u
    inc face_def_ptr
    inc face_def_ptr           ; v2
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v2_v

    ; V3 (if quad):
    frame_ptr compile_frame::flags, r7
    ldw (r7)            ; r0 = flags
    iwt r5, #FACE_DEF_FLAG_QUAD
    from r0
    and r5
    bne @do_unpack_ptrs_v3
    nop
    iwt r13, #@unpack_done
    jmp r13
    nop
@do_unpack_ptrs_v3:

    inc face_def_ptr
    inc face_def_ptr           ; face_def_ptr -> v3.x_or_ptr
    inc r8
    inc r8
    ldw (face_def_ptr)
    move r7, r0
    ldw (r7)
    stw (r8)            ; v3_x
    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)
    stw (r8)            ; v3_y
    inc face_def_ptr
    inc face_def_ptr           ; pad
    inc face_def_ptr
    inc face_def_ptr           ; u3
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v3_u
    inc face_def_ptr
    inc face_def_ptr           ; v3
    inc r8
    inc r8
    ldw (face_def_ptr)
    stw (r8)            ; v3_v

@unpack_done:

    ; --------------------------------------------------------------------------
    ; 4. Screen-Space Winding Order Backface Culling:
    ;    cross = (x1 - x0) * (y2 - y0) - (y1 - y0) * (x2 - x0)
    ;    If cross <= 0: cull face (emit 0 traps)
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::v0_x, r7
    ldw (r7)
    move r8, r0         ; r8 = v0_x
    inc r7
    inc r7
    ldw (r7)
    move r9, r0         ; r9 = v0_y

    frame_ptr compile_frame::v1_x, r7
    ldw (r7)            ; r0 = v1_x
    with r0
    sub r8
    move r1, r0         ; r1 = dx1 = x1 - x0

    inc r7
    inc r7
    ldw (r7)            ; r0 = v1_y
    with r0
    sub r9
    move r2, r0         ; r2 = dy1 = y1 - y0

    frame_ptr compile_frame::v2_x, r7
    ldw (r7)            ; r0 = v2_x
    with r0
    sub r8
    move r3, r0         ; r3 = dx2 = x2 - x0

    inc r7
    inc r7
    ldw (r7)            ; r0 = v2_y
    with r0
    sub r9
    move r5, r0         ; r5 = dy2 = y2 - y0

    ; term1 = dx1 * dy2 (32-bit signed: r7:r8)
    move r6, r5         ; r6 = dy2
    from r1
    to r7
    lmult               ; r7:r4_reg = dx1 * dy2
    move r8, r4         ; r7:r8 = term1 (hi:lo)

    ; term2 = dy1 * dx2 (32-bit signed: r1:r2)
    move r6, r3         ; r6 = dx2
    from r2
    to r1
    lmult               ; r1:r4_reg = dy1 * dx2
    move r2, r4         ; r1:r2 = term2 (hi:lo)

    ; Compare term1 (r7:r8) with term2 (r1:r2):
    from r7
    cmp r1
    bge @check_term1_hi_gt
    nop
    iwt r13, #@cull_face
    jmp r13
    nop

@check_term1_hi_gt:
    from r1
    cmp r7
    bge @check_low_words
    nop
    iwt r13, #@winding_ok
    jmp r13
    nop

@check_low_words:
    ; High words are equal: compare low words (unsigned):
    from r8
    cmp r2
    bne @term1_hi_eq_lo_ne
    nop
    iwt r13, #@cull_face
    jmp r13
    nop
@term1_hi_eq_lo_ne:
    bcs @winding_ok
    nop
    iwt r13, #@cull_face
    jmp r13
    nop

@winding_ok:

    ; --------------------------------------------------------------------------
    ; 5. Solve Horizontal Affine UV Gradients (du_dx, dv_dx):
    ;    Mode 0 (Flat Horizontal): derived from cos_yaw, sin_yaw (ZERO division!)
    ;    Modes 1, 2, 3: widest horizontal span reciprocal lookup
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::uv_mode, r7
    ldw (r7)
    from r0
    sub #0
    beq @solve_mode_0
    nop
    iwt r13, #@solve_mode_123
    jmp r13
    nop

@solve_mode_0:
    ; --- Mode 0 (Flat Horizontal Surface) ---
    ; du_dx = cos_yaw >> 6 (in Q8.8)
    frame_ptr compile_frame::cos_yaw, r7
    ldw (r7)            ; r0 = cos_yaw (Q2.14)
    with r0
    asr
    with r0
    asr
    with r0
    asr
    with r0
    asr
    with r0
    asr
    with r0
    asr                 ; r0 = cos_yaw >> 6
    move r8, r0         ; r8 = du_dx

    ; dv_dx = -(sin_yaw >> (14 - stride_shift)) in Q(16-S).S
    frame_ptr compile_frame::stride_shift, r7
    ldw (r7)            ; r0 = stride_shift (S)
    iwt r5, #14
    with r5
    sub r0              ; r5 = shift_count = 14 - S

    ; Check shift count before loading sin_yaw:
    from r5
    sub #0
    beq @shift_sin_zero
    nop
    blt @shift_sin_zero
    nop

    frame_ptr compile_frame::sin_yaw, r7
    ldw (r7)            ; r0 = sin_yaw (Q2.14)

    move r12, r5
    iwt r13, #@shift_sin_loop
@shift_sin_loop:
    with r0
    asr
    loop
    nop
    bra @shift_sin_done
    nop

@shift_sin_zero:
    frame_ptr compile_frame::sin_yaw, r7
    ldw (r7)

@shift_sin_done:
    ; Negate: dv_dx = -shifted_val
    with r0
    not
    inc r0
    move r9, r0         ; r9 = dv_dx

    ; Store du_dx and dv_dx in frame:
    frame_ptr compile_frame::du_dx, r7
    from r8
    stw (r7)            ; frame.du_dx
    inc r7
    inc r7
    from r9
    stw (r7)            ; frame.dv_dx
    iwt r13, #@gradients_solved
    jmp r13
    nop

@solve_mode_123:
    ; --- Modes 1, 2, 3 (Vertical Walls & Sloped Faces) ---
    ; Solve du_dx, dv_dx from widest horizontal span of Triangle 0 (V0, V1, V2).
    frame_ptr compile_frame::v0_x, r7
    frame_ptr compile_frame::t0_x, r8
    iwt r12, #12        ; 12 words = 3 vertices * 4 words
    iwt r13, #@copy_verts_loop
@copy_verts_loop:
    ldw (r7)
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    loop
    nop

    ; Sort T0, T1, T2 by Y (y0 <= y1 <= y2):
    frame_ptr compile_frame::sort_ret_flag, r7
    iwt r0, #0
    stw (r7)
    iwt r13, #@sort_t_mode
    jmp r13
    nop
@sorted_mode_ret:

    ; Find split point M on long edge T0-T2 at scanline y1:
    frame_ptr compile_frame::split_ret_flag, r7
    iwt r0, #0
    stw (r7)
    iwt r13, #@compute_split_m
    jmp r13
    nop
@split_m_mode_ret:

    ; Compute span at scanline y1:
    ; M is at (m_x, m_u, m_v); T1 is at (t1_x, t1_u, t1_v)
    frame_ptr compile_frame::t1_x, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::m_x, r7
    ldw (r7)
    move r2, r0

    ; Determine left vs right between T1 and M:
    from r1
    cmp r2
    blt @t1_is_left_grad
    nop

    ; M is Left, T1 is Right:
    ; delta_x = t1_x - m_x
    from r1
    sub r2
    move r3, r0         ; r3 = delta_x

    frame_ptr compile_frame::t1_u, r7
    ldw (r7)
    move r8, r0
    frame_ptr compile_frame::m_u, r7
    ldw (r7)
    with r8
    sub r0              ; r8 = delta_u = t1_u - m_u

    frame_ptr compile_frame::t1_v, r7
    ldw (r7)
    move r9, r0
    frame_ptr compile_frame::m_v, r7
    ldw (r7)
    with r9
    sub r0              ; r9 = delta_v = t1_v - m_v
    iwt r13, #@solve_uv_span
    jmp r13
    nop

@t1_is_left_grad:
    ; T1 is Left, M is Right:
    ; delta_x = m_x - t1_x
    from r2
    sub r1
    move r3, r0         ; r3 = delta_x

    frame_ptr compile_frame::m_u, r7
    ldw (r7)
    move r8, r0
    frame_ptr compile_frame::t1_u, r7
    ldw (r7)
    with r8
    sub r0              ; r8 = delta_u = m_u - t1_u

    frame_ptr compile_frame::m_v, r7
    ldw (r7)
    move r9, r0
    frame_ptr compile_frame::t1_v, r7
    ldw (r7)
    with r9
    sub r0              ; r9 = delta_v = m_v - t1_v

@solve_uv_span:
    ; If delta_x == 0: du_dx = 0, dv_dx = 0
    from r3
    sub #0
    bne @check_dx_1
    nop
    iwt r8, #0
    iwt r9, #0
    iwt r13, #@store_grad
    jmp r13
    nop
@check_dx_1:

    ; If delta_x == 1: du_dx = delta_u, dv_dx = delta_v
    from r3
    sub #1
    bne @check_dx_2
    nop
    iwt r13, #@store_grad
    jmp r13
    nop
@check_dx_2:

    ; If delta_x == 2: du_dx = delta_u >> 1, dv_dx = delta_v >> 1
    from r3
    sub #2
    bne @check_dx_general
    nop
    with r8
    asr
    with r9
    asr
    iwt r13, #@store_grad
    jmp r13
    nop
@check_dx_general:

    ; General delta_x >= 3: lookup 1/delta_x via reciprocal_lookup_rom
    reciprocal_lookup_rom r3, r6
    from r8
    to r8
    fmult               ; r8 = du_dx = delta_u * recip_dx in Q8.8
    from r9
    to r9
    fmult               ; r9 = dv_dx = delta_v * recip_dx in Q(16-S).S

@store_grad:
    frame_ptr compile_frame::du_dx, r7
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)

@gradients_solved:

    ; --------------------------------------------------------------------------
    ; 6. Process Triangle 0: (V0, V1, V2)
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::tri_index, r7
    iwt r0, #0
    stw (r7)            ; tri_index = 0

    ; Copy V0, V1, V2 into T0, T1, T2:
    frame_ptr compile_frame::v0_x, r7
    frame_ptr compile_frame::t0_x, r8
    iwt r12, #12
    iwt r13, #@copy_t0_loop
@copy_t0_loop:
    ldw (r7)
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    loop
    nop

    ; Process current triangle (T0, T1, T2):
    iwt r13, #@process_current_triangle
    jmp r13
    nop
@tri0_done:

    ; --------------------------------------------------------------------------
    ; 7. Check if Quad: Process Triangle 1: (V0, V2, V3)
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::flags, r7
    ldw (r7)            ; r0 = flags
    iwt r5, #FACE_DEF_FLAG_QUAD
    from r0
    and r5
    bne @process_tri1
    nop
    iwt r13, #@all_triangles_done
    jmp r13
    nop
@process_tri1:

    frame_ptr compile_frame::tri_index, r7
    iwt r0, #1
    stw (r7)            ; tri_index = 1

    ; Copy V0 into T0 (4 words):
    frame_ptr compile_frame::v0_x, r7
    frame_ptr compile_frame::t0_x, r8
    iwt r12, #4
    iwt r13, #@copy_v0_loop
@copy_v0_loop:
    ldw (r7)
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    loop
    nop

    ; Copy V2 into T1 (4 words):
    frame_ptr compile_frame::v2_x, r7
    frame_ptr compile_frame::t1_x, r8
    iwt r12, #4
    iwt r13, #@copy_v2_loop
@copy_v2_loop:
    ldw (r7)
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    loop
    nop

    ; Copy V3 into T2 (4 words):
    frame_ptr compile_frame::v3_x, r7
    frame_ptr compile_frame::t2_x, r8
    iwt r12, #4
    iwt r13, #@copy_v3_loop
@copy_v3_loop:
    ldw (r7)
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    loop
    nop

    ; Process current triangle (T0, T1, T2):
    iwt r13, #@process_current_triangle
    jmp r13
    nop
@tri1_done:

@all_triangles_done:
    ; Read total trap_count
    frame_ptr compile_frame::trap_count, r7
    ldw (r7)
    to num_traps_emitted
    move num_traps_emitted, r0
    move r0, num_traps_emitted
    return num_traps_emitted

@cull_face:
    iwt num_traps_emitted, #0
    move r0, num_traps_emitted
    return num_traps_emitted

; ==============================================================================
; Internal Subroutine: Sort T0, T1, T2 by Y coordinate (y0 <= y1 <= y2)
; ==============================================================================
@sort_t_mode:
@sort_current_t:
    ; Pass 1: if T0.y > T1.y, swap T0 and T1
    frame_ptr compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0         ; r1 = t0_y
    frame_ptr compile_frame::t1_y, r7
    ldw (r7)
    move r2, r0         ; r2 = t1_y
    from r2
    cmp r1
    bge @skip_swap1
    nop
    ; Swap T0 and T1:
    frame_ptr compile_frame::t0_x, r7
    frame_ptr compile_frame::t1_x, r8
    iwt r12, #@skip_swap1
    iwt r13, #@swap_4words
    jmp r13
    nop
@skip_swap1:

    ; Pass 2: if T1.y > T2.y, swap T1 and T2
    frame_ptr compile_frame::t1_y, r7
    ldw (r7)
    move r1, r0         ; r1 = t1_y
    frame_ptr compile_frame::t2_y, r7
    ldw (r7)
    move r2, r0         ; r2 = t2_y
    from r2
    cmp r1
    bge @skip_swap2
    nop
    ; Swap T1 and T2:
    frame_ptr compile_frame::t1_x, r7
    frame_ptr compile_frame::t2_x, r8
    iwt r12, #@skip_swap2
    iwt r13, #@swap_4words
    jmp r13
    nop
@skip_swap2:

    ; Pass 3: if T0.y > T1.y, swap T0 and T1
    frame_ptr compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::t1_y, r7
    ldw (r7)
    move r2, r0
    from r2
    cmp r1
    bge @skip_swap3
    nop
    ; Swap T0 and T1:
    frame_ptr compile_frame::t0_x, r7
    frame_ptr compile_frame::t1_x, r8
    iwt r12, #@skip_swap3
    iwt r13, #@swap_4words
    jmp r13
    nop
@skip_swap3:

    ; Return from sort:
    frame_ptr compile_frame::sort_ret_flag, r7
    ldw (r7)
    from r0
    sub #0
    bne @ret_proc_tri
    nop
    iwt r13, #@sorted_mode_ret
    jmp r13
    nop
@ret_proc_tri:
    iwt r13, #@t_sorted_proc
    jmp r13
    nop

; Swaps 4 words at r7 with 4 words at r8, then jumps to r12:
@swap_4words:
    ldw (r7)
    move r1, r0
    ldw (r8)
    stw (r7)
    from r1
    stw (r8)

    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)
    move r1, r0
    ldw (r8)
    stw (r7)
    from r1
    stw (r8)

    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)
    move r1, r0
    ldw (r8)
    stw (r7)
    from r1
    stw (r8)

    inc r7
    inc r7
    inc r8
    inc r8
    ldw (r7)
    move r1, r0
    ldw (r8)
    stw (r7)
    from r1
    stw (r8)

    jmp r12
    nop

; ==============================================================================
; Internal Subroutine: Compute Split Point M on Edge T0-T2 at Scanline Y1
; ==============================================================================
@compute_split_m:
    frame_ptr compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0         ; r1 = y0
    frame_ptr compile_frame::t1_y, r7
    ldw (r7)
    move r2, r0         ; r2 = y1
    frame_ptr compile_frame::t2_y, r7
    ldw (r7)
    move r3, r0         ; r3 = y2

    ; dy_long = y2 - y0
    from r3
    sub r1
    move r5, r0         ; r5 = dy_long

    ; dy1 = y1 - y0
    from r2
    sub r1
    move r8, r0         ; r8 = dy1

    ; Check if dy1 == 0 (y1 == y0, flat top):
    from r8
    sub #0
    bne @check_y1_y2
    nop
    ; M = T0:
    frame_ptr compile_frame::t0_x, r7
    ldw (r7)
    move r1, r0
    inc r7
    inc r7              ; t0_y
    inc r7
    inc r7              ; t0_u
    ldw (r7)
    move r2, r0
    inc r7
    inc r7              ; t0_v
    ldw (r7)
    move r3, r0

    frame_ptr compile_frame::m_x, r7
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)
    inc r7
    inc r7
    from r3
    stw (r7)
    iwt r13, #@split_m_done
    jmp r13
    nop

@check_y1_y2:
    ; Check if y1 == y2 (flat bottom):
    from r2
    cmp r3
    bne @general_split_m
    nop
    ; M = T2:
    frame_ptr compile_frame::t2_x, r7
    ldw (r7)
    move r1, r0
    inc r7
    inc r7              ; t2_y
    inc r7
    inc r7              ; t2_u
    ldw (r7)
    move r2, r0
    inc r7
    inc r7              ; t2_v
    ldw (r7)
    move r3, r0

    frame_ptr compile_frame::m_x, r7
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)
    inc r7
    inc r7
    from r3
    stw (r7)
    iwt r13, #@split_m_done
    jmp r13
    nop

@general_split_m:
    ; General case: 0 < dy1 < dy_long:
    ; Lookup reciprocal 1/dy_long:
    reciprocal_lookup_rom r5, r6 ; r6 = 1/dy_long in Q0.16
    from r8
    to r7
    lmult               ; r7:r4_reg = dy1 * recip
    move r6, r4         ; r6 = t in Q0.16 (since r8 < r5, r7 is 0)

    ; m_x = t0_x + fmult(t2_x - t0_x, t):
    frame_ptr compile_frame::t2_x, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::t0_x, r7
    ldw (r7)
    move r2, r0
    from r1
    sub r2              ; r0 = t2_x - t0_x
    from r0
    to r0
    fmult               ; r0 = delta_x * t
    with r0
    add r2              ; r0 = m_x
    frame_ptr compile_frame::m_x, r7
    stw (r7)            ; frame.m_x = m_x

    ; m_u = t0_u + fmult(t2_u - t0_u, t):
    frame_ptr compile_frame::t2_u, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::t0_u, r7
    ldw (r7)
    move r2, r0
    from r1
    sub r2              ; delta_u
    from r0
    to r0
    fmult
    with r0
    add r2              ; m_u
    frame_ptr compile_frame::m_u, r7
    stw (r7)

    ; m_v = t0_v + fmult(t2_v - t0_v, t):
    frame_ptr compile_frame::t2_v, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::t0_v, r7
    ldw (r7)
    move r2, r0
    from r1
    sub r2              ; delta_v
    from r0
    to r0
    fmult
    with r0
    add r2              ; m_v
    frame_ptr compile_frame::m_v, r7
    stw (r7)

@split_m_done:
    frame_ptr compile_frame::split_ret_flag, r7
    ldw (r7)
    from r0
    sub #0
    bne @ret_proc_split
    nop
    iwt r13, #@split_m_mode_ret
    jmp r13
    nop
@ret_proc_split:
    iwt r13, #@m_computed_proc
    jmp r13
    nop

; ==============================================================================
; Internal Subroutine: Process Current Triangle (T0, T1, T2)
; ==============================================================================
@process_current_triangle:
    ; 1. Sort T0, T1, T2 by Y
    frame_ptr compile_frame::sort_ret_flag, r7
    iwt r0, #1
    stw (r7)
    iwt r13, #@sort_current_t
    jmp r13
    nop
@t_sorted_proc:

    ; 2. Check if entire triangle has height 0 (t0_y == t2_y)
    frame_ptr compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::t2_y, r7
    ldw (r7)
    from r1
    cmp r0
    bne @triangle_has_height
    nop
    ; Height is 0! Skip triangle entirely:
    iwt r13, #@finish_current_triangle
    jmp r13
    nop
@triangle_has_height:

    ; 3. Compute Split Point M on Edge T0-T2 at Scanline Y1
    frame_ptr compile_frame::split_ret_flag, r7
    iwt r0, #1
    stw (r7)
    iwt r13, #@compute_split_m
    jmp r13
    nop
@m_computed_proc:

    ; 4. Determine whether T1 is Left or Right: is_t1_left = (t1_x < m_x)
    frame_ptr compile_frame::t1_x, r7
    ldw (r7)
    move r1, r0
    frame_ptr compile_frame::m_x, r7
    ldw (r7)
    move r2, r0

    from r1
    cmp r2
    blt @t1_is_left
    nop
    ; T1 is Right:
    iwt r0, #0
    frame_ptr compile_frame::is_t1_left, r7
    stw (r7)
    iwt r13, #@is_t1_left_done
    jmp r13
    nop
@t1_is_left:
    iwt r0, #1
    frame_ptr compile_frame::is_t1_left, r7
    stw (r7)
@is_t1_left_done:

    ; --------------------------------------------------------------------------
    ; 5. Emit Top Half [y0, y1):
    ;    h_top = y1 - y0
    ;    If h_top == 0: suppress top half!
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0         ; r1 = y0 = dy_start
    frame_ptr compile_frame::t1_y, r7
    ldw (r7)
    move r2, r0         ; r2 = y1

    from r2
    sub r1
    move r3, r0         ; r3 = h_top = y1 - y0
    bne @top_half_has_height
    nop
    iwt r13, #@top_half_suppressed
    jmp r13
    nop
@top_half_has_height:

    ; Top vertex is T0:
    frame_ptr compile_frame::t0_x, r7
    ldw (r7)
    move r5, r0         ; r5 = xTL = t0_x
    move r6, r0         ; r6 = xTR = t0_x

    frame_ptr compile_frame::t0_u, r7
    ldw (r7)
    move r7, r0
    frame_ptr compile_frame::t0_v, r8
    ldw (r8)
    move r8, r0

    ; Bottom vertices at y1:
    frame_ptr compile_frame::is_t1_left, r9
    ldw (r9)
    from r0
    sub #0
    bne @top_t1_left
    nop

    ; T1 is Right, M is Left:
    ; xBL = m_x, uBL = m_u, vBL = m_v
    ; xBR = t1_x
    frame_ptr compile_frame::m_x, r9
    ldw (r9)
    move r9, r0

    frame_ptr compile_frame::t1_x, r11
    ldw (r11)
    move r12, r0

    frame_ptr compile_frame::m_u, r11
    ldw (r11)
    move r13, r0

    frame_ptr compile_frame::m_v, r11
    ldw (r11)
    move r14, r0
    iwt r11, #@emit_top_trap
    jmp r11
    nop

@top_t1_left:
    ; T1 is Left, M is Right:
    ; xBL = t1_x, uBL = t1_u, vBL = t1_v
    ; xBR = m_x
    frame_ptr compile_frame::t1_x, r9
    ldw (r9)
    move r9, r0

    frame_ptr compile_frame::m_x, r11
    ldw (r11)
    move r12, r0

    frame_ptr compile_frame::t1_u, r11
    ldw (r11)
    move r13, r0

    frame_ptr compile_frame::t1_v, r11
    ldw (r11)
    move r14, r0

@emit_top_trap:
    ; Parameters to emit:
    ;   r1  = dy_start
    ;   r3  = line_count (h)
    ;   r5  = xTL
    ;   r6  = xTR
    ;   r9  = xBL
    ;   r12 = xBR
    ;   r7  = uTL
    ;   r8  = vTL
    ;   r13 = uBL
    ;   r14 = vBL
    frame_ptr compile_frame::half_index, r7
    iwt r0, #0
    stw (r7)
    iwt r11, #@emit_half_logic
    jmp r11
    nop
@top_trap_emitted:

@top_half_suppressed:

    ; --------------------------------------------------------------------------
    ; 6. Emit Bottom Half [y1, y2):
    ;    h_bot = y2 - y1
    ;    If h_bot == 0: suppress bottom half!
    ; --------------------------------------------------------------------------
    frame_ptr compile_frame::t1_y, r7
    ldw (r7)
    move r1, r0         ; r1 = y1 = dy_start
    frame_ptr compile_frame::t2_y, r7
    ldw (r7)
    move r2, r0         ; r2 = y2

    from r2
    sub r1
    move r3, r0         ; r3 = h_bot = y2 - y1
    bne @bot_half_has_height
    nop
    iwt r13, #@bottom_half_suppressed
    jmp r13
    nop
@bot_half_has_height:

    ; Top vertices at y1:
    frame_ptr compile_frame::is_t1_left, r9
    ldw (r9)
    from r0
    sub #0
    bne @bot_t1_left
    nop

    ; T1 is Right, M is Left:
    ; xTL = m_x, uTL = m_u, vTL = m_v
    ; xTR = t1_x
    frame_ptr compile_frame::m_x, r9
    ldw (r9)
    move r5, r0

    frame_ptr compile_frame::t1_x, r9
    ldw (r9)
    move r6, r0

    frame_ptr compile_frame::m_u, r9
    ldw (r9)
    move r7, r0

    frame_ptr compile_frame::m_v, r9
    ldw (r9)
    move r8, r0
    iwt r11, #@bot_top_verts_set
    jmp r11
    nop

@bot_t1_left:
    ; T1 is Left, M is Right:
    ; xTL = t1_x, uTL = t1_u, vTL = t1_v
    ; xTR = m_x
    frame_ptr compile_frame::t1_x, r9
    ldw (r9)
    move r5, r0

    frame_ptr compile_frame::m_x, r9
    ldw (r9)
    move r6, r0

    frame_ptr compile_frame::t1_u, r9
    ldw (r9)
    move r7, r0

    frame_ptr compile_frame::t1_v, r9
    ldw (r9)
    move r8, r0

@bot_top_verts_set:
    ; Bottom vertex is T2:
    ; xBL = t2_x, xBR = t2_x
    ; uBL = t2_u, vBL = t2_v
    frame_ptr compile_frame::t2_x, r9
    ldw (r9)
    move r9, r0         ; r9 = xBL = t2_x
    move r12, r0        ; r12 = xBR = t2_x

    frame_ptr compile_frame::t2_u, r11
    ldw (r11)
    move r13, r0

    frame_ptr compile_frame::t2_v, r11
    ldw (r11)
    move r14, r0

    ; Parameters to emit:
    ;   r1  = dy_start
    ;   r3  = line_count (h)
    ;   r5  = xTL
    ;   r6  = xTR
    ;   r9  = xBL
    ;   r12 = xBR
    ;   r7  = uTL
    ;   r8  = vTL
    ;   r13 = uBL
    ;   r14 = vBL
    frame_ptr compile_frame::half_index, r7
    iwt r0, #1
    stw (r7)
    iwt r11, #@emit_half_logic
    jmp r11
    nop
@bot_trap_emitted:

@bottom_half_suppressed:

@finish_current_triangle:
    frame_ptr compile_frame::tri_index, r7
    ldw (r7)
    from r0
    sub #0
    beq @ret_tri0
    nop
    iwt r13, #@tri1_done
    jmp r13
    nop
@ret_tri0:
    iwt r13, #@tri0_done
    jmp r13
    nop

; ==============================================================================
; Internal Subroutine: Emit Half Trapezoid & Write to curr_out_ptr
;
; In:
;   r1  = dy_start
;   r3  = line_count (h)
;   r5  = xTL
;   r6  = xTR
;   r9  = xBL
;   r12 = xBR
;   r7  = uTL
;   r8  = vTL
;   r13 = uBL
;   r14 = vBL
; ==============================================================================
@emit_half_logic:
    ; delta_xL = xBL - xTL = r9 - r5
    from r9
    sub r5
    move r9, r0         ; r9 = delta_xL (integer pixels)

    ; delta_xR = xBR - xTR = r12 - r6
    from r12
    sub r6
    move r12, r0        ; r12 = delta_xR (integer pixels)

    ; delta_u = uBL - uTL = r13 - r7
    from r13
    sub r7
    move r13, r0        ; r13 = delta_u (Q8.8)

    ; delta_v = vBL - vTL = r14 - r8
    from r14
    sub r8
    move r14, r0        ; r14 = delta_v (Q(16-S).S)

    ; Convert delta_xL and delta_xR to Q8.8 (<< 8):
    to r2
    from r9
    swap
    iwt r5, #$FF00
    with r2
    and r5              ; r2 = delta_xL in Q8.8

    to r9
    from r12
    swap
    with r9
    and r5              ; r9 = delta_xR in Q8.8

    ; Check height r3 (line_count):
    from r3
    sub #1
    beq @h_is_1
    nop

    from r3
    sub #2
    beq @h_is_2
    nop

    ; General h >= 3:
    move r8, r14
    reciprocal_lookup_rom r3, r6 ; r6 = 1/h in Q0.16
    from r2
    to r2
    fmult               ; r2 = dxL_dy = fmult(delta_xL, recip_h)

    from r9
    to r9
    fmult               ; r9 = dxR_dy = fmult(delta_xR, recip_h)

    from r13
    to r13
    fmult               ; r13 = du_dy = fmult(delta_u, recip_h)

    from r8
    to r14
    fmult               ; r14 = dv_dy = fmult(delta_v, recip_h)
    iwt r11, #@slopes_computed
    jmp r11
    nop

@h_is_1:
    ; h == 1: slopes equal numerators!
    ; r2 is dxL_dy, r9 is dxR_dy, r13 is du_dy, r14 is dv_dy
    iwt r11, #@slopes_computed
    jmp r11
    nop

@h_is_2:
    ; h == 2: asr 1
    with r2
    asr
    with r9
    asr
    with r13
    asr
    with r14
    asr

@slopes_computed:
    ; Convert xTL (r5) and xTR (r6) to Q8.8:
    ; r5 was xTL, r6 was xTR (we preserved or need to reload them):
    ; Note: r5 was clobbered by iwt r5, #$FF00 above!
    ; Let's re-read xTL and xTR from parameters:
    ; If top half: xTL was T0.x, xTR was T0.x.
    ; If bottom half: xTL was m_x / t1_x, xTR was t1_x / m_x.
    ; Wait! We can restore xTL and xTR:
    ; Check half_index: 0 = top half, 1 = bottom half:
    frame_ptr compile_frame::half_index, r7
    ldw (r7)
    from r0
    sub #0
    bne @reload_bot_xt
    nop

    ; Top half: xTL = t0_x, xTR = t0_x
    frame_ptr compile_frame::t0_x, r7
    ldw (r7)
    to r5
    from r0
    swap
    iwt r8, #$FF00
    with r5
    and r8              ; r5 = xL_start (Q8.8)
    move r6, r5         ; r6 = xR_start (Q8.8)

    ; uTL = t0_u, vTL = t0_v
    frame_ptr compile_frame::t0_u, r7
    ldw (r7)
    move r7, r0         ; r7 = uL_start
    frame_ptr compile_frame::t0_v, r8
    ldw (r8)
    move r8, r0         ; r8 = vL_start
    iwt r11, #@write_trap_fields
    jmp r11
    nop

@reload_bot_xt:
    ; Bottom half:
    frame_ptr compile_frame::is_t1_left, r7
    ldw (r7)
    from r0
    sub #0
    bne @bot_t1_left_reload
    nop

    ; T1 is Right, M is Left: xTL = m_x, xTR = t1_x, uTL = m_u, vTL = m_v
    frame_ptr compile_frame::m_x, r7
    ldw (r7)
    to r5
    from r0
    swap
    iwt r8, #$FF00
    with r5
    and r8              ; r5 = xL_start

    frame_ptr compile_frame::t1_x, r7
    ldw (r7)
    to r6
    from r0
    swap
    with r6
    and r8              ; r6 = xR_start

    frame_ptr compile_frame::m_u, r7
    ldw (r7)
    move r7, r0         ; r7 = uL_start

    frame_ptr compile_frame::m_v, r8
    ldw (r8)
    move r8, r0         ; r8 = vL_start
    iwt r11, #@write_trap_fields
    jmp r11
    nop

@bot_t1_left_reload:
    ; T1 is Left, M is Right: xTL = t1_x, xTR = m_x, uTL = t1_u, vTL = t1_v
    frame_ptr compile_frame::t1_x, r7
    ldw (r7)
    to r5
    from r0
    swap
    iwt r8, #$FF00
    with r5
    and r8              ; r5 = xL_start

    frame_ptr compile_frame::m_x, r7
    ldw (r7)
    to r6
    from r0
    swap
    with r6
    and r8              ; r6 = xR_start

    frame_ptr compile_frame::t1_u, r7
    ldw (r7)
    move r7, r0         ; r7 = uL_start

    frame_ptr compile_frame::t1_v, r8
    ldw (r8)
    move r8, r0         ; r8 = vL_start

@write_trap_fields:
    ; Load curr_out_ptr:
    frame_ptr compile_frame::curr_out_ptr, r11
    ldw (r11)
    move r11, r0

    ; Write cached_trap struct fields:
    ; +0: dy_start (r1)
    from r1
    stw (r11)

    ; +2: line_count (r3)
    inc r11
    inc r11
    from r3
    stw (r11)

    ; +4: xL_start (r5)
    inc r11
    inc r11
    from r5
    stw (r11)

    ; +6: xR_start (r6)
    inc r11
    inc r11
    from r6
    stw (r11)

    ; +8: dxL_dy (r2)
    inc r11
    inc r11
    from r2
    stw (r11)

    ; +10: dxR_dy (r9)
    inc r11
    inc r11
    from r9
    stw (r11)

    ; +12: uL_start (r7)
    inc r11
    inc r11
    from r7
    stw (r11)

    ; +14: vL_start (r8)
    inc r11
    inc r11
    from r8
    stw (r11)

    ; +16: du_dy (r13)
    inc r11
    inc r11
    from r13
    stw (r11)

    ; +18: dv_dy (r14)
    inc r11
    inc r11
    from r14
    stw (r11)

    ; +20: du_dx (from frame.du_dx)
    frame_ptr compile_frame::du_dx, r7
    ldw (r7)
    inc r11
    inc r11
    from r0
    stw (r11)

    ; +22: dv_dx (from frame.dv_dx)
    inc r7
    inc r7
    ldw (r7)
    inc r11
    inc r11
    from r0
    stw (r11)

    ; +24: tex_id (from frame.tex_id)
    frame_ptr compile_frame::tex_id, r7
    ldw (r7)
    inc r11
    inc r11
    from r0
    stw (r11)

    ; Advance curr_out_ptr (+26 bytes):
    inc r11
    inc r11
    frame_ptr compile_frame::curr_out_ptr, r7
    from r11
    stw (r7)

    ; Increment trap_count (+1):
    frame_ptr compile_frame::trap_count, r7
    ldw (r7)
    inc r0
    stw (r7)

    ; Check whether returning to top half or bottom half:
    frame_ptr compile_frame::half_index, r7
    ldw (r7)
    from r0
    sub #0
    beq @ret_from_top
    nop
    iwt r11, #@bot_trap_emitted
    jmp r11
    nop
@ret_from_top:
    iwt r11, #@top_trap_emitted
    jmp r11
    nop

endfunction

.endif ; ::__COMPILE_FACE_TRAPS_DEFINED__
