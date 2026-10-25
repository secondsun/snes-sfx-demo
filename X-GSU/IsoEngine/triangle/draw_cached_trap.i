; ==============================================================================
; IsoEngine CACHE-Resident Affine Textured Scanline Trapezoid Rasterizer
; ==============================================================================
.ifndef ::__DRAW_CACHED_TRAP_DEFINED__
::__DRAW_CACHED_TRAP_DEFINED__ = 1

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/control.i"
.include "../../common/util.i"

.include "cached_trap.i"

; Stack-allocated trapezoid state frame (22 bytes, 11 words)
.struct trap_frame
    lines_left  .word ; +0:  Number of scanlines remaining
    xL          .word ; +2:  Current left edge X in Q8.8
    xR          .word ; +4:  Current right edge X in Q8.8
    dxL_dy      .word ; +6:  Left edge slope dxL/dy in Q8.8
    dxR_dy      .word ; +8:  Right edge slope dxR/dy in Q8.8
    uL          .word ; +10: Current left edge U in Q8.8
    vL          .word ; +12: Current left edge V in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)
    du_dy       .word ; +14: Left edge du/dy in Q8.8
    dv_dy       .word ; +16: Left edge dv/dy in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)
    du_dx       .word ; +18: Scanline du/dx in Q8.8
    dv_dx       .word ; +20: Scanline dv/dx in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)
.endstruct

; External or global reference to TEXTURE_TABLE
.global TEXTURE_TABLE

.segment "GSUCODE"

; ==============================================================================
; draw_cached_trap
; Rasterizes a pre-compiled scanline trapezoid with affine texture mapping.
;
; In:
;   trap_ptr    = r1: Pointer to cached_trap struct in GSURAM
;   anchor_x    = r3: Screen anchor X coordinate (integer pixels, signed)
;   anchor_y    = r4: Screen anchor Y coordinate (integer pixels, signed)
;   u_offset    = r5: World-space U offset in Q8.8
;   v_offset    = r6: World-space V offset in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)
;   frame_half  = r7: Active frame half (0 = Pass 0 [0..127], 1 = Pass 1 [128..255])
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function draw_cached_trap trap_ptr, anchor_x, anchor_y, u_offset, v_offset, frame_half
    register trap_ptr = r1, anchor_x = r3, anchor_y = r4, u_offset = r5, v_offset = r6, frame_half = r7

    ; Ensure cmode = 0 (bit 0 = 0: transparency enabled: color 0 transparent, 1..15 opaque)
    iwt r0, #$00
    cmode

    ; Read dy_start from trap_ptr (+0)
    ldw (trap_ptr)      ; r0 = dy_start
    with anchor_y
    add r0              ; anchor_y = y = anchor_y + dy_start

    ; Read line_count from trap_ptr + 2
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = line_count

    ; If line_count == 0: early exit
    beq @early_exit
    nop

    ; Check if completely above screen: y_end <= 0
    to r8
    from anchor_y
    add r0              ; r8 = y_end = y + line_count
    from r8
    sub #1
    blt @early_exit
    nop

    ; Check if completely below screen: y >= 160
    iwt r8, #160
    from anchor_y
    cmp r8
    bge @early_exit
    nop

    ; Top clipping: if y < 0, skip = -y, y = 0, line_count -= skip
    from anchor_y
    sub #0
    bge @no_top_clip
    nop
    ; anchor_y < 0:
    iwt r0, #0
    with r0
    sub anchor_y        ; r0 = skip = 0 - y
    to r9
    move r9, r0         ; r9 = skip
    ldw (trap_ptr)      ; r0 = line_count
    from r9
    cmp r0
    bge @early_exit     ; if skip >= line_count, entirely off screen!
    nop
    with r0
    sub r9              ; r0 = new line_count = line_count - skip
    iwt anchor_y, #0    ; y = 0
    bra @top_clip_done
    nop

@no_top_clip:
    iwt r9, #0          ; skip = 0
    ldw (trap_ptr)      ; r0 = line_count

