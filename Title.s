.include "libSFX.i"
.include "pointers.s"
.include "CpuMacros.s"

TitleInit: 

    ;unpack_models
    jsr unpack_models

unpack_models:
    jsr unpack_array
    .dword doUnpackModel
    rts

;Subroutine expects a callback to be stack + 1 (word)
unpack_array:;(fn)
    ;local n=unpack_variant()
	;for i=1,n do
	;	fn(i)
	;end
    rts

doUnpackModel:
