; ==============================================================================
; draw_cached_trap_ram.i - Bank-$71 RAM Affine Textured Trapezoid Rasterizer
;
; Bank-$71 counterpart to `IsoEngine/triangle/draw_cached_trap.i`:
;   - Entire function fits 100% within the 512-byte GSU instruction cache
;   - Reads pre-shifted 8-byte texture descriptors from `TEXTURE_TABLE_RAM` ($70)
;   - Switches `RAMBR = 1` ($71) solely around `@pixel_loop`, fetching 8-bit
;     row-major texels via `ldb (r11); color` from `$71:0000 - $71:7FFF`
;   - Immediately restores `RAMBR = 0` ($70) after `@pixel_loop` so stack frame
;     reads/writes (`r10`) and caller state always see Bank $70
; ==============================================================================

.ifndef __GSU_ISO_DRAW_CACHED_TRAP_RAM__
__GSU_ISO_DRAW_CACHED_TRAP_RAM__ = 1

.include "../IsoEngine/triangle/cached_trap.i"
.include "../common/util.i"

.ifndef __TRAP_FRAME_DEFINED__
__TRAP_FRAME_DEFINED__ = 1
; Stack-allocated trapezoid state frame (12 bytes, 6 words in $70 GSURAM)
.struct trap_frame
    lines_left  .word ; +0: Number of scanlines remaining
    xL          .word ; +2: Current left edge X in Q8.8
    xR          .word ; +4: Current right edge X in Q8.8
    uL          .word ; +6: Current left edge U in Q8.8
    vL          .word ; +8: Current left edge V in Q(16 - stride_shift).(stride_shift)
    trap_ptr    .word ; +10: Base pointer to cached_trap struct in GSURAM
.endstruct
.endif

.global TEXTURE_TABLE_RAM

.segment "GSUCODE"

; ==============================================================================
; draw_cached_trap_ram
; Rasterizes a pre-compiled scanline trapezoid sampling texels from Bank $71.
;
; In:
;   trap_ptr    = r1: Pointer to cached_trap struct in Bank $70 GSURAM
;   anchor_x    = r3: Screen anchor X coordinate (integer pixels, signed)
;   anchor_y    = r4: Screen anchor Y coordinate (integer pixels, signed)
;   u_offset    = r5: World-space U offset in Q8.8
;   v_offset    = r6: World-space V offset in Q(16 - stride_shift).(stride_shift)
;   frame_half  = r7: Active frame half (0 = Pass 0 [0..127], 1 = Pass 1 [128..255])
;
; Postconditions:
;   - `RAMBR == 0` ($70) on all return paths
;   - Caller flushes dual 8-pixel plot caches via `rpix; rpix` at pass end
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function draw_cached_trap_ram trap_ptr, anchor_x, anchor_y, u_offset, v_offset, frame_half
    register trap_ptr = r1, anchor_x = r3, anchor_y = r4, u_offset = r5, v_offset = r6, frame_half = r7

    .align 16, $01
    cache

    ; Ensure cmode = 0 (transparency enabled: color 0 transparent, 1..15 opaque)
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

    ; If line_count <= 0: early exit (RAMBR is still 0)
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
    ; Note: `moves` sets OV = bit 7, so test 16-bit sign (S == 0) with `bpl`, never `bge`!
    moves anchor_y, anchor_y
    bpl @no_top_clip
    nop
    ibt r0, #0
    sub anchor_y        ; r0 = 0 - y
    move r9, r0         ; r9 = skip = -y

    from r9
    cmp r8
    bge @early_exit     ; if skip >= line_count, entirely off screen
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

    ; Allocate stack frame (12 bytes = .sizeof(trap_frame)) in Bank $70
    move r4, r10        ; r4 = frame_base
    with r10
    add #12

    ; Store lines_left (+0)
    from r8
    stw (r4)

    ; Compute anchor_x_eff in r11:
    move r11, anchor_x
    moves frame_half, frame_half
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
    moves r9, r9
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

    ; xL += dxL_dy (use r8 as scratch instead of r14 to avoid ROM buffer stalls)
    to r8
    ldw (r11)
    ldw (r3)
    add r8
    stw (r3)

    ; xR += dxR_dy
    inc r3
    inc r3
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    to r8
    ldw (r11)
    ldw (r3)
    add r8
    stw (r3)

    ; uL += du_dy
    inc r3
    inc r3
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    to r8
    ldw (r11)
    ldw (r3)
    add r8
    stw (r3)

    ; vL += dv_dy
    inc r3
    inc r3
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    to r8
    ldw (r11)
    ldw (r3)
    add r8
    stw (r3)

    loop
    nop
@skip_done:

    ; Read tex_id (+24 of cached_trap) and lookup TEXTURE_TABLE_RAM in Bank $70
    ibt r0, #24
    from trap_ptr
    to r11
    add r0              ; r11 = trap_ptr + 24 (tex_id)
    ldw (r11)           ; r0 = tex_id

    add r0              ; tex_id * 2
    add r0              ; tex_id * 4
    add r0              ; tex_id * 8
    iwt r11, #TEXTURE_TABLE_RAM
    add r11
    move r11, r0

    ldw (r11)           ; r0 = atlas_offset ($0000..$7FFF in Bank $71)
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

    ; Mask UV offsets and add to uL, vL
    with r6
    and r11             ; r6 = masked v_offset

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
    ;   r9  = atlas_offset in Bank $71 ($0000..$7FFF)
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

    iwt r11, #$00FF

    ; Check if r4 has bit 15 set (xR >= 128):
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

    ; Check if r3 has bit 15 set (xL < 0):
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

    ; Clip left edge against 0 (`moves` sets OV = bit 7, so test S == 0 via `bpl`):
    moves r3, r3
    bpl @no_clip_left
    nop
    ibt r0, #0
    sub r3              ; r0 = -r3
    move r12, r0        ; r12 = clip_left
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

    ; Switch RAMBR = 1 (Game Pak RAM Bank $71) for texel reads
    ibt r0, #1
    ramb

    iwt r13, #@pixel_loop
@pixel_loop:
    from r3
    hib                 ; r0 = u_cur >> 8
    to r11
    and r7              ; r11 = (u_cur >> 8) & u_mask
    from r4
    and r8              ; r0 = v_cur & v_mask_shifted
    add r11             ; r0 = col + row
    to r11
    add r9              ; r11 = Bank-$71 texel address (R0..R11 valid for ldb)
    ldb (r11)           ; r0 = unsigned texel index from $71:(r11)
    color               ; latch pixel color into COLR
    with r3
    add r5              ; u_cur += du_dx
    with r4
    add r6              ; v_cur += dv_dx
    loop
    plot                ; Delay slot: plot pixel at (R1, R2) and increment R1

    ; Immediately restore RAMBR = 0 (Bank $70) before touching stack frame!
    ibt r0, #0
    ramb

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
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)

    ; xR += dxR_dy
    inc r1
    inc r1
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)

    ; uL += du_dy
    inc r1
    inc r1
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)

    ; vL += dv_dy
    inc r1
    inc r1
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)

    iwt r13, #scanline_loop
    jmp r13
    nop

@trap_finished:
    ; Deallocate stack frame (12 bytes)
    with r10
    sub #12
    return
endfunction

.endif ; __GSU_ISO_DRAW_CACHED_TRAP_RAM__