@top_clip_done:
    ; Bottom clipping: if y + line_count > 160, line_count = 160 - y
    to r8
    from anchor_y
    add r0              ; r8 = y_end
    iwt r11, #160
    from r8
    cmp r11
    blt @bottom_clip_done
    nop
    beq @bottom_clip_done
    nop
    ; y_end > 160:
    from r11
    sub r4              ; r0 = 160 - y
    to r8
    move r8, r0         ; r8 = line_count
    bra @bottom_clipped
    nop

@bottom_clip_done:
    to r8
    move r8, r0         ; r8 = line_count

@bottom_clipped:
    from r8
    sub #1
    blt @early_exit
    nop

    bra @not_early_exit
    nop

@early_exit:
    return

@not_early_exit:
    ; Save clipped line_count in r12
    to r12
    move r12, r8

    ; Save starting Y in r2 (R2 is SuperFX hardware Y coordinate register for plot)
    to r2
    move r2, anchor_y

    ; Compute effective horizontal anchor shift in Q8.8:
    ; anchor_x_eff = anchor_x << 8
    to r8
    from anchor_x
    swap
    iwt r11, #$FF00
    with r8
    and r11             ; r8 = anchor_x in Q8.8

    ; If frame_half != 0, subtract 128 in Q8.8 (-$8000 = +$8000)
    from frame_half
    sub #0
    beq @no_frame_half_shift
    nop
    iwt r0, #$8000
    with r8
    add r0              ; r8 += -$8000 (mod 64k)
