.struct edgeentry
  texture .word ;address
  start   .byte
  length  .byte
  scale   .word ; 8.8 fixed point

.endstruct

.struct edgerow
  count  .byte
  edges  .res 5 * .sizeof(edgeentry) ; each row can have 5 entries (number pulled firmly from keister)
.endstruct



.struct edgetable
  rows .res 160 * .sizeof(edgerow) ; 160 rows of edges
.endstruct

.struct sprite
  texture .word ; address
  xLoc .byte
  yLoc .byte
  scale .word ; 8.8 fixed point
.endstruct

.struct spritelist
  count .byte
  sprites .res 60* .sizeof(sprite) ; 60 sprites on screen max
.endstruct