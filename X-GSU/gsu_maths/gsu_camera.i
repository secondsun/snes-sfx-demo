; SuperFX
; Summers Pittman <secondsun@gmail.com>
; Matrix utility functions
;
.ifndef ::__GSU_MATRIX_DEFINED__
::__GSU_MATRIX_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"
.include "./gsu_sqrt.i"
.include "./gsu_vector.i"
.include "./gsu_recip.i"

;Calculates LOOKAT_MATRIX from CAMERA
; This operates on Static values and has no input/output
; Clobbers : All
function lookAt:
    ;zaxis = Math.normalize(lookAt.subtract(eye));    
    iwt r0, #(CAMERA + camera::eye)
    sm (VECTOR_SUBTRACT_IN), r0
    iwt r0, #(CAMERA + camera::lookAt)
    call vector3_subtract
    move r0,r3
    call vector3_normalize
    
    iwt r0, #(LOOKAT_ZAXIS)
    sm (COPY_IN),r0
    move r0,r3
    ;copy the normalized vector to ZAXIS @r0 = @copy_in
    call vector3_copy

    ;xaxis = Math.normalize(zaxis.cross(up));
    iwt r0, #(CAMERA + camera::up)
    sm (VECTOR_CROSS_IN), r0
    iwt r0, #(LOOKAT_ZAXIS)
    call vector3_cross
    move r0,r3
    call vector3_normalize
    sm (LOOKAT_XAXIS), r3

    ;yaxis = xaxis.cross(zaxis);
    
    iwt r0, #(LOOKAT_ZAXIS)
    sm (VECTOR_CROSS_IN), r0
    iwt r0, #(LOOKAT_XAXIS)
    call vector3_cross
    sm (LOOKAT_YAXIS), r3

    ;zaxis = zaxis.negate();
    iwt r0, #(LOOKAT_ZAXIS)
    call vector3_negate
    sm (LOOKAT_ZAXIS), r3


    return
endfunction

.endif