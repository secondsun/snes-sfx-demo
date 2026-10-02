;The GSU stack is 16 bit values
.ifndef ::__STACK_DEFINED__
::__STACK_DEFINED__ = 1    
	.include "var.i"

	.define stackPointer r10

	; Peeks the top 16-bit value from the stack without popping
	; In:       R = destination register
	; Out:      R = peeked value
	; Clobbers: None (r10 restored)
	.macro gsu_stack_peek R
		dec	stackPointer
		dec	stackPointer
		.if .not( .blank({R}))
			to	R
		.endif
		ldw	(stackPointer)
		inc	stackPointer
		inc	stackPointer
	.endmacro

	; Pushes a 16-bit value stored in R onto the stack
	; In:       R = source register containing value to push
	; Out:      Memory at (r10) written, r10 incremented by 2
	; Clobbers: None (updates r10)
	.macro gsu_stack_push R
		.if .not(.blank ({R}))
			from	R
		.endif
		stw	(stackPointer)
		inc	stackPointer
		inc	stackPointer
	.endmacro

	; Allocates a struct on the stack and returns its base pointer
	; In:       struct = struct type name, R = temp/destination register
	; Out:      R = base address of allocated struct
	; Clobbers: R (updates r10)
	.macro gsu_stack_alloc struct, R
		.if .blank({R})
				.error "gsu_stack_alloc: R is blank"
		.endif

		.if .blank({struct})
				.error "gsu_stack_alloc: struct is blank"
		.endif

		iwt R, #.sizeof({struct})
		with r10
		add R
		from r10
		to R
		sub R
	.endmacro

	; Allocates S bytes on the stack
	; In:       S = number of bytes to allocate
	; Out:      r10 advanced by S
	; Clobbers: None (updates r10)
	.macro gsu_stack_alloc_bytes S
		.if .blank({S})
				.error "gsu_stack_alloc_bytes: S is blank"
		.endif
		with r10
		adds S
	.endmacro

	; Frees S bytes from the stack
	; In:       S = number of bytes to free
	; Out:      r10 decremented by S
	; Clobbers: None (updates r10)
	.macro gsu_stack_free_bytes S
		.if .blank({S})
				.error "gsu_stack_free_bytes: S is blank"
		.endif
		with r10
		sub S
	.endmacro
	
	; Frees a struct from the stack
	; In:       struct = struct type name, R = scratch register for sizeof
	; Out:      r10 decremented by .sizeof(struct)
	; Clobbers: R (updates r10)
	.macro gsu_stack_free struct, R
		.if .blank({R})
				.error "gsu_stack_free: R is blank"
		.endif

		.if .blank({struct})
				.error "gsu_stack_free: struct is blank"
		.endif

		iwt R, #.sizeof({struct})
		with r10
		sub R
	.endmacro

	; Pops a 16-bit value from the stack into R
	; In:       R = destination register
	; Out:      R = popped 16-bit value, r10 decremented by 2
	; Clobbers: None (updates r10)
	.macro gsu_stack_pop R
		dec	stackPointer
		dec	stackPointer
		.if .not( .blank({R}))
			to	R
		.endif
		ldw	(stackPointer)
	.endmacro

	; Initializes the stack pointer register (r10) to gsu_stack_ram
	; In:       None
	; Out:      r10 = address of gsu_stack_ram
	; Clobbers: r10
	.macro init_stack
		iwt stackPointer, #(gsu_stack_ram)
	.endmacro 

	; Copies a block of data from ROM to the stack
	; In:       rom_addr = ROM source address, rom_bank = ROM bank, size = byte count
	; Out:      Copies bytes to stack, advances r10 by size
	; Clobbers: r0, r10, r12, r13, r14
	.macro rom_to_stack rom_addr, rom_bank, size
	.ifblank(rom_addr)
		.error "rom_to_stack: rom_addr is blank"
	.endif
	.ifblank(rom_bank)
		.error "rom_to_stack: rom_bank is blank"
	.endif
	.ifblank(size)
		.error "rom_to_stack: size is blank"
	.endif

		ibt r0, #rom_bank
		romb
		iwt r14, rom_addr
		iwt r12, #size ; loop count times 
		move r13,r15
		getb
		inc r14
		from r0
		stb (r10)
		nop
		loop
		inc r10
	.endmacro
.endif