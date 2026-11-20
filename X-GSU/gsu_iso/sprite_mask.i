; ==============================================================================
; sprite_mask.i - SuperFX 1-Bit Sprite Mask Cutout Puncher & Entity O(1) LUT
;
; Implements ADR 0005 (`0005-bg1-sprite-mask-cutouts-for-under-bg1-oam.md`) and
; GitHub Issue #34 for `gsu_iso`:
;   - Builds a 256-byte O(1) `cell_entity_lut` in Bank $70 GSURAM on Pass 0
;     (initialized to `GSU_ENTITY_NONE` = $FF) so `@step_4_unit_hook` skips
;     empty cells with a single byte load.
;   - Computes each entity's projected screen top-left `(sx, sy)` anchored to
;     the cell's projected floor center at `base_height`:
;       floor_cx = anchor_x + ((Sx.x + Sz.x) >> 1)
;       floor_cy = anchor_y + ((Sx.y + Sz.y) >> 1)
;       sx       = floor_cx - (mask_w >> 1) + sub_x_offset
;       sy       = floor_cy - mask_h + anchor_y_offset + sub_y_offset
;   - Writes `(sx, sy, visible)` into `desc->entity_out[slot]` so the 65816
;     latches hardware OAM on the exact `BG12NBA` flip VBlank.
;   - Punches MSB-first 1-bit Sprite Masks (bit 7 = leftmost pixel; `1` = punch
;     `color 0` with `CMODE = $01`, `0` = skip; bit 0 of `flags` = HFLIP) from
;     `mask_bank:mask_addr` via `ROMB` + `R14`/`GETB`, strictly clipped to the
;     active Frame Half (`[0..127]` on Pass 0, `[128..GSU_ISO_VIEWPORT_W-1]` on
;     Pass 1) and `Y in [0..GSU_ISO_SCREEN_H-1]`.
; ==============================================================================

.ifndef __GSU_ISO_SPRITE_MASK_DEFINED__
__GSU_ISO_SPRITE_MASK_DEFINED__ = 1

.include "scene_descriptor.i"

.ifndef GSU_ISO_VIEWPORT_W
    GSU_ISO_VIEWPORT_W = 256
.endif
.ifndef GSU_ISO_SCREEN_H
    GSU_ISO_SCREEN_H = 160
.endif

; ==============================================================================
; GSURAM State (Bank $70, word-aligned)
; ==============================================================================
.segment "GSURAM"
.align 2
cell_entity_lut:        .res 256    ; Indexed by j * cols + i -> entity slot (0..7) or $FF
.export cell_entity_lut
gsu_entity_lut_active:  .res 2      ; Non-zero when >= 1 entity is active in descriptor
.export gsu_entity_lut_active
gsu_sm_mask_w:          .res 2      ; Scratch: active mask width (pixels)
gsu_sm_mask_h:          .res 2      ; Scratch: active mask height (pixels)
gsu_sm_sx:              .res 2      ; Scratch: computed top-left screen X
gsu_sm_sy:              .res 2      ; Scratch: computed top-left screen Y
gsu_sm_slot_ptr:        .res 2      ; Scratch: &desc->entities[slot]
gsu_sm_slot_idx:        .res 2      ; Scratch: entity slot index (0..7)

.segment "GSUCODE"

; ==============================================================================
; gsu_sprite_mask_build_lut
; Initializes `cell_entity_lut[0..255]` to $FF (`GSU_ENTITY_NONE`), clears
; `desc->entity_out[0..7].visible` to 0, and populates `cell_entity_lut` from
; `desc->entities[0..entity_count-1]`. Called on Pass 0.
;
; In:
;   desc_ptr = r1: Pointer to `gsu_scene_descriptor` in Bank $70 GSURAM
;   cols     = r2: Map Grid column count (4..16)
; Postconditions:
;   - `RAMBR == 0` ($70)
;   - `cell_entity_lut` populated for O(1) lookup in `@step_4_unit_hook`
;   - `gsu_entity_lut_active` set to clamped `entity_count` (0..8)
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r12, r13
; ==============================================================================
function gsu_sprite_mask_build_lut desc_ptr, cols
    register desc_ptr = r1, cols = r2

    ; 1. Fill cell_entity_lut[0..255] with $FF (128 words of $FFFF)
    iwt r7, #cell_entity_lut
    iwt r0, #$FFFF
    iwt r12, #128
    iwt r13, #@lut_clear_loop
