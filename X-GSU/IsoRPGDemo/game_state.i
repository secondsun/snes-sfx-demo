; ==============================================================================
; game_state.i - Top-Level Game State Machine, Focus Transitions & Title/GameOver
;
; Part of IsoRPGDemo (Epic #30 / Issue #38).
; All runtime routines & UI strings reside in `MAIN_LOOP` (WRAM / LORAM) so they
; execute safely at 60fps while the SuperFX GSU owns the ROM/RAM buses.
; ==============================================================================

.ifndef __ISORPG_GAME_STATE__
__ISORPG_GAME_STATE__ = 1

; ------------------------------------------------------------------------------
; Top-Level Game States
; ------------------------------------------------------------------------------
STATE_TITLE                 = 0
STATE_EXPLORE               = 1
STATE_EXPLORE_MENU          = 2
STATE_BATTLE_INTRO          = 3
STATE_BATTLE_PLAYER_MENU    = 4
STATE_BATTLE_MOVE_SELECT    = 5
STATE_BATTLE_MOVE_ANIM      = 6
STATE_BATTLE_ATTACK_SELECT  = 7
STATE_BATTLE_ACTION_ANIM    = 8
STATE_BATTLE_ENEMY_TURN     = 9
STATE_VICTORY_BANNER        = 10
STATE_GAME_OVER             = 11
STATE_DEMO_CLEAR            = 12

; ------------------------------------------------------------------------------
; Input Focus Targets
; ------------------------------------------------------------------------------
FOCUS_ISOMAP                = 0
FOCUS_SIDE_MENU             = 1

; ------------------------------------------------------------------------------
; LORAM State Variables
; ------------------------------------------------------------------------------
.segment "LORAM"
game_state:                 .res 1  ; Current STATE_*
game_prev_state:            .res 1  ; Previous STATE_*
ui_focus:                   .res 1  ; FOCUS_ISOMAP (0) or FOCUS_SIDE_MENU (1)
gsu_render_enabled:         .res 1  ; 0 = paused (Title/Game Over), 1 = active 3D
pending_level_load:         .res 1  ; Non-zero => MAIN_LOOP stages Bank $71 & starts GSU
state_timer:                .res 2  ; Frame counter reset on every state transition
_gs_menu_mode:              .res 1  ; 0 = none, 1 = explore menu, 2 = battle menu
boot_auto_start:            .res 1  ; Test hook (0 on real boot; non-zero auto-starts from Title)
_gs_fmt_tens:               .res 1  ; Scratch for 2-digit decimal formatter

; Live WRAM-formatted Exploration Side Menu stat strings (6 chars + NUL)
str_stat_hp:                .res 7  ; "HP  20\0"
str_stat_atk:               .res 7  ; "ATK  8\0"
str_stat_def:               .res 7  ; "DEF  4\0"
str_stat_secr:              .res 7  ; "SECR 0\0"

.export game_state, game_prev_state, ui_focus, gsu_render_enabled, pending_level_load
.export boot_auto_start
.export str_stat_hp, str_stat_atk, str_stat_def, str_stat_secr

; ------------------------------------------------------------------------------
; WRAM-Resident Strings & Code (`MAIN_LOOP` -> LORAM, 100% GSU-bus-safe)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

; Title Screen & Game Over strings
str_title_name:             .asciiz "ISO RPG DEMO"
str_title_sub:              .asciiz "SUPERFX TACTICAL RPG"
str_title_prompt:           .asciiz "PRESS START"
str_title_hint:             .asciiz "L/R:ROTATE  SEL:MENU"

str_gameover_title:         .asciiz "GAME OVER"
str_gameover_sub:           .asciiz "YOUR PARTY HAS FALLEN"
str_gameover_prompt:        .asciiz "PRESS START TO RETRY"

; Explore Side Menu & Status strings
str_menu_explore_title:     .asciiz "STATS"
str_item_resume:            .asciiz "RESUME"

; Battle Side Menu & Status strings
str_menu_battle_title:      .asciiz "BATTLE"
str_item_move:              .asciiz "MOVE"
str_item_attack:            .asciiz "ATTACK"
str_item_defend:            .asciiz "DEFEND"
str_item_flee:              .asciiz "FLEE"
str_item_wait:              .asciiz "WAIT"

; Status Bar Headers (<= 11 chars)
str_hdr_explore:            .asciiz "EXPLORE"
str_hdr_menu:               .asciiz "MENU"
str_hdr_battle:             .asciiz "BATTLE!"
str_hdr_your_turn:          .asciiz "YOUR TURN"
str_hdr_move:               .asciiz "MOVE"
str_hdr_attack:             .asciiz "ATTACK"
str_hdr_enemy:              .asciiz "ENEMY TURN"
str_hdr_victory:            .asciiz "VICTORY!"

; Status Bar Messages (<= 30 chars)
str_msg_explore_1:          .asciiz "FORT ZEAKDEN - COURTYARD"
str_msg_explore_2:          .asciiz "L/R:ROTATE  SEL:SIDE MENU"
str_msg_menu_open:          .asciiz "D-PAD:SELECT A:OK B/SEL:BACK"
str_msg_status_ok:          .asciiz "KNIGHT LV.1  ATK:8 DEF:4"
str_msg_items_none:         .asciiz "NO ITEMS IN PACK."
str_msg_equip_ok:           .asciiz "EQUIP: IRON SWORD, SHIELD"
str_msg_camp_ok:            .asciiz "RESTED. HP/MP RESTORED!"
str_msg_battle_intro:       .asciiz "ENEMIES BLOCK THE PATH!"
str_msg_select_move:        .asciiz "CHOOSE DESTINATION TILE."
str_msg_select_atk:         .asciiz "CHOOSE TARGET TO ATTACK."
str_msg_enemy_turn:         .asciiz "ENEMY IS THINKING..."
str_msg_victory:            .asciiz "ALL ENEMIES DEFEATED!"

; Demo Clear / Final Victory Screen strings
str_clear_title:            .asciiz "VICTORY!"
str_clear_sub1:             .asciiz "ALL FOES DEFEATED!"
str_clear_sub2:             .asciiz "SECRET TREASURE FOUND!"
str_clear_prompt:           .asciiz "PRESS START TO REPLAY"

; ------------------------------------------------------------------------------
; game_state_init
; Initializes state machine variables and enters STATE_TITLE.
; ------------------------------------------------------------------------------
game_state_init:
        php
        RW_forced a8i16
        stz     a:game_state
        stz     a:game_prev_state
        stz     a:ui_focus
        stz     a:gsu_render_enabled
        stz     a:pending_level_load
        stz     a:_gs_menu_mode
        stz     a:state_timer
        stz     a:state_timer + 1
        jsr     battle_highlights_clear
        lda     #STATE_TITLE
        jsr     game_state_enter
        plp
        rts

; ------------------------------------------------------------------------------
; game_state_is_active_world
; Out: Carry Set if game_state is an active 3D gameplay state (not Title/GameOver).
; ------------------------------------------------------------------------------
game_state_is_active_world:
        RW_forced a8i16
        lda     a:game_state
        cmp     #STATE_TITLE
        beq     @inactive
        cmp     #STATE_GAME_OVER
        beq     @inactive
        cmp     #STATE_DEMO_CLEAR
        beq     @inactive
        sec
        rts
@inactive:
        clc
        rts

; ------------------------------------------------------------------------------
; game_state_is_battle
; Out: Carry Set if game_state is in battle (STATE_BATTLE_INTRO..STATE_VICTORY_BANNER).
; ------------------------------------------------------------------------------
game_state_is_battle:
        RW_forced a8i16
        lda     a:game_state
        cmp     #STATE_BATTLE_INTRO
        bcc     @not_battle
        cmp     #(STATE_VICTORY_BANNER + 1)
        bcs     @not_battle
        sec
        rts
@not_battle:
        clc
        rts

; ------------------------------------------------------------------------------
; _gs_fmt_u8_2d (Internal)
; Formats unsigned byte A (0..99) into 2 ASCII chars (leading space if < 10)
; at `a:0, x` and `a:1, x` in LORAM.
; ------------------------------------------------------------------------------
_gs_fmt_u8_2d:
        RW_forced a8i16
        cmp     #100
        bcc     :+
        lda     #99
:       stz     a:_gs_fmt_tens
@div10:
        cmp     #10
        bcc     @div_done
        sec
        sbc     #10
        inc     a:_gs_fmt_tens
        bra     @div10
@div_done:
        clc
        adc     #'0'
        sta     a:$0001, x
        lda     a:_gs_fmt_tens
        beq     @lead_sp
        clc
        adc     #'0'
        bra     @store_tens
@lead_sp:
        lda     #' '
@store_tens:
        sta     a:$0000, x
        rts

; ------------------------------------------------------------------------------
; game_state_refresh_explore_stats
; Formats live Player HP/ATK/DEF/SECR into LORAM Side Menu strings and marks
; `side_menu_dirty = 1`.
; ------------------------------------------------------------------------------
game_state_refresh_explore_stats:
        php
        RW_forced a8i16

        ; "HP  xx"
        lda     #'H'
        sta     a:str_stat_hp + 0
        lda     #'P'
        sta     a:str_stat_hp + 1
        lda     #' '
        sta     a:str_stat_hp + 2
        sta     a:str_stat_hp + 3
        ldx     #.loword(str_stat_hp + 4)
        lda     a:player_hp
        jsr     _gs_fmt_u8_2d
        stz     a:str_stat_hp + 6

        ; "ATK xx"
        lda     #'A'
        sta     a:str_stat_atk + 0
        lda     #'T'
        sta     a:str_stat_atk + 1
        lda     #'K'
        sta     a:str_stat_atk + 2
        lda     #' '
        sta     a:str_stat_atk + 3
        ldx     #.loword(str_stat_atk + 4)
        lda     a:player_atk
        jsr     _gs_fmt_u8_2d
        stz     a:str_stat_atk + 6

        ; "DEF xx"
        lda     #'D'
        sta     a:str_stat_def + 0
        lda     #'E'
        sta     a:str_stat_def + 1
        lda     #'F'
        sta     a:str_stat_def + 2
        lda     #' '
        sta     a:str_stat_def + 3
        ldx     #.loword(str_stat_def + 4)
        lda     a:player_def
        jsr     _gs_fmt_u8_2d
        stz     a:str_stat_def + 6

        ; "SECR x" (single digit or 2-digit if >= 10)
        lda     #'S'
        sta     a:str_stat_secr + 0
        lda     #'E'
        sta     a:str_stat_secr + 1
        lda     #'C'
        sta     a:str_stat_secr + 2
        lda     #'R'
        sta     a:str_stat_secr + 3
        ldx     #.loword(str_stat_secr + 4)
        lda     a:player_secrets_found
        jsr     _gs_fmt_u8_2d
        stz     a:str_stat_secr + 6

        lda     #$01
        sta     a:side_menu_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; _gs_setup_explore_menu (Internal)
; Populates Side Menu with live Player stats (HP/ATK/DEF/SECR) + RESUME.
; ------------------------------------------------------------------------------
_gs_setup_explore_menu:
        RW_forced a8i16
        jsr     game_state_refresh_explore_stats
        lda     a:_gs_menu_mode
        cmp     #$01
        beq     @already_set
        lda     #$01
        sta     a:_gs_menu_mode
        jsr     side_menu_init
        SIDE_MENU_SET_TITLE str_menu_explore_title
        SIDE_MENU_SET_ITEM 0, str_stat_hp
        SIDE_MENU_SET_ITEM 1, str_stat_atk
        SIDE_MENU_SET_ITEM 2, str_stat_def
        SIDE_MENU_SET_ITEM 3, str_stat_secr
        SIDE_MENU_SET_ITEM 4, str_item_resume
        lda     #$1F
        jsr     side_menu_set_enabled
        lda     #$04                    ; Default cursor on RESUME
        sta     a:side_menu_selected
@already_set:
        rts

; ------------------------------------------------------------------------------
; _gs_setup_battle_menu (Internal)
; Populates Side Menu with 5 Battle commands (MOVE, ATTACK, DEFEND, FLEE, WAIT)
; if not already active.
; ------------------------------------------------------------------------------
_gs_setup_battle_menu:
        RW_forced a8i16
        lda     a:_gs_menu_mode
        cmp     #$02
        beq     @already_set
        lda     #$02
        sta     a:_gs_menu_mode
        jsr     side_menu_init
        SIDE_MENU_SET_TITLE str_menu_battle_title
        SIDE_MENU_SET_ITEM 0, str_item_move
        SIDE_MENU_SET_ITEM 1, str_item_attack
        SIDE_MENU_SET_ITEM 2, str_item_defend
        SIDE_MENU_SET_ITEM 3, str_item_flee
        SIDE_MENU_SET_ITEM 4, str_item_wait
        lda     #$1F
        jsr     side_menu_set_enabled
@already_set:
        rts

; ------------------------------------------------------------------------------
; _gs_draw_title_screen (Internal)
; Draws the centered BG3 Title Screen (`ISO RPG DEMO` + `PRESS START`).
; ------------------------------------------------------------------------------
_gs_draw_title_screen:
        RW_forced a8i16
        jsr     bg3_ui_init
        UI_DRAW_BOX   4, 5, 24, 15, UI_PAL_ACTIVE
        UI_PRINT_STR  10, 8,  str_title_name,   UI_PAL_ALERT
        UI_PRINT_STR  6,  10, str_title_sub,    UI_PAL_ACTIVE
        UI_PRINT_STR  10, 14, str_title_prompt, UI_PAL_ALERT
        UI_PRINT_STR  6,  17, str_title_hint,   UI_PAL_DISABLED
        rts

; ------------------------------------------------------------------------------
; _gs_draw_game_over_screen (Internal)
; Draws the centered BG3 Game Over screen (`PRESS START TO RETRY`).
; ------------------------------------------------------------------------------
_gs_draw_game_over_screen:
        RW_forced a8i16
        jsr     bg3_ui_init
        UI_DRAW_BOX   4, 6, 24, 13, UI_PAL_ALERT
        UI_PRINT_STR  11, 9,  str_gameover_title,  UI_PAL_ALERT
        UI_PRINT_STR  5,  11, str_gameover_sub,    UI_PAL_ACTIVE
        UI_PRINT_STR  6,  15, str_gameover_prompt, UI_PAL_ALERT
        rts

; ------------------------------------------------------------------------------
; _gs_draw_demo_clear_screen (Internal)
; Draws the centered BG3 Demo Clear / Stage Victory screen (`PRESS START TO REPLAY`).
; ------------------------------------------------------------------------------
_gs_draw_demo_clear_screen:
        RW_forced a8i16
        jsr     bg3_ui_init
        UI_DRAW_BOX   3, 5, 26, 15, UI_PAL_ALERT
        UI_PRINT_STR  12, 8,  str_clear_title,  UI_PAL_ALERT
        UI_PRINT_STR  7,  11, str_clear_sub1,   UI_PAL_ACTIVE
        UI_PRINT_STR  5,  13, str_clear_sub2,   UI_PAL_ACTIVE
        UI_PRINT_STR  5,  16, str_clear_prompt, UI_PAL_ALERT
        rts

; ------------------------------------------------------------------------------
; game_state_check_demo_clear
; Checks overall demo win condition: all NPCs defeated AND all secrets found.
; Transitions to STATE_DEMO_CLEAR when satisfied.
; ------------------------------------------------------------------------------
game_state_check_demo_clear:
        php
        RW_forced a8i16
        ; Must have loaded at least 1 NPC and found all interactables/secrets
        lda     a:gmap_npc_count
        beq     @not_clear
        lda     a:player_secrets_found
        cmp     a:gmap_interact_count
        bcc     @not_clear

        ; Verify every NPC in npc_table[0..gmap_npc_count-1] is defeated (ACTIVE==0 || HP==0)
        stz     a:_gs_fmt_tens          ; loop index i
        ldx     #$0000
@chk_npc:
        lda     a:_gs_fmt_tens
        cmp     a:gmap_npc_count
        bcs     @all_clear
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @next_npc
        lda     f:npc_table + NPC_OFF_HP, x
        bne     @not_clear              ; Still alive!
@next_npc:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        inc     a:_gs_fmt_tens
        bra     @chk_npc

@all_clear:
        lda     #STATE_DEMO_CLEAR
        jsr     game_state_enter
@not_clear:
        plp
        rts

; ------------------------------------------------------------------------------
; game_state_enter
; Transitions to state A (0..11), automatically updating `ui_focus`,
; `side_menu_focused`, and refreshing BG3 windows.
; In: A (8-bit) = target STATE_*
; ------------------------------------------------------------------------------
game_state_enter:
        php
        RW_forced a8i16
        pha
        lda     a:game_state
        sta     a:game_prev_state
        pla
        sta     a:game_state
        stz     a:state_timer
        stz     a:state_timer + 1

        ; Dispatch state entry handler
        cmp     #STATE_TITLE
        bne     :+
        brl     @enter_title
:       cmp     #STATE_EXPLORE
        bne     :+
        brl     @enter_explore
:       cmp     #STATE_EXPLORE_MENU
        bne     :+
        brl     @enter_explore_menu
:       cmp     #STATE_BATTLE_INTRO
        bne     :+
        brl     @enter_battle_intro
:       cmp     #STATE_BATTLE_PLAYER_MENU
        bne     :+
        brl     @enter_battle_player_menu
:       cmp     #STATE_BATTLE_MOVE_SELECT
        bne     :+
        brl     @enter_battle_move_select
:       cmp     #STATE_BATTLE_MOVE_ANIM
        bne     :+
        brl     @enter_battle_move_anim
:       cmp     #STATE_BATTLE_ATTACK_SELECT
        bne     :+
        brl     @enter_battle_attack_select
:       cmp     #STATE_BATTLE_ACTION_ANIM
        bne     :+
        brl     @enter_battle_action_anim
:       cmp     #STATE_BATTLE_ENEMY_TURN
        bne     :+
        brl     @enter_battle_enemy_turn
:       cmp     #STATE_VICTORY_BANNER
        bne     :+
        brl     @enter_victory_banner
:       cmp     #STATE_DEMO_CLEAR
        bne     :+
        brl     @enter_demo_clear
:       brl     @enter_game_over

@enter_title:
        stz     a:ui_focus
        stz     a:gsu_render_enabled
        stz     a:_gs_menu_mode
        jsr     _gs_draw_title_screen
        brl     @done

@enter_explore:
        stz     a:ui_focus
        UI_CLEAR_RECT 0, 0, 24, 20      ; Expose 192x160 BG1 3D viewport
        jsr     _gs_setup_explore_menu
        lda     #$00
        jsr     side_menu_set_focused
        lda     #$01
        sta     a:side_menu_dirty
        STATUS_SET_HEADER str_hdr_explore, UI_PAL_ACTIVE
        ; Populate welcome log if transitioning from Title/GameOver
        lda     a:game_prev_state
        cmp     #STATE_TITLE
        beq     @explore_welcome
        cmp     #STATE_GAME_OVER
        bne     @explore_redraw
@explore_welcome:
        UI_SET_MESSAGE str_msg_explore_1
        UI_SET_MESSAGE str_msg_explore_2
@explore_redraw:
        lda     #$01
        sta     a:status_bar_dirty
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_explore_menu:
        lda     #FOCUS_SIDE_MENU
        sta     a:ui_focus
        jsr     _gs_setup_explore_menu
        lda     #$01
        jsr     side_menu_set_focused
        STATUS_SET_HEADER str_hdr_menu, UI_PAL_ALERT
        UI_SET_MESSAGE str_msg_menu_open
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_battle_intro:
        stz     a:ui_focus
        UI_CLEAR_RECT 0, 0, 24, 20
        jsr     _gs_setup_battle_menu
        jsr     battle_init_encounter
        lda     #$00
        jsr     side_menu_set_focused
        lda     #$01
        sta     a:side_menu_dirty
        STATUS_SET_HEADER str_hdr_battle, UI_PAL_ALERT
        UI_SET_MESSAGE str_msg_battle_intro
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_battle_player_menu:
        lda     #FOCUS_SIDE_MENU
        sta     a:ui_focus
        jsr     _gs_setup_battle_menu
        jsr     battle_refresh_menu_enabled
        lda     #$01
        jsr     side_menu_set_focused
        STATUS_SET_HEADER str_hdr_your_turn, UI_PAL_ACTIVE
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_battle_move_select:
        stz     a:ui_focus
        lda     #$00
        jsr     side_menu_set_focused
        jsr     battle_move_select_enter
        STATUS_SET_HEADER str_hdr_move, UI_PAL_ALERT
        UI_SET_MESSAGE str_msg_select_move
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_battle_move_anim:
        stz     a:ui_focus
        lda     #$00
        jsr     side_menu_set_focused
        jsr     battle_move_anim_enter
        jsr     side_menu_draw
        brl     @done

@enter_battle_attack_select:
        stz     a:ui_focus
        lda     #$00
        jsr     side_menu_set_focused
        jsr     battle_attack_select_enter
        STATUS_SET_HEADER str_hdr_attack, UI_PAL_ALERT
        UI_SET_MESSAGE str_msg_select_atk
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_battle_action_anim:
        stz     a:ui_focus
        lda     #$00
        jsr     side_menu_set_focused
        jsr     battle_action_anim_enter
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_battle_enemy_turn:
        stz     a:ui_focus
        lda     #$00
        jsr     side_menu_set_focused
        STATUS_SET_HEADER str_hdr_enemy, UI_PAL_ALERT
        UI_SET_MESSAGE str_msg_enemy_turn
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_victory_banner:
        stz     a:ui_focus
        jsr     battle_highlights_clear
        lda     #$00
        jsr     side_menu_set_focused
        STATUS_SET_HEADER str_hdr_victory, UI_PAL_ALERT
        UI_SET_MESSAGE str_msg_victory
        jsr     side_menu_draw
        jsr     status_bar_draw
        brl     @done

@enter_game_over:
        stz     a:ui_focus
        stz     a:gsu_render_enabled
        stz     a:_gs_menu_mode
        stz     a:side_menu_dirty
        stz     a:status_bar_dirty
        jsr     battle_highlights_clear
        jsr     oam_mgr_init
        jsr     _gs_draw_game_over_screen
        brl     @done

@enter_demo_clear:
        stz     a:ui_focus
        stz     a:gsu_render_enabled
        stz     a:_gs_menu_mode
        stz     a:side_menu_dirty
        stz     a:status_bar_dirty
        jsr     battle_highlights_clear
        jsr     oam_mgr_init
        jsr     _gs_draw_demo_clear_screen

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; game_state_tick
; Called once per 60fps logic tick after `input_router_tick`.
; ------------------------------------------------------------------------------
game_state_tick:
        php
        RW_forced a8i16

        ; Increment 16-bit state timer
        RW a16
        inc     a:state_timer
        RW a8

        lda     a:game_state
        cmp     #STATE_TITLE
        beq     @tick_title
        cmp     #STATE_GAME_OVER
        bne     :+
        brl     @tick_game_over
:       cmp     #STATE_DEMO_CLEAR
        bne     :+
        brl     @tick_game_over
:       cmp     #STATE_EXPLORE
        beq     @tick_explore
        cmp     #STATE_EXPLORE_MENU
        bne     :+
        brl     @tick_explore_menu
:       cmp     #STATE_BATTLE_INTRO
        bne     :+
        brl     @tick_battle_intro
:       cmp     #STATE_BATTLE_PLAYER_MENU
        bne     :+
        brl     @tick_battle_player_menu
:       cmp     #STATE_BATTLE_MOVE_SELECT
        bne     :+
        brl     @tick_battle_move_select
:       cmp     #STATE_BATTLE_MOVE_ANIM
        bne     :+
        brl     @tick_battle_move_anim
:       cmp     #STATE_BATTLE_ATTACK_SELECT
        bne     :+
        brl     @tick_battle_attack_select
:       cmp     #STATE_BATTLE_ACTION_ANIM
        bne     :+
        brl     @tick_battle_action_anim
:       cmp     #STATE_BATTLE_ENEMY_TURN
        bne     :+
        brl     @tick_battle_enemy_turn
:       cmp     #STATE_VICTORY_BANNER
        bne     :+
        brl     @tick_victory_banner
:       brl     @redraw_hud

@tick_explore:
        jsr     explore_move_tick
        jsr     interactables_check_action
        jsr     npc_explore_ai_tick
        lda     a:game_state
        cmp     #STATE_EXPLORE
        beq     :+
        brl     @redraw_hud
:       jsr     game_state_check_demo_clear
        lda     a:game_state
        cmp     #STATE_DEMO_CLEAR
        beq     :+
        brl     @redraw_hud
:       brl     @done

@tick_title:
        ; Press START (or headless test hook boot_auto_start) to stage level & enter STATE_EXPLORE
        lda     a:boot_auto_start
        bne     @do_start_game
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_START
        bne     @do_start_game
        brl     @done
@do_start_game:
        stz     a:boot_auto_start
        jsr     status_bar_init
        jsr     input_router_init
        lda     #$01
        sta     a:pending_level_load
        lda     #STATE_EXPLORE
        jsr     game_state_enter
        brl     @done

@tick_game_over:
        ; Press START to reset gameplay state and retry
        lda     z:SFX_joy1trig + 1
        bit     #>JOY_START
        bne     :+
        brl     @done
:       jsr     status_bar_init
        jsr     input_router_init
        lda     #$01
        sta     a:pending_level_load
        lda     #STATE_EXPLORE
        jsr     game_state_enter
        brl     @done

@tick_explore_menu:
        jsr     side_menu_update_joy1
        cmp     #SIDE_MENU_NONE
        bne     :+
        brl     @redraw_hud
:       cmp     #SIDE_MENU_CANCEL
        bne     @explore_menu_confirm
        lda     #STATE_EXPLORE
        jsr     game_state_enter
        brl     @redraw_hud

@explore_menu_confirm:
        cmp     #$04                    ; Item 4 = RESUME
        bne     :+
        lda     #STATE_EXPLORE
        jsr     game_state_enter
        bra     @redraw_hud
:       UI_SET_MESSAGE str_msg_status_ok
        bra     @redraw_hud

@tick_battle_intro:
        jsr     battle_intro_tick
        bra     @redraw_hud

@tick_battle_player_menu:
        jsr     battle_player_menu_tick
        bra     @redraw_hud

@tick_battle_move_select:
        jsr     battle_move_select_tick
        bra     @redraw_hud

@tick_battle_move_anim:
        jsr     battle_move_anim_tick
        bra     @redraw_hud

@tick_battle_attack_select:
        jsr     battle_attack_select_tick
        bra     @redraw_hud

@tick_battle_action_anim:
        jsr     battle_action_anim_tick
        bra     @redraw_hud

@tick_battle_enemy_turn:
        jsr     npc_battle_ai_tick
        bra     @redraw_hud

@tick_victory_banner:
        jsr     battle_victory_tick

@redraw_hud:
        jsr     side_menu_draw
        jsr     status_bar_draw

@done:
        plp
        rts

.endif ; __ISORPG_GAME_STATE__
