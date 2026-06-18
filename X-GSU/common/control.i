; SuperFX
; Summers Pittman <secondsun@gmail.com>
; Control flow statements for the SuperFX
; 
.ifndef ::__GSU_CONTROL_DEFINED__
::__GSU_CONTROL_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"

.macro if_lt R, V, instruction 

    ; Error check: Ensure all parameters are provided
    .ifblank(R)
        .error "if_lt: R parameter is required"
    .endif
    
    .ifblank(V)
        .error "if_lt: V parameter is required"
    .endif
    
    .ifblank(instruction)
        .error "if_lt: instruction parameter is required"
    .endif

    ; Your macro implementation follows
    .if ( .not(.xmatch({R}, {r0}) || .xmatch({R}, {R0})))
        from R
    .endif
    cmp V
    bge :+
    nop
    instruction
    :

.endmacro

.macro if_eq R, V, instruction
    ; Execute instruction if R == V
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
    bne :+
    nop
    instruction
    :
.endmacro

.macro if_ne R, V, instruction
    ; Execute instruction if R != V
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
    beq :+
    nop
    instruction
    :
.endmacro

.macro if_gte R, V, instruction
    ; Execute instruction if R >= V (signed comparison)
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
    blt :+
    nop
    instruction
    :
.endmacro

.macro if_gt R, V, instruction
    ; Execute instruction if R > V (signed comparison)
    ; Condition requires: (S^O = 0) AND (Z = 0)
    ; Skip if: < OR =
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
    blt :+
    nop
    beq :+
    nop
    instruction
    :
.endmacro

.macro if_lte R, V, instruction
    ; Execute instruction if R <= V (signed comparison)
    ; Condition requires: (S^O = 1) OR (Z = 1)
    ; Skip if: > (which is >= AND !=)
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
    bge :check_eq
    ; If less than, execute
    nop
    instruction
    bra :skip_end
    nop
    :check_eq
    bne :skip_end   ; If >= but not equal (i.e., >), skip
    nop
    instruction
    :skip_end
.endmacro

.endif