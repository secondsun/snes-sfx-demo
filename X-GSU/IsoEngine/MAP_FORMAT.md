# IsoEngine Map Format & Geometry Specification

This guide documents the architecture, mathematical foundations, binary layout, and authoring patterns of the **`IsoEngine` Map Format** (`snes-sfx-demo/X-GSU/IsoEngine/`). The format is designed specifically for the SuperFX (GSU / FX3) coprocessor to render rotatable isometric tactical dioramas (in the style of *Final Fantasy Tactics* and *Tactics Ogre*) across $4 \times 4$ to $12 \times 12$ cell grids with zero per-cell 3D projection overhead and zero sub-pixel seams.

---

## 1. Overview & Design Philosophy

### 1.1 Dual-Memory Split: S-CPU Gameplay vs. GSU Visual Map Data

On the SNES, tactical RPG maps serve two fundamentally different consumers:
1. **S-CPU (65816 in WRAM)**: Runs turn order, A* pathfinding, line-of-sight, height-advantage combat math, and elemental terrain effects. It needs compact logical state (walkability, movement cost, water depth, unit occupancy ID) that never touches the 3D rasterizer.
2. **GSU (SuperFX in GSURAM / ROM)**: Runs back-to-front painter's traversal, trapezoid scanline edge setup, and affine UV texture rasterization at 21.47 MHz. It needs pre-baked visual indices, elevation drops, and texture IDs with zero pointer chasing.

```
+-----------------------------------+       +-----------------------------------+
|        S-CPU Gameplay Grid        |       |       GSU Visual Map Format       |
|            (S-WRAM)               |       |          (GSURAM / ROM)           |
+-----------------------------------+       +-----------------------------------+
| - Move cost / walkability flags   |       | - 8-byte MapHeader                |
| - Terrain elemental type          |       | - 8-byte MapCell[cols * rows]     |
| - Unit occupancy index            |       |   (height, archetype, tex IDs,    |
| - Event / trigger IDs             |       |    edge panels, baked drops)      |
+-----------------------------------+       +-----------------------------------+
                  |                                           |
                  +-----> Synchronized by (i, j) Grid <-------+
```

By decoupling gameplay state from visual map records, each `MapCell` consumed by the GSU fits into an exact **8-byte power-of-two stride** (`i << 3`), enabling fast address computation without hardware multiplication.

---

### 1.2 Orthographic Linearity & Archetype Instancing

In an orthographic projection with fixed pitch ($\alpha = 30^\circ$) and variable yaw ($\theta \in [0, 120)$), projection is a strictly linear operator:

$$\text{Project}(\vec{v}_{\text{local}} + \vec{P}_{\text{cell}}) = \text{Project}(\vec{v}_{\text{local}}) + \text{Project}(\vec{P}_{\text{cell}})$$

Because of this linearity, the engine **never transforms or projects vertices per map cell**:
1. **Once per camera `yaw` angle**, the engine projects a small fixed pool of local **`Shape Archetypes`** (`PRIM_FLAT`, `PRIM_WEDGE`, `PRIM_STAIRS`, `PRIM_LIQUID`, `PRIM_PILLAR`, `PRIM_FOLIAGE_CROSS`) into pre-sliced screen-space trapezoid templates (`ARCH_TRAPS`).
2. **During grid traversal** ($4 \times 4$ up to $12 \times 12$ cells), each `MapCell` simply computes its integer screen-space anchor $(X_{\text{cell}}, Y_{\text{cell}})$ and stamps the pre-built trapezoids of its assigned `Shape Archetype` by adding $(X_{\text{cell}}, Y_{\text{cell}})$ to the trapezoid X-intercepts and Y-bounds.

---

### 1.3 1:1 World-to-Texel Scale & True $32 \times 32 \times 32$ Cubes

Every spatial dimension in `IsoEngine` maps **1:1 with texture space** (1 world unit = 1 texel):

| Dimension / Unit | World Units (Texels) | Screen-Space Vertical Span ($\alpha = 30^\circ$) | Description |
| :--- | :---: | :---: | :--- |
| **Cell Width ($\Delta x$)** | $32$ | $\text{round}(16 \sin\theta)$ | Horizontal East-West cell span |
| **Cell Depth ($\Delta z$)** | $32$ | $\text{round}(16 \cos\theta)$ | Horizontal North-South cell span |
| **$1\text{h}$ Half-Block** | $16$ | $14\text{ px}$ ($\text{round}(16 \cos 30^\circ)$) | Standard tactical step height |
| **$2\text{h}$ Full Block** | $32$ | $28\text{ px}$ ($2 \times 14\text{ px}$) | True $32 \times 32 \times 32$ world-unit cube |

```
         /\
        /  \         <- Top Diamond: 32 x 32 world units (texels)
       /    \
      |\    /|
      | \  / |  14 px = 1h (Half-Block = 16 world units / texels)
      |  \/  |
      |\    /|
      | \  / |  28 px = 2h (Full Block = 32 world units / texels = True Cube)
       \ \/ /
        \  /
         \/
```

Because $1\text{h} = 16$ world units and $2\text{h} = 32$ world units, a standard $32 \times 32$ texture tiles seamlessly across both horizontal ground faces and $2\text{h}$ vertical cliff or wall faces with zero aspect distortion.

---

### 1.4 Integer Basis Vectors & The 28-Point Canonical Lattice (`LATTICE_V2`)

