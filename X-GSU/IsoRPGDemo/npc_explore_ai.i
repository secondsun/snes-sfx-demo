; ==============================================================================
; npc_explore_ai.i - Exploration NPC Patrol AI & Aggro Encounter Trigger
;
; Part of IsoRPGDemo (Epic #30 / Issue #39).
; Responsibilities:
;   1. Decrements `player_flee_grace_timer` once per frame when > 0.
;   2. Steps `GMAP_AI_PATROL` NPCs 1 cell toward their active waypoint every
;      `NPC_PATROL_PERIOD` (50) frames, respecting walkability, elevation, and
;      entity occupation, with smooth 12-frame sub-cell interpolation.
;      `GMAP_AI_GUARD` NPCs remain stationary.
;   3. Checks Manhattan distance `|npc.col - player.col| + |npc.row - player.row|`
;      against `npc.aggro_range` when `player_flee_grace_timer == 0`; on aggro,
;      records `battle_enemy_idx` / `battle_enemy_mask`, logs `"ENEMY ENCOUNTER!"`,
;      and transitions cleanly to `STATE_BATTLE_INTRO`.
; ==============================================================================

.ifndef __ISORPG_NPC_EXPLORE_AI__
__ISORPG_NPC_EXPLORE_AI__ = 1

; ------------------------------------------------------------------------------
; LORAM Scratch
; ------------------------------------------------------------------------------
.segment "LORAM"
_ai_idx:                        .res 1
_ai_off:                        .res 2
_ai_wp_col:                     .res 1
_ai_wp_row:                     .res 1
_ai_npc_col:                    .res 1
_ai_npc_row:                    .res 1
_ai_world_dir:                  .res 1
_ai_moved:                      .res 1
_ai_dist:                       .res 1
_ai_bit:                        .res 1

; ------------------------------------------------------------------------------
; WRAM-Resident Strings & AI Logic (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

str_enemy_encounter:            .asciiz "ENEMY ENCOUNTER!"

; ------------------------------------------------------------------------------
; _ai_try_step (Internal)
; Attempts to step NPC `_ai_idx` (struct offset `_ai_off`) in world direction
; `A` (0=N, 1=E, 2=S, 3=W).
; Out: Carry Set if step committed, Carry Clear if blocked.
; ------------------------------------------------------------------------------
_ai_try_step:
        php
        RW_forced a8i16
        sta     a:_ai_world_dir

        RW a16
        and     #$0003
        tax
        RW a8
        lda     a:_ai_npc_col
        clc
        adc     f:DIR_DCOL, x
        sta     a:gmap_arg_col
        lda     a:_ai_npc_row
        clc
        adc     f:DIR_DROW, x
        sta     a:gmap_arg_row

        lda     a:_ai_npc_col
        sta     a:gmap_arg_from_col
        lda     a:_ai_npc_row
        sta     a:gmap_arg_from_row
        lda     a:_ai_idx
        sta     a:gmap_arg_ignore_npc
        lda     #$01
        sta     a:gmap_arg_check_player

        jsr     gmap_is_cell_passable
        bcs     :+
        plp
        clc
        rts
:
        ; Commit step to NPC struct
        ldx     a:_ai_off
        lda     a:gmap_arg_col
        sta     f:npc_table + NPC_OFF_COL, x
        sta     a:_ai_npc_col
        lda     a:gmap_arg_row
        sta     f:npc_table + NPC_OFF_ROW, x
        sta     a:_ai_npc_row

        ; Compute screen_dir = (world_dir + cam_quadrant) & 3
        jsr     explore_get_cam_quadrant
        clc
        adc     a:_ai_world_dir
        and     #$03
        ldx     a:_ai_off
        sta     f:npc_table + NPC_OFF_MOVE_DIR, x

        ; Set hflip if moving screen-left (dir 2 or 3)
        cmp     #$02
        bcc     @face_r
        lda     #$01
        bra     @set_flip
@face_r:
        lda     #$00
@set_flip:
        sta     f:npc_table + NPC_OFF_HFLIP, x

        ; Start 12-frame glide
        lda     #PLAYER_MOVE_ANIM_FRAMES
        sta     f:npc_table + NPC_OFF_MOVE_ANIM, x
        lda     f:npc_table + NPC_OFF_MOVE_DIR, x
        RW a16
        and     #$0003
        tay
        RW a8
        lda     #PLAYER_MOVE_ANIM_FRAMES
        jsr     explore_compute_sub_offset
        ldx     a:_ai_off
        RW a16
        lda     a:exp_out_sub_x
        sta     f:npc_table + NPC_OFF_SUB_X, x
        lda     a:exp_out_sub_y
        sta     f:npc_table + NPC_OFF_SUB_Y, x
        RW a8

        plp
        sec
        rts

; ------------------------------------------------------------------------------
; npc_explore_ai_tick
; Call once per 60fps tick when `game_state == STATE_EXPLORE`.
; ------------------------------------------------------------------------------
npc_explore_ai_tick:
        php
        RW_forced a8i16

        ; 1. Decrement flee grace timer if active
        lda     a:player_flee_grace_timer
        beq     :+
        dec     a:player_flee_grace_timer
:
        ; 2. Iterate over active NPCs
        stz     a:_ai_idx
        ldx     #$0000
        stx     a:_ai_off

@npc_loop:
        lda     a:_ai_idx
        cmp     a:gmap_npc_count
        bcc     :+
        brl     @done
:
        ldx     a:_ai_off
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        bne     :+
        brl     @next_npc
:       lda     f:npc_table + NPC_OFF_HP, x
        bne     :+
        brl     @next_npc
:
        ; Cache NPC (col, row)
        lda     f:npc_table + NPC_OFF_COL, x
        sta     a:_ai_npc_col
        lda     f:npc_table + NPC_OFF_ROW, x
        sta     a:_ai_npc_row

        ; 2a. Advance active step interpolation if moving
        lda     f:npc_table + NPC_OFF_MOVE_ANIM, x
        beq     @check_patrol
        dec
        sta     f:npc_table + NPC_OFF_MOVE_ANIM, x
        beq     @anim_done
        pha
        lda     f:npc_table + NPC_OFF_MOVE_DIR, x
        RW a16
        and     #$0003
        tay
        RW a8
        pla
        jsr     explore_compute_sub_offset
        ldx     a:_ai_off
        RW a16
        lda     a:exp_out_sub_x
        sta     f:npc_table + NPC_OFF_SUB_X, x
        lda     a:exp_out_sub_y
        sta     f:npc_table + NPC_OFF_SUB_Y, x
        RW a8
        brl     @check_aggro

@anim_done:
        RW a16
        lda     #$0000
        sta     f:npc_table + NPC_OFF_SUB_X, x
        sta     f:npc_table + NPC_OFF_SUB_Y, x
        RW a8
        brl     @check_aggro

        ; 2b. Patrol AI stepping (`GMAP_AI_PATROL` only)
@check_patrol:
        lda     f:npc_table + NPC_OFF_AI_TYPE, x
        cmp     #GMAP_AI_PATROL
        beq     :+
        brl     @check_aggro
:       lda     f:npc_table + NPC_OFF_WP_COUNT, x
        bne     :+
        brl     @check_aggro
:
        lda     f:npc_table + NPC_OFF_PATROL_TIMER, x
        beq     @do_patrol_step
        dec
        sta     f:npc_table + NPC_OFF_PATROL_TIMER, x
        brl     @check_aggro

@do_patrol_step:
        lda     #NPC_PATROL_PERIOD
        sta     f:npc_table + NPC_OFF_PATROL_TIMER, x

        ; Load active waypoint (wp_idx * 2)
        lda     f:npc_table + NPC_OFF_WP_IDX, x
        asl
        RW a16
        and     #$0007
        clc
        adc     a:_ai_off
        tax
        RW a8
        lda     f:npc_table + NPC_OFF_WAYPOINTS, x
        sta     a:_ai_wp_col
        lda     f:npc_table + NPC_OFF_WAYPOINTS + 1, x
        sta     a:_ai_wp_row

        ; If already at waypoint, advance wp_idx = (wp_idx + 1) % wp_count
        lda     a:_ai_npc_col
        cmp     a:_ai_wp_col
        bne     @step_toward_wp
        lda     a:_ai_npc_row
        cmp     a:_ai_wp_row
        bne     @step_toward_wp

        ldx     a:_ai_off
        lda     f:npc_table + NPC_OFF_WP_IDX, x
        inc
        cmp     f:npc_table + NPC_OFF_WP_COUNT, x
        bcc     :+
        lda     #$00
:       sta     f:npc_table + NPC_OFF_WP_IDX, x
        asl
        RW a16
        and     #$0007
        clc
        adc     a:_ai_off
        tax
        RW a8
        lda     f:npc_table + NPC_OFF_WAYPOINTS, x
        sta     a:_ai_wp_col
        lda     f:npc_table + NPC_OFF_WAYPOINTS + 1, x
        sta     a:_ai_wp_row

@step_toward_wp:
        ; Ignore unused $FF sentinel waypoints
        lda     a:_ai_wp_col
        cmp     #GMAP_UNUSED_WAYPOINT
        beq     @check_aggro

        ; Try X axis first if wp_col != npc_col
        lda     a:_ai_wp_col
        cmp     a:_ai_npc_col
        beq     @try_y_axis
        bcc     @try_west
        lda     #GMAP_FACING_EAST
        jsr     _ai_try_step
        bcs     @check_aggro
        bra     @try_y_axis
@try_west:
        lda     #GMAP_FACING_WEST
        jsr     _ai_try_step
        bcs     @check_aggro

@try_y_axis:
        lda     a:_ai_wp_row
        cmp     a:_ai_npc_row
        beq     @check_aggro
        bcc     @try_north
        lda     #GMAP_FACING_SOUTH
        jsr     _ai_try_step
        bra     @check_aggro
@try_north:
        lda     #GMAP_FACING_NORTH
        jsr     _ai_try_step

        ; 2c. Aggro Encounter Trigger Check
@check_aggro:
        lda     a:player_flee_grace_timer
        bne     @next_npc

        ; Manhattan distance = |npc_col - player_col| + |npc_row - player_row|
        lda     a:_ai_npc_col
        sec
        sbc     a:player_col
        bpl     :+
        eor     #$FF
        inc
:       sta     a:_ai_dist

        lda     a:_ai_npc_row
        sec
        sbc     a:player_row
        bpl     :+
        eor     #$FF
        inc
:       clc
        adc     a:_ai_dist
        sta     a:_ai_dist

        ldx     a:_ai_off
        lda     f:npc_table + NPC_OFF_AGGRO_RANGE, x
        beq     @next_npc               ; aggro_range == 0 => non-hostile
        cmp     a:_ai_dist
        bcc     @next_npc               ; aggro_range < dist => out of range

        ; Aggro triggered! Record enemy index & bitmask, enter STATE_BATTLE_INTRO
        lda     a:_ai_idx
        sta     a:battle_enemy_idx
        RW a16
        and     #$0007
        tay
        RW a8
        lda     #$01
@shift_bit:
        cpy     #$0000
        beq     @bit_done
        asl
        dey
        bra     @shift_bit
@bit_done:
        sta     a:battle_enemy_mask
        lda     f:npc_table + NPC_OFF_FLAGS, x
        ora     #$01
        sta     f:npc_table + NPC_OFF_FLAGS, x

        UI_SET_MESSAGE str_enemy_encounter
        lda     #STATE_BATTLE_INTRO
        jsr     game_state_enter
        bra     @done

@next_npc:
        RW a16
        lda     a:_ai_off
        clc
        adc     #NPC_STRUCT_SIZE
        sta     a:_ai_off
        RW a8
        inc     a:_ai_idx
        brl     @npc_loop

@done:
        plp
        rts

.endif ; __ISORPG_NPC_EXPLORE_AI__
