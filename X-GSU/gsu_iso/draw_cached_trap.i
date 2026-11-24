; ==============================================================================
; draw_cached_trap.i - Unified SuperFX Affine Textured Trapezoid Rasterizer
;
; Defines `_gsu_define_trap_rasterizer`, a single macro generator instantiating
; two separate, zero-overhead 512B-cache-resident leaf functions:
;   - `draw_cached_trap`     (`use_bank71_ram = 0`, defined by this file):
;       Samples 8-bit row-major texels from ROM (`ROMBR`, `$04:8000+`) via a
;       16-byte pipelined `getc; ...; to r14; add r9; ...; loop; plot` inner loop.
;   - `draw_cached_trap_ram` (`use_bank71_ram = 1`, defined by `draw_cached_trap_ram.i`):
;       Switches `RAMBR = 1` (`$71`) solely around `@pixel_loop`, fetching 8-bit
;       row-major texels from `$71:0000 - $71:7FFF` via an 18-byte `ldb (r11); color`
;       loop and immediately restoring `RAMBR = 0` (`$70`) on exit.
;
; Shared Invariants Across Both Leaves:
;   - Both leaves fit 100% inside the 512-byte GSU instruction cache (verified at
;     build time via `.assert (cbr_end - cbr_anchor) <= 512`).
;   - Both leaves read pre-shifted 8-byte texture descriptors from Bank-$70
;     `TEXTURE_TABLE_RAM` (`offset, u_mask, v_mask_shifted, v_offset_mask`).
;   - Zero spurious `R14` ROM prefetch stalls during `@skip_loop` (uses `r8`) or
;     `@clip_u_loop` (keeps `v_cur` in `r1` during left-edge clipping).
;   - `moves Rn, Rn` is paired exclusively with `bpl`/`beq` (never `bge`/`blt`).
;   - Caller flushes dual 8-pixel plot caches once per pass via `rpix; rpix`.
; ==============================================================================

.ifndef __GSU_TRAP_RASTERIZER_MACRO__
__GSU_TRAP_RASTERIZER_MACRO__ = 1

.include "../IsoEngine/triangle/cached_trap.i"
.include "../common/util.i"

.ifndef GSU_TRAP_SCREEN_H
    GSU_TRAP_SCREEN_H = 160
.endif
.ifndef GSU_TRAP_PASS1_MAX_X
    GSU_TRAP_PASS1_MAX_X = 128
.endif

.if GSU_TRAP_PASS1_MAX_X < 128
.segment "GSURAM"
.align 2
gsu_trap_max_x: .res 2
.segment "GSUCODE"
.endif

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

; Streaming trapezoid batch entry (14 bytes, 7 words in $70 GSURAM)
.struct trap_batch_entry
    trap_ptr     .word ; +0:  Pointer to cached_trap in Bank $70 GSURAM
    line_count   .word ; +2:  Scanline count (>= 1)
    anchor_x_eff .word ; +4:  Pre-biased ((anchor_x - 128*frame_half) & $FF) << 8
    anchor_y     .word ; +6:  Screen anchor Y (signed integer)
    u_offset     .word ; +8:  World-space U offset (Q8.8)
    v_offset     .word ; +10: World-space V offset (Q(16-S).S)
    tex_id       .word ; +12: Texture ID (0..255; $F0..$FF = solid palette color)
.endstruct

.ifndef GSU_TRAP_BATCH_CAP
    GSU_TRAP_BATCH_CAP = 32
.endif

.segment "GSURAM"
.align 2
gsu_trap_batch_buf:     .res (GSU_TRAP_BATCH_CAP * .sizeof(trap_batch_entry))
gsu_trap_batch_ptr:     .res 2
gsu_trap_batch_count:   .res 2
gsu_trap_batch_cur:     .res 2
gsu_trap_batch_rem:     .res 2
gsu_trap_batch_tex_id:  .res 2
gsu_trap_batch_mode:    .res 2  ; 0 = textured batch, 1 = flat-color ($F0..$FF) batch
.segment "GSUCODE"
.endif

.global TEXTURE_TABLE_RAM

