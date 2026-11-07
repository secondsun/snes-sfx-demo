; ==============================================================================
; draw_cached_trap.i - Affine Textured Scanline Trapezoid Rasterizer for SuperFX
;
; Optimized Cache-Resident Implementation:
;   - Entire function fits 100% within the 512-byte GSU instruction cache
;   - Stack-allocated trapezoid state frame: 12 bytes on stack
;   - Pre-shifted TEXTURE_TABLE integration (zero runtime shift loop)
;   - Pipelined 16-byte inner pixel loop with early R14 prefetch and delay-slot plot
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
.ifdef TEXTURE_TABLE_IN_RAM
.global TEXTURE_TABLE_RAM
.endif

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

    .align 16, $01
    cache

    ; Ensure cmode = 0 (bit 0 = 0: transparency enabled: color 0 transparent, 1..15 opaque)
    ibt r0, #0
    cmode

    ; Read dy_start from trap_ptr (+0)
    ldw (trap_ptr)      ; r0 = dy_start
    with anchor_y
    add r0              ; anchor_y = y = anchor_y + dy_start

    ; Read line_count from trap_ptr + 2
    from trap_ptr
    to r11
    add #2              ; r11 = trap_ptr + 2
    to r8
    ldw (r11)           ; r8 = line_count

    ; If line_count <= 0: early exit
    from r8
    sub #1
    blt @early_exit
    nop

    ; Check if completely above screen: y_end <= 0
    from anchor_y
    add r8              ; r0 = y_end = y + line_count
    sub #1              ; r0 = y_end - 1
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
    ibt r0, #0
    sub anchor_y        ; r0 = 0 - y
    move r9, r0         ; r9 = skip = -y

    from r9
    cmp r8
    bge @early_exit     ; if skip >= line_count, entirely off screen!
    nop
    with r8
    sub r9              ; r8 = line_count - skip
    ibt anchor_y, #0    ; y = 0
    bra @top_clip_done
    nop

@no_top_clip:
    ibt r9, #0          ; skip = 0

@top_clip_done:
    ; Bottom clipping: if y + line_count > 160, line_count = 160 - y (r11 is still 160)
    from anchor_y
    add r8              ; r0 = y_end = anchor_y + line_count
    from r11
    cmp r0              ; compare 160 with y_end
    bge @bottom_clip_done
    nop
    ; y_end > 160:
    from r11
    to r8
    sub anchor_y        ; r8 = line_count = 160 - y

@bottom_clip_done:
    from r8
    sub #1
    bge @not_early_exit
    nop

@early_exit:
    return

@not_early_exit:
    ; Save starting Y in r2 (SuperFX hardware Y coordinate register for plot)
    move r2, anchor_y

    ; Allocate stack frame (12 bytes = .sizeof(trap_frame))
    move r4, r10        ; r4 = frame_base
    with r10
    add #12             ; advance r10 by 12 bytes

    ; Store lines_left (+0)
    from r8
    stw (r4)

    ; Compute anchor_x_eff in r11:
    move r11, anchor_x
    from frame_half
    sub #0
    beq :+
    nop
    ibt r0, #$80
    with r11
    add r0              ; if frame_half == 1, subtract 128
:
    with r11
    lob
    with r11
    swap
    ; Sequentially initialize trap_frame from cached_trap:
    move r3, r4
    inc r3
    inc r3              ; r3 = frame_base + 2 (xL)

    from trap_ptr
    to r8
    add #4              ; r8 = trap_ptr + 4 (xL_start)
    ldw (r8)            ; r0 = xL_start
    with r0
    add r11             ; r0 = xL = xL_start + anchor_x_eff
    stw (r3)            ; store xL at frame_base + 2

    inc r8
    inc r8              ; r8 = trap_ptr + 6 (xR_start)
    inc r3
    inc r3              ; r3 = frame_base + 4 (xR)
    ldw (r8)            ; r0 = xR_start
    with r0
    add r11             ; r0 = xR = xR_start + anchor_x_eff
    stw (r3)            ; store xR at frame_base + 4

    with r8
    add #6              ; r8 = trap_ptr + 12 (uL_start)
    inc r3
    inc r3              ; r3 = frame_base + 6 (uL)
    ldw (r8)            ; r0 = uL_start
    stw (r3)            ; store uL at frame_base + 6

    inc r8
    inc r8              ; r8 = trap_ptr + 14 (vL_start)
    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    ldw (r8)            ; r0 = vL_start
    stw (r3)            ; store vL at frame_base + 8

    inc r3
    inc r3              ; r3 = frame_base + 10 (trap_ptr)
    from trap_ptr
    stw (r3)            ; store trap_ptr at frame_base + 10

    ; If top clipping skipped scanlines (r9 > 0): advance edges by skip now
    from r9
    sub #0
    beq @skip_done
    nop
    move r12, r9        ; r12 = skip count
    iwt r13, #@skip_loop
