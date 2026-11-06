; ==============================================================================
; Starship Bridge 12x8 Diorama Map for IsoEngine (StarshipMap)
; Inspired by USS Enterprise-D (Galaxy-class) & USS Voyager (Intrepid-class)
;
; Grid Dimensions:
;   cols = 12 (East-West: Port Wing i=0..3, Central Bridge i=4..7, Starboard Wing i=8..11)
;   rows = 8  (North-South amphitheater layout viewed from Forward Viewscreen cutaway:
;              j=0: Aft Upper Bulkhead — Turbolifts, Master Systems Display & Sector Chart
;              j=1: Aft Engineering/Science Deck, Structural Pillars & Warp Plasma Grates
;              j=2: Tactical Horseshoe Arch, Weapons/Shields Consoles & Bridge Stairs
;              j=3: Central Command Center — Elevated Captain's Chair Dais, XO & Counselor
;              j=4: Crimson Command Circle & Port/Starboard Upper Access Ramps
;              j=5: Forward Bridge Pit — Conn/Helm & Ops Console Blocks & Pit Ramps
;              j=6: Forward Bridge Pit — Conn/Ops Seats & Tactical Holo-Projector
;              j=7: Forward Viewscreen Cutaway Apron & Forward Auxiliary Stations)
;
; Elevation Tiers:
;   - Forward Bridge Pit (h=0, j=5..7, i=3..8): Sunken forward section with
;     elevated Conn/Helm & Ops console blocks (h=1 at j=5 with front LCARS risers),
;     Helm/Ops seats, glowing Tactical Holo-Projector, and Viewscreen holostrip.
;   - Central Command Circle & Aft Walkway (h=1, j=1..4, i=3..8): Crimson command
;     carpet stepping up 1h above the Forward Pit, Tactical Horseshoe sloped
;     weapons/shields consoles, Bulkhead Support Columns (PRIM_PILLAR), and
;     sub-floor Warp Plasma Conduit gratings (PRIM_LIQUID_SHALLOW at bed h=0,
;     flush surface h=1).
;   - Captain's Chair Dais & Aft Upper Bulkhead / Perimeter Decks (h=2..3):
;     Elevated Captain's Chair platform (i=5..6, j=3 at h=2), Aft Master Systems
;     Display & Turbolift Bulkhead (j=0 at h=2 exposing full 14px vertical walls),
;     and terraced Port/Starboard Auxiliary Console Wings (i=0..2 & i=9..11 at h=1..3).
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
    ; Row 0 (j = 0, Aft Upper Bulkhead, h=2): Turbolifts, MSD & Sector Star Chart
    ; Exposes a full 14px vertical wall (y=4..18) above Row 1 (h=1, y=18..34)
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_TURBOLIFT_DOOR, TEXTURE_ID_LCARS_WALL, PANEL_W,    0, 0 ; (0,0)  Port Outer Turbolift Bay
    def_cell 2, PRIM_FLAT, TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_LCARS_WALL,     0,                     PANEL_NONE, 0, 0 ; (1,0)  Port Aft Engineering Alcove
    def_cell 2, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_TURBOLIFT_DOOR, 0,                     PANEL_NONE, 0, 0 ; (2,0)  Port Bridge Turbolift Door
    def_cell 2, PRIM_FLAT, TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT,  0,                     PANEL_NONE, 0, 0 ; (3,0)  Aft Engineering Station I
    def_cell 2, PRIM_FLAT, TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_LCARS_WALL,     0,                     PANEL_NONE, 0, 0 ; (4,0)  Master Systems Display Port
    def_cell 2, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_VIEWSCREEN,     0,                     PANEL_NONE, 0, 0 ; (5,0)  Aft Sector Star Chart Left
    def_cell 2, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_VIEWSCREEN,     0,                     PANEL_NONE, 0, 0 ; (6,0)  Aft Sector Star Chart Right
    def_cell 2, PRIM_FLAT, TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_LCARS_WALL,     0,                     PANEL_NONE, 0, 0 ; (7,0)  Master Systems Display Stbd
    def_cell 2, PRIM_FLAT, TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT,  0,                     PANEL_NONE, 0, 0 ; (8,0)  Aft Science Station I
    def_cell 2, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_TURBOLIFT_DOOR, 0,                     PANEL_NONE, 0, 0 ; (9,0)  Stbd Emergency Turbolift Door
    def_cell 2, PRIM_FLAT, TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_LCARS_WALL,     0,                     PANEL_NONE, 0, 0 ; (10,0) Stbd Aft Science Alcove
    def_cell 2, PRIM_FLAT, TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_TURBOLIFT_DOOR, TEXTURE_ID_LCARS_WALL, PANEL_E,    0, 0 ; (11,0) Captain's Ready Room Door

    ; --------------------------------------------------------------------------
    ; Row 1 (j = 1, Aft Bridge Walkway, h=1..2): Pillars & Sub-Floor Plasma Grates
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT,           TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,     TEXTURE_ID_LCARS_WALL, PANEL_W,    0, 0 ; (0,1)  Port Upper Aux Corner
    def_cell 2, PRIM_FLAT,           TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT,  0,                     PANEL_NONE, 0, 0 ; (1,1)  Port Upper Aux Console
    def_cell 1, PRIM_FLAT,           TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,     0,                     PANEL_NONE, 0, 0 ; (2,1)  Port Turbolift Vestibule
    def_cell 1, PRIM_PILLAR,         TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_BULKHEAD_COL,   0,                     PANEL_NONE, 0, 0 ; (3,1)  Port Structural Support Column
    def_cell 0, PRIM_LIQUID_SHALLOW, TEXTURE_ID_DECK_GRATE,  TEXTURE_ID_PLASMA_CONDUIT, 0,                     PANEL_NONE, 0, 0 ; (4,1)  Port Warp Plasma Floor Grating
    def_cell 1, PRIM_FLAT,           TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,     0,                     PANEL_NONE, 0, 0 ; (5,1)  Aft Bridge Walkway Center-Left
    def_cell 1, PRIM_FLAT,           TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,     0,                     PANEL_NONE, 0, 0 ; (6,1)  Aft Bridge Walkway Center-Right
    def_cell 0, PRIM_LIQUID_SHALLOW, TEXTURE_ID_DECK_GRATE,  TEXTURE_ID_PLASMA_CONDUIT, 0,                     PANEL_NONE, 0, 0 ; (7,1)  Stbd Warp Plasma Floor Grating
    def_cell 1, PRIM_PILLAR,         TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_BULKHEAD_COL,   0,                     PANEL_NONE, 0, 0 ; (8,1)  Stbd Structural Support Column
    def_cell 1, PRIM_FLAT,           TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,     0,                     PANEL_NONE, 0, 0 ; (9,1)  Stbd Turbolift Vestibule
    def_cell 2, PRIM_FLAT,           TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT,  0,                     PANEL_NONE, 0, 0 ; (10,1) Stbd Upper Aux Console
    def_cell 2, PRIM_FLAT,           TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,     TEXTURE_ID_LCARS_WALL, PANEL_E,    0, 0 ; (11,1) Stbd Upper Aux Corner

    ; --------------------------------------------------------------------------
    ; Row 2 (j = 2, Tactical Horseshoe & Bridge Stairs): Security Arch & Aux Wings
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_LCARS_WALL,    PANEL_W,             0, 0 ; (0,2)  Port Upper Perimeter Walkway
    def_cell 2, (PRIM_WEDGE_OUTER | ROT_0),      TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE,          0, 0 ; (1,2)  Port Environmental Station
    def_cell 1, (PRIM_STAIRS | ROT_180),         TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE,          0, 0 ; (2,2)  Port Aft Bridge Stairs (1h->2h)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE,          0, 0 ; (3,2)  Tactical Port Passage
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, (PANEL_N | PANEL_W), 0, 0 ; (4,2)  Tactical Horseshoe Port Wing
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_N,             0, 0 ; (5,2)  Tactical Weapons Console
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_N,             0, 0 ; (6,2)  Tactical Shields Console
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, (PANEL_N | PANEL_E), 0, 0 ; (7,2)  Tactical Horseshoe Stbd Wing
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE,          0, 0 ; (8,2)  Tactical Stbd Passage
    def_cell 1, (PRIM_STAIRS | ROT_180),         TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE,          0, 0 ; (9,2)  Stbd Aft Bridge Stairs (1h->2h)
    def_cell 2, (PRIM_WEDGE_OUTER | ROT_90),     TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE,          0, 0 ; (10,2) Stbd Communications Station
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_LCARS_WALL,    PANEL_E,             0, 0 ; (11,2) Stbd Upper Perimeter Walkway

    ; --------------------------------------------------------------------------
    ; Row 3 (j = 3, Central Command Center): Captain's Chair Dais, XO & Counselor
    ; --------------------------------------------------------------------------
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (0,3)  Port Mid-Bridge Overlook
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP,    TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (1,3)  Port Mission Ops Console
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP,    TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (2,3)  Port Auxiliary Duty Console
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,     TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (3,3)  Command Circle Port Aisle
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (4,3)  First Officer (XO) Chair
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (5,3)  Captain's Chair Dais (Port)
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (6,3)  Captain's Chair Dais (Stbd)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (7,3)  Counselor / Command Chair
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,     TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (8,3)  Command Circle Stbd Aisle
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP,    TEXTURE_ID_CONSOLE_FRONT, TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (9,3)  Stbd Auxiliary Duty Console
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP,    TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (10,3) Stbd Science Aux Console
    def_cell 2, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (11,3) Stbd Mid-Bridge Overlook

    ; --------------------------------------------------------------------------
    ; Row 4 (j = 4, Command Circle Front Lip): Crimson Carpet & Side Aux Ramps
    ; --------------------------------------------------------------------------
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (0,4)  Port Outer Wing Ramp (1h->2h)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (1,4)  Port Mid Walkway
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (2,4)  Port Aux-to-Upper Ramp (1h->2h)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_S,    0, 0 ; (3,4)  Command Circle SW Corner
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (4,4)  Command Carpet Front-Left
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (5,4)  Command Carpet Center-Left
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (6,4)  Command Carpet Center-Right
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (7,4)  Command Carpet Front-Right
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_CMD,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_S,    0, 0 ; (8,4)  Command Circle SE Corner
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (9,4)  Stbd Aux-to-Upper Ramp (1h->2h)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (10,4) Stbd Mid Walkway
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (11,4) Stbd Outer Wing Ramp (1h->2h)

    ; --------------------------------------------------------------------------
    ; Row 5 (j = 5, Forward Bridge Pit Consoles): Conn/Helm, Ops & Pit Ramps
    ; --------------------------------------------------------------------------
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (0,5)  Port Forward Aux Deck
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (1,5)  Port Deflector Control
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (2,5)  Port Forward Aux Console
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (3,5)  Port Pit-to-Command Ramp (0h->1h)
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (4,5)  Conn / Helm Console Block
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (5,5)  Forward Pit Center-Left
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (6,5)  Forward Pit Center-Right
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (7,5)  Ops Station Console Block
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_0),   TEXTURE_ID_CARPET_MAIN, TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (8,5)  Stbd Pit-to-Command Ramp (0h->1h)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (9,5)  Stbd Forward Aux Console
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (10,5) Stbd Tractor Beam Control
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (11,5) Stbd Forward Aux Deck

    ; --------------------------------------------------------------------------
    ; Row 6 (j = 6, Forward Bridge Pit Floor): Helm/Ops Seats & Holo-Projector
    ; --------------------------------------------------------------------------
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,     TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (0,6)  Port Forward Walkway
    def_cell 0, PRIM_LIQUID_SHALLOW,             TEXTURE_ID_DECK_GRATE,     TEXTURE_ID_PLASMA_CONDUIT, 0,                        PANEL_NONE, 0, 0 ; (1,6)  Port Forward EPS Conduit Grate
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN,    TEXTURE_ID_HULL_RISER,     TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (2,6)  Port Pit Overlook Rail
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,     0,                        PANEL_NONE, 0, 0 ; (3,6)  Forward Pit Port Aisle
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_CONSOLE_FRONT,  0,                        PANEL_NONE, 0, 0 ; (4,6)  Conn / Helm Officer Seat
    def_cell 0, PRIM_FOLIAGE_CROSS,              TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,     TEXTURE_ID_HOLO_FIN,      PANEL_NONE, 0, 0 ; (5,6)  Tactical Holo-Projector
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_GRATE,     TEXTURE_ID_HULL_RISER,     0,                        PANEL_NONE, 0, 0 ; (6,6)  Forward Pit Sensor Grating
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_CAPTAINS_CHAIR, TEXTURE_ID_CONSOLE_FRONT,  0,                        PANEL_NONE, 0, 0 ; (7,6)  Ops Officer Seat
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,     0,                        PANEL_NONE, 0, 0 ; (8,6)  Forward Pit Stbd Aisle
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_CARPET_MAIN,    TEXTURE_ID_HULL_RISER,     TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (9,6)  Stbd Pit Overlook Rail
    def_cell 0, PRIM_LIQUID_SHALLOW,             TEXTURE_ID_DECK_GRATE,     TEXTURE_ID_PLASMA_CONDUIT, 0,                        PANEL_NONE, 0, 0 ; (10,6) Stbd Forward EPS Conduit Grate
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,     TEXTURE_ID_HULL_RISER,     TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (11,6) Stbd Forward Walkway

    ; --------------------------------------------------------------------------
    ; Row 7 (j = 7, Forward Viewscreen Cutaway Edge): Viewscreen Apron & Wings
    ; --------------------------------------------------------------------------
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_W,    0, 0 ; (0,7)  Port Forward Bulkhead Corner
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (1,7)  Port Forward Aux Station
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_270), TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (2,7)  Port Forward Step Ramp (0h->1h)
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_S,    0, 0 ; (3,7)  Viewscreen Apron Port Wing
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_VIEWSCREEN,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (4,7)  Forward Viewscreen Holostrip L
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_VIEWSCREEN,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (5,7)  Forward Viewscreen Holostrip CL
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_VIEWSCREEN,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (6,7)  Forward Viewscreen Holostrip CR
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_VIEWSCREEN,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (7,7)  Forward Viewscreen Holostrip R
    def_cell 0, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_S,    0, 0 ; (8,7)  Viewscreen Apron Stbd Wing
    def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    0,                        PANEL_NONE, 0, 0 ; (9,7)  Stbd Forward Step Ramp (0h->1h)
    def_cell 1, (PRIM_WEDGE_STRAIGHT | ROT_90),  TEXTURE_ID_CONSOLE_TOP, TEXTURE_ID_CONSOLE_FRONT, 0,                        PANEL_NONE, 0, 0 ; (10,7) Stbd Forward Aux Station
    def_cell 1, PRIM_FLAT,                       TEXTURE_ID_DECK_PLATE,  TEXTURE_ID_HULL_RISER,    TEXTURE_ID_TACTICAL_RAIL, PANEL_E,    0, 0 ; (11,7) Stbd Forward Bulkhead Corner
STARSHIP_MAP_ROM_END:
.assert (STARSHIP_MAP_ROM_END - STARSHIP_MAP_ROM) = MAP_BYTE_SIZE, error, "STARSHIP_MAP_ROM size does not match MAP_BYTE_SIZE"

.segment "GSUCODE"

.endif ; __STARSHIP_MAP_I_DEFINED__
