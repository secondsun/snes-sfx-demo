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

; Updates center_x and center_y in iso_camera by rotating cam_x and cam_z around screen center (128, 80).
; In:       cam_ptr = address of iso_camera struct
; Out:      Writes updated center_x (+6) and center_y (+8)
; Clobbers: r0, r6, allocated registers
function iso_camera_sync_cam_to_screen cam_ptr
    register mul_b = r6, sin_val, cos_val, val1, val2, term, ptr

    ; Load sin_yaw (+2) and cos_yaw (+4)
    move ptr, cam_ptr
    inc ptr
    inc ptr
    to sin_val
    ldw (ptr)
    inc ptr
    inc ptr
    to cos_val
    ldw (ptr)

    ; Load cam_x (+10) into val1 and cam_z (+12) into val2
    move ptr, cam_ptr
    with ptr
    add #10
    to val1
    ldw (ptr)
    inc ptr
    inc ptr
    to val2
    ldw (ptr)

    ; dx_q4 = fmult(cam_x, cos) - fmult(cam_z, sin)
    move mul_b, cos_val
    from val1
    to term
    fmult

    move mul_b, sin_val
    from val2
    fmult

    with term
    sub r0

    ; Convert Q12.4 to integer pixel with +8 rounding and >> 4
    with term
    add #8
    with term
    asr
    with term
    asr
    with term
    asr
    with term
    asr

    ; cx = 128 + dx
    iwt r0, #128
    with term
    add r0

    ; Store center_x (+6)
    move ptr, cam_ptr
    with ptr
    add #6
    from term
    stw (ptr)

    ; dz_q4 = fmult(cam_x, sin) + fmult(cam_z, cos)
    move mul_b, sin_val
    from val1
    to term
    fmult

    move mul_b, cos_val
    from val2
    fmult

    with term
    add r0

    ; Convert Q12.4 to integer pixel with +8 rounding and >> 4
    with term
    add #8
    with term
    asr
    with term
    asr
    with term
    asr
    with term
    asr

    ; dy = dz >> 1
    with term
    asr

    ; cy = 80 + dy
    iwt r0, #80
    with term
    add r0

    ; Store center_y (+8)
    inc ptr
    inc ptr
    from term
    stw (ptr)

    return
endfunction

; Updates cam_x and cam_z in iso_camera from center_x and center_y relative to screen center (128, 80).
; In:       cam_ptr = address of iso_camera struct
; Out:      Writes updated cam_x (+10) and cam_z (+12)
; Clobbers: r0, r6, allocated registers
function iso_camera_sync_screen_to_cam cam_ptr
    register mul_b = r6, sin_val, cos_val, val1, val2, term, ptr

    ; Load sin_yaw (+2) and cos_yaw (+4)
    move ptr, cam_ptr
    inc ptr
    inc ptr
    to sin_val
    ldw (ptr)
    inc ptr
    inc ptr
    to cos_val
    ldw (ptr)

    ; Load center_x (+6) and center_y (+8)
    inc ptr
    inc ptr
    to val1
    ldw (ptr)
    inc ptr
    inc ptr
    to val2
    ldw (ptr)

    ; val1 = dx_q6 = (cx - 128) << 6
    iwt r0, #128
    with val1
    sub r0
    with val1
    add val1
    with val1
    add val1
    with val1
    add val1
    with val1
    add val1
    with val1
    add val1
    with val1
    add val1

    ; val2 = dz_q6 = ((cy - 80) * 2) << 6 = (cy - 80) << 7
    iwt r0, #80
    with val2
    sub r0
    with val2
    add val2
    with val2
    add val2
    with val2
    add val2
    with val2
    add val2
    with val2
    add val2
    with val2
    add val2
    with val2
    add val2

    ; cam_x = (fmult(dx, cos) + fmult(dz, sin)) << 2
    move mul_b, cos_val
    from val1
    to term
    fmult

    move mul_b, sin_val
    from val2
    fmult

    with term
    add r0
    with term
    add term
    with term
    add term

    ; Store cam_x (+10)
    move ptr, cam_ptr
    with ptr
    add #10
    from term
    stw (ptr)

    ; cam_z = (fmult(dz, cos) - fmult(dx, sin)) << 2
    move mul_b, cos_val
    from val2
    to term
    fmult

    move mul_b, sin_val
    from val1
    fmult

    with term
    sub r0
    with term
    add term
    with term
    add term

    ; Store cam_z (+12)
    inc ptr
    inc ptr
    from term
    stw (ptr)

    return
