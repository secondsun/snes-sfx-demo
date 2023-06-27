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



    return
endfunction

.endif