; ==============================================================================
; _gsu_define_trap_rasterizer fn_name, use_bank71_ram
;
; Instantiates a 512B-cache-resident affine trapezoid rasterizer leaf function.
;
; In:
;   r1 = trap_ptr   : Pointer to cached_trap struct in Bank $70 GSURAM
;   r3 = anchor_x   : Screen anchor X coordinate (integer pixels, signed)
;   r4 = anchor_y   : Screen anchor Y coordinate (integer pixels, signed)
;   r5 = u_offset   : World-space U offset in Q8.8
;   r6 = v_offset   : World-space V offset in Q(16 - stride_shift).(stride_shift)
;   r7 = frame_half : Active frame half (0 = Pass 0 [0..127], 1 = Pass 1 [128..255])
;
; Postconditions:
;   - `RAMBR == 0` ($70) on all return paths
;   - Caller flushes dual 8-pixel plot caches via `rpix; rpix` at pass end
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
.macro _gsu_define_trap_rasterizer fn_name, use_bank71_ram
function fn_name
    .align 16, $01
cbr_anchor:
    cache

    ; Ensure cmode = 0 (transparency enabled: color 0 transparent, 1..max opaque)
    ibt r0, #0
    cmode

    ; Read dy_start from trap_ptr (+0)
    ldw (r1)            ; r0 = dy_start
    with r4
    add r0              ; r4 = y = anchor_y + dy_start

    ; Read line_count from trap_ptr + 2
    from r1
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
    from r4
    add r8              ; r0 = y_end = y + line_count
    sub #1              ; r0 = y_end - 1
    blt @early_exit
    nop

    ; Check if completely below screen: y >= GSU_TRAP_SCREEN_H
    iwt r11, #GSU_TRAP_SCREEN_H
    from r4
    cmp r11
    bge @early_exit
    nop

    ; Top clipping: if y < 0, skip = -y, y = 0, line_count -= skip
    ; Note: `moves` sets OV = bit 7, so test 16-bit sign (S == 0) with `bpl`, never `bge`!
    moves r4, r4
    bpl @no_top_clip
    nop
    ibt r0, #0
    sub r4              ; r0 = 0 - y
    move r9, r0         ; r9 = skip = -y

    from r9
    cmp r8
    bge @early_exit     ; if skip >= line_count, entirely off screen
    nop
    with r8
    sub r9              ; r8 = line_count - skip
    ibt r4, #0          ; y = 0
    bra @top_clip_done
    nop

@no_top_clip:
    ibt r9, #0          ; skip = 0

@top_clip_done:
    ; Bottom clipping: if y + line_count > 160, line_count = 160 - y (r11 is still 160)
    from r4
    add r8              ; r0 = y_end = y + line_count
    from r11
    cmp r0              ; compare 160 with y_end
    bge @bottom_clip_done
    nop
    from r11
    to r8
    sub r4              ; r8 = line_count = 160 - y

@bottom_clip_done:
    from r8
    sub #1
    bge @not_early_exit
    nop

@early_exit:
    return

@not_early_exit:
    ; Save starting Y in r2 (SuperFX hardware Y coordinate register for plot)
    move r2, r4

    ; Allocate stack frame (12 bytes = .sizeof(trap_frame)) in Bank $70
    move r4, r10        ; r4 = frame_base
    with r10
    add #12

    ; Store lines_left (+0)
    from r8
    stw (r4)

    ; Compute anchor_x_eff in r11:
    move r11, r3        ; r11 = anchor_x
    moves r7, r7        ; test frame_half == 0
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

    from r1
    to r8
    add #4              ; r8 = trap_ptr + 4 (xL_start)
    ldw (r8)            ; r0 = xL_start
    add r11             ; r0 = xL = xL_start + anchor_x_eff
    stw (r3)            ; store xL at frame_base + 2

    inc r8
    inc r8              ; r8 = trap_ptr + 6 (xR_start)
    inc r3
    inc r3              ; r3 = frame_base + 4 (xR)
    ldw (r8)            ; r0 = xR_start
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
    from r1
    stw (r3)            ; store trap_ptr at frame_base + 10
.if ::GSU_TRAP_PASS1_MAX_X < 128
    iwt r0, #128
    moves r7, r7        ; frame_half == 0 -> max_x = 128; frame_half != 0 -> GSU_TRAP_PASS1_MAX_X
    beq @store_max_x
    nop
    ibt r0, #::GSU_TRAP_PASS1_MAX_X
@store_max_x:
    sm (gsu_trap_max_x), r0
