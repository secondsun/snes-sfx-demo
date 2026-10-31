

; SuperFX triangle drawing code
; Summers Pittman <secondsun@gmail.com>
.ifndef ::__GSU_TRIS_DEFINED__
::__GSU_TRIS_DEFINED__ = 1   

.include "libSFX.i"
.include "../../common/stack.i"
.include "../../common/function.i"
.include "../../common/control.i"
.include "../constants.i"
.include "../Data/TEXTURES.i"
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

; Plot a single texel at the current position. This function will 
; load a texel from the specified atlas and plot a pixel at x and y
; xPx: X coordinate of the texel
; yPx: Y coordinate of the texel
; uTex: U coordinate of the texel
; vTex: V coordinate of the texel
; table_index: Index of the texture table entry
function plot_texel xPx, yPx, uTex, vTex, table_index
    register plot_x = r1, plot_y = r2
    ;set plot options
    move plot_x, xPx
    move plot_y, yPx

    ; Implementation for plotting a single texel goes here
    register texture_base_address
    
    ;find texture table entry
    ;texture table entry address = TEXTURE_TABLE + table_index * 8
    
    iwt texture_base_address, #(.loword(TEXTURE_TABLE))
    with table_index
    mult #8
    with texture_base_address
    add table_index

    ;r0 = texture rom_offset
    ;for the rest of this code we're assuming textures are 32x32
    bpl @load_tex_from_ram
    nop
        with table_index
        add #0
        bne :+
        nop
            ibt r0, #0
            bra @tex_offset_ready
            nop
        :
        ibt r0, #8
        from table_index
        cmp r0
        bne :+
        nop
            ibt r0, #32
            bra @tex_offset_ready
            nop
        :
        ibt r0, #16
        from table_index
        cmp r0
        bne :+
        nop
            iwt r0, #2080
            bra @tex_offset_ready
            nop
        :
        ibt r0, #24
        from table_index
        cmp r0
        bne :+
        nop
            iwt r0, #2048
            bra @tex_offset_ready
            nop
        :
        ibt r0, #40
        from table_index
        cmp r0
        bne :+
        nop
            iwt r0, #4096
            bra @tex_offset_ready
            nop
        :
        ibt r0, #3
        romb
        move r14, texture_base_address
        getbl
        inc r14
        getbh
        move texture_base_address, r0
        ibt r0, #4
        romb
        move r0, texture_base_address
        bra @tex_offset_ready
        nop
@load_tex_from_ram:
    to r0
    ldw (texture_base_address)
@tex_offset_ready:

    ;texture offset = vTex * ATLAS_WIDTH + uTex
    ;vText = offset within texture
    iwt r6, #ATLAS_WIDTH
    with vTex
    umult r6
    with vTex
    add uTex

    to r14
    from vTex
    add r0
    ;fetch and plot color
    getc
    plot

    return
endfunction

; Rasterizes an affine-textured triangle to the GSU framebuffer using plot_texel
; In:       points = pointer to 3 interleaved vertices (24 bytes: x0, y0, u0, v0, x1, y1, u1, v1, x2, y2, u2, v2)
;                    where x, y are integer screen coordinates and u, v are Q8.8 texture coordinates
;           table_index = index into TEXTURE_TABLE
; Out:      Texels plotted to framebuffer
; Clobbers: All
function draw_textured_triangle points, table_index
    register curr_y = r2, u_val = r4, f_reg = r6
    register xMin, xMax, v0_ptr, v1_ptr, dy

    iwt r0, #TEX_TRI_TBL_IDX
    from table_index
    stw (r0)

    ; yPoints[0] is at points + 2
    from points
    to dy
    add #2

    ; maxY (v1_ptr) = yPoints[0], minY (v0_ptr) = yPoints[0]
    to v1_ptr
    ldw (dy)
    move v0_ptr, v1_ptr

    ; yPoints[1] is at points + 10 (dy + 8)
    from dy
    add #8
    ldw (r0)
    if_lt r0, v0_ptr, { move v0_ptr, r0 }
    nop
    if_gt r0, v1_ptr, { move v1_ptr, r0 }
    nop

    ; yPoints[2] is at points + 18 (dy + 16)
    from dy
    add #8
    add #8
    ldw (r0)
    if_lt r0, v0_ptr, { move v0_ptr, r0 }
    nop
    if_gt r0, v1_ptr, { move v1_ptr, r0 }
    nop

    ; Clamp minY and maxY to 0..SCREEN_HEIGHT (160)
    ibt r0, #0
    if_lt v0_ptr, r0, { move v0_ptr, r0 }
    nop
    iwt r0, #SCREEN_HEIGHT
    if_lt r0, v1_ptr, { move v1_ptr, r0 }
    nop
    if_lte v1_ptr, v0_ptr, { return }
    nop

    ; Bounding box culling in X (x0 at +0, x1 at +8, x2 at +16)
    to xMax
    ldw (points)
    move xMin, xMax

    from points
    add #8
    ldw (r0)
    if_lt r0, xMin, { move xMin, r0 }
    nop
    if_gt r0, xMax, { move xMax, r0 }
    nop

    from points
    add #8
    add #8
    ldw (r0)
    if_lt r0, xMin, { move xMin, r0 }
    nop
    if_gt r0, xMax, { move xMax, r0 }
    nop

    ; If all vertices have X < 0, entirely off-screen to the left
    ibt r0, #0
    if_lt xMax, r0, { return }
    nop

    ; If all vertices have X >= 256, entirely off-screen to the right
    iwt r0, #256
    if_gte xMin, r0, { return }
    nop

    backuploop
    move curr_y, v0_ptr
    iwt r13, #yLoop
    to r12
    from v1_ptr
    sub v0_ptr

