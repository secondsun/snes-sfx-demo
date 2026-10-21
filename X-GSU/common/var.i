
.ifndef __VARS_DEFINED__
__VARS_DEFINED__ = 1
.include "structs.i"

.segment "GSURAM"
.res 0
gsu_stack_ram:
	.res .sizeof(gsu_stack)
	
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

;val literalTable = HuffTree();
literalTable:
	.res .sizeof(hufftree)

;val lengthTable = HuffTree();
lengthTable:
	.res .sizeof(hufftree)

;val positionTable = HuffTree();
positionTable:
	.res .sizeof(hufftree)

.endif