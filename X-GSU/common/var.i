
.ifndef __VARS_DEFINED__
__VARS_DEFINED__ = 1
.include "structs.i"

.segment "GSURAM"

.res 1
;Temp variables for return vectors
vector_1:
  .res .sizeof(vector3)
vector_2:
  .res .sizeof(vector3)
vector_3:
  .res .sizeof(vector3)  
vector_normalize_out:
  .res .sizeof(vector3)
VECTOR_SUBTRACT_IN:
  .res .sizeof(vector3)
VECTOR_SUBTRACT_OUT:
  .res .sizeof(vector3)
VECTOR_ADD_IN:
  .res .sizeof(vector3)
  .out "def again \n"
VECTOR_ADD_OUT:
  .res .sizeof(vector3)

;Global Camera   
camera_mem:
  .res .sizeof(camera)
; Global Matrix Transform  
world_matrix_mem:
  .res .sizeof(matrix4)
gsu_stack_ram:
	.res .sizeof(gsu_stack)
	

.endif