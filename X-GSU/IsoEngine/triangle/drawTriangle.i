

; SuperFX triangle drawing code
; Summers Pittman <secondsun@gmail.com>
.ifndef ::__GSU_TRIS_DEFINED__
::__GSU_TRIS_DEFINED__ = 1   

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/control.i"

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

        ;    if (yPoints[1] < yMin) yMin = yPoints[1]
        from r4 
        add #2
        ldw (r0)
        if_lt r0, yMin, {move yMin, r0}
        

        ;    if (yPoints[1] > yMax) yMax = yPoints[1]
        if_gt r0, yMax, {move yMax, r0}
        
        ;    if (yPoints[2] < yMin) yMin = yPoints[2]
        from r4 
        add #4
        ldw (r0)
        if_lt r0, yMin, {move yMin, r0}
        
        
        ;    if (yPoints[2] > yMax) yMax = yPoints[2]
        if_gt r0, yMax, {move yMax, r0}
        
        ;clamp yMin and yMax to 0-172
        ;   yMin = Math.max(0, yMin)
        sub r0
        if_gt r0, yMin, {move yMin, r0}
        
        ;   yMax = Math.min(172, yMax)
        iwt r0, #172
        if_lt r0, yMax, {move yMax, r0}
        
        if_lt yMax, yMin, { return }

        ;y = yMin
        move r2, yMin
        iwt r13, #yLoop
        to r12
        from yMax
        sub yMin
            
            yLoop:
            ;we are done with yMin and yMax so lets reuse the registers
            register xMin = yMin
            register xMax = yMin

            
            reciprocal_lookup_rom r2, r0 ; r0 = 1/y

        loop
        inc r2
    
    
    return
endfunction

.endif