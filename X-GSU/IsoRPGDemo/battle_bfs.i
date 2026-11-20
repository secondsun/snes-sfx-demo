; ==============================================================================
; battle_bfs.i - WRAM-Resident Orthogonal BFS, Path Reconstruction & Highlights
;
; Part of IsoRPGDemo (Epic #30 / Issue #40).
; All code, queues, distance/parent tables, and highlight mirrors reside in
; WRAM (`MAIN_LOOP` / `HIRAM` / `LORAM`) so the 65816 never touches ROM while
; the SuperFX GSU owns the ROM bus.
;
; Public API:
;   - `battle_bfs_compute`         : Shortest orthogonal path distances <= max_steps
;   - `battle_bfs_reconstruct_path`: Reconstructs step-by-step path to destination
;   - `battle_highlights_clear`    : Disables highlights & zeros `battle_hl_grid`
;   - `battle_highlights_publish`  : Copies highlights into `GSU_SCENE_DESC`
;                                    (call ONLY while GSU is stopped!)
; ==============================================================================

.ifndef __ISORPG_BATTLE_BFS__
__ISORPG_BATTLE_BFS__ = 1

.include "../gsu_iso/scene_descriptor.i"

BATTLE_MAX_PATH_LEN             = 8

; ------------------------------------------------------------------------------
; LORAM BFS Parameters, Path Output & Highlight Control
; ------------------------------------------------------------------------------
.segment "LORAM"
battle_hl_enabled:              .res 1  ; 0 = disabled, 1 = enabled
bfs_arg_start_col:              .res 1
bfs_arg_start_row:              .res 1
bfs_arg_max_steps:              .res 1
bfs_arg_ignore_npc:             .res 1  ; $FF = check all NPCs, 0..3 = ignore index
bfs_arg_check_player:           .res 1  ; 0 = ignore player, 1 = block on player cell
bfs_arg_dest_col:               .res 1
bfs_arg_dest_row:               .res 1

; Reconstructed path output (step 0 = first cell after start, len-1 = dest)
battle_path_cols:               .res BATTLE_MAX_PATH_LEN
battle_path_rows:               .res BATTLE_MAX_PATH_LEN
battle_path_len:                .res 1

; Shared cell index -> (col, row) helper outputs
bfs_out_col:                    .res 1
bfs_out_row:                    .res 1

; Internal scratch
_bfs_q_head:                    .res 1
_bfs_q_tail:                    .res 1
_bfs_cur_idx:                   .res 1
_bfs_cur_col:                   .res 1
_bfs_cur_row:                   .res 1
_bfs_cur_dist:                  .res 1
_bfs_dir:                       .res 1
_bfs_rev_cnt:                   .res 1
_bfs_rev_idx:                   .res 1
_bfs_rev_buf:                   .res BATTLE_MAX_PATH_LEN

.export battle_hl_enabled
.export bfs_arg_start_col, bfs_arg_start_row, bfs_arg_max_steps
.export bfs_arg_ignore_npc, bfs_arg_check_player
.export bfs_arg_dest_col, bfs_arg_dest_row
.export battle_path_cols, battle_path_rows, battle_path_len
.export bfs_out_col, bfs_out_row

; ------------------------------------------------------------------------------
; HIRAM Fixed 256-Byte BFS & Highlight Buffers ($7E:xxxx)
; ------------------------------------------------------------------------------
.segment "HIRAM"
bfs_dist:                       .res 256 ; $FF = unreachable, 0..max_steps = cost
bfs_parent:                     .res 256 ; $FF = start/none, else parent cell idx
bfs_queue:                      .res 256 ; Circular queue of cell indices
battle_hl_grid:                 .res 256 ; Mirror of GSU_SCENE_DESC.cell_highlights

.export bfs_dist, bfs_parent, bfs_queue, battle_hl_grid

; ------------------------------------------------------------------------------
; WRAM-Resident BFS & Highlight Routines (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

; ------------------------------------------------------------------------------
; battle_bfs_idx_to_col_row
; Converts 8-bit cell index A (0..255) into `(bfs_out_col, bfs_out_row)` using
; `gmap_cols`.
; ------------------------------------------------------------------------------
battle_bfs_idx_to_col_row:
        php
        RW_forced a8i16
        stz     a:bfs_out_row
        ldx     a:gmap_cols             ; Check gmap_cols != 0 (low byte)
        pha
        lda     a:gmap_cols
        beq     @zero_cols
        pla
@div_loop:
        cmp     a:gmap_cols
        bcc     @div_done
        sec
        sbc     a:gmap_cols
        inc     a:bfs_out_row
        bra     @div_loop
@div_done:
        sta     a:bfs_out_col
        plp
        rts
@zero_cols:
        pla
        stz     a:bfs_out_col
        plp
        rts

; ------------------------------------------------------------------------------
; battle_bfs_compute
; Computes exact shortest orthogonal path distances from
; `(bfs_arg_start_col, bfs_arg_start_row)` up to `bfs_arg_max_steps`, respecting
; map bounds, `gmap_walk_grid & 1`, `|target_h - cur_h| <= 1`, and blocking units
; (`bfs_arg_ignore_npc`, `bfs_arg_check_player`).
; Populates `bfs_dist[256]` ($FF = unreachable) and `bfs_parent[256]`.
; ------------------------------------------------------------------------------
battle_bfs_compute:
        php
        RW_forced a8i16

        lda     a:gmap_cols
        bne     :+
        brl     @done
:       lda     a:gmap_rows
        bne     :+
        brl     @done
:
        ; 1. Fill bfs_dist[0..255] and bfs_parent[0..255] with $FF (128 words)
        RW a16
        lda     #$FFFF
        ldx     #$0000
@fill_ff:
        sta     f:bfs_dist, x
        sta     f:bfs_parent, x
        inx
        inx
        cpx     #256
        bcc     @fill_ff
        RW a8

        ; 2. Validate start cell and enqueue
        lda     a:bfs_arg_start_col
        sta     a:gmap_arg_col
        lda     a:bfs_arg_start_row
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        bcc     :+
        brl     @done
:
        lda     #$00
        sta     f:bfs_dist, x
        lda     #$FF
        sta     f:bfs_parent, x

        txa                             ; low 8 bits of start cell index
        sta     f:bfs_queue
        stz     a:_bfs_q_head
        lda     #$01
        sta     a:_bfs_q_tail

        ; 3. BFS expansion loop
@bfs_loop:
        lda     a:_bfs_q_head
        cmp     a:_bfs_q_tail
        bne     :+
        brl     @done
:
        ; Pop cur_idx = bfs_queue[_bfs_q_head++]
        RW a16
        and     #$00FF
        tax
        RW a8
        lda     f:bfs_queue, x
        sta     a:_bfs_cur_idx
        inc     a:_bfs_q_head

        ; Check cur_dist < bfs_arg_max_steps
        RW a16
        lda     a:_bfs_cur_idx
        and     #$00FF
        tax
        RW a8
        lda     f:bfs_dist, x
        sta     a:_bfs_cur_dist
        cmp     a:bfs_arg_max_steps
        bcs     @bfs_loop

        ; Convert cur_idx -> (_bfs_cur_col, _bfs_cur_row)
        lda     a:_bfs_cur_idx
        jsr     battle_bfs_idx_to_col_row
        lda     a:bfs_out_col
        sta     a:_bfs_cur_col
        lda     a:bfs_out_row
        sta     a:_bfs_cur_row

        ; Expand 4 orthogonal neighbors (0=N, 1=E, 2=S, 3=W)
        stz     a:_bfs_dir
@dir_loop:
        lda     a:_bfs_dir
        cmp     #$04
        bcs     @bfs_loop

        RW a16
        and     #$0003
        tax
        RW a8
        lda     a:_bfs_cur_col
        clc
        adc     f:DIR_DCOL, x
        sta     a:gmap_arg_col
        lda     a:_bfs_cur_row
        clc
        adc     f:DIR_DROW, x
        sta     a:gmap_arg_row

        lda     a:_bfs_cur_col
        sta     a:gmap_arg_from_col
        lda     a:_bfs_cur_row
        sta     a:gmap_arg_from_row
        lda     a:bfs_arg_ignore_npc
        sta     a:gmap_arg_ignore_npc
        lda     a:bfs_arg_check_player
        sta     a:gmap_arg_check_player

        jsr     gmap_is_cell_passable
        bcc     @next_dir

        ; Look up neighbor cell index -> X
        jsr     gmap_cell_index
        bcs     @next_dir

        ; Skip if already visited (bfs_dist[X] != $FF)
        lda     f:bfs_dist, x
        cmp     #$FF
        bne     @next_dir

        ; Record distance = cur_dist + 1 and parent = _bfs_cur_idx
        lda     a:_bfs_cur_dist
        inc
        sta     f:bfs_dist, x
        lda     a:_bfs_cur_idx
        sta     f:bfs_parent, x

        ; Enqueue neighbor index at bfs_queue[_bfs_q_tail++]
        txa                             ; low byte of neighbor index
        pha
        RW a16
        lda     a:_bfs_q_tail
        and     #$00FF
        tax
        RW a8
        pla
        sta     f:bfs_queue, x
        inc     a:_bfs_q_tail

@next_dir:
        inc     a:_bfs_dir
        bra     @dir_loop

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_bfs_reconstruct_path
; Reconstructs the step-by-step cell path from the last BFS start cell to
; `(bfs_arg_dest_col, bfs_arg_dest_row)` into `battle_path_cols[0..len-1]` and
; `battle_path_rows[0..len-1]`, setting `battle_path_len`.
; Out: `battle_path_len` = 0 if unreachable or dest == start.
; ------------------------------------------------------------------------------
battle_bfs_reconstruct_path:
        php
        RW_forced a8i16
        stz     a:battle_path_len

        lda     a:bfs_arg_dest_col
        sta     a:gmap_arg_col
        lda     a:bfs_arg_dest_row
        sta     a:gmap_arg_row
        jsr     gmap_cell_index
        bcc     :+
        brl     @done
:
        ; Must be reachable (1 <= dist <= BATTLE_MAX_PATH_LEN)
        lda     f:bfs_dist, x
        bne     :+
        brl     @done
:       cmp     #(BATTLE_MAX_PATH_LEN + 1)
        bcc     :+
        brl     @done
:

        ; Walk parent pointers backwards into _bfs_rev_buf
        stz     a:_bfs_rev_cnt
        txa
        sta     a:_bfs_cur_idx

@walk_back:
        lda     a:_bfs_rev_cnt
        cmp     #BATTLE_MAX_PATH_LEN
        bcs     @reverse_path

        RW a16
        lda     a:_bfs_cur_idx
        and     #$00FF
        tax
        RW a8
        lda     f:bfs_parent, x
        cmp     #$FF
        beq     @reverse_path

        ; Push _bfs_cur_idx into _bfs_rev_buf[_bfs_rev_cnt++]
        pha                             ; save parent
        RW a16
        lda     a:_bfs_rev_cnt
        and     #$00FF
        tax
        RW a8
        lda     a:_bfs_cur_idx
        sta     a:_bfs_rev_buf, x
        inc     a:_bfs_rev_cnt
        pla                             ; restore parent
        sta     a:_bfs_cur_idx
        bra     @walk_back

@reverse_path:
        lda     a:_bfs_rev_cnt
        sta     a:battle_path_len
        beq     @done

        ; Reverse _bfs_rev_buf[cnt-1..0] -> battle_path_cols/rows[0..cnt-1]
        stz     a:_bfs_rev_idx
@rev_loop:
        lda     a:_bfs_rev_idx
        cmp     a:battle_path_len
        bcs     @done

        ; src = battle_path_len - 1 - _bfs_rev_idx
        lda     a:battle_path_len
        dec
        sec
        sbc     a:_bfs_rev_idx
        RW a16
        and     #$00FF
        tax
        RW a8
        lda     a:_bfs_rev_buf, x
        jsr     battle_bfs_idx_to_col_row

        RW a16
        lda     a:_bfs_rev_idx
        and     #$00FF
        tax
        RW a8
        lda     a:bfs_out_col
        sta     a:battle_path_cols, x
        lda     a:bfs_out_row
        sta     a:battle_path_rows, x

        inc     a:_bfs_rev_idx
        bra     @rev_loop

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; battle_highlights_clear
; Disables tactical cell highlights and zeros `battle_hl_grid[256]`.
; ------------------------------------------------------------------------------
battle_highlights_clear:
        php
        RW_forced a8i16
        stz     a:battle_hl_enabled
        RW a16
        lda     #$0000
        ldx     #$0000
@clr_loop:
        sta     f:battle_hl_grid, x
        inx
        inx
        cpx     #256
        bcc     @clr_loop
        plp
        rts

; ------------------------------------------------------------------------------
; battle_highlights_publish
; Copies `battle_hl_enabled` and `battle_hl_grid[256]` into Bank-$70
; `GSU_SCENE_DESC.highlights_enabled` / `cell_highlights[]`.
; MUST be called ONLY while GSU is stopped (`gsuRunning == 0`).
; ------------------------------------------------------------------------------
battle_highlights_publish:
        php
        RW_forced a8i16
        lda     a:battle_hl_enabled
        beq     @disabled

        RW a16
        lda     #$0001
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::highlights_enabled
        ldx     #$0000
@copy_hl:
        lda     f:battle_hl_grid, x
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::cell_highlights, x
        inx
        inx
        cpx     #256
        bcc     @copy_hl
        plp
        rts

@disabled:
        RW_forced a16i16
        lda     #$0000
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::highlights_enabled
        plp
        rts

.endif ; __ISORPG_BATTLE_BFS__