.endif

    ; If top clipping skipped scanlines (r9 > 0): constant-time lmult edge advance
    moves r9, r9
    beq @skip_done
    nop
    move r7, r6         ; preserve v_offset across lmult
    move r3, r4         ; r3 = frame_base (before lmult clobbers r4)
    inc r3
    inc r3              ; r3 = frame_base + 2 (xL)
    move r6, r9         ; r6 = skip count

    from r1
    to r11
    add #8              ; r11 = trap_ptr + 8 (dxL_dy)

    ; xL += dxL_dy * skip
    ldw (r11)
    lmult               ; r4 = low16(dxL_dy * skip)
    ldw (r3)
    add r4
    stw (r3)

    ; xR += dxR_dy * skip
    inc r3
    inc r3
    inc r11
    inc r11             ; r11 = trap_ptr + 10 (dxR_dy)
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)

    ; uL += du_dy * skip
    inc r3
    inc r3
    with r11
    add #6              ; r11 = trap_ptr + 16 (du_dy)
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)

    ; vL += dv_dy * skip
    inc r3
    inc r3
    inc r11
    inc r11             ; r11 = trap_ptr + 18 (dv_dy)
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)

    move r6, r7         ; restore v_offset
@skip_done:

    ; Read tex_id (+24 of cached_trap) and lookup TEXTURE_TABLE_RAM in Bank $70
    ibt r0, #24
    from r1
    to r11
    add r0              ; r11 = trap_ptr + 24 (tex_id)
    ldw (r11)           ; r0 = tex_id

    add r0              ; tex_id * 2
    add r0              ; tex_id * 4
    add r0              ; tex_id * 8
    iwt r11, #TEXTURE_TABLE_RAM
    with r11
    add r0

    to r9
    ldw (r11)           ; r9 = base_offset (ROM $8000+ or Bank-$71 $0000..$7FFF)
    inc r11
    inc r11
    to r7
    ldw (r11)           ; r7 = u_mask
    inc r11
    inc r11
    to r8
    ldw (r11)           ; r8 = v_mask_shifted
    inc r11
    inc r11
    to r11
    ldw (r11)           ; r11 = v_offset_mask

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

    from r10
    to r3
    sub #6              ; r3 = frame_base + 6 (uL)
    ldw (r3)
    add r5
    stw (r3)            ; uL += masked u_offset

    inc r3
    inc r3              ; r3 = frame_base + 8 (vL)
    ldw (r3)
    add r6
    stw (r3)            ; vL += masked v_offset

    ; Load du_dx (+20) into r5, dv_dx (+22) into r6
    ibt r0, #20
    from r1
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
    ;   r9  = base_offset (ROM $04:8000+ or Bank-$71 $0000..$7FFF)
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
    bpl :+
    nop
    iwt r15, #@skip_scanline
    nop
:

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
.if ::GSU_TRAP_PASS1_MAX_X < 128
    ; Clamp xR_int (r4) to active half's max_x (128 on Pass 0, e.g. 64 on Pass 1 for 192px)
    lm r0, (gsu_trap_max_x)
    from r4
    cmp r0
    blt @xR_clamped
    nop
    move r4, r0
@xR_clamped:
.endif

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
    to r1
    ldw (r1)            ; r1 = v_cur = vL (held in r1 instead of r14 -> zero ROM stalls!)

    ; Clip left edge against 0 (`moves` sets OV = bit 7, so test S == 0 via `bpl`):
    ; Constant-time lmult: v_cur += dv_dx * clip_left, u_cur += du_dx * clip_left
    moves r3, r3
    bpl @no_clip_left
    nop
    move r12, r4        ; preserve xR_int across lmult (lmult clobbers r4)
    ibt r0, #0
    sub r3              ; r0 = clip_left = -xL_int
    move r13, r0        ; r13 = clip_left

    from r13
    lmult               ; r4 = low16(clip_left * dv_dx) [r6 is already dv_dx]
    with r1
    add r4              ; v_cur += dv_dx * clip_left

    move r3, r6         ; preserve dv_dx in r3
    move r6, r5         ; r6 = du_dx
    from r13
    lmult               ; r4 = low16(clip_left * du_dx)
    with r11
    add r4              ; u_cur += du_dx * clip_left

    move r6, r3         ; restore dv_dx
    move r4, r12        ; restore xR_int
    ibt r3, #0          ; x_start = 0

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
    move r4, r1         ; r4 = v_cur (read r1 before overwriting r1 with x_start!)
    move r1, r3         ; r1 = x_start (plot X)
    move r3, r11        ; r3 = u_cur

