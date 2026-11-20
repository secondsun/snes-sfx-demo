; ==============================================================================
; status_bar.i - 64px Bottom Status & 2-Line Message Log Bar (rows 20..27)
;
; Part of `snes_ui` (Epic #30 / Issue #36).
; Layout (32x8 tiles, cols 0..31, rows 20..27, screen Y = 160..223 px):
;   Row 20 : Top 9-slice window border
;   Row 21 : [Mode/Turn Header] | [Heart]HP xx/xx | [Boots]MP x/x
;   Row 22 : Horizontal interior divider
;   Row 23 : Message Log Line 0 (previous message, up to 30 chars)
;   Row 25 : Message Log Line 1 (latest message, up to 30 chars)
;   Row 27 : Bottom 9-slice window border
;
; Public API:
;   - `status_bar_init`       : Defaults HP 20/20, MP 4/4, empty header/log
;   - `status_bar_set_stats`  : Updates HP/MP fields and marks dirty
;   - `status_bar_set_header` : Sets 24-bit mode/turn header string & palette
;   - `ui_set_message`        : Scrolls log (line 1 -> line 0) and sets line 1
;   - `ui_set_messages`       : Sets both log lines explicitly
;   - `status_bar_draw`       : Redraws into `bg3_tilemap_buf` when dirty
;   - Convenience macros: STATUS_SET_HEADER, UI_SET_MESSAGE
; ==============================================================================

.ifndef __SNES_UI_STATUS_BAR__
__SNES_UI_STATUS_BAR__ = 1

.include "bg3_ui.i"

; ------------------------------------------------------------------------------
; Layout Constants (overridable before .include)
; ------------------------------------------------------------------------------
.ifndef STATUS_BAR_X
STATUS_BAR_X            = 0
.endif
.ifndef STATUS_BAR_Y
STATUS_BAR_Y            = 20            ; Y = 160 px (directly beneath 192x160 BG1)
.endif
.ifndef STATUS_BAR_W
STATUS_BAR_W            = 32            ; Full 256 px width
.endif
.ifndef STATUS_BAR_H
STATUS_BAR_H            = 8             ; 64 px tall (rows 20..27)
.endif

STATUS_ROW_HEADER       = STATUS_BAR_Y + 1
STATUS_ROW_DIVIDER      = STATUS_BAR_Y + 2
STATUS_ROW_MSG0         = STATUS_BAR_Y + 3
STATUS_ROW_MSG1         = STATUS_BAR_Y + 5

STATUS_HP_LOW_THRESH    = 5             ; Highlight HP in UI_PAL_ALERT when <= 5

; ------------------------------------------------------------------------------
; LORAM State
; ------------------------------------------------------------------------------
.segment "LORAM"
status_hp_cur:          .res 1
status_hp_max:          .res 1
status_mp_cur:          .res 1
status_mp_max:          .res 1
status_header_ptr:      .res 3          ; 24-bit pointer to Mode/Turn header string
status_header_pal:      .res 1          ; Palette for Mode/Turn header
status_msg0_ptr:        .res 3          ; 24-bit pointer to Message Log Line 0
status_msg1_ptr:        .res 3          ; 24-bit pointer to Message Log Line 1
status_bar_dirty:       .res 1          ; Non-zero => status_bar_draw redraws
_sb_hp_pal:             .res 1

.export status_hp_cur, status_hp_max, status_mp_cur, status_mp_max
.export status_header_pal, status_bar_dirty

; ------------------------------------------------------------------------------
; Convenience Macros
; ------------------------------------------------------------------------------
.macro STATUS_SET_HEADER str_sym, pal_idx
        RW_push set:a8i16
        ldx     #.loword(str_sym)
        stx     z:ui_str_ptr
        lda     #^str_sym
        sta     z:ui_str_ptr + 2
        lda     #(pal_idx)
        jsr     status_bar_set_header
        RW_pull
.endmac

.macro UI_SET_MESSAGE str_sym
        RW_push set:a8i16
        ldx     #.loword(str_sym)
        stx     z:ui_str_ptr
        lda     #^str_sym
        sta     z:ui_str_ptr + 2
        jsr     ui_set_message
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
; status_bar_init
; Initializes default stats (HP 20/20, MP 4/4), clears header/message pointers,
; and marks `status_bar_dirty = 1`.
; ------------------------------------------------------------------------------
status_bar_init:
        php
        RW_forced a8i16
        lda     #20
        sta     a:status_hp_cur
        sta     a:status_hp_max
        lda     #4
        sta     a:status_mp_cur
        sta     a:status_mp_max
        lda     #UI_PAL_ACTIVE
        sta     a:status_header_pal
        stz     a:status_header_ptr
        stz     a:status_header_ptr + 1
        stz     a:status_header_ptr + 2
        stz     a:status_msg0_ptr
        stz     a:status_msg0_ptr + 1
        stz     a:status_msg0_ptr + 2
        stz     a:status_msg1_ptr
        stz     a:status_msg1_ptr + 1
        stz     a:status_msg1_ptr + 2
        lda     #$01
        sta     a:status_bar_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; status_bar_set_stats
; Call after updating `status_hp_cur`, `status_hp_max`, `status_mp_cur`,
; `status_mp_max` (or just sets `status_bar_dirty = 1`).
; ------------------------------------------------------------------------------
status_bar_set_stats:
        php
        RW_forced a8i16
        lda     #$01
        sta     a:status_bar_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; status_bar_set_header
; In: z:ui_str_ptr = 24-bit pointer to header string (up to 11 chars),
;     A (8-bit)    = palette (UI_PAL_ACTIVE / UI_PAL_ALERT / UI_PAL_UNFOCUS).
; ------------------------------------------------------------------------------
status_bar_set_header:
        php
        RW_forced a8i16
        sta     a:status_header_pal
        lda     z:ui_str_ptr
        sta     a:status_header_ptr
        lda     z:ui_str_ptr + 1
        sta     a:status_header_ptr + 1
        lda     z:ui_str_ptr + 2
        sta     a:status_header_ptr + 2
        lda     #$01
        sta     a:status_bar_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; ui_set_message
; Scrolls 2-line log (current Line 1 -> Line 0) and sets Line 1 to `z:ui_str_ptr`.
; Marks `status_bar_dirty = 1`.
; ------------------------------------------------------------------------------
ui_set_message:
        php
        RW_forced a8i16
        lda     a:status_msg1_ptr
        sta     a:status_msg0_ptr
        lda     a:status_msg1_ptr + 1
        sta     a:status_msg0_ptr + 1
        lda     a:status_msg1_ptr + 2
        sta     a:status_msg0_ptr + 2

        lda     z:ui_str_ptr
        sta     a:status_msg1_ptr
        lda     z:ui_str_ptr + 1
        sta     a:status_msg1_ptr + 1
        lda     z:ui_str_ptr + 2
        sta     a:status_msg1_ptr + 2

        lda     #$01
        sta     a:status_bar_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; ui_set_messages
; Marks `status_bar_dirty = 1` after caller writes `status_msg0_ptr` and
; `status_msg1_ptr` directly.
; ------------------------------------------------------------------------------
ui_set_messages:
        php
        RW_forced a8i16
        lda     #$01
        sta     a:status_bar_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; status_bar_draw
; Redraws the 32x8 bottom status & message log bar into `bg3_tilemap_buf` when
; `status_bar_dirty != 0`, then clears `status_bar_dirty`.
; ------------------------------------------------------------------------------
status_bar_draw:
        php
        RW_forced a8i16
        lda     a:status_bar_dirty
        bne     :+
        brl     @done
:       stz     a:status_bar_dirty

        ; 1. Outer 32x8 9-slice RPG window frame
        lda     #STATUS_BAR_X
        sta     a:ui_arg_x
        lda     #STATUS_BAR_Y
        sta     a:ui_arg_y
        lda     #STATUS_BAR_W
        sta     a:ui_arg_w
        lda     #STATUS_BAR_H
        sta     a:ui_arg_h
        lda     #UI_PAL_ACTIVE
        sta     a:ui_arg_pal
        jsr     ui_draw_box

        ; 2. Mode / Turn Header at (1, STATUS_ROW_HEADER)
        lda     a:status_header_ptr
        ora     a:status_header_ptr + 1
        ora     a:status_header_ptr + 2
        beq     @draw_dividers

        lda     a:status_header_ptr
        sta     z:ui_str_ptr
        lda     a:status_header_ptr + 1
        sta     z:ui_str_ptr + 1
        lda     a:status_header_ptr + 2
        sta     z:ui_str_ptr + 2
        lda     #(STATUS_BAR_X + 1)
        sta     a:ui_arg_x
        lda     #STATUS_ROW_HEADER
        sta     a:ui_arg_y
        lda     a:status_header_pal
        sta     a:ui_arg_pal
        jsr     ui_print_str

@draw_dividers:
        ; Vertical dividers on header row at col 12 and col 22
        lda     #UI_PAL_ACTIVE
        sta     a:ui_arg_pal
        lda     #STATUS_ROW_HEADER
        sta     a:ui_arg_y
        lda     #UI_TILE_VLINE
        sta     a:ui_arg_val
        lda     #12
        sta     a:ui_arg_x
        jsr     ui_put_tile
        lda     #22
        sta     a:ui_arg_x
        jsr     ui_put_tile

        ; 3. Player HP: [Heart]HP xx/xx at cols 13..21
        lda     a:status_hp_cur
        cmp     #(STATUS_HP_LOW_THRESH + 1)
        bcc     @hp_alert
        lda     #UI_PAL_ACTIVE
        bra     @hp_pal_ok
@hp_alert:
        lda     #UI_PAL_ALERT
@hp_pal_ok:
        sta     a:_sb_hp_pal
        sta     a:ui_arg_pal
        lda     #STATUS_ROW_HEADER
        sta     a:ui_arg_y

        lda     #13
        sta     a:ui_arg_x
        lda     #UI_TILE_HEART
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #14
        sta     a:ui_arg_x
        lda     #'H'
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #15
        sta     a:ui_arg_x
        lda     #'P'
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #16
        sta     a:ui_arg_x
        lda     #' '
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #17
        sta     a:ui_arg_x
        lda     a:status_hp_cur
        sta     a:ui_arg_val
        jsr     ui_print_u8_2d

        lda     #19
        sta     a:ui_arg_x
        lda     #'/'
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #20
        sta     a:ui_arg_x
        lda     a:status_hp_max
        sta     a:ui_arg_val
        jsr     ui_print_u8_2d

        ; 4. Player MP: [Boots]MP x/x at cols 23..29
        lda     #UI_PAL_ACTIVE
        sta     a:ui_arg_pal
        lda     #STATUS_ROW_HEADER
        sta     a:ui_arg_y

        lda     #23
        sta     a:ui_arg_x
        lda     #UI_TILE_BOOTS
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #24
        sta     a:ui_arg_x
        lda     #'M'
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #25
        sta     a:ui_arg_x
        lda     #'P'
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #26
        sta     a:ui_arg_x
        lda     #' '
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #27
        sta     a:ui_arg_x
        lda     a:status_mp_cur
        sta     a:ui_arg_val
        jsr     ui_print_u8

        lda     #28
        sta     a:ui_arg_x
        lda     #'/'
        sta     a:ui_arg_val
        jsr     ui_put_tile

        lda     #29
        sta     a:ui_arg_x
        lda     a:status_mp_max
        sta     a:ui_arg_val
        jsr     ui_print_u8

        ; 5. Horizontal divider across cols 1..30 at STATUS_ROW_DIVIDER
        lda     #STATUS_ROW_DIVIDER
        sta     a:ui_arg_y
        lda     #UI_TILE_HLINE
        sta     a:ui_arg_val
        lda     #1
        sta     a:ui_arg_x
@hdiv_loop:
        jsr     ui_put_tile
        inc     a:ui_arg_x
        lda     a:ui_arg_x
        cmp     #31
        bcc     @hdiv_loop

        ; 6. Message Log Line 0 (dimmed/previous) & Line 1 (active/latest)
        lda     a:status_msg0_ptr
        ora     a:status_msg0_ptr + 1
        ora     a:status_msg0_ptr + 2
        beq     @draw_msg1

        lda     a:status_msg0_ptr
        sta     z:ui_str_ptr
        lda     a:status_msg0_ptr + 1
        sta     z:ui_str_ptr + 1
        lda     a:status_msg0_ptr + 2
        sta     z:ui_str_ptr + 2
        lda     #1
        sta     a:ui_arg_x
        lda     #STATUS_ROW_MSG0
        sta     a:ui_arg_y
        lda     #UI_PAL_UNFOCUS
        sta     a:ui_arg_pal
        jsr     ui_print_str

@draw_msg1:
        lda     a:status_msg1_ptr
        ora     a:status_msg1_ptr + 1
        ora     a:status_msg1_ptr + 2
        beq     @done

        lda     a:status_msg1_ptr
        sta     z:ui_str_ptr
        lda     a:status_msg1_ptr + 1
        sta     z:ui_str_ptr + 1
        lda     a:status_msg1_ptr + 2
        sta     z:ui_str_ptr + 2
        lda     #1
        sta     a:ui_arg_x
        lda     #STATUS_ROW_MSG1
        sta     a:ui_arg_y
        lda     #UI_PAL_ACTIVE
        sta     a:ui_arg_pal
        jsr     ui_print_str

@done:
        plp
        rts

.endif ; __SNES_UI_STATUS_BAR__
