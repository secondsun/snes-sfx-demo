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
; In:       data_addr = start of compressed RNC data, bank = bank of compressed data, size_hi = high word of size, size_lo = low word of size
; Out:      Initializes RNC_WORD_BUFFER in GSURAM
; Clobbers: allocated registers
function initialize_buffer data_addr, bank, size_hi, size_lo
        register tmp

        with data_addr
        add #9 ; move to start of compressed data
        with data_addr
        add #9 ; move to start of compressed data

        sm (RNC_WORD_BUFFER + rncbuffer::bank), bank
        sm (RNC_WORD_BUFFER + rncbuffer::address), data_addr
        sm (RNC_WORD_BUFFER + rncbuffer::size), size_hi
        sm (RNC_WORD_BUFFER + rncbuffer::size + 2), size_lo
        iwt tmp, #$12
        sm (RNC_WORD_BUFFER + rncbuffer::index + 2), tmp

        ; initialize index, word, count to 0
        iwt tmp, #$0
        sm (RNC_WORD_BUFFER + rncbuffer::index), tmp
        sm (RNC_WORD_BUFFER + rncbuffer::word), tmp ; word
        sm (RNC_WORD_BUFFER + rncbuffer::count), tmp ; count

        return
    endfunction


; Reads an RNC header from ROM and stores unpacked fields into RNC_HEADER (ROMB must be set)
; In:       rom_addr = start of header data in ROM
; Out:      header_out = address of header (RNC_HEADER)
; Clobbers: r0, r14, allocated registers
function parseHeader rom_addr : header_out
    register tmp

    from rom_addr
    to r14
    add #4

    ;read uncompressed size
    _romreadword tmp
    sm (RNC_HEADER), tmp
    _romreadword tmp
    sm (RNC_HEADER+2), tmp

    ;read compressed size
    _romreadword tmp
    sm (RNC_HEADER+4), tmp
    _romreadword tmp
    sm (RNC_HEADER+6), tmp

    with r14
    add #5
    
    ;read packs size
    _romreadbyte tmp
    sm (RNC_HEADER+8), tmp

    iwt header_out, #RNC_HEADER
    return header_out
endfunction