.if use_bank71_ram
    ; Switch RAMBR = 1 (Game Pak RAM Bank $71) for texel reads
    ibt r0, #1
    ramb

    iwt r13, #@pixel_loop_ram
@pixel_loop_ram:
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
.else
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
.endif

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
cbr_end:
    .assert (cbr_end - cbr_anchor) <= 512, error, .concat(.string(fn_name), " exceeds 512-byte GSU instruction cache")
endfunction
.endmacro

; ==============================================================================
; _gsu_define_trap_batch_rasterizer fn_name, use_bank71_ram
;
; Instantiates a 512B-cache-resident batched trapezoid rasterizer leaf that
; drains `count` queued `trap_batch_entry` records without leaving the 512B
; GSU instruction cache.
;
; In:
;   r1 = batch_buf_ptr : Pointer to first `trap_batch_entry` in Bank $70
;   r2 = count         : Number of queued entries (>= 1)
;   r7 = frame_half    : Active frame half (0 = Pass 0, 1 = Pass 1)
; ==============================================================================
.macro _gsu_define_trap_batch_rasterizer fn_name, use_bank71_ram
function fn_name
    ; One-time batch setup (outside 512B cache so IsoRPGDemo 192px clamp fits easily)
    sm (gsu_trap_batch_cur), r1
    sm (gsu_trap_batch_rem), r2
.if ::GSU_TRAP_PASS1_MAX_X < 128
    iwt r0, #128
    moves r7, r7
    beq @b_store_max_x
    nop
    ibt r0, #::GSU_TRAP_PASS1_MAX_X
@b_store_max_x:
    sm (gsu_trap_max_x), r0
.endif
    ibt r0, #0
    cmode
    with r10
    add #12                 ; Allocate 12B trap_frame once for entire batch

    .align 16, $01
batch_cbr_anchor:
    cache

@batch_loop:
    ; Load 7-word trap_batch_entry sequentially from gsu_trap_batch_cur:
    ;   r1=trap_ptr, r8=line_count, r11=anchor_x_eff, r4=anchor_y, r5=u_off, r6=v_off
    lm r3, (gsu_trap_batch_cur)
    to r1
    ldw (r3)                ; +0: trap_ptr
    inc r3
    inc r3
    to r8
    ldw (r3)                ; +2: line_count
    inc r3
    inc r3
    to r11
    ldw (r3)                ; +4: anchor_x_eff
    inc r3
    inc r3
    to r4
    ldw (r3)                ; +6: anchor_y
    inc r3
    inc r3
    to r5
    ldw (r3)                ; +8: u_offset
    inc r3
    inc r3
    to r6
    ldw (r3)                ; +10: v_offset
    inc r3
    inc r3
    ldw (r3)                ; +12: tex_id
    sm (gsu_trap_batch_tex_id), r0
    inc r3
    inc r3
    sm (gsu_trap_batch_cur), r3

    ; r4 = y = anchor_y + dy_start (+0)
    ldw (r1)
    with r4
    add r0

    ; Reject line_count <= 0, y + line_count <= 0, or y >= SCREEN_H
    from r8
    sub #1
    blt @b_next_tramp
    nop
    from r4
    add r8
    sub #1
    blt @b_next_tramp
    nop
    iwt r7, #GSU_TRAP_SCREEN_H
    from r4
    cmp r7
    bge @b_next_tramp
    nop

    ; Top clipping
    moves r4, r4
    bpl @b_no_top_clip
    nop
    ibt r0, #0
    sub r4
    move r9, r0             ; r9 = skip = -y
    from r9
    cmp r8
    bge @b_next_tramp
    nop
    with r8
    sub r9
    ibt r4, #0
    bra @b_top_clip_done
    nop
@b_next_tramp:
    iwt r15, #@batch_next
    nop
@b_no_top_clip:
    ibt r9, #0
@b_top_clip_done:
    ; Bottom clipping (r7 still = GSU_TRAP_SCREEN_H)
    from r4
    add r8
    from r7
    cmp r0
    bge @b_bot_clip_done
    nop
    from r7
    to r8
    sub r4
