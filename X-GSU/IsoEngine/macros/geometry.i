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

; Emits 72 unique 3D scene vertices (216 words = 432 bytes) in Q8.8
; 21 terrain/path + 28 enlarged house + 15 pine trees + 8 stone well
.macro scene_vertices
    ; Terrain top 3x3 grid: v0..v8
    .word $AC00, $E800, $BC00 ; v 0: (-84, -24, -68) lawn top-nw
    .word $0000, $E800, $BC00 ; v 1: (  0, -24, -68) lawn top-n
    .word $5400, $E800, $BC00 ; v 2: ( 84, -24, -68) lawn top-ne
    .word $AC00, $E800, $0000 ; v 3: (-84, -24,   0) lawn top-w
    .word $0000, $E800, $0000 ; v 4: (  0, -24,   0) lawn top-c
    .word $5400, $E800, $0000 ; v 5: ( 84, -24,   0) lawn top-e
    .word $AC00, $E800, $4400 ; v 6: (-84, -24,  68) lawn top-sw
    .word $0000, $E800, $4400 ; v 7: (  0, -24,  68) lawn top-s
    .word $5400, $E800, $4400 ; v 8: ( 84, -24,  68) lawn top-se

    ; Soil bottom perimeter: v9..v16
    .word $AC00, $E000, $BC00 ; v 9: (-84, -32, -68) soil bot-nw
    .word $0000, $E000, $BC00 ; v10: (  0, -32, -68) soil bot-n
    .word $5400, $E000, $BC00 ; v11: ( 84, -32, -68) soil bot-ne
    .word $5400, $E000, $0000 ; v12: ( 84, -32,   0) soil bot-e
    .word $5400, $E000, $4400 ; v13: ( 84, -32,  68) soil bot-se
    .word $0000, $E000, $4400 ; v14: (  0, -32,  68) soil bot-s
    .word $AC00, $E000, $4400 ; v15: (-84, -32,  68) soil bot-sw
    .word $AC00, $E000, $0000 ; v16: (-84, -32,   0) soil bot-w

    ; Path: v17..v20
    .word $F600, $E800, $1A00 ; v17: (-10, -24,  26) path top-left
    .word $0A00, $E800, $1A00 ; v18: ( 10, -24,  26) path top-right
    .word $0A00, $E800, $4400 ; v19: ( 10, -24,  68) path bot-right
    .word $F600, $E800, $4400 ; v20: (-10, -24,  68) path bot-left

    ; House: v21..v48
    .word $DC00, $E800, $E600 ; v21: (-36, -24, -26) house back-left bot
    .word $2400, $E800, $E600 ; v22: ( 36, -24, -26) house back-right bot
    .word $2400, $0C00, $E600 ; v23: ( 36,  12, -26) house back-right top
    .word $DC00, $0C00, $E600 ; v24: (-36,  12, -26) house back-left top
    .word $DC00, $E800, $1A00 ; v25: (-36, -24,  26) house front-left bot
    .word $2400, $E800, $1A00 ; v26: ( 36, -24,  26) house front-right bot
    .word $2400, $0C00, $1A00 ; v27: ( 36,  12,  26) house front-right top
    .word $DC00, $0C00, $1A00 ; v28: (-36,  12,  26) house front-left top
    .word $DC00, $2800, $0000 ; v29: (-36,  40,   0) house roof ridge left
    .word $2400, $2800, $0000 ; v30: ( 36,  40,   0) house roof ridge right
    .word $F600, $E800, $1A00 ; v31: (-10, -24,  26) door bot-left
    .word $0A00, $E800, $1A00 ; v32: ( 10, -24,  26) door bot-right
    .word $0A00, $FE00, $1A00 ; v33: ( 10,  -2,  26) door top-right
    .word $F600, $FE00, $1A00 ; v34: (-10,  -2,  26) door top-left
    .word $F600, $0C00, $1A00 ; v35: (-10,  12,  26) front wall top-left-center
    .word $0A00, $0C00, $1A00 ; v36: ( 10,  12,  26) front wall top-right-center
    .word $2400, $F800, $F600 ; v37: ( 36,  -8, -10) right window bot-back
    .word $2400, $F800, $0A00 ; v38: ( 36,  -8,  10) right window bot-front
    .word $2400, $0600, $0A00 ; v39: ( 36,   6,  10) right window top-front
    .word $2400, $0600, $F600 ; v40: ( 36,   6, -10) right window top-back
    .word $DC00, $F800, $0A00 ; v41: (-36,  -8,  10) left window bot-front
    .word $DC00, $F800, $F600 ; v42: (-36,  -8, -10) left window bot-back
    .word $DC00, $0600, $F600 ; v43: (-36,   6, -10) left window top-back
    .word $DC00, $0600, $0A00 ; v44: (-36,   6,  10) left window top-front
    .word $0A00, $F800, $E600 ; v45: ( 10,  -8, -26) back window bot-right
    .word $F600, $F800, $E600 ; v46: (-10,  -8, -26) back window bot-left
    .word $F600, $0600, $E600 ; v47: (-10,   6, -26) back window top-left
    .word $0A00, $0600, $E600 ; v48: ( 10,   6, -26) back window top-right

    ; Tree 1: v49..v53
    .word $C600, $0A00, $2A00 ; v49: (-58,  10,  42) tree 1 apex
    .word $C600, $EE00, $3700 ; v50: (-58, -18,  55) tree 1 front
    .word $D300, $EE00, $2A00 ; v51: (-45, -18,  42) tree 1 right
    .word $C600, $EE00, $1D00 ; v52: (-58, -18,  29) tree 1 back
    .word $B900, $EE00, $2A00 ; v53: (-71, -18,  42) tree 1 left

    ; Tree 2: v54..v58
    .word $3A00, $0800, $D400 ; v54: ( 58,   8, -44) tree 2 apex
    .word $3A00, $EE00, $E000 ; v55: ( 58, -18, -32) tree 2 front
    .word $4600, $EE00, $D400 ; v56: ( 70, -18, -44) tree 2 right
    .word $3A00, $EE00, $C800 ; v57: ( 58, -18, -56) tree 2 back
    .word $2E00, $EE00, $D400 ; v58: ( 46, -18, -44) tree 2 left

    ; Tree 3: v59..v63
    .word $C600, $0600, $D400 ; v59: (-58,   6, -44) tree 3 apex
    .word $C600, $EE00, $DF00 ; v60: (-58, -18, -33) tree 3 front
    .word $D100, $EE00, $D400 ; v61: (-47, -18, -44) tree 3 right
    .word $C600, $EE00, $C900 ; v62: (-58, -18, -55) tree 3 back
    .word $BB00, $EE00, $D400 ; v63: (-69, -18, -44) tree 3 left

    ; Well: v64..v71
    .word $2A00, $E800, $2E00 ; v64: ( 42, -24,  46) well front-left bot
    .word $3A00, $E800, $2E00 ; v65: ( 58, -24,  46) well front-right bot
    .word $3A00, $F200, $2E00 ; v66: ( 58, -14,  46) well front-right top
    .word $2A00, $F200, $2E00 ; v67: ( 42, -14,  46) well front-left top
    .word $2A00, $E800, $1E00 ; v68: ( 42, -24,  30) well back-left bot
    .word $3A00, $E800, $1E00 ; v69: ( 58, -24,  30) well back-right bot
    .word $3A00, $F200, $1E00 ; v70: ( 58, -14,  30) well back-right top
    .word $2A00, $F200, $1E00 ; v71: ( 42, -14,  30) well back-left top