@lut_clear_loop:
    stw (r7)
    inc r7
    loop
    inc r7

    ; 2. Clear desc->entity_out[0..7].visible (+4 in each 8-byte output slot)
    iwt r0, #(gsu_scene_descriptor::entity_out + gsu_entity_screen_pos::visible)
    from desc_ptr
    to r7
    add r0
    ibt r0, #0
    ibt r12, #GSU_SCENE_MAX_ENTITIES
    iwt r13, #@out_clear_loop
@out_clear_loop:
    stw (r7)
    with r7
    add #GSU_ENTITY_POS_BYTES
    loop
    nop

    ; 3. Read entity_count = desc->entity_count (+10), clamp to 0..8
    from desc_ptr
    to r7
    add #gsu_scene_descriptor::entity_count
    to r3
    ldw (r7)                    ; r3 = entity_count

    ; If entity_count <= 0 -> mark inactive and return
    from r3
    sub #1
    blt @lut_no_entities
    nop

    ; Clamp to GSU_SCENE_MAX_ENTITIES (8)
    ibt r0, #GSU_SCENE_MAX_ENTITIES
    from r3
    cmp r0
    blt @lut_count_ok
    nop
    ibt r3, #GSU_SCENE_MAX_ENTITIES
@lut_count_ok:
    sm (gsu_entity_lut_active), r3

    ; 4. Populate cell_entity_lut[cell_j * cols + cell_i] = slot
    iwt r0, #gsu_scene_descriptor::entities
    from desc_ptr
    to r4
    add r0                      ; r4 = &desc->entities[0]
    ibt r5, #0                  ; r5 = slot index (0..entity_count-1)
    iwt r8, #cell_entity_lut    ; r8 = base address of cell_entity_lut
    iwt r9, #256                ; r9 = LUT bounds limit

@lut_entity_loop:
    ; Check active (+0)
    ldb (r4)
    lob
    moves r0, r0
    beq @lut_next_entity
    nop

    ; Read cell_i (+1) into r6, cell_j (+2) into r7
    from r4
    to r7
    add #1
    to r6
    ldb (r7)
    with r6
    lob                         ; r6 = cell_i (0..255)
    inc r7
    ldb (r7)
    lob                         ; r0 = cell_j (0..255)

    ; cell_idx = cell_j * cols + cell_i (r2 = cols in R1..R15)
    umult cols                  ; r0 = cell_j * cols
    add r6                      ; r0 = cell_idx

    ; Bounds check: 0 <= cell_idx < 256 (unsigned compare)
    cmp r9
    bcs @lut_next_entity
    nop

    ; cell_entity_lut[cell_idx] = slot (r5)
    from r8
    to r7
    add r0
    from r5
    stb (r7)

@lut_next_entity:
    iwt r0, #GSU_ENTITY_SLOT_BYTES
    with r4
    add r0
    inc r5
    from r5
    cmp r3
    blt @lut_entity_loop
    nop
    return

@lut_no_entities:
    ibt r0, #0
    sm (gsu_entity_lut_active), r0
    return
endfunction

