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

; Copies a block of data from SuperFX ROM to SuperFX RAM
; In:       rom_addr = ROM source address, rom_bank = ROM bank, ram_addr = RAM destination address or register, size = byte count
; Out:      Copies bytes to RAM, advances destination register by size
; Clobbers: r0, r12, r13, r14, destination register (ram_addr if register, r1 if address)
.macro rom_to_ram rom_addr, rom_bank, ram_addr, size
    .ifblank(rom_addr)
        .error "rom_to_ram: rom_addr is blank"
    .endif
    .ifblank(rom_bank)
        .error "rom_to_ram: rom_bank is blank"
    .endif
    .ifblank(ram_addr)
        .error "rom_to_ram: ram_addr is blank"
    .endif
    .ifblank(size)
        .error "rom_to_ram: size is blank"
    .endif

    .if .xmatch({ram_addr}, {r0}) || .xmatch({ram_addr}, {R0})
        .error "rom_to_ram: ram_addr cannot be r0 (r0 is clobbered by getb)"
    .endif

    .if .xmatch (.left (1, {rom_bank}), #)
        ibt r0, rom_bank
    .else
        ibt r0, #rom_bank
    .endif
    romb

    .if .xmatch (.left (1, {rom_addr}), #)
        iwt r14, rom_addr
    .else
        iwt r14, #rom_addr
    .endif

    .if .xmatch (.left (1, {size}), #)
        iwt r12, size
    .else
        iwt r12, #size
    .endif

    .if .xmatch({ram_addr}, {r1}) || .xmatch({ram_addr}, {R1}) || \
        .xmatch({ram_addr}, {r2}) || .xmatch({ram_addr}, {R2}) || \
        .xmatch({ram_addr}, {r3}) || .xmatch({ram_addr}, {R3}) || \
        .xmatch({ram_addr}, {r4}) || .xmatch({ram_addr}, {R4}) || \
        .xmatch({ram_addr}, {r5}) || .xmatch({ram_addr}, {R5}) || \
        .xmatch({ram_addr}, {r6}) || .xmatch({ram_addr}, {R6}) || \
        .xmatch({ram_addr}, {r7}) || .xmatch({ram_addr}, {R7}) || \
        .xmatch({ram_addr}, {r8}) || .xmatch({ram_addr}, {R8}) || \
        .xmatch({ram_addr}, {r9}) || .xmatch({ram_addr}, {R9}) || \
        .xmatch({ram_addr}, {r10}) || .xmatch({ram_addr}, {R10}) || \
        .xmatch({ram_addr}, {r11}) || .xmatch({ram_addr}, {R11})

        move r13, r15
        getb
        inc r14
        from r0
        stb (ram_addr)
        nop
        loop
        inc ram_addr
    .else
        .if .xmatch (.left (1, {ram_addr}), #)
            iwt r1, ram_addr
        .else
            iwt r1, #ram_addr
        .endif
        move r13, r15
        getb
        inc r14
        from r0
        stb (r1)
        nop
        loop
        inc r1
    .endif
.endmacro

.endif