Independent floating-point rounding of shared vertices between adjacent cells or sub-cell wedges causes 1-pixel cracks during rotation. `IsoEngine` eliminates all T-junctions and seams by defining cell origins and intra-cell geometry strictly on a **Discrete Integer Basis** for every yaw step $\theta$:

$$\vec{S}_x = \bigl(\text{round}(32\cos\theta),\; \text{round}(16\sin\theta)\bigr), \qquad \vec{S}_z = \bigl(\text{round}(-32\sin\theta),\; \text{round}(16\cos\theta)\bigr), \qquad \vec{S}_y = (0, -14)$$

A map cell at grid coordinate $(i, j)$ with elevation $h$ (in $1\text{h}$ units) resolves its screen anchor purely via integer addition:

$$(X_{\text{cell}}, Y_{\text{cell}}) = (X_{\text{origin}}, Y_{\text{origin}}) + i \cdot \vec{S}_x + j \cdot \vec{S}_z + h \cdot \vec{S}_y$$

Within each cell, all vertices of all `Shape Archetypes` snap to the **28-Point Canonical Lattice (`LATTICE_V2`)**, derived purely by halving (`>> 1`) and quartering (`>> 2`) the integer cell basis vectors $\vec{S}_x$ and $\vec{S}_z$:
- **Corners $\{0, 32\} \times \{0, 32\}$**: Exact multiples of $\vec{S}_x, \vec{S}_z$ (shared seamlessly across cell boundaries).
- **Edge Midpoints ($16$)**: Exact integer halves $\vec{S}_{x/2} = \vec{S}_x \gg 1$ and $\vec{S}_{z/2} = \vec{S}_z \gg 1$ (used by `PRIM_STAIRS` and `PRIM_FOLIAGE_CROSS`).
- **Quarter Insets ($8, 24$)**: Exact quarter steps (used by `PRIM_PILLAR` $[8..24] \times [8..24]$).

---

## 2. Binary Layout & Data Structures

All map data is stored in little-endian format with an 8-byte header followed immediately by `cols * rows` 8-byte cell records in row-major order (`index = j * cols + i`).

### 2.1 `map_header` (8 Bytes)

| Offset | Field | Type | Size | Description |
| :---: | :--- | :---: | :---: | :--- |
| `+0` | `cols` | `u8` | 1 B | Map width in cells ($i \in [0, \text{cols}-1]$, supported range $4..12$) |
| `+1` | `rows` | `u8` | 1 B | Map depth in cells ($j \in [0, \text{rows}-1]$, supported range $4..12$) |
| `+2` | `origin_x` | `s16` | 2 B | Screen-space X pixel anchor for cell $(0, 0, h=0)$ |
| `+4` | `origin_z` | `s16` | 2 B | Screen-space Y pixel anchor for cell $(0, 0, h=0)$ |
| `+6` | `reserved` | `u16` | 2 B | Reserved padding (set to `$0000` for 8-byte alignment) |

---

### 2.2 `map_cell` (8 Bytes)

| Offset | Field | Type | Size | Description |
| :---: | :--- | :---: | :---: | :--- |
| `+0` | `base_height` | `u8` | 1 B | **Lowest opaque floor** elevation in $1\text{h}$ ($16$-unit / $14\text{px}$) steps |
| `+1` | `archetype_id` | `u8` | 1 B | Bits `0..5`: `Shape Archetype` ID (`0..63`); Bits `6..7`: $90^\circ$ rotation (`0..3`) |
| `+2` | `top_tex_id` | `u8` | 1 B | Texture ID for primary upper/horizontal surfaces (floor, slope, water surface) |
| `+3` | `skirt_tex_id` | `u8` | 1 B | Texture ID for `Cell Skirts`, stair risers, pillar sides, or submerged riverbed |
| `+4` | `panel_tex_id` | `u8` | 1 B | Texture ID for vertical `Edge Panels` or `PRIM_FOLIAGE_CROSS` cutout fins |
| `+5` | `panel_flags` | `u8` | 1 B | Edge panel placement bitmask, height flag, and future UV mode bits |
| `+6` | `drop_ns` | `u8` | 1 B | Baked vertical skirt drop ($\Delta h$ in $1\text{h}$ steps) on the North or South face |
| `+7` | `drop_ew` | `u8` | 1 B | Baked vertical skirt drop ($\Delta h$ in $1\text{h}$ steps) on the East or West face |

#### Bitfield Breakdown: `archetype_id` (Offset `+1`) & `panel_flags` (Offset `+5`)

```
  archetype_id (+1)                                panel_flags (+5)
 +----+----+----+----+----+----+----+----+        +----+----+----+----+----+----+----+----+
 | R1 | R0 | A5 | A4 | A3 | A2 | A1 | A0 |        | M2 | M1 | M0 | H2 | PW | PS | PE | PN |
 +----+----+----+----+----+----+----+----+        +----+----+----+----+----+----+----+----+
   7    6    5    4    3    2    1    0             7    6    5    4    3    2    1    0
   \____/    \_________________________/            \_________/   \_/   \______________/
  Rotation       Base Archetype (0..63)             Reserved UV   0=1h   Edge Panel Mask
  00 = 0 deg     (Combined 0..255 index             Wrap/Clamp    1=2h   Bit 0: North (j-1)
  01 = 90 deg     into ARCH_TABLE after             Modes (000)   Full   Bit 1: East  (i+1)
  10 = 180 deg    rotation baking)                               Tall   Bit 2: South (j+1)
  11 = 270 deg                                                           Bit 3: West  (i-1)
```

---

### 2.3 `ca65` Struct & Constant Definitions