@skip_loop:
    from trap_ptr
    to r11
    add #8              ; r11 = trap_ptr + 8 (dxL_dy)
    move r3, r4
    inc r3
    inc r3              ; r3 = frame_base + 2 (xL)

    ; xL += dxL_dy
    to r14
    ldw (r11)           ; r14 = dxL_dy
    ldw (r3)            ; r0 = xL
    add r14
    stw (r3)

    ; xR += dxR_dy
    inc r3
    inc r3              ; r3 = frame_base + 4 (xR)
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    to r14
    ldw (r11)           ; r14 = dxR_dy
    ldw (r3)            ; r0 = xR
    add r14
    stw (r3)

    ; uL += du_dy
    inc r3
    inc r3              ; r3 = frame_base + 6 (uL)
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    to r14
    ldw (r11)           ; r14 = du_dy
    ldw (r3)            ; r0 = uL
    add r14
    stw (r3)

    ; vL += dv_dy
    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    to r14
    ldw (r11)           ; r14 = dv_dy
    ldw (r3)            ; r0 = vL
    add r14
    stw (r3)

    loop
    nop
@skip_done:

    ; Read tex_id (+24 of cached_trap)
    ibt r0, #24
    from trap_ptr
    to r11
    add r0              ; r11 = trap_ptr + 24 (tex_id)
    ldw (r11)           ; r0 = tex_id

    ; Lookup TEXTURE_TABLE + (tex_id << 3)
    add r0              ; tex_id * 2
    add r0              ; tex_id * 4
    add r0              ; tex_id * 8
.ifdef TEXTURE_TABLE_IN_RAM
    iwt r11, #TEXTURE_TABLE_RAM
.else
    iwt r11, #TEXTURE_TABLE
.endif
    add r11             ; r0 = TEXTURE_TABLE + (tex_id << 3)

.ifdef TEXTURE_TABLE_IN_RAM
    move r11, r0
    ldw (r11)           ; r0 = rom_offset
    move r9, r0
    inc r11
    inc r11
    ldw (r11)           ; r0 = u_mask
    move r7, r0
    inc r11
    inc r11
    ldw (r11)           ; r0 = v_mask_shifted
    move r8, r0
    inc r11
    inc r11
    ldw (r11)           ; r0 = v_offset_mask
    move r11, r0
.else
    move r14, r0        ; r14 = ROM address of texture descriptor in TEXTURE_TABLE
    _romreadwordLE r9   ; r9 = rom_offset
    _romreadwordLE r7   ; r7 = u_mask
    _romreadwordLE r8   ; r8 = v_mask_shifted
    _romreadwordLE r11  ; r11 = v_offset_mask
.endif

.ifdef TEXTURE_BASE_ADDR
    iwt r0, #TEXTURE_BASE_ADDR
    with r9
    add r0
.endif

    ; Mask UV offsets and add to uL, vL
    ; v_offset (r6) is Q10.6, pre-shifted wrap mask is r11
    with r6
    and r11             ; r6 = masked v_offset

    ; u_offset (r5) is Q8.8, mask is (u_mask << 8) | $00FF
    move r12, r7
    with r12
    swap                ; r12 = u_mask << 8
    iwt r11, #$00FF
    with r12
    or r11              ; r12 = (u_mask << 8) | $00FF
    with r5
    and r12             ; r5 = masked u_offset

    move r3, r4
    with r3
    add #6              ; r3 = frame_base + 6 (uL)
    ldw (r3)            ; r0 = uL
    with r0
    add r5
    stw (r3)            ; uL += masked u_offset

    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    ldw (r3)            ; r0 = vL
    with r0
    add r6
    stw (r3)            ; vL += masked v_offset

    ; Load du_dx (+20) into r5, dv_dx (+22) into r6
    ibt r0, #20
    from trap_ptr
    to r11
    add r0              ; r11 = trap_ptr + 20 (du_dx)
    to r5
    ldw (r11)           ; r5 = du_dx

    inc r11
    inc r11             ; r11 = trap_ptr + 22 (dv_dx)
    to r6
    ldw (r11)           ; r6 = dv_dx

    ; --------------------------------------------------------------------------
    ; Register Invariants Across Scanlines:
    ;   r2  = Y scanline
    ;   r5  = du_dx (Q8.8)
    ;   r6  = dv_dx (Q(16-S).S)
    ;   r7  = u_mask
    ;   r8  = v_mask_shifted
    ;   r9  = rom_offset
    ; --------------------------------------------------------------------------
