; SuperFX
; Summers Pittman <secondsun@gmail.com>
; Analytical 30-degree Orbital-Isometric Camera Projection
;

.ifndef ::__GSU_ISO_CAMERA_DEFINED__
::__GSU_ISO_CAMERA_DEFINED__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"
.include "../common/structs.i"
.include "../common/control.i"
.include "./gsu_trig.i"

.segment "GSUCODE"

; Updates an iso_camera struct with a new yaw angle index (1..120) and caches sin/cos.
; In:       cam_ptr = address of iso_camera struct in GSURAM
;           yaw_idx = angle index (1..120, 3 degrees per step)
; Out:      Writes yaw, sin_yaw, and cos_yaw (in Q2.14) to cam_ptr
; Clobbers: r0, r14, allocated registers
function iso_camera_set_yaw cam_ptr, yaw_idx
    register trig_val, ptr

    move ptr, cam_ptr
    from yaw_idx
    stw (ptr) ; iso_camera::yaw (+0)

    sin_lookup_rom yaw_idx, trig_val
    inc ptr
    inc ptr
    from trig_val
    stw (ptr) ; iso_camera::sin_yaw (+2)

    cos_lookup_rom yaw_idx, trig_val
    inc ptr
    inc ptr
    from trig_val
    stw (ptr) ; iso_camera::cos_yaw (+4)

    return
endfunction

; Projects a single 3D Q8.8 vertex into 2D integer screen coordinates
; using a 30-degree orbital-isometric camera:
;   X_screen = center_x + round(x * cos(yaw) - z * sin(yaw))
;   Y_screen = center_y + round((x * sin(yaw) + z * cos(yaw)) / 2 - y * cos(30 deg))
; In:       cam_ptr    = address of iso_camera struct
;           v3_ptr     = address of input vector3 (Q8.8)
;           v2_out_ptr = address of output vector2 (integer pixels)
; Out:      Writes projected 2D integer coordinates (xPos, yPos) to v2_out_ptr
; Clobbers: r0, r6, allocated registers
function iso_camera_project_vertex cam_ptr, v3_ptr, v2_out_ptr
    register mul_b = r6, vx, vy, vz, x_acc, y_acc

    ; 1. Load 3D vertex (vx, vy, vz) in Q8.8
    to vx
    ldw (v3_ptr)
    inc v3_ptr
    inc v3_ptr
    to vy
    ldw (v3_ptr)
    inc v3_ptr
    inc v3_ptr
    to vz
    ldw (v3_ptr)

    ; 2. Advance cam_ptr to sin_yaw (+2) and load into r6 (mul_b)
    inc cam_ptr
    inc cam_ptr
    to mul_b
    ldw (cam_ptr) ; mul_b = sin_yaw (Q2.14)

    ; x_acc = (z * sin_yaw) in Q10.6
    from vz
    to x_acc
    fmult

    ; y_acc = (x * sin_yaw) in Q10.6
    from vx
    to y_acc
    fmult

    ; 3. Advance cam_ptr to cos_yaw (+4) and load into r6 (mul_b)
    inc cam_ptr
    inc cam_ptr
    to mul_b
    ldw (cam_ptr) ; mul_b = cos_yaw (Q2.14)

    ; x_acc = (x * cos_yaw) - (z * sin_yaw) in Q10.6
    from vx
    fmult
    sub x_acc
    move x_acc, r0

    ; y_acc = ((x * sin_yaw) + (z * cos_yaw)) >> 1 in Q10.6 (sin 30 deg = 0.5)
    from vz
    fmult
    with y_acc
    add r0
    with y_acc
    asr

    ; 4. Subtract y * cos(30 deg), where cos(30 deg) = $376D in Q2.14
    iwt mul_b, #$376D
    from vy
    fmult
    with y_acc
    sub r0

    ; 5. Convert x_acc (Q10.6 -> Q8.8, round +$0080, hib, sex) and add center_x (+6)
    iwt r0, #$0080
    with x_acc
    add x_acc
    with x_acc
    add x_acc
    with x_acc
    add r0
    with x_acc
    hib
    with x_acc
    sex

    inc cam_ptr
    inc cam_ptr
    ldw (cam_ptr) ; r0 = center_x
    with x_acc
    add r0
    from x_acc
    stw (v2_out_ptr)

    ; 6. Convert y_acc (Q10.6 -> Q8.8, round +$0080, hib, sex) and add center_y (+8)
    iwt r0, #$0080
    with y_acc
    add y_acc
    with y_acc
    add y_acc
    with y_acc
    add r0
    with y_acc
    hib
    with y_acc
    sex

    inc cam_ptr
    inc cam_ptr
    ldw (cam_ptr) ; r0 = center_y
    with y_acc
    add r0
    inc v2_out_ptr
    inc v2_out_ptr
    from y_acc
    stw (v2_out_ptr)

    return
endfunction