; ==============================================================================
; gsu_punch_sprite_mask
; Streams an MSB-first 1-bit Sprite Mask from `slot->mask_bank:mask_addr` via
; `ROMB` + `R14`/`GETB` and punches `color 0` (`CMODE = $01`) into the BG1
; framebuffer for every `1` bit, leaving `0` bits untouched.
;
; Clipping:
;   - Pass 0 (`frame_half == 0`): X in [0..127] (framebuffer X = x)
;   - Pass 1 (`frame_half != 0`): X in [128..GSU_ISO_VIEWPORT_W-1] (fb X = x - 128)
;   - Vertical: Y in [0..GSU_ISO_SCREEN_H-1]
;   - Supports `GSU_ENTITY_FLAG_HFLIP` (bit 0 of `slot->flags`)
;
; In:
;   slot_ptr   = r1: Pointer to `gsu_entity_mask_slot` in Bank $70 GSURAM
;   sx_in      = r2: Projected top-left screen X (signed 16-bit)
;   sy_in      = r3: Projected top-left screen Y (signed 16-bit)
;   frame_half = r4: Active frame half (0 = Pass 0, non-zero = Pass 1)
; Postconditions:
;   - `CMODE == 0` (transparency enabled) on all return paths
;   - `ROMBR == $04` on all return paths
;   - `RAMBR == 0` ($70)
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_punch_sprite_mask slot_ptr, sx_in, sy_in, frame_half
    register slot_ptr = r1, sx_in = r2, sy_in = r3, frame_half = r4

    ; 1. Read mask_w (+12) and mask_h (+13), applying defaults (16, 24) if 0
    from slot_ptr
    to r7
    add #gsu_entity_mask_slot::mask_w
    ldb (r7)
    lob
    moves r0, r0
    bne @sm_w_ok
    nop
    iwt r0, #16
@sm_w_ok:
    move r5, r0                 ; r5 = mask_w
    sm (gsu_sm_mask_w), r5

    inc r7
    ldb (r7)
    lob
    moves r0, r0
    bne @sm_h_ok
    nop
    iwt r0, #24
@sm_h_ok:
    move r9, r0                 ; r9 = mask_h
    sm (gsu_sm_mask_h), r9

    ; 2. Compute Frame-Half local X (`local_sx` in r6) and `max_local_x` in r8
    moves frame_half, frame_half
    bne @sm_pass1_bounds
    nop
    move r6, sx_in              ; Pass 0: local_sx = sx
    iwt r8, #128                ; Pass 0: max_local_x = 128
    bra @sm_horiz_check
    nop
@sm_pass1_bounds:
    iwt r0, #128
    from sx_in
    to r6
    sub r0                      ; Pass 1: local_sx = sx - 128
    iwt r8, #(GSU_ISO_VIEWPORT_W - 128)
@sm_horiz_check:
    ; Cull if local_sx >= max_local_x
    from r6
    cmp r8
    bge @sm_early_exit
    nop
    ; Cull if local_sx + mask_w <= 0
    from r6
    add r5
    sub #1
    blt @sm_early_exit
    nop

    ; 3. Vertical bounds & clipping against [0 .. GSU_ISO_SCREEN_H - 1]
    ; Cull if sy >= GSU_ISO_SCREEN_H
    iwt r0, #GSU_ISO_SCREEN_H
    from sy_in
    cmp r0
    bge @sm_early_exit
    nop
    ; Cull if sy + mask_h <= 0
    from sy_in
    add r9
    sub #1
    blt @sm_early_exit
    nop

    ; Read mask_addr (+4) into r14_pending (keep in r11 until ROMB is set)
    from slot_ptr
    to r7
    add #gsu_entity_mask_slot::mask_addr
    to r11
    ldw (r7)                    ; r11 = mask_addr

    ; Top clipping: if sy < 0, skip = -sy, mask_addr += skip * row_bytes
    moves sy_in, sy_in
    bpl @sm_no_top_clip
    nop
    ibt r0, #0
    sub sy_in                   ; r0 = skip_rows = -sy
    move r4, r0                 ; r4 = skip_rows

    ; rows_left = mask_h - skip_rows
    with r9
    sub r4
    from r9
    sub #1
    blt @sm_early_exit
    nop

    ; row_bytes = (mask_w + 7) >> 3
    from r5
    add #7
    lsr
    lsr
    lsr                         ; r0 = row_bytes
    umult r4                    ; r0 = skip_rows * row_bytes (r4 in R1..R15)
    with r11
    add r0                      ; mask_addr += skip_rows * row_bytes
    ibt sy_in, #0               ; cur_y = 0
