;The GSU stack is 16 bit values
.ifndef ::__STACK_DEFINED__
::__STACK_DEFINED__ = 1    
	.include "var.i"

	.define stackPointer r10

	; Peeks the top the value stored in R to the stack
	; assumes r10 is stack pointer
	;Example :
	;   iwt r2, #$4
	;	gsu_stack_push r2
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




; Pushes the value stored in R to the stack
	; assumes r10 is stack pointer
	;Example :
	;   iwt r2, #$4
	;	gsu_stack_push r2
	.macro gsu_stack_push R
		.if .not(.blank ({R}))
			from	R
		.endif
		stw	(stackPointer)
		inc	stackPointer
		inc	stackPointer

	.endmacro

	; Allocates a struct on the stack
	; assumes r10 is stack pointer
	; Returns the address of the struct in R
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

	.macro gsu_stack_alloc_bytes S
		.if .blank({S})
				.error "gsu_stack_alloc_bytes: S is blank"
		.endif
		with r10
		adds S
	.endmacro

	.macro gsu_stack_free_bytes S
		.if .blank({S})
				.error "gsu_stack_free_bytes: S is blank"
		.endif
		with r10
		sub S
	.endmacro
	
	; Frees a struct on the stack
	; assumes r10 is stack pointer
	; R is used as a temp register to store the size of the struct
	.macro gsu_stack_free struct, R
		.if .blank({R})
				.error "gsu_stack_alloc: R is blank"
		.endif

		.if .blank({struct})
				.error "gsu_stack_alloc: struct is blank"
		.endif

		iwt R, #.sizeof({struct})
		with r10
		sub R
	.endmacro

	; Pops the value stored in R to the stack
	; assumes r10 is stack pointer
	;Example :
	;   iwt r2, #$4
	;	gsu_stack_pop r2
	.macro gsu_stack_pop R
		dec	stackPointer
		dec	stackPointer
		.if .not( .blank({R}))
			to	R
		.endif
		ldw	(stackPointer)
	.endmacro

	;initialize stackPointer to stack ram;
	.macro init_stack
		iwt stackPointer, #(gsu_stack_ram)
	.endmacro 

	;uses a loop, use backuploop and restoreloop if you need to use a loop in your code
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

		;assumes r10 is stack pointer
		;assumes r0 is free to use as a temp register
		;assumes r1 is free to use as a temp register
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