```ca65
; ==============================================================================
; IsoEngine Binary Map Structures (ca65)
; ==============================================================================

.struct map_header
    cols            .byte   ; +0: Grid width (4..12)
    rows            .byte   ; +1: Grid depth (4..12)
    origin_x        .word   ; +2: Screen X anchor (signed 16-bit)
    origin_z        .word   ; +4: Screen Y anchor (signed 16-bit)
    reserved        .word   ; +6: Alignment padding ($0000)
.endstruct

.struct map_cell
    base_height     .byte   ; +0: Lowest opaque floor height (1h = 16 world units = 14px)
    archetype_id    .byte   ; +1: [7:6] rot (0..3), [5:0] shape archetype
    top_tex_id      .byte   ; +2: Top/cap surface texture ID
    skirt_tex_id    .byte   ; +3: Skirt/cliff/riser/riverbed texture ID
    panel_tex_id    .byte   ; +4: Edge panel / foliage cutout texture ID
    panel_flags     .byte   ; +5: [3:0] W/S/E/N mask, [4] 2h tall flag, [7:5] reserved
    drop_ns         .byte   ; +6: Baked North/South skirt drop in 1h units
    drop_ew         .byte   ; +7: Baked East/West skirt drop in 1h units
.endstruct

; Rotation encodings for archetype_id bits [7:6]
ROT_0               = (0 << 6)
ROT_90              = (1 << 6)
ROT_180             = (2 << 6)
ROT_270             = (3 << 6)

; Edge Panel flags for panel_flags
PANEL_NONE          = $00
PANEL_N             = (1 << 0)  ; North edge (j - 1 boundary)
PANEL_E             = (1 << 1)  ; East edge  (i + 1 boundary)
PANEL_S             = (1 << 2)  ; South edge (j + 1 boundary)
PANEL_W             = (1 << 3)  ; West edge  (i - 1 boundary)
PANEL_TALL_2H       = (1 << 4)  ; 0 = 1h (16-unit) parapet, 1 = 2h (32-unit) facade
```

---

### 2.4 Elevation Invariants: `base_height` & Baked Skirt Drops (`drop_ns`, `drop_ew`)

To prevent vertical gaps without performing neighbor lookups at runtime, map compilers enforce two elevation invariants when baking a `map_cell`:

1. **Lowest-Opaque-Floor Invariant (`base_height`)**:
   `base_height` always records the **lowest opaque horizontal surface** of the cell in $1\text{h}$ units:
   - For flat blocks (`PRIM_FLAT`), pillars (`PRIM_PILLAR`), and foliage (`PRIM_FOLIAGE_CROSS`), `base_height` is the floor height $h$.
   - For ramps (`PRIM_WEDGE`) and stairs (`PRIM_STAIRS`) rising from $h$ to $h+1$ or $h+2$, `base_height` is the **bottom** elevation $h$ (the ramp/stair geometry itself rises $+1\text{h}$ or $+2\text{h}$ above `base_height`).
   - For water (`PRIM_LIQUID`), `base_height` is the **opaque riverbed** elevation $h_{\text{bed}}$, while the translucent water surface floats at $+1\text{h}$ (shallow) or $+2\text{h}$ (deep) above `base_height`.

2. **Baked Neighbor Skirt Drop Formula**:
   For any cell $(i, j)$ with lowest opaque floor $h_{\text{cell}} = \text{base\_height}(i, j)$, the vertical `Cell Skirt` drop toward an adjacent neighbor $(i', j')$ is pre-computed as:
   $$\Delta h = \max\bigl(0,\; h_{\text{cell}} - h_{\text{neighbor}}\bigr)$$
   On the outer boundaries of the map ($i=0, i=\text{cols}-1, j=0, j=\text{rows}-1$), $h_{\text{neighbor}} = 0$, so the outer diorama walls automatically drop all the way to the base of the plinth ($\Delta h = h_{\text{cell}}$).

---

## 3. Universal `Shape Archetypes`, `Cell Skirts`, and `Edge Panels`

Every cell in the `Map Grid` is composed from up to three modular visual layers:
1. **`Cell Skirts`**: Vertical cliff/wall faces extending downward from `base_height` by `drop_ns` / `drop_ew`.
2. **`Shape Archetype`**: The primary 3D terrain primitive occupying the cell above `base_height`.
3. **`Edge Panels`**: Optional vertical cutout billboards ($1\text{h}$ or $2\text{h}$) along the cell's N/E/S/W perimeter.

### 3.1 Summary of the 7 Universal `Shape Archetypes`