yLoop:
    iwt xMin, #$0FFF
    iwt xMax, #$F000
    ibt dy, #0
    iwt r0, #TEX_TRI_MIN_U
    from dy
    stw (r0)
    iwt r0, #TEX_TRI_MAX_U
    from dy
    stw (r0)
    iwt r0, #TEX_TRI_MIN_V
    from dy
    stw (r0)
    iwt r0, #TEX_TRI_MAX_V
    from dy
    stw (r0)

    ; Edge 0: i = 0 (points + 0), j = 1 (points + 8)
i_eq_0:
    from points
    to v0_ptr
    add #2
    from points
    to v1_ptr
    add #10

    to u_val
    ldw (v0_ptr)    ; u_val = y0
    from curr_y
    to dy
    sub u_val       ; dy = y - y0

    to f_reg
    ldw (v1_ptr)    ; f_reg = y1
    from curr_y
    sub f_reg       ; r0 = y - y1
    xor dy          ; r0 = (y - y0) ^ (y - y1)
    bpl i_eq_1
    nop

    from f_reg
    sub u_val
    bpl :+
    nop
        move dy, v0_ptr
        move v0_ptr, v1_ptr
        move v1_ptr, dy
        from curr_y
        to dy
        sub f_reg
        from u_val
        sub f_reg
    :
    reciprocal_lookup_rom r0, f_reg
    from dy
    lmult
    from u_val
    to f_reg
    lsr

    dec v0_ptr
    dec v0_ptr
    dec v1_ptr
    dec v1_ptr

    to u_val
    ldw (v0_ptr)    ; x_top
    ldw (v1_ptr)    ; x_bot
    sub u_val
    add r0
    fmult
    to dy
    add u_val       ; dy = x

    from v0_ptr
    to v0_ptr
    add #4
    from v1_ptr
    to v1_ptr
    add #4

    to u_val
    ldw (v0_ptr)    ; u_top
    ldw (v1_ptr)    ; u_bot
    sub u_val
    add r0
    fmult
    with u_val
    add r0          ; u_val = u

    inc v0_ptr
    inc v0_ptr
    inc v1_ptr
    inc v1_ptr

    to v0_ptr
    ldw (v0_ptr)    ; v_top
    ldw (v1_ptr)    ; v_bot
    sub v0_ptr
    add r0
    fmult
    with v0_ptr
    add r0          ; v0_ptr = v

    from dy
    cmp xMin
    bge :+
    nop
        move xMin, dy
        iwt r0, #TEX_TRI_MIN_U
        from u_val
        stw (r0)
        iwt r0, #TEX_TRI_MIN_V
        from v0_ptr
        stw (r0)
    :
    from xMax
    cmp dy
    bge :+
    nop
        move xMax, dy
        iwt r0, #TEX_TRI_MAX_U
        from u_val
        stw (r0)
        iwt r0, #TEX_TRI_MAX_V
        from v0_ptr
        stw (r0)
    :

    ; Edge 1: i = 1 (points + 8), j = 2 (points + 16)
