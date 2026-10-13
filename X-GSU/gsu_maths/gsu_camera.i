; SuperFX
; Summers Pittman <secondsun@gmail.com>
; CAMERA utility functions
;
.ifndef ::__GSU_CAMERA_DEFINED__
::__GSU_CAMERA_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"
.include "./gsu_sqrt.i"
.include "./gsu_vector.i"
.include "./gsu_recip.i"

; Negates a signed Q8.8 fixed-point number using two's complement (NOT + INC)
; In:       reg = register to negate (defaults to r0 if blank)
; Out:      reg (or r0) negated
; Clobbers: reg (or r0), flags
.macro fixed88_negate reg
    .if .not(.blank ({reg}))
		with reg
	.endif
    
    not
    
    .if (.blank ({reg}))
		inc r0
    .else    
        inc reg
	.endif
    
.endmacro    

; Computes a 4x4 LookAt view matrix from global CAMERA into LOOKAT_MATRIX
; In:       None (reads global CAMERA structure)
; Out:      out = address of LOOKAT_MATRIX
; Clobbers: All
function camera_lookAt : out
    register p1, p2, res, dot_val

    ;zaxis = Math.normalize(lookAt.subtract(eye));    
    iwt p1, #(CAMERA + camera::eye)
    iwt p2, #(CAMERA + camera::lookAt)
    call vector3_subtract p1, p2 : res
    call vector3_normalize res : res
    
    iwt p2, #(__LOOKAT_ZAXIS__)
    ;copy the normalized vector to ZAXIS
    call vector3_copy res, p2
camera_lookAt_XAXIS:
    ;xaxis = Math.normalize(up.cross(zaxis));
    iwt p1, #(CAMERA + camera::up)
    iwt p2, #(__LOOKAT_ZAXIS__)
    call vector3_cross p1, p2 : res
    call vector3_normalize res : res
    
    iwt p2, #(__LOOKAT_XAXIS__)
    ;copy the normalized vector to XAXIS
    call vector3_copy res, p2

    ;yaxis = xaxis.cross(zaxis);
    
    iwt p1, #(__LOOKAT_ZAXIS__)
    iwt p2, #(__LOOKAT_XAXIS__)
    call vector3_cross p1, p2 : res
    
    iwt p2, #(__LOOKAT_YAXIS__)
    ;copy the cross vector to YAXIS
    call vector3_copy res, p2

    iwt p1, #(__LOOKAT_XAXIS__)
    iwt p2, #(CAMERA + camera::eye)
    call vector3_dot p1, p2 : dot_val

    fixed88_negate dot_val
    sm (LOOKAT_MATRIX + 6), dot_val

    iwt p1, #(__LOOKAT_YAXIS__)
    iwt p2, #(CAMERA + camera::eye)
    call vector3_dot p1, p2 : dot_val

    fixed88_negate dot_val
    sm (LOOKAT_MATRIX + 14), dot_val

    iwt p2, #(CAMERA + camera::eye)
    iwt p1, #(__LOOKAT_ZAXIS__)
    call vector3_dot p1, p2 : dot_val

    
    fixed88_negate dot_val
    sm (LOOKAT_MATRIX + 22), dot_val

    iwt dot_val, #0
    sm (LOOKAT_MATRIX + 24), dot_val
    sm (LOOKAT_MATRIX + 26), dot_val
    sm (LOOKAT_MATRIX + 28), dot_val
    iwt dot_val, #$100
    sm (LOOKAT_MATRIX + 30), dot_val

    iwt out, #LOOKAT_MATRIX

    return out
endfunction

.endif