@sm_no_top_clip:
    ; Bottom clipping: if cur_y + rows_left > GSU_ISO_SCREEN_H, clamp rows_left
    iwt r0, #GSU_ISO_SCREEN_H
    from sy_in
    add r9                      ; r0 = cur_y + rows_left
    iwt r4, #GSU_ISO_SCREEN_H
    cmp r4                      ; compare (cur_y + rows_left) with SCREEN_H
    blt @sm_bottom_ok
    nop
    from r4
    to r9
    sub sy_in                   ; rows_left = SCREEN_H - cur_y
@sm_bottom_ok:
    from r9
    sub #1
    bge @sm_bounds_ok
    nop
@sm_early_exit:
    return

@sm_bounds_ok:

    ; 4. Configure HFLIP: r11_start = start_local_px, r7 = step_x (+1 or -1)
    ; Save mask_addr (r11) on stack briefly while computing start_local_px
    gsu_stack_push r11          ; [SP] = mask_addr

    from slot_ptr
    to r7
    add #gsu_entity_mask_slot::flags
    ldb (r7)
    and #GSU_ENTITY_FLAG_HFLIP
    bne @sm_hflip_on
    nop
    ; Normal (left-to-right): start_local_px = local_sx, step_x = +1
    move r11, r6
    ibt r7, #1
    bra @sm_hflip_done
    nop
@sm_hflip_on:
    ; Mirrored (right-to-left): start_local_px = local_sx + mask_w - 1, step_x = -1
    from r6
    to r11
    add r5
    dec r11
    ibt r7, #<(-1)              ; $FF -> sign-extended to -1 ($FFFF)
