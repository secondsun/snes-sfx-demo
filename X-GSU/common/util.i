.ifndef ::__GSU_UTIL_DEFINED__
::__GSU_UTIL_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"


;IN : RO address to a rombuffer struct
;out : R3 Byte from rombuffer
;Modifies rombuffer.index
;Clobbers r0-r3
function readrombyte
    
endfunction

;IN : RO address to a rombuffer struct
;out : R3 Byte from rombuffer
;Modifies rombuffer.index
;Clobbers r0-r3
function readromword
endfunction

;IN : RO address to a rombuffer struct
;IN : R1 size in bytes to copy
;IN : R2 address of array destination
;out : R3 0 if successful, error code otherwise
;Modifies rombuffer.index
;Clobbers r0-r3
function copyrombytes
endfunction

.endif