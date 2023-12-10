.ifndef ::__STRUCTS_DEFINED__
::__STRUCTS_DEFINED__ = 1   

.struct vector3
      xPos  .word
      yPos  .word
      zPos  .word
   .endstruct   

   .struct vector4
      xPos .word
      yPos .word
      zPos .word
      wPos .word
   .endstruct   

   .struct matrix4
      aVector .tag vector4
      bVector .tag vector4
      cVector .tag vector4
      dVector .tag vector4
   .endstruct   

   .struct polygon
      v1 .tag vector3
      v2 .tag vector3
      v3 .tag vector3
   .endstruct

   .struct camera
      eye .tag vector3
      lookAt .tag vector3
      up .tag vector3
   .endstruct
.struct gsu_stack
	entries  .res $200 ; 512 Bytes of stack
	.endstruct

.struct rnc_header
   uncompressed_size .res 4
   compressed_size   .res 4
   pack_chunks       .res 2
.endstruct  

.struct rncbuffer
   bank .res 2 ; bank of data
   address .res 2 ; next address to read
   index .res 4 ; index within larger bytestream
   size .res 4 ; size of bytestream
   word  .res 2 ; current bits in the buffer. 
   count .res 2 ; number of biuts remaining in buffer
.endstruct

.struct node
   depth .res 2
   encoding .res 2
.endstruct

.struct hufftree
    nodeCount .res 2; ; +0
    nodes .res 32* .sizeof(node); ; +4
.endstruct


.endif   