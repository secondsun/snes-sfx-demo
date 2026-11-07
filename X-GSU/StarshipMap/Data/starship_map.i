; ==============================================================================
; Starship Bridge 12x8 Diorama Map for IsoEngine (StarshipMap)
; Simplified, clean layout using repurposed ramps (PRIM_WEDGE_STRAIGHT) as
; angled 3D bridge terminals:
;   - Single raised section (h=1, i=3..8, j=1..4) for the Captain's console area:
;       * Auxiliary control terminals along the rear row (j=1, i=4..7) built from
;         PRIM_WEDGE_STRAIGHT ramps rising from h=1 to h=2
;       * Captain's chairs (j=2, i=5..6) overlooking the Captain's console
;       * Captain's console terminals at the front of the raised section
;         (j=4, i=5..6) built from PRIM_WEDGE_STRAIGHT ramps rising from h=1 to h=2
;   - Lowered main deck (h=0) surrounding the raised section and across j=5..7:
;       * Two freestanding terminal consoles in the lowered area (at (4,7) and
;         (7,7)) built from PRIM_WEDGE_STRAIGHT ramps rising from h=0 to h=1
; ==============================================================================
.ifndef ::__STARSHIP_MAP_I_DEFINED__
::__STARSHIP_MAP_I_DEFINED__ = 1

.include "../../IsoEngine/map_grid.i"
.include "TEXTURES.i"

.segment "GSUDATA"

MAP_COLS = 12
MAP_ROWS = 8
MAP_BYTE_SIZE = 8 + (MAP_COLS * MAP_ROWS * 8)
.export MAP_BYTE_SIZE

.export STARSHIP_MAP_ROM
STARSHIP_MAP_ROM:
    ; map_header (8 bytes):
    ; cols = MAP_COLS (12), rows = MAP_ROWS (8), origin_x = 128, origin_z = 80, reserved = 0
    .byte MAP_COLS, MAP_ROWS
    .word 128, 80
    .word 0

    ; --------------------------------------------------------------------------
    ; Row 0 (j = 0): Aft Deck Perimeter (h = 0)
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,0)  Port Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,0)  Port Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,0)  Port Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,0)  Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,0)  Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,0)  Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,0)  Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,0)  Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,0)  Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,0)  Stbd Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,0) Stbd Aft Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,0) Stbd Aft Deck

    ; --------------------------------------------------------------------------
    ; Row 1 (j = 1): Raised Section Rear (h = 1) — Auxiliary Control Ramp Terminals
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,1)  Port Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,1)  Port Deck
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_HULL_RISER, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,1)  Port Raised Platform Side Slope
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,1)  Raised Section NW Corner
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_LCARS_WALL, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,1)  Auxiliary Terminal Ramp (Port)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_LCARS_WALL, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,1)  Auxiliary Terminal Ramp (Center-Left)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_LCARS_WALL, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,1)  Auxiliary Terminal Ramp (Center-Right)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_LCARS_WALL, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,1)  Auxiliary Terminal Ramp (Stbd)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,1)  Raised Section NE Corner
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_HULL_RISER, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,1)  Stbd Raised Platform Side Slope
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,1) Stbd Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,1) Stbd Deck

    ; --------------------------------------------------------------------------
    ; Row 2 (j = 2): Raised Section — Captain's Seating Area (h = 1)
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,2)  Port Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,2)  Port Deck
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_HULL_RISER,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,2)  Port Raised Platform Side Slope
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,2)  Raised Command Platform Port
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,2)  Raised Command Platform Inner-Port
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,2)  Captain's Chair (Left)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,2)  Captain's Chair (Right)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,2)  Raised Command Platform Inner-Stbd
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,2)  Raised Command Platform Stbd
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_HULL_RISER,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,2)  Stbd Raised Platform Side Slope
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,2) Stbd Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,2) Stbd Deck

    ; --------------------------------------------------------------------------
    ; Row 3 (j = 3): Raised Section Center Walkway (h = 1)
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,3)  Port Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,3)  Port Deck
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_HULL_RISER, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,3)  Port Raised Platform Side Slope
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,3)  Raised Platform Port
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,3)  Raised Platform Inner-Port
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,3)  Raised Platform Center-Left
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,3)  Raised Platform Center-Right
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,3)  Raised Platform Inner-Stbd
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,3)  Raised Platform Stbd
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_HULL_RISER, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,3)  Stbd Raised Platform Side Slope
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,3) Stbd Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,3) Stbd Deck

    ; --------------------------------------------------------------------------
    ; Row 4 (j = 4): Raised Section Front (h = 1) — Captain's Console Ramp Terminals
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,4)  Port Lower Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,4)  Port Lower Deck
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_HULL_RISER,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,4)  Port Raised Platform Side Slope
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,4)  Raised Platform SW Corner
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,4)  Raised Platform Front-Port
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_VIEWSCREEN,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,4)  Captain's Console Terminal Ramp (Left)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_VIEWSCREEN,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,4)  Captain's Console Terminal Ramp (Right)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,4)  Raised Platform Front-Stbd
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,4)  Raised Platform SE Corner
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_HULL_RISER,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,4)  Stbd Raised Platform Side Slope
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,4) Stbd Lower Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,4) Stbd Lower Deck

    ; --------------------------------------------------------------------------
    ; Row 5 (j = 5): Lowered Area (h = 0) Walkway Below Captain's Console
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,5)  Port Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,5)  Port Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,5)  Port Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,5)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,5)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,5)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,5)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,5)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,5)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,5)  Stbd Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,5) Stbd Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,5) Stbd Lower Deck

    ; --------------------------------------------------------------------------
    ; Row 6 (j = 6): Lowered Area (h = 0) Open Floor
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (0,6)  Port Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (1,6)  Port Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (2,6)  Port Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (3,6)  Lowered Area Port Aisle
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (4,6)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (5,6)  Lowered Area Center Aisle
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (6,6)  Lowered Area Center Aisle
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (7,6)  Lowered Area Floor
    def_cell 0, PRIM_FLAT, TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (8,6)  Lowered Area Stbd Aisle
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (9,6)  Stbd Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (10,6) Stbd Lower Deck
    def_cell 0, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER, 0, PANEL_NONE, 0, 0 ; (11,6) Stbd Lower Deck

    ; --------------------------------------------------------------------------
    ; Row 7 (j = 7): Lowered Area — Two Ramp Terminal Consoles Below Captain's Console
    ; --------------------------------------------------------------------------
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (0,7)  Port Forward Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (1,7)  Port Forward Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (2,7)  Port Forward Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (3,7)  Forward Lowered Deck
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0, PANEL_NONE, 0, 0 ; (4,7)  Lowered Port Terminal Ramp (Helm/Conn)
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (5,7)  Forward Lowered Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (6,7)  Forward Lowered Deck
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0, PANEL_NONE, 0, 0 ; (7,7)  Lowered Stbd Terminal Ramp (Ops)
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (8,7)  Forward Lowered Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (9,7)  Stbd Forward Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (10,7) Stbd Forward Deck
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0, PANEL_NONE, 0, 0 ; (11,7) Stbd Forward Deck
STARSHIP_MAP_ROM_END:
.assert (STARSHIP_MAP_ROM_END - STARSHIP_MAP_ROM) = MAP_BYTE_SIZE, error, "STARSHIP_MAP_ROM size does not match MAP_BYTE_SIZE"

.segment "GSUCODE"

.endif ; __STARSHIP_MAP_I_DEFINED__
