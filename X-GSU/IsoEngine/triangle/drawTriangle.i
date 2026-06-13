

; SuperFX triangle drawing code
; Summers Pittman <secondsun@gmail.com>
.ifndef ::__GSU_TRIS_DEFINED__
::__GSU_TRIS_DEFINED__ = 1   

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"


; In : r3 = xPoints array pointer
;      r4 = yPoints array pointer
;      r5 = color
; Clobbers : r0, r1, r2, r3, r4, r5, r6, r7, r8, r12, r13
; Out : Nada
function draw_triangle
    with r5
    color

    register yMin = r5
    register yMax = r6

    ;; Find the min and max y values
        ; xMin = yPoints[0]
        to yMax
        ldw (r4)
        ; yMin = yPoints[0]
        move yMin, yMax

        ;    if (yPoints[1] < minY) minY = yPoints[1]
        from r4 
        add #2
        ldw (r0)
        cmp yMin
        bge :+
        nop
        move yMin, r0
        
        : ;    if (yPoints[1] > maxY) maxY = yPoints[1]
        cmp yMax
        blt :+
        nop
        move yMax, r0
        
        :;    if (yPoints[2] < minY) minY = yPoints[2]
        from r4 
        add #4
        ldw (r0)
        cmp yMin
        bge :+
        nop
        move yMin, r0
        
        :;    if (yPoints[2] > maxY) maxY = yPoints[2]
        cmp yMax
        blt :+
        nop
        move yMax, r0
        : ;skip

        ;   minY = Math.max(0, minY)
        sub r0
        cmp yMin
        blt :+
        nop
        move yMin, r0       
        : ;   maxY = Math.min(height - 1, maxY)
        iwt r0, #172
        cmp yMax
        bge :+
        nop
        move yMax, r0       
        : ; skip

    return
endfunction

.endif