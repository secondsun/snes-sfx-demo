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

;Calculates LOOKAT_MATRIX from CAMERA
; This operates on Static values and has no input/output
; Clobbers : All
function camera_lookAt
    ;zaxis = Math.normalize(lookAt.subtract(eye));    
    iwt r0, #(CAMERA + camera::eye)
    sm (VECTOR_SUBTRACT_IN), r0
    iwt r0, #(CAMERA + camera::lookAt)
    call vector3_subtract
    move r0,r3
    call vector3_normalize
    
    iwt r0, #(__LOOKAT_ZAXIS__)
    sm (VECTOR_COPY_IN),r0
    move r0,r3
    ;copy the normalized vector to ZAXIS @r0 = @VECTOR_COPY_IN
    call vector3_copy
camera_lookAt_XAXIS:
    ;xaxis = Math.normalize(zaxis.cross(up));
    iwt r0, #(CAMERA + camera::up)
    sm (VECTOR_CROSS_IN), r0
    iwt r0, #(__LOOKAT_ZAXIS__)
    call vector3_cross
    move r0,r3
    call vector3_normalize
    
    iwt r0, #(__LOOKAT_XAXIS__)
    sm (VECTOR_COPY_IN),r0
    move r0,r3
    ;copy the normalized vector to ZAXIS @r0 = @VECTOR_COPY_IN
    call vector3_copy

    ;yaxis = xaxis.cross(zaxis);
    
    iwt r0, #(__LOOKAT_ZAXIS__)
    sm (VECTOR_CROSS_IN), r0
    iwt r0, #(__LOOKAT_XAXIS__)
    call vector3_cross
    
    iwt r0, #(__LOOKAT_YAXIS__)
    sm (VECTOR_COPY_IN),r0
    move r0,r3
    ;copy the normalized vector to YAXIS @r0 = @VECTOR_COPY_IN
    call vector3_copy

    ;zaxis = zaxis.negate();
    iwt r0, #(__LOOKAT_ZAXIS__)
    call vector3_negate
    
    iwt r0, #(__LOOKAT_ZAXIS__)
    sm (VECTOR_COPY_IN),r0
    move r0,r3
    ;copy the normalized vector to ZAXIS @r0 = @VECTOR_COPY_IN
    call vector3_copy

    iwt r0, #(CAMERA + camera::eye)
    sm (VECTOR_DOT_IN),r0
    iwt r0, #(__LOOKAT_XAXIS__)
    call vector3_dot

    fixed88_negate r3
    sm (LOOKAT_MATRIX + 6),r3


    iwt r0, #(__LOOKAT_YAXIS__)
    call vector3_dot

    fixed88_negate r3
    sm (LOOKAT_MATRIX + 14),r3

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