endfunction

; Updates an iso_camera struct based on controller inputs:
;   - L / R buttons rotate yaw continuously (1 yaw index = 3 degrees per frame)
;     R increments yaw (clockwise), L decrements yaw (counter-clockwise)
;     Wraps yaw in range 1..120
;     Rotates scene around the center of the screen (128, 80)
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
; Out:      Updates ISO_CAM yaw, sin_yaw, cos_yaw, center_x, center_y, cam_x, cam_z
; Clobbers: r0, r6, r14, allocated registers
function iso_camera_update_controls cam_ptr, pad_val
    register yaw, cx, cy, tmp, mask, ptr, yaw_changed, dpad_changed

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
    call iso_camera_sync_cam_to_screen cam_ptr
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

    iwt dpad_changed, #0

    ; D-pad UP ($0800): Move up -> cy -= 2
    iwt mask, #$0800
    from pad_val
    and mask
    beq check_down
    nop
    with cy
    sub #2
    iwt dpad_changed, #1

check_down:
    ; D-pad DOWN ($0400): Move down -> cy += 2
    iwt mask, #$0400
    from pad_val
    and mask
    beq check_left
    nop
    with cy
    add #2
    iwt dpad_changed, #1

check_left:
    ; D-pad LEFT ($0200): Move left -> cx -= 2
    iwt mask, #$0200
    from pad_val
    and mask
    beq check_right
    nop
    with cx
    sub #2
    iwt dpad_changed, #1

check_right:
    ; D-pad RIGHT ($0100): Move right -> cx += 2
    iwt mask, #$0100
    from pad_val
    and mask
    beq clamp_bounds
    nop
    with cx
    add #2
    iwt dpad_changed, #1

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

    with dpad_changed
    add #0
    beq no_dpad_sync
    nop
    call iso_camera_sync_screen_to_cam cam_ptr
no_dpad_sync:

    return
endfunction

; ==============================================================================
; 28-Point Canonical Lattice (LATTICE_V2) Constants
; ==============================================================================
LATTICE_C0          = 0   ; Base corner (0, 0, 0)
LATTICE_C1          = 1   ; Base corner (32, 0, 0)  = Sx
LATTICE_C2          = 2   ; Base corner (32, 0, 32) = Sx + Sz
LATTICE_C3          = 3   ; Base corner (0, 0, 32)  = Sz

LATTICE_SKIRT_C0    = 4   ; Skirt bottom y=-1h (+14px): C0 + (0, 14)
LATTICE_SKIRT_C1    = 5   ; Skirt bottom y=-1h (+14px): C1 + (0, 14)
LATTICE_SKIRT_C2    = 6   ; Skirt bottom y=-1h (+14px): C2 + (0, 14)
LATTICE_SKIRT_C3    = 7   ; Skirt bottom y=-1h (+14px): C3 + (0, 14)

LATTICE_ELEV1_C0    = 8   ; Elevated corner y=+1h (-14px): C0 + (0, -14)
LATTICE_ELEV1_C1    = 9   ; Elevated corner y=+1h (-14px): C1 + (0, -14)
LATTICE_ELEV1_C2    = 10  ; Elevated corner y=+1h (-14px): C2 + (0, -14)
LATTICE_ELEV1_C3    = 11  ; Elevated corner y=+1h (-14px): C3 + (0, -14)

LATTICE_ELEV2_C0    = 12  ; Elevated corner y=+2h (-28px): C0 + (0, -28)
LATTICE_ELEV2_C1    = 13  ; Elevated corner y=+2h (-28px): C1 + (0, -28)
LATTICE_ELEV2_C2    = 14  ; Elevated corner y=+2h (-28px): C2 + (0, -28)
LATTICE_ELEV2_C3    = 15  ; Elevated corner y=+2h (-28px): C3 + (0, -28)

LATTICE_MID_N       = 16  ; Canonical edge midpoint at y=0: MN = Sx/2
LATTICE_MID_E       = 17  ; Canonical edge midpoint at y=0: ME = Sx + Sz/2
LATTICE_MID_S       = 18  ; Canonical edge midpoint at y=0: MS = Sx/2 + Sz
LATTICE_MID_W       = 19  ; Canonical edge midpoint at y=0: MW = Sz/2

