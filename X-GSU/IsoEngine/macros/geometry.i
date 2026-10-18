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

; Emits 8 unique 3D cube vertices centered at (0, 0, 0) with half-extent _r in Q8.8 (48 bytes)
; In:       _r = half-size in Q8.8 (e.g. $2000 for 32.0)
; Out:      8 vector3 entries (24 words)
.macro indexed_cube_vertices _r
    .word .loword(-_r), .loword(-_r), .loword(-_r) ; v0: (-r, -r, -r)
    .word .loword( _r), .loword(-_r), .loword(-_r) ; v1: ( r, -r, -r)
    .word .loword( _r), .loword( _r), .loword(-_r) ; v2: ( r,  r, -r)
    .word .loword(-_r), .loword( _r), .loword(-_r) ; v3: (-r,  r, -r)
    .word .loword(-_r), .loword(-_r), .loword( _r) ; v4: (-r, -r,  r)
    .word .loword( _r), .loword(-_r), .loword( _r) ; v5: ( r, -r,  r)
    .word .loword( _r), .loword( _r), .loword( _r) ; v6: ( r,  r,  r)
    .word .loword(-_r), .loword( _r), .loword( _r) ; v7: (-r,  r,  r)
.endmac

; Emits 5 quad face descriptors (omitting the permanently hidden bottom face).
; Each face is 5 words (10 bytes): 4 byte-offsets into a vector2 array (idx * 4) + 1 color word.
; Vertices are ordered clockwise in 2D screen space when front-facing.
; In:       c_top, c_front, c_right, c_back, c_left = palette color indices (1..15)
; Out:      5 quad descriptors (25 words = 50 bytes)
.macro indexed_cube_faces c_top, c_front, c_right, c_back, c_left
    .word 3*4, 2*4, 6*4, 7*4, c_top   ; Top   (+Y)
    .word 7*4, 6*4, 5*4, 4*4, c_front ; Front (+Z)
    .word 6*4, 2*4, 1*4, 5*4, c_right ; Right (+X)
    .word 2*4, 3*4, 0*4, 1*4, c_back  ; Back  (-Z)
    .word 3*4, 7*4, 4*4, 0*4, c_left  ; Left  (-X)
.endmac

; Loads a projected 2D vertex from CUBE_V2 using the byte offset at (face_ptr_reg)
; and packs (x, y) into a single 16-bit word: (y << 8) | (x & 0xFF).
; In:       face_ptr_reg = pointer to current vertex offset word in CUBE_FACES
;           v_ptr_reg    = scratch pointer register
;           xy_out_reg   = destination register for packed (y << 8) | x
; Out:      xy_out_reg = (y << 8) | x
; Clobbers: r0, v_ptr_reg, xy_out_reg
.macro _load_packed_xy face_ptr_reg, v_ptr_reg, xy_out_reg
    iwt v_ptr_reg, #CUBE_V2
    ldw (face_ptr_reg)
    with v_ptr_reg
    add r0
    to xy_out_reg
    ldw (v_ptr_reg)
    inc v_ptr_reg
    inc v_ptr_reg
    ldw (v_ptr_reg)
    swap
    to xy_out_reg
    or xy_out_reg
.endmac

.endif  ; GEOMETRY_I


