; ==============================================================================
; level_loader.i - `.gmap` Gameplay Loader, WRAM Entity Tables & Cell Queries
;
; Part of IsoRPGDemo (Epic #30 / Issue #39).
; Responsibilities:
;   1. Defines `.gmap` binary format constants (matching `GameplayLayer.kt`) and
;      runtime WRAM tables for Map walkability/heights, Player, NPCs (max 4),
;      and Interactables (max 4).
;   2. `level_loader_load` (in `CODE`/ROM0, called during boot/level staging
;      while GSU is stopped) parses `.gmap` and `.map` `base_height` into WRAM
;      so the 65816 never touches ROM or Bank $71 while GSU is running.
;   3. WRAM-resident (`MAIN_LOOP`) helpers: `gmap_cell_index` and
;      `gmap_is_cell_passable` (shared by Exploration Mode #39 and Battle #40).
; ==============================================================================

.ifndef __ISORPG_LEVEL_LOADER__
__ISORPG_LEVEL_LOADER__ = 1

; ------------------------------------------------------------------------------
; `.gmap` Binary Format Constants (guard matches GameplayHeaderGenerator)
; ------------------------------------------------------------------------------
.ifndef ::__GMAP_FORMAT_CONSTANTS_DEFINED__
::__GMAP_FORMAT_CONSTANTS_DEFINED__ = 1

GMAP_MAGIC                          = $4D47
GMAP_VERSION                        = 1
GMAP_HEADER_SIZE                    = 16
GMAP_NPC_RECORD_SIZE                = 20
GMAP_INTERACTABLE_RECORD_SIZE       = 8
GMAP_MAX_WAYPOINTS                  = 4
GMAP_UNUSED_WAYPOINT                = $FF

; Walkability byte bitfields
GMAP_WALK_FLAG_WALKABLE             = $01
GMAP_WALK_COST_MASK                 = $0E
GMAP_WALK_COST_SHIFT                = 1
GMAP_WALK_EXTRA_MASK                = $F0
GMAP_WALK_EXTRA_SHIFT               = 4

; Cardinal facing enum
GMAP_FACING_NORTH                   = 0
GMAP_FACING_EAST                    = 1
GMAP_FACING_SOUTH                   = 2
GMAP_FACING_WEST                    = 3

; NPC AI enum
GMAP_AI_GUARD                       = 0
GMAP_AI_PATROL                      = 1

; Interactable & Reward enums
GMAP_INTERACT_CHEST                 = 0
GMAP_INTERACT_SWITCH                = 1
GMAP_INTERACT_SIGN                  = 2
GMAP_REWARD_NONE                    = 0
GMAP_REWARD_ATK_BUFF                = 1
GMAP_REWARD_HP_HEAL                 = 2

; Header struct offsets (16 bytes)
GMAP_HDR_OFF_MAGIC                  = 0
GMAP_HDR_OFF_VERSION                = 2
GMAP_HDR_OFF_COLS                   = 3
GMAP_HDR_OFF_ROWS                   = 4
GMAP_HDR_OFF_PLAYER_COL             = 5
GMAP_HDR_OFF_PLAYER_ROW             = 6
GMAP_HDR_OFF_PLAYER_FACING          = 7
GMAP_HDR_OFF_NPC_COUNT              = 8
GMAP_HDR_OFF_INTERACTABLE_COUNT     = 9
GMAP_HDR_OFF_WALK_GRID_OFFSET       = 10
GMAP_HDR_OFF_NPC_TABLE_OFFSET       = 12
GMAP_HDR_OFF_INTERACTABLE_TABLE_OFFSET = 14

; NPC record struct offsets (20 bytes)
GMAP_NPC_OFF_COL                    = 0
GMAP_NPC_OFF_ROW                    = 1
GMAP_NPC_OFF_SPRITE_ID              = 2
GMAP_NPC_OFF_AI_TYPE                = 3
GMAP_NPC_OFF_AGGRO_RANGE            = 4
GMAP_NPC_OFF_HP                     = 5
GMAP_NPC_OFF_ATK                    = 6
GMAP_NPC_OFF_DEF                    = 7
GMAP_NPC_OFF_SPEED                  = 8
GMAP_NPC_OFF_MOVE_POINTS            = 9
GMAP_NPC_OFF_WAYPOINT_COUNT         = 10
GMAP_NPC_OFF_RESERVED               = 11
GMAP_NPC_OFF_WAYPOINTS              = 12

; Interactable record struct offsets (8 bytes)
GMAP_INTERACT_OFF_COL               = 0
GMAP_INTERACT_OFF_ROW               = 1
GMAP_INTERACT_OFF_KIND              = 2
GMAP_INTERACT_OFF_CLOSED_SPRITE_ID  = 3
GMAP_INTERACT_OFF_OPEN_SPRITE_ID    = 4
GMAP_INTERACT_OFF_REWARD_KIND       = 5
GMAP_INTERACT_OFF_REWARD_VALUE      = 6
GMAP_INTERACT_OFF_MESSAGE_ID        = 7

.endif ; ::__GMAP_FORMAT_CONSTANTS_DEFINED__

; ------------------------------------------------------------------------------
; Runtime Capacity, Defaults & Struct Layouts
; ------------------------------------------------------------------------------
MAX_NPCS                            = 4
MAX_INTERACTABLES                   = 4
NPC_PATROL_PERIOD                   = 50      ; Frames between patrol steps

PLAYER_DEFAULT_HP                   = 20
PLAYER_DEFAULT_MP                   = 4
PLAYER_DEFAULT_ATK                  = 8
PLAYER_DEFAULT_DEF                  = 4
PLAYER_DEFAULT_SPEED                = 5

; Runtime NPC struct offsets (32 bytes per NPC, power-of-2 stride in HIRAM)
NPC_OFF_ACTIVE                      = 0     ; 1B: 0=inactive/dead, 1=alive
NPC_OFF_COL                         = 1     ; 1B: grid col
NPC_OFF_ROW                         = 2     ; 1B: grid row
NPC_OFF_SPRITE_ID                   = 3     ; 1B: sprite sheet ID
NPC_OFF_AI_TYPE                     = 4     ; 1B: GMAP_AI_GUARD / GMAP_AI_PATROL
NPC_OFF_AGGRO_RANGE                 = 5     ; 1B: Manhattan aggro radius
NPC_OFF_HP                          = 6     ; 1B: current HP
NPC_OFF_MAX_HP                      = 7     ; 1B: max HP
NPC_OFF_ATK                         = 8     ; 1B: attack stat
NPC_OFF_DEF                         = 9     ; 1B: defense stat
NPC_OFF_SPEED                       = 10    ; 1B: turn speed stat
NPC_OFF_MOVE_POINTS                 = 11    ; 1B: battle movement range
NPC_OFF_WP_COUNT                    = 12    ; 1B: patrol waypoint count (0..4)
NPC_OFF_WP_IDX                      = 13    ; 1B: active waypoint index (0..3)
NPC_OFF_PATROL_TIMER                = 14    ; 1B: countdown frames to next patrol step
NPC_OFF_MOVE_ANIM                   = 15    ; 1B: step interpolation frames (0..12)
NPC_OFF_WAYPOINTS                   = 16    ; 8B: 4 x (col, row) pairs
NPC_OFF_HFLIP                       = 24    ; 1B: horizontal flip flag
NPC_OFF_MOVE_DIR                    = 25    ; 1B: screen direction (0..3) of active step
NPC_OFF_SUB_X                       = 26    ; 2B: signed pixel X sub-cell offset
NPC_OFF_SUB_Y                       = 28    ; 2B: signed pixel Y sub-cell offset
NPC_OFF_FLAGS                       = 30    ; 1B: bit 0 = engaged in battle
NPC_OFF_RESERVED                    = 31    ; 1B: padding
NPC_STRUCT_SIZE                     = 32

; Runtime Interactable struct offsets (16 bytes per entry, power-of-2 in HIRAM)
INTERACT_OFF_ACTIVE                 = 0     ; 1B: 0=inactive, 1=active
INTERACT_OFF_OPENED                 = 1     ; 1B: 0=closed, 1=opened
INTERACT_OFF_COL                    = 2     ; 1B: grid col
INTERACT_OFF_ROW                    = 3     ; 1B: grid row
INTERACT_OFF_KIND                   = 4     ; 1B: GMAP_INTERACT_*
INTERACT_OFF_CLOSED_SPR             = 5     ; 1B: closed sprite/mask ID
INTERACT_OFF_OPEN_SPR               = 6     ; 1B: open sprite/mask ID
INTERACT_OFF_REWARD_KIND            = 7     ; 1B: GMAP_REWARD_*
INTERACT_OFF_REWARD_VAL             = 8     ; 1B: reward magnitude
INTERACT_OFF_MSG_ID                 = 9     ; 1B: discovery message table ID
INTERACT_STRUCT_SIZE                = 16

; ------------------------------------------------------------------------------
; Zero-Page 24-bit Loader Pointers
; ------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage
lvl_gmap_ptr:                       .res 3
lvl_map_ptr:                        .res 3

; ------------------------------------------------------------------------------
; LORAM Gameplay Scalars, Player State & Query Parameters
; ------------------------------------------------------------------------------
.segment "LORAM"
gmap_cols:                          .res 1
gmap_rows:                          .res 1
gmap_total_cells:                   .res 2
gmap_npc_count:                     .res 1
gmap_interact_count:                .res 1
gmap_is_mesh:                       .res 1  ; 0 = .map MapGrid, 1 = .mgrid Hybrid 3D Mesh

; Player state (shared by Exploration Mode #39 and Battle Mode #40)
player_col:                         .res 1
player_row:                         .res 1
player_facing:                      .res 1  ; 0=N, 1=E, 2=S, 3=W
player_hp:                          .res 1
player_max_hp:                      .res 1
player_atk:                         .res 1
player_def:                         .res 1
player_speed:                       .res 1
player_mp:                          .res 1
player_max_mp:                      .res 1
player_secrets_found:               .res 1
player_flee_grace_timer:            .res 1
player_move_anim_timer:             .res 1  ; 12..0 frames
player_move_from_col:               .res 1
player_move_from_row:               .res 1
player_move_screen_dir:             .res 1  ; 0=UP, 1=RIGHT, 2=DOWN, 3=LEFT
player_sprite_id:                   .res 1  ; 0 or 1 walk toggle
player_hflip:                       .res 1  ; 0 or 1
player_sub_x:                       .res 2  ; signed 16-bit pixel offset
player_sub_y:                       .res 2  ; signed 16-bit pixel offset

; Encounter handoff state (populated on aggro for #40 Battle Mode)
battle_enemy_idx:                   .res 1  ; Primary triggering NPC index ($FF = none)
battle_enemy_mask:                  .res 1  ; Bitmask of engaged NPCs (bits 0..3)

; Shared query parameters & scratch
gmap_arg_col:                       .res 1
gmap_arg_row:                       .res 1
gmap_arg_from_col:                  .res 1
gmap_arg_from_row:                  .res 1
gmap_arg_ignore_npc:                .res 1  ; $FF = check all NPCs, 0..3 = ignore index
gmap_arg_check_player:              .res 1  ; 0 = ignore player, 1 = block on player cell

_lvl_walk_off:                      .res 2
_lvl_npc_off:                       .res 2
_lvl_int_off:                       .res 2
_lvl_idx:                           .res 1
_lvl_cnt:                           .res 1
_lvl_src_y:                         .res 2
_lvl_dst_x:                         .res 2
_gmap_tmp_h1:                       .res 1
_gmap_tmp_h2:                       .res 1
_gmap_chk_idx:                      .res 1

.export gmap_cols, gmap_rows, gmap_total_cells, gmap_npc_count, gmap_interact_count, gmap_is_mesh
.export player_col, player_row, player_facing
.export player_hp, player_max_hp, player_atk, player_def, player_speed
.export player_mp, player_max_mp, player_secrets_found, player_flee_grace_timer
.export player_move_anim_timer, player_move_from_col, player_move_from_row
.export player_move_screen_dir, player_sprite_id, player_hflip, player_sub_x, player_sub_y
.export battle_enemy_idx, battle_enemy_mask
.export gmap_arg_col, gmap_arg_row, gmap_arg_from_col, gmap_arg_from_row
.export gmap_arg_ignore_npc, gmap_arg_check_player

; ------------------------------------------------------------------------------
; HIRAM Gameplay Grids & Entity Arrays ($7E:xxxx)
; ------------------------------------------------------------------------------
.segment "HIRAM"
gmap_walk_grid:                     .res 256
gmap_height_grid:                   .res 256
gmap_mesh_y_grid:                   .res 512  ; 256 x signed s16 Q10.6 floor Y for gsu_mesh camera tracking
npc_table:                          .res (MAX_NPCS * NPC_STRUCT_SIZE)
interact_table:                     .res (MAX_INTERACTABLES * INTERACT_STRUCT_SIZE)

.export gmap_walk_grid, gmap_height_grid, gmap_mesh_y_grid, npc_table, interact_table

; ==============================================================================
; Boot / Level-Load Parser (`CODE` / ROM0 — runs ONLY while GSU is stopped!)
; ==============================================================================
.segment "CODE"

; ------------------------------------------------------------------------------
; level_loader_load
; Parses `.gmap` (at `z:lvl_gmap_ptr`) and `.map` base heights (at `z:lvl_map_ptr`)
; into WRAM tables. MUST be called only while GSU is stopped (`GSU_SCMR == 0`).
; ------------------------------------------------------------------------------
level_loader_load:
        php
        RW_forced a8i16

        ; Verify magic "$4D47" ("GM") and version 1
        ldy     #GMAP_HDR_OFF_MAGIC
        lda     [lvl_gmap_ptr], y
        cmp     #$47
        beq     :+
        brl     @abort
:       iny
        lda     [lvl_gmap_ptr], y
        cmp     #$4D
        beq     :+
        brl     @abort
:       ldy     #GMAP_HDR_OFF_VERSION
        lda     [lvl_gmap_ptr], y
        cmp     #GMAP_VERSION
        beq     :+
        brl     @abort
:
        ; Read dimensions & header offsets
        ldy     #GMAP_HDR_OFF_COLS
        lda     [lvl_gmap_ptr], y
        sta     a:gmap_cols
        ldy     #GMAP_HDR_OFF_ROWS
        lda     [lvl_gmap_ptr], y
        sta     a:gmap_rows

        ; Compute gmap_total_cells = cols * rows (clamped <= 256)
        RW a16
        lda     a:gmap_cols
        and     #$00FF
        sta     a:_lvl_src_y
        lda     #$0000
        sta     a:gmap_total_cells
        RW a8
        lda     a:gmap_rows
        sta     a:_lvl_cnt
@mul_loop:
        lda     a:_lvl_cnt
        beq     @mul_ok
        dec     a:_lvl_cnt
        RW a16
        lda     a:gmap_total_cells
        clc
        adc     a:_lvl_src_y
        sta     a:gmap_total_cells
        RW a8
        bra     @mul_loop
@mul_ok:
        RW a16
        lda     a:gmap_total_cells
        cmp     #257
        bcc     :+
        lda     #256
        sta     a:gmap_total_cells
:
        ; Read 16-bit table offsets from header
        ldy     #GMAP_HDR_OFF_WALK_GRID_OFFSET
        lda     [lvl_gmap_ptr], y
        sta     a:_lvl_walk_off
        ldy     #GMAP_HDR_OFF_NPC_TABLE_OFFSET
        lda     [lvl_gmap_ptr], y
        sta     a:_lvl_npc_off
        ldy     #GMAP_HDR_OFF_INTERACTABLE_TABLE_OFFSET
        lda     [lvl_gmap_ptr], y
        sta     a:_lvl_int_off
        RW a8

        ; Initialize Player spawn & default RPG stats
        ldy     #GMAP_HDR_OFF_PLAYER_COL
        lda     [lvl_gmap_ptr], y
        sta     a:player_col
        sta     a:player_move_from_col
        ldy     #GMAP_HDR_OFF_PLAYER_ROW
        lda     [lvl_gmap_ptr], y
        sta     a:player_row
        sta     a:player_move_from_row
        ldy     #GMAP_HDR_OFF_PLAYER_FACING
        lda     [lvl_gmap_ptr], y
        sta     a:player_facing

        lda     #PLAYER_DEFAULT_HP
        sta     a:player_hp
        sta     a:player_max_hp
        sta     a:status_hp_cur
        sta     a:status_hp_max
        lda     #PLAYER_DEFAULT_MP
        sta     a:player_mp
        sta     a:player_max_mp
        sta     a:status_mp_cur
        sta     a:status_mp_max
        lda     #PLAYER_DEFAULT_ATK
        sta     a:player_atk
        lda     #PLAYER_DEFAULT_DEF
        sta     a:player_def
        lda     #PLAYER_DEFAULT_SPEED
        sta     a:player_speed
        stz     a:player_secrets_found
        stz     a:player_flee_grace_timer
        stz     a:player_move_anim_timer
        stz     a:player_move_screen_dir
        stz     a:player_sprite_id
        stz     a:player_hflip
        stz     a:player_sub_x
        stz     a:player_sub_x + 1
        stz     a:player_sub_y
        stz     a:player_sub_y + 1

        lda     #$FF
        sta     a:battle_enemy_idx
        stz     a:battle_enemy_mask
        lda     #$01
        sta     a:status_bar_dirty

        ; ------------------------------------------------------------------
        ; Copy Walkability Grid (`gmap_total_cells` bytes) -> f:gmap_walk_grid
        ; ------------------------------------------------------------------
        ldx     #$0000
        ldy     a:_lvl_walk_off
@copy_walk:
        cpx     a:gmap_total_cells
        bcs     @copy_walk_done
        lda     [lvl_gmap_ptr], y
        sta     f:gmap_walk_grid, x
        iny
        inx
        bra     @copy_walk
@copy_walk_done:

        ; ------------------------------------------------------------------
        ; Copy Elevation Heights -> f:gmap_height_grid (and optional Q10.6 Y
        ; -> f:gmap_mesh_y_grid when lvl_map_ptr points to an `SFX_MGRID_MAGIC`
        ; "$474D" companion mesh grid instead of a `.map` binary).
        ; ------------------------------------------------------------------
        ldy     #$0000
        lda     [lvl_map_ptr], y
        cmp     #$4D                    ; 'M'
        bne     @load_iso_map_heights
        iny
        lda     [lvl_map_ptr], y
        cmp     #$47                    ; 'G'
        bne     @load_iso_map_heights

        ; Hybrid Mesh Grid (`.mgrid`): 12B hdr + total_cells*2 Q10.6 Y + total_cells u8 1h heights
        lda     #$01
        sta     a:gmap_is_mesh
        RW a16
        lda     a:gmap_total_cells
        asl
        sta     a:_lvl_dst_x            ; byte count of y_grid (total_cells * 2)
        RW a8
        ldx     #$0000
        ldy     #$000C                  ; Skip 12-byte sfx_mesh_grid_header
@copy_mgrid_y:
        cpx     a:_lvl_dst_x
        bcs     @copy_mgrid_y_done
        lda     [lvl_map_ptr], y
        sta     f:gmap_mesh_y_grid, x
        iny
        inx
        bra     @copy_mgrid_y
@copy_mgrid_y_done:
        ; Y now points right at trailing normalized 1h height bytes
        ldx     #$0000
@copy_mgrid_h:
        cpx     a:gmap_total_cells
        bcs     @copy_heights_done
        lda     [lvl_map_ptr], y
        sta     f:gmap_height_grid, x
        iny
        inx
        bra     @copy_mgrid_h

@load_iso_map_heights:
        stz     a:gmap_is_mesh
        ldx     #$0000
        ldy     #$0008                  ; Skip 8-byte map_header
@copy_heights:
        cpx     a:gmap_total_cells
        bcs     @copy_heights_done
        lda     [lvl_map_ptr], y
        sta     f:gmap_height_grid, x
        iny
        iny
        iny
        iny
        iny
        iny
        iny
        iny                             ; +8 bytes per map_cell
        inx
        bra     @copy_heights
@copy_heights_done:

        ; ------------------------------------------------------------------
        ; Clear & Parse NPC Table (up to MAX_NPCS = 4)
        ; ------------------------------------------------------------------
        ldx     #$0000
        lda     #$00
@clr_npcs:
        sta     f:npc_table, x
        inx
        cpx     #(MAX_NPCS * NPC_STRUCT_SIZE)
        bcc     @clr_npcs

        ldy     #GMAP_HDR_OFF_NPC_COUNT
        lda     [lvl_gmap_ptr], y
        cmp     #(MAX_NPCS + 1)
        bcc     :+
        lda     #MAX_NPCS
:       sta     a:gmap_npc_count

        stz     a:_lvl_idx
        ldx     #$0000
        stx     a:_lvl_dst_x
        ldy     a:_lvl_npc_off
        sty     a:_lvl_src_y

@npc_loop:
        lda     a:_lvl_idx
        cmp     a:gmap_npc_count
        bcc     :+
        brl     @npcs_done
:
        ldx     a:_lvl_dst_x
        ldy     a:_lvl_src_y

        lda     #$01
        sta     f:npc_table + NPC_OFF_ACTIVE, x
        lda     [lvl_gmap_ptr], y       ; +0 col
        sta     f:npc_table + NPC_OFF_COL, x
        iny
        lda     [lvl_gmap_ptr], y       ; +1 row
        sta     f:npc_table + NPC_OFF_ROW, x
        iny
        lda     [lvl_gmap_ptr], y       ; +2 sprite_id
        sta     f:npc_table + NPC_OFF_SPRITE_ID, x
        iny
        lda     [lvl_gmap_ptr], y       ; +3 ai_type
        sta     f:npc_table + NPC_OFF_AI_TYPE, x
        iny
        lda     [lvl_gmap_ptr], y       ; +4 aggro_range
        sta     f:npc_table + NPC_OFF_AGGRO_RANGE, x
        iny
        lda     [lvl_gmap_ptr], y       ; +5 hp
        sta     f:npc_table + NPC_OFF_HP, x
        sta     f:npc_table + NPC_OFF_MAX_HP, x
        iny
        lda     [lvl_gmap_ptr], y       ; +6 atk
        sta     f:npc_table + NPC_OFF_ATK, x
        iny
        lda     [lvl_gmap_ptr], y       ; +7 def
        sta     f:npc_table + NPC_OFF_DEF, x
        iny
        lda     [lvl_gmap_ptr], y       ; +8 speed
        sta     f:npc_table + NPC_OFF_SPEED, x
        iny
        lda     [lvl_gmap_ptr], y       ; +9 move_points
        sta     f:npc_table + NPC_OFF_MOVE_POINTS, x
        iny
        lda     [lvl_gmap_ptr], y       ; +10 waypoint_count
        cmp     #(GMAP_MAX_WAYPOINTS + 1)
        bcc     :+
        lda     #GMAP_MAX_WAYPOINTS
:       sta     f:npc_table + NPC_OFF_WP_COUNT, x
        iny
        iny                             ; skip +11 reserved

        lda     #NPC_PATROL_PERIOD
        sta     f:npc_table + NPC_OFF_PATROL_TIMER, x

        ; Copy 8 waypoint bytes (+12..+19 -> NPC_OFF_WAYPOINTS..+7)
        lda     #$08
        sta     a:_lvl_cnt
@wp_copy:
        lda     [lvl_gmap_ptr], y
        sta     f:npc_table + NPC_OFF_WAYPOINTS, x
        iny
        inx
        dec     a:_lvl_cnt
        bne     @wp_copy

        ; Advance pointers: src += 20, dst += 32
        RW a16
        lda     a:_lvl_src_y
        clc
        adc     #GMAP_NPC_RECORD_SIZE
        sta     a:_lvl_src_y
        lda     a:_lvl_dst_x
        clc
        adc     #NPC_STRUCT_SIZE
        sta     a:_lvl_dst_x
        RW a8
        inc     a:_lvl_idx
        brl     @npc_loop
@npcs_done:

        ; ------------------------------------------------------------------
        ; Clear & Parse Interactable Table (up to MAX_INTERACTABLES = 4)
        ; ------------------------------------------------------------------
        ldx     #$0000
        lda     #$00
@clr_ints:
        sta     f:interact_table, x
        inx
        cpx     #(MAX_INTERACTABLES * INTERACT_STRUCT_SIZE)
        bcc     @clr_ints

        ldy     #GMAP_HDR_OFF_INTERACTABLE_COUNT
        lda     [lvl_gmap_ptr], y
        cmp     #(MAX_INTERACTABLES + 1)
        bcc     :+
        lda     #MAX_INTERACTABLES
:       sta     a:gmap_interact_count

        stz     a:_lvl_idx
        ldx     #$0000
        stx     a:_lvl_dst_x
        ldy     a:_lvl_int_off
        sty     a:_lvl_src_y

@int_loop:
        lda     a:_lvl_idx
        cmp     a:gmap_interact_count
        bcs     @ints_done

        ldx     a:_lvl_dst_x
        ldy     a:_lvl_src_y

        lda     #$01
        sta     f:interact_table + INTERACT_OFF_ACTIVE, x
        lda     #$00
        sta     f:interact_table + INTERACT_OFF_OPENED, x
        lda     [lvl_gmap_ptr], y       ; +0 col
        sta     f:interact_table + INTERACT_OFF_COL, x
        iny
        lda     [lvl_gmap_ptr], y       ; +1 row
        sta     f:interact_table + INTERACT_OFF_ROW, x
        iny
        lda     [lvl_gmap_ptr], y       ; +2 kind
        sta     f:interact_table + INTERACT_OFF_KIND, x
        iny
        lda     [lvl_gmap_ptr], y       ; +3 closed_sprite_id
        sta     f:interact_table + INTERACT_OFF_CLOSED_SPR, x
        iny
        lda     [lvl_gmap_ptr], y       ; +4 open_sprite_id
        sta     f:interact_table + INTERACT_OFF_OPEN_SPR, x
        iny
        lda     [lvl_gmap_ptr], y       ; +5 reward_kind
        sta     f:interact_table + INTERACT_OFF_REWARD_KIND, x
        iny
        lda     [lvl_gmap_ptr], y       ; +6 reward_value
        sta     f:interact_table + INTERACT_OFF_REWARD_VAL, x
        iny
        lda     [lvl_gmap_ptr], y       ; +7 message_id
        sta     f:interact_table + INTERACT_OFF_MSG_ID, x

        RW a16
        lda     a:_lvl_src_y
        clc
        adc     #GMAP_INTERACTABLE_RECORD_SIZE
        sta     a:_lvl_src_y
        lda     a:_lvl_dst_x
        clc
        adc     #INTERACT_STRUCT_SIZE
        sta     a:_lvl_dst_x
        RW a8
        inc     a:_lvl_idx
        bra     @int_loop
@ints_done:

@abort:
        plp
        rts

; ==============================================================================
; WRAM-Resident Cell Indexing & Passability Queries (`MAIN_LOOP`)
; ==============================================================================
.segment "MAIN_LOOP"

; ------------------------------------------------------------------------------
; gmap_cell_index
; Computes 16-bit cell index `row * gmap_cols + col` with unsigned bounds check.
; In:  a:gmap_arg_col, a:gmap_arg_row
; Out: Carry Clear & X = index if in bounds; Carry Set if out of bounds.
; ------------------------------------------------------------------------------
gmap_cell_index:
        php
        RW_forced a8i16
        lda     a:gmap_arg_col
        cmp     a:gmap_cols
        bcs     @oob
        lda     a:gmap_arg_row
        cmp     a:gmap_rows
        bcs     @oob

        ; Compute row * gmap_cols + col (small loop, row < 16)
        RW a16
        and     #$00FF
        tay                             ; Y = zero-extended row (0..15)
        lda     a:gmap_cols
        and     #$00FF
        sta     a:_lvl_src_y
        lda     a:gmap_arg_col
        and     #$00FF
@row_mul:
        cpy     #$0000
        beq     @in_bounds
        clc
        adc     a:_lvl_src_y
        dey
        bra     @row_mul
@in_bounds:
        tax
        plp
        clc
        rts
@oob:
        plp
        sec
        rts

; ------------------------------------------------------------------------------
; gmap_is_cell_passable
; Checks whether moving from `(gmap_arg_from_col, gmap_arg_from_row)` to
; `(gmap_arg_col, gmap_arg_row)` is valid:
;   - In bounds
;   - `gmap_walk_grid[idx] & GMAP_WALK_FLAG_WALKABLE != 0`
;   - `|gmap_height_grid[target] - gmap_height_grid[from]| <= 1`
;   - Not occupied by player (when `gmap_arg_check_player != 0`)
;   - Not occupied by any living NPC (except `gmap_arg_ignore_npc`)
;   - Not occupied by any active Interactable
; Out: Carry Set = passable, Carry Clear = blocked.
; ------------------------------------------------------------------------------
gmap_is_cell_passable:
        php
        RW_forced a8i16

        ; 1. Target cell bounds & walkability
        jsr     gmap_cell_index
        bcc     :+
        brl     @blocked
:       lda     f:gmap_walk_grid, x
        and     #GMAP_WALK_FLAG_WALKABLE
        bne     :+
        brl     @blocked
:       lda     f:gmap_height_grid, x
        sta     a:_gmap_tmp_h1          ; target height

        ; 2. Source cell height & |target_h - from_h| <= 1
        lda     a:gmap_arg_col
        pha
        lda     a:gmap_arg_row
        pha
        lda     a:gmap_arg_from_col
        sta     a:gmap_arg_col
        lda     a:gmap_arg_from_row
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        pla
        sta     a:gmap_arg_row
        pla
        sta     a:gmap_arg_col
        bcc     :+
        brl     @blocked
:       lda     f:gmap_height_grid, x
        sta     a:_gmap_tmp_h2          ; from height

        lda     a:_gmap_tmp_h1
        sec
        sbc     a:_gmap_tmp_h2
        bpl     :+
        eor     #$FF
        inc
:       cmp     #$02                    ; |dh| >= 2 => blocked
        bcc     :+
        brl     @blocked
:
        ; 3. Optional player occupation check (used by NPC patrol AI)
        lda     a:gmap_arg_check_player
        beq     @check_npcs
        lda     a:gmap_arg_col
        cmp     a:player_col
        bne     @check_npcs
        lda     a:gmap_arg_row
        cmp     a:player_row
        bne     @check_npcs
        brl     @blocked

        ; 4. Living NPC occupation check
@check_npcs:
        stz     a:_gmap_chk_idx
        ldx     #$0000
@npc_chk_loop:
        lda     a:_gmap_chk_idx
        cmp     a:gmap_npc_count
        bcs     @check_interacts
        cmp     a:gmap_arg_ignore_npc
        beq     @npc_chk_next
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @npc_chk_next
        lda     f:npc_table + NPC_OFF_HP, x
        beq     @npc_chk_next
        lda     f:npc_table + NPC_OFF_COL, x
        cmp     a:gmap_arg_col
        bne     @npc_chk_next
        lda     f:npc_table + NPC_OFF_ROW, x
        cmp     a:gmap_arg_row
        beq     @blocked
@npc_chk_next:
        RW a16
        txa
        clc
        adc     #NPC_STRUCT_SIZE
        tax
        RW a8
        inc     a:_gmap_chk_idx
        bra     @npc_chk_loop

        ; 5. Active Interactable occupation check
@check_interacts:
        stz     a:_gmap_chk_idx
        ldx     #$0000
@int_chk_loop:
        lda     a:_gmap_chk_idx
        cmp     a:gmap_interact_count
        bcs     @passable
        lda     f:interact_table + INTERACT_OFF_ACTIVE, x
        beq     @int_chk_next
        lda     f:interact_table + INTERACT_OFF_COL, x
        cmp     a:gmap_arg_col
        bne     @int_chk_next
        lda     f:interact_table + INTERACT_OFF_ROW, x
        cmp     a:gmap_arg_row
        beq     @blocked
@int_chk_next:
        RW a16
        txa
        clc
        adc     #INTERACT_STRUCT_SIZE
        tax
        RW a8
        inc     a:_gmap_chk_idx
        bra     @int_chk_loop

@passable:
        plp
        sec
        rts

@blocked:
        plp
        clc
        rts

.endif ; __ISORPG_LEVEL_LOADER__
