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



; Sets up a two-byte RNC buffer for stream decompression
; In:       R0 = start of compressed RNC data, R1 = bank of compressed data, R2 = high word of size, R3 = low word of size
; Out:      Initializes RNC_WORD_BUFFER in GSURAM
; Clobbers: R0, R3
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
        sm (RNC_WORD_BUFFER + rncbuffer::index + 2),r3

        ; initialize index, word, count to 0
        iwt r3, #$0
        sm (RNC_WORD_BUFFER + rncbuffer::index),r3
        sm  (RNC_WORD_BUFFER + rncbuffer::word), r3; word
        sm  (RNC_WORD_BUFFER + rncbuffer::count), r3; count

        return
    endfunction


; Reads an RNC header from ROM and stores unpacked fields into RNC_HEADER (ROMB must be set)
; In:       R0 = start of header data in ROM
; Out:      R3 = address of header (RNC_HEADER)
; Clobbers: R1, R3, R14
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

; Decompresses an RNC-compressed data stream to destination buffer
; In:       R0 = start of compressed data, R1 = bank of compressed data, R2 = start of uncompressed buffer, R3 = byte count
; Out:      Decompressed data written to destination buffer at R2
; Clobbers: All
function decompress
        from r1
        romb
        move r6, r3
        gsu_stack_push r2
        call parseHeader
        move r7, r3
        header = r7
        outCounter = r6

        with outCounter
        sub #$2

        iwt r0, #$2
        call read_buffer
        gsu_stack_pop r8
        output = r8

        ;// do {
        outCounterLoop:
            ;val literalTable = HuffTree();
            ;val lengthTable = HuffTree();
            ;val positionTable = HuffTree();
            iwt r0, #(literalTable)
            call init_hufftree
            iwt r0, #(lengthTable)
            call init_hufftree
            iwt r0, #(positionTable)
            call init_hufftree

            iwt r0, #16
            call read_buffer
            move r9, r3
            subchunks = r9
            

            subchunksLoop:    
            ;while (subchunks-- > 0) {
                with subchunks
                sub #$0
                beq endSubchunksLoop
                nop
                bmi endSubchunksLoop
                dec subchunks
            ;   var literalLength = decodeNext(literalTable)
                iwt r0, #literalTable
                ; TODO call decode_next
                literalLength = r3 ;;TODO push/pop registers, todo create decode_next
        ;       while (literalLength-- > 0u) {
                literalLengthLoop:
                     with literalLength
                     sub #$0
                     beq endLiteralLengthLoop
                     nop
                     bmi endSubchunksLoop
                     nop
                     dec literalLength
                         
        ;                output[outIndex] = twoWordBuffer.readSourceByte().toByte()

                         
        ;                outIndex++
        ;                outCounter--
        ;            }
                bra literalLengthLoop
                nop
                endLiteralLengthLoop:
            ;        if (subchunks > 0 ) {
            ;            val offset = decodeNext(lengthTable) + 1u
            ;            var count :Int = (decodeNext(positionTable) + 2u).toInt()
            ;            while ((count--) !=0) {
            ;                if (offset.toInt() >= 0x4000) {
            ;                    System.out.println("offset ${offset} is too large ")
            ;                }
            ;                output[outIndex] = output[(outIndex - offset.toInt()) ]
            ;                outIndex++
            ;                outCounter--
            ;            }
            ;        }
            ;    }
            bra subchunksLoop
            nop
            endSubchunksLoop:

        ; } while (outCounter > 0)
            with outCounter
            sub #$0
            beq endOutCounterLoop
            nop
            bpl outCounterLoop
            nop
        endOutCounterLoop:
    

    return
    endfunction

; Reads specified number of bits from the RNC bitstream
; In:       R0 = number of bits to read
; Out:      R3 = bits read
; Clobbers: R0, R1, R2, R3, R4, R5, R10, R12, R13, R14
function read_buffer
    
        lm r5, (RNC_WORD_BUFFER + rncbuffer::bank); bank
        from r5
        romb
        lm r14, (RNC_WORD_BUFFER + rncbuffer::address); bank

        iwt r3, #0 ; out
        iwt r1, #1 ; bitflag
        lm r4, (RNC_WORD_BUFFER + rncbuffer::word); word
        lm r2, (RNC_WORD_BUFFER + rncbuffer::count); count
        break_for_word1:
        forR r0
            with r2
            add #0
            bne countFine
            nop
                ;val lower = inputBytes[index].toInt()
                ;val upper = inputBytes[index + 1].toInt()
                ;word = ((upper and 0x0FF) shl (8)) or ((lower) and 0x0FF) and 0x0FFFF
                _romreadwordLE r4
                ;index += 2
                ;
                bne noBankChange
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
            
            shl r1
            ;count -= 1
            dec r2


        endfor
        
        
        sm (RNC_WORD_BUFFER + rncbuffer::bank),r5 ; bank
        sm  (RNC_WORD_BUFFER + rncbuffer::address),r14; bank
        sm  (RNC_WORD_BUFFER + rncbuffer::word),r4; word
        sm (RNC_WORD_BUFFER + rncbuffer::count), r2 ; count
        break_for_word2:
    return
    endfunction