scanline_loop:
    from r10
    to r1
    sub #12             ; r1 = frame_base

    inc r1
    inc r1              ; r1 = frame_base + 2 (xL)
    to r3
    ldw (r1)            ; r3 = xL

    inc r1
    inc r1              ; r1 = frame_base + 4 (xR)
    to r4
    ldw (r1)            ; r4 = xR

    ; If both xL and xR have bit 15 set (both < 0 or both >= 128):
    from r3
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
    bge @skip_scanline
    nop

    ; --- Begin span ---
    inc r1
    inc r1              ; r1 = frame_base + 6 (uL)
    to r11
    ldw (r1)            ; r11 = u_cur = uL
    inc r1
    inc r1              ; r1 = frame_base + 8 (vL)
    to r14
    ldw (r1)            ; r14 = v_cur = vL

    ; Clip left edge against 0:
    from r3
    sub #0
    bge @no_clip_left
    nop
    ; r3 < 0:
    ibt r0, #0
    sub r3              ; r0 = 0 - r3
    move r12, r0        ; r12 = clip_left = -r3
    ibt r3, #0          ; x_start = 0

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

@draw_span:
    move r12, r0        ; r12 = pixel_count
    move r1, r3         ; r1 = x_start (plot X)
    move r3, r11        ; r3 = u_cur
    move r4, r14        ; r4 = v_cur

    ; Prime R14 with first texel ROM address:
    from r3
    hib                 ; r0 = u_cur >> 8
    to r11
    and r7              ; r11 = u_int & u_mask
    from r4
    and r8              ; r0 = v_cur & v_mask_shifted
    add r11             ; r0 = col + row
    to r14
    add r9              ; Prime R14 (starts hardware ROM prefetch for pixel 0!)
    with r3
    add r5              ; Advance u_cur to pixel 1 while R14 prefetches
    with r4
    add r6              ; Advance v_cur to pixel 1 while R14 prefetches

    iwt r13, #@pixel_loop
@pixel_loop:
    getc                ; Latch pixel k color from RomBuf into COLR
    from r3
    hib                 ; r0 = u_{k+1} >> 8
    to r11
    and r7              ; r11 = (u_{k+1} >> 8) & u_mask
    from r4
    and r8              ; r0 = v_{k+1} & v_mask_shifted
    add r11             ; r0 = col + row
    to r14
    add r9              ; Start R14 ROM prefetch for pixel k+1 early!
    with r3
    add r5              ; u_cur += du_dx (hides R14 prefetch latency)
    with r4
    add r6              ; v_cur += dv_dx (hides R14 prefetch latency)
    loop
    plot                ; Delay slot: plot pixel k at (R1, R2) and increment R1

@skip_scanline:
@advance_scanline:
    inc r2              ; next Y scanline

    from r10
    to r1
    sub #12             ; r1 = frame_base

    ldw (r1)            ; r0 = lines_left
    dec r0
    stw (r1)            ; save lines_left
    beq @trap_finished
    nop

@lines_remain_adv:
    ; Read trap_ptr from frame_base + 10:
    from r1
    to r11
    add #10
    to r11
    ldw (r11)           ; r11 = trap_ptr

    with r11
    add #8              ; r11 = trap_ptr + 8 (dxL_dy)
    inc r1
    inc r1              ; r1 = frame_base + 2 (xL)

    ; xL += dxL_dy
    to r3
    ldw (r11)           ; r3 = dxL_dy
    ldw (r1)            ; r0 = xL
    add r3
    stw (r1)

    ; xR += dxR_dy
    inc r1
    inc r1              ; r1 = frame_base + 4 (xR)
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    to r3
    ldw (r11)           ; r3 = dxR_dy
    ldw (r1)            ; r0 = xR
    add r3
    stw (r1)

    ; uL += du_dy
    inc r1
    inc r1              ; r1 = frame_base + 6 (uL)
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    to r3
    ldw (r11)           ; r3 = du_dy
    ldw (r1)            ; r0 = uL
    add r3
    stw (r1)

    ; vL += dv_dy
    inc r1
    inc r1              ; r1 = frame_base + 8 (vL)
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    to r3
    ldw (r11)           ; r3 = dv_dy
    ldw (r1)            ; r0 = vL
    add r3
    stw (r1)

    iwt r13, #scanline_loop
    jmp r13
    nop

@trap_finished:
    ; Flush GSU pixel caches to game pak RAM
    rpix
    rpix

    ; Deallocate stack frame (12 bytes)
    with r10
    sub #12
    return
endfunction
