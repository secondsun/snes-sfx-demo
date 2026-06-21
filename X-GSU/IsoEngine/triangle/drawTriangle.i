

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
    register yMax = r8
    register yPoints = r4
    register xPoints = r3

    ;; Find the min and max y values
        ; xMin = yPoints[0]
        to yMax
        ldw (yPoints)
        ; yMin = yPoints[0]
        move yMin, yMax

        ;    if (yPoints[1] < yMin) yMin = yPoints[1]
        from yPoints 
        add #2
        ldw (r0)
        if_lt r0, yMin, {move yMin, r0}
        nop
        

        ;    if (yPoints[1] > yMax) yMax = yPoints[1]
        if_gt r0, yMax, {move yMax, r0}
        nop
        ;    if (yPoints[2] < yMin) yMin = yPoints[2]
        from yPoints 
        add #4
        ldw (r0)
        if_lt r0, yMin, {move yMin, r0}
        nop
        
        ;    if (yPoints[2] > yMax) yMax = yPoints[2]
        if_gt r0, yMax, {move yMax, r0}
        nop
        ;clamp yMin and yMax to 0-172
        ;   yMin = Math.max(0, yMin)
        sub r0
        if_gt r0, yMin, {move yMin, r0}
        nop
        ;   yMax = Math.min(172, yMax)
        iwt r0, #172
        if_lt r0, yMax, {move yMax, r0}
        nop
        if_lt yMax, yMin, { return }
        nop
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
            register xMax = yMax
            ;var minX = Int.MAX_VALUE
            ;var maxX = Int.MIN_VALUE
            
            iwt xMin, #$7FFF
            iwt xMax, #$8000
            
            ;We're unrolling  for (i in 0 until nPoints) since nPoints is always 3 for a triangle
            ;val j = (i + 1) % nPoints : i == 0 j == 1
            ; y0 = yPoints[0]
            ; y1 = yPoints[1]
            ; x0 = xPoints[0]
            ; x1 = xPoints[1]
            i_eq_0:
            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
            register y0 = r9
            register y1 = r11
            to y0
            ldw (yPoints) ; r1 = yPoints[0]

            to r1
            from r2
            sub y0; r1 = y - y0

            
            from yPoints
            add #2
            to y1
            ldw (r0) ; r0 = yPoints[1]
            
            from r2
            to r6
            sub y1; r6 = y - y1

            from r1
            xor r6 ; r0= (y - y0) ^ (y - y1)

            ibt r7, #0 ;we will save r1 for y-y0 in it
            ;TODO : implement from here
            if_gt r0, r7, { bra i_eq_1 }
            nop
            register x0 = r7
            register x1 = r6 ;x1 has to be r6 because the reister is used later for a multiplication

            to x0
            ldw(xPoints) ;x0=xPoints[0]
            from xPoints
            add #2
            to x1
            ldw(r0) ;x1=xPoints[1]
            

            
            
            ;val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            ; r0 = 1 / (y1 - y0)
            from y1
            sub y0
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / (y1 - y0) in Q0.16
            with x1
            sub x0
            ;x1-x0
            to x1
            fmult ;r6 = ((x1 - x0) / (y1 - y0))
            from r1 ; r1 = (y - y0)
            to x1
            mult x1 ; r6 = (y - y0) * (x1 - x0) / (y1 - y0)
            to x0
            from r6
            add x0

;                minX = x
;               if (x > maxX) maxX = x
             move xMin, x0
            nop
             move xMax, x0
            nop

            ;val j = (i + 1) % nPoints : i == 1  j == 2
            i_eq_1:
            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