LATTICE_PILLAR_B0   = 20  ; Inset [8..24] pillar base at y=0: P0 = Sx/4 + Sz/4
LATTICE_PILLAR_B1   = 21  ; Inset [8..24] pillar base at y=0: P1 = P0 + Sx/2
LATTICE_PILLAR_B2   = 22  ; Inset [8..24] pillar base at y=0: P2 = P1 + Sz/2
LATTICE_PILLAR_B3   = 23  ; Inset [8..24] pillar base at y=0: P3 = P0 + Sz/2

LATTICE_PILLAR_T0   = 24  ; Inset [8..24] pillar top at +2h (-28px): P0 + (0, -28)
LATTICE_PILLAR_T1   = 25  ; Inset [8..24] pillar top at +2h (-28px): P1 + (0, -28)
LATTICE_PILLAR_T2   = 26  ; Inset [8..24] pillar top at +2h (-28px): P2 + (0, -28)
LATTICE_PILLAR_T3   = 27  ; Inset [8..24] pillar top at +2h (-28px): P3 + (0, -28)

LATTICE_POINT_COUNT = 28
LATTICE_V2_SIZE     = 28 * .sizeof(vector2) ; 112 bytes ($70)

; ==============================================================================
; iso_compute_basis
; Computes discrete integer basis vectors (Sx, Sz, Sy) from camera yaw_idx (1..120).
;   Sx = (round(32 * cos(yaw)), round(16 * sin(yaw)))
;   Sz = (round(-32 * sin(yaw)), round(16 * cos(yaw)))
;   Sy = (0, -14)
; In:       yaw_idx   = camera yaw index (1..120)
;           basis_ptr = address of iso_basis struct to populate
; Out:      Writes Sx, Sz, Sy to basis_ptr
; Clobbers: r0, r14, allocated registers
; ==============================================================================
function iso_compute_basis yaw_idx, basis_ptr
    register sin_val, cos_val, tmp, val, ptr

    move ptr, basis_ptr

    sin_lookup_rom yaw_idx, sin_val
    cos_lookup_rom yaw_idx, cos_val

    ; 1. Sx.x = round(32 * cos) = (cos_val + 256) asr 9
    iwt tmp, #256
    from cos_val
    add tmp
    move val, r0
    with val
    hib
    with val
    sex
    with val
    asr
    from val
    stw (ptr)
    inc ptr
    inc ptr

    ; 2. Sx.y = round(16 * sin) = (sin_val + 512) asr 10
    iwt tmp, #512
    from sin_val
    add tmp
    move val, r0
    with val
    hib
    with val
    sex
    with val
    asr
    with val
    asr
    from val
    stw (ptr)
    inc ptr
    inc ptr

    ; 3. Sz.x = round(-32 * sin) = - ((sin_val + 256) asr 9)
    iwt tmp, #256
    from sin_val
    add tmp
    move val, r0
    with val
    hib
    with val
    sex
    with val
    asr
    with val
    not
    inc val
    from val
    stw (ptr)
    inc ptr
    inc ptr

    ; 4. Sz.y = round(16 * cos) = (cos_val + 512) asr 10
    iwt tmp, #512
    from cos_val
    add tmp
    move val, r0
    with val
    hib
    with val
    sex
    with val
    asr
    with val
    asr
    from val
    stw (ptr)
    inc ptr
    inc ptr

    ; 5. Sy.x = 0
    iwt val, #0
    from val
    stw (ptr)
    inc ptr
    inc ptr

    ; 6. Sy.y = -14 ($FFF2)
    iwt val, #$FFF2
    from val
    stw (ptr)

    return
endfunction

; Helper to compute basis from an iso_camera struct
; In:       cam_ptr   = address of iso_camera struct
;           basis_ptr = address of iso_basis struct
function iso_camera_compute_basis cam_ptr, basis_ptr
    register yaw_val, c_ptr
    move c_ptr, cam_ptr
    to yaw_val
    ldw (c_ptr)
    call iso_compute_basis yaw_val, basis_ptr
    return
endfunction