i_eq_1:
    from points
    to v0_ptr
    add #10
    from v0_ptr
    to v1_ptr
    add #8

    to u_val
    ldw (v0_ptr)    ; u_val = y0
    from curr_y
    to dy
    sub u_val       ; dy = y - y0

    to f_reg
    ldw (v1_ptr)    ; f_reg = y1
    from curr_y
    sub f_reg       ; r0 = y - y1
    xor dy          ; r0 = (y - y0) ^ (y - y1)
    bpl i_eq_2
    nop

    from f_reg
    sub u_val
    bpl :+
    nop
        move dy, v0_ptr
        move v0_ptr, v1_ptr
        move v1_ptr, dy
        from curr_y
        to dy
        sub f_reg
        from u_val
        sub f_reg
    :
    reciprocal_lookup_rom r0, f_reg
    from dy
    lmult
    from u_val
    to f_reg
    lsr

    dec v0_ptr
    dec v0_ptr
    dec v1_ptr
    dec v1_ptr

    to u_val
    ldw (v0_ptr)    ; x_top
    ldw (v1_ptr)    ; x_bot
    sub u_val
    add r0
    fmult
    to dy
    add u_val       ; dy = x

    from v0_ptr
    to v0_ptr
    add #4
    from v1_ptr
    to v1_ptr
    add #4

    to u_val
    ldw (v0_ptr)    ; u_top
    ldw (v1_ptr)    ; u_bot
    sub u_val
    add r0
    fmult
    with u_val
    add r0          ; u_val = u

    inc v0_ptr
    inc v0_ptr
    inc v1_ptr
    inc v1_ptr

    to v0_ptr
    ldw (v0_ptr)    ; v_top
    ldw (v1_ptr)    ; v_bot
    sub v0_ptr
    add r0
    fmult
    with v0_ptr
    add r0          ; v0_ptr = v

    from dy
    cmp xMin
    bge :+
    nop
        move xMin, dy
        iwt r0, #TEX_TRI_MIN_U
        from u_val
        stw (r0)
        iwt r0, #TEX_TRI_MIN_V
        from v0_ptr
        stw (r0)
    :
    from xMax
    cmp dy
    bge :+
    nop
        move xMax, dy
        iwt r0, #TEX_TRI_MAX_U
        from u_val
        stw (r0)
        iwt r0, #TEX_TRI_MAX_V
        from v0_ptr
        stw (r0)
    :

    ; Edge 2: i = 2 (points + 16), j = 0 (points + 0)
i_eq_2:
    from points
    to v0_ptr
    add #10
    with v0_ptr
    add #8
    from points
    to v1_ptr
    add #2

    to u_val
    ldw (v0_ptr)    ; u_val = y0
    from curr_y
    to dy
    sub u_val       ; dy = y - y0

    to f_reg
    ldw (v1_ptr)    ; f_reg = y1
    from curr_y
    sub f_reg       ; r0 = y - y1
    xor dy          ; r0 = (y - y0) ^ (y - y1)
    bpl plotXLoop
    nop

    from f_reg
    sub u_val
    bpl :+
    nop
        move dy, v0_ptr
        move v0_ptr, v1_ptr
        move v1_ptr, dy
        from curr_y
        to dy
        sub f_reg
        from u_val
        sub f_reg
    :
    reciprocal_lookup_rom r0, f_reg
    from dy
    lmult
    from u_val
    to f_reg
    lsr

    dec v0_ptr
    dec v0_ptr
    dec v1_ptr
    dec v1_ptr

    to u_val
    ldw (v0_ptr)    ; x_top
    ldw (v1_ptr)    ; x_bot
    sub u_val
    add r0
    fmult
    to dy
    add u_val       ; dy = x

    from v0_ptr
    to v0_ptr
    add #4
    from v1_ptr
    to v1_ptr
    add #4

    to u_val
    ldw (v0_ptr)    ; u_top
    ldw (v1_ptr)    ; u_bot
    sub u_val
    add r0
    fmult
    with u_val
    add r0          ; u_val = u

    inc v0_ptr
    inc v0_ptr
    inc v1_ptr
    inc v1_ptr

    to v0_ptr
    ldw (v0_ptr)    ; v_top
    ldw (v1_ptr)    ; v_bot
    sub v0_ptr
    add r0
    fmult
    with v0_ptr
    add r0          ; v0_ptr = v

    from dy
    cmp xMin
    bge :+
    nop
        move xMin, dy
        iwt r0, #TEX_TRI_MIN_U
        from u_val
        stw (r0)
        iwt r0, #TEX_TRI_MIN_V
        from v0_ptr
        stw (r0)
    :
    from xMax
    cmp dy
    bge :+
    nop
        move xMax, dy
        iwt r0, #TEX_TRI_MAX_U
        from u_val
        stw (r0)
        iwt r0, #TEX_TRI_MAX_V
        from v0_ptr
        stw (r0)
    :

