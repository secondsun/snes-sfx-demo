; ==============================================================================
; fallback_gmap.i - Built-In Fallback `.gmap` Gameplay Table (9x13 Fort Zeakden)
;
; Included in `ROM_LEVELS` when `USE_DEMO_LEVEL_DATA` is NOT defined so
; `IsoRPGDemo` builds and runs cleanly in parallel with #33/#41 asset authoring.
; Matches the exact binary layout of `GameplayBinarySerializer` (GameplayLayer.kt):
;   - 16-byte header ("GM", v1, 9x13, player=(5,4) facing S, 1 NPC, 1 chest)
;   - 117-byte walkability grid (9 * 13 = 117 bytes, $03 = walkable, cost 1)
;   - 1 x 20-byte patrolling NPC at (5,1) -> waypoints (4,1), (6,1), aggro=2
;   - 1 x 8-byte treasure chest at (6,4) -> ATK_BUFF +3 ("FOUND IRON SWORD! ATK +3")
; ==============================================================================

.ifndef __ISORPG_FALLBACK_GMAP__
__ISORPG_FALLBACK_GMAP__ = 1

Level0GmapBin:
        ; --- 16-byte Header (offsets 0..15) ---
        .word   $4D47                   ; +0..+1:  Magic "GM" (LE)
        .byte   $01                     ; +2:      Version = 1
        .byte   9                       ; +3:      cols = 9
        .byte   13                      ; +4:      rows = 13
        .byte   5                       ; +5:      player_col = 5 (height 2 on Zeakden)
        .byte   4                       ; +6:      player_row = 4
        .byte   2                       ; +7:      player_facing = SOUTH (2)
        .byte   1                       ; +8:      npc_count = 1
        .byte   1                       ; +9:      interactable_count = 1
        .word   16                      ; +10..+11: walk_grid_offset = 16
        .word   (16 + 117)              ; +12..+13: npc_table_offset = 133
        .word   (16 + 117 + 20)         ; +14..+15: interactable_table_offset = 153

        ; --- Walkability Grid (9 * 13 = 117 bytes; $03 = walkable, cost 1) ---
        .res    117, $03

        ; --- NPC Record 0 (20 bytes): Patrolling Guard along row 1 (cols 4..6) ---
        .byte   5                       ; +0:  col
        .byte   1                       ; +1:  row (Manhattan dist 3 from player (5,4) > aggro 2)
        .byte   2                       ; +2:  sprite_id (Enemy A)
        .byte   1                       ; +3:  ai_type = GMAP_AI_PATROL (1)
        .byte   2                       ; +4:  aggro_range = 2
        .byte   12                      ; +5:  hp
        .byte   4                       ; +6:  atk
        .byte   1                       ; +7:  def
        .byte   2                       ; +8:  speed
        .byte   3                       ; +9:  move_points
        .byte   2                       ; +10: waypoint_count = 2
        .byte   0                       ; +11: reserved
        .byte   4, 1                    ; +12..+13: wp0 = (4, 1)
        .byte   6, 1                    ; +14..+15: wp1 = (6, 1)
        .byte   $FF, $FF                ; +16..+17: wp2 unused
        .byte   $FF, $FF                ; +18..+19: wp3 unused

        ; --- Interactable Record 0 (8 bytes): Chest adjacent to player at (6,4) ---
        .byte   6                       ; +0: col (height 2 on Zeakden)
        .byte   4                       ; +1: row
        .byte   0                       ; +2: kind = GMAP_INTERACT_CHEST (0)
        .byte   5                       ; +3: closed_sprite_id = 5
        .byte   6                       ; +4: open_sprite_id = 6
        .byte   1                       ; +5: reward_kind = GMAP_REWARD_ATK_BUFF (1)
        .byte   3                       ; +6: reward_value = 3
        .byte   0                       ; +7: message_id = 0
Level0GmapBinEnd:

.endif ; __ISORPG_FALLBACK_GMAP__
