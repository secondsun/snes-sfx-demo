; ==============================================================================
; compile_flat_tri.i - Flat-Shaded 2D Triangle -> Flat Trapezoid Compiler
;
; Matches `compile_face_traps.i`'s exact 32-bit CW backface test, Y-sort, and
; Q8.8 sub-pixel long-edge split (`m_xq`) so adjacent flat and textured polygons
; share bit-identical interior edges with zero scanline cracks.
; ==============================================================================

.ifndef __GSU_MESH_COMPILE_FLAT_TRI__
__GSU_MESH_COMPILE_FLAT_TRI__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"
.include "../gsu_maths/gsu_recip.i"
.include "mesh_layout.i"

.struct flat_compile_frame
    curr_out_ptr    .word   ; +0
    trap_count      .word   ; +2
    t0_x            .word   ; +4
    t0_y            .word   ; +6
    t1_x            .word   ; +8
    t1_y            .word   ; +10
    t2_x            .word   ; +12
    t2_y            .word   ; +14
    m_x             .word   ; +16
    m_xq            .word   ; +18
    is_t1_left      .word   ; +20
    half_index      .word   ; +22
.endstruct

.segment "GSURAM"
.align 2
gsu_flat_compile_frame: .res .sizeof(flat_compile_frame)

.macro flat_fptr off, dest
    iwt dest, #(gsu_flat_compile_frame + off)
.endmacro

.segment "GSUCODE"

; ==============================================================================
; compile_flat_tri
; Compiles a 2D relative triangle (x0,y0, x1,y1, x2,y2) into 0..2 `flat_trap`s.
;
; In:
;   tri_pts_ptr   = r1: Pointer to 6 signed words (x0,y0, x1,y1, x2,y2), |coord| < 128
;   out_traps_ptr = r2: Destination `flat_trap` array in Bank $70 GSURAM
;
; Out:
;   r0 / r3 = trap_count (0 if culled or degenerate height, else 1..2)
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function compile_flat_tri
    ; Save output pointer and initialize trap_count = 0
    flat_fptr flat_compile_frame::curr_out_ptr, r7
    from r2
    stw (r7)
    flat_fptr flat_compile_frame::trap_count, r7
    ibt r0, #0
    stw (r7)

    ; Copy 6 words (x0,y0, x1,y1, x2,y2) into t0_x..t2_y
    flat_fptr flat_compile_frame::t0_x, r8
    ibt r12, #6
    iwt r13, #@copy_pts
@copy_pts:
    ldw (r1)
    stw (r8)
    inc r1
    inc r1
    inc r8
    inc r8
    loop
    nop

    ; 1. 32-bit CW Backface Culling:
    ;    cross = (x1 - x0)*(y2 - y0) - (y1 - y0)*(x2 - x0) > 0
    flat_fptr flat_compile_frame::t0_x, r7
    ldw (r7)
    move r8, r0             ; r8 = x0
    inc r7
    inc r7
    ldw (r7)
    move r9, r0             ; r9 = y0

    inc r7
    inc r7
    ldw (r7)
    with r0
    sub r8
    move r1, r0             ; r1 = dx1 = x1 - x0
    inc r7
    inc r7
    ldw (r7)
    with r0
    sub r9
    move r2, r0             ; r2 = dy1 = y1 - y0

    inc r7
    inc r7
    ldw (r7)
    with r0
    sub r8
    move r3, r0             ; r3 = dx2 = x2 - x0
    inc r7
    inc r7
    ldw (r7)
    with r0
    sub r9
    move r5, r0             ; r5 = dy2 = y2 - y0

    move r6, r5
    from r1
    to r7
    lmult                   ; r7:r4 = dx1 * dy2
    move r8, r4             ; r7:r8 = term1 (hi:lo)

    move r6, r3
    from r2
    to r1
    lmult                   ; r1:r4 = dy1 * dx2
    move r2, r4             ; r1:r2 = term2 (hi:lo)

    from r7
    cmp r1
    bge :+
    nop
    iwt r13, #@cull_flat
    jmp r13
    nop
