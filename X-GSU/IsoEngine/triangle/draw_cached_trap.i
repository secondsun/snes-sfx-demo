; ==============================================================================
; draw_cached_trap.i - Affine Textured Scanline Trapezoid Rasterizer for SuperFX
;
; Optimized Cache-Resident Implementation:
;   - Shrunk trap_frame from 22 bytes to 12 bytes on the stack
;   - Inner scanline loop fits 100% within the 512-byte GSU instruction cache
;   - Efficient per-scanline setup and 20-byte inner pixel loop
; ==============================================================================

.include "cached_trap.i"
.include "../../common/util.i"

; Stack-allocated trapezoid state frame (12 bytes, 6 words)
.struct trap_frame
    lines_left  .word ; +0: Number of scanlines remaining
    xL          .word ; +2: Current left edge X in Q8.8
    xR          .word ; +4: Current right edge X in Q8.8
    uL          .word ; +6: Current left edge U in Q8.8
    vL          .word ; +8: Current left edge V in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)
    trap_ptr    .word ; +10: Base pointer to cached_trap struct in GSURAM
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
    move r11, trap_ptr
    inc r11
    inc r11             ; r11 = trap_ptr + 2
    ldw (r11)           ; r0 = line_count

    ; If line_count <= 0: early exit
    beq @early_exit
    nop
    from r0
    sub #0
    blt @early_exit
    nop

    ; Check if completely above screen: y_end <= 0
    from anchor_y
    add r0              ; r0 = y_end = y + line_count
    move r8, r0         ; r8 = y_end
    from r8
    sub #1
    blt @early_exit
    nop

    ; Check if completely below screen: y >= 160
    iwt r11, #160
    from anchor_y
    cmp r11
    bge @early_exit
    nop

    ; Top clipping: if y < 0, skip = -y, y = 0, line_count -= skip
    from anchor_y
    sub #0
    bge @no_top_clip
    nop
    iwt r0, #0
    with r0
    sub anchor_y        ; r0 = skip = 0 - y
    move r9, r0         ; r9 = skip

    move r11, trap_ptr
    inc r11
    inc r11
    ldw (r11)           ; r0 = line_count
    from r9
    cmp r0
    bge @early_exit     ; if skip >= line_count, entirely off screen!
    nop
    with r0
    sub r9              ; r0 = line_count - skip
    iwt anchor_y, #0    ; y = 0
    bra @top_clip_done
    nop

@no_top_clip:
    iwt r9, #0          ; skip = 0
    move r11, trap_ptr
    inc r11
    inc r11
    ldw (r11)           ; r0 = line_count

@top_clip_done:
    ; Bottom clipping: if y + line_count > 160, line_count = 160 - y
    move r8, r0         ; r8 = line_count
    from anchor_y
    add r8              ; r0 = y_end = anchor_y + line_count
    iwt r11, #160
    from r0
    cmp r11             ; compare y_end with 160
    blt @bottom_clip_done
    nop
    beq @bottom_clip_done
    nop
    ; y_end > 160:
    from r11
    sub anchor_y        ; r0 = 160 - y
    move r8, r0         ; r8 = line_count = 160 - y

@bottom_clip_done:
    from r8
    sub #1
    blt @early_exit
    nop

    bra @not_early_exit
    nop

@early_exit:
    return

@not_early_exit:
    ; Save starting Y in r2 (SuperFX hardware Y coordinate register for plot)
    move r2, anchor_y

    ; Allocate stack frame (12 bytes = .sizeof(trap_frame))
    with r10
    add #12
    move r4, r10
    with r4
    sub #12             ; r4 = frame_base

    ; Store lines_left (+0)
    from r8
    stw (r4)

    ; Store trap_ptr (+10)
    move r11, r4
    with r11
    add #10             ; r11 = frame_base + 10
    from trap_ptr
    stw (r11)

    ; Compute anchor_x_eff in r11:
    move r11, anchor_x
    with r11
    swap
    iwt r14, #$FF00
    with r11
    and r14

    from frame_half
    sub #0
    beq :+
    nop
    iwt r0, #$8000
    with r11
    add r0              ; if frame_half == 1, subtract 128 (mod 64k)
