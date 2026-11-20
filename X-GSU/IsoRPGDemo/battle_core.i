; ==============================================================================
; battle_core.i - Turn Queue, Action Economy, Battle Menu & Combat State Handlers
;
; Part of IsoRPGDemo (Epic #30 / Issue #40).
; All code, strings, and state buffers live in WRAM (`MAIN_LOOP` / `LORAM`) so
; the 65816 never touches ROM while the SuperFX GSU owns the ROM bus.
; ==============================================================================

.ifndef __ISORPG_BATTLE_CORE__
__ISORPG_BATTLE_CORE__ = 1

BATTLE_UNIT_PLAYER              = $FF
BATTLE_MOVE_ANIM_FRAMES         = 10    ; Smooth 10-frame cell-to-cell battle glide
BATTLE_ATK_ANIM_FRAMES          = 18    ; Brief hero attack pose duration
BATTLE_INTRO_FRAMES             = 45    ; ~0.75s battle intro banner (skippable)
BATTLE_VICTORY_FRAMES           = 60    ; ~1.0s victory banner (skippable)
BATTLE_FLEE_GRACE_FRAMES        = 120   ; ~2.0s post-flee aggro immunity

; ------------------------------------------------------------------------------
; LORAM Battle State & Scratch
; ------------------------------------------------------------------------------
.segment "LORAM"
battle_queue:                   .res 5  ; Speed-sorted unit IDs ($FF=Player, 0..3=NPC)
battle_queue_len:               .res 1  ; 1..5
battle_queue_pos:               .res 1  ; Index into battle_queue ($FF before first turn)
battle_active_unit:             .res 1  ; $FF=Player, 0..3=NPC
battle_action_used:             .res 1  ; 0=available, 1=spent this turn
player_defending:               .res 1  ; 0=normal, 1=halves incoming damage
battle_npc_defending:           .res MAX_NPCS ; Per-NPC defending flag (0/1)

battle_cursor_col:              .res 1
battle_cursor_row:              .res 1
battle_atk_targets:             .res MAX_NPCS
battle_atk_count:               .res 1
battle_atk_sel:                 .res 1
battle_move_step_idx:           .res 1
battle_anim_timer:              .res 1
battle_rng_state:               .res 2  ; 16-bit LFSR RNG for Flee

; Mutable WRAM formatted combat log buffers (separate so 2-line log never aliases)
str_hero_hit_buf:               .res 24 ; "HERO HITS FOR XX!\0"
str_enemy_hit_buf:              .res 24 ; "ENEMY HITS FOR XX!\0"

; Internal scratch
_bc_i:                          .res 1
_bc_j:                          .res 1
_bc_bit:                        .res 1
_bc_off:                        .res 2
_bc_spd1:                       .res 1
_bc_spd2:                       .res 1
_bc_tmp:                        .res 1
_bc_tmp2:                       .res 1
_bc_pl_h:                       .res 1
_bc_t_h:                        .res 1
_bc_dmg:                        .res 1
_bc_slot:                       .res 1
_bc_dpad:                       .res 1
_bc_wdir:                       .res 1
_bc_nc:                         .res 1
_bc_nr:                         .res 1

.export battle_queue, battle_queue_len, battle_queue_pos, battle_active_unit
.export battle_action_used, player_defending, battle_npc_defending
.export battle_cursor_col, battle_cursor_row
.export battle_atk_targets, battle_atk_count, battle_atk_sel
.export str_hero_hit_buf, str_enemy_hit_buf

; ------------------------------------------------------------------------------
; WRAM-Resident Battle Strings & Core Logic (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

str_msg_hero_defends:           .asciiz "HERO DEFENDS!"
str_msg_flee_ok:                .asciiz "ESCAPED!"
str_msg_flee_fail:              .asciiz "COULDN'T ESCAPE!"
str_msg_enemy_defends:          .asciiz "ENEMY DEFENDS!"
str_msg_reinforcement:          .asciiz "ENEMY JOINS BATTLE!"
str_pfx_hero_hit:               .asciiz "HERO HITS FOR "
str_pfx_enemy_hit:              .asciiz "ENEMY HITS FOR "

; ------------------------------------------------------------------------------
; _bc_rng_next (Internal)
; Steps 16-bit Galois LFSR (`battle_rng_state`, poly $B400) and returns low byte in A.
; ------------------------------------------------------------------------------
_bc_rng_next:
        php
        RW_forced a16i16
        lda     a:battle_rng_state
        bne     :+
        lda     #$ACE1
:       lsr
        bcc     :+
        eor     #$B400
:       sta     a:battle_rng_state
        RW a8
        plp
        rts

; ------------------------------------------------------------------------------
; _bc_bit_mask (Internal)
; In:  A (8-bit) = index 0..7
; Out: A (8-bit) = (1 << index)
; ------------------------------------------------------------------------------
_bc_bit_mask:
        RW_forced a16i16
        and     #$0007
        tax
        RW a8
        lda     #$01
        cpx     #$0000
        beq     @done
@sh:    asl
        dex
        bne     @sh
@done:  rts

; ------------------------------------------------------------------------------
; _bc_npc_offset (Internal)
; In:  A (8-bit) = NPC index (0..3)
; Out: X (16-bit) = A * NPC_STRUCT_SIZE (32)
; ------------------------------------------------------------------------------
_bc_npc_offset:
        php
        RW_forced a16i16
        and     #$0003
        asl
        asl
        asl
        asl
        asl
        tax
        plp
        rts

; ------------------------------------------------------------------------------
; _bc_unit_speed (Internal)
; In:  A (8-bit) = unit ID ($FF = Player, 0..3 = NPC)
; Out: A (8-bit) = speed stat
; ------------------------------------------------------------------------------
_bc_unit_speed:
        RW_forced a8i16
        cmp     #BATTLE_UNIT_PLAYER
        bne     @npc
        lda     a:player_speed
        rts
@npc:   jsr     _bc_npc_offset
        lda     f:npc_table + NPC_OFF_SPEED, x
        rts

; ------------------------------------------------------------------------------
; battle_get_cell_height
; In:  A (8-bit) = col, Y (low 8-bit) = row
; Out: A (8-bit) = gmap_height_grid[row * gmap_cols + col] (0 if OOB)
; ------------------------------------------------------------------------------
battle_get_cell_height:
        php
        RW_forced a8i16
        sta     a:gmap_arg_col
        tya
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        bcs     @oob
        lda     f:gmap_height_grid, x
        plp
        rts
@oob:   lda     #$00
        plp
        rts

; ------------------------------------------------------------------------------
; battle_find_npc_entity_slot
; Computes the `GSU_SCENE_DESC.entity_out` slot index (1..4) for living NPC `A`
; (call BEFORE setting HP=0 so it matches the last published frame).
; In:  A (8-bit) = target NPC index (0..3)
; Out: A (8-bit) = entity slot index (1..7)
; ------------------------------------------------------------------------------
battle_find_npc_entity_slot:
        php
        RW_forced a8i16
        sta     a:_bc_tmp               ; target npc idx
        lda     #$01
        sta     a:_bc_slot              ; slot 0 is Player
        stz     a:_bc_i
        ldx     #$0000
@loop:
        lda     a:_bc_i
        cmp     a:_bc_tmp
        bcs     @done
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @next
        lda     f:npc_table + NPC_OFF_HP, x
        beq     @next
        inc     a:_bc_slot
@next:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        inc     a:_bc_i
        brl     @loop
@done:
        lda     a:_bc_slot
        plp
        rts

; ------------------------------------------------------------------------------
; battle_format_hit_msg
; Formats "HERO HITS FOR X!" (Y == 0 -> `str_hero_hit_buf`) or
; "ENEMY HITS FOR X!" (Y != 0 -> `str_enemy_hit_buf`).
; In:  A (8-bit) = dmg (0..99), Y (low 8-bit) = 0 (hero) or 1 (enemy).
; ------------------------------------------------------------------------------
battle_format_hit_msg:
        php
        RW_forced a8i16
        sta     a:_bc_dmg

        cpy     #$0000
        bne     @fmt_enemy

        ; Copy "HERO HITS FOR " -> str_hero_hit_buf
        ldx     #$0000
@copy_hero:
        lda     f:str_pfx_hero_hit, x
        beq     @hero_pfx_done
        sta     a:str_hero_hit_buf, x
        inx
        bra     @copy_hero
@hero_pfx_done:
        RW a16
        txa
        clc
        adc     #.loword(str_hero_hit_buf)
        tax
        RW a8
        bra     @write_dmg

@fmt_enemy:
        ; Copy "ENEMY HITS FOR " -> str_enemy_hit_buf
        ldx     #$0000
@copy_enemy:
        lda     f:str_pfx_enemy_hit, x
        beq     @enemy_pfx_done
        sta     a:str_enemy_hit_buf, x
        inx
        bra     @copy_enemy
@enemy_pfx_done:
        RW a16
        txa
        clc
        adc     #.loword(str_enemy_hit_buf)
        tax
        RW a8

@write_dmg:
        ; Convert _bc_dmg (0..99) -> 1 or 2 ASCII digits at a:$0000, x
        lda     a:_bc_dmg
        cmp     #100
        bcc     :+
        lda     #99
:       stz     a:_bc_tmp               ; tens
@div10:
        cmp     #10
        bcc     @div_done
        sec
        sbc     #10
        inc     a:_bc_tmp
        bra     @div10
@div_done:
        sta     a:_bc_tmp2              ; ones
        lda     a:_bc_tmp
        beq     @write_ones
        clc
        adc     #'0'
        sta     a:$0000, x
        inx
@write_ones:
        lda     a:_bc_tmp2
        clc
        adc     #'0'
        sta     a:$0000, x
        inx
        lda     #'!'
        sta     a:$0000, x
        inx
        stz     a:$0000, x              ; NUL terminator
        plp
        rts

; ------------------------------------------------------------------------------
; battle_spawn_slot_popup
; Spawns a floating OAM damage popup at entity slot `Y` (0 = Player, 1..4 = NPC)
; with value `A` (0..99). Falls back to (96, 80) if slot coordinates are (0, 0).
; ------------------------------------------------------------------------------
battle_spawn_slot_popup:
        php
        RW_forced a8i16
        sta     a:oam_arg_val
        lda     #OAM_PAL_UI_DMG
        sta     a:oam_arg_pal

        RW a16
        tya
        and     #$0007
        asl
        tax
        lda     a:entity_slot_sx, x
        ora     a:entity_slot_sy, x
        beq     @fallback
        lda     a:entity_slot_sx, x
        sta     a:oam_arg_x
        lda     a:entity_slot_sy, x
        sta     a:oam_arg_y
        bra     @spawn
@fallback:
        lda     #96
        sta     a:oam_arg_x
        lda     #80
        sta     a:oam_arg_y
@spawn:
        RW a8
        jsr     oam_spawn_damage_popup
        plp
        rts

; ------------------------------------------------------------------------------
; battle_check_any_enemy_alive
; Out: Carry Set if >= 1 engaged NPC in `battle_enemy_mask` is alive; Carry Clear else.
; ------------------------------------------------------------------------------
battle_check_any_enemy_alive:
        php
        RW_forced a8i16
        stz     a:_bc_i
        lda     #$01
        sta     a:_bc_bit
        ldx     #$0000
@loop:
        lda     a:_bc_i
        cmp     a:gmap_npc_count
        bcs     @none
        lda     a:battle_enemy_mask
        and     a:_bc_bit
        beq     @next
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @next
        lda     f:npc_table + NPC_OFF_HP, x
        bne     @alive
@next:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        asl     a:_bc_bit
        inc     a:_bc_i
        bra     @loop
@alive:
        plp
        sec
        rts
@none:
        plp
        clc
        rts

; ------------------------------------------------------------------------------
; battle_init_encounter
; Initializes turn queue (speed-sorted, Player wins ties), clears defending flags,
; seeds LFSR RNG, and clears highlights. Called on `STATE_BATTLE_INTRO` entry.
; ------------------------------------------------------------------------------
battle_init_encounter:
        php
        RW_forced a8i16

        jsr     battle_highlights_clear
        stz     a:player_defending
        stz     a:battle_action_used
        stz     a:battle_npc_defending + 0
        stz     a:battle_npc_defending + 1
        stz     a:battle_npc_defending + 2
        stz     a:battle_npc_defending + 3

        ; Seed LFSR RNG from SFX_tick (fallback $ACE1)
        RW a16
        lda     z:SFX_tick
        bne     :+
        lda     #$ACE1
:       sta     a:battle_rng_state
        RW a8

        ; Fallback: if battle_enemy_mask == 0, engage all living NPCs
        lda     a:battle_enemy_mask
        bne     @build_queue
        stz     a:_bc_i
        lda     #$01
        sta     a:_bc_bit
        ldx     #$0000
@fb_loop:
        lda     a:_bc_i
        cmp     a:gmap_npc_count
        bcs     @build_queue
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @fb_next
        lda     f:npc_table + NPC_OFF_HP, x
        beq     @fb_next
        lda     a:battle_enemy_mask
        ora     a:_bc_bit
        sta     a:battle_enemy_mask
@fb_next:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        asl     a:_bc_bit
        inc     a:_bc_i
        bra     @fb_loop

        ; Build queue: Player ($FF) first so stable sort gives Player priority on ties
@build_queue:
        lda     #BATTLE_UNIT_PLAYER
        sta     a:battle_queue
        lda     #$01
        sta     a:battle_queue_len

        stz     a:_bc_i
        lda     #$01
        sta     a:_bc_bit
        ldx     #$0000
@add_npcs:
        lda     a:_bc_i
        cmp     a:gmap_npc_count
        bcs     @sort_queue
        lda     a:battle_enemy_mask
        and     a:_bc_bit
        beq     @add_next
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @add_next
        lda     f:npc_table + NPC_OFF_HP, x
        beq     @add_next
        RW a16
        lda     a:battle_queue_len
        and     #$0007
        tay
        RW a8
        lda     a:_bc_i
        sta     a:battle_queue, y
        inc     a:battle_queue_len
@add_next:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        asl     a:_bc_bit
        inc     a:_bc_i
        bra     @add_npcs

        ; Stable bubble sort descending by speed (swap ONLY if spd[j+1] > spd[j])
@sort_queue:
        lda     a:battle_queue_len
        cmp     #$02
        bcc     @sort_done
        sta     a:_bc_i
@outer:
        dec     a:_bc_i
        beq     @sort_done
        stz     a:_bc_j
@inner:
        lda     a:_bc_j
        cmp     a:_bc_i
        bcs     @outer

        RW a16
        and     #$0007
        tay
        RW a8
        lda     a:battle_queue, y
        jsr     _bc_unit_speed
        sta     a:_bc_spd1
        lda     a:battle_queue + 1, y
        jsr     _bc_unit_speed
        sta     a:_bc_spd2

        ; Swap iff _bc_spd2 > _bc_spd1 (strictly greater => Player wins ties)
        lda     a:_bc_spd1
        cmp     a:_bc_spd2
        bcs     @no_swap
        lda     a:battle_queue, y
        pha
        lda     a:battle_queue + 1, y
        sta     a:battle_queue, y
        pla
        sta     a:battle_queue + 1, y
@no_swap:
        inc     a:_bc_j
        bra     @inner

@sort_done:
        lda     #$FF
        sta     a:battle_queue_pos
        plp
        rts

; ------------------------------------------------------------------------------
; battle_intro_tick
; Ticks `STATE_BATTLE_INTRO`; advances to first turn after 45 frames or A/START.
; ------------------------------------------------------------------------------
battle_intro_tick:
        php
        RW_forced a8i16
        lda     z:SFX_joy1trig
        bit     #<JOY_A
        bne     @start_battle
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_START
        bne     @start_battle
        RW a16
        lda     a:state_timer
        cmp     #BATTLE_INTRO_FRAMES
        RW a8
        bcc     @done
@start_battle:
        jsr     battle_advance_turn
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_advance_turn
; Checks Victory / Game Over, advances to next living unit in `battle_queue`,
; grants turn MP/Action, clears active unit's defend flag, and enters turn state.
; ------------------------------------------------------------------------------
battle_advance_turn:
        php
        RW_forced a8i16

        ; 1. Defeat check
        lda     a:player_hp
        bne     @chk_victory
        jsr     battle_highlights_clear
        lda     #STATE_GAME_OVER
        jsr     game_state_enter
        brl     @done

        ; 2. Victory check
@chk_victory:
        jsr     battle_check_any_enemy_alive
        bcs     @next_unit
        jsr     battle_highlights_clear
        lda     #STATE_VICTORY_BANNER
        jsr     game_state_enter
        brl     @done

        ; 3. Advance battle_queue_pos to next living unit
@next_unit:
        lda     a:battle_queue_len
        sta     a:_bc_i                 ; safety bound
@find_living:
        inc     a:battle_queue_pos
        lda     a:battle_queue_pos
        cmp     a:battle_queue_len
        bcc     :+
        stz     a:battle_queue_pos
:       RW a16
        lda     a:battle_queue_pos
        and     #$0007
        tay
        RW a8
        lda     a:battle_queue, y
        sta     a:battle_active_unit
        cmp     #BATTLE_UNIT_PLAYER
        beq     @start_player_turn

        ; Check if NPC is still active and alive
        jsr     _bc_npc_offset
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @skip_dead
        lda     f:npc_table + NPC_OFF_HP, x
        bne     @start_enemy_turn
@skip_dead:
        dec     a:_bc_i
        bne     @find_living
        ; Fallback: no living enemy found -> victory
        jsr     battle_highlights_clear
        lda     #STATE_VICTORY_BANNER
        jsr     game_state_enter
        brl     @done

@start_player_turn:
        stz     a:player_defending
        stz     a:battle_action_used
        lda     a:player_max_mp
        sta     a:player_mp
        sta     a:status_mp_cur
        sta     a:status_mp_max
        lda     a:player_hp
        sta     a:status_hp_cur
        lda     #$01
        sta     a:status_bar_dirty
        lda     #STATE_BATTLE_PLAYER_MENU
        jsr     game_state_enter
        brl     @done

@start_enemy_turn:
        RW a16
        lda     a:battle_active_unit
        and     #$0003
        tay
        RW a8
        lda     #$00
        sta     a:battle_npc_defending, y
        stz     a:battle_action_used
        jsr     npc_battle_ai_begin_turn
        lda     #STATE_BATTLE_ENEMY_TURN
        jsr     game_state_enter

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_find_attack_targets
; Populates `battle_atk_targets[]` and `battle_atk_count` with all living engaged
; NPCs on an orthogonal adjacent cell (`|dx|+|dy| == 1`) within `|dh| <= 1`.
; ------------------------------------------------------------------------------
battle_find_attack_targets:
        php
        RW_forced a8i16
        stz     a:battle_atk_count

        ; Player cell height
        lda     a:player_row
        RW a16
        and     #$00FF
        tay
        RW a8
        lda     a:player_col
        jsr     battle_get_cell_height
        sta     a:_bc_pl_h

        stz     a:_bc_i
        lda     #$01
        sta     a:_bc_bit
        ldx     #$0000
        stx     a:_bc_off

@loop:
        lda     a:_bc_i
        cmp     a:gmap_npc_count
        bcc     :+
        brl     @done
:       lda     a:battle_enemy_mask
        and     a:_bc_bit
        bne     :+
        brl     @next
:       ldx     a:_bc_off
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        bne     :+
        brl     @next
:       lda     f:npc_table + NPC_OFF_HP, x
        bne     :+
        brl     @next
:
        ; Manhattan distance == 1?
        lda     f:npc_table + NPC_OFF_COL, x
        sec
        sbc     a:player_col
        bpl     :+
        eor     #$FF
        inc
:       sta     a:_bc_tmp
        lda     f:npc_table + NPC_OFF_ROW, x
        sec
        sbc     a:player_row
        bpl     :+
        eor     #$FF
        inc
:       clc
        adc     a:_bc_tmp
        cmp     #$01
        bne     @next

        ; Check |target_h - player_h| <= 1
        lda     f:npc_table + NPC_OFF_ROW, x
        RW a16
        and     #$00FF
        tay
        RW a8
        lda     f:npc_table + NPC_OFF_COL, x
        jsr     battle_get_cell_height
        sec
        sbc     a:_bc_pl_h
        bpl     :+
        eor     #$FF
        inc
:       cmp     #$02
        bcs     @next

        ; Valid attack target! Append _bc_i
        RW a16
        lda     a:battle_atk_count
        and     #$0003
        tay
        RW a8
        lda     a:_bc_i
        sta     a:battle_atk_targets, y
        inc     a:battle_atk_count

@next:
        RW a16
        lda     a:_bc_off
        clc
        adc     #NPC_STRUCT_SIZE
        sta     a:_bc_off
        RW a8
        asl     a:_bc_bit
        inc     a:_bc_i
        brl     @loop

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_refresh_menu_enabled
; Computes dynamic 5-bit Battle Side Menu enabled mask:
;   Bit 0 (MOVE)   : player_mp > 0
;   Bit 1 (ATTACK) : battle_action_used == 0 && battle_atk_count > 0
;   Bit 2 (DEFEND) : battle_action_used == 0
;   Bit 3 (FLEE)   : battle_action_used == 0
;   Bit 4 (WAIT)   : always enabled ($10)
; ------------------------------------------------------------------------------
battle_refresh_menu_enabled:
        php
        RW_forced a8i16

        lda     #$10                    ; WAIT always enabled
        sta     a:_bc_tmp

        ; MOVE enabled iff player_mp > 0
        lda     a:player_mp
        beq     @chk_action
        lda     a:_bc_tmp
        ora     #$01
        sta     a:_bc_tmp

@chk_action:
        lda     a:battle_action_used
        bne     @apply_mask

        ; DEFEND (bit 2) & FLEE (bit 3) enabled when action unused
        lda     a:_bc_tmp
        ora     #$0C
        sta     a:_bc_tmp

        ; ATTACK (bit 1) enabled iff >= 1 adjacent enemy within +-1 height
        ; Preserve _bc_tmp across battle_find_attack_targets (which uses _bc_tmp as scratch)
        lda     a:_bc_tmp
        pha
        jsr     battle_find_attack_targets
        pla
        sta     a:_bc_tmp
        lda     a:battle_atk_count
        beq     @apply_mask
        lda     a:_bc_tmp
        ora     #$02
        sta     a:_bc_tmp

@apply_mask:
        lda     a:_bc_tmp
        jsr     side_menu_set_enabled

        ; Sync status bar HP/MP
        lda     a:player_hp
        sta     a:status_hp_cur
        lda     a:player_mp
        sta     a:status_mp_cur
        lda     #$01
        sta     a:status_bar_dirty

        plp
        rts

; ------------------------------------------------------------------------------
; battle_check_reinforcements
; Scans all living unengaged NPCs; if the player entered an unengaged NPC's
; aggro_range (Manhattan distance <= aggro_range), adds it to `battle_enemy_mask`,
; appends it to `battle_queue`, logs "ENEMY JOINS BATTLE!", and refreshes menu.
; ------------------------------------------------------------------------------
battle_check_reinforcements:
        php
        RW_forced a8i16
        stz     a:_bc_i
        stz     a:_bc_tmp2              ; added_any flag
        ldx     #$0000

@loop:
        lda     a:_bc_i
        cmp     a:gmap_npc_count
        bcc     :+
        brl     @finish
:
        ; Must be active and alive
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        bne     :+
        brl     @next
:       lda     f:npc_table + NPC_OFF_HP, x
        bne     :+
        brl     @next
:
        ; Skip if already in battle_enemy_mask
        phx
        lda     a:_bc_i
        jsr     _bc_bit_mask
        plx
        sta     a:_bc_bit
        bit     a:battle_enemy_mask
        beq     :+
        brl     @next
:

        ; Compute |npc.col - player.col| -> _bc_tmp
        lda     f:npc_table + NPC_OFF_COL, x
        sec
        sbc     a:player_col
        bcs     :+
        eor     #$FF
        inc
:       sta     a:_bc_tmp

        ; Add |npc.row - player.row|
        lda     f:npc_table + NPC_OFF_ROW, x
        sec
        sbc     a:player_row
        bcs     :+
        eor     #$FF
        inc
:       clc
        adc     a:_bc_tmp

        ; Compare with aggro_range (<= triggers reinforcement)
        cmp     f:npc_table + NPC_OFF_AGGRO_RANGE, x
        beq     @join
        bcs     @next

@join:
        ; Add to battle_enemy_mask & mark NPC engaged
        lda     a:battle_enemy_mask
        ora     a:_bc_bit
        sta     a:battle_enemy_mask
        lda     f:npc_table + NPC_OFF_FLAGS, x
        ora     #$01
        sta     f:npc_table + NPC_OFF_FLAGS, x

        ; Clear defending flag for this NPC
        RW a16
        lda     a:_bc_i
        and     #$0003
        tay
        RW a8
        lda     #$00
        sta     a:battle_npc_defending, y

        ; Append NPC index to battle_queue if space (< 5)
        lda     a:battle_queue_len
        cmp     #$05
        bcs     @skip_q
        RW a16
        and     #$0007
        tay
        RW a8
        lda     a:_bc_i
        sta     a:battle_queue, y
        inc     a:battle_queue_len
@skip_q:
        lda     #$01
        sta     a:_bc_tmp2
        phx
        UI_SET_MESSAGE str_msg_reinforcement
        plx

@next:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        inc     a:_bc_i
        brl     @loop

@finish:
        lda     a:_bc_tmp2
        beq     @done
        lda     a:game_state
        cmp     #STATE_BATTLE_PLAYER_MENU
        bne     @done
        jsr     battle_refresh_menu_enabled
@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_player_menu_tick
; Handles Battle Side Menu (`STATE_BATTLE_PLAYER_MENU`):
;   0: MOVE, 1: ATTACK, 2: DEFEND, 3: FLEE, 4: WAIT
; ------------------------------------------------------------------------------
battle_player_menu_tick:
        php
        RW_forced a8i16
        jsr     explore_update_camera_follow
        jsr     battle_check_reinforcements

        jsr     side_menu_update_joy1
        cmp     #SIDE_MENU_NONE
        bne     :+
        brl     @done
:       cmp     #SIDE_MENU_CANCEL
        bne     :+
        brl     @done
:       cmp     #$00
        beq     @cmd_move
        cmp     #$01
        beq     @cmd_attack
        cmp     #$02
        beq     @cmd_defend
        cmp     #$03
        beq     @cmd_flee
        cmp     #$04
        bne     :+
        brl     @cmd_wait
:       brl     @done

@cmd_move:
        lda     #STATE_BATTLE_MOVE_SELECT
        jsr     game_state_enter
        brl     @done

@cmd_attack:
        lda     #STATE_BATTLE_ATTACK_SELECT
        jsr     game_state_enter
        brl     @done

@cmd_defend:
        lda     #$01
        sta     a:player_defending
        sta     a:battle_action_used
        UI_SET_MESSAGE str_msg_hero_defends
        jsr     battle_advance_turn
        brl     @done

@cmd_flee:
        ; 75% success chance: (rng & 3) != 0
        jsr     _bc_rng_next
        and     #$03
        beq     @flee_failed

        ; Flee succeeded: clear highlights, disengage NPCs, grant 120-frame grace
        jsr     battle_highlights_clear
        stz     a:battle_enemy_mask
        lda     #$FF
        sta     a:battle_enemy_idx
        lda     #BATTLE_FLEE_GRACE_FRAMES
        sta     a:player_flee_grace_timer
        lda     a:player_max_mp
        sta     a:player_mp
        sta     a:status_mp_cur
        lda     #$01
        sta     a:status_bar_dirty

        ; Clear engaged bit (bit 0) on all NPCs
        stz     a:_bc_i
        ldx     #$0000
@clr_eng:
        lda     a:_bc_i
        cmp     a:gmap_npc_count
        bcs     @flee_exit
        lda     f:npc_table + NPC_OFF_FLAGS, x
        and     #$FE
        sta     f:npc_table + NPC_OFF_FLAGS, x
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        inc     a:_bc_i
        bra     @clr_eng

@flee_exit:
        UI_SET_MESSAGE str_msg_flee_ok
        lda     #STATE_EXPLORE
        jsr     game_state_enter
        brl     @done

@flee_failed:
        lda     #$01
        sta     a:battle_action_used
        UI_SET_MESSAGE str_msg_flee_fail
        lda     a:player_mp
        bne     @flee_stay_menu
        jsr     battle_advance_turn
        brl     @done
@flee_stay_menu:
        jsr     battle_refresh_menu_enabled
        brl     @done

@cmd_wait:
        jsr     battle_advance_turn

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; _bc_paint_move_highlights (Internal)
; Paints `battle_hl_grid[256]`:
;   1 <= bfs_dist[i] <= player_mp -> GSU_HIGHLIGHT_MOVE (1)
;   cursor cell                   -> GSU_HIGHLIGHT_CURSOR (3)
; ------------------------------------------------------------------------------
_bc_paint_move_highlights:
        php
        RW_forced a8i16

        ldx     #$0000
@loop:
        cpx     a:gmap_total_cells
        bcs     @paint_cursor
        lda     f:bfs_dist, x
        beq     @none
        cmp     #$FF
        beq     @none
        cmp     a:player_mp
        beq     @mark_move
        bcs     @none
@mark_move:
        lda     #GSU_HIGHLIGHT_MOVE
        bra     @store
@none:
        lda     #GSU_HIGHLIGHT_NONE
@store:
        sta     f:battle_hl_grid, x
        inx
        bra     @loop

@paint_cursor:
        lda     a:battle_cursor_col
        sta     a:gmap_arg_col
        lda     a:battle_cursor_row
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        bcs     @enable
        lda     #GSU_HIGHLIGHT_CURSOR
        sta     f:battle_hl_grid, x

@enable:
        lda     #$01
        sta     a:battle_hl_enabled
        plp
        rts

; ------------------------------------------------------------------------------
; battle_move_select_enter
; Computes BFS from player cell up to `player_mp`, places cursor on player,
; and publishes tactical movement highlights.
; ------------------------------------------------------------------------------
battle_move_select_enter:
        php
        RW_forced a8i16

        lda     a:player_col
        sta     a:bfs_arg_start_col
        sta     a:battle_cursor_col
        lda     a:player_row
        sta     a:bfs_arg_start_row
        sta     a:battle_cursor_row
        lda     a:player_mp
        sta     a:bfs_arg_max_steps
        lda     #$FF
        sta     a:bfs_arg_ignore_npc
        stz     a:bfs_arg_check_player
        jsr     battle_bfs_compute

        jsr     _bc_paint_move_highlights
        plp
        rts

; ------------------------------------------------------------------------------
; battle_move_select_tick
; Yaw-relative D-pad cursor movement, B cancels to menu, A confirms reachable cell.
; ------------------------------------------------------------------------------
battle_move_select_tick:
        php
        RW_forced a8i16
        jsr     explore_update_camera_follow

        ; Check B -> cancel back to menu
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_B
        beq     @check_a
        jsr     battle_highlights_clear
        lda     #STATE_BATTLE_PLAYER_MENU
        jsr     game_state_enter
        brl     @done

        ; Check A -> confirm if cursor cell is reachable (1 <= dist <= player_mp)
@check_a:
        lda     z:SFX_joy1trig
        bit     #<JOY_A
        beq     @check_dpad

        lda     a:battle_cursor_col
        sta     a:gmap_arg_col
        lda     a:battle_cursor_row
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        bcs     @check_dpad
        lda     f:bfs_dist, x
        beq     @check_dpad
        cmp     #$FF
        beq     @check_dpad
        cmp     a:player_mp
        beq     @confirm_move
        bcs     @check_dpad

@confirm_move:
        lda     a:battle_cursor_col
        sta     a:bfs_arg_dest_col
        lda     a:battle_cursor_row
        sta     a:bfs_arg_dest_row
        jsr     battle_bfs_reconstruct_path
        lda     a:battle_path_len
        beq     @done
        jsr     battle_highlights_clear
        stz     a:battle_move_step_idx
        lda     #STATE_BATTLE_MOVE_ANIM
        jsr     game_state_enter
        brl     @done

        ; Check rising-edge D-pad (yaw-relative via explore_get_cam_quadrant)
@check_dpad:
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_UP
        bne     @dir_up
        bit     #>JOY_RIGHT
        bne     @dir_right
        bit     #>JOY_DOWN
        bne     @dir_down
        bit     #>JOY_LEFT
        bne     @dir_left
        brl     @done

@dir_up:
        lda     #$00
        bra     @move_cursor
@dir_right:
        lda     #$01
        bra     @move_cursor
@dir_down:
        lda     #$02
        bra     @move_cursor
@dir_left:
        lda     #$03

@move_cursor:
        sta     a:_bc_dpad
        jsr     explore_get_cam_quadrant
        sta     a:_bc_tmp
        lda     a:_bc_dpad
        sec
        sbc     a:_bc_tmp
        and     #$03
        RW a16
        and     #$0003
        tax
        RW a8

        lda     a:battle_cursor_col
        clc
        adc     f:DIR_DCOL, x
        cmp     a:gmap_cols
        bcs     @done
        sta     a:_bc_nc

        lda     a:battle_cursor_row
        clc
        adc     f:DIR_DROW, x
        cmp     a:gmap_rows
        bcs     @done
        sta     a:battle_cursor_row
        lda     a:_bc_nc
        sta     a:battle_cursor_col

        jsr     _bc_paint_move_highlights

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; _bc_start_player_step (Internal)
; Starts 10-frame glide to `battle_path_cols/rows[battle_move_step_idx]`.
; ------------------------------------------------------------------------------
_bc_start_player_step:
        php
        RW_forced a8i16

        RW a16
        lda     a:battle_move_step_idx
        and     #$0007
        tax
        RW a8
        lda     a:battle_path_cols, x
        sta     a:_bc_nc
        lda     a:battle_path_rows, x
        sta     a:_bc_nr

        ; Determine world_dir (0=N, 1=E, 2=S, 3=W)
        lda     a:_bc_nc
        cmp     a:player_col
        beq     @chk_row
        bcc     @w_west
        lda     #GMAP_FACING_EAST
        bra     @dir_ok
@w_west:
        lda     #GMAP_FACING_WEST
        bra     @dir_ok
@chk_row:
        lda     a:_bc_nr
        cmp     a:player_row
        bcc     @w_north
        lda     #GMAP_FACING_SOUTH
        bra     @dir_ok
@w_north:
        lda     #GMAP_FACING_NORTH

@dir_ok:
        sta     a:_bc_wdir
        sta     a:player_facing

        ; screen_dir = (world_dir + cam_quadrant) & 3
        jsr     explore_get_cam_quadrant
        clc
        adc     a:_bc_wdir
        and     #$03
        sta     a:player_move_screen_dir

        ; hflip if moving screen-left (dir 2 or 3)
        cmp     #$02
        bcc     @face_r
        lda     #$01
        bra     @set_hf
@face_r:
        lda     #$00
@set_hf:
        sta     a:player_hflip

        ; Commit step coordinates & start glide
        lda     a:player_col
        sta     a:player_move_from_col
        lda     a:player_row
        sta     a:player_move_from_row
        lda     a:_bc_nc
        sta     a:player_col
        lda     a:_bc_nr
        sta     a:player_row

        lda     #BATTLE_MOVE_ANIM_FRAMES
        sta     a:player_move_anim_timer
        lda     #$01
        sta     a:player_sprite_id

        ; Seed initial sub-cell offset
        RW a16
        lda     a:player_move_screen_dir
        and     #$0003
        tay
        RW a8
        lda     #BATTLE_MOVE_ANIM_FRAMES
        jsr     explore_compute_sub_offset
        RW a16
        lda     a:exp_out_sub_x
        sta     a:player_sub_x
        lda     a:exp_out_sub_y
        sta     a:player_sub_y
        RW a8

        plp
        rts

; ------------------------------------------------------------------------------
; battle_move_anim_enter / battle_move_anim_tick
; Animates player step-by-step along `battle_path`, deducts cost from `player_mp`,
; and returns to `STATE_BATTLE_PLAYER_MENU` (or advances turn if MP==0 && action used).
; ------------------------------------------------------------------------------
battle_move_anim_enter:
        php
        RW_forced a8i16
        stz     a:battle_move_step_idx
        lda     a:battle_path_len
        beq     @done
        jsr     _bc_start_player_step
@done:
        plp
        rts

battle_move_anim_tick:
        php
        RW_forced a8i16
        jsr     explore_update_camera_follow

        lda     a:player_move_anim_timer
        beq     @step_done
        dec
        sta     a:player_move_anim_timer
        beq     @step_done

        ; Walk frame toggle & sub-pixel interpolation
        lsr
        lsr
        and     #$01
        sta     a:player_sprite_id

        RW a16
        lda     a:player_move_screen_dir
        and     #$0003
        tay
        RW a8
        lda     a:player_move_anim_timer
        jsr     explore_compute_sub_offset
        RW a16
        lda     a:exp_out_sub_x
        sta     a:player_sub_x
        lda     a:exp_out_sub_y
        sta     a:player_sub_y
        RW a8
        brl     @done

@step_done:
        stz     a:player_sprite_id
        stz     a:player_sub_x
        stz     a:player_sub_x + 1
        stz     a:player_sub_y
        stz     a:player_sub_y + 1

        ; Check if stepping onto this cell aggros any nearby unengaged enemy
        jsr     battle_check_reinforcements

        inc     a:battle_move_step_idx
        lda     a:battle_move_step_idx
        cmp     a:battle_path_len
        bcs     @path_finished
        jsr     _bc_start_player_step
        brl     @done

@path_finished:
        ; Deduct exact path cost from player_mp
        lda     a:player_mp
        sec
        sbc     a:battle_path_len
        bcs     :+
        lda     #$00
:       sta     a:player_mp
        sta     a:status_mp_cur
        lda     #$01
        sta     a:status_bar_dirty

        ; Splittable movement: return to menu unless both MP and Action are spent
        lda     a:player_mp
        bne     @back_to_menu
        lda     a:battle_action_used
        beq     @back_to_menu
        jsr     battle_advance_turn
        brl     @done

@back_to_menu:
        lda     #STATE_BATTLE_PLAYER_MENU
        jsr     game_state_enter

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; _bc_paint_attack_highlights (Internal)
; Paints valid adjacent enemy cells as GSU_HIGHLIGHT_ATTACK (2) and selected
; target as GSU_HIGHLIGHT_CURSOR (3).
; ------------------------------------------------------------------------------
_bc_paint_attack_highlights:
        php
        RW_forced a8i16
        jsr     battle_highlights_clear

        stz     a:_bc_i
@loop:
        lda     a:_bc_i
        cmp     a:battle_atk_count
        bcs     @enable

        RW a16
        and     #$0003
        tay
        RW a8
        lda     a:battle_atk_targets, y
        jsr     _bc_npc_offset
        lda     f:npc_table + NPC_OFF_COL, x
        sta     a:gmap_arg_col
        lda     f:npc_table + NPC_OFF_ROW, x
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        bcs     @next

        lda     a:_bc_i
        cmp     a:battle_atk_sel
        beq     @is_cur
        lda     #GSU_HIGHLIGHT_ATTACK
        bra     @store
@is_cur:
        lda     #GSU_HIGHLIGHT_CURSOR
@store:
        sta     f:battle_hl_grid, x
@next:
        inc     a:_bc_i
        bra     @loop

@enable:
        lda     #$01
        sta     a:battle_hl_enabled
        plp
        rts

; ------------------------------------------------------------------------------
; battle_attack_select_enter / battle_attack_select_tick
; Cycles valid adjacent enemy targets with D-pad, B cancels, A confirms attack.
; ------------------------------------------------------------------------------
battle_attack_select_enter:
        php
        RW_forced a8i16
        jsr     battle_find_attack_targets
        lda     a:battle_atk_count
        bne     @has_targets
        lda     #STATE_BATTLE_PLAYER_MENU
        jsr     game_state_enter
        plp
        rts
@has_targets:
        stz     a:battle_atk_sel
        jsr     _bc_paint_attack_highlights
        plp
        rts

battle_attack_select_tick:
        php
        RW_forced a8i16
        jsr     explore_update_camera_follow

        ; B -> cancel back to menu
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_B
        beq     @check_a
        jsr     battle_highlights_clear
        lda     #STATE_BATTLE_PLAYER_MENU
        jsr     game_state_enter
        brl     @done

        ; A -> confirm attack on selected target
@check_a:
        lda     z:SFX_joy1trig
        bit     #<JOY_A
        beq     @check_cycle
        jsr     battle_highlights_clear
        lda     #STATE_BATTLE_ACTION_ANIM
        jsr     game_state_enter
        brl     @done

        ; D-pad cycles targets if > 1
@check_cycle:
        lda     a:battle_atk_count
        cmp     #$02
        bcc     @done

        lda     z:SFX_joy1trig + 1
        bit     #(>JOY_UP | >JOY_LEFT)
        bne     @prev_target
        bit     #(>JOY_DOWN | >JOY_RIGHT)
        bne     @next_target
        bra     @done

@prev_target:
        lda     a:battle_atk_sel
        bne     :+
        lda     a:battle_atk_count
:       dec
        sta     a:battle_atk_sel
        jsr     _bc_paint_attack_highlights
        bra     @done

@next_target:
        lda     a:battle_atk_sel
        inc
        cmp     a:battle_atk_count
        bcc     :+
        lda     #$00
:       sta     a:battle_atk_sel
        jsr     _bc_paint_attack_highlights

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_action_anim_enter / battle_action_anim_tick
; Plays hero attack pose (frame 2) for 18 frames, applies damage & OAM popup,
; logs "HERO HITS FOR X!", checks enemy defeat, then returns to menu (if MP > 0)
; or advances turn.
; ------------------------------------------------------------------------------
battle_action_anim_enter:
        php
        RW_forced a8i16

        lda     #BATTLE_ATK_ANIM_FRAMES
        sta     a:battle_anim_timer
        lda     #$02                    ; Hero attack pose
        sta     a:player_sprite_id

        ; Resolve target NPC index
        RW a16
        lda     a:battle_atk_sel
        and     #$0003
        tay
        RW a8
        lda     a:battle_atk_targets, y
        sta     a:_bc_i                 ; target NPC index (0..3)

        ; Snapshot entity_out slot BEFORE potentially zeroing HP
        jsr     battle_find_npc_entity_slot
        sta     a:_bc_slot

        ; Compute dmg = max(1, player_atk - npc.def)
        lda     a:_bc_i
        jsr     _bc_npc_offset
        stx     a:_bc_off
        lda     a:player_atk
        sec
        sbc     f:npc_table + NPC_OFF_DEF, x
        bcc     @min_dmg
        bne     @chk_def
@min_dmg:
        lda     #$01
@chk_def:
        sta     a:_bc_dmg

        ; Halve damage (min 1) if target NPC is defending
        RW a16
        lda     a:_bc_i
        and     #$0003
        tay
        RW a8
        lda     a:battle_npc_defending, y
        beq     @apply_dmg
        lda     a:_bc_dmg
        lsr
        bne     :+
        lda     #$01
:       sta     a:_bc_dmg

@apply_dmg:
        ldx     a:_bc_off
        lda     f:npc_table + NPC_OFF_HP, x
        sec
        sbc     a:_bc_dmg
        bcs     :+
        lda     #$00
:       sta     f:npc_table + NPC_OFF_HP, x

        ; If HP == 0, mark NPC inactive (permanently defeated)
        bne     @spawn_fx
        lda     #$00
        sta     f:npc_table + NPC_OFF_ACTIVE, x

@spawn_fx:
        ; Spawn floating OAM damage popup at target's projected (sx, sy)
        RW a16
        lda     a:_bc_slot
        and     #$0007
        tay
        RW a8
        lda     a:_bc_dmg
        jsr     battle_spawn_slot_popup

        ; Format & log "HERO HITS FOR X!"
        ldy     #$0000
        lda     a:_bc_dmg
        jsr     battle_format_hit_msg
        UI_SET_MESSAGE str_hero_hit_buf

        lda     #$01
        sta     a:battle_action_used

        plp
        rts

battle_action_anim_tick:
        php
        RW_forced a8i16
        jsr     explore_update_camera_follow

        lda     a:battle_anim_timer
        beq     @anim_done
        dec
        sta     a:battle_anim_timer
        bne     @done

@anim_done:
        stz     a:player_sprite_id

        ; Check Victory first
        jsr     battle_check_any_enemy_alive
        bcs     @check_mp
        jsr     battle_highlights_clear
        lda     #STATE_VICTORY_BANNER
        jsr     game_state_enter
        bra     @done

        ; Splittable movement: if player_mp > 0, return to menu!
@check_mp:
        lda     a:player_mp
        beq     @end_turn
        lda     #STATE_BATTLE_PLAYER_MENU
        jsr     game_state_enter
        bra     @done

@end_turn:
        jsr     battle_advance_turn

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_victory_tick
; Shows "VICTORY!" banner for 60 frames (or skips on A/START), restores MP,
; clears battle mask/highlights, and returns to `STATE_EXPLORE`.
; ------------------------------------------------------------------------------
battle_victory_tick:
        php
        RW_forced a8i16
        lda     z:SFX_joy1trig
        bit     #<JOY_A
        bne     @finish_victory
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_START
        bne     @finish_victory
        RW a16
        lda     a:state_timer
        cmp     #BATTLE_VICTORY_FRAMES
        RW a8
        bcc     @done

@finish_victory:
        jsr     battle_highlights_clear
        stz     a:battle_enemy_mask
        lda     #$FF
        sta     a:battle_enemy_idx
        stz     a:player_defending
        lda     a:player_max_mp
        sta     a:player_mp
        sta     a:status_mp_cur
        lda     a:player_hp
        sta     a:status_hp_cur
        lda     #$01
        sta     a:status_bar_dirty
        jsr     game_state_refresh_explore_stats
        lda     #STATE_EXPLORE
        jsr     game_state_enter

@done:
        plp
        rts

.endif ; __ISORPG_BATTLE_CORE__