; Decompresses an RNC-compressed data stream to destination buffer
; In:       data_addr = start of compressed data, bank = bank of compressed data, output = start of uncompressed buffer, outCounter = byte count
; Out:      Decompressed data written to destination buffer at output
; Clobbers: All
function decompress data_addr, bank, output, outCounter
        register header, bits_arg, subchunks, table_addr, literalLength

        from bank
        romb
        call parseHeader data_addr : header

        with outCounter
        sub #$2

        iwt bits_arg, #$2
        call read_buffer bits_arg

        ;// do {
        outCounterLoop:
            ;val literalTable = HuffTree();
            ;val lengthTable = HuffTree();
            ;val positionTable = HuffTree();
            iwt table_addr, #(literalTable)
            call init_hufftree table_addr
            iwt table_addr, #(lengthTable)
            call init_hufftree table_addr
            iwt table_addr, #(positionTable)
            call init_hufftree table_addr

            iwt bits_arg, #16
            call read_buffer bits_arg : subchunks
            

            subchunksLoop:    
            ;while (subchunks-- > 0) {
                with subchunks
                sub #$0
                beq endSubchunksLoop
                nop
                bmi endSubchunksLoop
                dec subchunks
            ;   var literalLength = decodeNext(literalTable)
                iwt table_addr, #literalTable
                ; TODO call decode_next
                iwt literalLength, #0
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
; In:       bit_count = number of bits to read
; Out:      out = bits read
; Clobbers: r0, r12, r13, r14, allocated registers
function read_buffer bit_count : out
        register bank, bitflag, word, count
    
        lm bank, (RNC_WORD_BUFFER + rncbuffer::bank); bank
        from bank
        romb
        lm r14, (RNC_WORD_BUFFER + rncbuffer::address); address

        iwt out, #0 ; out
        iwt bitflag, #1 ; bitflag
        lm word, (RNC_WORD_BUFFER + rncbuffer::word); word
        lm count, (RNC_WORD_BUFFER + rncbuffer::count); count
        break_for_word1:
        forR bit_count
            with count
            add #0
            bne countFine
            nop
                ;val lower = inputBytes[index].toInt()
                ;val upper = inputBytes[index + 1].toInt()
                ;word = ((upper and 0x0FF) shl (8)) or ((lower) and 0x0FF) and 0x0FFFF
                _romreadwordLE word
                ;index += 2
                ;
                bne noBankChange
                    nop 
                    inc bank
                    sm (RNC_WORD_BUFFER + rncbuffer::bank), bank; bank
                    from bank
                    romb
                noBankChange:
                
                sm (RNC_WORD_BUFFER + rncbuffer::address), r14 ; address
                ;count = 16
                iwt count, #16
            countFine:            
            from word
            and #1
            beq afterWrite
            nop
                ;out = out or bitflag
                with out
                or bitflag
            afterWrite:

            ;word = word shr 1
            with word
            lsr
            ;bitflag = bitflag shl 1
            
            shl bitflag
            ;count -= 1
            dec count


        endfor
        
        
        sm (RNC_WORD_BUFFER + rncbuffer::bank), bank ; bank
        sm (RNC_WORD_BUFFER + rncbuffer::address), r14 ; address
        sm (RNC_WORD_BUFFER + rncbuffer::word), word ; word
        sm (RNC_WORD_BUFFER + rncbuffer::count), count ; count
        break_for_word2:
    return out
    endfunction

; Reads Huffman tree header and builds decoding table for RNC stream
; In:       address = address of hufftree structure to initialize
; Out:      Hufftree structure at address populated
; Clobbers: All
function init_hufftree address
        register ptr, node_ptr, node_count, bits_arg, bit_depth
        register div, value, bits_count, idx, enc_ptr, shift_div, shift_val, encoding

        move ptr, address ; ptr = address of hufftree
        ;Read number of nodes
        for .sizeof(hufftree)
            iwt r0, #0
            stw (ptr)
            inc ptr
            inc ptr
        endfor
        iwt bits_arg, #$5 ; bits to read
        call read_buffer bits_arg : node_count

        from node_count ; node count
        stw (address) ; store node count
        
        ;set node_ptr to start of nodes for hufftree (at address)
        from address
        to node_ptr
        add #hufftree::nodes ; node_ptr = address of nodes

        forR node_count ; for each node in hufftree 
            ;read node
            iwt bits_arg, #$4 ; bits to read
            call read_buffer bits_arg : bit_depth
            from bit_depth ;save bitdepth to node
            stw (node_ptr)    
            with node_ptr
            add #.sizeof(node) ;point node_ptr at next node
        endfor

        ;var div = 0x8000u
        ;var value = 0u;
        ;var bits_count = 1;

        iwt div, #$8000 ; div
        iwt value, #0 ; value
        iwt bits_count, #$1 ; bits_count

        ;while (bits_count <= 16) 
        init_encoding:
        iwt r0, #16
        cmp bits_count
        bmi end_init_encoding
        nop
            ;var i = 0
            iwt idx, #0 ; idx = i
            init_encoding_loop: 
            ;while (true) {
                ;if (i >= nodeCount) {
                    ldw (address) ; r0 = nodeCount
                    cmp idx
                    beq :+
                    nop
                    blt set_encoding
                    nop
                    :
                    ;bits_count++
                    inc bits_count
                    ;div = div shr 1
                    with div
                    lsr
                    ;break
                    bra end_init_encoding_loop
                    nop
                ;} endif
                set_encoding:    
                ;nodes[i].bitdepth
                ;set enc_ptr to start of nodes for hufftree (at address)
                from address
                add #hufftree::nodes ; r0 = address of nodes[0]

                from idx ; idx = i
                to enc_ptr
                mult #.sizeof(node) ; enc_ptr = offset of nodes[i]
                to enc_ptr
                add enc_ptr ; enc_ptr = r0 + enc_ptr = address of nodes[i] 

                ldw (enc_ptr) ; r0 = nodes[i].bitdepth
                cmp bits_count ; bits_count
                bne skip_encoding
                nop
                ;if (nodes[i].bitdepth == bits_count) {
                ;   nodes[i].encoding = inverse_bits(value / div, bits_count)
                
                with enc_ptr
                add #node::encoding ; enc_ptr = address of nodes[i].encoding
                move shift_div, div
                move shift_val, value ; shift_val = value
                ;shift_val = value / div (div is always a power of 2, so we can just shift right)
                :
                    from shift_div
                    sub #1
                    beq :+
                    nop
                    with shift_val
                    lsr
                    with shift_div
                    lsr
                    bra :-
                    nop
                :    
                ; inverse_bits(value / div, bits_count)
                call inverse_bits shift_val, bits_count : encoding
                saveEncoding:
                
                from encoding
                stw (enc_ptr)

                ;   value += div
                with value
                add div
                ;}
                skip_encoding:
                inc idx ; i++
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
; In:       val = value to invert, bits_count = bit count
; Out:      out = bit-reversed value
; Clobbers: r0, allocated registers
function inverse_bits val, bits_count : out
        ;var i = 0
        iwt out, #0 ; out = i = 0
        ;while (bitsCount-- != 0) {
        inverse_bits_loop:
        with bits_count
        add #0
        beq end_inverse_bits_loop
        nop
            ;    i = i shl 1
            shl out
            ;    if (value and 1u != 0u) {
            from val
            and #1
            beq inverse_bits_if
                nop
                ; i = i or 1
                with out
                or #1
            inverse_bits_if:    
            ;    }
            ;    value = value shr 1
            with val
            lsr
            ;}
        dec bits_count
        bra inverse_bits_loop
        nop
        end_inverse_bits_loop:
        ;return i
    return out
    endfunction

.endif