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

.macro _romreadword  R
    .if .not( .blank({R}))
        to	R
    .endif
    getb
	inc	r14
    .if .not( .blank({R}))
        to	R
    .endif
    getbh
	inc	r14
.endmacro

.endif