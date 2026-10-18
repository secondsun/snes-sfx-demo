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

.endif

