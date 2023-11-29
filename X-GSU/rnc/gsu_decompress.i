; SuperFX
; Summers Pittman <secondsun@gmail.com>
; RNC method 1 with 0x4000 dictsize Decompress utility functions
;
.ifndef ::__GSU_DECOMPRESS_DEFINED__
::__GSU_DECOMPRESS_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"
.include "../common/util.i"


    .struct two_word_buffer
        hi .word 
        lo .word 
    .endstruct

    .segment "GSUCODE"

    ; reads a rnc header from the cart
    ; r0 = start of header data
    ; r3 = address of header
    ;
    ; ROMB should be set to the bank of compressed data before calling this function
    ; clobbers r1,r14,r3
    function parseHeader

        to r14
        add #4

        ;read uncompressed size
        _romreadword r1
        sm (RNC_HEADER), r1
        _romreadword r1
        sm (RNC_HEADER+2), r1

        ;read compressed size
        _romreadword r1
        sm (RNC_HEADER+4), r1
        _romreadword r1
        sm (RNC_HEADER+6), r1

        with r14
        add #5
        
        ;read packs size
        _romreadbyte r1
        sm (RNC_HEADER+8), r1

        iwt r3, #RNC_HEADER
        return 
    endfunction

    
    ; r0 = start of compressed data
    ; r1 = bank of compressed data
    ; r2 = start of uncompressed data; must be preallocated
    ; r3 = bytes to decompress
    ; NOTE : romb should be selected before calling this function

    function decompress
        from r1
        romb
        
        call parseHeader
        


        ;todo write structure for hufftree
        ;todo create hufftree
        ;read from buffer
        ;create buffer handler 
        ;create decompression function
        
    return
    endfunction

.endif