:
    from r1
    cmp r7
    bge :+
    nop
    bra @winding_ok
    nop
:
    from r8
    cmp r2
    bne :+
    nop
    iwt r13, #@cull_flat
    jmp r13
    nop
:
    bcs @winding_ok
    nop
    iwt r13, #@cull_flat
    jmp r13
    nop

@winding_ok:
    ; 2. Sort (T0, T1, T2) by Y ascending (t0_y <= t1_y <= t2_y)
    ; Pass 1: T0 vs T1
    flat_fptr flat_compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0
    flat_fptr flat_compile_frame::t1_y, r7
    ldw (r7)
    from r0
    cmp r1
    bge @s1_done
    nop
    flat_fptr flat_compile_frame::t0_x, r7
    flat_fptr flat_compile_frame::t1_x, r8
    to r1
    ldw (r7)
    to r2
    ldw (r8)
    from r2
    stw (r7)
    from r1
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    to r1
    ldw (r7)
    to r2
    ldw (r8)
    from r2
    stw (r7)
    from r1
    stw (r8)
@s1_done:

    ; Pass 2: T1 vs T2
    flat_fptr flat_compile_frame::t1_y, r7
    ldw (r7)
    move r1, r0
    flat_fptr flat_compile_frame::t2_y, r7
    ldw (r7)
    from r0
    cmp r1
    bge @s2_done
    nop
    flat_fptr flat_compile_frame::t1_x, r7
    flat_fptr flat_compile_frame::t2_x, r8
    to r1
    ldw (r7)
    to r2
    ldw (r8)
    from r2
    stw (r7)
    from r1
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    to r1
    ldw (r7)
    to r2
    ldw (r8)
    from r2
    stw (r7)
    from r1
    stw (r8)
@s2_done:

    ; Pass 3: T0 vs T1
    flat_fptr flat_compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0
    flat_fptr flat_compile_frame::t1_y, r7
    ldw (r7)
    from r0
    cmp r1
    bge @s3_done
    nop
    flat_fptr flat_compile_frame::t0_x, r7
    flat_fptr flat_compile_frame::t1_x, r8
    to r1
    ldw (r7)
    to r2
    ldw (r8)
    from r2
    stw (r7)
    from r1
    stw (r8)
    inc r7
    inc r7
    inc r8
    inc r8
    to r1
    ldw (r7)
    to r2
    ldw (r8)
    from r2
    stw (r7)
    from r1
    stw (r8)
@s3_done:

    ; 3. Height check & long-edge split point M at scanline t1_y
    flat_fptr flat_compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0             ; r1 = t0_y
    flat_fptr flat_compile_frame::t1_y, r7
    ldw (r7)
    move r2, r0             ; r2 = t1_y
    flat_fptr flat_compile_frame::t2_y, r7
    ldw (r7)
    move r3, r0             ; r3 = t2_y

    from r3
    sub r1
    move r5, r0             ; r5 = dy_long = t2_y - t0_y
    beq @cull_jump
    nop
    bmi @cull_jump
    nop
    bra @height_ok
    nop
@cull_jump:
    iwt r13, #@cull_flat
    jmp r13
    nop

@height_ok:
    from r2
    sub r1
    move r8, r0             ; r8 = dy1 = t1_y - t0_y
    bne @check_flat_bot
    nop
    ; Flat top (t1_y == t0_y): M = T0
    flat_fptr flat_compile_frame::t0_x, r7
    ldw (r7)
    flat_fptr flat_compile_frame::m_x, r7
    stw (r7)
    cft_to_q88
    inc r7
    inc r7
    stw (r7)                ; m_xq = t0_x << 8
    iwt r13, #@split_done
    jmp r13
    nop

