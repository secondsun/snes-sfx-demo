; ==============================================================================
; draw_flat_trap.i - 512B-Cache-Resident SuperFX Flat-Shaded Trapezoid Rasterizer
;
; Renders pre-compiled 12-byte `flat_trap` trapezoids using register-resident
; scanline state (zero RAM stack traffic inside the scanline loop) and 1-cycle
; `loop; plot` hardware spans.
; ==============================================================================

.ifndef __GSU_MESH_DRAW_FLAT_TRAP__
__GSU_MESH_DRAW_FLAT_TRAP__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"
.include "mesh_layout.i"

.ifndef GSU_TRAP_SCREEN_H
    GSU_TRAP_SCREEN_H = 160
.endif
.ifndef GSU_TRAP_PASS1_MAX_X
    GSU_TRAP_PASS1_MAX_X = 128
.endif

.if GSU_TRAP_PASS1_MAX_X < 128
.segment "GSURAM"
.align 2
gsu_flat_max_x: .res 2
.endif

.segment "GSUCODE"

; ==============================================================================
; draw_flat_trap
; Rasterizes a pre-compiled 12-byte `flat_trap` in solid palette slot `color_idx`.
;
; In:
;   r1 = trap_ptr   : Pointer to `flat_trap` struct in Bank $70 GSURAM
;   r3 = anchor_x   : Screen anchor X coordinate (integer pixels, signed)
;   r4 = anchor_y   : Screen anchor Y coordinate (integer pixels, signed)
;   r5 = color_idx  : 4bpp CGRAM palette slot (1..15)
;   r7 = frame_half : Active frame half (0 = Pass 0 [0..127], 1 = Pass 1 [128..255])
;
; Postconditions:
;   - `RAMBR == 0` ($70)
;   - Caller flushes dual 8-pixel plot caches via `rpix; rpix` at pass end
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13
; ==============================================================================
function draw_flat_trap
    .align 16, $01
flat_cbr_anchor:
    cache

    ; Set cmode=0 (color 0 transparent) and latch flat COLR before repurposing r5
    ibt r0, #0
    cmode
    from r5
    color

    ; r4 = y = anchor_y + dy_start (+0)
    ldw (r1)
    with r4
    add r0

    ; r8 = line_count (+2)
    from r1
    to r11
    add #2
    to r8
    ldw (r11)

    ; Early exit if line_count <= 0 or completely above screen (y + line_count <= 0)
    from r8
    sub #1
    blt @early_exit
    nop

    from r4
    add r8
    sub #1
    blt @early_exit
    nop

    ; Check if completely below screen (y >= GSU_TRAP_SCREEN_H)
    iwt r11, #GSU_TRAP_SCREEN_H
    from r4
    cmp r11
    bge @early_exit
    nop

    ; Top clipping: if y < 0, skip = -y, y = 0, line_count -= skip
    moves r4, r4
    bpl @no_top_clip
    nop
    ibt r0, #0
    sub r4
    move r9, r0         ; r9 = skip = -y
    from r9
    cmp r8
    bge @early_exit
    nop
    with r8
    sub r9
    ibt r4, #0
    bra @top_clip_done
    nop

@no_top_clip:
    ibt r9, #0

@top_clip_done:
    ; Bottom clipping: if y + line_count > 160, line_count = 160 - y (r11 still 160)
    from r4
    add r8
    from r11
    cmp r0
    bge @bottom_clip_done
    nop
    from r11
    to r8
    sub r4

@bottom_clip_done:
    from r8
    sub #1
    bge @not_early_exit
    nop

@early_exit:
    return

@not_early_exit:
    ; Save starting scanline Y in hardware plot register r2
    move r2, r4

    ; Compute anchor_x_eff = ((anchor_x - 128 * frame_half) & $FF) << 8 in r11
    move r11, r3
    moves r7, r7
    beq :+
    nop
    ibt r0, #$80        ; -128 in signed 8-bit
    with r11
    add r0
