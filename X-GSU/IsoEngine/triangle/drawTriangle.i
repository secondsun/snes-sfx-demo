

; SuperFX triangle drawing code
; Summers Pittman <secondsun@gmail.com>
.ifndef ::__GSU_TRIS_DEFINED__
::__GSU_TRIS_DEFINED__ = 1   

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/control.i"
.include "../constants.i"
; Rasterizes a flat-shaded triangle to the GSU framebuffer
; In:       points = points array pointer (6 bytes: x0, y0, x1, y1, x2, y2), col = color
; Out:      Pixels plotted to framebuffer
; Clobbers: All
function draw_triangle points, col
    register yMin, yMax, yPoints, xMin, xMax, y0, y1, dy, x0
    register y = r2, x1 = r6, plot_x = r1
    
    with col
    color

        to yPoints
        from points
        add #2

        ;; Find the min and max y values
        ; yMax = yPoints[0]
        to yMax
        ldw (yPoints)
        ; yMin = yPoints[0]
        move yMin, yMax

        ;    if (yPoints[1] < yMin) yMin = yPoints[1]
        from yPoints 
        add #4
        ldw (r0)
        if_lt r0, yMin, {move yMin, r0}
        nop
        

        ;    if (yPoints[1] > yMax) yMax = yPoints[1]
        if_gt r0, yMax, {move yMax, r0}
        nop
        ;    if (yPoints[2] < yMin) yMin = yPoints[2]
        from yPoints 
        add #8
        ldw (r0)
        if_lt r0, yMin, {move yMin, r0}
        nop
        
        ;    if (yPoints[2] > yMax) yMax = yPoints[2]
        if_gt r0, yMax, {move yMax, r0}
        nop
        ;clamp yMin and yMax to 0-160
        ;   yMin = Math.max(0, yMin)
        ibt r0, #0
        if_lt yMin, r0, {move yMin, r0}
        nop
        ;   yMax = Math.min(160, yMax)
        iwt r0, #160
        if_lt r0, yMax, {move yMax, r0}
        nop
        if_lte yMax, yMin, { return }
        nop

        ;; Bounding box culling in X
        to xMax
        ldw (points)
        move xMin, xMax

        from points
        add #4
        ldw (r0)
        if_lt r0, xMin, {move xMin, r0}
        nop
        if_gt r0, xMax, {move xMax, r0}
        nop

        from points
        add #8
        ldw (r0)
        if_lt r0, xMin, {move xMin, r0}
        nop
        if_gt r0, xMax, {move xMax, r0}
        nop

        ; If all vertices have X < 0, entirely off-screen to the left
        ibt r0, #0
        if_lt xMax, r0, { return }
        nop

        ; If all vertices have X >= 256, entirely off-screen to the right
        iwt r0, #256
        if_gte xMin, r0, { return }
        nop
        ;cache the loop
        startCache:
        backuploop
        cache
        ;y = yMin
        ;start (y in minY..maxY) {
        move y, yMin
        iwt r13, #yLoop
        to r12
        from yMax
        sub yMin
          
            yLoop:
            ;var minX = Int.MAX_VALUE
            ;var maxX = Int.MIN_VALUE
            
            iwt xMin, #$0FFF
            iwt xMax, #$F000
            
            ;We're unrolling  for (i in 0 until nPoints) since nPoints is always 3 for a triangle
            ;val j = (i + 1) % nPoints : i == 0 j == 1
            ; y0 = yPoints[0]
            ; y1 = yPoints[1]
            ; x0 = points[0]
            ; x1 = points[1]
            i_eq_0:
            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
            to y0
            ldw (yPoints) ; y0 = yPoints[0]

            to dy
            from y
            sub y0; dy = y - y0

            
            from yPoints
            add #4
            to y1
            ldw (r0) ; y1 = yPoints[1]
            
            from y
            to x1
            sub y1; x1 = y - y1

            from dy
            xor x1 ; r0 = (y - y0) ^ (y - y1)

            ibt x0, #0
            if_gte r0, x0, { bra i_eq_1 }
            nop

            to x0
            ldw (points) ;x0 = points[0]
            
            from points
            add #4
            to x1
            ldw (r0) ;x1 = points[1]
            
            from y1
            sub y0
            bpl :+
                nop
                from x0
                sub x1
                move x0, x1
                move x1, r0
                from y
                to dy
                sub y1
                from y0
                sub y1
                bra :++
                nop
            :
                with x1
                sub x0
            :
            from dy ; dy = (y - top_Y)
            to x1
            mult x1 ; x1 (r6) = (y - top_Y) * (bottom_X - top_X)
            
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / |y1 - y0| in Q0.16
            
            
            to x1
            fmult ;x1 (r6) = ((y - y0) * (x1 - x0)  / (y1 - y0))
            to x0
            from x1
            add x0

;           if (x < xMin) xMin = x
;           if (x > xMax) xMax = x
            if_lt x0, xMin, { move xMin, x0 }
            nop
            if_gt x0, xMax, { move xMax, x0 }
            nop

            ;val j = (i + 1) % nPoints : i == 1  j == 2
        i_eq_1:
            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
            
            from yPoints
            add #4
            to y0
            ldw (r0) ; y0 = yPoints[1]

            to dy
            from y
            sub y0; dy = y - y0

            from yPoints
            add #8
            to y1
            ldw (r0) ; y1 = yPoints[2]
            

            from y
            to x1
            sub y1; x1 = y - y1

            from dy
            xor x1 ; r0 = (y - y0) ^ (y - y1)

            ibt x0, #0
            if_gte r0, x0, { bra i_eq_2 }
            nop

            from points
            add #4
            to x0
            ldw (r0) ;x0 = points[1]
            
            from points
            add #8
            to x1
            ldw (r0) ;x1 = points[2]
            
            from y1
            sub y0
            bpl :+
                nop
                from x0
                sub x1
                move x0, x1
                move x1, r0
                from y
                to dy
                sub y1
                from y0
                sub y1
                bra :++
                nop
            :
                with x1
                sub x0
            :
            from dy ; dy = (y - top_Y)
            to x1
            mult x1 ; x1 (r6) = (y - top_Y) * (bottom_X - top_X)
            
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / |y1 - y0| in Q0.16
            
            
            to x1
            fmult ;x1 (r6) = ((y - y0) * (x1 - x0)  / (y1 - y0))
            to x0
            from x1
            add x0

;               if (x0 < minX) minX = x0
;               if (x0 > maxX) maxX = x0
            if_lt x0, xMin, { move xMin, x0 }
            nop
            if_gt x0, xMax, { move xMax, x0 }
            nop


            ;val j = (i + 1) % nPoints :   i == 2  j == 0
        i_eq_2:
            ; if ((y0 <= y && y < y1) || (y1 <= y && y < y0))
            ; this is a range check that y is between y0 and y1, exclusive of the max value. 
            ; simplified logic ((y - y0) ^ (y - y1)) < 0
            
            from yPoints
            add #8
            to y0
            ldw (r0) ; y0 = yPoints[2]

            to dy
            from y
            sub y0; dy = y - y0

            to y1
            ldw (yPoints) ; y1 = yPoints[0]
            
            from y
            to x1
            sub y1; x1 = y - y1

            from dy
            xor x1 ; r0 = (y - y0) ^ (y - y1)

            ibt x0, #0
            if_gte r0, x0, {bra plotXLoop}
            nop

            from points
            add #8
            to x0
            ldw (r0) ;x0 = points[2]
            
            to x1
            ldw (points) ;x1 = points[0]
            
            from y1
            sub y0
            bpl :+
                nop
                from x0
                sub x1
                move x0, x1
                move x1, r0
                from y
                to dy
                sub y1
                from y0
                sub y1
                bra :++
                nop
            :
                with x1
                sub x0
            :
            from dy ; dy = (y - top_Y)
            to x1
            mult x1 ; x1 (r6) = (y - top_Y) * (bottom_X - top_X)
            
            reciprocal_lookup_rom r0, r0 ; r0 = 1 / |y1 - y0| in Q0.16
            
            
            to x1
            fmult ;x1 (r6) = ((y - y0) * (x1 - x0)  / (y1 - y0))
            to x0
            from x1
            add x0

;               if (x < minX) minX = x
;               if (x > maxX) maxX = x
            if_lt x0, xMin, { move xMin, x0 }
            nop
            if_gt x0, xMax, { move xMax, x0 }
            nop

            plotXLoop:
            ;end unrolled loop for (i in 0 until nPoints)

            iwt r0, #GSU_FRAME_HALF
            ldb (r0)
            with r0
            add #0
            beq :+
            nop
            iwt r0, #128
            with xMin
            sub r0
            with xMax
            sub r0
            :

            ; Clamp xMin to 0
            ibt r0, #0
            if_lt xMin, r0, { move xMin, r0 }
            nop

            ; Clamp xMax to 127
            iwt r0, #127
            if_gt xMax, r0, { move xMax, r0 }
            nop

            ; If xMin > xMax, span is outside the current buffer (or empty)
            if_gt xMin, xMax, { bra nextY }
            nop

            move plot_x, xMin
            from xMin 
            xor xMax
            lsr
            bcs startX
            nop
            plot
            
            if_gt plot_x, xMax, { bra nextY }
            nop
            startX:

            nextX:
                plot
                if_lt plot_x, xMax, { bra nextX }
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
        inc y
        ; //end for (y in minY..maxY) 
    endcache:
    restoreloop
    return
endfunction

.endif