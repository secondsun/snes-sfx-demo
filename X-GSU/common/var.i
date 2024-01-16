
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
_normalize_small_big_reciprocal_temp:
  .res 2
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
RNC_HEADER:
  .res .sizeof(rnc_header)
;Global Camera   
CAMERA:
  .res .sizeof(camera)
; Global Matrix Transform  
LOOKAT_MATRIX:
  .res .sizeof(matrix4)
;LookAt look-ups
__LOOKAT_WAXIS__ = LOOKAT_MATRIX + 3 * .sizeof(vector4)
__LOOKAT_ZAXIS__ = LOOKAT_MATRIX + 2 * .sizeof(vector4)
__LOOKAT_YAXIS__ = LOOKAT_MATRIX + .sizeof(vector4)
__LOOKAT_XAXIS__ = LOOKAT_MATRIX 
__LOOKAT_ZAXIS_W__ = LOOKAT_MATRIX + 2 * .sizeof(vector4) + .sizeof(vector3) 
__LOOKAT_YAXIS_W__ = LOOKAT_MATRIX + .sizeof(vector4) + .sizeof(vector3) 
__LOOKAT_XAXIS_W__ = LOOKAT_MATRIX + .sizeof(vector3) 

;Decompress GLOBALS
RNC_WORD_BUFFER:
  .res .sizeof(rncbuffer)

RNC_LITERAL_TABLE:
	.res .sizeof(hufftree)
;val lengthTable = HuffTree();
RNC_LENGTH_TABLE:
	.res .sizeof(hufftree)
;val positionTable = HuffTree();
RNC_POSTION_TABLE:
	.res .sizeof(hufftree)


gsu_stack_ram:
	.res .sizeof(gsu_stack)
	

.endif