@sm_hflip_done:

    ; 5. Configure ROMB (slot->mask_bank), CMODE ($01 = plot color 0), COLOR (#0)
    from slot_ptr
    to r4
    add #gsu_entity_mask_slot::mask_bank
    ldb (r4)
    lob
    romb                        ; ROMBR = mask_bank

    ; Pop mask_addr into r14 (triggers ROM prefetch of first mask byte)
    gsu_stack_pop r14

    ; Set PLOT Y register (r2 = cur_y)
    move r2, sy_in

    ; Enable color-0 plotting (CMODE bit 0 = 1) and set COLR = 0
    ibt r0, #$01
    cmode
    ibt r0, #0
    color

    ; 6. Row & byte streaming loop
    ; Registers live across rows:
    ;   r2  = cur_y (PLOT Y)
    ;   r7  = step_x (+1 or -1)
    ;   r8  = max_local_x (128 or GSU_ISO_VIEWPORT_W - 128)
    ;   r9  = rows_left
    ;   r11 = start_local_px
    ;   r14 = ROM mask byte pointer
@sm_row_loop:
    move r6, r11                ; r6 = local_px = start_local_px
    lm r3, (gsu_sm_mask_w)      ; r3 = bits_rem in current row

@sm_byte_loop:
    getb                        ; r0 = next mask byte (0..255), MSB = leftmost bit
    inc r14                     ; prefetch next byte in background

    ; bits_in_byte = min(8, bits_rem) -> r12; bits_rem -= bits_in_byte
    ibt r4, #8
    from r3
    cmp r4
    blt @sm_tail_bits
    nop
    move r12, r4                ; r12 = 8
    with r3
    sub r4                      ; r3 -= 8
    bra @sm_check_zero_byte
    nop
@sm_tail_bits:
    move r12, r3                ; r12 = bits_rem (1..7)
    ibt r3, #0
@sm_check_zero_byte:
    ; Fast skip when all 8 mask bits are 0
    moves r0, r0
    bne @sm_punch_bits
    nop
    moves r7, r7
    bmi @sm_skip_neg
    nop
    with r6
    add r12
    bra @sm_byte_done
    nop
@sm_skip_neg:
    with r6
    sub r12
    bra @sm_byte_done
    nop

@sm_punch_bits:
    ; Move mask byte into bits 15..8 so `with r5; add r5` shifts MSB into CY
    swap
    move r5, r0
    iwt r13, #@sm_bit_loop
@sm_bit_loop:
    with r5
    add r5                      ; CY = MSB mask bit
    bcc @sm_bit_skip
    nop
    ; Unsigned check: 0 <= local_px < max_local_x
    from r6
    cmp r8
    bcs @sm_bit_skip
    nop
    move r1, r6                 ; PLOT X = local_px
    plot                        ; Punch color 0 into BG1 framebuffer!
@sm_bit_skip:
    with r6
    add r7                      ; local_px += step_x
    loop
    nop

@sm_byte_done:
    moves r3, r3
    bne @sm_byte_loop
    nop

    inc r2                      ; cur_y++
    dec r9                      ; rows_left--
    bne @sm_row_loop
    nop

    ; 7. Restore CMODE = 0 (transparency) and ROMBR = $04 before returning
    ibt r0, #0
    cmode
    ibt r0, #4
    romb
    return
endfunction

; ==============================================================================
; gsu_sprite_mask_stamp_cell
; Invoked at `@step_4_unit_hook` in `gsu_iso_map.i` ONLY when `cell_entity_lut`
; indicates an active entity occupies the current cell.
;   1. Computes projected `(sx, sy)` from `gsu_iso_render_frame::anchor_x/y`,
;      `basis_ptr` (`Sx`, `Sz`), and the entity's offsets/dimensions.
;   2. Writes `(sx, sy, visible)` into `desc->entity_out[slot]`.
;   3. Calls `gsu_punch_sprite_mask` to punch the 1-bit cutout into the active
;      Frame Half.
;
; In:
;   desc_ptr = r1: Active `gsu_scene_descriptor` pointer in Bank $70 GSURAM
;   slot_idx = r2: Entity slot index (0..7) from `cell_entity_lut[cell_idx]`
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_sprite_mask_stamp_cell desc_ptr, slot_idx
    register desc_ptr = r1, slot_idx = r2

    sm (gsu_sm_slot_idx), slot_idx

    ; slot_ptr = desc_ptr + entities (+16) + (slot_idx << 4)
    move r3, slot_idx
    with r3
    add r3
    with r3
    add r3
    with r3
    add r3
    with r3
    add r3                      ; r3 = slot_idx * 16
    iwt r0, #gsu_scene_descriptor::entities
    add desc_ptr
    add r3
    move r4, r0                 ; r4 = slot_ptr
    sm (gsu_sm_slot_ptr), r4

    ; Compute cell floor center:
    ;   floor_cx = anchor_x + ((Sx.x + Sz.x) >> 1)
    ;   floor_cy = anchor_y + ((Sx.y + Sz.y) >> 1)
    iwt r7, #gsu_iso_render_frame + map_render_frame::basis_ptr
    ldw (r7)
    move r7, r0                 ; r7 = basis_ptr
    to r5
    ldw (r7)                    ; r5 = Sx.x (+0)
    inc r7
    inc r7
    to r6
    ldw (r7)                    ; r6 = Sx.y (+2)
    inc r7
    inc r7
    ldw (r7)                    ; r0 = Sz.x (+4)
    with r5
    add r0
    with r5
    asr                         ; r5 = (Sx.x + Sz.x) >> 1
    inc r7
    inc r7
    ldw (r7)                    ; r0 = Sz.y (+6)
    with r6
    add r0
    with r6
    asr                         ; r6 = (Sx.y + Sz.y) >> 1

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    ldw (r7)
    with r5
    add r0                      ; r5 = floor_cx
    inc r7
    inc r7
    ldw (r7)
    with r6
    add r0                      ; r6 = floor_cy

    ; Read mask_w (+12) and mask_h (+13) with defaults 16 and 24
    from r4
    to r7
    add #gsu_entity_mask_slot::mask_w
    ldb (r7)
    lob
    moves r0, r0
    bne @sc_w_ok
    nop
    iwt r0, #16
@sc_w_ok:
    move r8, r0                 ; r8 = mask_w

    inc r7
    ldb (r7)
    lob
    moves r0, r0
    bne @sc_h_ok
    nop
    iwt r0, #24
@sc_h_ok:
    move r9, r0                 ; r9 = mask_h

    ; sx = floor_cx - (mask_w >> 1) + sub_x_offset (+6)
    from r8
    lsr                         ; r0 = mask_w >> 1
    with r5
    sub r0                      ; r5 = floor_cx - (mask_w >> 1)
    from r4
    to r7
    add #gsu_entity_mask_slot::sub_x_offset
    ldw (r7)
    with r5
    add r0                      ; r5 = sx

    ; sy = floor_cy - mask_h + sub_y_offset (+8) + anchor_y_offset (+10)
    with r6
    sub r9                      ; r6 = floor_cy - mask_h
    inc r7
    inc r7                      ; r7 = &sub_y_offset (+8)
    ldw (r7)
    with r6
    add r0
    inc r7
    inc r7                      ; r7 = &anchor_y_offset (+10)
    ldw (r7)
    with r6
    add r0                      ; r6 = sy

    sm (gsu_sm_sx), r5
    sm (gsu_sm_sy), r6

    ; Determine viewport visibility:
    ;   visible = (sx + mask_w > 0) && (sx < GSU_ISO_VIEWPORT_W)
    ;          && (sy + mask_h > 0) && (sy < GSU_ISO_SCREEN_H)
    ibt r11, #0                 ; default visible = 0
    from r5
    add r8
    sub #1
    blt @sc_write_out
    nop
    iwt r0, #GSU_ISO_VIEWPORT_W
    from r5
    cmp r0
    bge @sc_write_out
    nop
    from r6
    add r9
    sub #1
    blt @sc_write_out
    nop
    iwt r0, #GSU_ISO_SCREEN_H
    from r6
    cmp r0
    bge @sc_write_out
    nop
    ibt r11, #1                 ; visible = 1

@sc_write_out:
    ; out_ptr = desc_ptr + entity_out (+144) + (slot_idx << 3)
    lm r3, (gsu_sm_slot_idx)
    with r3
    add r3
    with r3
    add r3
    with r3
    add r3                      ; r3 = slot_idx * 8
    iwt r0, #gsu_scene_descriptor::entity_out
    add desc_ptr
    add r3
    move r7, r0                 ; r7 = &desc->entity_out[slot_idx]

    from r5
    stw (r7)                    ; +0: sx
    inc r7
    inc r7
    from r6
    stw (r7)                    ; +2: sy
    inc r7
    inc r7
    from r11
    stw (r7)                    ; +4: visible

    ; Skip punching if entity is completely outside viewport
    moves r11, r11
    beq @sc_done
    nop

    ; Punch 1-bit Sprite Mask clipped to active Frame Half
    lm r1, (gsu_sm_slot_ptr)
    lm r2, (gsu_sm_sx)
    lm r3, (gsu_sm_sy)
    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    to r4
    ldw (r7)
    call gsu_punch_sprite_mask r1, r2, r3, r4

@sc_done:
    return
endfunction

.endif ; __GSU_ISO_SPRITE_MASK_DEFINED__