plotXLoop:
    ; If no edge intersected this scanline (xMin > xMax), skip to nextY
    from xMax
    cmp xMin
    bge :+
    nop
    iwt r15, #nextY
    nop
:
    ; Shift xMin and xMax by -128 when rendering the right half of the screen
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
    ; Check if minX == maxX or minX < maxX
    from xMin
    cmp xMax
    bne :+
    nop
    iwt r15, #singlePixelSpan
    nop
:

    ; startX (v0_ptr) = Math.max(0, minX)
    move v0_ptr, xMin
    ibt r0, #0
    if_lt v0_ptr, r0, { move v0_ptr, r0 }
    nop

    ; endX (v1_ptr) = Math.min(SCREEN_WIDTH - 1, maxX)
    move v1_ptr, xMax
    iwt r0, #(SCREEN_WIDTH - 1)
    if_gt v1_ptr, r0, { move v1_ptr, r0 }
    nop

    ; If startX > endX, span is outside the active 128px screen half
    from v1_ptr
    cmp v0_ptr
    bge :+
    nop
    iwt r15, #nextY
    nop
:
    ; Precompute 1 / dx in Q0.15 for the scanline and restore ROM bank 4
    from xMax
    sub xMin
    reciprocal_lookup_rom r0, f_reg
    ibt dy, #1
    from r0
    cmp dy
    beq :+
    nop
        dec f_reg
        with f_reg
        lsr
    :
    iwt r0, #TEX_TRI_RECIP_DX
    from f_reg
    stw (r0)
    ibt r0, #4
    romb

xLoop:
    iwt r0, #TEX_TRI_RECIP_DX
    to f_reg
    ldw (r0)
    from v0_ptr
    sub xMin
    lmult
    move f_reg, u_val

    ; u = minU + (((maxU - minU) * f) >> 8)
    iwt r0, #TEX_TRI_MIN_U
    to u_val
    ldw (r0)
    iwt r0, #TEX_TRI_MAX_U
    to dy
    ldw (r0)
    from dy
    sub u_val
    add r0
    fmult
    with u_val
    add r0

    ; v = minV + (((maxV - minV) * f) >> 8)
    iwt r0, #TEX_TRI_MIN_V
    to dy
    ldw (r0)
    iwt r0, #TEX_TRI_MAX_V
    ldw (r0)
    sub dy
    add r0
    fmult
    to f_reg
    add dy

    ; tu = (u >> 8) & 31
    with u_val
    hib
    ibt r0, #31
    to u_val
    and u_val

    ; tv = (v >> 8) & 31
    with f_reg
    hib
    to f_reg
    and f_reg

    iwt r0, #TEX_TRI_TBL_IDX
    to dy
    ldw (r0)
    call plot_texel v0_ptr, curr_y, u_val, f_reg, dy

    inc v0_ptr
    from v1_ptr
    cmp v0_ptr
    bge xLoop
    nop
    bra nextY
    nop

singlePixelSpan:
    ; else if (minX == maxX && minX in 0 until width)
    ibt r0, #0
    from xMin
    cmp r0
    blt nextY
    nop
    iwt r0, #SCREEN_WIDTH
    from xMin
    cmp r0
    bge nextY
    nop

    iwt r0, #TEX_TRI_MIN_U
    to u_val
    ldw (r0)
    with u_val
    hib
    ibt r0, #31
    to u_val
    and u_val

    iwt r0, #TEX_TRI_MIN_V
    to f_reg
    ldw (r0)
    with f_reg
    hib
    to f_reg
    and f_reg

    ibt r0, #4
    romb

    iwt r0, #TEX_TRI_TBL_IDX
    to dy
    ldw (r0)
    call plot_texel xMin, curr_y, u_val, f_reg, dy

nextY:
    loop
    inc curr_y

    restoreloop
    return
endfunction

.segment "GSURAM"
TEX_TRI_MIN_U:
    .res 2
TEX_TRI_MAX_U:
    .res 2
TEX_TRI_MIN_V:
    .res 2
TEX_TRI_MAX_V:
    .res 2
TEX_TRI_RECIP_DX:
    .res 2
TEX_TRI_TBL_IDX:
    .res 2

.segment "GSUCODE"

.endif