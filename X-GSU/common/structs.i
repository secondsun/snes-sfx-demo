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

   .struct camera
      eye .tag vector3
      lookAt .tag vector3
      up .tag vector3
   .endstruct
.struct gsu_stack
	entries  .res $200 ; 512 Bytes of stack
	.endstruct

.endif   