@check_flat_bot:
    from r2
    cmp r3
    bne @general_split
    nop
    ; Flat bottom (t1_y == t2_y): M = T2
    flat_fptr flat_compile_frame::t2_x, r7
    ldw (r7)
    flat_fptr flat_compile_frame::m_x, r7
    stw (r7)
    cft_to_q88
    inc r7
    inc r7
    stw (r7)                ; m_xq = t2_x << 8
    iwt r13, #@split_done
    jmp r13
    nop

@general_split:
    reciprocal_lookup_rom r5, r6 ; r6 = 1/dy_long (Q0.16)
    from r8
    to r7
    lmult
    move r6, r4             ; r6 = t in Q0.16

    flat_fptr flat_compile_frame::t2_x, r7
    ldw (r7)
    move r1, r0
    flat_fptr flat_compile_frame::t0_x, r7
    ldw (r7)
    move r2, r0

    from r6
    sub #0
    bmi @split_high_t
    nop

    ; t < 0.5: m_x = t0_x + fmult(t2_x - t0_x, t), m_xq = (t0_x << 8) + fmult((t2_x - t0_x) << 8, t)
    from r1
    sub r2
    fmult
    add r2
    flat_fptr flat_compile_frame::m_x, r7
    stw (r7)

    from r1
    sub r2
    cft_to_q88
    fmult
    move r3, r0
    move r0, r2
    cft_to_q88
    add r3
    flat_fptr flat_compile_frame::m_xq, r7
    stw (r7)
    bra @split_done
    nop

@split_high_t:
    ; t >= 0.5: m_x = t2_x + fmult(t2_x - t0_x, t), m_xq = (t2_x << 8) + fmult((t2_x - t0_x) << 8, t)
    from r1
    sub r2
    fmult
    add r1
    flat_fptr flat_compile_frame::m_x, r7
    stw (r7)

    from r1
    sub r2
    cft_to_q88
    fmult
    move r3, r0
    move r0, r1
    cft_to_q88
    add r3
    flat_fptr flat_compile_frame::m_xq, r7
    stw (r7)

@split_done:
    ; Determine is_t1_left = (t1_x < m_x)
    flat_fptr flat_compile_frame::t1_x, r7
    ldw (r7)
    move r1, r0
    flat_fptr flat_compile_frame::m_x, r7
    ldw (r7)
    move r2, r0
    ibt r0, #0
    from r1
    cmp r2
    bge :+
    nop
    ibt r0, #1
:
    flat_fptr flat_compile_frame::is_t1_left, r7
    stw (r7)

    ; 4. Emit Top Half [t0_y, t1_y)
    flat_fptr flat_compile_frame::t0_y, r7
    ldw (r7)
    move r1, r0             ; r1 = dy_start = t0_y
    flat_fptr flat_compile_frame::t1_y, r7
    ldw (r7)
    sub r1
    move r3, r0             ; r3 = h_top
    bne :+
    nop
    iwt r13, #@top_done
    jmp r13
    nop
:
    flat_fptr flat_compile_frame::t0_x, r7
    ldw (r7)
    cft_to_q88
    move r5, r0             ; xTL
    move r6, r0             ; xTR

    flat_fptr flat_compile_frame::is_t1_left, r7
    ldw (r7)
    from r0
    sub #0
    bne @top_t1_left
    nop

    ; M is Left, T1 is Right
    flat_fptr flat_compile_frame::m_xq, r7
    ldw (r7)
    move r9, r0             ; xBL
    flat_fptr flat_compile_frame::t1_x, r7
    ldw (r7)
    cft_to_q88
    move r12, r0            ; xBR
    bra @top_emit
    nop

@top_t1_left:
    flat_fptr flat_compile_frame::t1_x, r7
    ldw (r7)
    cft_to_q88
    move r9, r0             ; xBL
    flat_fptr flat_compile_frame::m_xq, r7
    ldw (r7)
    move r12, r0            ; xBR

@top_emit:
    flat_fptr flat_compile_frame::half_index, r11
    ibt r0, #0
    stw (r11)
    iwt r11, #@emit_flat_half
    jmp r11
    nop