:
    ; Read xL_start (+4 of cached_trap) and add anchor_x_eff (r11)
    move r8, trap_ptr
    with r8
    add #4              ; r8 = trap_ptr + 4
    ldw (r8)            ; r0 = xL_start
    with r0
    add r11             ; r0 = xL = xL_start + anchor_x_eff
    move r3, r4
    inc r3
    inc r3              ; r3 = frame_base + 2 (xL)
    stw (r3)            ; store xL

    ; Read xR_start (+6 of cached_trap) and add anchor_x_eff (r11)
    inc r8
    inc r8              ; r8 = trap_ptr + 6
    ldw (r8)            ; r0 = xR_start
    with r0
    add r11             ; r0 = xR = xR_start + anchor_x_eff
    inc r3
    inc r3              ; r3 = frame_base + 4 (xR)
    stw (r3)            ; store xR

    ; Read uL_start (+12 of cached_trap)
    move r11, trap_ptr
    with r11
    add #12             ; r11 = trap_ptr + 12
    ldw (r11)           ; r0 = uL_start
    inc r3
    inc r3              ; r3 = frame_base + 6 (uL)
    stw (r3)

    ; Read vL_start (+14 of cached_trap)
    inc r11
    inc r11             ; r11 = trap_ptr + 14
    ldw (r11)           ; r0 = vL_start
    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    stw (r3)

    ; If top clipping skipped scanlines (r9 > 0): advance edges by skip now
    from r9
    sub #0
    beq @skip_done
    nop
    move r12, r9        ; r12 = skip count
    iwt r13, #@skip_loop
@skip_loop:
    move r11, trap_ptr
    with r11
    add #8              ; r11 = trap_ptr + 8 (dxL_dy)
    move r3, r4
    inc r3
    inc r3              ; r3 = frame_base + 2 (xL)

    ; xL += dxL_dy
    ldw (r3)
    move r14, r0
    ldw (r11)           ; r0 = dxL_dy
    with r14
    add r0
    from r14
    stw (r3)

    ; xR += dxR_dy
    inc r3
    inc r3              ; r3 = frame_base + 4 (xR)
    ldw (r3)
    move r14, r0
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    ldw (r11)           ; r0 = dxR_dy
    with r14
    add r0
    from r14
    stw (r3)

    ; uL += du_dy
    inc r3
    inc r3              ; r3 = frame_base + 6 (uL)
    ldw (r3)
    move r14, r0
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    ldw (r11)           ; r0 = du_dy
    with r14
    add r0
    from r14
    stw (r3)

    ; vL += dv_dy
    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    ldw (r3)
    move r14, r0
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    ldw (r11)           ; r0 = dv_dy
    with r14
    add r0
    from r14
    stw (r3)

    loop
    nop
@skip_done:

    ; Read tex_id (+24 of cached_trap)
    move r11, trap_ptr
    with r11
    add #15
    with r11
    add #9              ; r11 = trap_ptr + 24 (tex_id)
    ldw (r11)           ; r0 = tex_id

    ; Lookup TEXTURE_TABLE + (tex_id << 3)
    from r0
    add r0              ; tex_id * 2
    add r0              ; tex_id * 4
    add r0              ; tex_id * 8
    move r7, r0
    iwt r0, #TEXTURE_TABLE
    with r0
    add r7              ; r0 = TEXTURE_TABLE + (tex_id << 3)

.ifdef TEXTURE_TABLE_IN_RAM
    move r7, r0
    ldw (r7)
    move r9, r0         ; r9 = rom_offset
    inc r7
    inc r7
    ldw (r7)
    move r8, r0         ; r8 = u_mask (temp)
    inc r7
    inc r7
    ldw (r7)
    move r11, r0        ; r11 = v_mask
    inc r7
    inc r7
    ldw (r7)            ; r0 = stride_shift
.else
    move r14, r0
    _romreadwordLE r9   ; r9 = rom_offset
    _romreadwordLE r8   ; r8 = u_mask (temp in r8)
    _romreadwordLE r11  ; r11 = v_mask
    _romreadwordLE r0   ; r0 = stride_shift
.endif

.ifdef TEXTURE_BASE_ADDR
    iwt r7, #TEXTURE_BASE_ADDR
    with r9
    add r7
.endif

    move r7, r8         ; r7 = u_mask

    ; Shift v_mask by stride_shift:
    move r12, r0        ; r12 = stride_shift
    move r0, r11        ; r0 = v_mask
    from r12
    sub #0
    beq @shift_v_done
    nop
    iwt r13, #@shift_v_loop
@shift_v_loop:
    with r0
    add r0              ; r0 <<= 1
    loop
    nop
@shift_v_done:
    move r8, r0         ; r8 = v_mask_shifted

    ; Mask UV offsets and add to uL, vL
    with r5
    and r7              ; r5 = u_offset & u_mask
    with r6
    and r8              ; r6 = v_offset & v_mask_shifted

    move r3, r4
    with r3
    add #6              ; r3 = frame_base + 6 (uL)
    ldw (r3)
    with r0
    add r5
    stw (r3)            ; uL += masked u_offset

    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    ldw (r3)
    with r0
    add r6
    stw (r3)            ; vL += masked v_offset

    ; Load du_dx (+20) into r5, dv_dx (+22) into r6
    move r11, trap_ptr
    with r11
    add #15
    with r11
    add #5              ; r11 = trap_ptr + 20 (du_dx)
    ldw (r11)           ; r0 = du_dx
    move r5, r0         ; r5 = du_dx

    inc r11
    inc r11             ; r11 = trap_ptr + 22 (dv_dx)
    ldw (r11)           ; r0 = dv_dx
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
    .align 16, $01
    cache
