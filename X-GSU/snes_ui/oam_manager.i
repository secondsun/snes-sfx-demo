; ==============================================================================
; oam_manager.i - Under-BG1 Hardware OAM Manager & BG12NBA-Synced VBlank Latch
;
; Part of `snes_ui` (Epic #30 / Issue #37 / ADR 0005).
; Manages two hardware OAM priority tiers in SNES Mode 1 (`OBJ_8X8_16X16`):
;   Tier 1 (Slots  0..31, OBJ Priority 1 - behind BG1 Priority 1):
;     - Up to 16 in-world 16x24 metasprites (upper 16x16 + lower 16x8/16x16),
;       revealed through GSU 1-bit Sprite Mask cutouts in BG1.
;     - Staged into `oam_pending_entities` via `oam_begin_entities` /
;       `oam_push_entity_16x24` (clipped to X in [0..191], Y in [0..159]).
;     - Committed to `oam_shadow_buf` ONLY when `oam_latch_entities` is called
;       on the exact VBlank that flips `BG12NBA` (Pass 1 completion), ensuring
;       zero 1-frame desync between BG1 cutouts and hardware OAM sprites.
;   Tier 2 (Slots 32..127, OBJ Priority 3 - in front of BG1 & BG3):
;     - 60fps screen-space UI sprites (Side Menu cursor, turn badges, floating
;       damage numbers `-6` / `MISS`), rebuilt every frame via `oam_begin_frame`,
;       `oam_push_ui_sprite`, and `oam_update_damage_popups`.
;
; Define `SNES_UI_WRAM_CODE = 1` before `.include` to place runtime routines in
; `MAIN_LOOP` (WRAM) so they execute safely while SuperFX GSU owns the ROM bus.
; ==============================================================================

.ifndef __SNES_UI_OAM_MANAGER__
__SNES_UI_OAM_MANAGER__ = 1

; ------------------------------------------------------------------------------
; VRAM / CGRAM & Slot Contract Constants (overridable before .include)
; ------------------------------------------------------------------------------
.ifndef VRAM_UI_OBJ_TILES
VRAM_UI_OBJ_TILES       = $C000         ; 8 KB ($C000..$DFFF), $4000-aligned for OBSEL
.endif

; OBJ Palette Slots (0..7 -> CGRAM 128..255)
OAM_PAL_PLAYER          = 0             ; CGRAM 128..143
OAM_PAL_ENEMY_A         = 1             ; CGRAM 144..159
OAM_PAL_ENEMY_B         = 2             ; CGRAM 160..175
OAM_PAL_PROP            = 3             ; CGRAM 176..191
OAM_PAL_FX              = 4             ; CGRAM 192..207
OAM_PAL_RESERVED        = 5             ; CGRAM 208..223
OAM_PAL_UI_CUR          = 6             ; CGRAM 224..239 (Side Menu cursor / badges)
OAM_PAL_UI_DMG          = 7             ; CGRAM 240..255 (Floating damage numbers)

; OAM Priority Attribute Bits (OAM byte 3, bits 5..4)
OAM_PRIO_1_UNDER_BG1    = $10           ; Behind BG1 Priority 1 (revealed via Sprite Mask)
OAM_PRIO_3_OVER_UI      = $30           ; In front of BG1 and BG3_PRIO_HIGH
OAM_ATTR_HFLIP          = $40
OAM_ATTR_VFLIP          = $80

; Viewport Clipping Bounds for In-World Entities (192x160 BG1)
OAM_VIEWPORT_W          = 192
OAM_VIEWPORT_H          = 160
OAM_OFFSCREEN_Y         = $E0           ; Y = 224 (hidden below 224-line NTSC viewport)

; Slot Partitioning
OAM_MAX_ENTITIES        = 16
OAM_ENTITY_SLOT_COUNT   = (OAM_MAX_ENTITIES * 2) ; Slots 0..31 (32 sprites)
OAM_UI_SLOT_START       = OAM_ENTITY_SLOT_COUNT  ; Slots 32..127 (96 UI sprites)
OAM_TOTAL_SLOTS         = 128
OAM_SHADOW_SIZE         = 544           ; 512 low table + 32 high table

; Floating Damage Popup Configuration
OAM_MAX_POPUPS          = 4
OAM_POPUP_DURATION      = 30            ; 30 frames (~0.5s at 60fps)
OAM_DMG_MISS            = $FF           ; Special value -> displays "MISS"

; Default OBJ Tile Indices for Floating Damage Digits (overridable)
.ifndef OAM_TILE_DIGIT_0
OAM_TILE_DIGIT_0        = $E0           ; $E0..$E9 = '0'..'9'
.endif
.ifndef OAM_TILE_MINUS
OAM_TILE_MINUS          = $EA           ; '-'
.endif
.ifndef OAM_TILE_MISS_M
OAM_TILE_MISS_M         = $EB           ; 'M'
.endif
.ifndef OAM_TILE_MISS_I
OAM_TILE_MISS_I         = $EC           ; 'I'
.endif
.ifndef OAM_TILE_MISS_S
OAM_TILE_MISS_S         = $ED           ; 'S'
.endif

; Pending Entity Struct Offsets (8 bytes each)
OAM_ENT_SX              = 0             ; sint16
OAM_ENT_SY              = 2             ; sint16
OAM_ENT_TILE            = 4             ; uint8 (lower half = tile + $20)
OAM_ENT_PAL             = 5             ; uint8 (0..7)
OAM_ENT_HFLIP           = 6             ; uint8 (0 or non-zero)
OAM_ENT_STRIDE          = 8

; Damage Popup Struct Offsets (8 bytes each)
OAM_POP_TIMER           = 0             ; uint8 (0 = inactive)
OAM_POP_VAL             = 1             ; uint8 (0..99 or OAM_DMG_MISS)
OAM_POP_X               = 2             ; uint16
OAM_POP_Y               = 4             ; uint16
OAM_POP_PAL             = 6             ; uint8
OAM_POP_STRIDE          = 8

; ------------------------------------------------------------------------------
; LORAM Control State & Call Parameters
; ------------------------------------------------------------------------------
.segment "LORAM"
oam_pending_count:      .res 1          ; Number of staged entities (0..16)
oam_entity_latch_ready: .res 1          ; Non-zero => oam_latch_entities commits on BG12NBA flip
oam_ui_slot:            .res 1          ; Next free UI OAM slot (32..127)
oam_prev_ui_slot:       .res 1          ; High-water UI OAM slot from previous frame

; Shared call parameter block
oam_arg_x:              .res 2          ; Signed 16-bit screen X
oam_arg_y:              .res 2          ; Signed 16-bit screen Y
oam_arg_tile:           .res 1          ; Base tile index (0..255)
oam_arg_pal:            .res 1          ; OBJ palette (0..7)
oam_arg_hflip:          .res 1          ; Non-zero => horizontal flip
oam_arg_size:           .res 1          ; 0 = 8x8, 1 = 16x16 (for oam_push_ui_sprite)
oam_arg_val:            .res 1          ; Damage value (0..99 or OAM_DMG_MISS)

; Internal scratch
_oam_slot:              .res 1
_oam_wx:                .res 2
_oam_wy:                .res 1
_oam_wtile:             .res 1
_oam_wattr:             .res 1
_oam_wsize:             .res 1
_oam_hbits:             .res 1
_oam_idx:               .res 1
_oam_ent_slot:          .res 1
_oam_tmp_x:             .res 2
_oam_tmp_y:             .res 2
_oam_tmp_val:           .res 1
_oam_tmp_tens:          .res 1
_oam_tmp_pal:           .res 1

.export oam_pending_count, oam_entity_latch_ready, oam_ui_slot
.export oam_arg_x, oam_arg_y, oam_arg_tile, oam_arg_pal, oam_arg_hflip, oam_arg_size, oam_arg_val

; ------------------------------------------------------------------------------
; HIRAM Shadow OAM & Latch Buffers ($7E:xxxx)
; ------------------------------------------------------------------------------
.segment "HIRAM"
oam_shadow_buf:         .res OAM_SHADOW_SIZE
oam_pending_entities:   .res (OAM_MAX_ENTITIES * OAM_ENT_STRIDE)
oam_popups:             .res (OAM_MAX_POPUPS * OAM_POP_STRIDE)

.export oam_shadow_buf, oam_pending_entities, oam_popups

; ------------------------------------------------------------------------------
; Code Segment
; ------------------------------------------------------------------------------
.ifdef SNES_UI_WRAM_CODE
.segment "MAIN_LOOP"
.else
.segment "CODE"
.endif

; ------------------------------------------------------------------------------
; oam_mgr_init
; Hides all 128 sprites in `oam_shadow_buf` (Y = $E0), clears high table,
; resets pending entity latch and all floating damage popups.
; ------------------------------------------------------------------------------
oam_mgr_init:
        php
        RW_forced a8i16

        ; Clear low OAM table (128 sprites x 4 bytes: X=0, Y=$E0, tile=0, attr=0)
        ldx     #$0000
@clr_low:
        lda     #$00
        sta     f:oam_shadow_buf, x
        lda     #OAM_OFFSCREEN_Y
        sta     f:oam_shadow_buf + 1, x
        lda     #$00
        sta     f:oam_shadow_buf + 2, x
        sta     f:oam_shadow_buf + 3, x
        inx
        inx
        inx
        inx
        cpx     #512
        bcc     @clr_low

        ; Clear high OAM table (32 bytes = 0)
        lda     #$00
@clr_hi:
        sta     f:oam_shadow_buf, x
        inx
        cpx     #OAM_SHADOW_SIZE
        bcc     @clr_hi

        ; Clear floating damage popups
        ldx     #$0000
@clr_pop:
        sta     f:oam_popups, x
        inx
        cpx     #(OAM_MAX_POPUPS * OAM_POP_STRIDE)
        bcc     @clr_pop

        stz     a:oam_pending_count
        stz     a:oam_entity_latch_ready
        lda     #OAM_UI_SLOT_START
        sta     a:oam_ui_slot
        sta     a:oam_prev_ui_slot
        plp
        rts

; ------------------------------------------------------------------------------
; _oam_write_slot (Internal)
; Writes a single OAM sprite into `oam_shadow_buf` (both low & high tables).
; Expects: _oam_slot (0..127), _oam_wx (16-bit), _oam_wy (8-bit),
;          _oam_wtile (8-bit), _oam_wattr (8-bit), _oam_wsize (0 or 1).
; ------------------------------------------------------------------------------
_oam_write_slot:
        RW_forced a8i16
        ; Low table offset = slot * 4
        RW a16
        lda     a:_oam_slot
        and     #$007F
        asl
        asl
        tax
        RW a8
        lda     a:_oam_wx
        sta     f:oam_shadow_buf, x
        lda     a:_oam_wy
        sta     f:oam_shadow_buf + 1, x
        lda     a:_oam_wtile
        sta     f:oam_shadow_buf + 2, x
        lda     a:_oam_wattr
        sta     f:oam_shadow_buf + 3, x

        ; Compute 2-bit high-table entry: (size << 1) | (wx_hi & 1)
        lda     a:_oam_wsize
        and     #$01
        asl
        sta     a:_oam_hbits
        lda     a:_oam_wx + 1
        and     #$01
        ora     a:_oam_hbits
        sta     a:_oam_hbits

        ; High table byte index = 512 + (slot >> 2)
        RW a16
        lda     a:_oam_slot
        and     #$007F
        lsr
        lsr
        clc
        adc     #512
        tax
        RW a8

        ; Select 2-bit lane (slot & 3) with zero ROM table reads
        lda     a:_oam_slot
        and     #$03
        beq     @lane0
        cmp     #$01
        beq     @lane1
        cmp     #$02
        beq     @lane2

@lane3:
        lda     a:_oam_hbits
        asl
        asl
        asl
        asl
        asl
        asl
        sta     a:_oam_hbits
        lda     f:oam_shadow_buf, x
        and     #%00111111
        ora     a:_oam_hbits
        sta     f:oam_shadow_buf, x
        rts

@lane2:
        lda     a:_oam_hbits
        asl
        asl
        asl
        asl
        sta     a:_oam_hbits
        lda     f:oam_shadow_buf, x
        and     #%11001111
        ora     a:_oam_hbits
        sta     f:oam_shadow_buf, x
        rts

@lane1:
        lda     a:_oam_hbits
        asl
        asl
        sta     a:_oam_hbits
        lda     f:oam_shadow_buf, x
        and     #%11110011
        ora     a:_oam_hbits
        sta     f:oam_shadow_buf, x
        rts

@lane0:
        lda     f:oam_shadow_buf, x
        and     #%11111100
        ora     a:_oam_hbits
        sta     f:oam_shadow_buf, x
        rts

; ------------------------------------------------------------------------------
; oam_begin_frame
; Call once per 60fps logic tick before pushing Priority 3 UI sprites (cursor,
; damage popups, badges). Hides previous frame's UI slots (32..oam_prev_ui_slot)
; without touching Tier 1 in-world entity slots (0..31).
; ------------------------------------------------------------------------------
oam_begin_frame:
        php
        RW_forced a8i16
        lda     a:oam_ui_slot
        sta     a:oam_prev_ui_slot

        lda     #OAM_UI_SLOT_START
        sta     a:_oam_idx
@hide_loop:
        lda     a:_oam_idx
        cmp     a:oam_prev_ui_slot
        bcs     @reset_cursor
        RW a16
        and     #$007F
        asl
        asl
        tax
        RW a8
        lda     #OAM_OFFSCREEN_Y
        sta     f:oam_shadow_buf + 1, x
        inc     a:_oam_idx
        bra     @hide_loop

@reset_cursor:
        lda     #OAM_UI_SLOT_START
        sta     a:oam_ui_slot
        plp
        rts

; ------------------------------------------------------------------------------
; oam_begin_entities
; Begins staging a new batch of in-world entity positions into the pending
; latch buffer. Does NOT touch `oam_shadow_buf` until `oam_latch_entities` runs
; on the BG12NBA flip VBlank.
; ------------------------------------------------------------------------------
oam_begin_entities:
        php
        RW_forced a8i16
        stz     a:oam_pending_count
        stz     a:oam_entity_latch_ready
        plp
        rts

; ------------------------------------------------------------------------------
; oam_push_entity_16x24
; Stages one 16x24 in-world entity into `oam_pending_entities` for commit on
; the next BG12NBA flip VBlank.
; In: oam_arg_x (sint16), oam_arg_y (sint16), oam_arg_tile (uint8),
;     oam_arg_pal (0..7), oam_arg_hflip (0/non-zero).
; Clips entities completely outside X in [-15..191] or Y in [-23..159].
; ------------------------------------------------------------------------------
oam_push_entity_16x24:
        php
        RW_forced a8i16
        lda     a:oam_pending_count
        cmp     #OAM_MAX_ENTITIES
        bcs     @done

        ; Viewport clip: X must be in [-15 .. 191]
        RW a16
        lda     a:oam_arg_x
        clc
        adc     #15                     ; shift [-15..191] -> [0..206]
        cmp     #(OAM_VIEWPORT_W + 15)  ; unsigned >= 207 => outside!
        bcs     @done_a16

        ; Viewport clip: Y must be in [-23 .. 159]
        lda     a:oam_arg_y
        clc
        adc     #23                     ; shift [-23..159] -> [0..182]
        cmp     #(OAM_VIEWPORT_H + 23)  ; unsigned >= 183 => outside!
        bcs     @done_a16

        ; Write to oam_pending_entities[oam_pending_count * 8]
        lda     a:oam_pending_count
        and     #$00FF
        asl
        asl
        asl
        tax
        lda     a:oam_arg_x
        sta     f:oam_pending_entities + OAM_ENT_SX, x
        lda     a:oam_arg_y
        sta     f:oam_pending_entities + OAM_ENT_SY, x
        RW a8
        lda     a:oam_arg_tile
        sta     f:oam_pending_entities + OAM_ENT_TILE, x
        lda     a:oam_arg_pal
        sta     f:oam_pending_entities + OAM_ENT_PAL, x
        lda     a:oam_arg_hflip
        sta     f:oam_pending_entities + OAM_ENT_HFLIP, x

        inc     a:oam_pending_count
        lda     #$01
        sta     a:oam_entity_latch_ready
        bra     @done

@done_a16:
        RW_forced a8i16
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; oam_latch_entities
; ADR 0005 CRITICAL SYNC POINT:
; Call ONLY inside VBlank on the exact frame that flips `BG12NBA` (Pass 1 done).
; Commits `oam_pending_entities` into OAM slots 0..31 (OBJ Priority 1, behind
; BG1 Priority 1) and hides unused entity slots.
; ------------------------------------------------------------------------------
oam_latch_entities:
        php
        RW_forced a8i16
        lda     a:oam_entity_latch_ready
        bne     :+
        brl     @done
:       stz     a:oam_entity_latch_ready

        stz     a:_oam_idx
        stz     a:_oam_ent_slot

@ent_loop:
        lda     a:_oam_idx
        cmp     a:oam_pending_count
        bcc     :+
        brl     @hide_remaining
:

        ; Compute byte offset = _oam_idx * 8
        RW a16
        and     #$00FF
        asl
        asl
        asl
        tax
        lda     f:oam_pending_entities + OAM_ENT_SX, x
        sta     a:_oam_wx
        lda     f:oam_pending_entities + OAM_ENT_SY, x
        sta     a:_oam_tmp_y
        RW a8

        ; Build OBJ Priority 1 attribute byte: $10 | ((pal & 7) << 1) | (hflip ? $40 : 0)
        lda     f:oam_pending_entities + OAM_ENT_PAL, x
        and     #$07
        asl
        ora     #OAM_PRIO_1_UNDER_BG1
        sta     a:_oam_wattr
        lda     f:oam_pending_entities + OAM_ENT_HFLIP, x
        beq     :+
        lda     a:_oam_wattr
        ora     #OAM_ATTR_HFLIP
        sta     a:_oam_wattr
:
        lda     f:oam_pending_entities + OAM_ENT_TILE, x
        sta     a:_oam_wtile
        lda     #$01                    ; 16x16 large OBJ
        sta     a:_oam_wsize

        ; --- Upper 16x16 half at (sx, sy) ---
        RW a16
        lda     a:_oam_tmp_y
        bmi     @upper_check_neg
        cmp     #OAM_VIEWPORT_H
        bcs     @skip_upper
        bra     @emit_upper
@upper_check_neg:
        cmp     #$FFF1                  ; >= -15
        bcc     @skip_upper
@emit_upper:
        RW a8
        lda     a:_oam_tmp_y
        sta     a:_oam_wy
        lda     a:_oam_ent_slot
        sta     a:_oam_slot
        jsr     _oam_write_slot
        inc     a:_oam_ent_slot
        bra     @do_lower
@skip_upper:
        RW_forced a8i16

        ; --- Lower 16x8/16x16 half at (sx, sy + 16), tile + $20 ---
@do_lower:
        RW a16
        lda     a:_oam_tmp_y
        clc
        adc     #16
        bmi     @lower_check_neg
        cmp     #OAM_VIEWPORT_H         ; clip so feet never enter bottom bar (Y >= 160)
        bcs     @skip_lower
        bra     @emit_lower
@lower_check_neg:
        cmp     #$FFF1
        bcc     @skip_lower
@emit_lower:
        RW a8
        sta     a:_oam_wy
        lda     a:_oam_wtile
        clc
        adc     #$20
        sta     a:_oam_wtile
        lda     a:_oam_ent_slot
        sta     a:_oam_slot
        jsr     _oam_write_slot
        inc     a:_oam_ent_slot
        bra     @next_ent
@skip_lower:
        RW_forced a8i16

@next_ent:
        inc     a:_oam_idx
        brl     @ent_loop

@hide_remaining:
        lda     a:_oam_ent_slot
        cmp     #OAM_ENTITY_SLOT_COUNT
        bcs     @done
        RW a16
        and     #$007F
        asl
        asl
        tax
        RW a8
        lda     #OAM_OFFSCREEN_Y
        sta     f:oam_shadow_buf + 1, x
        inc     a:_oam_ent_slot
        bra     @hide_remaining

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; oam_push_ui_sprite
; Pushes a single Priority 3 UI sprite (slots 32..127, rendered above BG1 & BG3).
; In: oam_arg_x (16-bit), oam_arg_y (8-bit low), oam_arg_tile (uint8),
;     oam_arg_pal (0..7), oam_arg_size (0=8x8, 1=16x16), oam_arg_hflip (0/1).
; ------------------------------------------------------------------------------
oam_push_ui_sprite:
        php
        RW_forced a8i16
        lda     a:oam_ui_slot
        cmp     #OAM_TOTAL_SLOTS
        bcs     @done

        sta     a:_oam_slot
        inc     a:oam_ui_slot

        RW a16
        lda     a:oam_arg_x
        sta     a:_oam_wx
        RW a8
        lda     a:oam_arg_y
        sta     a:_oam_wy
        lda     a:oam_arg_tile
        sta     a:_oam_wtile
        lda     a:oam_arg_size
        sta     a:_oam_wsize

        lda     a:oam_arg_pal
        and     #$07
        asl
        ora     #OAM_PRIO_3_OVER_UI
        sta     a:_oam_wattr
        lda     a:oam_arg_hflip
        beq     :+
        lda     a:_oam_wattr
        ora     #OAM_ATTR_HFLIP
        sta     a:_oam_wattr
:
        jsr     _oam_write_slot
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; oam_spawn_damage_popup
; Spawns a floating damage number (`-6`, `-24`, or `MISS`) that rises and
; vanishes after `OAM_POPUP_DURATION` (30) frames.
; In: oam_arg_x (16-bit), oam_arg_y (16-bit), oam_arg_val (0..99 or OAM_DMG_MISS),
;     oam_arg_pal (0..7, typically OAM_PAL_UI_DMG).
; ------------------------------------------------------------------------------
oam_spawn_damage_popup:
        php
        RW_forced a8i16

        ; Find first inactive popup slot (fallback to slot 0)
        ldx     #$0000
        stz     a:_oam_idx
@find_slot:
        lda     f:oam_popups + OAM_POP_TIMER, x
        beq     @use_slot
        txa
        clc
        adc     #OAM_POP_STRIDE
        RW a16
        and     #$00FF
        tax
        RW a8
        inc     a:_oam_idx
        lda     a:_oam_idx
        cmp     #OAM_MAX_POPUPS
        bcc     @find_slot
        ldx     #$0000                  ; overwrite slot 0 if all active

@use_slot:
        lda     #OAM_POPUP_DURATION
        sta     f:oam_popups + OAM_POP_TIMER, x
        lda     a:oam_arg_val
        sta     f:oam_popups + OAM_POP_VAL, x
        lda     a:oam_arg_pal
        sta     f:oam_popups + OAM_POP_PAL, x
        RW a16
        lda     a:oam_arg_x
        sta     f:oam_popups + OAM_POP_X, x
        lda     a:oam_arg_y
        sta     f:oam_popups + OAM_POP_Y, x
        RW a8
        plp
        rts

; ------------------------------------------------------------------------------
; oam_update_damage_popups
; Call once per frame after `oam_begin_frame`. Steps all active floating damage
; popups (rising 1 px every 2 frames) and pushes their Priority 3 8x8 sprites.
; ------------------------------------------------------------------------------
oam_update_damage_popups:
        php
        RW_forced a8i16
        stz     a:_oam_idx

@pop_loop:
        lda     a:_oam_idx
        cmp     #OAM_MAX_POPUPS
        bcc     :+
        brl     @done
:
        ; Offset = _oam_idx * 8
        RW a16
        and     #$00FF
        asl
        asl
        asl
        tax
        RW a8

        lda     f:oam_popups + OAM_POP_TIMER, x
        bne     :+
        brl     @next_pop
:       dec
        sta     f:oam_popups + OAM_POP_TIMER, x

        ; Rise 1 px on even ticks
        bit     #$01
        bne     @read_pos
        RW a16
        lda     f:oam_popups + OAM_POP_Y, x
        beq     :+
        dec
        sta     f:oam_popups + OAM_POP_Y, x
:
        RW a8

@read_pos:
        RW a16
        lda     f:oam_popups + OAM_POP_X, x
        sta     a:_oam_tmp_x
        lda     f:oam_popups + OAM_POP_Y, x
        sta     a:_oam_tmp_y
        RW a8
        lda     f:oam_popups + OAM_POP_VAL, x
        sta     a:_oam_tmp_val
        lda     f:oam_popups + OAM_POP_PAL, x
        sta     a:_oam_tmp_pal

        ; Shared UI sprite fields
        lda     a:_oam_tmp_pal
        sta     a:oam_arg_pal
        stz     a:oam_arg_size          ; 8x8 small sprite
        stz     a:oam_arg_hflip
        RW a16
        lda     a:_oam_tmp_x
        sta     a:oam_arg_x
        lda     a:_oam_tmp_y
        sta     a:oam_arg_y
        RW a8

        ; Check special "MISS" sentinel
        lda     a:_oam_tmp_val
        cmp     #OAM_DMG_MISS
        bne     @emit_number

        ; Emit "M", "I", "S", "S"
        lda     #OAM_TILE_MISS_M
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite
        RW a16
        lda     a:oam_arg_x
        clc
        adc     #7
        sta     a:oam_arg_x
        RW a8
        lda     #OAM_TILE_MISS_I
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite
        RW a16
        lda     a:oam_arg_x
        clc
        adc     #7
        sta     a:oam_arg_x
        RW a8
        lda     #OAM_TILE_MISS_S
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite
        RW a16
        lda     a:oam_arg_x
        clc
        adc     #7
        sta     a:oam_arg_x
        RW a8
        lda     #OAM_TILE_MISS_S
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite
        bra     @next_pop

@emit_number:
        ; Emit '-'
        lda     #OAM_TILE_MINUS
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite

        ; Split value (0..99) into tens & ones
        lda     a:_oam_tmp_val
        cmp     #100
        bcc     :+
        lda     #99
:
        stz     a:_oam_tmp_tens
@div10:
        cmp     #10
        bcc     @div10_done
        sec
        sbc     #10
        inc     a:_oam_tmp_tens
        bra     @div10
@div10_done:
        sta     a:_oam_tmp_val          ; ones digit

        ; Emit tens digit if > 0
        lda     a:_oam_tmp_tens
        beq     @emit_ones
        RW a16
        lda     a:oam_arg_x
        clc
        adc     #7
        sta     a:oam_arg_x
        RW a8
        lda     a:_oam_tmp_tens
        clc
        adc     #OAM_TILE_DIGIT_0
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite

@emit_ones:
        RW a16
        lda     a:oam_arg_x
        clc
        adc     #7
        sta     a:oam_arg_x
        RW a8
        lda     a:_oam_tmp_val
        clc
        adc     #OAM_TILE_DIGIT_0
        sta     a:oam_arg_tile
        jsr     oam_push_ui_sprite

@next_pop:
        inc     a:_oam_idx
        brl     @pop_loop

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; oam_vblank_flush
; Call every VBlank (60fps). DMAs 544-byte `oam_shadow_buf` to PPU OAM using
; inline DMA channel 7. Safe to execute from WRAM while GSU owns ROM/RAM buses.
; ------------------------------------------------------------------------------
oam_vblank_flush:
        php
        RW_forced a8i16
        OAM_memcpy oam_shadow_buf
        plp
        rts

.endif ; __SNES_UI_OAM_MANAGER__
