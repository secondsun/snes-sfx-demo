; ==============================================================================
; npc_battle_ai.i - Greedy Tactical Battle NPC AI (`STATE_BATTLE_ENEMY_TURN`)
;
; Part of IsoRPGDemo (Epic #30 / Issue #40).
; All code and scratch variables live in WRAM (`MAIN_LOOP` / `LORAM`) so the
; 65816 never touches ROM while the SuperFX GSU owns the ROM bus.
;
; Behavior:
;   1. Runs orthogonal BFS from active NPC's cell up to `npc.move_points`.
;   2. Picks the reachable cell minimizing Manhattan distance to the player,
;      strictly preferring orthogonal adjacent cells within `|h_diff| <= 1`.
;   3. Animates NPC step-by-step along the reconstructed path.
;   4. If adjacent to player (`|dx|+|dy| == 1` and `|dh| <= 1`): executes Attack
;      (halved if `player_defending`), spawns floating OAM damage popup, logs
;      `"ENEMY HITS FOR X!"`, and triggers `STATE_GAME_OVER` if `player_hp == 0`.
;   5. Otherwise: sets `battle_npc_defending[u] = 1`, logs `"ENEMY DEFENDS!"`,
;      and advances turn.
; ==============================================================================

.ifndef __ISORPG_NPC_BATTLE_AI__
__ISORPG_NPC_BATTLE_AI__ = 1

BAI_PHASE_THINK                 = 0
BAI_PHASE_MOVE                  = 1
BAI_PHASE_ACT                   = 2

BAI_THINK_FRAMES                = 15
BAI_ACT_PAUSE_FRAMES            = 24

; ------------------------------------------------------------------------------
; LORAM Battle AI State & Scratch
; ------------------------------------------------------------------------------
.segment "LORAM"
_bai_phase:                     .res 1
_bai_timer:                     .res 1
_bai_step_idx:                  .res 1
_bai_npc_idx:                   .res 1
_bai_off:                       .res 2
_bai_pl_h:                      .res 1
_bai_best_score:                .res 1
_bai_best_dist:                 .res 1
_bai_best_col:                  .res 1
_bai_best_row:                  .res 1
_bai_cur_score:                 .res 1
_bai_cur_dist:                  .res 1
_bai_scan_idx:                  .res 2
_bai_nc:                        .res 1
_bai_nr:                        .res 1
_bai_wdir:                      .res 1
_bai_dmg:                       .res 1
_bai_tmp:                       .res 1

; ------------------------------------------------------------------------------
; WRAM-Resident Battle AI Logic (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

; ------------------------------------------------------------------------------
; npc_battle_ai_begin_turn
; Initializes AI state for `battle_active_unit` (0..3).
; ------------------------------------------------------------------------------
npc_battle_ai_begin_turn:
        php
        RW_forced a8i16
        lda     a:battle_active_unit
        sta     a:_bai_npc_idx
        jsr     _bc_npc_offset
        stx     a:_bai_off
        lda     #BAI_PHASE_THINK
        sta     a:_bai_phase
        lda     #BAI_THINK_FRAMES
        sta     a:_bai_timer
        stz     a:_bai_step_idx
        plp
        rts

; ------------------------------------------------------------------------------
; _bai_is_adjacent_to_player (Internal)
; Checks if active NPC (`_bai_off`) is orthogonally adjacent to Player AND
; within `|npc_h - player_h| <= 1`.
; Out: Carry Set if adjacent & valid melee elevation, Carry Clear otherwise.
; ------------------------------------------------------------------------------
_bai_is_adjacent_to_player:
        php
        RW_forced a8i16

        ldx     a:_bai_off
        lda     f:npc_table + NPC_OFF_COL, x
        sec
        sbc     a:player_col
        bpl     :+
        eor     #$FF
        inc
:       sta     a:_bai_tmp

        lda     f:npc_table + NPC_OFF_ROW, x
        sec
        sbc     a:player_row
        bpl     :+
        eor     #$FF
        inc
:       clc
        adc     a:_bai_tmp
        cmp     #$01
        bne     @not_adj

        ; Player height
        lda     a:player_row
        RW a16
        and     #$00FF
        tay
        RW a8
        lda     a:player_col
        jsr     battle_get_cell_height
        sta     a:_bai_pl_h

        ; NPC height
        ldx     a:_bai_off
        lda     f:npc_table + NPC_OFF_ROW, x
        RW a16
        and     #$00FF
        tay
        RW a8
        lda     f:npc_table + NPC_OFF_COL, x
        jsr     battle_get_cell_height
        sec
        sbc     a:_bai_pl_h
        bpl     :+
        eor     #$FF
        inc
:       cmp     #$02
        bcs     @not_adj

        plp
        sec
        rts
@not_adj:
        plp
        clc
        rts

; ------------------------------------------------------------------------------
; _bai_start_npc_step (Internal)
; Starts smooth cell glide for active NPC (`_bai_off`) to
; `battle_path_cols/rows[_bai_step_idx]`.
; ------------------------------------------------------------------------------
_bai_start_npc_step:
        php
        RW_forced a8i16

        RW a16
        lda     a:_bai_step_idx
        and     #$0007
        tax
        RW a8
        lda     a:battle_path_cols, x
        sta     a:_bai_nc
        lda     a:battle_path_rows, x
        sta     a:_bai_nr

        ldx     a:_bai_off
        lda     a:_bai_nc
        cmp     f:npc_table + NPC_OFF_COL, x
        beq     @chk_row
        bcc     @w_west
        lda     #GMAP_FACING_EAST
        bra     @dir_ok
@w_west:
        lda     #GMAP_FACING_WEST
        bra     @dir_ok
@chk_row:
        lda     a:_bai_nr
        cmp     f:npc_table + NPC_OFF_ROW, x
        bcc     @w_north
        lda     #GMAP_FACING_SOUTH
        bra     @dir_ok
@w_north:
        lda     #GMAP_FACING_NORTH

@dir_ok:
        sta     a:_bai_wdir

        ; Commit new (col, row) to NPC struct
        lda     a:_bai_nc
        sta     f:npc_table + NPC_OFF_COL, x
        lda     a:_bai_nr
        sta     f:npc_table + NPC_OFF_ROW, x

        ; screen_dir = (world_dir + cam_quadrant) & 3
        jsr     explore_get_cam_quadrant
        clc
        adc     a:_bai_wdir
        and     #$03
        ldx     a:_bai_off
        sta     f:npc_table + NPC_OFF_MOVE_DIR, x

        ; hflip if moving screen-left (dir 2 or 3)
        cmp     #$02
        bcc     @face_r
        lda     #$01
        bra     @set_hf
@face_r:
        lda     #$00
@set_hf:
        sta     f:npc_table + NPC_OFF_HFLIP, x

        ; Start smooth glide
        lda     #BATTLE_MOVE_ANIM_FRAMES
        sta     f:npc_table + NPC_OFF_MOVE_ANIM, x
        lda     f:npc_table + NPC_OFF_MOVE_DIR, x
        RW a16
        and     #$0003
        tay
        RW a8
        lda     #BATTLE_MOVE_ANIM_FRAMES
        jsr     explore_compute_sub_offset
        ldx     a:_bai_off
        RW a16
        lda     a:exp_out_sub_x
        sta     f:npc_table + NPC_OFF_SUB_X, x
        lda     a:exp_out_sub_y
        sta     f:npc_table + NPC_OFF_SUB_Y, x
        RW a8

        plp
        rts

; ------------------------------------------------------------------------------
; npc_battle_ai_tick
; Called once per 60fps tick when `game_state == STATE_BATTLE_ENEMY_TURN`.
; ------------------------------------------------------------------------------
npc_battle_ai_tick:
        php
        RW_forced a8i16
        jsr     explore_update_camera_follow

        lda     a:_bai_phase
        beq     @phase_think
        cmp     #BAI_PHASE_MOVE
        bne     :+
        brl     @phase_move
:       brl     @phase_act

; --- Phase 0: Think (brief pause, BFS, choose optimal destination) ---
@phase_think:
        lda     a:_bai_timer
        beq     @do_think
        dec
        sta     a:_bai_timer
        brl     @done

@do_think:
        ; If already orthogonally adjacent to player within +-1 height, skip move
        jsr     _bai_is_adjacent_to_player
        bcc     @run_bfs
        lda     #BAI_PHASE_ACT
        sta     a:_bai_phase
        stz     a:_bai_timer
        brl     @done

@run_bfs:
        ldx     a:_bai_off
        lda     f:npc_table + NPC_OFF_COL, x
        sta     a:bfs_arg_start_col
        sta     a:_bai_best_col
        lda     f:npc_table + NPC_OFF_ROW, x
        sta     a:bfs_arg_start_row
        sta     a:_bai_best_row
        lda     f:npc_table + NPC_OFF_MOVE_POINTS, x
        cmp     #(BATTLE_MAX_PATH_LEN + 1)
        bcc     :+
        lda     #BATTLE_MAX_PATH_LEN
:       sta     a:bfs_arg_max_steps
        lda     a:_bai_npc_idx
        sta     a:bfs_arg_ignore_npc
        lda     #$01
        sta     a:bfs_arg_check_player
        jsr     battle_bfs_compute

        ; Cache player height for melee elevation scoring
        lda     a:player_row
        RW a16
        and     #$00FF
        tay
        RW a8
        lda     a:player_col
        jsr     battle_get_cell_height
        sta     a:_bai_pl_h

        ; Scan all reachable cells to minimize score (0 = melee adjacent, else md*2)
        lda     #$FF
        sta     a:_bai_best_score
        sta     a:_bai_best_dist
        stz     a:_bai_scan_idx
        stz     a:_bai_scan_idx + 1

@scan_loop:
        RW a16
        lda     a:_bai_scan_idx
        cmp     a:gmap_total_cells
        RW a8
        bcc     :+
        brl     @scan_done
:
        ldx     a:_bai_scan_idx
        lda     f:bfs_dist, x
        cmp     #$FF
        bne     :+
        brl     @scan_next
:       sta     a:_bai_cur_dist

        ; Convert cell index -> (bfs_out_col, bfs_out_row)
        lda     a:_bai_scan_idx
        jsr     battle_bfs_idx_to_col_row

        ; Manhattan distance to player
        lda     a:bfs_out_col
        sec
        sbc     a:player_col
        bpl     :+
        eor     #$FF
        inc
:       sta     a:_bai_tmp
        lda     a:bfs_out_row
        sec
        sbc     a:player_row
        bpl     :+
        eor     #$FF
        inc
:       clc
        adc     a:_bai_tmp              ; A = Manhattan distance

        ; Compute score = (md == 1 && |dh| <= 1) ? 0 : min(md * 2, $FE)
        cmp     #$01
        bne     @non_adj_score
        ldx     a:_bai_scan_idx
        lda     f:gmap_height_grid, x
        sec
        sbc     a:_bai_pl_h
        bpl     :+
        eor     #$FF
        inc
:       cmp     #$02
        bcs     @adj_bad_height
        lda     #$00                    ; Best possible score: valid melee tile!
        bra     @cmp_best
@adj_bad_height:
        lda     #$02                    ; md == 1 but bad height
        bra     @cmp_best

@non_adj_score:
        asl
        bcc     :+
        lda     #$FE
:
@cmp_best:
        sta     a:_bai_cur_score
        cmp     a:_bai_best_score
        bcc     @take_best
        bne     @scan_next
        ; Tie on score: prefer smaller BFS step distance
        lda     a:_bai_cur_dist
        cmp     a:_bai_best_dist
        bcs     @scan_next

@take_best:
        lda     a:_bai_cur_score
        sta     a:_bai_best_score
        lda     a:_bai_cur_dist
        sta     a:_bai_best_dist
        lda     a:bfs_out_col
        sta     a:_bai_best_col
        lda     a:bfs_out_row
        sta     a:_bai_best_row

@scan_next:
        RW a16
        inc     a:_bai_scan_idx
        RW a8
        brl     @scan_loop

@scan_done:
        ; If best cell requires > 0 steps, reconstruct path & start moving
        lda     a:_bai_best_dist
        beq     @skip_move
        cmp     #$FF
        beq     @skip_move
        lda     a:_bai_best_col
        sta     a:bfs_arg_dest_col
        lda     a:_bai_best_row
        sta     a:bfs_arg_dest_row
        jsr     battle_bfs_reconstruct_path
        lda     a:battle_path_len
        beq     @skip_move

        stz     a:_bai_step_idx
        lda     #BAI_PHASE_MOVE
        sta     a:_bai_phase
        jsr     _bai_start_npc_step
        brl     @done

@skip_move:
        lda     #BAI_PHASE_ACT
        sta     a:_bai_phase
        stz     a:_bai_timer
        brl     @done

; --- Phase 1: Animate NPC step-by-step along reconstructed path ---
@phase_move:
        ldx     a:_bai_off
        lda     f:npc_table + NPC_OFF_MOVE_ANIM, x
        beq     @npc_step_done
        dec
        sta     f:npc_table + NPC_OFF_MOVE_ANIM, x
        beq     @npc_step_done

        pha
        lda     f:npc_table + NPC_OFF_MOVE_DIR, x
        RW a16
        and     #$0003
        tay
        RW a8
        pla
        jsr     explore_compute_sub_offset
        ldx     a:_bai_off
        RW a16
        lda     a:exp_out_sub_x
        sta     f:npc_table + NPC_OFF_SUB_X, x
        lda     a:exp_out_sub_y
        sta     f:npc_table + NPC_OFF_SUB_Y, x
        RW a8
        brl     @done

@npc_step_done:
        ldx     a:_bai_off
        RW a16
        lda     #$0000
        sta     f:npc_table + NPC_OFF_SUB_X, x
        sta     f:npc_table + NPC_OFF_SUB_Y, x
        RW a8

        inc     a:_bai_step_idx
        lda     a:_bai_step_idx
        cmp     a:battle_path_len
        bcs     @move_finished
        jsr     _bai_start_npc_step
        brl     @done

@move_finished:
        lda     #BAI_PHASE_ACT
        sta     a:_bai_phase
        stz     a:_bai_timer
        brl     @done

; --- Phase 2: Execute Attack (if adjacent) or Defend, pause, then advance turn ---
@phase_act:
        lda     a:_bai_timer
        beq     @execute_act
        dec
        sta     a:_bai_timer
        beq     :+
        brl     @done
:
        ; Pause complete: check player defeat or advance turn
        lda     a:player_hp
        bne     @end_enemy_turn
        jsr     battle_highlights_clear
        lda     #STATE_GAME_OVER
        jsr     game_state_enter
        brl     @done

@end_enemy_turn:
        jsr     battle_advance_turn
        brl     @done

@execute_act:
        lda     #BAI_ACT_PAUSE_FRAMES
        sta     a:_bai_timer

        jsr     _bai_is_adjacent_to_player
        bcc     @enemy_defend

        ; Enemy Attack: dmg = max(1, npc.atk - player_def), halved if player_defending
        ldx     a:_bai_off
        lda     f:npc_table + NPC_OFF_ATK, x
        sec
        sbc     a:player_def
        bcc     @min_dmg
        bne     @chk_pdef
@min_dmg:
        lda     #$01
@chk_pdef:
        sta     a:_bai_dmg

        lda     a:player_defending
        beq     @apply_pdmg
        lda     a:_bai_dmg
        lsr
        bne     :+
        lda     #$01
:       sta     a:_bai_dmg

@apply_pdmg:
        lda     a:player_hp
        sec
        sbc     a:_bai_dmg
        bcs     :+
        lda     #$00
:       sta     a:player_hp
        sta     a:status_hp_cur
        lda     #$01
        sta     a:status_bar_dirty
        jsr     game_state_refresh_explore_stats

        ; Spawn floating OAM damage popup on Player (slot 0)
        ldy     #$0000
        lda     a:_bai_dmg
        jsr     battle_spawn_slot_popup

        ; Format & log "ENEMY HITS FOR X!"
        ldy     #$0001
        lda     a:_bai_dmg
        jsr     battle_format_hit_msg
        UI_SET_MESSAGE str_enemy_hit_buf
        bra     @done

@enemy_defend:
        RW a16
        lda     a:_bai_npc_idx
        and     #$0003
        tay
        RW a8
        lda     #$01
        sta     a:battle_npc_defending, y
        UI_SET_MESSAGE str_msg_enemy_defends

@done:
        plp
        rts

.endif ; __ISORPG_NPC_BATTLE_AI__
