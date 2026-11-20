; ==============================================================================
; interactables.i - Occluded Chest & Interactable Discovery Handler
;
; Part of IsoRPGDemo (Epic #30 / Issue #39).
; Pressing `A` in `STATE_EXPLORE` checks the Map Cell in front of the player
; (or any orthogonally adjacent unopened interactable if not facing directly),
; opens it, swaps its sprite/mask ID from `closed_sprite_id` -> `open_sprite_id`,
; applies its reward (`ATK_BUFF` / `HP_HEAL`), increments `player_secrets_found`,
; refreshes live Side Menu stats, and logs a discovery message.
; ==============================================================================

.ifndef __ISORPG_INTERACTABLES__
__ISORPG_INTERACTABLES__ = 1

; ------------------------------------------------------------------------------
; LORAM Scratch
; ------------------------------------------------------------------------------
.segment "LORAM"
_int_chk_col:                   .res 1
_int_chk_row:                   .res 1
_int_idx:                       .res 1
_int_dir_idx:                   .res 1

; ------------------------------------------------------------------------------
; WRAM-Resident Strings & Logic (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

str_chest_atk_buff:             .asciiz "FOUND IRON SWORD! ATK +3"
str_chest_hp_heal:              .asciiz "FOUND POTION! HP +5"
str_chest_generic:              .asciiz "OPENED TREASURE CHEST!"

; ------------------------------------------------------------------------------
; _interact_find_unopened_at (Internal)
; Searches `interact_table` for an active, unopened interactable at
; `(_int_chk_col, _int_chk_row)`.
; Out: Carry Set & X = byte offset in `interact_table` if found; Carry Clear if not.
; ------------------------------------------------------------------------------
_interact_find_unopened_at:
        php
        RW_forced a8i16
        stz     a:_int_idx
        ldx     #$0000
@loop:
        lda     a:_int_idx
        cmp     a:gmap_interact_count
        bcs     @not_found
        lda     f:interact_table + INTERACT_OFF_ACTIVE, x
        beq     @next
        lda     f:interact_table + INTERACT_OFF_OPENED, x
        bne     @next
        lda     f:interact_table + INTERACT_OFF_COL, x
        cmp     a:_int_chk_col
        bne     @next
        lda     f:interact_table + INTERACT_OFF_ROW, x
        cmp     a:_int_chk_row
        beq     @found
@next:
        RW a16
        txa
        clc
        adc     #INTERACT_STRUCT_SIZE
        tax
        RW a8
        inc     a:_int_idx
        bra     @loop
@found:
        plp
        sec
        rts
@not_found:
        plp
        clc
        rts

; ------------------------------------------------------------------------------
; interactables_check_action
; Call once per 60fps tick in `STATE_EXPLORE`.
; Triggers on rising-edge `JOY_A` when player is not mid-step.
; ------------------------------------------------------------------------------
interactables_check_action:
        php
        RW_forced a8i16

        ; Only act when stationary and A button was just pressed
        lda     a:player_move_anim_timer
        bne     @done_early
        lda     z:SFX_joy1trig          ; Low byte: A = $80
        bit     #<JOY_A
        bne     :+
@done_early:
        brl     @done
:
        ; 1. Check cell directly in front of player
        RW a16
        lda     a:player_facing
        and     #$0003
        tax
        RW a8
        lda     a:player_col
        clc
        adc     f:DIR_DCOL, x
        sta     a:_int_chk_col
        lda     a:player_row
        clc
        adc     f:DIR_DROW, x
        sta     a:_int_chk_row
        jsr     _interact_find_unopened_at
        bcs     @open_interactable

        ; 2. Fallback: check all 4 orthogonally adjacent cells
        stz     a:_int_dir_idx
@adj_loop:
        lda     a:_int_dir_idx
        cmp     #$04
        bcc     :+
        brl     @done
:       RW a16
        and     #$0003
        tax
        RW a8
        lda     a:player_col
        clc
        adc     f:DIR_DCOL, x
        sta     a:_int_chk_col
        lda     a:player_row
        clc
        adc     f:DIR_DROW, x
        sta     a:_int_chk_row
        jsr     _interact_find_unopened_at
        bcs     @open_interactable
        inc     a:_int_dir_idx
        bra     @adj_loop

        ; 3. Open chest / interactable at byte offset X in `interact_table`
@open_interactable:
        lda     #$01
        sta     f:interact_table + INTERACT_OFF_OPENED, x
        inc     a:player_secrets_found

        ; Apply reward
        lda     f:interact_table + INTERACT_OFF_REWARD_KIND, x
        cmp     #GMAP_REWARD_ATK_BUFF
        beq     @reward_atk
        cmp     #GMAP_REWARD_HP_HEAL
        beq     @reward_heal

        UI_SET_MESSAGE str_chest_generic
        bra     @refresh_ui

@reward_atk:
        lda     a:player_atk
        clc
        adc     f:interact_table + INTERACT_OFF_REWARD_VAL, x
        sta     a:player_atk
        UI_SET_MESSAGE str_chest_atk_buff
        bra     @refresh_ui

@reward_heal:
        lda     a:player_hp
        clc
        adc     f:interact_table + INTERACT_OFF_REWARD_VAL, x
        cmp     a:player_max_hp
        bcc     :+
        lda     a:player_max_hp
:       sta     a:player_hp
        sta     a:status_hp_cur
        jsr     status_bar_set_stats
        UI_SET_MESSAGE str_chest_hp_heal

@refresh_ui:
        jsr     game_state_refresh_explore_stats

@done:
        plp
        rts

.endif ; __ISORPG_INTERACTABLES__
