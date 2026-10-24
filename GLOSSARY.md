# GLOSSARY: SuperFX 3D & Isometric Engine

### Backface Culling
Hidden-surface removal technique that discards polygon faces oriented away from the camera before rasterization, determined by the screen-space winding order of their projected vertices.

### Face
A planar surface of a 3D mesh (such as one side of a cube) composed of one or more coplanar triangles sharing a surface orientation and color attribute.

### Frame Half
One of two vertical 128-pixel-wide screen regions (left half and right half) rendered sequentially by the coprocessor to compose a full 256-pixel-wide frame.

### Indexed Mesh
A 3D geometric representation that stores each unique vertex once in a vertex table and defines faces by referencing those vertices by index, separating vertex projection from face assembly.

### Isometric Camera
An orthographic camera rig with a fixed downward elevation pitch that orbits horizontally (yaw) around a target focal cell on the game board without perspective foreshortening.

### Projected Vertex Cache
The per-frame collection of 2D screen-space vertex coordinates computed during the first frame-half pass and reused during the second frame-half pass.

### Map Grid
The rectangular $N \times M$ array of Map Cells that defines a tactical battlefield.
_Avoid_: Game model, board, level mesh

### Map Cell
A single $(i, j)$ coordinate slot on the Map Grid holding a Base Elevation, a Shape Archetype, texture references, and Neighbor Skirt Drops.
_Avoid_: Tile, block, map square

### Base Elevation
The height (in Half-Block steps) of the solid, opaque vertical column beneath a Map Cell's Shape Archetype.
_Avoid_: Z-height, floor height, Y-offset

### Cell Skirt
The vertical side faces of a Map Cell's solid column that are exposed above adjacent Map Cells or at the outer perimeter of the Map Grid.
_Avoid_: Cliff wall, pillar side, drop face

### Shape Archetype
A canonical 3D surface template from a fixed pool (such as Flat, Wedge, Stairs, Liquid, Pillar, or Foliage Cross) projected once per camera yaw angle and stamped at a Map Cell's Base Elevation.
_Avoid_: Prop, model object, tile model

### Edge Panel
A double-sided vertical quad rising above a Map Cell's Base Elevation along one of its four compass edges (North, East, South, or West) to form parapets, railings, awnings, or wall facades.
_Avoid_: Thin wall, decal, billboard wall

### Canonical Lattice
The fixed set of 3D sub-cell reference points (corners, midpoints, inset ring, and elevation steps) projected once per camera yaw angle using integer basis vector shifts and additions to guarantee watertight geometry across adjacent Map Cells.
_Avoid_: Local mesh, unit cube vertices

### Scanline Trapezoid
A horizontal-top, horizontal-bottom screen-space slice of a visible Shape Archetype face with pre-solved left/right edge slopes and affine UV gradients ready for direct scanline stamping.
_Avoid_: Cached triangle, span entry

### Target Cell
The focal coordinate on the isometric game board around which the camera orbits and at which scene geometry is anchored.

### Destination Parameter Seam
An interface convention for vector and arithmetic operations where callers supply an explicit memory address (`dst`) to receive results, enabling zero-copy pipelines, in-place mutation, and call-chaining without hidden global buffers.

### Stack-Allocated Frame
Temporary data storage dynamically allocated on `gsu_stack_ram` via `gsu_stack_alloc` / `gsu_stack_free` using register `R10` (`stackPointer`), replacing singleton global RAM variables.

### Winding Order
The clockwise or counter-clockwise sequence of a face's projected 2D vertices on screen, whose signed area indicates whether the face is front-facing or back-facing relative to the camera.

### Source Texture
An individual power-of-two bitmap graphic imported into a texture project to be quantized, edited, and positioned within a Texture Atlas.
_Avoid_: Imported tile, bitmap graphic, source image

### Texture Atlas
The composite power-of-two graphics buffer into which multiple Source Textures are positioned and merged for runtime texture mapping.
_Avoid_: Binary graphics file, texture map

### Texel
A single pixel element within a Source Texture or Texture Atlas representing a 4-bit palette color index (`0` for transparent, `1`–`15` for opaque colors).
_Avoid_: Tile pixel, byte pixel

### Atlas Index
The symbolic metadata manifest describing the Texture Atlas dimensions and each Source Texture's identifier, coordinates, dimensions, and byte offset for use by the engine.
_Avoid_: Index file, texture header