| Archetype Constant | ID | Height Span | Texture Slots Used | Primary Tactical Use Cases |
| :--- | :---: | :---: | :--- | :--- |
| `PRIM_FLAT` | `0` | $+0\text{h}$ | `top_tex_id` | Flat tiles, half/full blocks, bridges, false-archway gates |
| `PRIM_WEDGE_STRAIGHT` | `1..2` | $+1\text{h}$ or $+2\text{h}$ | `top_tex_id`, `skirt_tex_id` | Sloped ramps, pitched roofs, angled buttresses |
| `PRIM_WEDGE_OUTER` | `3..4` | $+1\text{h}$ or $+2\text{h}$ | `top_tex_id`, `skirt_tex_id` | Convex hillside corners, hipped roof corners |
| `PRIM_WEDGE_INNER` | `5..6` | $+1\text{h}$ or $+2\text{h}$ | `top_tex_id` | Concave valley corners, roof valleys |
| `PRIM_STAIRS` | `7` | $+2\text{h}$ (2 steps) | `top_tex_id`, `skirt_tex_id` | Stone/wood staircases ($+1\text{h}$ at $z=16$, $+2\text{h}$ at $z=0$) |
| `PRIM_LIQUID_SHALLOW` | `8` | $+0\text{h}$ bed, $+1\text{h}$ top | `skirt_tex_id` (bed), `top_tex_id` (water) | Fordable rivers, canals, fountains, shallow marshes |
| `PRIM_LIQUID_DEEP` | `9` | $+0\text{h}$ bed, $+2\text{h}$ top | `skirt_tex_id` (bed), `top_tex_id` (water) | Deep swamps, castle moats, flooded caverns |
| `PRIM_PILLAR` | `10` | $+2\text{h}$ column | `top_tex_id`, `skirt_tex_id` | Cathedral columns, broken obelisks, thick tree trunks |
| `PRIM_FOLIAGE_CROSS` | `11` | $+2\text{h}$ fins | `top_tex_id` (floor), `panel_tex_id` (fins) | Tree canopies, bushes, tall reeds, crystals |

---

### 3.2 Detailed Archetype Breakdown & ASCII Geometry

#### 1. `PRIM_FLAT` (Flat Tile / Block Cap)
Renders a single horizontal $32 \times 32$ quad at $y = \text{base\_height}$ using `top_tex_id`. Combined with `Cell Skirts` (`skirt_tex_id`), it forms half-blocks ($1\text{h}$), full $32\times 32\times 32$ cubes ($2\text{h}$), tall cliffs, rooftops, or false-archway gates (where an arch doorway is painted into a $64\times 64$ `skirt_tex_id` texture).

```
  (0,0,0) +-----------+ (32,0,0)
         /           /
        / top_tex   /   <- Horizontal quad at y = base_height (UV: 0..32 x 0..32)
       /           /
(0,0,32)+-----------+ (32,0,32)
```

#### 2. `PRIM_WEDGE` (`STRAIGHT`, `OUTER`, `INNER` + Rotations `ROT_0..ROT_270`)
Sloped terrain primitives rising $+1\text{h}$ ($16$ units / $14\text{px}$) or $+2\text{h}$ ($32$ units / $28\text{px}$) above `base_height`. `WEDGE_STRAIGHT` includes two vertical triangular side cheeks (`skirt_tex_id`) that are back-face culled depending on camera `yaw`.

```
  WEDGE_STRAIGHT (ROT_0: rises South->North)    WEDGE_OUTER (Convex)     WEDGE_INNER (Concave)
       (0,h,0) +-----------+ (32,h,0)                (0,h,0) +---+            +-----------+
              /           /|                                / \   \          / \         /
             /  top_tex  / | <- cheek (skirt_tex)          /   \   \        /   \_______/
            /           /  + (32,0,0)                     /     \   \      /           /
  (0,0,32) +-----------+                                 +-------+---+    +-----------+
```

#### 3. `PRIM_STAIRS` (2-Step Monolithic Staircase)
Splits the cell along the canonical midpoint ($16$) into two horizontal treads (`top_tex_id` at $+1\text{h}$ and $+2\text{h}$), two vertical risers (`skirt_tex_id`), and stepped side cheeks (`skirt_tex_id`). All interior faces are pre-sorted into `ARCH_TRAPS` per yaw angle.

```
              (0,32,0) +-----------+ (32,32,0)   <- Upper Tread (+2h = +32 units, top_tex_id)
                      /|  Tread 2  |
                     / +-----------+             <- Upper Riser (z=16, y=16..32, skirt_tex_id)
        (0,16,16)   +-/  Tread 1  /|             <- Lower Tread (+1h = +16 units, top_tex_id)
                    | +----------+ |
  cheek (skirt_tex) |/   Riser 1  \|             <- Lower Riser (z=32, y=0..16, skirt_tex_id)
          (0,0,32)  +--------------+ (32,0,32)
```

#### 4. `PRIM_LIQUID` (`PRIM_LIQUID_SHALLOW` $+1\text{h}$ / `PRIM_LIQUID_DEEP` $+2\text{h}$)
Renders two stacked horizontal $32 \times 32$ quads inside a single cell without requiring multi-layer map cells:
1. **Submerged Bed Quad** at $y = \text{base\_height}$ using `skirt_tex_id` (sand, mud, or cobbles).
2. **Water Surface Quad** at $y = \text{base\_height} + 1\text{h}$ (shallow) or $+2\text{h}$ (deep) using `top_tex_id`. By authoring `top_tex_id` with a 50% checkerboard of palette index `0` (transparent) and water texels, the GSU's native `plot` transparency hardware composites the water over the bed in a single pass.

```
         +-----------+  <- Water Surface (+1h or +2h): top_tex_id (50% color-0 screen-door)
        / ~ ~ ~ ~ ~ /
       +-----------+
       :           :    <- Parallax depth gap (14px shallow / 28px deep)
       +-----------+
      /  bed_tex  /     <- Opaque Riverbed (y = base_height): skirt_tex_id
     +-----------+
```

#### 5. `PRIM_PILLAR` (Floor + Inset $[8..24] \times [8..24]$ Convex Column)
Renders the full $32 \times 32$ floor quad (`top_tex_id`) at $y = \text{base\_height}$, followed by a central $16 \times 16$ square column spanning $x \in [8, 24], z \in [8, 24]$ and rising $+2\text{h}$ ($32$ units). Because the column is strictly convex, only its two camera-facing vertical walls (`skirt_tex_id`) and its $16 \times 16$ cap (`top_tex_id`) are emitted for any yaw angle.

