.ifndef ::__GEOMETRY_DEFINED__
::__GEOMETRY_DEFINED__ = 1   
; geometry.i - geometry related macros/definitions

; Defines a 3D cube mesh as 12 triangles (36 vertices) with clockwise winding in Q8.8 format
; In:       _x, _y, _z = origin position (Q8.8), _side_length = cube dimension (Q8.8)
; Out:      Emits 108 words (36 vertices x 3 coordinates) of triangle mesh data
; Clobbers: None (data generator)
.macro cube _x, _y, _z, _side_length
    .if     .paramcount <> 4
        .error  "Too few parameters for macro cube"
    .endif
        ; define cube as 12 triangles with vertices ordered clockwise when the outside is facing the viewer

        ; front face (+z)
        .word .loword(_x), .loword(_y), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z + _side_length)

        ; back face (-z)
        .word .loword(_x), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z)
        .word .loword(_x), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z)

        ; left face (-x)
        .word .loword(_x), .loword(_y), .loword(_z)
        .word .loword(_x), .loword(_y), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y), .loword(_z)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z)

        ; right face (+x)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z + _side_length)

        ; top face (+y)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y + _side_length), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z + _side_length)
        .word .loword(_x + _side_length), .loword(_y + _side_length), .loword(_z)

        ; bottom face (-y)
        .word .loword(_x), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y), .loword(_z)
        .word .loword(_x + _side_length), .loword(_y), .loword(_z + _side_length)
        .word .loword(_x), .loword(_y), .loword(_z + _side_length)
    .endmac

.endif  ; GEOMETRY_I


