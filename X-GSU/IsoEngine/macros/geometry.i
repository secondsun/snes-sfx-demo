;.ifndef ::__GEOMETRY_DEFINED__
;::__GEOMETRY_DEFINED__ = 1   
; geometry.i - geometry related macros/definitions

    ;Each of these variables is a Q8.8 fixed point number. 
    ;.macro cube x, y, z, length
    


     ;   .if     .paramcount <> 4
      ;  .error  "Too few parameters for macro cube"
       ; .endif
        ; define 8 cube vertices starting at (x, y, z) with edge length

        ;.word x, y, z
        ;.word x + length, y, z
        ;.word x, y + length, z
        ;.word x + length, y + length, z
        ;.word x, y, z + length
        ;.word x + length, y, z + length
        ;.word x, y + length, z + length
        ;.word x + length, y + length, z + length
    ;.endmac

;.endif  ; GEOMETRY_I


