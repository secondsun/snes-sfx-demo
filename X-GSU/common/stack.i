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
.endif