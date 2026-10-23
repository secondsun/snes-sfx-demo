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


