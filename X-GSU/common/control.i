; SuperFX
; Summers Pittman <secondsun@gmail.com>
; Control flow statements for the SuperFX
; 
.ifndef ::__GSU_CONTROL_DEFINED__
::__GSU_CONTROL_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"

; Executes instruction if R < V (signed comparison)
; In:       R = register to test, V = register or immediate value, instruction = statement to execute
; Out:      Executes instruction if condition met
; Clobbers: R0 (if R != R0), flags
.macro if_lt R, V, instruction 
    .local  Skip
    .ifblank(R)
        .error "if_lt: R parameter is required"
    .endif
    
    .ifblank(V)
        .error "if_lt: V parameter is required"
    .endif
    
    .ifblank(instruction)
        .error "if_lt: instruction parameter is required"
    .endif

    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    bge Skip
    nop
    instruction
    Skip:
.endmacro

; Executes instruction if R == V
; In:       R = register to test, V = register or immediate value, instruction = statement to execute
; Out:      Executes instruction if condition met
; Clobbers: R0 (if R != R0), flags
.macro if_eq R, V, instruction
    .local  Skip
    .ifblank(R)
        .error "if_eq: R parameter is required"
    .endif
    .ifblank(V)
        .error "if_eq: V parameter is required"
    .endif
    .ifblank(instruction)
        .error "if_eq: instruction parameter is required"
    .endif
    
    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    bne Skip
    nop
    instruction
    Skip:
.endmacro

; Executes instruction if R != V
; In:       R = register to test, V = register or immediate value, instruction = statement to execute
; Out:      Executes instruction if condition met
; Clobbers: R0 (if R != R0), flags
.macro if_ne R, V, instruction
    .local  Skip
    .ifblank(R)
        .error "if_ne: R parameter is required"
    .endif
    .ifblank(V)
        .error "if_ne: V parameter is required"
    .endif
    .ifblank(instruction)
        .error "if_ne: instruction parameter is required"
    .endif
    
    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    beq Skip
    nop
    instruction
    Skip:
.endmacro

; Executes instruction if R >= V (signed comparison)
; In:       R = register to test, V = register or immediate value, instruction = statement to execute
; Out:      Executes instruction if condition met
; Clobbers: R0 (if R != R0), flags
.macro if_gte R, V, instruction
    .local  Skip
    .ifblank(R)
        .error "if_gte: R parameter is required"
    .endif
    .ifblank(V)
        .error "if_gte: V parameter is required"
    .endif
    .ifblank(instruction)
        .error "if_gte: instruction parameter is required"
    .endif
    
    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    blt Skip
    nop
    instruction
    Skip:
.endmacro

; Executes instruction if R > V (signed comparison)
; In:       R = register to test, V = register or immediate value, instruction = statement to execute
; Out:      Executes instruction if condition met
; Clobbers: R0 (if R != R0), flags
.macro if_gt R, V, instruction
    .local  Skip
    .ifblank(R)
        .error "if_gt: R parameter is required"
    .endif
    .ifblank(V)
        .error "if_gt: V parameter is required"
    .endif
    .ifblank(instruction)
        .error "if_gt: instruction parameter is required"
    .endif
    
    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    blt Skip
    nop
    beq Skip
    nop
    instruction
    Skip:
.endmacro

; Executes instruction if R <= V (signed comparison)
; In:       R = register to test, V = register or immediate value, instruction = statement to execute
; Out:      Executes instruction if condition met
; Clobbers: R0 (if R != R0), flags
.macro if_lte R, V, instruction
    .local  check_eq
    .local  skip_end
    .ifblank(R)
        .error "if_lte: R parameter is required"
    .endif
    .ifblank(V)
        .error "if_lte: V parameter is required"
    .endif
    .ifblank(instruction)
        .error "if_lte: instruction parameter is required"
    .endif
    
    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    bge check_eq
    nop
    instruction
    bra Skip_end
    nop
    :check_eq
    bne Skip_end
    nop
    instruction
    Skip_end
.endmacro

.endif