; ==============================================================================
; entity_sync.i - 65816 <-> GSU Entity Descriptor Publisher & OAM Latch Bridge
;
; Part of IsoRPGDemo (Epic #30 / Issue #39, ADR 0005 & ADR 0006).
; Responsibilities:
;   1. `entity_sync_publish_descriptor` (called while GSU is stopped):
;      Publishes active entities (Slot 0 = Player, Slots 1..N = living NPCs,
;      remaining slots up to 8 = active Interactables) into
;      `GSU_SCENE_DESC.entities[]` with 1-bit Sprite Mask pointers, sub-cell
;      offsets, and HFLIP flags, and snapshots per-slot OAM metadata for exact
;      frame-matched latching when Pass 1 finishes.
;   2. `entity_sync_latch_oam` (called on Pass 1 VBlank immediately after
;      `BG12NBA` flip, BEFORE publishing the next frame's descriptor):
;      Reads `GSU_SCENE_DESC.entity_out[]` into `oam_push_entity_16x24` and
;      commits via `oam_latch_entities` with zero 1-frame desync.
; ==============================================================================

.ifndef __ISORPG_ENTITY_SYNC__
__ISORPG_ENTITY_SYNC__ = 1

.include "../gsu_iso/scene_descriptor.i"

ENTITY_DEFAULT_MASK_W           = 16
ENTITY_DEFAULT_MASK_H           = 24
ENTITY_MASK_STRIDE_BYTES        = 48    ; 16x24 1-bit mask = 2 B/row * 24 rows

; ------------------------------------------------------------------------------
; LORAM Snapshot State (tracks entities currently being rendered by GSU)
; ------------------------------------------------------------------------------
.segment "LORAM"
entity_published_count:         .res 1  ; Count of entities published in active GSU frame
entity_slot_oam_tile:           .res GSU_SCENE_MAX_ENTITIES
entity_slot_oam_pal:            .res GSU_SCENE_MAX_ENTITIES
entity_slot_oam_hflip:          .res GSU_SCENE_MAX_ENTITIES
entity_slot_sx:                 .res (GSU_SCENE_MAX_ENTITIES * 2)
entity_slot_sy:                 .res (GSU_SCENE_MAX_ENTITIES * 2)

; Internal scratch
_es_slot:                       .res 1
_es_idx:                        .res 1
_es_src_off:                    .res 2
_es_dst_off:                    .res 2
_es_spr_id:                     .res 1
_es_col:                        .res 1
_es_row:                        .res 1
_es_hflip:                      .res 1
_es_sub_x:                      .res 2
_es_sub_y:                      .res 2

.export entity_published_count, entity_slot_sx, entity_slot_sy

; ------------------------------------------------------------------------------
; WRAM-Resident Sprite/Mask Lookup Tables & Sync Routines (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

; Sprite ID (0..7) -> Base 4bpp OAM tile index (16x16 upper; lower = +$20)
;   0: Hero Idle, 1: Hero Walk, 2: Hero Attack, 3: Slime,
;   4: Guardian Knight, 5: Chest Closed, 6: Chest Open, 7: Prop (fallback)
.ifndef USE_DEMO_LEVEL_DATA
ENT_OAM_TILE_LUT:               .byte $00, $00, $00, $00, $00, $00, $00, $00
.else
ENT_OAM_TILE_LUT:               .byte $00, $02, $04, $06, $08, $0A, $0C, $0A
.endif

; Sprite ID (0..7) -> Hardware OBJ palette (0..7 -> CGRAM 128..255)
ENT_OAM_PAL_LUT:
        .byte OAM_PAL_PLAYER            ; 0: Hero Idle
        .byte OAM_PAL_PLAYER            ; 1: Hero Walk
        .byte OAM_PAL_PLAYER            ; 2: Hero Attack
        .byte OAM_PAL_ENEMY_A           ; 3: Patrol Slime
        .byte OAM_PAL_ENEMY_B           ; 4: Guardian Knight
        .byte OAM_PAL_PROP              ; 5: Chest Closed
        .byte OAM_PAL_PROP              ; 6: Chest Open
        .byte OAM_PAL_PROP              ; 7: Prop

; Sprite ID (0..7) -> 16-bit offset in Bank $05 (`ROM_MASKS`)
.ifndef USE_DEMO_LEVEL_DATA
ENT_MASK_ADDR_LUT:
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
        .word .loword(PlaceholderMask16x24)
.else
ENT_MASK_ADDR_LUT:
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_0_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_1_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_2_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_3_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_4_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_5_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_6_MSK_OFFSET)
        .word .loword(DemoSpriteMasks + DEMO_SPRITES_FRAME_5_MSK_OFFSET)
.endif

; ------------------------------------------------------------------------------
; _es_emit_slot (Internal)
; Writes one `gsu_entity_mask_slot` at `_es_slot` (0..7) into `GSU_SCENE_DESC`
; and snapshots its OAM tile/palette/hflip for Pass 1 latching.
; Expects: _es_col, _es_row, _es_spr_id, _es_hflip, _es_sub_x, _es_sub_y.
; ------------------------------------------------------------------------------
_es_emit_slot:
        RW_forced a8i16
        lda     a:_es_slot
        cmp     #GSU_SCENE_MAX_ENTITIES
        bcc     :+
        rts
:
        ; Snapshot OAM metadata into LORAM[slot]
        lda     a:_es_spr_id
        and     #$07
        RW a16
        and     #$0007
        tax                             ; X = sprite_id (0..7)
        lda     a:_es_slot
        and     #$0007
        tay                             ; Y = slot (0..7)
        RW a8

        lda     f:ENT_OAM_TILE_LUT, x
        sta     a:entity_slot_oam_tile, y
        lda     f:ENT_OAM_PAL_LUT, x
        sta     a:entity_slot_oam_pal, y
        lda     a:_es_hflip
        sta     a:entity_slot_oam_hflip, y

        ; Compute GSU_SCENE_DESC.entities[slot] offset = 16 + (slot << 4)
        RW a16
        lda     a:_es_slot
        and     #$0007
        asl
        asl
        asl
        asl
        clc
        adc     #gsu_scene_descriptor::entities
        sta     a:_es_dst_off
        tax
        RW a8

        lda     #$01
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::active, x
        lda     a:_es_col
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::cell_i, x
        lda     a:_es_row
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::cell_j, x
.ifndef USE_DEMO_LEVEL_DATA
        lda     #^PlaceholderMask16x24
.else
        lda     #^DemoSpriteMasks
.endif
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::mask_bank, x
        lda     #ENTITY_DEFAULT_MASK_W
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::mask_w, x
        lda     #ENTITY_DEFAULT_MASK_H
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::mask_h, x

        lda     a:_es_hflip
        beq     :+
        lda     #GSU_ENTITY_FLAG_HFLIP
:       sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::flags, x
        lda     #$00
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::reserved, x

        ; Write 16-bit mask_addr, sub_x_offset, sub_y_offset, anchor_y_offset
        RW a16
        lda     a:_es_spr_id
        and     #$0007
        asl
        tax
        lda     f:ENT_MASK_ADDR_LUT, x
        ldx     a:_es_dst_off
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::mask_addr, x
        lda     a:_es_sub_x
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::sub_x_offset, x
        lda     a:_es_sub_y
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::sub_y_offset, x
        lda     #$0000
        sta     f:GSU_SCENE_DESC + gsu_entity_mask_slot::anchor_y_offset, x
        RW a8

        inc     a:_es_slot
        rts

; ------------------------------------------------------------------------------
; entity_sync_publish_descriptor
; Publishes Player + living NPCs + active Interactables into `GSU_SCENE_DESC`.
; MUST be called only while GSU is stopped (`gsuRunning == 0`).
; ------------------------------------------------------------------------------
entity_sync_publish_descriptor:
        php
        RW_forced a8i16
        stz     a:_es_slot

        ; --- Slot 0: Player ---
        lda     a:player_col
        sta     a:_es_col
        lda     a:player_row
        sta     a:_es_row
        lda     a:player_sprite_id
        sta     a:_es_spr_id
        lda     a:player_hflip
        sta     a:_es_hflip
        RW a16
        lda     a:player_sub_x
        sta     a:_es_sub_x
        lda     a:player_sub_y
        sta     a:_es_sub_y
        RW a8
        jsr     _es_emit_slot

        ; --- Slots 1..N: Living NPCs ---
        stz     a:_es_idx
        ldx     #$0000
        stx     a:_es_src_off
@npc_pub_loop:
        lda     a:_es_idx
        cmp     a:gmap_npc_count
        bcs     @pub_interacts
        lda     a:_es_slot
        cmp     #GSU_SCENE_MAX_ENTITIES
        bcc     :+
        brl     @finish_pub
:

        ldx     a:_es_src_off
        lda     f:npc_table + NPC_OFF_ACTIVE, x
        beq     @npc_pub_next
        lda     f:npc_table + NPC_OFF_HP, x
        beq     @npc_pub_next

        lda     f:npc_table + NPC_OFF_COL, x
        sta     a:_es_col
        lda     f:npc_table + NPC_OFF_ROW, x
        sta     a:_es_row
        lda     f:npc_table + NPC_OFF_SPRITE_ID, x
        sta     a:_es_spr_id
        lda     f:npc_table + NPC_OFF_HFLIP, x
        sta     a:_es_hflip
        RW a16
        lda     f:npc_table + NPC_OFF_SUB_X, x
        sta     a:_es_sub_x
        lda     f:npc_table + NPC_OFF_SUB_Y, x
        sta     a:_es_sub_y
        RW a8
        jsr     _es_emit_slot

@npc_pub_next:
        RW a16
        lda     a:_es_src_off
        clc
        adc     #NPC_STRUCT_SIZE
        sta     a:_es_src_off
        RW a8
        inc     a:_es_idx
        bra     @npc_pub_loop

        ; --- Remaining Slots: Active Interactables (closed vs open sprite/mask) ---
@pub_interacts:
        stz     a:_es_idx
        ldx     #$0000
        stx     a:_es_src_off
@int_pub_loop:
        lda     a:_es_idx
        cmp     a:gmap_interact_count
        bcs     @finish_pub
        lda     a:_es_slot
        cmp     #GSU_SCENE_MAX_ENTITIES
        bcc     :+
        brl     @finish_pub
:

        ldx     a:_es_src_off
        lda     f:interact_table + INTERACT_OFF_ACTIVE, x
        beq     @int_pub_next

        lda     f:interact_table + INTERACT_OFF_COL, x
        sta     a:_es_col
        lda     f:interact_table + INTERACT_OFF_ROW, x
        sta     a:_es_row
        lda     f:interact_table + INTERACT_OFF_OPENED, x
        bne     @use_open_spr
        lda     f:interact_table + INTERACT_OFF_CLOSED_SPR, x
        bra     @spr_ready
@use_open_spr:
        lda     f:interact_table + INTERACT_OFF_OPEN_SPR, x
@spr_ready:
        sta     a:_es_spr_id
        stz     a:_es_hflip
        stz     a:_es_sub_x
        stz     a:_es_sub_x + 1
        stz     a:_es_sub_y
        stz     a:_es_sub_y + 1
        jsr     _es_emit_slot

@int_pub_next:
        RW a16
        lda     a:_es_src_off
        clc
        adc     #INTERACT_STRUCT_SIZE
        sta     a:_es_src_off
        RW a8
        inc     a:_es_idx
        bra     @int_pub_loop

@finish_pub:
        lda     a:_es_slot
        sta     a:entity_published_count
        RW a16
        and     #$00FF
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::entity_count
        RW a8
        jsr     battle_highlights_publish
        plp
        rts

; ------------------------------------------------------------------------------
; entity_sync_latch_oam
; ADR 0005 VBlank Sync Bridge:
; Reads `GSU_SCENE_DESC.entity_out[0..entity_published_count-1]` written by
; GSU Pass 0, pushes visible entities via `oam_push_entity_16x24`, and commits
; them into OAM Tier 1 slots 0..31 via `oam_latch_entities`.
; MUST be called on Pass 1 VBlank immediately after `BG12NBA` flip and BEFORE
; `entity_sync_publish_descriptor`.
; ------------------------------------------------------------------------------
entity_sync_latch_oam:
        php
        RW_forced a8i16

        jsr     oam_begin_entities

        stz     a:_es_idx
@latch_loop:
        lda     a:_es_idx
        cmp     a:entity_published_count
        bcs     @commit

        ; offset = gsu_scene_descriptor::entity_out + (_es_idx * 8)
        RW a16
        and     #$0007
        asl
        asl
        asl
        clc
        adc     #gsu_scene_descriptor::entity_out
        tax

        lda     f:GSU_SCENE_DESC + gsu_entity_screen_pos::visible, x
        beq     @latch_next_a16

        lda     f:GSU_SCENE_DESC + gsu_entity_screen_pos::sx, x
        sta     a:oam_arg_x
        lda     f:GSU_SCENE_DESC + gsu_entity_screen_pos::sy, x
        sta     a:oam_arg_y

        ; Snapshot projected (sx, sy) into WRAM for GSU-bus-safe damage popups
        lda     a:_es_idx
        and     #$0007
        asl
        tay
        lda     a:oam_arg_x
        sta     a:entity_slot_sx, y
        lda     a:oam_arg_y
        sta     a:entity_slot_sy, y

        lda     a:_es_idx
        and     #$0007
        tay
        RW a8
        lda     a:entity_slot_oam_tile, y
        sta     a:oam_arg_tile
        lda     a:entity_slot_oam_pal, y
        sta     a:oam_arg_pal
        lda     a:entity_slot_oam_hflip, y
        sta     a:oam_arg_hflip
        jsr     oam_push_entity_16x24
        bra     @latch_next

@latch_next_a16:
        RW_forced a8i16
@latch_next:
        inc     a:_es_idx
        bra     @latch_loop

@commit:
        ; Always force latch so stale entity OAM slots are hidden even if 0 visible
        lda     #$01
        sta     a:oam_entity_latch_ready
        jsr     oam_latch_entities
        plp
        rts

.endif ; __ISORPG_ENTITY_SYNC__
