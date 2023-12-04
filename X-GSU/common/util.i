.ifndef ::__GSU_UTIL_DEFINED__
::__GSU_UTIL_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"


 .macro _romreadbyte R
    .if .not( .blank({R}))
        to	R
    .endif
    getb
	inc	r14
.endmacro

;resets carry flag
;logical shift left
.macro shl R
    add #0
    .if .not( .blank({R}))
        with R
    .endif
    rol
.endmacro

;BIG ENDIAN
;Z is set on overflow
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

;LITTLE ENDIAN
;Z is set on overflow of address
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


