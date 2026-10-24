; ==============================================================================
; cached_trap Struct Definition
; ==============================================================================
.ifndef ::__CACHED_TRAP_STRUCT_DEFINED__
::__CACHED_TRAP_STRUCT_DEFINED__ = 1

; cached_trap Struct (26 bytes, 13 words)
.struct cached_trap
    dy_start    .word ; +0:  Screen-space Y offset (signed word)
    line_count  .word ; +2:  Number of scanlines in trapezoid (unsigned word)
    xL_start    .word ; +4:  Initial left edge X in Q8.8 (signed word)
    xR_start    .word ; +6:  Initial right edge X in Q8.8 (signed word)
    dxL_dy      .word ; +8:  Left edge slope dxL/dy in Q8.8 (signed word)
    dxR_dy      .word ; +10: Right edge slope dxR/dy in Q8.8 (signed word)
    uL_start    .word ; +12: Initial left edge U in Q8.8 (signed word)
    vL_start    .word ; +14: Initial left edge V in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT) (signed word)
    du_dy       .word ; +16: Left edge du/dy in Q8.8 (signed word)
    dv_dy       .word ; +18: Left edge dv/dy in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT) (signed word)
    du_dx       .word ; +20: Scanline du/dx in Q8.8 (signed word)
    dv_dx       .word ; +22: Scanline dv/dx in Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT) (signed word)
    tex_id      .word ; +24: Texture slot / ID into TEXTURE_TABLE (word)
.endstruct

cached_trap_tex_slot = cached_trap::tex_id

.endif ; ::__CACHED_TRAP_STRUCT_DEFINED__
