; ==============================================================================
; Showcase 8x8 Diorama Map for IsoEngine
; Exercises all 7 archetype families:
;   - Flat courtyard/terrace (PRIM_FLAT)
;   - Sloped crag (PRIM_WEDGE_STRAIGHT, PRIM_WEDGE_OUTER, PRIM_WEDGE_INNER)
;   - Ceremonial stairs (PRIM_STAIRS)
;   - Shallow & deep water pool (PRIM_LIQUID_SHALLOW, PRIM_LIQUID_DEEP)
;   - Ruined columns (PRIM_PILLAR)
;   - Foliage clusters (PRIM_FOLIAGE_CROSS)
;   - Multi-story cliff drops (drop_ns, drop_ew)
;   - Perimeter battlements & parapets (PANEL_N, PANEL_S, PANEL_W, PANEL_E, PANEL_TALL_2H)
; ==============================================================================
.ifndef ::__SHOWCASE_MAP_I_DEFINED__
::__SHOWCASE_MAP_I_DEFINED__ = 1

.include "../map_grid.i"
.include "TEXTURES.i"

.segment "GSUDATA"

.export SHOWCASE_MAP_ROM
SHOWCASE_MAP_ROM:
    ; map_header (8 bytes):
    ; cols = 8, rows = 8, origin_x = 128, origin_z = 80, reserved = 0
    .byte 8, 8
    .word 128, 80
    .word 0

    ; --------------------------------------------------------------------------
    ; Row 0 (j = 0, North edge): Terrace with battlements, ruined pillar, lawn
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (0,0) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (1,0) Lawn
    def_cell 0, PRIM_FOLIAGE_CROSS,        TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, TEXTURE_ID_FOLIAGE, PANEL_NONE,            0, 0 ; (2,0) Foliage
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (3,0) Lawn
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, (PANEL_N | PANEL_W),  2, 2 ; (4,0) Terrace N+W
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_N,              2, 0 ; (5,0) Terrace N
    def_cell 2, PRIM_PILLAR,               TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_N,              2, 0 ; (6,0) Pillar N
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, (PANEL_N | PANEL_E),  2, 0 ; (7,0) Terrace N+E

    ; --------------------------------------------------------------------------
    ; Row 1 (j = 1): Shallow pool, sand shore, foliage, terrace courtyard
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FOLIAGE_CROSS,        TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, TEXTURE_ID_FOLIAGE, PANEL_NONE,            0, 0 ; (0,1) Foliage
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (1,1) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_SAND,  TEXTURE_ID_SAND,  0,                  PANEL_NONE,            0, 0 ; (2,1) Sand shore
    def_cell 0, PRIM_LIQUID_SHALLOW,       TEXTURE_ID_WATER, TEXTURE_ID_SAND,  0,                  PANEL_NONE,            0, 0 ; (3,1) Shallow water
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_W,              0, 2 ; (4,1) Terrace W
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (5,1) Courtyard
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (6,1) Courtyard
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_E,              0, 0 ; (7,1) Terrace E

    ; --------------------------------------------------------------------------
    ; Row 2 (j = 2): Deep & shallow pool, sand shore, tall 2H facade, ruined pillar
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (0,2) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_SAND,  TEXTURE_ID_SAND,  0,                  PANEL_NONE,            0, 0 ; (1,2) Sand shore
    def_cell 0, PRIM_LIQUID_DEEP,          TEXTURE_ID_WATER_DEEP, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (2,2) Deep water
    def_cell 0, PRIM_LIQUID_SHALLOW,       TEXTURE_ID_WATER, TEXTURE_ID_SAND,  0,                  PANEL_NONE,            0, 0 ; (3,2) Shallow water
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, (PANEL_W | PANEL_TALL_2H), 0, 2 ; (4,2) Tall 2H facade W
    def_cell 2, PRIM_PILLAR,               TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (5,2) Ruined pillar
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (6,2) Courtyard
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_E,              0, 0 ; (7,2) Terrace E

    ; --------------------------------------------------------------------------
    ; Row 3 (j = 3): Pillar in lawn, shallow pool shore, south terrace battlements
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_PILLAR,               TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (0,3) Ruined pillar
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_SAND,  TEXTURE_ID_SAND,  0,                  PANEL_NONE,            0, 0 ; (1,3) Sand shore
    def_cell 0, PRIM_LIQUID_SHALLOW,       TEXTURE_ID_WATER, TEXTURE_ID_SAND,  0,                  PANEL_NONE,            0, 0 ; (2,3) Shallow pool
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (3,3) Lawn
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, (PANEL_S | PANEL_W),  0, 2 ; (4,3) Terrace S+W
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_S,              0, 0 ; (5,3) Terrace S
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (6,3) Terrace
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, (PANEL_S | PANEL_E),  0, 0 ; (7,3) Terrace S+E

    ; --------------------------------------------------------------------------
    ; Row 4 (j = 4): Foliage, Ceremonial stairs up to terrace, straight wedge ramp
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (0,4) Lawn
    def_cell 0, PRIM_FOLIAGE_CROSS,        TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, TEXTURE_ID_FOLIAGE, PANEL_NONE,            0, 0 ; (1,4) Foliage
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (2,4) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (3,4) Lawn
    def_cell 0, (PRIM_STAIRS | ROT_0),     TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (4,4) Ceremonial stairs
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0), TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,             PANEL_NONE,            1, 0 ; (5,4) Straight ramp
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (6,4) Stone landing
    def_cell 2, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_E,              0, 0 ; (7,4) Terrace E

    ; --------------------------------------------------------------------------
    ; Row 5 (j = 5): Sloped crag (inner & outer wedge, straight slope), stone path
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (0,5) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (1,5) Lawn
    def_cell 0, (PRIM_WEDGE_INNER | ROT_0), TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                 PANEL_NONE,            0, 0 ; (2,5) Inner wedge
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_90), TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,            PANEL_NONE,            0, 0 ; (3,5) Straight wedge
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (4,5) Stone path
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (5,5) Stone path
    def_cell 1, (PRIM_WEDGE_OUTER | ROT_0), TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                 PANEL_NONE,            1, 0 ; (6,5) Outer wedge
    def_cell 1, PRIM_FLAT,                 TEXTURE_ID_STONE, TEXTURE_ID_STONE, TEXTURE_ID_PARAPET, PANEL_E,              1, 0 ; (7,5) Bluff edge E

    ; --------------------------------------------------------------------------
    ; Row 6 (j = 6): Foliage, ruined column, grassy courtyard
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (0,6) Lawn
    def_cell 0, PRIM_FOLIAGE_CROSS,        TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, TEXTURE_ID_FOLIAGE, PANEL_NONE,            0, 0 ; (1,6) Foliage
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (2,6) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (3,6) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (4,6) Courtyard
    def_cell 0, PRIM_PILLAR,               TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (5,6) Ruined pillar
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (6,6) Courtyard
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 1 ; (7,6) Lawn

    ; --------------------------------------------------------------------------
    ; Row 7 (j = 7, South edge): Fallen pillar, foliage cluster, perimeter lawn
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (0,7) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (1,7) Lawn
    def_cell 0, PRIM_PILLAR,               TEXTURE_ID_STONE, TEXTURE_ID_STONE, 0,                  PANEL_NONE,            0, 0 ; (2,7) Ruined pillar
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (3,7) Lawn
    def_cell 0, PRIM_FOLIAGE_CROSS,        TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, TEXTURE_ID_FOLIAGE, PANEL_NONE,            0, 0 ; (4,7) Foliage
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (5,7) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (6,7) Lawn
    def_cell 0, PRIM_FLAT,                 TEXTURE_ID_GRASS, TEXTURE_ID_GRASS, 0,                  PANEL_NONE,            0, 0 ; (7,7) Lawn

.segment "GSUCODE"

.endif ; __SHOWCASE_MAP_I_DEFINED__
