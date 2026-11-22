; ==============================================================================
; explore_move.i - Stepped Cell-to-Cell Movement, Sub-Cell Interp & Camera Follow
;
; Part of IsoRPGDemo (Epic #30 / Issue #39).
; All code & lookup tables live in `MAIN_LOOP` (WRAM / HIRAM) and are accessed
; via `f:` long addressing so the 65816 never touches ROM while GSU runs.
; ==============================================================================

.ifndef __ISORPG_EXPLORE_MOVE__
__ISORPG_EXPLORE_MOVE__ = 1

PLAYER_MOVE_ANIM_FRAMES         = 12    ; 12-frame smooth cell-to-cell glide
CAM_WORLD_FOLLOW_STEP           = 2     ; Max world-space camera follow (Q8.4 units/frame)

; ------------------------------------------------------------------------------
; LORAM Scratch for Movement & Camera Math
; ------------------------------------------------------------------------------
.segment "LORAM"
exp_out_sub_x:                  .res 2  ; Output signed 16-bit sub_x_offset
exp_out_sub_y:                  .res 2  ; Output signed 16-bit sub_y_offset
cam_world_x:                    .res 2  ; Continuous camera world X (Q8.4: 16 units/cell)
cam_world_z:                    .res 2  ; Continuous camera world Z (Q8.4: 16 units/cell)
_exp_dpad_dir:                  .res 1  ; 0=UP, 1=RIGHT, 2=DOWN, 3=LEFT
_exp_quad:                      .res 1  ; Active yaw quadrant (0..3)
_exp_world_dir:                 .res 1  ; 0=N, 1=E, 2=S, 3=W
_exp_dc:                        .res 2  ; Signed world dx from map center (Q8.4)
_exp_dr:                        .res 2  ; Signed world dz from map center (Q8.4)
_exp_u:                         .res 2  ; Scratch
_exp_v:                         .res 2  ; Signed cos31 scratch
_exp_tmp:                       .res 2
_exp_target_wx:                 .res 2  ; Target player world X (Q8.4)
_exp_target_wz:                 .res 2  ; Target player world Z (Q8.4)
_exp_target_x:                  .res 2
_exp_target_y:                  .res 2

.export exp_out_sub_x, exp_out_sub_y, cam_world_x, cam_world_z

; ------------------------------------------------------------------------------
; WRAM-Resident Lookup Tables & Movement Logic (`MAIN_LOOP`)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

; Cardinal world-direction deltas indexed by Facing (0=N, 1=E, 2=S, 3=W)
DIR_DCOL:                       .byte 0, 1, 0, $FF
DIR_DROW:                       .byte $FF, 0, 1, 0

; 13-entry sub-cell pixel magnitude LUTs for timer = 0..12 (step = 22px X, 11px Y)
MOVE_SUB_X_LUT:                 .byte 0, 2, 4, 6, 7, 9, 11, 13, 15, 16, 18, 20, 22
MOVE_SUB_Y_LUT:                 .byte 0, 1, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 11
; Subtle sprite-only vertical walk-hop arc (pixels upward) for timer = 0..12
MOVE_HOP_Y_LUT:                 .byte 0, 1, 2, 3, 3, 4, 4, 4, 3, 3, 2, 1, 0
; Linear Q8.4 world-space fraction (0..16) for timer = 0..12
MOVE_WORLD_FRAC_LUT:            .byte 0, 1, 3, 4, 5, 7, 8, 9, 11, 12, 13, 15, 16

; 120-entry signed Q0 trig LUTs scaled by 31 for yaw = 1..120 (index = yaw - 1)
CAM_COS_31:
        .byte $1F, $1F, $1F, $1E, $1E, $1D, $1D, $1C, $1C, $1B, $1A, $19
        .byte $18, $17, $16, $15, $14, $12, $11, $10, $0E, $0D, $0B, $0A
        .byte $08, $06, $05, $03, $02, $00, $FE, $FD, $FB, $FA, $F8, $F6
        .byte $F5, $F3, $F2, $F1, $EF, $EE, $EC, $EB, $EA, $E9, $E8, $E7
        .byte $E6, $E5, $E4, $E4, $E3, $E3, $E2, $E2, $E1, $E1, $E1, $E1
        .byte $E1, $E1, $E1, $E2, $E2, $E3, $E3, $E4, $E4, $E5, $E6, $E7
        .byte $E8, $E9, $EA, $EB, $EC, $EE, $EF, $F0, $F2, $F3, $F5, $F6
        .byte $F8, $FA, $FB, $FD, $FE, $00, $02, $03, $05, $06, $08, $0A
        .byte $0B, $0D, $0E, $10, $11, $12, $14, $15, $16, $17, $18, $19
        .byte $1A, $1B, $1C, $1C, $1D, $1D, $1E, $1E, $1F, $1F, $1F, $1F
CAM_SIN_31:
        .byte $02, $03, $05, $06, $08, $0A, $0B, $0D, $0E, $0F, $11, $12
        .byte $14, $15, $16, $17, $18, $19, $1A, $1B, $1C, $1C, $1D, $1D
        .byte $1E, $1E, $1F, $1F, $1F, $1F, $1F, $1F, $1F, $1E, $1E, $1D
        .byte $1D, $1C, $1C, $1B, $1A, $19, $18, $17, $16, $15, $14, $12
        .byte $11, $0F, $0E, $0D, $0B, $0A, $08, $06, $05, $03, $02, $00
        .byte $FE, $FD, $FB, $FA, $F8, $F6, $F5, $F3, $F2, $F0, $EF, $EE
        .byte $EC, $EB, $EA, $E9, $E8, $E7, $E6, $E5, $E4, $E4, $E3, $E3
        .byte $E2, $E2, $E1, $E1, $E1, $E1, $E1, $E1, $E1, $E2, $E2, $E3
        .byte $E3, $E4, $E4, $E5, $E6, $E7, $E8, $E9, $EA, $EB, $EC, $EE
        .byte $EF, $F0, $F2, $F3, $F5, $F6, $F8, $FA, $FB, $FD, $FE, $00

; ------------------------------------------------------------------------------
; explore_get_cam_quadrant
; Maps `cam_yaw_target` (1..120) to cardinal yaw quadrant 0..3:
;   0: 1..29   (45 deg)
;   1: 30..59  (135 deg)
;   2: 60..89  (225 deg)
;   3: 90..120 (315 deg)
; Out: A (8-bit) = quadrant (0..3)
; ------------------------------------------------------------------------------
explore_get_cam_quadrant:
        php
        RW_forced a16i16
        lda     a:cam_yaw_target
        cmp     #30
        bcc     @q0
        cmp     #60
        bcc     @q1
        cmp     #90
        bcc     @q2
        lda     #$0003
        bra     @ret
@q0:    lda     #$0000
        bra     @ret
@q1:    lda     #$0001
        bra     @ret
@q2:    lda     #$0002
@ret:   plp
        rts

; ------------------------------------------------------------------------------
; explore_compute_sub_offset
; Computes signed 16-bit `(exp_out_sub_x, exp_out_sub_y)` for a cell-to-cell
; transition in screen direction `Y` (0=UP, 1=RIGHT, 2=DOWN, 3=LEFT) with
; remaining animation timer `A` (0..12).
; In:  A (8-bit) = timer (0..12), Y (16-bit, low byte) = screen_dir (0..3)
; Out: a:exp_out_sub_x, a:exp_out_sub_y
; ------------------------------------------------------------------------------
explore_compute_sub_offset:
        php
        RW_forced a8i16
        cmp     #(PLAYER_MOVE_ANIM_FRAMES + 1)
        bcc     :+
        lda     #PLAYER_MOVE_ANIM_FRAMES
:       RW a16
        and     #$00FF
        tax
        lda     f:MOVE_SUB_X_LUT, x
        and     #$00FF
        sta     a:exp_out_sub_x
        lda     f:MOVE_SUB_Y_LUT, x
        and     #$00FF
        sta     a:exp_out_sub_y

        ; Apply sign opposite to travel direction so entity glides from prev cell -> cur cell:
        ;   0 (UP    = +X, -Y) => from-offset = (-X, +Y)
        ;   1 (RIGHT = +X, +Y) => from-offset = (-X, -Y)
        ;   2 (DOWN  = -X, +Y) => from-offset = (+X, -Y)
        ;   3 (LEFT  = -X, -Y) => from-offset = (+X, +Y)
        tya
        and     #$0003
        beq     @dir_up
        cmp     #$0001
        beq     @dir_right
        cmp     #$0002
        beq     @dir_down
        ; dir_left: (+X, +Y) already positive
        bra     @done

@dir_up:
        ; (-X, +Y)
        lda     #$0000
        sec
        sbc     a:exp_out_sub_x
        sta     a:exp_out_sub_x
        bra     @done

@dir_right:
        ; (-X, -Y)
        lda     #$0000
        sec
        sbc     a:exp_out_sub_x
        sta     a:exp_out_sub_x
        lda     #$0000
        sec
        sbc     a:exp_out_sub_y
        sta     a:exp_out_sub_y
        bra     @done

@dir_down:
        ; (+X, -Y)
        lda     #$0000
        sec
        sbc     a:exp_out_sub_y
        sta     a:exp_out_sub_y

@done:
        ; Apply subtle sprite-only vertical hop (-MOVE_HOP_Y_LUT[timer]) so sprite
        ; bounces gently on each step while the camera glides smoothly on world X/Z
        lda     f:MOVE_HOP_Y_LUT, x
        and     #$00FF
        sta     a:_exp_tmp
        lda     a:exp_out_sub_y
        sec
        sbc     a:_exp_tmp
        sta     a:exp_out_sub_y
        plp
        rts

; ------------------------------------------------------------------------------
; _exp_mul_s8_s8 (Internal)
; Signed multiply `A * a:_exp_tmp` using SNES hardware 8x8 multiplier ($4202/$4203).
; Valid for `|A| <= 31` and `|a:_exp_tmp| <= 128`.
; In:  A (16-bit signed), a:_exp_tmp (16-bit signed)
; Out: A (16-bit signed product)
; ------------------------------------------------------------------------------
_exp_mul_s8_s8:
        RW_forced a16i16
        sta     a:_exp_u                ; multiplicand 1
        eor     a:_exp_tmp
        pha                             ; stack bit 15 = result sign

        ; |multiplicand 1| -> WRMPYA
        lda     a:_exp_u
        bpl     :+
        eor     #$FFFF
        inc
:       RW a8
        sta     f:WRMPYA

        ; |multiplicand 2| -> WRMPYB
        RW a16
        lda     a:_exp_tmp
        bpl     :+
        eor     #$FFFF
        inc
:       RW a8
        sta     f:WRMPYB
        nop
        nop
        nop
        nop

        RW a16
        lda     f:RDMPYL
        sta     a:_exp_u
        pla
        bpl     @pos
        lda     a:_exp_u
        eor     #$FFFF
        inc
        rts
@pos:
        lda     a:_exp_u
        rts

; ------------------------------------------------------------------------------
; _exp_compute_player_world_xz (Internal)
; Computes player's exact continuous world `(x, z)` in Q8.4 (16 units/cell),
; linearly interpolating from `(from_col, from_row)` -> `(player_col, player_row)`
; during a cell glide.
; Out: a:_exp_target_wx, a:_exp_target_wz
; ------------------------------------------------------------------------------
_exp_compute_player_world_xz:
        php
        RW_forced a16i16
        ; target_wx = player_col * 16 + 8
        lda     a:player_col
        and     #$00FF
        asl
        asl
        asl
        asl
        clc
        adc     #$0008
        sta     a:_exp_target_wx

        ; target_wz = player_row * 16 + 8
        lda     a:player_row
        and     #$00FF
        asl
        asl
        asl
        asl
        clc
        adc     #$0008
        sta     a:_exp_target_wz

        ; If gliding, blend linearly back toward (from_col, from_row) by frac(timer)
        RW a8
        lda     a:player_move_anim_timer
        beq     @done
        cmp     #(PLAYER_MOVE_ANIM_FRAMES + 1)
        bcc     :+
        lda     #PLAYER_MOVE_ANIM_FRAMES
:       RW a16
        and     #$00FF
        tax
        lda     f:MOVE_WORLD_FRAC_LUT, x
        and     #$00FF
        sta     a:_exp_tmp              ; frac in 0..16

        RW a8
        lda     a:player_move_from_col
        cmp     a:player_col
        beq     @chk_z
        bcc     @sub_x
        ; from_col > player_col -> add frac
        RW a16
        lda     a:_exp_target_wx
        clc
        adc     a:_exp_tmp
        sta     a:_exp_target_wx
        RW a8
        bra     @chk_z
@sub_x:
        RW_forced a16i16
        lda     a:_exp_target_wx
        sec
        sbc     a:_exp_tmp
        sta     a:_exp_target_wx
        RW a8

@chk_z:
        lda     a:player_move_from_row
        cmp     a:player_row
        beq     @done
        bcc     @sub_z
        ; from_row > player_row -> add frac
        RW a16
        lda     a:_exp_target_wz
        clc
        adc     a:_exp_tmp
        sta     a:_exp_target_wz
        bra     @done
@sub_z:
        RW_forced a16i16
        lda     a:_exp_target_wz
        sec
        sbc     a:_exp_tmp
        sta     a:_exp_target_wz

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; _exp_project_cam_world_to_screen (Internal)
; Projects `(cam_world_x, cam_world_z)` (Q8.4) into `(cam_center_x, cam_center_y)`
; at the active `cam_yaw_cur` (1..120):
;   dx = ((cam_world_x - cols*8) * cos31 - (cam_world_z - rows*8) * sin31) >> 4
;   dy = ((cam_world_x - cols*8) * sin31 + (cam_world_z - rows*8) * cos31) >> 5
; ------------------------------------------------------------------------------
_exp_project_cam_world_to_screen:
        php
        RW_forced a16i16

        ; _exp_dc = cam_world_x - (gmap_cols * 8)
        lda     a:gmap_cols
        and     #$00FF
        asl
        asl
        asl
        sta     a:_exp_tmp
        lda     a:cam_world_x
        sec
        sbc     a:_exp_tmp
        sta     a:_exp_dc

        ; _exp_dr = cam_world_z - (gmap_rows * 8)
        lda     a:gmap_rows
        and     #$00FF
        asl
        asl
        asl
        sta     a:_exp_tmp
        lda     a:cam_world_z
        sec
        sbc     a:_exp_tmp
        sta     a:_exp_dr

        ; Load sign-extended cos31 -> _exp_v, sin31 -> Y (idx = cam_yaw_cur - 1)
        lda     a:cam_yaw_cur
        dec
        cmp     #120
        bcc     :+
        lda     #$0000
:       tax

        RW a8
        lda     f:CAM_COS_31, x
        bpl     @cos_pos
        RW a16
        ora     #$FF00
        bra     @cos_ok
@cos_pos:
        RW_forced a16i16
        and     #$00FF
@cos_ok:
        sta     a:_exp_v

        RW a8
        lda     f:CAM_SIN_31, x
        bpl     @sin_pos
        RW a16
        ora     #$FF00
        bra     @sin_ok
@sin_pos:
        RW_forced a16i16
        and     #$00FF
@sin_ok:
        tay

        ; --- dx = (dc * cos31 - dr * sin31) >> 4 ---
        lda     a:_exp_dc
        sta     a:_exp_tmp
        lda     a:_exp_v
        jsr     _exp_mul_s8_s8
        pha

        lda     a:_exp_dr
        sta     a:_exp_tmp
        tya
        jsr     _exp_mul_s8_s8
        sta     a:_exp_tmp
        pla
        sec
        sbc     a:_exp_tmp
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        sta     a:_exp_tmp
        lda     #CAM_CENTER_X_DEFAULT
        sec
        sbc     a:_exp_tmp
        sta     a:cam_center_x

        ; --- dy = (dc * sin31 + dr * cos31) >> 5 ---
        lda     a:_exp_dc
        sta     a:_exp_tmp
        tya
        jsr     _exp_mul_s8_s8
        pha

        lda     a:_exp_dr
        sta     a:_exp_tmp
        lda     a:_exp_v
        jsr     _exp_mul_s8_s8
        sta     a:_exp_tmp
        pla
        clc
        adc     a:_exp_tmp
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        sta     a:_exp_tmp
        lda     #CAM_CENTER_Y_DEFAULT
        sec
        sbc     a:_exp_tmp
        sta     a:cam_center_y

        ; Hybrid 3D Mesh stages (`gmap_is_mesh != 0`) can have non-zero floor Y
        ; (e.g. Orbonne courtyard y = -130px). Shift `cam_center_y` by
        ; `+(y_px * 7/8)` so the player's standing elevation stays centered at Y ~ 96.
        RW a8
        lda     a:gmap_is_mesh
        beq     @cam_y_ready
        RW a16
        lda     a:player_row
        and     #$00FF
        tay
        RW a8
        lda     a:player_col
        jsr     gmap_cell_index         ; X = cell_idx (0..255)
        RW a16
        txa
        asl
        tax                             ; X = cell_idx * 2
        lda     f:gmap_mesh_y_grid, x   ; signed Q10.6 floor Y
        cmp     #$8000
        beq     @cam_y_mesh_done
        ; y_px = arithmetic_shift_right(y_q106, 6)
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        sta     a:_exp_u                ; _exp_u = y_px (signed)
        ; y_bias = y_px - (y_px >> 3) ~= 0.875 * y_px
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        cmp     #$8000
        ror
        sta     a:_exp_tmp
        lda     a:_exp_u
        sec
        sbc     a:_exp_tmp
        clc
        adc     a:cam_center_y
        sta     a:cam_center_y
@cam_y_mesh_done:
        RW a8
@cam_y_ready:
        lda     #$01
        sta     a:cam_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; explore_snap_camera_to_player
; Immediately locks `(cam_world_x, cam_world_z)` to the player's continuous
; world `(x, z)` and projects to `(cam_center_x, cam_center_y)`.
; ------------------------------------------------------------------------------
explore_snap_camera_to_player:
        php
        RW_forced a16i16
        jsr     _exp_compute_player_world_xz
        lda     a:_exp_target_wx
        sta     a:cam_world_x
        lda     a:_exp_target_wz
        sta     a:cam_world_z
        jsr     _exp_project_cam_world_to_screen
        plp
        rts

; ------------------------------------------------------------------------------
; explore_update_camera_follow
; Smoothly follows the player's continuous world `(x, z)` coordinate (Q8.4)
; instead of screen `(x, y)`, eliminating jaunty screen-space bounce.
; ------------------------------------------------------------------------------
explore_update_camera_follow:
        php
        RW_forced a16i16
        jsr     _exp_compute_player_world_xz

        ; Ease cam_world_x toward _exp_target_wx in world X space
        lda     a:_exp_target_wx
        sec
        sbc     a:cam_world_x
        beq     @check_z
        bmi     @wx_neg
        cmp     #CAM_WORLD_FOLLOW_STEP
        bcc     :+
        lda     #CAM_WORLD_FOLLOW_STEP
:       clc
        adc     a:cam_world_x
        sta     a:cam_world_x
        bra     @check_z
@wx_neg:
        cmp     #($10000 - CAM_WORLD_FOLLOW_STEP)
        bcs     :+
        lda     #($10000 - CAM_WORLD_FOLLOW_STEP)
:       clc
        adc     a:cam_world_x
        sta     a:cam_world_x

@check_z:
        ; Ease cam_world_z toward _exp_target_wz in world Z space
        lda     a:_exp_target_wz
        sec
        sbc     a:cam_world_z
        beq     @project
        bmi     @wz_neg
        cmp     #CAM_WORLD_FOLLOW_STEP
        bcc     :+
        lda     #CAM_WORLD_FOLLOW_STEP
:       clc
        adc     a:cam_world_z
        sta     a:cam_world_z
        bra     @project
@wz_neg:
        cmp     #($10000 - CAM_WORLD_FOLLOW_STEP)
        bcs     :+
        lda     #($10000 - CAM_WORLD_FOLLOW_STEP)
:       clc
        adc     a:cam_world_z
        sta     a:cam_world_z

@project:
        jsr     _exp_project_cam_world_to_screen
        plp
        rts

; ------------------------------------------------------------------------------
; explore_move_tick
; Called once per 60fps tick when `game_state == STATE_EXPLORE`.
; Handles 12-frame cell-to-cell glide, yaw-relative D-pad stepping, and
; smooth camera follow.
; ------------------------------------------------------------------------------
explore_move_tick:
        php
        RW_forced a8i16

        ; 1. If currently gliding between cells, advance 12-frame interpolation
        lda     a:player_move_anim_timer
        beq     @check_dpad

        dec
        sta     a:player_move_anim_timer
        beq     @glide_finished

        ; Walk frame toggle (0 <-> 1 every 4 frames)
        lsr
        lsr
        and     #$01
        sta     a:player_sprite_id

        ; Update sub-pixel offset
        lda     a:player_move_anim_timer
        ldy     #$0000
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
        brl     @update_cam

@glide_finished:
        stz     a:player_sprite_id
        stz     a:player_sub_x
        stz     a:player_sub_x + 1
        stz     a:player_sub_y
        stz     a:player_sub_y + 1
        brl     @update_cam

        ; 2. Read held D-pad (SFX_joy1cont + 1: UP=$08, DOWN=$04, LEFT=$02, RIGHT=$01)
@check_dpad:
        lda     z:SFX_joy1cont + 1
        bit     #>JOY_UP
        bne     @dpad_up
        bit     #>JOY_RIGHT
        bne     @dpad_right
        bit     #>JOY_DOWN
        bne     @dpad_down
        bit     #>JOY_LEFT
        bne     @dpad_left
        brl     @update_cam

@dpad_up:
        lda     #$00
        sta     a:_exp_dpad_dir
        stz     a:player_hflip
        bra     @map_yaw
@dpad_right:
        lda     #$01
        sta     a:_exp_dpad_dir
        stz     a:player_hflip
        bra     @map_yaw
@dpad_down:
        lda     #$02
        sta     a:_exp_dpad_dir
        lda     #$01
        sta     a:player_hflip
        bra     @map_yaw
@dpad_left:
        lda     #$03
        sta     a:_exp_dpad_dir
        lda     #$01
        sta     a:player_hflip

        ; 3. Convert screen D-pad direction -> world direction via active yaw quadrant:
        ;    world_dir = (dpad_dir - quadrant) & 3
@map_yaw:
        jsr     explore_get_cam_quadrant
        sta     a:_exp_quad
        lda     a:_exp_dpad_dir
        sec
        sbc     a:_exp_quad
        and     #$03
        sta     a:_exp_world_dir
        sta     a:player_facing

        ; Compute target (col, row)
        RW a16
        and     #$0003
        tax
        RW a8
        lda     a:player_col
        clc
        adc     f:DIR_DCOL, x
        sta     a:gmap_arg_col
        lda     a:player_row
        clc
        adc     f:DIR_DROW, x
        sta     a:gmap_arg_row

        lda     a:player_col
        sta     a:gmap_arg_from_col
        lda     a:player_row
        sta     a:gmap_arg_from_row
        lda     #$FF
        sta     a:gmap_arg_ignore_npc
        stz     a:gmap_arg_check_player

        jsr     gmap_is_cell_passable
        bcc     @update_cam             ; Blocked -> turn in place, don't move

        ; 4. Commit step & start 12-frame smooth interpolation
        lda     a:player_col
        sta     a:player_move_from_col
        lda     a:player_row
        sta     a:player_move_from_row
        lda     a:gmap_arg_col
        sta     a:player_col
        lda     a:gmap_arg_row
        sta     a:player_row

        lda     a:_exp_dpad_dir
        sta     a:player_move_screen_dir
        lda     #PLAYER_MOVE_ANIM_FRAMES
        sta     a:player_move_anim_timer
        lda     #$01
        sta     a:player_sprite_id

        ; Seed initial sub_x/sub_y immediately so there is zero 1-frame pop
        RW a16
        lda     a:_exp_dpad_dir
        and     #$0003
        tay
        RW a8
        lda     #PLAYER_MOVE_ANIM_FRAMES
        jsr     explore_compute_sub_offset
        RW a16
        lda     a:exp_out_sub_x
        sta     a:player_sub_x
        lda     a:exp_out_sub_y
        sta     a:player_sub_y
        RW a8

@update_cam:
        jsr     explore_update_camera_follow
        plp
        rts

.endif ; __ISORPG_EXPLORE_MOVE__