@top_done:

    ; 5. Emit Bottom Half [t1_y, t2_y)
    flat_fptr flat_compile_frame::t1_y, r7
    ldw (r7)
    move r1, r0             ; r1 = dy_start = t1_y
    flat_fptr flat_compile_frame::t2_y, r7
    ldw (r7)
    sub r1
    move r3, r0             ; r3 = h_bot
    beq @all_done
    nop

    flat_fptr flat_compile_frame::is_t1_left, r7
    ldw (r7)
    from r0
    sub #0
    bne @bot_t1_left
    nop

    flat_fptr flat_compile_frame::m_xq, r7
    ldw (r7)
    move r5, r0             ; xTL = m_xq
    flat_fptr flat_compile_frame::t1_x, r7
    ldw (r7)
    cft_to_q88
    move r6, r0             ; xTR = t1_x << 8
    bra @bot_x_bot
    nop

@bot_t1_left:
    flat_fptr flat_compile_frame::t1_x, r7
    ldw (r7)
    cft_to_q88
    move r5, r0             ; xTL = t1_x << 8
    flat_fptr flat_compile_frame::m_xq, r7
    ldw (r7)
    move r6, r0             ; xTR = m_xq

@bot_x_bot:
    flat_fptr flat_compile_frame::t2_x, r7
    ldw (r7)
    cft_to_q88
    move r9, r0             ; xBL = t2_x << 8
    move r12, r0            ; xBR = t2_x << 8

    flat_fptr flat_compile_frame::half_index, r11
    ibt r0, #1
    stw (r11)
    iwt r11, #@emit_flat_half
    jmp r11
    nop
@bot_done:

@all_done:
    flat_fptr flat_compile_frame::trap_count, r7
    ldw (r7)
    move r3, r0
    return

@cull_flat:
    ibt r3, #0
    ibt r0, #0
    return

; ==============================================================================
; Emit Half Flat Trapezoid
;   r1=dy_start, r3=line_count, r5=xTL, r6=xTR, r9=xBL, r12=xBR
; ==============================================================================
@emit_flat_half:
    from r9
    sub r5
    move r2, r0             ; r2 = delta_xL (Q8.8)

    from r12
    sub r6
    move r9, r0             ; r9 = delta_xR (Q8.8)

    from r3
    sub #1
    beq @fh_1
    nop
    from r3
    sub #2
    beq @fh_2
    nop

    ; General h >= 3: preserve r6 (xTR) in r12 across reciprocal_lookup_rom
    move r12, r6
    reciprocal_lookup_rom r3, r6 ; r6 = 1/h (Q0.16)
    from r2
    to r2
    fmult
    from r9
    to r9
    fmult
    move r6, r12
    bra @fh_write
    nop

@fh_1:
    bra @fh_write
    nop

@fh_2:
    with r2
    asr
    with r9
    asr

@fh_write:
    flat_fptr flat_compile_frame::curr_out_ptr, r11
    ldw (r11)
    move r11, r0

    from r1
    stw (r11)               ; +0: dy_start
    inc r11
    inc r11
    from r3
    stw (r11)               ; +2: line_count
    inc r11
    inc r11
    from r5
    stw (r11)               ; +4: xL_start
    inc r11
    inc r11
    from r6
    stw (r11)               ; +6: xR_start
    inc r11
    inc r11
    from r2
    stw (r11)               ; +8: dxL_dy
    inc r11
    inc r11
    from r9
    stw (r11)               ; +10: dxR_dy
    inc r11
    inc r11

    flat_fptr flat_compile_frame::curr_out_ptr, r7
    from r11
    stw (r7)

    flat_fptr flat_compile_frame::trap_count, r7
    ldw (r7)
    inc r0
    stw (r7)

    flat_fptr flat_compile_frame::half_index, r7
    ldw (r7)
    from r0
    sub #0
    beq @ret_top
    nop
    iwt r11, #@bot_done
    jmp r11
    nop
@ret_top:
    iwt r11, #@top_done
    jmp r11
    nop
endfunction

.endif ; __GSU_MESH_COMPILE_FLAT_TRI__