; Projects an array of 3D Q8.8 vertices into an array of 2D integer screen vertices.
; In:       cam_ptr         = address of iso_camera struct
;           v3_list_ptr     = address of input vector3 array
;           v2_out_list_ptr = address of output vector2 array
;           vertex_count    = number of vertices to project
; Out:      Writes vertex_count vector2 entries to v2_out_list_ptr
; Clobbers: r0, r6, r12, r13, allocated registers
function iso_camera_project_mesh cam_ptr, v3_list_ptr, v2_out_list_ptr, vertex_count
    forR vertex_count
        call iso_camera_project_vertex cam_ptr, v3_list_ptr, v2_out_list_ptr
        with v3_list_ptr
        add #.sizeof(vector3)
        with v2_out_list_ptr
        add #.sizeof(vector2)
    endfor
    return
endfunction

; Updates an iso_camera struct based on controller inputs:
;   - L / R buttons rotate yaw continuously (1 yaw index = 3 degrees per frame)
;     R increments yaw (clockwise), L decrements yaw (counter-clockwise)
;     Wraps yaw in range 1..120
;   - D-pad translates camera around screen plane at 2 pixels/frame:
;     Up:    Scene moves down (center_y += 2)
;     Down:  Scene moves up   (center_y -= 2)
;     Left:  Scene moves right(center_x += 2)
;     Right: Scene moves left (center_x -= 2)
;   - Clamps lookAt/center to a bounding box (+/-128 pixels from model center 128, 80):
;     center_x in [0, 256]
;     center_y in [-48, 208]
; In:       cam_ptr = address of iso_camera struct
;           pad_val = 16-bit joypad mask (e.g. from SFX_joy1cont)
; Out:      Updates ISO_CAM yaw, sin_yaw, cos_yaw, center_x, center_y
; Clobbers: r0, r6, r14, allocated registers
function iso_camera_update_controls cam_ptr, pad_val
    register yaw, cx, cy, tmp, mask, ptr, yaw_changed

    iwt yaw_changed, #0

    ; --- 1. Rotation (L / R) ---
    to yaw
    ldw (cam_ptr)

    ; Check R button ($0010) -> Clockwise (yaw++)
    iwt mask, #$0010
    from pad_val
    and mask
    beq check_l
    nop
    inc yaw
    iwt tmp, #121
    from yaw
    sub tmp
    bmi r_in_range
    nop
    iwt yaw, #1
r_in_range:
    iwt yaw_changed, #1
    bra check_yaw_done
    nop

check_l:
    ; Check L button ($0020) -> Counter-Clockwise (yaw--)
    iwt mask, #$0020
    from pad_val
    and mask
    beq check_yaw_done
    nop
    dec yaw
    with yaw
    add #0
    bne l_in_range
    nop
    iwt yaw, #120
l_in_range:
    iwt yaw_changed, #1

check_yaw_done:
    with yaw_changed
    add #0
    beq no_yaw_update
    nop
    call iso_camera_set_yaw cam_ptr, yaw
no_yaw_update:

    ; --- 2. Translation (D-pad) ---
    ; Load center_x (+6) and center_y (+8)
    move ptr, cam_ptr
    with ptr
    add #6
    to cx
    ldw (ptr)
    inc ptr
    inc ptr
    to cy
    ldw (ptr)

    ; D-pad UP ($0800): Move up -> cy -= 2
    iwt mask, #$0800
    from pad_val
    and mask
    beq check_down
    nop
    with cy
    sub #2

check_down:
    ; D-pad DOWN ($0400): Move down -> cy += 2
    iwt mask, #$0400
    from pad_val
    and mask
    beq check_left
    nop
    with cy
    add #2

check_left:
    ; D-pad LEFT ($0200): Move left -> cx -= 2
    iwt mask, #$0200
    from pad_val
    and mask
    beq check_right
    nop
    with cx
    sub #2

check_right:
    ; D-pad RIGHT ($0100): Move right -> cx += 2
    iwt mask, #$0100
    from pad_val
    and mask
    beq clamp_bounds
    nop
    with cx
    add #2

clamp_bounds:
    ; Clamp center_x: [0, 256] (128 +/- 128)
    iwt tmp, #0
    if_lt cx, tmp, { move cx, tmp }
    iwt tmp, #256
    if_gt cx, tmp, { move cx, tmp }

    ; Clamp center_y: [-48, 208] (80 +/- 128)
    iwt tmp, #$FFD0 ; -48 in 16-bit signed
    if_lt cy, tmp, { move cy, tmp }
    iwt tmp, #208
    if_gt cy, tmp, { move cy, tmp }

    ; Store center_x and center_y back to ISO_CAM
    move ptr, cam_ptr
    with ptr
    add #6
    from cx
    stw (ptr)
    inc ptr
    inc ptr
    from cy
    stw (ptr)

    return
endfunction

.endif