```
       +-------+
      /  cap  /|        <- Inset [8..24] x [8..24] column (+2h = 32 units tall)
     +-------+ |
     |       | |        <- 2 visible vertical walls (skirt_tex_id)
  +--+       | +--+
 /   |       |/  /      <- Full 32x32 floor quad at y = base_height (top_tex_id)
+----+-------+--+
```

#### 6. `PRIM_FOLIAGE_CROSS` (Floor + 4 Center-Radiating Cutout Fins)
Renders the $32 \times 32$ floor quad (`top_tex_id`) at $y = \text{base\_height}$, followed by 4 vertical $16 \times 32$ billboard fins (`panel_tex_id` with color-`0` transparency) radiating from the cell center $(16, 16)$ to the 4 canonical edge midpoints: North $(16,0)$, South $(16,32)$, West $(0,16)$, and East $(32,16)$. Because the fins meet only at the center spine $(16, 16)$ and never cross through each other, sorting the 4 fins back-to-front by camera yaw quadrant produces exact painter's order with zero splitting.

> **Important Tactical Constraint**: Unit occupation on `PRIM_FOLIAGE_CROSS` cells is **disallowed in the initial implementation** (the S-CPU pathfinder marks these cells as impassable obstacle foliage). Allowing units to stand inside a foliage cross cell requires splitting the 4 fins into 2 back fins (drawn before the unit) and 2 front fins (drawn after the unit) and is reserved as a future feature.

```
        (16,0) North Fin
           |
  (0,16) --+-- (32,16)   <- 4 center-radiating vertical cutout fins (panel_tex_id)
           |                sorted back-to-front per camera yaw quadrant
        (16,32) South Fin
```

---

### 3.3 `Cell Skirts` (`ARCH_SKIRT_NS`, `ARCH_SKIRT_EW`) & Half-Open Scanline Intervals

For any camera yaw $\theta$, exactly two vertical cliff faces of a cell can face the viewer: one from $\{N, S\}$ (`drop_ns`) and one from $\{E, W\}$ (`drop_ew`). Rather than storing separate archetypes for every cliff height, the engine builds two unit-height ($1\text{h} = 14\text{px}$) vertical parallelogram templates (`ARCH_SKIRT_NS` and `ARCH_SKIRT_EW`) and scales their vertical body span by $\Delta h \times 14\text{px}$ at stamp time.

All trapezoids in `IsoEngine` use **half-open vertical scanline intervals** $[y_{\text{top}}, y_{\text{bot}})$:
- The bottom scanline of a `Shape Archetype` ($y_{\text{top}} + \text{height}$) equals the exact top scanline of the `Cell Skirt` below it.
- Because the upper trapezoid stops at $y_{\text{bot}} - 1$ and the skirt starts at $y_{\text{bot}}$, every screen pixel along a horizontal seam is rasterized **once and only once** (zero gaps, zero double-draw).

---

### 3.4 `Edge Panels` (`panel_flags`) & The 5-Step Intra-Cell Draw Order

`Edge Panels` are zero-thickness vertical quads placed along any combination of a cell's 4 outer borders (`PANEL_N`, `PANEL_E`, `PANEL_S`, `PANEL_W`), rising either $1\text{h}$ ($16$ world units, e.g., stone parapets, bridge railings, wooden fences) or $2\text{h}$ (`PANEL_TALL_2H`, $32$ world units, e.g., windowed cottage facades, portcullis gates, stained glass).

When rendering a cell $(i, j)$, the GSU executes a deterministic **5-step intra-cell painter's pipeline**:

```
  Step 1: Cell Skirts        (drop_ns, drop_ew below base_height using skirt_tex_id)
            |
            v
  Step 2: Back Edge Panels   (panels on the 2 receding edges of the cell using panel_tex_id)
            |
            v
  Step 3: Shape Archetype    (primary terrain primitive at base_height)
            |
            v
  Step 4: [Future Unit Hook] (character sprite standing on the cell floor)
            |
            v
  Step 5: Front Edge Panels  (panels on the 2 camera-facing edges using panel_tex_id)
```

Because **Step 5 (`Front Edge Panels`)** executes *after* the floor (`Step 3`) and any character sprite (`Step 4`), palette color `0` (transparent) texels in `panel_tex_id` naturally reveal the floor and any unit standing behind battlements, railings, or window frames!

---

## 4. Texture System & World-Aligned UV Tiling

### 4.1 `TEXTURE_TABLE` & Pre-Shifted Fixed-Point $V$ Coordinates

All textures live in a linear ROM atlas with power-of-two row stride $2^{\text{ATLAS\_STRIDE\_SHIFT}}$ (typically $128$ or $256$ bytes/row). Each `tex_id` (`0..255`) indexes a 4-byte descriptor in `TEXTURE_TABLE`:

| Offset | Field | Type | Description |
| :---: | :--- | :---: | :--- |
| `+0` | `rom_offset` | `u16` | Base pointer `(V_atlas_base << ATLAS_STRIDE_SHIFT) \| U_atlas_base` |
| `+2` | `u_mask` | `u8` | Horizontal power-of-two wrap mask ($2^W - 1$: `$0F`, `$1F`, `$3F`) |
| `+3` | `v_mask` | `u8` | Vertical power-of-two wrap mask ($2^H - 1$: `$0F`, `$1F`, `$3F`) |