; Reads Huffman tree header and builds decoding table for RNC stream
; In:       R0 = address of hufftree structure to initialize
; Out:      Hufftree structure at R0 populated
; Clobbers: All
function init_hufftree
        address = r0
        move r1,address ; r1 = address of hufftree
        iwt r0, #$5 ;r0 = bits to read
        ;Read number of nodes
        gsu_stack_push r1
        for .sizeof(hufftree)
            iwt r0, #0
            stw (r1)
            inc r1
            inc r1
        endfor
        iwt r0, #$5 ;r0 = bits to read
        call read_buffer
        gsu_stack_pop r1

        from r3 ; r3 = node count
        stw (r1) ; store node count
        
        ;set r2 to start of nodes for hufftree (at r1)
            from  r1 ; r2 = address of hufftree
            to r2
            add #hufftree::nodes ; r2 = address of nodes

        forR r3 ; for each node in hufftree 
            ;read node
            iwt r0, #$4 ; r0 = bits to read
            gsu_stack_push r1
            gsu_stack_push r2
            call read_buffer ; read bit_depth
            gsu_stack_pop r2
            gsu_stack_pop r1
            from r3 ;save bitdepth to node
            stw (r2)    
            with r2
            add #.sizeof(node) ;point r2 at next node
        endfor

        ;var div = 0x8000u
        ;var value = 0u;
        ;var bits_count = 1;

        iwt r4, #$8000 ; r4 = div
        iwt r5, #0;  r5 = value
        iwt r6, #$1; r6 = bits_count

        ;while (bits_count <= 16) 
        init_encoding:
        iwt r0, #16
        cmp r6
        bmi end_init_encoding
        nop
            ;var i = 0
            iwt r7, #0 ; r7 = i
            init_encoding_loop: 
            ;while (true) {
                ;if (i >= nodeCount) {
                    ldw (r1) ; r0 = nodeCount
                    cmp r7
                    beq :+
                    nop
                    blt set_encoding
                    nop
                    :
                    ;bits_count++
                    inc r6
                    ;div = div shr 1
                    with r4
                    lsr
                    ;break
                    bra end_init_encoding_loop
                    nop
                ;} endif
                set_encoding:    
                ;nodes[i].bitdepth
                ;set r2 to start of nodes for hufftree (at r1)
                move r0, r1 ; r0 = address of hufftree
                add #hufftree::nodes ; r0 = address of nodes[0]

                iwt r2, #.sizeof(node) ; r2 = sizeof(node)
                from r7 ; r7 = i
                to r2
                mult #.sizeof(node) ;   r2 = offset of nodes[i]
                to r2
                add r2; r2 = r0 + r2 = address of nodes[i] 

                ldw(r2) ; r0 = nodes[i].bitdepth
                cmp r6 ; r6 = bits_count
                bne skip_encoding
                nop
                ;if (nodes[i].bitdepth == bits_count) {
                ;   nodes[i].encoding = inverse_bits(value / div, bits_count)
                
                with r2
                add #node::encoding ; r2 = address of nodes[i].encoding
                gsu_stack_push r2
                gsu_stack_push r1
                move r2, r4 
                move r0, r5 ; r0 = value
                ;r0 = value / div (div is always a power of 2, so we can just shift right)
                :
                    to r9
                    from r2
                    sub #1
                    beq :+
                    nop
                    lsr
                    with r2
                    lsr
                    bra :-
                    nop
                :    
                ; inverse_bits(value / div, bits_count)
                move r1, r6 ; r1 = bits_count
                call inverse_bits ; r3 = encoding
                ;
                gsu_stack_pop r1
                gsu_stack_pop r2
                saveEncoding:
                
                from r3
                stw (r2)

                ;   value += div
                with r5
                add r4
                ;}
                skip_encoding:
                inc r7 ; i++
            bra init_encoding_loop
            nop ; } endwhile 
            end_init_encoding_loop:
        ; } endwhile
        bra init_encoding
        nop            
        end_init_encoding:
    
    return
    endfunction

; Reverses bit order of a given value up to bit count
; In:       R0 = value to invert, R1 = bit count
; Out:      R3 = bit-reversed value
; Clobbers: R0, R1, R2, R3
function inverse_bits
        ;var i = 0
        iwt r3, #0 ; r3 = i = 0
        ;while (bitsCount-- != 0) {
        inverse_bits_loop:
        with r1
        add #0
        beq end_inverse_bits_loop
        nop
            ;    i = i shl 1
            shl r3
            ;    if (value and 1u != 0u) {
            to r2
            and #1
            beq inverse_bits_if
                nop
                ; i = i or 1
                with r3
                or #1
            inverse_bits_if:    
            ;    }
            ;    value = value shr 1
            lsr
            ;}
        dec r1
        bra inverse_bits_loop
        nop
        end_inverse_bits_loop:
        ;return i
    return
    endfunction

.endif