@no_frame_half_shift:

    ; Read xL_start (+4) and add anchor_x_eff
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = xL_start
    with r0
    add r8
    to r7
    move r7, r0         ; r7 = xL = xL_start + anchor_x_eff

    ; Read xR_start (+6) and add anchor_x_eff
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = xR_start
    with r0
    add r8
    to r8
    move r8, r0         ; r8 = xR = xR_start + anchor_x_eff

    ; Allocate stack frame (22 bytes = .sizeof(trap_frame))
    with r10
    to r4               ; r4 = frame_base = r10
    with r10
    add #11
    with r10
    add #11             ; advance r10 by 22 bytes

    ; Store lines_left (+0)
    from r12
    stw (r4)

    ; Store xL (+2)
    inc r4
    inc r4
    from r7
    stw (r4)

    ; Store xR (+4)
    inc r4
    inc r4
    from r8
    stw (r4)

    ; Read dxL_dy (+8 of cached_trap, trap_ptr was at +6)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = dxL_dy
    inc r4
    inc r4
    stw (r4)            ; Store dxL_dy at frame + 6

    ; Read dxR_dy (+10 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = dxR_dy
    inc r4
    inc r4
    stw (r4)            ; Store dxR_dy at frame + 8

    ; Read uL_start (+12 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = uL_start
    inc r4
    inc r4
    stw (r4)            ; Store uL at frame + 10

    ; Read vL_start (+14 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = vL_start
    inc r4
    inc r4
    stw (r4)            ; Store vL at frame + 12

    ; Read du_dy (+16 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = du_dy
    inc r4
    inc r4
    stw (r4)            ; Store du_dy at frame + 14

    ; Read dv_dy (+18 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = dv_dy
    inc r4
    inc r4
    stw (r4)            ; Store dv_dy at frame + 16

    ; Read du_dx (+20 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = du_dx
    inc r4
    inc r4
    stw (r4)            ; Store du_dx at frame + 18

    ; Read dv_dx (+22 of cached_trap)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = dv_dx
    inc r4
    inc r4
    stw (r4)            ; Store dv_dx at frame + 20

    ; If top clipping skipped scanlines (r9 > 0): advance edges by skip now
    from r9
    sub #0
    beq @skip_done
    nop
    to r12
    move r12, r9        ; r12 = skip count
    iwt r13, #@skip_loop
@skip_loop:
    from r10
    to r4
    sub #11
    with r4
    sub #11             ; r4 = frame_base
    inc r4
    inc r4              ; r4 = frame_base + 2 (xL)
    from r4
    to r11
    add #4              ; r11 = frame_base + 6 (dxL_dy)

    ; xL += dxL_dy
    ldw (r4)
    to r3
    move r3, r0
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r4)

    ; xR += dxR_dy
    inc r4
    inc r4              ; frame_base + 4 (xR)
    ldw (r4)
    to r3
    move r3, r0
    inc r11
    inc r11             ; frame_base + 8 (dxR_dy)
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r4)

    ; uL += du_dy
    from r4
    to r4
    add #6              ; frame_base + 10 (uL)
    ldw (r4)
    to r3
    move r3, r0
    from r11
    to r11
    add #6              ; frame_base + 14 (du_dy)
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r4)

    ; vL += dv_dy
    inc r4
    inc r4              ; frame_base + 12 (vL)
    ldw (r4)
    to r3
    move r3, r0
    inc r11
    inc r11             ; frame_base + 16 (dv_dy)
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r4)

    loop
    nop
@skip_done:

    ; Read tex_id (+24 of cached_trap, trap_ptr is at +22)
    inc trap_ptr
    inc trap_ptr
    ldw (trap_ptr)      ; r0 = tex_id

    ; Lookup TEXTURE_TABLE + (tex_id << 3)
    from r0
    add r0              ; tex_id * 2
    add r0              ; tex_id * 4
    add r0              ; tex_id * 8
    to r8
    move r8, r0
    iwt r0, #TEXTURE_TABLE
    with r0
    add r8              ; r0 = TEXTURE_TABLE + (tex_id << 3)

.ifdef TEXTURE_TABLE_IN_RAM
    to r1
    move r1, r0
    ldw (r1)
    to r9               ; r9 = rom_offset
    move r9, r0
    inc r1
    inc r1
    ldw (r1)
    to r7               ; r7 = u_mask
    move r7, r0
    inc r1
    inc r1
    ldw (r1)
    to r8               ; r8 = v_mask
    move r8, r0
    inc r1
    inc r1
    ldw (r1)            ; r0 = stride_shift
.else
    to r14
    move r14, r0
    _romreadwordLE r9   ; r9 = rom_offset
    _romreadwordLE r7   ; r7 = u_mask
    _romreadwordLE r8   ; r8 = v_mask
    _romreadwordLE r0   ; r0 = stride_shift
.endif

.ifdef TEXTURE_BASE_ADDR
    iwt r11, #TEXTURE_BASE_ADDR
    with r9
    add r11
.endif

    ; Compute v_mask_shifted = v_mask << stride_shift
    to r4
    move r4, r0         ; r4 = stride_shift
    move r0, r8         ; r0 = v_mask
    from r4
    sub #0              ; test stride_shift
    beq @shift_v_done
    nop
    to r12
    move r12, r4        ; loop count = stride_shift
    iwt r13, #@shift_v_loop
@shift_v_loop:
    with r0
    add r0              ; r0 <<= 1
    loop
    nop
@shift_v_done:
    to r8
    move r8, r0         ; r8 = v_mask_shifted

    ; Finalize uL and vL with world-aligned UV offsets
    ; r5 = u_offset, r6 = v_offset
    with r5
    and r7              ; r5 = u_offset & u_mask
    with r6
    and r8              ; r6 = v_offset & v_mask_shifted

    ; r10 is at frame_base + 22
    ; frame_base + 10 = r10 - 12
    from r10
    to r4
    sub #11
    with r4
    sub #1              ; r4 = frame_base + 10 (uL)
    ldw (r4)
    with r0
    add r5
    stw (r4)            ; uL = uL + (u_offset & u_mask)

    inc r4
    inc r4              ; r4 = frame_base + 12 (vL)
    ldw (r4)
    with r0
    add r6
    stw (r4)            ; vL = vL + (v_offset & v_mask_shifted)

    ; Load du_dx (at +18) into r5, dv_dx (at +20) into r6
    from r4
    to r4
    add #6              ; r4 = frame_base + 18 (du_dx)
    ldw (r4)
    to r5
    move r5, r0         ; r5 = du_dx
    inc r4
    inc r4              ; r4 = frame_base + 20 (dv_dx)
    ldw (r4)
    to r6
    move r6, r0         ; r6 = dv_dx

    ; --------------------------------------------------------------------------
    ; Register Invariants Across Scanlines:
    ;   r2  = Y scanline
    ;   r5  = du_dx (Q8.8)
    ;   r6  = dv_dx (Q(16-S).S)
    ;   r7  = u_mask
    ;   r8  = v_mask_shifted
    ;   r9  = rom_offset
    ; --------------------------------------------------------------------------
    cache
scanline_loop:
    from r10
    to r1
    sub #11
    with r1
    sub #11             ; r1 = frame_base

    ; Check lines_left (+0)
    ldw (r1)
    bne @lines_remaining
    nop
    iwt r13, #@trap_finished
    jmp r13
    nop

@lines_remaining:
    ; Load xL (+2) and xR (+4)
    inc r1
    inc r1
    ldw (r1)            ; r0 = xL
    to r3
    move r3, r0         ; r3 = xL

    inc r1
    inc r1
    ldw (r1)            ; r0 = xR
    to r4
    move r4, r0         ; r4 = xR

    ; If both xL and xR have bit 15 set (both < 0 or both >= 128):
    from r3
    to r0
    and r4
    bmi @skip_scanline
    nop

    ; Now: at most one of r3, r4 has bit 15 set.
    iwt r11, #$00FF     ; mask for low byte

    ; Check if r4 has bit 15 set (xR >= 128):
    from r4
    sub #0
    bpl :+
    nop
    ; r4 has bit 15 set -> xR >= 128, so xR_int = 128:
    iwt r4, #128
    bra @xR_resolved
    nop
:   ; r4 has bit 15 clear -> xR in [0, 127], so xR_int = r4 >> 8:
    with r4
    swap
    with r4
    and r11
@xR_resolved:

    ; Check if r3 has bit 15 set (xL < 0):
    from r3
    sub #0
    bpl :+
    nop
    ; r3 has bit 15 set -> xL < 0.
    ; Floor of negative Q8.8: floor(xL)
    with r3
    swap
    with r3
    sex                 ; r3 = xL_int = -skip
    bra @xL_resolved
    nop
:   ; r3 has bit 15 clear -> xL in [0, 127], so xL_int = r3 >> 8:
    with r3
    swap
    with r3
    and r11
@xL_resolved:

    ; If xL_int >= xR_int: nothing to draw on this scanline
    from r3
    cmp r4
    bge @skip_scanline
    nop

    bra @begin_span
    nop

@skip_scanline:
    iwt r13, #@advance_scanline
    jmp r13
    nop

@begin_span:

    ; Load uL (+10) and vL (+12) into r11 and r14
    from r1
    to r1
    add #6              ; r1 = frame_base + 10 (uL)
    ldw (r1)            ; r0 = uL
    to r11
    move r11, r0        ; r11 = u_cur = uL
    inc r1
    inc r1              ; r1 = frame_base + 12 (vL)
    ldw (r1)            ; r0 = vL
    to r14
    move r14, r0        ; r14 = v_cur = vL

    ; Clip left edge against 0:
    from r3
    sub #0
    bge @no_clip_left
    nop
    ; r3 < 0:
    iwt r0, #0
    with r0
    sub r3
    to r12
    move r12, r0        ; r12 = clip_left = -r3
    iwt r3, #0          ; x_start = 0

    ; Advance u_cur (r11) and v_cur (r14) by clip_left * step:
    iwt r13, #@clip_u_loop
@clip_u_loop:
    with r11
    add r5              ; u_cur += du_dx
    with r14
    add r6              ; v_cur += dv_dx
    loop
    nop

@no_clip_left:
    ; Compute pixel_count = x_end - x_start = r4 - r3
    from r4
    sub r3
    beq @advance_scanline
    nop
    bmi @advance_scanline
    nop
    to r12
    move r12, r0        ; r12 = pixel_count

    ; Set R1 = x_start (plot_x)
    to r1
    move r1, r3

    ; Move u_cur to r3 and v_cur to r4:
    to r3
    move r3, r11        ; r3 = u_cur
    to r4
    move r4, r14        ; r4 = v_cur

    ; Prime R14 with first texel ROM address:
    from r3
    to r11
    hib                 ; r11 = u_cur >> 8
    with r11
    and r7              ; r11 = u_int & u_mask
    from r4
    to r0
    and r8              ; r0 = v_cur & v_mask_shifted
    with r11
    add r0              ; r11 = col + row
    with r11
    add r9              ; r11 = col + row + rom_offset
    to r14
    move r14, r11       ; Prime R14 (starts hardware ROM prefetch!)

    iwt r13, #@pixel_loop
@pixel_loop:
    getc                ; Color = RomBuf
    plot                ; Plot Color at (R1, R2); R1 = R1 + 1
    with r3
    add r5              ; u_cur += du_dx
    with r4
    add r6              ; v_cur += dv_dx
    from r3
    to r11
    hib
    with r11
    and r7
    from r4
    to r0
    and r8
    with r11
    add r0
    with r11
    add r9
    to r14
    move r14, r11       ; R14 = next texel address
    loop
    nop

@advance_scanline:
    ; Increment Y scanline
    inc r2

    ; Decrement lines_left and advance edges
    from r10
    to r1
    sub #11
    with r1
    sub #11             ; r1 = frame_base

    ldw (r1)            ; r0 = lines_left
    dec r0
    stw (r1)            ; save lines_left
    bne @lines_remain_adv
    nop
    iwt r13, #@trap_finished
    jmp r13
    nop

@lines_remain_adv:
    ; Advance xL: xL (+2) += dxL_dy (+6)
    inc r1
    inc r1              ; r1 = frame_base + 2 (xL)
    ldw (r1)            ; r0 = xL
    to r3
    move r3, r0
    from r1
    to r11
    add #4              ; r11 = frame_base + 6 (dxL_dy)
    ldw (r11)           ; r0 = dxL_dy
    with r3
    add r0
    from r3
    stw (r1)            ; save updated xL

    ; Advance xR: xR (+4) += dxR_dy (+8)
    inc r1
    inc r1              ; r1 = frame_base + 4 (xR)
    ldw (r1)
    to r3
    move r3, r0
    inc r11
    inc r11             ; r11 = frame_base + 8 (dxR_dy)
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r1)

    ; Advance uL: uL (+10) += du_dy (+14)
    from r1
    to r1
    add #6              ; r1 = frame_base + 10 (uL)
    ldw (r1)
    to r3
    move r3, r0
    from r11
    to r11
    add #6              ; r11 = frame_base + 14 (du_dy)
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r1)

    ; Advance vL: vL (+12) += dv_dy (+16)
    inc r1
    inc r1              ; r1 = frame_base + 12 (vL)
    ldw (r1)
    to r3
    move r3, r0
    inc r11
    inc r11             ; r11 = frame_base + 16 (dv_dy)
    ldw (r11)
    with r3
    add r0
    from r3
    stw (r1)

    iwt r13, #scanline_loop
    jmp r13
    nop

@trap_finished:
    ; Flush GSU pixel caches to game pak RAM
    rpix
    rpix

    ; Deallocate stack frame (22 bytes)
    with r10
    sub #11
    with r10
    sub #11
    return
endfunction

; Macro helper for invoking draw_cached_trap
.macro draw_cached_trap_call trap_ptr, ax, ay, u_off, v_off, fh
    call draw_cached_trap trap_ptr, ax, ay, u_off, v_off, fh
.endmacro

.endif ; ::__DRAW_CACHED_TRAP_DEFINED__