During inner-loop scanline rasterization, $U$ is maintained in standard `Q8.8` fixed-point, while $V$ is maintained in **pre-shifted `Q(16 - ATLAS_STRIDE_SHIFT).(ATLAS_STRIDE_SHIFT)` fixed-point**. Extracting the integer row offset and wrapping by `v_mask` requires only a single bitwise `AND` before `OR`-combining with `U_int` and adding `rom_offset`.

---

### 4.2 Seamless World-Space UV Alignment

Rather than resetting UV coordinates to $(0, 0)$ on every cell, `IsoEngine` shifts each cell's starting $(U_0, V_0)$ by its world-space grid coordinates masked by `(u_mask, v_mask)`:

$$U_{\text{base}} = (i \times 32) \;\ \&\;\ \text{u\_mask}, \qquad V_{\text{base}} = \begin{cases} (j \times 32) \;\ \&\;\ \text{v\_mask} & \text{(Horizontal surfaces)} \\ (h \times 16) \;\ \&\;\ \text{v\_mask} & \text{(Vertical skirts / panels)} \end{cases}$$

This single formula automatically supports three texture tiling scales out of the box:
- **$16 \times 16$ Micro-Tile (`mask = $0F`)**: Repeats $2 \times 2$ times across a $32 \times 32$ cell floor or $2 \times 1$ across a $1\text{h}$ skirt.
- **$32 \times 32$ Standard Tile (`mask = $1F`)**: Maps $1:1$ onto a single cell floor or a $2\text{h}$ ($32$-unit) full-block wall.
- **$64 \times 64+$ Macro-Tile (`mask = $3F`)**: Seamlessly spans a $2 \times 2$ block of cells horizontally or a $4\text{h}$ ($64$-unit) vertical cliff face—allowing large stone arches, rose windows, or multi-tile mosaics without splitting geometry.

> **Future UV Wrapping Modes (`panel_flags` bits `5..7`)**: Bits `5..7` of `panel_flags` are reserved (`000` in v1) for future per-cell UV mapping overrides, including **tile/repeat** (default), **fill/stretch** (scaling a $16\times 16$ texture across a $32\times 32$ face), and **clamp** (single non-repeating decal placement).

---

## 5. Six Concrete Cookbook Examples (*Final Fantasy Tactics* Scenarios)

To streamline map authoring in `ca65`, define a helper macro `def_cell` that emits the 8-byte `map_cell` structure in a single readable line:

```ca65
.macro def_cell h, arch, top_tex, skirt_tex, panel_tex, pflags, drop_ns, drop_ew
    .byte h, arch, top_tex, skirt_tex, panel_tex, pflags, drop_ns, drop_ew
.endmacro
```

---

### 5.1 Scenario 1: High-Density Urban Slum (*Dorter Trade City*)

**Visual Design**: Multi-story brick tenements topped with pitched clay-tile roofs (`PRIM_WEDGE_STRAIGHT`), narrow cobblestone alleys (`PRIM_FLAT`), wooden external stairs (`PRIM_STAIRS`) climbing to upper balconies, and $1\text{h}$ wooden balcony railings (`PANEL_S | PANEL_E`).

```
       +-----------+  <- Pitched Clay Roof: base_height=4h, PRIM_WEDGE_STRAIGHT (+2h)
      /  Clay Roof  \
     +---------------+
     |  Plaster Wall | <- 4h Brick/Plaster Tenement Skirt (drop_ns=4, drop_ew=2)
     |   [Window]    |
     +---------------+-------+
     | Stairs (+2h)  |Balcony| <- Balcony (h=2) with 1h Wooden Railing (PANEL_S)
     +---------------+-------+
    / Cobble Alley  /
   +---------------+
```

```ca65
; --- Dorter Slum 2x2 Excerpt (Alley, Stairway, Balcony, Tenement Roof) ---
; Row j=0: Tenement Roof (0,0) at h=4 and Upper Balcony (1,0) at h=2
def_cell 4, (PRIM_WEDGE_STRAIGHT | ROT_0), TEX_CLAY_ROOF, TEX_PLASTER_WALL, TEX_NONE, PANEL_NONE, 4, 2
def_cell 2, PRIM_FLAT,                     TEX_WOOD_FLOOR, TEX_BRICK_WALL,  TEX_WOOD_RAIL, (PANEL_E | PANEL_S), 2, 2

; Row j=1: Cobblestone Alley (0,1) at h=0 and Wooden Stairs (1,1) rising h=0 -> h=2
def_cell 0, PRIM_FLAT,                     TEX_COBBLE,     TEX_DIRT_PLINTH, TEX_NONE, PANEL_NONE, 0, 0
def_cell 0, (PRIM_STAIRS | ROT_0),         TEX_WOOD_STEP,  TEX_WOOD_RISER,  TEX_WOOD_RAIL, PANEL_E, 0, 0
```

---

### 5.2 Scenario 2: Natural Chokepoint / Mountain Pass (*Mount Bervenia / Balias Tor*)

**Visual Design**: Terraced rocky crags combining straight slopes (`PRIM_WEDGE_STRAIGHT`), convex cliff spurs (`PRIM_WEDGE_OUTER`), and concave valley corners (`PRIM_WEDGE_INNER`) so all diagonal ridgelines lock together on the 28-point `Canonical Lattice` with zero gaps.