@b_bot_clip_done:
    move r2, r4             ; r2 = plot Y

    ; Populate trap_frame at r10 - 12:
    from r10
    to r4
    sub #12                 ; r4 = frame_base
    from r8
    stw (r4)                ; +0: lines_left

    move r3, r4
    inc r3
    inc r3                  ; r3 = frame_base + 2 (xL)
    from r1
    to r8
    add #4                  ; r8 = trap_ptr + 4 (xL_start)
    ldw (r8)
    add r11
    stw (r3)                ; +2: xL
    inc r8
    inc r8
    inc r3
    inc r3
    ldw (r8)
    add r11
    stw (r3)                ; +4: xR
    with r8
    add #6                  ; r8 = trap_ptr + 12 (uL_start)
    inc r3
    inc r3
    ldw (r8)
    stw (r3)                ; +6: uL
    inc r8
    inc r8
    inc r3
    inc r3
    ldw (r8)
    stw (r3)                ; +8: vL
    inc r3
    inc r3
    from r1
    stw (r3)                ; +10: trap_ptr

    ; Constant-time top-clip advance if skip (r9) > 0
    moves r9, r9
    beq @b_skip_done
    nop
    move r7, r6             ; preserve v_offset
    move r3, r4
    inc r3
    inc r3                  ; frame_base + 2 (xL)
    move r6, r9
    from r1
    to r11
    add #8                  ; trap_ptr + 8 (dxL_dy)
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)
    inc r3
    inc r3
    inc r11
    inc r11
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)
    inc r3
    inc r3
    with r11
    add #6
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)
    inc r3
    inc r3
    inc r11
    inc r11
    ldw (r11)
    lmult
    ldw (r3)
    add r4
    stw (r3)
    move r6, r7
@b_skip_done:

    ; Lookup TEXTURE_TABLE_RAM using gsu_trap_batch_tex_id
    lm r0, (gsu_trap_batch_tex_id)
    add r0
    add r0
    add r0
    iwt r11, #TEXTURE_TABLE_RAM
    with r11
    add r0
    to r9
    ldw (r11)               ; r9 = base_offset
    inc r11
    inc r11
    to r7
    ldw (r11)               ; r7 = u_mask
    inc r11
    inc r11
    to r8
    ldw (r11)               ; r8 = v_mask_shifted
    inc r11
    inc r11
    to r11
    ldw (r11)               ; r11 = v_offset_mask

    with r6
    and r11
    move r12, r7
    with r12
    swap
    iwt r11, #$00FF
    with r12
    or r11
    with r5
    and r12

    from r10
    to r3
    sub #6                  ; frame_base + 6 (uL)
    ldw (r3)
    add r5
    stw (r3)
    inc r3
    inc r3
    ldw (r3)
    add r6
    stw (r3)

    ibt r0, #20
    from r1
    to r11
    add r0
    to r5
    ldw (r11)               ; r5 = du_dx
    inc r11
    inc r11
    to r6
    ldw (r11)               ; r6 = dv_dx

@b_scanline_loop:
    from r10
    to r1
    sub #10                 ; r1 = frame_base + 2 (xL)
    to r3
    ldw (r1)
    inc r1
    inc r1
    to r4
    ldw (r1)

    from r3
    and r4
    bpl :+
    nop
    iwt r15, #@b_advance_scanline
    nop
:
    moves r4, r4
    bpl :+
    nop
    iwt r4, #128
    bra @b_xR_ok
    nop
:
    with r4
    hib
@b_xR_ok:
    moves r3, r3
    bpl :+
    nop
    with r3
    hib
    with r3
    sex
    bra @b_xL_ok
    nop
:
    with r3
    hib
@b_xL_ok:
.if ::GSU_TRAP_PASS1_MAX_X < 128
    lm r0, (gsu_trap_max_x)
    from r4
    cmp r0
    blt @b_xR_clamped
    nop
    move r4, r0
@b_xR_clamped:
.endif
    from r3
    cmp r4
    bge @b_advance_scanline
    nop

    inc r1
    inc r1                  ; frame_base + 6 (uL)
    to r11
    ldw (r1)
    inc r1
    inc r1                  ; frame_base + 8 (vL)
    to r1
    ldw (r1)

    moves r3, r3
    bpl @b_no_clip_left
    nop
    move r12, r4
    ibt r0, #0
    sub r3
    move r13, r0
    from r13
    lmult
    with r1
    add r4
    move r3, r6
    move r6, r5
    from r13
    lmult
    with r11
    add r4
    move r6, r3
    move r4, r12
    ibt r3, #0
@b_no_clip_left:
    from r4
    sub r3
    beq @b_advance_scanline
    nop
    bmi @b_advance_scanline
    nop

    move r12, r0
    move r4, r1
    move r1, r3
    move r3, r11

