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



    .segment "GSUCODE"

    ; reads a rnc header from the cart
    ; In : r0 = start of header data
    ; Out : r3 = address of header
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

    ;This sets up a two byte RNC buffer. The buffer is read using the
    ; read and peek functions defined in this file. 
    ; 
    ;
    ;
    ; r0 = start of compressed rnc file
    ; r1 = bank of compressed rnc file
    ; r2 = hiword size of compressed rnc file
    ; r3 = loword size of compressed rnc file
    function initialize_buffer
        ;RNC_WORD_BUFFER
        ;from r1
        ;romb
        
        add #9;move to start of compressed data
        add #9;move to start of compressed data

        ;move r14,r0
        sm (RNC_WORD_BUFFER + rncbuffer::bank), r1
        sm (RNC_WORD_BUFFER + rncbuffer::address), r0
        sm (RNC_WORD_BUFFER + rncbuffer::size), r2
        sm (RNC_WORD_BUFFER + rncbuffer::size +2), r3
        iwt r3, #$12
        sm (RNC_WORD_BUFFER + rncbuffer::index),r3
        sm (RNC_WORD_BUFFER + rncbuffer::index + 2),r3
        return
    endfunction

    ; reads r0 bits from the rnc bitstream
    ; r0 = number of bits to read
    ; clobbers r1,r2,r3,r4,r5,r6,r7,r8,r9,r10,r11,r12,r13,r14
    ; returns r3 = bits read
    function read_buffer
    
        lm r5, (RNC_WORD_BUFFER + rncbuffer::bank); bank
        from r5
        romb
        lm r14, (RNC_WORD_BUFFER + rncbuffer::address); bank

        iwt r3, #0 ; out
        iwt r1, #1 ; bitflag
        lm r4, (RNC_WORD_BUFFER + rncbuffer::word); word
        lm r2, (RNC_WORD_BUFFER + rncbuffer::count); count
        
        forR r0
            from r2
            cmp r2
            bne countFine
            nop
                ;val lower = inputBytes[index].toInt()
                ;val upper = inputBytes[index + 1].toInt()
                ;word = ((upper and 0x0FF) shl (8)) or ((lower) and 0x0FF) and 0x0FFFF
                _romreadword r4
                ;index += 2
                with r14
                add #2
                bcc noBankChange
                    nop 
                    inc r5
                    sm (RNC_WORD_BUFFER + rncbuffer::bank), r5; bank
                    from r5
                    romb
                noBankChange:
                
                sm (RNC_WORD_BUFFER + rncbuffer::address), r14 ; address
                ;count = 16
                iwt r2, #16
            countFine:            
            from r4
            and #1
            beq afterWrite
            nop
                ;out = out or bitflag
                with r3
                or r1
            afterWrite:

            ;word = word shr 1
            with r4
            lsr
            ;bitflag = bitflag shl 1
            with r1
            shl
            ;count -= 1
            dec r2


        endfor
        sm (RNC_WORD_BUFFER + rncbuffer::bank),r5 ; bank
        sm  (RNC_WORD_BUFFER + rncbuffer::address),r14; bank
        sm  (RNC_WORD_BUFFER + rncbuffer::word),r4; word
        sm (RNC_WORD_BUFFER + rncbuffer::count), r2 ; count
    return
    endfunction

.endif