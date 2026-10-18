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
    .word .loword(CUBE_V2 + 3*4), .loword(CUBE_V2 + 2*4), .loword(CUBE_V2 + 6*4), .loword(CUBE_V2 + 7*4), c_top   ; Top   (+Y)
    .word .loword(CUBE_V2 + 7*4), .loword(CUBE_V2 + 6*4), .loword(CUBE_V2 + 5*4), .loword(CUBE_V2 + 4*4), c_front ; Front (+Z)
    .word .loword(CUBE_V2 + 6*4), .loword(CUBE_V2 + 2*4), .loword(CUBE_V2 + 1*4), .loword(CUBE_V2 + 5*4), c_right ; Right (+X)
    .word .loword(CUBE_V2 + 2*4), .loword(CUBE_V2 + 3*4), .loword(CUBE_V2 + 0*4), .loword(CUBE_V2 + 1*4), c_back  ; Back  (-Z)
    .word .loword(CUBE_V2 + 3*4), .loword(CUBE_V2 + 7*4), .loword(CUBE_V2 + 4*4), .loword(CUBE_V2 + 0*4), c_left  ; Left  (-X)
.endmac

; Copies a projected 16-bit 2D vertex (x, y) from CUBE_V2 into the cache buffer at (cache_ptr_reg)
; In:       face_ptr_reg  = pointer to current vertex address word in CUBE_FACES
;           v_ptr_reg     = scratch pointer register
;           cache_ptr_reg = destination pointer in CACHED_TRIS
; Out:      cache_ptr_reg advanced by 4 bytes (2 words: x, y)
; Clobbers: r0, v_ptr_reg, cache_ptr_reg
.macro _copy_vertex_to_cache face_ptr_reg, v_ptr_reg, cache_ptr_reg
    ldw (face_ptr_reg)
    move v_ptr_reg, r0
    ldw (v_ptr_reg)
    stw (cache_ptr_reg)
    inc cache_ptr_reg
    inc cache_ptr_reg
    inc v_ptr_reg
    inc v_ptr_reg
    ldw (v_ptr_reg)
    stw (cache_ptr_reg)
    inc cache_ptr_reg
    inc cache_ptr_reg
.endmac

.endif  ; GEOMETRY_I


