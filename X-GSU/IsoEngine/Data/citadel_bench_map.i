; ==============================================================================
; Citadel Benchmark 10x10 Fortress Map for IsoEngine
; Complex multi-story FFT-style diorama engineered to stress:
;   1. Tall vertical cliff skirt drops (2h..6h) -> Merged Vertical Skirts (Fix 1)
;   2. High trapezoid density (100 cells, all 7 archetype families + 1h/2h panels)
;      -> Batched 512B-Cached Rasterizer (Fix 2)
;   3. Optional solid-color shadowed cliffs / plinths (USE_FAST_COLOR_PATH)
;      -> Fast-Color Flat Fill Path (Fix 3)
; ==============================================================================
.ifndef ::__CITADEL_BENCH_MAP_I_DEFINED__
::__CITADEL_BENCH_MAP_I_DEFINED__ = 1

.include "../../gsu_iso/gsu_iso_map.i"
.include "TEXTURES.i"

.ifdef USE_FAST_COLOR_PATH
    BENCH_SKIRT_DARK    = ($F0 | 1)     ; Palette 1: dark shadow slate RGB(64,56,64)
    BENCH_SKIRT_STONE   = ($F0 | 3)     ; Palette 3: mid ashlar stone RGB(128,128,136)
    BENCH_ROOF_SOLID    = ($F0 | 14)    ; Palette 14: terracotta roof RGB(96,48,24)
    BENCH_PLINTH_SOLID  = ($F0 | 5)     ; Palette 5: warm earth plinth RGB(144,112,72)
.else
    BENCH_SKIRT_DARK    = TEXTURE_ID_STONE_CRACKED
    BENCH_SKIRT_STONE   = TEXTURE_ID_STONE
    BENCH_ROOF_SOLID    = TEXTURE_ID_ROOF
    BENCH_PLINTH_SOLID  = TEXTURE_ID_SAND
.endif

.segment "GSUDATA"

MAP_COLS = 10
MAP_ROWS = 10
MAP_BYTE_SIZE = 8 + (MAP_COLS * MAP_ROWS * 8)
.export MAP_BYTE_SIZE

