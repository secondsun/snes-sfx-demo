.struct edgeentry
  texture .word ;address
  start   .byte
  length  .byte
  scale_r   .word ; 8.8 fixed point reciprocal of sprite:scale

.endstruct

.struct edgerow
  count  .byte
  pad .byte
  edges  .res 5 * .sizeof(edgeentry) ; each row can have 5 entries (number pulled firmly from keister)
.endstruct



.struct edgetable
  rows .res 160 * .sizeof(edgerow) ; 160 rows of edges
.endstruct

.struct sprite
  texture .word ; address
  xLoc .byte
  yLoc .byte
  scale_r .word ; 8.8 fixed point
  scale .word ; 8.8 fixed point
.endstruct

.struct spritelist
  count .byte
  pad .byte
  sprites .res 60* .sizeof(sprite) ; 60 sprites on screen max
.endstruct