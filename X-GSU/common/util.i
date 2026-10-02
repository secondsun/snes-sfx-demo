.ifndef ::__GSU_UTIL_DEFINED__
::__GSU_UTIL_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"


; Reads a byte from ROM buffer at r14 and increments r14
; In:       R = destination register, r14 = ROM address pointer
; Out:      R = byte read (zero-extended), r14 incremented by 1
; Clobbers: R, r14
.macro _romreadbyte R
    .if .not( .blank({R}))
        to	R
    .endif
    getb
	inc	r14
.endmacro

; Performs a logical shift left on R by clearing carry and rotating left
; In:       R = register to shift
; Out:      R shifted left by 1 (bit 0 = 0, carry = old bit 15)
; Clobbers: R, flags
.macro shl R
    add #0
    .if .not( .blank({R}))
        with R
    .endif
    rol
.endmacro

; Reads a 16-bit big-endian word from ROM buffer at r14 and increments r14 by 2
; In:       R = destination register, r14 = ROM address pointer
; Out:      R = word read (big-endian), r14 incremented by 2
; Clobbers: R, r14
.macro _romreadword  R
    .if .not( .blank({R}))
        to	R
    .endif
    getbh
	inc	r14
    .if .not( .blank({R}))
        with R
    .endif
    getbl
	inc	r14
.endmacro

; Reads a 16-bit little-endian word from ROM buffer at r14 and increments r14 by 2
; In:       R = destination register, r14 = ROM address pointer
; Out:      R = word read (little-endian), r14 incremented by 2
; Clobbers: R, r14
.macro _romreadwordLE  R
    .if .not( .blank({R}))
        to	R
    .endif
    getbl
	inc	r14
    .if .not( .blank({R}))
        with R
    .endif
    getbh
	inc	r14
.endmacro

.endif