; ==============================================================================
; iso_populate_lattice
; Populates the 28-point LATTICE_V2 in GSURAM purely via integer additions
; and arithmetic right shifts (zero multiplications).
; In:       basis_ptr   = address of iso_basis struct
;           lattice_ptr = destination buffer for 28 vector2 points (112 bytes)
; Out:      Writes 28 vector2 entries to lattice_ptr
; Clobbers: r0, allocated registers
; ==============================================================================
function iso_populate_lattice basis_ptr, lattice_ptr
    register b_ptr, lat_ptr, sx_x, sx_y, sz_x, sz_y, c2_x, c2_y, tmp, zero, h28
    register sx2_x, sx2_y, sz2_x, sz2_y, sx4_x, sx4_y, sz4_x, sz4_y
    register p0_x, p0_y, p1_x, p1_y, p2_x, p2_y, p3_x, p3_y

    move b_ptr, basis_ptr
    move lat_ptr, lattice_ptr
    iwt zero, #0
    iwt h28, #28

    ; Load Sx (x, y) and Sz (x, y)
    to sx_x
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    to sx_y
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    to sz_x
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    to sz_y
    ldw (b_ptr)

    ; Compute C2 = Sx + Sz
    from sx_x
    add sz_x
    move c2_x, r0

    from sx_y
    add sz_y
    move c2_y, r0

    ; ----------------------------------------------------
    ; Group 1: Base corners at y=0 (Indices 0..3)
    ; ----------------------------------------------------
    ; Index 0: C0 = (0, 0)
    from zero
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from zero
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 1: C1 = (Sx.x, Sx.y)
    from sx_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 2: C2 = (C2.x, C2.y)
    from c2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from c2_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 3: C3 = (Sz.x, Sz.y)
    from sz_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sz_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; ----------------------------------------------------
    ; Group 2: Skirt bottom corners at y=-1h (+14px) (Indices 4..7)
    ; ----------------------------------------------------
    ; Index 4: C0 + (0, 14) = (0, 14)
    from zero
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    iwt tmp, #14
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 5: C1 + (0, 14) = (Sx.x, Sx.y + 14)
    from sx_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx_y
    add #14
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 6: C2 + (0, 14) = (C2.x, C2.y + 14)
    from c2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from c2_y
    add #14
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 7: C3 + (0, 14) = (Sz.x, Sz.y + 14)
    from sz_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sz_y
    add #14
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; ----------------------------------------------------
    ; Group 3: Elevated corners at +1h (-14px) (Indices 8..11)
    ; ----------------------------------------------------
    ; Index 8: C0 + (0, -14) = (0, -14)
    from zero
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    iwt tmp, #$FFF2
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 9: C1 + (0, -14) = (Sx.x, Sx.y - 14)
    from sx_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx_y
    sub #14
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 10: C2 + (0, -14) = (C2.x, C2.y - 14)
    from c2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from c2_y
    sub #14
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 11: C3 + (0, -14) = (Sz.x, Sz.y - 14)
    from sz_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sz_y
    sub #14
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; ----------------------------------------------------
    ; Group 4: Elevated corners at +2h (-28px) (Indices 12..15)
    ; ----------------------------------------------------
    ; Index 12: C0 + (0, -28) = (0, -28)
    from zero
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    iwt tmp, #$FFE4
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 13: C1 + (0, -28) = (Sx.x, Sx.y - 28)
    from sx_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 14: C2 + (0, -28) = (C2.x, C2.y - 28)
    from c2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from c2_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 15: C3 + (0, -28) = (Sz.x, Sz.y - 28)
    from sz_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sz_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; ----------------------------------------------------
    ; Group 5: Canonical edge midpoints at y=0 (Indices 16..19)
    ; ----------------------------------------------------
    move sx2_x, sx_x
    with sx2_x
    asr
    move sx2_y, sx_y
    with sx2_y
    asr

    move sz2_x, sz_x
    with sz2_x
    asr
    move sz2_y, sz_y
    with sz2_y
    asr

    ; Index 16: MN = Sx/2
    from sx2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx2_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 17: ME = Sx + Sz/2
    from sx_x
    add sz2_x
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx_y
    add sz2_y
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 18: MS = Sx/2 + Sz
    from sx2_x
    add sz_x
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sx2_y
    add sz_y
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 19: MW = Sz/2
    from sz2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from sz2_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; ----------------------------------------------------
    ; Group 6 & 7: 8-Point Inset Pillar Ring (Indices 20..27)
    ; [8..24] x [8..24] pillar
    ; Base corners at y=0 (20..23), Top corners at +2h (24..27)
    ; ----------------------------------------------------
    move sx4_x, sx2_x
    with sx4_x
    asr
    move sx4_y, sx2_y
    with sx4_y
    asr

    move sz4_x, sz2_x
    with sz4_x
    asr
    move sz4_y, sz2_y
    with sz4_y
    asr

    ; P0 = Sx/4 + Sz/4
    from sx4_x
    add sz4_x
    move p0_x, r0

    from sx4_y
    add sz4_y
    move p0_y, r0

    ; P1 = P0 + Sx/2
    from p0_x
    add sx2_x
    move p1_x, r0

    from p0_y
    add sx2_y
    move p1_y, r0

    ; P2 = P1 + Sz/2
    from p1_x
    add sz2_x
    move p2_x, r0

    from p1_y
    add sz2_y
    move p2_y, r0

    ; P3 = P0 + Sz/2
    from p0_x
    add sz2_x
    move p3_x, r0

    from p0_y
    add sz2_y
    move p3_y, r0

    ; Index 20: P0 base
    from p0_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p0_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 21: P1 base
    from p1_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p1_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 22: P2 base
    from p2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p2_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 23: P3 base
    from p3_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p3_y
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 24: P0 top (+2h = -28px)
    from p0_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p0_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 25: P1 top (+2h = -28px)
    from p1_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p1_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 26: P2 top (+2h = -28px)
    from p2_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p2_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr

    ; Index 27: P3 top (+2h = -28px)
    from p3_x
    stw (lat_ptr)
    inc lat_ptr
    inc lat_ptr
    from p3_y
    sub h28
    move tmp, r0
    from tmp
    stw (lat_ptr)

    return