:
    with r11
    lob
    with r11
    swap
.if ::GSU_TRAP_PASS1_MAX_X < 128
    iwt r0, #128
    moves r7, r7
    beq @flat_store_max_x
    nop
    ibt r0, #::GSU_TRAP_PASS1_MAX_X
@flat_store_max_x:
    sm (gsu_flat_max_x), r0
.endif

    ; Load edge initial X and slopes into permanent loop registers:
    ;   r7 = xL (Q8.8), r4 = xR (Q8.8 temporarily), r5 = dxL_dy, r6 = dxR_dy
    from r1
    to r3
    add #4              ; r3 = trap_ptr + xL_start
    ldw (r3)
    add r11
    move r7, r0         ; r7 = xL

    inc r3
    inc r3
    ldw (r3)
    add r11
    move r4, r0         ; r4 = xR (temp)

    inc r3
    inc r3
    to r5
    ldw (r3)            ; r5 = dxL_dy

    inc r3
    inc r3
    to r6
    ldw (r3)            ; r6 = dxR_dy

    ; Constant-time top-clip edge advance if skip (r9) > 0:
    ;   xR += dxR_dy * skip, xL += dxL_dy * skip
    moves r9, r9
    beq @skip_done
    nop
    move r12, r4        ; preserve xR across lmult (lmult clobbers r4)
    from r9
    lmult               ; r4 = low16(skip * dxR_dy) [r6 is already dxR_dy]
    with r12
    add r4
    move r11, r6        ; preserve dxR_dy
    move r6, r5         ; r6 = dxL_dy
    from r9
    lmult               ; r4 = low16(skip * dxL_dy)
    with r7
    add r4
    move r6, r11        ; restore dxR_dy
    move r4, r12        ; restore xR
@skip_done:

    ; Arrange final register-resident scanline loop state:
    ;   r2 = Y, r5 = dxL_dy, r6 = dxR_dy, r7 = xL, r8 = xR, r9 = lines_left, r11 = $00FF
    move r9, r8
    move r8, r4
    iwt r11, #$00FF

@scanline_loop:
    move r3, r7
    move r4, r8

    ; Reject scanlines where both Q8.8 endpoints have bit 15 set (both < 0 or both >= 128)
    from r3
    and r4
    bmi @advance_scanline
    nop

    ; Resolve xR_int into r4, clamped at <= 128
    moves r4, r4
    bpl :+
    nop
    iwt r4, #128
    bra @xR_resolved
    nop
:
    with r4
    swap
    with r4
    and r11
@xR_resolved:
.if ::GSU_TRAP_PASS1_MAX_X < 128
    lm r0, (gsu_flat_max_x)
    from r4
    cmp r0
    blt @flat_xR_clamped
    nop
    move r4, r0
@flat_xR_clamped:
.endif

    ; Resolve xL_int into r3 (sign-extended if negative), clamped at >= 0
    moves r3, r3
    bpl :+
    nop
    with r3
    swap
    with r3
    sex
    bra @xL_resolved
    nop
:
    with r3
    swap
    with r3
    and r11
@xL_resolved:

    moves r3, r3
    bpl :+
    nop
    ibt r3, #0
:
    from r4
    sub r3
    beq @advance_scanline
    nop
    bmi @advance_scanline
    nop

    move r12, r0
    move r1, r3
    iwt r13, #@flat_pixel_loop
@flat_pixel_loop:
    plot
    loop
    nop

@advance_scanline:
    inc r2
    with r7
    add r5
    with r8
    add r6
    dec r9
    bne @scanline_loop
    nop

    return
flat_cbr_end:
    .assert (flat_cbr_end - flat_cbr_anchor) <= 512, error, "draw_flat_trap exceeds 512B GSU cache!"
endfunction

.endif ; __GSU_MESH_DRAW_FLAT_TRAP__
