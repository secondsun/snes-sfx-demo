

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
    register yPoints = r4
    register xPoints = r3

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
        ;start (y in minY..maxY) {
        move r2, yMin
        iwt r13, #yLoop
        to r12
        from yMax
        sub yMin
            
            yLoop:
            ;we are done with yMin and yMax so lets reuse the registers
            register xMin = yMin
            register xMax = yMin
            ;var minX = Int.MAX_VALUE
            ;var maxX = Int.MIN_VALUE
            iwt minX, #$7FFF
            iwt maxX, #$8000
            
            ;We're unrolling  for (i in 0 until nPoints) since nPoints is always 3 for a triangle
            ;val j = (i + 1) % nPoints : i == 0 j == 1
            ; y0 = yPoints[0]
            ; y1 = yPoints[1]
            ; x0 = xPoints[0]
            ; x1 = xPoints[1]

            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
            to r1
            ldw (r4) ; r1 = yPoints[0]

            to r1
            from r2
            sub r1; r1 = y - y0

            to r0
            from r4
            add #2
            ldw (r0) ; r0 = yPoints[1]
            from r2
            sub r0; r0 = y - y1

            from r1
            xor r0 ; r0= (y - y0) ^ (y - y1)

            ivt r1, #0
            ;TODO : implement from here
            if_lt r0, r1, {
;               val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
;               if (x < minX) minX = x
;               if (x > maxX) maxX = x
            }

            ;val j = (i + 1) % nPoints : i == 1  j == 2
            
            ;val j = (i + 1) % nPoints :   i == 2  j == 0

            ;end unrolled loop for (i in 0 until nPoints)

            ;if (minX <= maxX) {
            ;    val startX = Math.max(0, minX)
            ;    val endX = Math.min(width - 1, maxX)
            ;    for (x in startX..endX) {
            ;        if (!isPixelSet(x, y)) {
            ;            pixels[y * width + x] = color
            ;            setPixelBit(x, y)
            ;        }
            ;    }
            ;}
            
            
           

        loop
        inc r2
        ; //end for (y in minY..maxY) 
    
    return
endfunction

.endif