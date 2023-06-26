
.ifndef __VARS_DEFINED__
__VARS_DEFINED__ = 1
.include "structs.i"

.segment "GSURAM"

;Temp variables for return vectors
LOOKAT_ZAXIS:
  .res .sizeof(vector3)
LOOKAT_XAXIS:
  .res .sizeof(vector3)
LOOKAT_YAXIS:
  .res .sizeof(vector3)
vector_normalize_out:
  .res .sizeof(vector3)
VECTOR_SUBTRACT_IN:
  .res 2
VECTOR_SUBTRACT_OUT:
  .res .sizeof(vector3)
VECTOR_ADD_IN:
  .res 2
VECTOR_DOT_IN:
  .res 2  
VECTOR_ADD_OUT:
  .res .sizeof(vector3)
VECTOR_NEGATE_OUT:
  .res .sizeof(vector3)
VECTOR_CROSS_IN:
  .res 2
VECTOR_CROSS_OUT:
  .res .sizeof(vector3)
VECTOR_COPY_IN:
  .res 2

;Global Camera   
CAMERA:
  .res .sizeof(camera)
; Global Matrix Transform  
LOOKAT_MATRIX:
  .res .sizeof(matrix4)
gsu_stack_ram:
	.res .sizeof(gsu_stack)
	

.endif