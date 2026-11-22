; ==============================================================================
; input_router.i - Global Camera Yaw Snap & Focus Input Router
;
; Part of IsoRPGDemo (Epic #30 / Issue #38).
; Responsibilities:
;   1. Smooth 90-degree cardinal camera yaw snaps on `L` (-30 steps) and `R`
;      (+30 steps) across yaw indices 1..120 (3 deg/step). ALWAYS active during
;      exploration and battle regardless of `ui_focus` (disabled only on Title
;      and Game Over).
;   2. `SELECT` focus toggle between `STATE_EXPLORE` (FOCUS_ISOMAP) and
;      `STATE_EXPLORE_MENU` (FOCUS_SIDE_MENU). Locked out during battle.
;   3. Publishes 65816 camera state into `GSU_SCENE_DESC` in Bank $70 GSURAM.
; ==============================================================================

.ifndef __ISORPG_INPUT_ROUTER__
__ISORPG_INPUT_ROUTER__ = 1

.include "../gsu_iso/scene_descriptor.i"

; ------------------------------------------------------------------------------
; Camera Constants (1..120 yaw index, 3 deg/step; 90 deg = 30 steps)
; ------------------------------------------------------------------------------
CAM_YAW_DEFAULT             = 15    ; Classic 45-deg isometric diamond view (Stage 0)
CAM_YAW_ORBONNE             = 75    ; Orbonne Monastery cathedral front view (Stage 1)
CAM_YAW_MIN                 = 1
CAM_YAW_MAX                 = 120
CAM_YAW_CARDINAL_STEP       = 30    ; 90 degrees (30 * 3 deg)
CAM_YAW_EASE_LEN            = 15    ; 15 frames (0.25s @ 60fps) ease-in/ease-out

CAM_CENTER_X_DEFAULT        = 96    ; Center of 192px BG1 viewport
CAM_CENTER_Y_DEFAULT        = 96    ; Vertical framing for isometric terrain

; ------------------------------------------------------------------------------
; LORAM Camera State
; ------------------------------------------------------------------------------
.segment "LORAM"
cam_yaw_cur:                .res 2  ; Active camera yaw index (1..120)
cam_yaw_target:             .res 2  ; Target cardinal yaw index (1..120)
cam_yaw_dir:                .res 1  ; 0 = idle, $01 = CW (+), $FF = CCW (-)
cam_yaw_anim_idx:           .res 1  ; Ease curve index (0..CAM_YAW_EASE_LEN)
_cam_yaw_step:              .res 2  ; Scratch step for current frame
cam_center_x:               .res 2  ; Screen focal X (default 96)
cam_center_y:               .res 2  ; Screen focal Y (default 96)
cam_dirty:                  .res 1  ; Non-zero when camera changed

.export cam_yaw_cur, cam_yaw_target, cam_yaw_dir, cam_center_x, cam_center_y, cam_dirty

; ------------------------------------------------------------------------------
; WRAM-Resident Routines (`MAIN_LOOP` -> HIRAM, 100% GSU-bus-safe)
; ------------------------------------------------------------------------------
.segment "MAIN_LOOP"

; Symmetric 15-frame (0.25s) ease-in / ease-out curve summing to 30 yaw steps (90 deg)
CAM_YAW_EASE_STEPS:         .byte 1, 1, 1, 2, 2, 3, 3, 4, 3, 3, 2, 2, 1, 1, 1

; ------------------------------------------------------------------------------
; input_router_init
; Resets isometric camera to default 45-deg diamond view (yaw=15, 96x96).
; ------------------------------------------------------------------------------
input_router_init:
        php
        RW_forced a8i16
        lda     a:active_stage_idx
        bne     @yaw_orbonne
        RW a16
        lda     #CAM_YAW_DEFAULT
        bra     @set_yaw
@yaw_orbonne:
        RW_forced a16i16
        lda     #CAM_YAW_ORBONNE
@set_yaw:
        sta     a:cam_yaw_cur
        sta     a:cam_yaw_target
        lda     #CAM_CENTER_X_DEFAULT
        sta     a:cam_center_x
        lda     #CAM_CENTER_Y_DEFAULT
        sta     a:cam_center_y
        RW a8
        stz     a:cam_yaw_dir
        stz     a:cam_yaw_anim_idx
        lda     #$01
        sta     a:cam_dirty
        plp
        rts

; ------------------------------------------------------------------------------
; input_router_tick
; Call once per 60fps logic tick before `game_state_tick`.
; ------------------------------------------------------------------------------
input_router_tick:
        php
        RW_forced a8i16

        ; Inactive on Title Screen & Game Over
        jsr     game_state_is_active_world
        bcs     :+
        brl     @done
:
        ; ------------------------------------------------------------------
        ; 1. Global L / R Smooth 90-deg Cardinal Camera Yaw Snap
        ;    Active in BOTH FOCUS_ISOMAP and FOCUS_SIDE_MENU (explore & battle)
        ; ------------------------------------------------------------------
        lda     z:SFX_joy1trig          ; Low byte: A($80) X($40) L($20) R($10)
        bit     #<JOY_L
        beq     @check_r

        ; L pressed: target -= 30 (wrap 1..120)
        RW a16
        lda     a:cam_yaw_target
        sec
        sbc     #CAM_YAW_CARDINAL_STEP
        beq     @l_wrap
        bpl     @l_store
@l_wrap:
        clc
        adc     #CAM_YAW_MAX
@l_store:
        sta     a:cam_yaw_target
        RW a8
        lda     #$FF
        sta     a:cam_yaw_dir
        stz     a:cam_yaw_anim_idx
        bra     @step_yaw

@check_r:
        lda     z:SFX_joy1trig
        bit     #<JOY_R
        beq     @step_yaw

        ; R pressed: target += 30 (wrap 1..120)
        RW a16
        lda     a:cam_yaw_target
        clc
        adc     #CAM_YAW_CARDINAL_STEP
        cmp     #(CAM_YAW_MAX + 1)
        bcc     @r_store
        sec
        sbc     #CAM_YAW_MAX
@r_store:
        sta     a:cam_yaw_target
        RW a8
        lda     #$01
        sta     a:cam_yaw_dir
        stz     a:cam_yaw_anim_idx

        ; ------------------------------------------------------------------
        ; 2. Smoothly Interpolate cam_yaw_cur Toward cam_yaw_target (Ease Curve)
        ; ------------------------------------------------------------------
@step_yaw:
        RW_forced a16i16
        lda     a:cam_yaw_cur
        cmp     a:cam_yaw_target
        bne     @do_step
        brl     @yaw_settled

@do_step:
        ; Look up ease-curve step (fallback 3 if multi-tap exceeds 15 frames)
        RW a8
        lda     a:cam_yaw_anim_idx
        cmp     #CAM_YAW_EASE_LEN
        bcc     @lut_step
        RW a16
        lda     #$0003
        bra     @have_step
@lut_step:
        RW_forced a16i16
        and     #$00FF
        tax
        lda     f:CAM_YAW_EASE_STEPS, x
        and     #$00FF
        RW a8
        inc     a:cam_yaw_anim_idx
        RW a16
@have_step:
        sta     a:_cam_yaw_step

        RW a8
        lda     a:cam_yaw_dir
        bmi     @step_ccw

        ; CW: remaining = (target - cur) mod 120; clamp step to remaining
        RW a16
        lda     a:cam_yaw_target
        sec
        sbc     a:cam_yaw_cur
        bpl     :+
        clc
        adc     #CAM_YAW_MAX
:       cmp     a:_cam_yaw_step
        bcs     :+
        sta     a:_cam_yaw_step
:       lda     a:cam_yaw_cur
        clc
        adc     a:_cam_yaw_step
        cmp     #(CAM_YAW_MAX + 1)
        bcc     @commit_yaw
        sec
        sbc     #CAM_YAW_MAX
        bra     @commit_yaw

@step_ccw:
        ; CCW: remaining = (cur - target) mod 120; clamp step to remaining
        RW_forced a16i16
        lda     a:cam_yaw_cur
        sec
        sbc     a:cam_yaw_target
        bpl     :+
        clc
        adc     #CAM_YAW_MAX
:       cmp     a:_cam_yaw_step
        bcs     :+
        sta     a:_cam_yaw_step
:       lda     a:cam_yaw_cur
        sec
        sbc     a:_cam_yaw_step
        beq     @ccw_wrap
        bpl     @commit_yaw
@ccw_wrap:
        clc
        adc     #CAM_YAW_MAX

@commit_yaw:
        sta     a:cam_yaw_cur
        cmp     a:cam_yaw_target
        bne     @mark_dirty
        RW_forced a8i16
        stz     a:cam_yaw_dir
        stz     a:cam_yaw_anim_idx
        jsr     explore_snap_camera_to_player
        lda     #$01
        sta     a:cam_dirty
        bra     @check_select

@mark_dirty:
        RW_forced a8i16
        jsr     explore_snap_camera_to_player
        lda     #$01
        sta     a:cam_dirty
        bra     @check_select

@yaw_settled:
        RW_forced a8i16
        stz     a:cam_yaw_dir
        stz     a:cam_yaw_anim_idx

        ; ------------------------------------------------------------------
        ; 3. SELECT Focus Toggle (Exploration Only; Locked Out During Battle)
        ; ------------------------------------------------------------------
@check_select:
        jsr     game_state_is_battle
        bcs     @done                   ; Battle owns focus transitions

        lda     z:SFX_joy1trig + 1
        bit     #>JOY_SELECT
        beq     @done

        lda     a:game_state
        cmp     #STATE_EXPLORE
        bne     @check_from_menu
        lda     #STATE_EXPLORE_MENU
        jsr     game_state_enter
        bra     @done

@check_from_menu:
        cmp     #STATE_EXPLORE_MENU
        bne     @done
        lda     #STATE_EXPLORE
        jsr     game_state_enter

@done:
        plp
        rts

; ------------------------------------------------------------------------------
; input_router_publish_descriptor
; Writes current 65816 camera & viewport fields into Bank-$70 `GSU_SCENE_DESC`.
; MUST be called only while GSU is stopped (`gsuRunning == 0`).
; ------------------------------------------------------------------------------
input_router_publish_descriptor:
        php
        RW_forced a16i16
        lda     a:cam_yaw_cur
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::cam_yaw
        lda     a:cam_center_x
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::cam_center_x
        lda     a:cam_center_y
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::cam_center_y
        lda     a:cam_dirty
        and     #$00FF
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::cam_dirty
        lda     #GSU_VIEWPORT_W_192
        sta     f:GSU_SCENE_DESC + gsu_scene_descriptor::viewport_width
        RW a8
        stz     a:cam_dirty
        plp
        rts

.endif ; __ISORPG_INPUT_ROUTER__