```
     (0,0) WEDGE_OUTER         (1,0) WEDGE_STRAIGHT      (2,0) FLAT PLATEAU
        +---+                     +-----------+             +-----------+
       / \   \                   /   Slope    /            /  High Pass /
      /   \   \                 /   (+2h)    /            /   (h=4)    /
     +-----+---+               +------------+            +------------+
     (0,1) WEDGE_STRAIGHT      (1,1) WEDGE_INNER         (2,1) WEDGE_STRAIGHT
```

```ca65
; --- Mountain Pass 3x2 Ridge Transition (h=2 Terrace Rising to h=4 Summit) ---
; Row j=0: Outer Spur (0,0), North Slope (1,0), Summit Plateau (2,0)
def_cell 2, (PRIM_WEDGE_OUTER    | ROT_0),  TEX_GRASS_ROCK, TEX_CLIFF_STRATA, TEX_NONE, PANEL_NONE, 2, 0
def_cell 2, (PRIM_WEDGE_STRAIGHT | ROT_90), TEX_GRASS_ROCK, TEX_CLIFF_STRATA, TEX_NONE, PANEL_NONE, 2, 0
def_cell 4, PRIM_FLAT,                      TEX_SNOW_ROCK,  TEX_CLIFF_STRATA, TEX_NONE, PANEL_NONE, 0, 4

; Row j=1: West Slope (0,1), Concave Valley Corner (1,1), Summit Ramp (2,1)
def_cell 0, (PRIM_WEDGE_STRAIGHT | ROT_0),  TEX_DIRT_TRAIL, TEX_CLIFF_STRATA, TEX_NONE, PANEL_NONE, 0, 0
def_cell 2, (PRIM_WEDGE_INNER    | ROT_0),  TEX_GRASS_ROCK, TEX_CLIFF_STRATA, TEX_NONE, PANEL_NONE, 2, 0
def_cell 2, (PRIM_WEDGE_STRAIGHT | ROT_0),  TEX_DIRT_TRAIL, TEX_CLIFF_STRATA, TEX_NONE, PANEL_NONE, 2, 2
```

---

### 5.3 Scenario 3: Deep Swamp & Waterfall (*Tchigolith Fenlands / Zeirchele Falls*)

**Visual Design**: Murky marsh water (`PRIM_LIQUID_SHALLOW` and `PRIM_LIQUID_DEEP`) over a visible mud riverbed, reed clusters (`PRIM_FOLIAGE_CROSS`), and a multi-step waterfall where an elevated stream (`h=4`) drops down to a lower pool (`h=0`) using a scrolling vertical waterfall texture (`TEX_WATERFALL`) on `skirt_tex_id` plus a wooden plank bridge (`PRIM_FLAT` at `h=2`) with rope railings (`PANEL_N | PANEL_S`).

```
   Upper River (h=4, PRIM_LIQUID_SHALLOW)
     +-----------+
    / ~ ~ ~ ~ ~ /
   +-----------+
   | ||||||||| |  <- 4h Waterfall Skirt (drop_ns=4, skirt_tex_id = TEX_WATERFALL)
   | ||||||||| |
   +-----------+-----------+
  / ~ ~ ~ ~ ~ / Bridge h=2 / <- Wooden Bridge with 1h Rope Railings (PANEL_N | PANEL_S)
 +-----------+-----------+
 :  Mud Bed  :  Water Surface (+1h) underneath/beside bridge
 +-----------+
```

```ca65
; --- Waterfall & Fenland Bridge 2x2 Excerpt ---
; Row j=0: Upper Waterfall Lip (0,0) at h=4 and Mossy Cliff Bank (1,0) at h=4
def_cell 4, PRIM_LIQUID_SHALLOW, TEX_WATER_SHIMMER, TEX_MUD_BED,      TEX_NONE,      PANEL_NONE, 4, 0
def_cell 4, PRIM_FLAT,           TEX_MOSS_STONE,    TEX_CLIFF_WET,    TEX_NONE,      PANEL_NONE, 2, 4

; Row j=1: Deep Plunge Pool (0,1) at h=0 (with 4h waterfall skirt on North neighbor) & Bridge (1,1)
def_cell 0, PRIM_LIQUID_DEEP,    TEX_WATER_MURKY,   TEX_WATERFALL,    TEX_NONE,      PANEL_NONE, 0, 0
def_cell 2, PRIM_FLAT,           TEX_WOOD_PLANK,    TEX_WOOD_SUPPORT, TEX_ROPE_RAIL, (PANEL_N | PANEL_S), 2, 2
```

---

### 5.4 Scenario 4: Fortress Ramparts & False Archway Gate (*Fort Besselat / Riovanes Castle*)

**Visual Design**: Crenellated stone battlements using $1\text{h}$ merlon parapets (`PANEL_S | PANEL_W`), stone guard towers, and a **False Archway Gatehouse**: because true overhang tunnels require multi-layer cells, the gatehouse is authored as a solid `h=4` `PRIM_FLAT` battlements block whose `skirt_tex_id` uses a $64 \times 64$ macro-texture (`TEX_GATE_ARCH_64`) containing a dark recessed archway and iron portcullis, paired with a $2\text{h}$ decorative portcullis frame panel (`PANEL_S | PANEL_TALL_2H`).

```
    [=] [=] [=] [=]   <- 1h Crenellated Battlement Parapet (panel_flags = PANEL_S)
   +---------------+
  /  Walkway (h=4) /  <- Castle Units stand here; color-0 gaps in merlons show legs!
 +---------------+
 |  _.-"""""-._  |
 | |  ARCHWAY  | |    <- False Archway: 4h Cell Skirt with 64x64 TEX_GATE_ARCH_64
 | | (Painted) | |       + 2h Portcullis Edge Panel at Gate Entrance
 +---------------+
```

