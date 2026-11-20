; ==============================================================================
; bg3_ui.i - BG3 WRAM Shadow Tilemap, Dirty-Flag VBlank DMA & Drawing Primitives
;
; Part of `snes_ui` (Epic #30 / Issue #36).
; Provides:
;   - 2 KB WRAM shadow tilemap (`bg3_tilemap_buf` in HIRAM) + `bg3_dirty` flag
;   - `bg3_ui_init`        : Clear shadow tilemap to transparent ($0000)
;   - `bg3_vblank_flush`   : Inline DMA channel 7 flush when `bg3_dirty != 0`
;   - `ui_put_tile`        : Write single tile + palette at (x, y)
;   - `ui_clear_rect`      : Clear (x, y, w, h) to transparent (exposes BG1)
;   - `ui_fill_rect`       : Fill (x, y, w, h) with solid panel tile + palette
;   - `ui_draw_box`        : Draw 9-slice RPG window border + fill at (x, y, w, h)
;   - `ui_print_str`       : Print 24-bit NUL-terminated ASCII string (auto-uppercase)
;   - `ui_print_u8`        : Print unsigned 8-bit integer (0..255, natural width)
;   - `ui_print_u8_2d`     : Print unsigned 8-bit integer (0..99, 2-char space-padded)
;   - Convenience macros: UI_CLEAR_RECT, UI_DRAW_BOX, UI_PRINT_STR, UI_PRINT_U8
;
; Define `SNES_UI_WRAM_CODE = 1` before `.include` to place runtime routines in
; `MAIN_LOOP` (WRAM) so they execute safely while SuperFX GSU owns the ROM bus.
; ==============================================================================

.ifndef __SNES_UI_BG3_UI__
__SNES_UI_BG3_UI__ = 1

.include "ui_font_tiles.i"

; ------------------------------------------------------------------------------
; Configuration Constants (overridable before .include)
; ------------------------------------------------------------------------------
.ifndef VRAM_BG3_MAP
VRAM_BG3_MAP            = $F000         ; 2 KB ($F000..$F7FF), $0800-aligned for BG3SC
.endif

BG3_TILEMAP_SIZE        = 2048          ; 32 * 32 * 2 bytes
BG3_ROW_STRIDE          = 64            ; 32 tiles * 2 bytes/tile
BG3_TILE_PRIO_HI        = $2000         ; Tilemap bit 13 = Priority 1 (BG3_PRIO_HIGH)

; ------------------------------------------------------------------------------
; Zero-Page Scratch & Pointer Registers
; ------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage
ui_str_ptr:             .res 3          ; 24-bit pointer to NUL-terminated ASCII string
ui_row_off:             .res 2          ; Byte offset into bg3_tilemap_buf (0..2046)

; ------------------------------------------------------------------------------
; LORAM Control State & Call Parameters
; ------------------------------------------------------------------------------
.segment "LORAM"
bg3_dirty:              .res 1          ; Non-zero => bg3_vblank_flush DMAs 2 KB to VRAM
ui_arg_x:               .res 1          ; Tile X (0..31)
ui_arg_y:               .res 1          ; Tile Y (0..31)
ui_arg_w:               .res 1          ; Width in tiles
ui_arg_h:               .res 1          ; Height in tiles
ui_arg_pal:             .res 1          ; BG3 palette index (0..7; use UI_PAL_*)
ui_arg_val:             .res 1          ; Single tile index or uint8 value
ui_arg_attr:            .res 2          ; Precomputed ((pal & 7) << 10) | BG3_TILE_PRIO_HI
ui_tmp_cnt:             .res 1          ; Internal loop counter
ui_tmp_row:             .res 1          ; Internal row loop counter
ui_tmp_rem:             .res 1          ; Internal digit remainder / column clamp

.export bg3_dirty, ui_arg_x, ui_arg_y, ui_arg_w, ui_arg_h, ui_arg_pal, ui_arg_val

; ------------------------------------------------------------------------------
; HIRAM 2 KB Shadow Tilemap Buffer ($7E:xxxx)
; ------------------------------------------------------------------------------
.segment "HIRAM"
bg3_tilemap_buf:        .res BG3_TILEMAP_SIZE

.export bg3_tilemap_buf

; ------------------------------------------------------------------------------
; Convenience Macros
; ------------------------------------------------------------------------------
.macro UI_CLEAR_RECT x_col, y_row, width, height
        RW_push set:a8i16
        lda     #(x_col)
        sta     a:ui_arg_x
        lda     #(y_row)
        sta     a:ui_arg_y
        lda     #(width)
        sta     a:ui_arg_w
        lda     #(height)
        sta     a:ui_arg_h
        jsr     ui_clear_rect
        RW_pull
.endmac

.macro UI_DRAW_BOX x_col, y_row, width, height, pal_idx
        RW_push set:a8i16
        lda     #(x_col)
        sta     a:ui_arg_x
        lda     #(y_row)
        sta     a:ui_arg_y
        lda     #(width)
        sta     a:ui_arg_w
        lda     #(height)
        sta     a:ui_arg_h
        lda     #(pal_idx)
        sta     a:ui_arg_pal
        jsr     ui_draw_box
        RW_pull
.endmac

.macro UI_PRINT_STR x_col, y_row, str_sym, pal_idx
        RW_push set:a8i16
        lda     #(x_col)
        sta     a:ui_arg_x
        lda     #(y_row)
        sta     a:ui_arg_y
        lda     #(pal_idx)
        sta     a:ui_arg_pal
        ldx     #.loword(str_sym)
        stx     z:ui_str_ptr
        lda     #^str_sym
        sta     z:ui_str_ptr + 2
        jsr     ui_print_str
        RW_pull
.endmac

.macro UI_PRINT_U8 x_col, y_row, val_imm, pal_idx
        RW_push set:a8i16
        lda     #(x_col)
        sta     a:ui_arg_x
        lda     #(y_row)
        sta     a:ui_arg_y
        lda     #(val_imm)
        sta     a:ui_arg_val
        lda     #(pal_idx)
        sta     a:ui_arg_pal
        jsr     ui_print_u8
        RW_pull
.endmac

; ------------------------------------------------------------------------------
; Code Segment (WRAM MAIN_LOOP when SNES_UI_WRAM_CODE is defined, else CODE)
; ------------------------------------------------------------------------------
.ifdef SNES_UI_WRAM_CODE
.segment "MAIN_LOOP"
.else
.segment "CODE"
.endif

; ------------------------------------------------------------------------------
; bg3_ui_init
; Clears the entire 2 KB BG3 shadow tilemap to transparent ($0000) and marks
; `bg3_dirty = 1`.
; ------------------------------------------------------------------------------
bg3_ui_init:
        php
        RW_forced a16i16
        lda     #$0000
        ldx     #$0000
@clr_loop:
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        cpx     #BG3_TILEMAP_SIZE
        bcc     @clr_loop
        RW a8
        lda     #$01
        sta     a:bg3_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; bg3_vblank_flush
; Call inside VBlank handler. If `bg3_dirty != 0`, clears `bg3_dirty` and DMAs
; the 2 KB WRAM shadow tilemap to `VRAM_BG3_MAP` using inline DMA channel 7.
; Safe to execute from WRAM while SuperFX GSU owns ROM/RAM buses.
; ------------------------------------------------------------------------------
bg3_vblank_flush:
        php
        RW_forced a8i16
        lda     a:bg3_dirty
        beq     _bg3_vblank_flush_done
        stz     a:bg3_dirty
        VRAM_memcpy VRAM_BG3_MAP, bg3_tilemap_buf, BG3_TILEMAP_SIZE
_bg3_vblank_flush_done:
        plp
        rts

; ------------------------------------------------------------------------------
; _ui_calc_offset (Internal)
; Computes:
;   z:ui_row_off  = (((ui_arg_y & $1F) << 5) | (ui_arg_x & $1F)) << 1
;   a:ui_arg_attr = ((ui_arg_pal & 7) << 10) | BG3_TILE_PRIO_HI
; Expects: a8i16. Preserves: nothing.
; ------------------------------------------------------------------------------
_ui_calc_offset:
        RW_forced a8i16
        ; Compute high attribute word: ((pal & 7) << 2) | $20 in high byte
        lda     a:ui_arg_pal
        and     #$07
        asl
        asl
        ora     #$20                    ; BG3_TILE_PRIO_HI high byte ($2000)
        sta     a:ui_arg_attr + 1
        stz     a:ui_arg_attr

        ; Compute byte offset: ((y & 31) * 32 + (x & 31)) * 2
        RW a16
        lda     a:ui_arg_y
        and     #$001F
        asl
        asl
        asl
        asl
        asl                             ; y * 32
        sta     z:ui_row_off
        lda     a:ui_arg_x
        and     #$001F
        ora     z:ui_row_off
        asl                             ; * 2 bytes/tile
        sta     z:ui_row_off
        RW a8
        rts

; ------------------------------------------------------------------------------
; ui_put_tile
; Writes a single tile (`ui_arg_val`) with palette `ui_arg_pal` at
; (`ui_arg_x`, `ui_arg_y`) and marks `bg3_dirty = 1`.
; ------------------------------------------------------------------------------
ui_put_tile:
        php
        RW_forced a8i16
        jsr     _ui_calc_offset
        ldx     z:ui_row_off
        RW a16
        lda     a:ui_arg_val
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        RW a8
        lda     #$01
        sta     a:bg3_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; ui_clear_rect
; Clears rectangle (`ui_arg_x`, `ui_arg_y`, `ui_arg_w`, `ui_arg_h`) to $0000
; (transparent over BG1) and marks `bg3_dirty = 1`.
; ------------------------------------------------------------------------------
ui_clear_rect:
        php
        RW_forced a8i16
        lda     a:ui_arg_w
        beq     @done
        lda     a:ui_arg_h
        beq     @done
        sta     a:ui_tmp_row
        jsr     _ui_calc_offset

@row_loop:
        ldx     z:ui_row_off
        RW a16
        lda     a:ui_arg_w
        and     #$00FF
        tay
        lda     #$0000
@col_loop:
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        dey
        bne     @col_loop

        lda     z:ui_row_off
        clc
        adc     #BG3_ROW_STRIDE
        and     #$07FF
        sta     z:ui_row_off
        RW a8
        dec     a:ui_tmp_row
        bne     @row_loop

        lda     #$01
        sta     a:bg3_dirty
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; ui_fill_rect
; Fills rectangle (`ui_arg_x`, `ui_arg_y`, `ui_arg_w`, `ui_arg_h`) with
; `UI_TILE_SOLID` + `ui_arg_pal` and marks `bg3_dirty = 1`.
; ------------------------------------------------------------------------------
ui_fill_rect:
        php
        RW_forced a8i16
        lda     a:ui_arg_w
        beq     @done
        lda     a:ui_arg_h
        beq     @done
        sta     a:ui_tmp_row
        jsr     _ui_calc_offset

@row_loop:
        ldx     z:ui_row_off
        RW a16
        lda     a:ui_arg_w
        and     #$00FF
        tay
        lda     a:ui_arg_attr
        ora     #UI_TILE_SOLID
@col_loop:
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        dey
        bne     @col_loop

        lda     z:ui_row_off
        clc
        adc     #BG3_ROW_STRIDE
        and     #$07FF
        sta     z:ui_row_off
        RW a8
        dec     a:ui_tmp_row
        bne     @row_loop

        lda     #$01
        sta     a:bg3_dirty
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; ui_draw_box
; Draws a 9-slice RPG window box at (`ui_arg_x`, `ui_arg_y`, `ui_arg_w`, `ui_arg_h`)
; using palette `ui_arg_pal` and marks `bg3_dirty = 1`. Requires w >= 2, h >= 2.
; ------------------------------------------------------------------------------
ui_draw_box:
        php
        RW_forced a8i16
        lda     a:ui_arg_w
        cmp     #$02
        bcs     :+
        brl     @done
:       lda     a:ui_arg_h
        cmp     #$02
        bcs     :+
        brl     @done
:

        jsr     _ui_calc_offset

        ; --- Top Row: TL + (w-2)*T + TR ---
        ldx     z:ui_row_off
        RW a16
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_TL
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        lda     a:ui_arg_w
        and     #$00FF
        sec
        sbc     #$0002
        beq     @top_right
        tay
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_T
@top_mid:
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        dey
        bne     @top_mid
@top_right:
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_TR
        sta     f:bg3_tilemap_buf, x

        ; Advance row offset
        lda     z:ui_row_off
        clc
        adc     #BG3_ROW_STRIDE
        and     #$07FF
        sta     z:ui_row_off

        ; --- Middle (h-2) Rows: L + (w-2)*SOLID + R ---
        RW a8
        lda     a:ui_arg_h
        sec
        sbc     #$02
        beq     @bottom_row
        sta     a:ui_tmp_row

@mid_row_loop:
        ldx     z:ui_row_off
        RW a16
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_L
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        lda     a:ui_arg_w
        and     #$00FF
        sec
        sbc     #$0002
        beq     @mid_right
        tay
        lda     a:ui_arg_attr
        ora     #UI_TILE_SOLID
@mid_col_loop:
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        dey
        bne     @mid_col_loop
@mid_right:
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_R
        sta     f:bg3_tilemap_buf, x

        lda     z:ui_row_off
        clc
        adc     #BG3_ROW_STRIDE
        and     #$07FF
        sta     z:ui_row_off
        RW a8
        dec     a:ui_tmp_row
        bne     @mid_row_loop

        ; --- Bottom Row: BL + (w-2)*B + BR ---
@bottom_row:
        ldx     z:ui_row_off
        RW a16
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_BL
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        lda     a:ui_arg_w
        and     #$00FF
        sec
        sbc     #$0002
        beq     @bot_right
        tay
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_B
@bot_mid:
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        dey
        bne     @bot_mid
@bot_right:
        lda     a:ui_arg_attr
        ora     #UI_TILE_BOX_BR
        sta     f:bg3_tilemap_buf, x
        RW a8

        lda     #$01
        sta     a:bg3_dirty
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; ui_print_str
; Prints NUL-terminated ASCII string at 24-bit `z:ui_str_ptr` starting at
; (`ui_arg_x`, `ui_arg_y`) with palette `ui_arg_pal`. Lowercase 'a'..'z' is
; folded to uppercase 'A'..'Z'. Clamps at column 31. Sets `bg3_dirty = 1`.
; ------------------------------------------------------------------------------
ui_print_str:
        php
        RW_forced a8i16
        lda     a:ui_arg_x
        cmp     #32
        bcs     @done
        lda     #32
        sec
        sbc     a:ui_arg_x
        sta     a:ui_tmp_rem            ; max characters before right edge

        jsr     _ui_calc_offset
        ldx     z:ui_row_off
        ldy     #$0000

@char_loop:
        lda     [ui_str_ptr], y
        beq     @finish
        ; Fold lowercase 'a' ($61) .. 'z' ($7A) -> 'A' ($41) .. 'Z' ($5A)
        cmp     #$61
        bcc     @write_ch
        cmp     #$7B
        bcs     @write_ch
        sec
        sbc     #$20
@write_ch:
        RW a16
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        iny
        RW a8
        dec     a:ui_tmp_rem
        bne     @char_loop

@finish:
        lda     #$01
        sta     a:bg3_dirty
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; ui_print_u8
; Prints unsigned 8-bit integer `ui_arg_val` (0..255) at (`ui_arg_x`, `ui_arg_y`)
; with palette `ui_arg_pal`, suppressing leading zeros (except "0").
; Sets `bg3_dirty = 1`.
; ------------------------------------------------------------------------------
ui_print_u8:
        php
        RW_forced a8i16
        jsr     _ui_calc_offset
        ldx     z:ui_row_off

        lda     a:ui_arg_val
        sta     a:ui_tmp_rem
        stz     a:ui_tmp_row            ; non-zero once any leading digit emitted

        ; Hundreds digit
        lda     #$00
@sub100:
        ldy     #$0000
        lda     a:ui_tmp_rem
        cmp     #100
        bcc     @emit100
        sec
        sbc     #100
        sta     a:ui_tmp_rem
        inc     a:ui_tmp_row
        ; Count hundreds in ui_tmp_cnt
        lda     #$01
        sta     a:ui_tmp_cnt
        lda     a:ui_tmp_rem
        cmp     #100
        bcc     @emit100_go
        sec
        sbc     #100
        sta     a:ui_tmp_rem
        inc     a:ui_tmp_cnt
@emit100_go:
        lda     a:ui_tmp_cnt
        clc
        adc     #$30                    ; '0'
        RW a16
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        RW a8
@emit100:

        ; Tens digit
        stz     a:ui_tmp_cnt
        lda     a:ui_tmp_rem
@sub10:
        cmp     #10
        bcc     @check_tens
        sec
        sbc     #10
        inc     a:ui_tmp_cnt
        bra     @sub10
@check_tens:
        sta     a:ui_tmp_rem            ; remainder = ones digit
        lda     a:ui_tmp_cnt
        bne     @emit_tens
        lda     a:ui_tmp_row
        beq     @emit_ones              ; suppress leading 0
        lda     #$00
@emit_tens:
        clc
        adc     #$30
        RW a16
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        RW a8

@emit_ones:
        lda     a:ui_tmp_rem
        clc
        adc     #$30
        RW a16
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        RW a8

        lda     #$01
        sta     a:bg3_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; ui_print_u8_2d
; Prints unsigned 8-bit integer `ui_arg_val` (clamped 0..99) as exactly 2 tiles
; (leading space if < 10) at (`ui_arg_x`, `ui_arg_y`) with `ui_arg_pal`.
; Ideal for fixed-width HUD fields such as `HP 20/20`.
; ------------------------------------------------------------------------------
ui_print_u8_2d:
        php
        RW_forced a8i16
        jsr     _ui_calc_offset
        ldx     z:ui_row_off

        lda     a:ui_arg_val
        cmp     #100
        bcc     :+
        lda     #99
:
        stz     a:ui_tmp_cnt
@sub10:
        cmp     #10
        bcc     @tens_done
        sec
        sbc     #10
        inc     a:ui_tmp_cnt
        bra     @sub10
@tens_done:
        sta     a:ui_tmp_rem            ; ones
        lda     a:ui_tmp_cnt
        bne     @has_tens
        lda     #$20                    ; ' '
        bra     @write_tens
@has_tens:
        clc
        adc     #$30
@write_tens:
        RW a16
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        inx
        inx
        RW a8

        lda     a:ui_tmp_rem
        clc
        adc     #$30
        RW a16
        and     #$00FF
        ora     a:ui_arg_attr
        sta     f:bg3_tilemap_buf, x
        RW a8

        lda     #$01
        sta     a:bg3_dirty
        plp
        rts

.endif ; __SNES_UI_BG3_UI__