scanline_loop:
    move r1, r10
    with r1
    sub #12             ; r1 = frame_base

    inc r1
    inc r1              ; r1 = frame_base + 2 (xL)
    ldw (r1)            ; r0 = xL
    move r3, r0         ; r3 = xL

    inc r1
    inc r1              ; r1 = frame_base + 4 (xR)
    ldw (r1)            ; r0 = xR
    move r4, r0         ; r4 = xR

    ; If both xL and xR have bit 15 set (both < 0 or both >= 128):
    from r3
    and r4
    bpl :+
    nop
    iwt r15, #@skip_scanline
:
    ; Now: at most one of r3, r4 has bit 15 set.
    iwt r11, #$00FF     ; mask for low byte

    ; Check if r4 has bit 15 set (xR >= 128):
    from r4
    sub #0
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

    ; Check if r3 has bit 15 set (xL < 0):
    from r3
    sub #0
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

    ; If xL_int >= xR_int: nothing to draw on this scanline
    from r3
    cmp r4
    blt :+
    nop
    iwt r15, #@skip_scanline
:
    ; --- Begin span ---
    inc r1
    inc r1              ; r1 = frame_base + 6 (uL)
    ldw (r1)            ; r0 = uL
    move r11, r0        ; r11 = u_cur = uL
    inc r1
    inc r1              ; r1 = frame_base + 8 (vL)
    ldw (r1)            ; r0 = vL
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
    move r12, r0        ; r12 = clip_left = -r3
    iwt r3, #0          ; x_start = 0

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
    beq :+
    nop
    bpl @draw_span
    nop
:
    iwt r15, #@advance_scanline

@draw_span:
    move r12, r0        ; r12 = pixel_count

    ; R1 = x_start (plot X)
    move r1, r3

    ; Move u_cur to r3 and v_cur to r4:
    move r3, r11
    move r4, r14

    ; Prime R14 with first texel ROM address:
    from r3
    hib                 ; r0 = u_cur >> 8
    to r11
    and r7              ; r11 = u_int & u_mask
    from r4
    and r8              ; r0 = v_cur & v_mask_shifted
    with r11
    add r0              ; r11 = col + row
    with r11
    add r9              ; r11 = col + row + rom_offset
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
    hib
    to r11
    and r7
    from r4
    and r8
    with r11
    add r0
    with r11
    add r9
    move r14, r11       ; R14 = next texel address
    loop
    nop

@skip_scanline:
@advance_scanline:
    inc r2              ; next Y scanline

    move r1, r10
    with r1
    sub #12             ; r1 = frame_base

    ldw (r1)            ; r0 = lines_left
    dec r0
    stw (r1)            ; save lines_left
    bne @lines_remain_adv
    nop
    iwt r15, #@trap_finished

@lines_remain_adv:
    ; Read trap_ptr from frame_base + 10:
    move r11, r1
    with r11
    add #10
    ldw (r11)           ; r0 = trap_ptr
    move r11, r0        ; r11 = trap_ptr

    with r11
    add #8              ; r11 = trap_ptr + 8 (dxL_dy)
    inc r1
    inc r1              ; r1 = frame_base + 2 (xL)

    ; xL += dxL_dy
    ldw (r1)
    move r3, r0
    ldw (r11)           ; r0 = dxL_dy
    with r3
    add r0
    from r3
    stw (r1)

    ; xR += dxR_dy
    inc r1
    inc r1              ; r1 = frame_base + 4 (xR)
    ldw (r1)
    move r3, r0
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    ldw (r11)           ; r0 = dxR_dy
    with r3
    add r0
    from r3
    stw (r1)

    ; uL += du_dy
    inc r1
    inc r1              ; r1 = frame_base + 6 (uL)
    ldw (r1)
    move r3, r0
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    ldw (r11)           ; r0 = du_dy
    with r3
    add r0
    from r3
    stw (r1)

    ; vL += dv_dy
    inc r1
    inc r1              ; r1 = frame_base + 8 (vL)
    ldw (r1)
    move r3, r0
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    ldw (r11)           ; r0 = dv_dy
    with r3
    add r0
    from r3
    stw (r1)

    iwt r15, #scanline_loop

@trap_finished:
    ; Flush GSU pixel caches to game pak RAM
    rpix
    rpix

    ; Deallocate stack frame (12 bytes)
    with r10
    sub #12
    return
endfunction
