.ifndef ::__GEOMETRY_DEFINED__
::__GEOMETRY_DEFINED__ = 1   
; geometry.i - geometry related macros/definitions

    ;Each of these variables is a Q8.8 fixed point number. 
    .macro cube _x, _y, _z, _side_length

        .if     .paramcount <> 4
            .error  "Too few parameters for macro cube"
        .endif
        ; define cube as 12 triangles with vertices ordered clockwise when the outside is facing the viewer

        ; front face (+z)
        .word #.loword(_x, _y, _z + _side_length)
        .word #.loword(_x + _side_length, _y, _z + _side_length)
        .word #.loword(_x + _side_length, _y + _side_length, _z + _side_length)
        .word #.loword(_x, _y, _z + _side_length)
        .word #.loword(_x + _side_length, _y + _side_length, _z + _side_length)
        .word #.loword(_x, _y + _side_length, _z + _side_length)

        ; back face (-z)
        .word #.loword(_x, _y, _z)
        .word #.loword(_x + _side_length, _y, _z)
        .word #.loword(_x + _side_length, _y + _side_length, _z)
        .word #.loword(_x, _y, _z)
        .word #.loword(_x + _side_length, _y + _side_length, _z)
        .word #.loword(_x, _y + _side_length, _z)

        ; left face (-x)
        .word #.loword(_x, _y, _z)
        .word #.loword(_x, _y, _z + _side_length)
        .word #.loword(_x, _y + _side_length, _z + _side_length)
        .word #.loword(_x, _y, _z)
        .word #.loword(_x, _y + _side_length, _z + _side_length)
        .word #.loword(_x, _y + _side_length, _z)

        ; right face (+x)
        .word #.loword(_x + _side_length, _y, _z)
        .word #.loword(_x + _side_length, _y + _side_length, _z)
        .word #.loword(_x + _side_length, _y + _side_length, _z + _side_length)
        .word #.loword(_x + _side_length, _y, _z)
        .word #.loword(_x + _side_length, _y + _side_length, _z + _side_length)
        .word #.loword(_x + _side_length, _y, _z + _side_length)

        ; top face (+y)
        .word #.loword(_x, _y + _side_length, _z)
        .word #.loword(_x, _y + _side_length, _z + _side_length)
        .word #.loword(_x + _side_length, _y + _side_length, _z + _side_length)
        .word #.loword(_x, _y + _side_length, _z)
        .word #.loword(_x + _side_length, _y + _side_length, _z + _side_length)
        .word #.loword(_x + _side_length, _y + _side_length, _z)

        ; bottom face (-y)
        .word #.loword(_x, _y, _z)
        .word #.loword(_x + _side_length, _y, _z)
        .word #.loword(_x + _side_length, _y, _z + _side_length)
        .word #.loword(_x, _y, _z)
        .word #.loword(_x + _side_length, _y, _z + _side_length)
        .word #.loword(_x, _y, _z + _side_length)
    .endmac

.endif  ; GEOMETRY_I