.if use_bank71_ram
    ibt r0, #1
    ramb
    iwt r13, #@b_pixel_loop_ram
@b_pixel_loop_ram:
    from r3
    hib
    to r11
    and r7
    from r4
    and r8
    add r11
    to r11
    add r9
    ldb (r11)
    color
    with r3
    add r5
    with r4
    add r6
    loop
    plot
    ibt r0, #0
    ramb
.else
    from r3
    hib
    to r11
    and r7
    from r4
    and r8
    add r11
    to r14
    add r9
    with r3
    add r5
    with r4
    add r6
    iwt r13, #@b_pixel_loop
@b_pixel_loop:
    getc
    from r3
    hib
    to r11
    and r7
    from r4
    and r8
    add r11
    to r14
    add r9
    with r3
    add r5
    with r4
    add r6
    loop
    plot
.endif

@b_advance_scanline:
    inc r2
    from r10
    to r1
    sub #12
    ldw (r1)
    dec r0
    stw (r1)
    beq @batch_next
    nop

    from r1
    to r11
    add #10
    to r11
    ldw (r11)
    with r11
    add #8
    inc r1
    inc r1
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)
    inc r1
    inc r1
    inc r11
    inc r11
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)
    inc r1
    inc r1
    with r11
    add #6
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)
    inc r1
    inc r1
    inc r11
    inc r11
    to r3
    ldw (r11)
    ldw (r1)
    add r3
    stw (r1)
    iwt r15, #@b_scanline_loop
    nop

@batch_next:
    lm r0, (gsu_trap_batch_rem)
    dec r0
    sm (gsu_trap_batch_rem), r0
    beq @batch_done
    nop
    iwt r15, #@batch_loop
    nop

@batch_done:
    with r10
    sub #12
    return
batch_cbr_end:
    .assert (batch_cbr_end - batch_cbr_anchor) <= 512, error, .concat(.string(fn_name), " exceeds 512-byte GSU instruction cache")
endfunction
.endmacro

; ==============================================================================
; draw_flat_trap_batch
; 512B-cache-resident batched solid-color trapezoid rasterizer (Fix 3).
; Drains `count` queued `trap_batch_entry` records whose `tex_id` is in `$F0..$FF`
; (palette slot = `tex_id & $0F`), keeping all scanline state in registers with
; 1-cycle/pixel `plot; loop` spans and zero stack traffic.
;
; In:
;   r1 = batch_buf_ptr : Pointer to first `trap_batch_entry` in Bank $70
;   r2 = count         : Number of queued entries (>= 1)
;   r7 = frame_half    : Active frame half (0 = Pass 0, 1 = Pass 1)
; ==============================================================================
function draw_flat_trap_batch
    .align 16, $01
flat_batch_cbr_anchor:
    cache

    sm (gsu_trap_batch_cur), r1
    sm (gsu_trap_batch_rem), r2
.if ::GSU_TRAP_PASS1_MAX_X < 128
    iwt r0, #128
    moves r7, r7
    beq @fb_store_max_x
    nop
    ibt r0, #::GSU_TRAP_PASS1_MAX_X
@fb_store_max_x:
    sm (gsu_trap_max_x), r0
.endif
    ibt r0, #0
    cmode

@fb_loop:
    ; Load trap_ptr (+0), line_count (+2), anchor_x_eff (+4), anchor_y (+6), tex_id (+12)
    lm r3, (gsu_trap_batch_cur)
    to r1
    ldw (r3)                ; +0: trap_ptr
    inc r3
    inc r3
    to r8
    ldw (r3)                ; +2: line_count
    inc r3
    inc r3
    to r11
    ldw (r3)                ; +4: anchor_x_eff
    inc r3
    inc r3
    to r4
    ldw (r3)                ; +6: anchor_y
    with r3
    add #6                  ; skip u_offset (+8), v_offset (+10) -> +12: tex_id
    ldw (r3)
    and #$0F
    color                   ; Latch solid palette color (0..15)
    inc r3
    inc r3
    sm (gsu_trap_batch_cur), r3

    ; r4 = y = anchor_y + dy_start (+0)
    ldw (r1)
    with r4
    add r0

    from r8
    sub #1
    blt @fb_next_tramp
    nop
    from r4
    add r8
    sub #1
    blt @fb_next_tramp
    nop
    iwt r7, #GSU_TRAP_SCREEN_H
    from r4
    cmp r7
    bge @fb_next_tramp
    nop

    moves r4, r4
    bpl @fb_no_top_clip
    nop
    ibt r0, #0
    sub r4
    move r9, r0             ; r9 = skip = -y
    from r9
    cmp r8
    bge @fb_next_tramp
    nop
    with r8
    sub r9
    ibt r4, #0
    bra @fb_top_clip_done
    nop