;            register y0 = r9
;            register y1 = r11
            
            
            from yPoints
            add #2
            to y0
            ldw (r0) ; r1 = yPoints[1]

            to r1
            from r2
            sub r1; r1 = y - y0

            from yPoints
            add #4
            ldw (r0) ; r0 = yPoints[2]
            move y1, r0;y1 = yPoints[2]

            from r2
            to r6
            sub r0; r6 = y - y1

            from r1
            xor r6 ; r0= (y - y0) ^ (y - y1)

            ibt r7, #0 ;we will save r1 for y-y0 in it
            ;TODO : implement from here
            if_gt r0, r7, { bra i_eq_2 }
            nop
;            register x0 = r7
;            register x1 = r6 ;x1 has to be r6 because the reister is used later for a multiplication

            
            from xPoints
            add #2
            to x0
            ldw(r0) ;x0=xPoints[1]
            
            from xPoints
            add #4
            to x1
            ldw(r0) ;x1=xPoints[2]
            

            
            
            ;val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            ; r0 = 1 / (y1 - y0)
            from y1
            sub y0
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / (y1 - y0) in Q0.16
            with x1
            sub x0
            ;x1-x0
            to x1
            fmult ;r6 = ((x1 - x0) / (y1 - y0))
            from r1 ; r1 = (y - y0)
            to x1
            mult x1 ; r6 = (y - y0) * (x1 - x0) / (y1 - y0)
            to x0
            from r6
            add x0

;               if (x0 < minX) minX = x0
;               if (x0 > maxX) maxX = x0
            if_lt r7, r5, { move r5, r7 }
            nop
            if_gt r7, r8, { move r8, r7 }
            nop


            ;val j = (i + 1) % nPoints :   i == 2  j == 0
            i_eq_2:
            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
            ;register y0 = x9
            ;register y1 = x11
            
            to r0
            from yPoints
            add #4
            to y0
            ldw (r0) ; r1 = yPoints[2]

            to r1
            from r2
            sub r1; r1 = y - y0

            ldw (yPoints) ; r0 = yPoints[0]
            move y1, r0;y1 = yPoints[0]
            from r2
            to r6
            sub r0; r6 = y - y1

            from r1
            xor r6 ; r0= (y - y0) ^ (y - y1)

            ibt r7, #0 ;we will save r1 for y-y0 in it
            ;TODO : implement from here
            if_gt r0, r7, {bra plotXLoop}
            nop
            ;register x0 = r7
            ;register x1 = r6 ;x1 has to be r6 because the reister is used later for a multiplication

            
            from xPoints
            add #4
            to x0
            ldw(r0) ;x0=xPoints[2]
            
            to x1
            ldw(xPoints) ;x1=xPoints[0]
            

            
            
            ;val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            ; r0 = 1 / (y1 - y0)
            from y1
            sub y0
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / (y1 - y0) in Q0.16
            with x1
            sub x0
            ;x1-x0
            to x1
            fmult ;r6 = ((x1 - x0) / (y1 - y0))
            from r1 ; r1 = (y - y0)
            to x1
            mult x1 ; r6 = (y - y0) * (x1 - x0) / (y1 - y0)
            to x0
            from r6
            add x0

;               if (x < minX) minX = x
;               if (x > maxX) maxX = x
            if_lt r7, r5, { move r5, r7 }
            nop
            if_gt r7, r8, { move r8, r7 }
            nop

            plotXLoop:
            ;end unrolled loop for (i in 0 until nPoints)
; unscope all registers but r2 (y), r12 and r13 (loop control), xMin and xMax. 

            ;if (minX <= maxX) {
            if_gt xMin, xMax, { bra nextY }
            nop
            ;    val startX = Math.max(0, minX)
            ;    val endX = Math.min(width - 1, maxX)
            move r1, xMin
            
            nextX:
                plot
                if_lt r1, xMax, { bra nextX }
                nop
            ;    for (x in startX..endX) {
            ;        if (!isPixelSet(x, y)) {
            ;            pixels[y * width + x] = color
            ;            setPixelBit(x, y)
            ;        }
            ;    }
            ;}
            
            
           
        nextY:
        loop
        inc r2
        ; //end for (y in minY..maxY) 
    
    return
endfunction

.endif