.endmac

; Emits 44 face descriptors (220 words = 440 bytes)
; 13 terrain/path + 14 house + 4 tree 1 + 4 tree 2 + 4 tree 3 + 5 well
.macro scene_faces
    ; 13 Terrain faces
    .word .loword(MODEL_V2 +  0*4), .loword(MODEL_V2 +  1*4), .loword(MODEL_V2 +  4*4), .loword(MODEL_V2 +  3*4), $8001 ; lawn_nw (TEXTURE_ID_GRASS = 1)
    .word .loword(MODEL_V2 +  1*4), .loword(MODEL_V2 +  2*4), .loword(MODEL_V2 +  5*4), .loword(MODEL_V2 +  4*4), $8001 ; lawn_ne (TEXTURE_ID_GRASS = 1)
    .word .loword(MODEL_V2 +  3*4), .loword(MODEL_V2 +  4*4), .loword(MODEL_V2 +  7*4), .loword(MODEL_V2 +  6*4), $8001 ; lawn_sw (TEXTURE_ID_GRASS = 1)
    .word .loword(MODEL_V2 +  4*4), .loword(MODEL_V2 +  5*4), .loword(MODEL_V2 +  8*4), .loword(MODEL_V2 +  7*4), $8001 ; lawn_se (TEXTURE_ID_GRASS = 1)
    .word .loword(MODEL_V2 +  6*4), .loword(MODEL_V2 +  7*4), .loword(MODEL_V2 + 14*4), .loword(MODEL_V2 + 15*4),  4 ; soil_front_l
    .word .loword(MODEL_V2 +  7*4), .loword(MODEL_V2 +  8*4), .loword(MODEL_V2 + 13*4), .loword(MODEL_V2 + 14*4),  4 ; soil_front_r
    .word .loword(MODEL_V2 +  8*4), .loword(MODEL_V2 +  5*4), .loword(MODEL_V2 + 12*4), .loword(MODEL_V2 + 13*4),  5 ; soil_right_f
    .word .loword(MODEL_V2 +  5*4), .loword(MODEL_V2 +  2*4), .loword(MODEL_V2 + 11*4), .loword(MODEL_V2 + 12*4),  5 ; soil_right_b
    .word .loword(MODEL_V2 +  2*4), .loword(MODEL_V2 +  1*4), .loword(MODEL_V2 + 10*4), .loword(MODEL_V2 + 11*4),  4 ; soil_back_r
    .word .loword(MODEL_V2 +  1*4), .loword(MODEL_V2 +  0*4), .loword(MODEL_V2 +  9*4), .loword(MODEL_V2 + 10*4),  4 ; soil_back_l
    .word .loword(MODEL_V2 +  0*4), .loword(MODEL_V2 +  3*4), .loword(MODEL_V2 + 16*4), .loword(MODEL_V2 +  9*4),  5 ; soil_left_b
    .word .loword(MODEL_V2 +  3*4), .loword(MODEL_V2 +  6*4), .loword(MODEL_V2 + 15*4), .loword(MODEL_V2 + 16*4),  5 ; soil_left_f
    .word .loword(MODEL_V2 + 17*4), .loword(MODEL_V2 + 18*4), .loword(MODEL_V2 + 19*4), .loword(MODEL_V2 + 20*4), $8005 ; path (stone, table_index = 5)

    ; 14 House faces
    .word .loword(MODEL_V2 + 28*4), .loword(MODEL_V2 + 35*4), .loword(MODEL_V2 + 31*4), .loword(MODEL_V2 + 25*4),  7 ; house_front_left
    .word .loword(MODEL_V2 + 36*4), .loword(MODEL_V2 + 27*4), .loword(MODEL_V2 + 26*4), .loword(MODEL_V2 + 32*4),  7 ; house_front_right
    .word .loword(MODEL_V2 + 35*4), .loword(MODEL_V2 + 36*4), .loword(MODEL_V2 + 33*4), .loword(MODEL_V2 + 34*4),  7 ; house_front_transom
    .word .loword(MODEL_V2 + 34*4), .loword(MODEL_V2 + 33*4), .loword(MODEL_V2 + 32*4), .loword(MODEL_V2 + 31*4),  4 ; house_door
    .word .loword(MODEL_V2 + 23*4), .loword(MODEL_V2 + 24*4), .loword(MODEL_V2 + 21*4), .loword(MODEL_V2 + 22*4),  6 ; house_back_wall
    .word .loword(MODEL_V2 + 48*4), .loword(MODEL_V2 + 47*4), .loword(MODEL_V2 + 46*4), .loword(MODEL_V2 + 45*4), 12 ; house_back_window
    .word .loword(MODEL_V2 + 24*4), .loword(MODEL_V2 + 28*4), .loword(MODEL_V2 + 25*4), .loword(MODEL_V2 + 21*4),  5 ; house_left_wall
    .word .loword(MODEL_V2 + 44*4), .loword(MODEL_V2 + 41*4), .loword(MODEL_V2 + 42*4), .loword(MODEL_V2 + 43*4), 12 ; house_left_window
    .word .loword(MODEL_V2 + 27*4), .loword(MODEL_V2 + 23*4), .loword(MODEL_V2 + 22*4), .loword(MODEL_V2 + 26*4), 15 ; house_right_wall
    .word .loword(MODEL_V2 + 39*4), .loword(MODEL_V2 + 40*4), .loword(MODEL_V2 + 37*4), .loword(MODEL_V2 + 38*4), 12 ; house_right_window
    .word .loword(MODEL_V2 + 28*4), .loword(MODEL_V2 + 29*4), .loword(MODEL_V2 + 30*4), .loword(MODEL_V2 + 27*4), $8000 ; house_front_roof (TEXTURE_ID_ROOF = 0)
    .word .loword(MODEL_V2 + 23*4), .loword(MODEL_V2 + 30*4), .loword(MODEL_V2 + 29*4), .loword(MODEL_V2 + 24*4), $8000 ; house_back_roof  (TEXTURE_ID_ROOF = 0)
    .word .loword(MODEL_V2 + 24*4), .loword(MODEL_V2 + 29*4), .loword(MODEL_V2 + 28*4), .loword(MODEL_V2 + 28*4), 10 ; house_left_gable
    .word .loword(MODEL_V2 + 27*4), .loword(MODEL_V2 + 30*4), .loword(MODEL_V2 + 23*4), .loword(MODEL_V2 + 23*4),  9 ; house_right_gable

    ; 12 Tree faces (4 facets each)
    .word .loword(MODEL_V2 + 49*4), .loword(MODEL_V2 + 51*4), .loword(MODEL_V2 + 50*4), .loword(MODEL_V2 + 50*4), 11 ; tree1_fr
    .word .loword(MODEL_V2 + 49*4), .loword(MODEL_V2 + 50*4), .loword(MODEL_V2 + 53*4), .loword(MODEL_V2 + 53*4),  3 ; tree1_fl
    .word .loword(MODEL_V2 + 49*4), .loword(MODEL_V2 + 53*4), .loword(MODEL_V2 + 52*4), .loword(MODEL_V2 + 52*4),  3 ; tree1_bl
    .word .loword(MODEL_V2 + 49*4), .loword(MODEL_V2 + 52*4), .loword(MODEL_V2 + 51*4), .loword(MODEL_V2 + 51*4),  1 ; tree1_br
    .word .loword(MODEL_V2 + 54*4), .loword(MODEL_V2 + 56*4), .loword(MODEL_V2 + 55*4), .loword(MODEL_V2 + 55*4), 11 ; tree2_fr
    .word .loword(MODEL_V2 + 54*4), .loword(MODEL_V2 + 55*4), .loword(MODEL_V2 + 58*4), .loword(MODEL_V2 + 58*4),  3 ; tree2_fl
    .word .loword(MODEL_V2 + 54*4), .loword(MODEL_V2 + 58*4), .loword(MODEL_V2 + 57*4), .loword(MODEL_V2 + 57*4),  3 ; tree2_bl
    .word .loword(MODEL_V2 + 54*4), .loword(MODEL_V2 + 57*4), .loword(MODEL_V2 + 56*4), .loword(MODEL_V2 + 56*4),  1 ; tree2_br
    .word .loword(MODEL_V2 + 59*4), .loword(MODEL_V2 + 61*4), .loword(MODEL_V2 + 60*4), .loword(MODEL_V2 + 60*4), 11 ; tree3_fr
    .word .loword(MODEL_V2 + 59*4), .loword(MODEL_V2 + 60*4), .loword(MODEL_V2 + 63*4), .loword(MODEL_V2 + 63*4),  3 ; tree3_fl
    .word .loword(MODEL_V2 + 59*4), .loword(MODEL_V2 + 63*4), .loword(MODEL_V2 + 62*4), .loword(MODEL_V2 + 62*4),  3 ; tree3_bl
    .word .loword(MODEL_V2 + 59*4), .loword(MODEL_V2 + 62*4), .loword(MODEL_V2 + 61*4), .loword(MODEL_V2 + 61*4),  1 ; tree3_br

    ; 5 Well faces
    .word .loword(MODEL_V2 + 71*4), .loword(MODEL_V2 + 70*4), .loword(MODEL_V2 + 66*4), .loword(MODEL_V2 + 67*4), $8002 ; well_water (TEXTURE_ID_WATER = 2)
    .word .loword(MODEL_V2 + 67*4), .loword(MODEL_V2 + 66*4), .loword(MODEL_V2 + 65*4), .loword(MODEL_V2 + 64*4), $8005 ; well_front (stone, table_index = 5)
    .word .loword(MODEL_V2 + 66*4), .loword(MODEL_V2 + 70*4), .loword(MODEL_V2 + 69*4), .loword(MODEL_V2 + 65*4), $8005 ; well_right (stone, table_index = 5)
    .word .loword(MODEL_V2 + 70*4), .loword(MODEL_V2 + 71*4), .loword(MODEL_V2 + 68*4), .loword(MODEL_V2 + 69*4), $8005 ; well_back  (stone, table_index = 5)
    .word .loword(MODEL_V2 + 71*4), .loword(MODEL_V2 + 67*4), .loword(MODEL_V2 + 64*4), .loword(MODEL_V2 + 68*4), $8005 ; well_left  (stone, table_index = 5)
.endmac

; Backwards compatibility aliases
.macro house_vertices
    scene_vertices
.endmac
.macro house_faces
    scene_faces
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


