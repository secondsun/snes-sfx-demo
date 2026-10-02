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
; Out:      R3 = address of LOOKAT_MATRIX
; Clobbers: All
function camera_lookAt
    ;zaxis = Math.normalize(lookAt.subtract(eye));    
    iwt r0, #(CAMERA + camera::eye)
    iwt r3, #(CAMERA + camera::lookAt)
    call vector3_subtract
    move r0,r3
    call vector3_normalize
    
    iwt r2, #(__LOOKAT_ZAXIS__)
    move r0,r3
    ;copy the normalized vector to ZAXIS (r0=src, r2=dest)
    call vector3_copy
camera_lookAt_XAXIS:
    ;xaxis = Math.normalize(up.cross(zaxis));
    iwt r0, #(CAMERA + camera::up)
    iwt r1, #(__LOOKAT_ZAXIS__)
    call vector3_cross
    move r0,r3
    call vector3_normalize
    
    iwt r2, #(__LOOKAT_XAXIS__)
    move r0,r3
    ;copy the normalized vector to XAXIS (r0=src, r2=dest)
    call vector3_copy

    ;yaxis = xaxis.cross(zaxis);
    
    iwt r0, #(__LOOKAT_ZAXIS__)
    iwt r1, #(__LOOKAT_XAXIS__)
    call vector3_cross
    
    iwt r2, #(__LOOKAT_YAXIS__)
    move r0,r3
    ;copy the cross vector to YAXIS (r0=src, r2=dest)
    call vector3_copy

    iwt r0, #(__LOOKAT_XAXIS__)
    iwt r1, #(CAMERA + camera::eye)
    call vector3_dot

    fixed88_negate r3
    sm (LOOKAT_MATRIX + 6),r3

    iwt r0, #(__LOOKAT_YAXIS__)
    iwt r1, #(CAMERA + camera::eye)
    call vector3_dot

    fixed88_negate r3
    sm (LOOKAT_MATRIX + 14),r3

    iwt r1, #(CAMERA + camera::eye)
    iwt r0, #(__LOOKAT_ZAXIS__)
    call vector3_dot

    
    fixed88_negate r3
    sm (LOOKAT_MATRIX + 22),r3

    iwt r3, #0
    sm (LOOKAT_MATRIX + 24),r3
    sm (LOOKAT_MATRIX + 26),r3
    sm (LOOKAT_MATRIX + 28),r3
    iwt r3, #$100
    sm (LOOKAT_MATRIX + 30),r3

    iwt r3, #LOOKAT_MATRIX

    return
endfunction

.endif