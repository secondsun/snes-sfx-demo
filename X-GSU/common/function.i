.ifndef ::__FUNCTION_DEFINED__
::__FUNCTION_DEFINED__ = 1

.include "stack.i"

; Calls a function by setting return address in r11 and branching to <label>_function
; In:       label = function identifier
; Out:      Jumps to function, r11 set to return address
; Clobbers: r11, r15
.macro call label
.if (.blank ({label}))
			.error "Label must not be blank"
		.endif
    link	#4
	iwt	  r15, #.ident(.concat( .string(label), "_function"))
	nop
.endmacro 

; Defines a function entry point, opens a scope, and pushes return address (r11)
; In:       name = function identifier
; Out:      Defines <name>_function, r11 pushed to stack
; Clobbers: None (updates r10)
.macro function name
    .if (.blank ({name}))
		.error "Name must not be blank"
	.endif
        .ident(.concat(.string(name), "_function")):
    .scope name
	gsu_stack_push r11 
.endmacro

; Returns from a function by popping return address from stack into r15
; In:       None (reads return address from stack)
; Out:      Jumps to return address, r10 decremented by 2
; Clobbers: r15 (updates r10)
.macro return
    gsu_stack_pop r15 ; jump to return address on stack
	nop
.endmacro

; Declares register alias / parameter placeholder
; In:       params = register assignment statement
; Out:      Direct parameter expansion
; Clobbers: None
.macro register params
  params	
.endmacro

; Closes the current function scope
; In:       None
; Out:      Closes .scope
; Clobbers: None
.macro endfunction
   .endscope
.endmacro

; Begins a counted loop executing an immediate count times
; In:       count = immediate iteration count
; Out:      Backs up r12/r13 to stack, sets r12 = count, r13 = loop top
; Clobbers: r12, r13 (updates r10)
.macro for count
	backuploop
	iwt r12, #count ; loop count times 
	move r13,r15
.endmacro

; Begins a counted loop executing the count in countRegister
; In:       countRegister = register containing iteration count
; Out:      Backs up r12/r13 to stack, sets r12 = countRegister, r13 = loop top
; Clobbers: r12, r13 (updates r10)
.macro forR countRegister
	backuploop
	move r12, countRegister ; loop number of times in countRegister
	move r13,r15
.endmacro

; Ends a counted loop, looping until r12 reaches 0 and restoring previous loop registers
; In:       None
; Out:      Decrements r12, branches to r13 while non-zero, restores r12/r13 from stack
; Clobbers: r12, r13 (updates r10)
.macro endfor 
	loop
	nop
	restoreloop
.endmacro

; Backs up current hardware loop registers (r12, r13) to the stack
; In:       None
; Out:      Pushes r12 and r13 to stack (4 bytes)
; Clobbers: None (updates r10)
.macro backuploop
	gsu_stack_push r12
	gsu_stack_push r13
.endmacro

; Restores previously backed-up loop registers (r13, r12) from the stack
; In:       None
; Out:      Pops r13 and r12 from stack (4 bytes)
; Clobbers: r12, r13 (updates r10)
.macro restoreloop
	gsu_stack_pop r13
	gsu_stack_pop r12
.endmacro

.endif