.export SHOWCASE_MAP_ROM
SHOWCASE_MAP_ROM:
    ; map_header (8 bytes):
    .byte MAP_COLS, MAP_ROWS
    .word 128, 108
    .word 0

    ; --------------------------------------------------------------------------
    ; Row 0 (j = 0): High Citadel Keep (h=6) flanked by pitched roofs & towers
    ; --------------------------------------------------------------------------
    def_cell 4, (PRIM_WEDGE_OUTER_2H | ROT_0),     BENCH_ROOF_SOLID,       BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 4, (PRIM_WEDGE_STRAIGHT_2H | ROT_0),  BENCH_ROOF_SOLID,       BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 6, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_N | PANEL_W),       0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_N | PANEL_TALL_2H), 0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_N | PANEL_TALL_2H), 0, 0
    def_cell 6, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_N | PANEL_E),       0, 0
    def_cell 4, (PRIM_WEDGE_STRAIGHT_2H | ROT_0),  BENCH_ROOF_SOLID,       BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 4, (PRIM_WEDGE_OUTER_2H | ROT_90),    BENCH_ROOF_SOLID,       BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_PILLAR,                       TEXTURE_ID_GRASS,       BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, BENCH_PLINTH_SOLID, TEXTURE_ID_FOLIAGE, PANEL_NONE,               0, 0

    ; --------------------------------------------------------------------------
    ; Row 1 (j = 1): Keep Sanctuary (h=6) + Flanking Bastions (h=4)
    ; --------------------------------------------------------------------------
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, PANEL_W,                   0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, PANEL_W,                   0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, PANEL_E,                   0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, PANEL_E,                   0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND_RIPPLE, BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_GRASS_WILD,  BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0

    ; --------------------------------------------------------------------------
    ; Row 2 (j = 2): Keep Front Battlements (h=6 -> 4h drop!) & Grand Stairs
    ; --------------------------------------------------------------------------
    def_cell 4, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, (PANEL_S | PANEL_W),       0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, PANEL_S,                   0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_W),       0, 0
    def_cell 4, (PRIM_STAIRS | ROT_0),             TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, (PRIM_STAIRS | ROT_0),             TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 6, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_E),       0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, PANEL_S,                   0, 0
    def_cell 4, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, (PANEL_S | PANEL_E),       0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, BENCH_PLINTH_SOLID, TEXTURE_ID_FOLIAGE, PANEL_NONE,               0, 0

    ; --------------------------------------------------------------------------
    ; Row 3 (j = 3): Mid Courtyard (h=4), Cliff Plinths, Side Ramparts (h=3)
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_GRASS,       BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 3, (PRIM_WEDGE_STRAIGHT | ROT_270),   TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, PANEL_W,                   0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, PANEL_E,                   0, 0
    def_cell 3, (PRIM_WEDGE_STRAIGHT | ROT_90),    TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND,        BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND_WET,    BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 2, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0

    ; --------------------------------------------------------------------------
    ; Row 4 (j = 4): Steep Courtyard Drop (h=4 -> h=0/2) + Moat Basin (h=2 surface)
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND,        BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 1, PRIM_LIQUID_SHALLOW,               TEXTURE_ID_WATER,       TEXTURE_ID_SAND_WET, 0,                PANEL_NONE,                0, 0
    def_cell 4, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_W),       0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, PANEL_S,                   0, 0
    def_cell 2, (PRIM_STAIRS | ROT_0),             TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_E),       0, 0
    def_cell 1, PRIM_LIQUID_SHALLOW,               TEXTURE_ID_WATER_CALM,  TEXTURE_ID_SAND_WET, 0,                PANEL_NONE,                0, 0
    def_cell 0, PRIM_LIQUID_DEEP,                  TEXTURE_ID_WATER_DEEP,  TEXTURE_ID_STONE_CRACKED, 0,           PANEL_NONE,                0, 0
    def_cell 1, PRIM_LIQUID_SHALLOW,               TEXTURE_ID_WATER,       TEXTURE_ID_SAND_WET, 0,                PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND_RIPPLE, BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0

    ; --------------------------------------------------------------------------
    ; Row 5 (j = 5): Bridge Crossing (h=2) over Moat + Rocky Crag Wedges
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND_WET,    BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 0, PRIM_LIQUID_DEEP,                  TEXTURE_ID_WATER_DEEP,  TEXTURE_ID_STONE_CRACKED, 0,           PANEL_NONE,                0, 0
    def_cell 1, PRIM_LIQUID_SHALLOW,               TEXTURE_ID_WATER,       TEXTURE_ID_SAND_WET, 0,                PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, PANEL_W,                   0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, TEXTURE_ID_PARAPET, PANEL_E,                   0, 0
    def_cell 0, PRIM_LIQUID_DEEP,                  TEXTURE_ID_WATER_DEEP,  TEXTURE_ID_STONE_CRACKED, 0,           PANEL_NONE,                0, 0
    def_cell 1, PRIM_LIQUID_SHALLOW,               TEXTURE_ID_WATER_CALM,  TEXTURE_ID_SAND_WET, 0,                PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND,        BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 2, (PRIM_WEDGE_STRAIGHT | ROT_0),     TEXTURE_ID_STONE_CRACKED, BENCH_SKIRT_STONE, 0,                PANEL_NONE,                0, 0

    ; --------------------------------------------------------------------------
    ; Row 6 (j = 6): Southern Gatehouse Wall (h=4 towers) + Lower Approach (h=2)
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, BENCH_PLINTH_SOLID, TEXTURE_ID_FOLIAGE, PANEL_NONE,               0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND,        BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_W | PANEL_TALL_2H), 0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_E | PANEL_TALL_2H), 0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_SAND_WET,    BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 2, (PRIM_WEDGE_INNER | ROT_0),        TEXTURE_ID_STONE_CRACKED, BENCH_SKIRT_STONE, 0,                PANEL_NONE,                0, 0
    def_cell 3, PRIM_FLAT,                         TEXTURE_ID_STONE_CRACKED, BENCH_SKIRT_DARK, 0,                 PANEL_NONE,                0, 0
    def_cell 3, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0

    ; --------------------------------------------------------------------------
    ; Row 7 (j = 7): Outer Cliff Terraces (h=3..4 -> h=0 drops) + Stairs
    ; --------------------------------------------------------------------------
    def_cell 1, PRIM_FLAT,                         TEXTURE_ID_GRASS,       BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 2, (PRIM_WEDGE_OUTER | ROT_0),        TEXTURE_ID_GRASS_WILD,  BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 4, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_W),       0, 0
    def_cell 0, (PRIM_STAIRS | ROT_0),             TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, (PRIM_STAIRS | ROT_0),             TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 4, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_E),       0, 0
    def_cell 2, (PRIM_WEDGE_STRAIGHT | ROT_0),     TEXTURE_ID_STONE_CRACKED, BENCH_SKIRT_STONE, 0,                PANEL_NONE,                0, 0
    def_cell 2, PRIM_FLAT,                         TEXTURE_ID_STONE_CRACKED, BENCH_SKIRT_STONE, 0,                PANEL_NONE,                0, 0
    def_cell 3, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, PANEL_S,                   0, 0
    def_cell 3, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  TEXTURE_ID_PARAPET, (PANEL_S | PANEL_E),       0, 0

    ; --------------------------------------------------------------------------
    ; Row 8 (j = 8): Lower Meadow & Ruined Colonnade (h=0..1)
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, TEXTURE_ID_GRASS,  TEXTURE_ID_FOLIAGE, PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_GRASS,       TEXTURE_ID_GRASS,  0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_PILLAR,                       TEXTURE_ID_GRASS_WILD,  BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_PILLAR,                       TEXTURE_ID_GRASS_WILD,  BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_GRASS,       TEXTURE_ID_GRASS,  0,                  PANEL_NONE,                0, 0
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),     TEXTURE_ID_GRASS_WILD,  BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 1, PRIM_FLAT,                         TEXTURE_ID_GRASS,       BENCH_PLINTH_SOLID, 0,                 PANEL_NONE,                0, 0
    def_cell 1, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, BENCH_PLINTH_SOLID, TEXTURE_ID_FOLIAGE, PANEL_NONE,               0, 0

    ; --------------------------------------------------------------------------
    ; Row 9 (j = 9): Front Plinth Perimeter (h=0..2 with outer cliff drops)
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_GRASS,       TEXTURE_ID_GRASS,  0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, TEXTURE_ID_GRASS,  TEXTURE_ID_FOLIAGE, PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_GRASS_WILD,  TEXTURE_ID_GRASS,  0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_GRASS_WILD,  TEXTURE_ID_GRASS,  0,                  PANEL_NONE,                0, 0
    def_cell 0, PRIM_FOLIAGE_CROSS,                TEXTURE_ID_GRASS_DENSE, TEXTURE_ID_GRASS,  TEXTURE_ID_FOLIAGE, PANEL_NONE,                0, 0
    def_cell 0, PRIM_FLAT,                         TEXTURE_ID_GRASS,       TEXTURE_ID_GRASS,  0,                  PANEL_NONE,                0, 0
    def_cell 1, PRIM_FLAT,                         TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_STONE, 0,                  PANEL_NONE,                0, 0
    def_cell 2, PRIM_PILLAR,                       TEXTURE_ID_STONE_FLOOR, BENCH_SKIRT_DARK,  0,                  PANEL_NONE,                0, 0

SHOWCASE_MAP_ROM_END:
.assert (SHOWCASE_MAP_ROM_END - SHOWCASE_MAP_ROM) = MAP_BYTE_SIZE, error, "SHOWCASE_MAP_ROM size does not match MAP_BYTE_SIZE"

.segment "GSUCODE"

.endif ; __CITADEL_BENCH_MAP_I_DEFINED__
