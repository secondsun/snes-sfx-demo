.ifndef ::__FUNCTION_DEFINED__
::__FUNCTION_DEFINED__ = 1

.include "stack.i"

;This file deinfes macros for calling and defining functions
; the call #label macro calls the function #label
; the function label macro starts a struct and sets up the return stack
; the return macro pops the stack to return.
.macro call label
.if (.blank ({label}))
			.error "Label must not be blank"
		.endif
    link	#4
	iwt	  r15, #.ident(.concat( .string(label), "_function"))
	nop
.endmacro 


.macro function name
    .if (.blank ({name}))
		.error "Name must not be blank"
	.endif
        .ident(.concat(.string(name), "_function")):
    .scope name
	gsu_stack_push r11 
.endmacro

; Useful to return midfunction
.macro return
    gsu_stack_pop r15 ; jump to return address on stack
	nop
.endmacro

.macro endfunction
   .endscope
.endmacro

.macro for count
	backuploop
	iwt r12, #count ; loop count times 
	move r13,r15
.endmacro

.macro forR countRegister
	backuploop
	move r12, countRegister ; loop number of times in countRegister
	move r13,r15
.endmacro


.macro endfor
	loop
	nop
	restoreloop
.endmacro

.macro backuploop
	gsu_stack_push r12
	gsu_stack_push r13
.endmacro

.macro restoreloop
	gsu_stack_pop r13
	gsu_stack_pop r12
.endmacro

.endif