@fb_next_tramp:
    iwt r15, #@fb_next
    nop
@fb_no_top_clip:
    ibt r9, #0
@fb_top_clip_done:
    from r4
    add r8
    from r7
    cmp r0
    bge @fb_bot_clip_done
    nop
    from r7
    to r8
    sub r4
@fb_bot_clip_done:
    move r2, r4             ; r2 = plot Y

    ; Load xL, xR, dxL_dy, dxR_dy into registers
    from r1
    to r3
    add #4                  ; trap_ptr + 4 (xL_start)
    ldw (r3)
    add r11
    move r7, r0             ; r7 = xL
    inc r3
    inc r3
    ldw (r3)
    add r11
    move r4, r0             ; r4 = xR (temp)
    inc r3
    inc r3
    to r5
    ldw (r3)                ; r5 = dxL_dy
    inc r3
    inc r3
    to r6
    ldw (r3)                ; r6 = dxR_dy

    moves r9, r9
    beq @fb_skip_done
    nop
    move r12, r4
    from r9
    lmult
    with r12
    add r4
    move r11, r6
    move r6, r5
    from r9
    lmult
    with r7
    add r4
    move r6, r11
    move r4, r12
@fb_skip_done:
    move r9, r8             ; r9 = lines_left
    move r8, r4             ; r8 = xR

@fb_scanline_loop:
    move r3, r7
    move r4, r8
    from r3
    and r4
    bmi @fb_advance
    nop

    moves r4, r4
    bpl :+
    nop
    iwt r4, #128
    bra @fb_xR_ok
    nop
:
    with r4
    hib
@fb_xR_ok:
.if ::GSU_TRAP_PASS1_MAX_X < 128
    lm r0, (gsu_trap_max_x)
    from r4
    cmp r0
    blt @fb_xR_clamped
    nop
    move r4, r0
@fb_xR_clamped:
.endif
    moves r3, r3
    bpl :+
    nop
    with r3
    hib
    with r3
    sex
    bra @fb_xL_ok
    nop
:
    with r3
    hib
@fb_xL_ok:
    moves r3, r3
    bpl :+
    nop
    ibt r3, #0
:
    from r4
    sub r3
    beq @fb_advance
    nop
    bmi @fb_advance
    nop

    move r12, r0
    move r1, r3
    iwt r13, #@fb_px_loop
@fb_px_loop:
    plot
    loop
    nop

@fb_advance:
    inc r2
    with r7
    add r5
    with r8
    add r6
    dec r9
    bne @fb_scanline_loop
    nop

@fb_next:
    lm r0, (gsu_trap_batch_rem)
    dec r0
    sm (gsu_trap_batch_rem), r0
    beq @fb_done
    nop
    iwt r15, #@fb_loop
    nop

@fb_done:
    return
flat_batch_cbr_end:
    .assert (flat_batch_cbr_end - flat_batch_cbr_anchor) <= 512, error, "draw_flat_trap_batch exceeds 512-byte GSU instruction cache"
endfunction

.endif ; __GSU_TRAP_RASTERIZER_MACRO__

.ifndef _GSU_SKIP_ROM_TRAP_INST
_GSU_SKIP_ROM_TRAP_INST .set 0
.endif

.if _GSU_SKIP_ROM_TRAP_INST = 0
.ifndef __GSU_ISO_DRAW_CACHED_TRAP__
__GSU_ISO_DRAW_CACHED_TRAP__ = 1
.segment "GSUCODE"

; ==============================================================================
; draw_cached_trap
; Rasterizes a pre-compiled scanline trapezoid sampling texels from ROM (`ROMBR`).
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
;   - Caller flushes dual 8-pixel plot caches via `rpix; rpix` at pass end
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
_gsu_define_trap_rasterizer draw_cached_trap, 0
_gsu_define_trap_batch_rasterizer draw_cached_trap_batch, 0

.endif ; __GSU_ISO_DRAW_CACHED_TRAP__
.endif ; _GSU_SKIP_ROM_TRAP_INST = 0
