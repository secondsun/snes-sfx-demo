; ==============================================================================
; side_menu.i - 64px Right-Panel Vertical RPG Menu Widget (cols 24..31, rows 0..19)
;
; Part of `snes_ui` (Epic #30 / Issue #36).
; Provides:
;   - Vertical list of up to 6 items (`SIDE_MENU_MAX_ITEMS = 6`)
;   - Per-item `enabled` bitmask (`side_menu_enabled`, bits 0..5): disabled items
;     render in `UI_PAL_DISABLED` and are skipped by Up/Down & rejected on A
;   - `focused` visual styling: `UI_PAL_ACTIVE` border + `UI_PAL_ALERT` selected
;     item + `UI_TILE_CURSOR` when focused; `UI_PAL_UNFOCUS` when unfocused
;   - Pure D-pad Up/Down + A/B handler (`side_menu_update`, `side_menu_update_joy1`)
;   - `side_menu_get_cursor_xy`: returns pixel (X, Y) for Priority 3 OAM cursor
;
; Define `SNES_UI_WRAM_CODE = 1` before `.include` to place runtime routines in
; `MAIN_LOOP` (WRAM) so they execute safely while SuperFX GSU owns the ROM bus.
; ==============================================================================

.ifndef __SNES_UI_SIDE_MENU__
__SNES_UI_SIDE_MENU__ = 1

.include "bg3_ui.i"

; ------------------------------------------------------------------------------
; Layout & Result Constants (overridable before .include)
; ------------------------------------------------------------------------------
.ifndef SIDE_MENU_X
SIDE_MENU_X             = 24            ; Left tile column (X = 192 px)
.endif
.ifndef SIDE_MENU_Y
SIDE_MENU_Y             = 0             ; Top tile row (Y = 0 px)
.endif
.ifndef SIDE_MENU_W
SIDE_MENU_W             = 8             ; 8 tiles = 64 px wide
.endif
.ifndef SIDE_MENU_H
SIDE_MENU_H             = 20            ; 20 tiles = 160 px tall
.endif

SIDE_MENU_MAX_ITEMS     = 6
SIDE_MENU_FIRST_ROW     = SIDE_MENU_Y + 3  ; Row 1 = title, Row 2 = divider, Rows 3,5,7,9,11,13 = items
SIDE_MENU_ROW_STEP      = 2

SIDE_MENU_NONE          = $FF           ; No A/B action this frame
SIDE_MENU_CANCEL        = $FE           ; B button pressed

; ------------------------------------------------------------------------------
; LORAM State
; ------------------------------------------------------------------------------
.segment "LORAM"
side_menu_count:        .res 1          ; Active item count (0..6)
side_menu_selected:     .res 1          ; Selected item index (0..count-1)
side_menu_enabled:      .res 1          ; Bitmask: bit i = 1 => item i enabled
side_menu_focused:      .res 1          ; 0 = unfocused (dim), non-zero = focused
side_menu_result:       .res 1          ; Last update result (0..5, $FE cancel, $FF none)
side_menu_dirty:        .res 1          ; Non-zero => side_menu_draw redraws box & items
side_menu_title_ptr:    .res 3          ; Optional 24-bit pointer to 6-char title (lo=hi=bank=0 => none)
side_menu_item_ptrs:    .res (SIDE_MENU_MAX_ITEMS * 3) ; 6 x 24-bit label pointers
_sm_tmp_idx:            .res 1
_sm_tmp_tries:          .res 1
_sm_tmp_row:            .res 1
_sm_tmp_mask:           .res 1
_sm_tmp_trig:           .res 2

.export side_menu_count, side_menu_selected, side_menu_enabled
.export side_menu_focused, side_menu_result, side_menu_dirty

; ------------------------------------------------------------------------------
; Convenience Macros
; ------------------------------------------------------------------------------
.macro SIDE_MENU_SET_TITLE str_sym
        RW_push set:a8i16
        ldx     #.loword(str_sym)
        stx     a:side_menu_title_ptr
        lda     #^str_sym
        sta     a:side_menu_title_ptr + 2
        lda     #$01
        sta     a:side_menu_dirty
        RW_pull
.endmac

.macro SIDE_MENU_SET_ITEM idx_imm, str_sym
        RW_push set:a8i16
        ldx     #.loword(str_sym)
        stx     z:ui_str_ptr
        lda     #^str_sym
        sta     z:ui_str_ptr + 2
        lda     #(idx_imm)
        jsr     side_menu_set_item
        RW_pull
.endmac

; ------------------------------------------------------------------------------
; Code Segment
; ------------------------------------------------------------------------------
.ifdef SNES_UI_WRAM_CODE
.segment "MAIN_LOOP"
.else
.segment "CODE"
.endif

; ------------------------------------------------------------------------------
; _sm_bit_for_idx (Internal)
; In:  A (8-bit) = index (0..5)
; Out: A (8-bit) = (1 << index)
; ------------------------------------------------------------------------------
_sm_bit_for_idx:
        RW_forced a16i16
        and     #$0007
        tax                             ; save zero-extended index in X
        RW a8
        lda     #$01
        cpx     #$0000
        beq     @done
@shift:
        asl
        dex
        bne     @shift
@done:
        rts

; ------------------------------------------------------------------------------
; side_menu_init
; Resets side menu to empty, all enabled ($3F), focused (1), dirty (1).
; ------------------------------------------------------------------------------
side_menu_init:
        php
        RW_forced a8i16
        stz     a:side_menu_count
        stz     a:side_menu_selected
        lda     #$3F
        sta     a:side_menu_enabled
        lda     #$01
        sta     a:side_menu_focused
        sta     a:side_menu_dirty
        lda     #SIDE_MENU_NONE
        sta     a:side_menu_result
        stz     a:side_menu_title_ptr
        stz     a:side_menu_title_ptr + 1
        stz     a:side_menu_title_ptr + 2
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_set_item
; In: A (8-bit) = item index (0..5), z:ui_str_ptr = 24-bit label string pointer.
; Automatically expands `side_menu_count` if `index + 1 > side_menu_count`.
; ------------------------------------------------------------------------------
side_menu_set_item:
        php
        RW_forced a8i16
        cmp     #SIDE_MENU_MAX_ITEMS
        bcs     @done
        sta     a:_sm_tmp_idx

        ; Compute offset = idx * 3
        asl                             ; idx * 2
        clc
        adc     a:_sm_tmp_idx           ; idx * 3
        RW a16
        and     #$00FF
        tax
        RW a8
        lda     z:ui_str_ptr
        sta     a:side_menu_item_ptrs, x
        lda     z:ui_str_ptr + 1
        sta     a:side_menu_item_ptrs + 1, x
        lda     z:ui_str_ptr + 2
        sta     a:side_menu_item_ptrs + 2, x

        ; Expand count if needed
        lda     a:_sm_tmp_idx
        inc
        cmp     a:side_menu_count
        bcc     @mark_dirty
        beq     @mark_dirty
        sta     a:side_menu_count
@mark_dirty:
        lda     #$01
        sta     a:side_menu_dirty
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_set_enabled
; In: A (8-bit) = enabled bitmask (bits 0..5).
; If currently selected item becomes disabled, advances to first enabled item.
; ------------------------------------------------------------------------------
side_menu_set_enabled:
        php
        RW_forced a8i16
        sta     a:side_menu_enabled
        lda     #$01
        sta     a:side_menu_dirty

        lda     a:side_menu_count
        beq     @done

        ; Check if current selection is enabled
        lda     a:side_menu_selected
        jsr     _sm_bit_for_idx
        and     a:side_menu_enabled
        bne     @done

        ; Find first enabled item (0..count-1)
        stz     a:_sm_tmp_idx
@find_loop:
        lda     a:_sm_tmp_idx
        cmp     a:side_menu_count
        bcs     @done
        jsr     _sm_bit_for_idx
        and     a:side_menu_enabled
        bne     @found
        inc     a:_sm_tmp_idx
        bra     @find_loop
@found:
        lda     a:_sm_tmp_idx
        sta     a:side_menu_selected
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_set_focused
; In: A (8-bit) = 0 (unfocused) or non-zero (focused).
; ------------------------------------------------------------------------------
side_menu_set_focused:
        php
        RW_forced a8i16
        cmp     a:side_menu_focused
        beq     @done
        sta     a:side_menu_focused
        lda     #$01
        sta     a:side_menu_dirty
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_update_joy1
; Convenience wrapper: reads `z:SFX_joy1trig` and calls `side_menu_update`.
; Out: A (8-bit) = `side_menu_result` (0..5, SIDE_MENU_CANCEL, or SIDE_MENU_NONE).
; ------------------------------------------------------------------------------
side_menu_update_joy1:
        php
        RW_forced a16i16
        lda     z:SFX_joy1trig
        jsr     side_menu_update
        RW a8
        lda     a:side_menu_result
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_update
; In:  A (16-bit) = rising-edge joypad trigger mask (libSFX JOY_* bit layout).
; Out: a:side_menu_result (and 8-bit A):
;        0..5             = confirmed item index (JOY_A on enabled item)
;        SIDE_MENU_CANCEL = cancelled (JOY_B)
;        SIDE_MENU_NONE   = no confirmation/cancel this frame
; ------------------------------------------------------------------------------
side_menu_update:
        php
        RW_forced a16i16
        sta     a:_sm_tmp_trig
        RW a8

        lda     #SIDE_MENU_NONE
        sta     a:side_menu_result

        lda     a:side_menu_focused
        bne     :+
        brl     @done
:       lda     a:side_menu_count
        bne     :+
        brl     @done
:

        ; Check JOY_UP ($0800 -> high byte bit 3)
        lda     a:_sm_tmp_trig + 1
        bit     #>JOY_UP
        beq     @check_down

        lda     a:side_menu_count
        sta     a:_sm_tmp_tries
        lda     a:side_menu_selected
        sta     a:_sm_tmp_idx
@up_step:
        lda     a:_sm_tmp_idx
        bne     @up_dec
        lda     a:side_menu_count
@up_dec:
        dec
        sta     a:_sm_tmp_idx
        jsr     _sm_bit_for_idx
        and     a:side_menu_enabled
        bne     @up_commit
        dec     a:_sm_tmp_tries
        bne     @up_step
        bra     @check_ab
@up_commit:
        lda     a:_sm_tmp_idx
        sta     a:side_menu_selected
        lda     #$01
        sta     a:side_menu_dirty
        bra     @check_ab

@check_down:
        lda     a:_sm_tmp_trig + 1
        bit     #>JOY_DOWN
        beq     @check_ab

        lda     a:side_menu_count
        sta     a:_sm_tmp_tries
        lda     a:side_menu_selected
        sta     a:_sm_tmp_idx
@down_step:
        lda     a:_sm_tmp_idx
        inc
        cmp     a:side_menu_count
        bcc     @down_store
        lda     #$00
@down_store:
        sta     a:_sm_tmp_idx
        jsr     _sm_bit_for_idx
        and     a:side_menu_enabled
        bne     @down_commit
        dec     a:_sm_tmp_tries
        bne     @down_step
        bra     @check_ab
@down_commit:
        lda     a:_sm_tmp_idx
        sta     a:side_menu_selected
        lda     #$01
        sta     a:side_menu_dirty

@check_ab:
        ; Check JOY_B ($8000 -> high byte bit 7)
        lda     a:_sm_tmp_trig + 1
        bit     #>JOY_B
        beq     @check_a
        lda     #SIDE_MENU_CANCEL
        sta     a:side_menu_result
        bra     @done

@check_a:
        ; Check JOY_A ($0080 -> low byte bit 7)
        lda     a:_sm_tmp_trig
        bit     #<JOY_A
        beq     @done
        ; Only confirm if selected item is enabled
        lda     a:side_menu_selected
        jsr     _sm_bit_for_idx
        and     a:side_menu_enabled
        beq     @done
        lda     a:side_menu_selected
        sta     a:side_menu_result

@done:
        lda     a:side_menu_result
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_draw
; Redraws the 8x20 right-hand menu box into `bg3_tilemap_buf` if `side_menu_dirty`
; is non-zero, then clears `side_menu_dirty`.
; ------------------------------------------------------------------------------
side_menu_draw:
        php
        RW_forced a8i16
        lda     a:side_menu_dirty
        bne     :+
        brl     @done
:       stz     a:side_menu_dirty

        ; Choose border palette based on focused state
        lda     a:side_menu_focused
        bne     @pal_focused
        lda     #UI_PAL_UNFOCUS
        bra     @draw_frame
@pal_focused:
        lda     #UI_PAL_ACTIVE
@draw_frame:
        sta     a:ui_arg_pal
        lda     #SIDE_MENU_X
        sta     a:ui_arg_x
        lda     #SIDE_MENU_Y
        sta     a:ui_arg_y
        lda     #SIDE_MENU_W
        sta     a:ui_arg_w
        lda     #SIDE_MENU_H
        sta     a:ui_arg_h
        jsr     ui_draw_box

        ; Optional title at (SIDE_MENU_X + 1, SIDE_MENU_Y + 1)
        lda     a:side_menu_title_ptr
        ora     a:side_menu_title_ptr + 1
        ora     a:side_menu_title_ptr + 2
        beq     @draw_items

        lda     a:side_menu_title_ptr
        sta     z:ui_str_ptr
        lda     a:side_menu_title_ptr + 1
        sta     z:ui_str_ptr + 1
        lda     a:side_menu_title_ptr + 2
        sta     z:ui_str_ptr + 2
        lda     #(SIDE_MENU_X + 1)
        sta     a:ui_arg_x
        lda     #(SIDE_MENU_Y + 1)
        sta     a:ui_arg_y
        jsr     ui_print_str

        ; Horizontal divider across cols (SIDE_MENU_X + 1 .. SIDE_MENU_X + 6) at row + 2
        lda     #(SIDE_MENU_Y + 2)
        sta     a:ui_arg_y
        lda     #UI_TILE_HLINE
        sta     a:ui_arg_val
        lda     #(SIDE_MENU_X + 1)
        sta     a:ui_arg_x
@div_loop:
        jsr     ui_put_tile
        inc     a:ui_arg_x
        lda     a:ui_arg_x
        cmp     #(SIDE_MENU_X + SIDE_MENU_W - 1)
        bcc     @div_loop

@draw_items:
        lda     a:side_menu_count
        bne     :+
        brl     @done
:       stz     a:_sm_tmp_idx
        lda     #SIDE_MENU_FIRST_ROW
        sta     a:_sm_tmp_row
        lda     #$01
        sta     a:_sm_tmp_mask

@item_loop:
        lda     a:_sm_tmp_idx
        cmp     a:side_menu_count
        bcs     @done

        ; Determine item palette:
        ;   disabled -> UI_PAL_DISABLED
        ;   unfocused -> UI_PAL_UNFOCUS
        ;   focused & selected -> UI_PAL_ALERT
        ;   focused & unselected -> UI_PAL_ACTIVE
        lda     a:side_menu_enabled
        and     a:_sm_tmp_mask
        bne     @item_enabled
        lda     #UI_PAL_DISABLED
        bra     @print_item
@item_enabled:
        lda     a:side_menu_focused
        beq     @item_unfocused
        lda     a:_sm_tmp_idx
        cmp     a:side_menu_selected
        bne     @item_active

        ; Draw BG3 cursor arrow on left border at (SIDE_MENU_X, _sm_tmp_row)
        lda     #SIDE_MENU_X
        sta     a:ui_arg_x
        lda     a:_sm_tmp_row
        sta     a:ui_arg_y
        lda     #UI_TILE_CURSOR
        sta     a:ui_arg_val
        lda     #UI_PAL_ALERT
        sta     a:ui_arg_pal
        jsr     ui_put_tile
        lda     #UI_PAL_ALERT
        bra     @print_item

@item_active:
        lda     #UI_PAL_ACTIVE
        bra     @print_item
@item_unfocused:
        lda     #UI_PAL_UNFOCUS

@print_item:
        sta     a:ui_arg_pal
        lda     #(SIDE_MENU_X + 1)
        sta     a:ui_arg_x
        lda     a:_sm_tmp_row
        sta     a:ui_arg_y

        ; Load 24-bit pointer side_menu_item_ptrs[idx * 3]
        lda     a:_sm_tmp_idx
        asl
        clc
        adc     a:_sm_tmp_idx
        RW a16
        and     #$00FF
        tax
        RW a8
        lda     a:side_menu_item_ptrs, x
        sta     z:ui_str_ptr
        lda     a:side_menu_item_ptrs + 1, x
        sta     z:ui_str_ptr + 1
        lda     a:side_menu_item_ptrs + 2, x
        sta     z:ui_str_ptr + 2
        jsr     ui_print_str

        ; Advance to next item
        lda     a:_sm_tmp_row
        clc
        adc     #SIDE_MENU_ROW_STEP
        sta     a:_sm_tmp_row
        asl     a:_sm_tmp_mask
        inc     a:_sm_tmp_idx
        brl     @item_loop

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; side_menu_get_cursor_xy
; Computes screen pixel coordinates for a Priority 3 OAM cursor pointing at the
; currently selected item.
; Out: X (16-bit) = pixel X (SIDE_MENU_X * 8), Y (16-bit) = pixel Y.
; ------------------------------------------------------------------------------
side_menu_get_cursor_xy:
        php
        RW_forced a8i16
        lda     a:side_menu_selected
        asl                             ; * SIDE_MENU_ROW_STEP (2)
        clc
        adc     #SIDE_MENU_FIRST_ROW
        RW a16
        and     #$00FF
        asl
        asl
        asl                             ; * 8 pixels/tile
        tay
        ldx     #(SIDE_MENU_X * 8)
        plp
        rts

.endif ; __SNES_UI_SIDE_MENU__