endfunction

; Helper alias for iso_populate_lattice
function iso_camera_populate_lattice basis_ptr, lattice_ptr
    call iso_populate_lattice basis_ptr, lattice_ptr
    return
endfunction

; ==============================================================================
; iso_cell_anchor
; Resolves the screen-space anchor of a map cell at (i, j, h):
;   Anchor(i, j, h) = MapOrigin_screen + i * Sx + j * Sz + h * Sy
; In:       origin_ptr     = address of vector2 origin (screen X, screen Y) or 0 for (0,0)
;           basis_ptr      = address of iso_basis struct
;           i_idx          = grid column (i)
;           j_idx          = grid row (j)
;           h_elev         = elevation height in 1h units (h)
;           out_anchor_ptr = destination vector2 address
; Out:      Writes Anchor.x, Anchor.y to out_anchor_ptr
; Clobbers: r0, r4, r6, allocated registers
; ==============================================================================
function iso_cell_anchor origin_ptr, basis_ptr, i_idx, j_idx, h_elev, out_anchor_ptr
    register mul_b = r6, term_x, term_y, tmp, b_ptr, out_ptr

    ; 1. Load origin if non-zero, else (0, 0)
    with origin_ptr
    add #0
    beq zero_orig
    nop

    to term_x
    ldw (origin_ptr)
    inc origin_ptr
    inc origin_ptr
    to term_y
    ldw (origin_ptr)
    bra orig_done
    nop

zero_orig:
    iwt term_x, #0
    iwt term_y, #0

orig_done:
    move b_ptr, basis_ptr

    ; 2. Add i * Sx: Sx.x at +0, Sx.y at +2
    move mul_b, i_idx
    to tmp
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    from tmp
    to tmp
    lmult
    with term_x
    add r4

    to tmp
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    from tmp
    to tmp
    lmult
    with term_y
    add r4

    ; 3. Add j * Sz: Sz.x at +4, Sz.y at +6
    move mul_b, j_idx
    to tmp
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    from tmp
    to tmp
    lmult
    with term_x
    add r4

    to tmp
    ldw (b_ptr)
    inc b_ptr
    inc b_ptr
    from tmp
    to tmp
    lmult
    with term_y
    add r4

    ; 4. Add h * Sy: Sy.y at +10 (Sy.x at +8 is 0)
    inc b_ptr
    inc b_ptr
    move mul_b, h_elev
    to tmp
    ldw (b_ptr)
    from tmp
    to tmp
    lmult
    with term_y
    add r4

    ; 5. Write to out_anchor_ptr
    move out_ptr, out_anchor_ptr
    from term_x
    stw (out_ptr)
    inc out_ptr
    inc out_ptr
    from term_y
    stw (out_ptr)

    return
endfunction

; Helper alias for iso_cell_anchor
function iso_camera_cell_anchor origin_ptr, basis_ptr, i_idx, j_idx, h_elev, out_anchor_ptr
    call iso_cell_anchor origin_ptr, basis_ptr, i_idx, j_idx, h_elev, out_anchor_ptr
    return
endfunction

.endif

