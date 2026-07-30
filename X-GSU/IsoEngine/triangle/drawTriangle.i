

; SuperFX triangle drawing code
; Summers Pittman <secondsun@gmail.com>
.ifndef ::__GSU_TRIS_DEFINED__
::__GSU_TRIS_DEFINED__ = 1   

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/control.i"
.include "../constants.i"
; In : r3 = points array pointer. Points are one byte each, byte aligned. 
;       The point format is x,y pairs. The array is 6 bytes long for a triangle.
;      r5 = color
; Clobbers : r0, r1, r2, r3, r4, r5, r6, r7, r8, r12, r13
; Out : Nada
function draw_triangle
    
    with r5
    color

    register yMin = r5
    register yMax = r8
    register points = r3
    register yPoints = r4
    register xPoints = r3

        to yPoints
        from points
        add #1

        ;move xPoints, points //registers are the same

        ;; Find the min and max y values
        ; xMin = yPoints[0]
        to yMax
        ldb (yPoints)
        ; yMin = yPoints[0]
        move yMin, yMax

        ;    if (yPoints[1] < yMin) yMin = yPoints[1]
        from yPoints 
        add #2
        ldb (r0)
        if_lt r0, yMin, {move yMin, r0}
        nop
        

        ;    if (yPoints[1] > yMax) yMax = yPoints[1]
        if_gt r0, yMax, {move yMax, r0}
        nop
        ;    if (yPoints[2] < yMin) yMin = yPoints[2]
        from yPoints 
        add #4
        ldb (r0)
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
        ;cache the loop
        startCache:
        cache
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
            ldb (yPoints) ; y0 = yPoints[0]

            to r1
            from r2
            sub y0; r1 = y - y0

            
            from yPoints
            add #2
            to y1
            ldb (r0) ; y1 = yPoints[1]
            
            from r2
            to r6
            sub y1; r6 = y - y1

            from r1
            xor r6 ; r0= (y - y0) ^ (y - y1)

            ibt r7, #0 ;we will save r1 for y-y0 in it
            ;TODO : implement from here
            if_gte r0, r7, { bra i_eq_1 }
            nop
            register x0 = r7
            register x1 = r6 ;x1 has to be r6 because the reister is used later for a multiplication

            to x0
            ldb(xPoints) ;x0=xPoints[0]
            
            from xPoints
            add #2
            to x1
            ldb(r0) ;x1=xPoints[1]
            

            
            ;x1-x0
            with x1
            sub x0

            from r1 ; r1 = (y - y0)
            to x1
            mult x1 ; r6 = (y - y0) * (x1 - x0) 
            

            ;val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            ; r0 = 1 / (y1 - y0)
            from y1
            sub y0
            
            beq :+
                nop
            bpl :+ ;if y1-y0 is negative, we need to negate (x1-x0) because we lose
                   ; the sign when we get the reciprocol

                nop
                with x1
                not
                with x1
                add #1
                not
                add #1

            :
            
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / (y1 - y0) in Q0.16
            
            
            to x1
            fmult ;r6 = ((y - y0) * (x1 - x0)  / (y1 - y0))
            to x0
            from r6
            add x0

;           if (x < xMin) xMin = x
;           if (x > xMax) xMax = x
            if_lt r7, r5, { move r5, r7 }
            nop
            if_gt r7, r8, { move r8, r7 }
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
            ldb (r0) ; y0 = yPoints[1]

            to r1
            from r2
            sub y0; r1 = y - y0

            from yPoints
            add #4
            to y1
            ldb (r0) ; r0 = yPoints[2]
            

            from r2
            to r6
            sub y1; r6 = y - y1

            from r1
            xor r6 ; r0= (y - y0) ^ (y - y1)

            ibt r7, #0 ;we will save r1 for y-y0 in it
            ;TODO : implement from here
            if_gte r0, r7, { bra i_eq_2 }
            nop
;            register x0 = r7
;            register x1 = r6 ;x1 has to be r6 because the reister is used later for a multiplication

            
            from xPoints
            add #2
            to x0
            ldb(r0) ;x0=xPoints[1]
            
            from xPoints
            add #4
            to x1
            ldb(r0) ;x1=xPoints[2]
            
            ;x1-x0
            with x1
            sub x0

            from r1 ; r1 = (y - y0)
            to x1
            mult x1 ; r6(x1) = (y - y0) * (x1 - x0) 

            ;val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            ; r0 = 1 / (y1 - y0)
            from y1
            sub y0
            
            beq :+
                nop
            bpl :+ ;if y1-y0 is negative, we need to negate (x1-x0) because we lose
                   ; the sign when we get the reciprocol
                nop
                with x1
                not
                with x1
                add #1
                not
                add #1
            :
            
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / (y1 - y0) in Q0.16
            
            
            to x1
            fmult ;r6 = ((y - y0) * (x1 - x0)  / (y1 - y0))
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
            ldb (r0) ; r1 = yPoints[2]

            to r1
            from r2
            sub y0; r1 = y - y0

            to y1
            ldb (yPoints) ; r0 = yPoints[0]
            
            from r2
            to r6
            sub y1; r6 = y - y1

            from r1
            xor r6 ; r0= (y - y0) ^ (y - y1)

            ibt r7, #0 ;we will save r1 for y-y0 in it
            ;TODO : implement from here
            if_gte r0, r7, {bra plotXLoop}
            nop
            ;register x0 = r7
            ;register x1 = r6 ;x1 has to be r6 because the reister is used later for a multiplication

            
            from xPoints
            add #4
            to x0
            ldb(r0) ;x0=xPoints[2]
            
            to x1
            ldb(xPoints) ;x1=xPoints[0]
            
            ;x1-x0
            with x1
            sub x0

            from r1 ; r1 = (y - y0)
            to x1
            mult x1 ; r6 = (y - y0) * (x1 - x0) 
            

            ;val x = x0 + (y - y0) * (x1 - x0) / (y1 - y0)
            ; r0 = 1 / (y1 - y0)
            from y1
            sub y0
            
            beq :+
                nop
            bpl :+ ;if y1-y0 is negative, we need to negate (x1-x0) because we lose
                   ; the sign when we get the reciprocol. This negation here 
                   ; preserves it
                nop
                with x1
                not
                with x1
                add #1
                not
                add #1
            :
            
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / (y1 - y0) in Q0.16
            
            
            to x1
            fmult ;r6 = ((y - y0) * (x1 - x0)  / (y1 - y0))
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
            ; unscope all registers but r2 (y), r12 and r13 (loop control), xMin(r5) and xMax(r8). 

            ;if (minX <= maxX) {
            if_gt xMin, xMax, { bra nextY }
            nop

            from xMin 
            xor xMax
            lsr
            bcc startX
            nop
            move r1, xMin
            plot
            
            if_gte r1   , xMax, { bra nextY }
            nop
            startX:
            move r1, xMin

            nextX:
                plot
                if_lt r1, xMax, { bra nextX }
                plot
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
    endcache:
    return
endfunction

.endif