```ca65
; --- Fortress Gatehouse & Crenellated Rampart 2x2 Excerpt ---
; Row j=0: Left Battlement Walkway (0,0) at h=4 and Gatehouse Crown (1,0) at h=4
def_cell 4, PRIM_FLAT, TEX_FLAGSTONE, TEX_CASTLE_ASHLAR, TEX_MERLON_PARAPET, PANEL_S, 4, 0
def_cell 4, PRIM_FLAT, TEX_FLAGSTONE, TEX_GATE_ARCH_64,  TEX_MERLON_PARAPET, PANEL_S, 4, 4

; Row j=1: Courtyard Flagstones (0,1) at h=0 and Gatehouse Threshold (1,1) at h=0
def_cell 0, PRIM_FLAT, TEX_COBBLE,    TEX_STONE_BASE,    TEX_NONE,           PANEL_NONE, 0, 0
def_cell 0, PRIM_FLAT, TEX_COBBLE,    TEX_STONE_BASE,    TEX_IRON_GRATE_2H,  (PANEL_N | PANEL_TALL_2H), 0, 0
```

---

### 5.5 Scenario 5: Dense Forest & Overgrown Ruins (*Araguay Woods / Nelveska Temple*)

**Visual Design**: Mossy forest floor (`PRIM_FLAT`) interspersed with ancient fluted stone columns and gnarled oak trunks (`PRIM_PILLAR` $[8..24] \times [8..24]$) topped or surrounded by lush canopy/fern cross-billboards (`PRIM_FOLIAGE_CROSS`).

```
       \  |  /
      -- (+) --       <- Upper Canopy Cell or Bush: PRIM_FOLIAGE_CROSS (impassable)
       /  |  \
       +-----+
       |Trunk|        <- Ancient Tree Trunk / Ruin Column: PRIM_PILLAR (+2h inset [8..24])
    +--+     +--+
   /   +-----+   \    <- Mossy Forest Floor (top_tex_id = TEX_FOREST_MOSS)
  +---------------+
```

```ca65
; --- Araguay Woods & Ruined Temple Pillars 2x2 Excerpt ---
; Row j=0: Ancient Oak Trunk (0,0) at h=1 and Dense Fern Thicket (1,0) at h=1 (no unit entry)
def_cell 1, PRIM_PILLAR,        TEX_FOREST_MOSS, TEX_BARK_TRUNK,  TEX_NONE,         PANEL_NONE, 1, 0
def_cell 1, PRIM_FOLIAGE_CROSS, TEX_FOREST_MOSS, TEX_DIRT_LOAM,   TEX_FERN_CANOPY,  PANEL_NONE, 1, 1

; Row j=1: Broken Ruin Column (0,1) at h=2 and Overgrown Stepping Stones (1,1) at h=1
def_cell 2, PRIM_PILLAR,        TEX_MARBLE_CRACK, TEX_FLUTED_COL, TEX_IVY_TRIM,     PANEL_S,    2, 1
def_cell 1, PRIM_FLAT,          TEX_MOSS_PAVING,  TEX_DIRT_LOAM,  TEX_NONE,         PANEL_NONE, 1, 1
```

---

### 5.6 Scenario 6: Underground Vault / Cathedral Interior (*Orbonne Monastery*)

**Visual Design**: Checkered marble nave floor (`PRIM_FLAT` at `h=1`), raised sanctuary altar (`h=3`) accessed via ceremonial stone steps (`PRIM_STAIRS`), flanking vaulted colonnades (`PRIM_PILLAR`), and tall $2\text{h}$ stained-glass / wrought-iron choir screens (`PANEL_N | PANEL_W | PANEL_TALL_2H`) along the back perimeter walls.

```
   +---------------+---------------+
   | [Stained      | [Stained      | <- 2h Tall Back Edge Panels (PANEL_N | PANEL_TALL_2H)
   |  Glass 2h]    |  Glass 2h]    |    drawn in Step 2 (Back Edge Panels) behind floor/units
   +---------------+---------------+
  / Sanctuary h=3 /   Pillar h=3  /
 +---------------+---------------+
 |  Ceremonial   | Checkered     |
 |  Stairs (+2h) | Marble Nave   |
 +---------------+---------------+
```

```ca65
; --- Orbonne Monastery Nave & Sanctuary 2x2 Excerpt ---
; Row j=0: Raised Sanctuary Altar (0,0) at h=3 with 2h Stained Glass & Colonnade Pillar (1,0) at h=3
def_cell 3, PRIM_FLAT,   TEX_ALTAR_CARPET, TEX_CARVED_STONE, TEX_STAINED_GLASS, (PANEL_N | PANEL_W | PANEL_TALL_2H), 2, 3
def_cell 3, PRIM_PILLAR, TEX_MARBLE_CHECK, TEX_GOTHIC_COL,   TEX_IRON_SCREEN,   (PANEL_N | PANEL_E | PANEL_TALL_2H), 2, 3

; Row j=1: Sanctuary Steps (0,1) rising h=1 -> h=3 and Checkered Nave Floor (1,1) at h=1
def_cell 1, (PRIM_STAIRS | ROT_0), TEX_ALTAR_CARPET, TEX_MARBLE_RISER, TEX_STONE_BALUSTER, PANEL_W, 1, 1
def_cell 1, PRIM_FLAT,             TEX_MARBLE_CHECK, TEX_CRYPT_WALL,   TEX_NONE,           PANEL_NONE, 1, 1
```
