# SNES SuperFX Demo & Development Framework (`snes-sfx-demo`)

A comprehensive Super Nintendo Entertainment System (SNES) homebrew codebase, 3D graphics testbed, and development framework targeting the **SuperFX (GSU / FX3)** RISC coprocessor.

[![Demo Video](https://img.youtube.com/vi/H3NiUNPcn8M/0.jpg)](https://youtu.be/H3NiUNPcn8M)  
*Watch the SuperFX demo running on real hardware / emulator: [https://youtu.be/H3NiUNPcn8M](https://youtu.be/H3NiUNPcn8M)*

---

## Architecture & Subprojects

This repository contains several interconnected components for bare-metal SNES and SuperFX development:

```
snes-sfx-demo/
├── libSFX/                  # Bare-metal SNES SDK and runtime
├── X-GSU/                   # High-level SuperFX macro language, 3D math & demos
│   ├── common/              # X-GSU ca65 macros (function, stack, loops, conditionals)
│   ├── gsu_maths/           # 16-bit fixed-point 3D vector, matrix & trig math
│   ├── IsoEngine/           # Interactive 3D isometric camera & mesh rendering engine
│   ├── rnc/                 # Rob Northen Compression (RNC) decompressor (Work In Progress)
│   └── tests/               # Automated unit test suite run via headless Mesen CE
├── SpriteScale/             # SuperFX polygon rasterization demo & scaling engine
├── edge-table/              # Scanline edge-table specification & span clipping architecture
├── build_tools/             # Tools for GSU Work RAM symbol extraction
└── docs/                    # Hardware references and rasterizer documentation
```

### Subproject Breakdown

1. **`libSFX`** (`/libSFX`):
   - Modular SNES bare-metal SDK and development runtime.
   - Provides runtime bootstrapper, ROM header creation, memory mapping (`Map.cfg`, `libSFX.cfg`), interrupt handlers (NMI/VBLANK), and SMP sound processor runtime.
   - Bundles precompiled `cc65` toolchain binaries: `ca65` (assembler), `ld65` (linker), and `superfamicheck` (ROM validation and checksum repair) in `libSFX/tools/cc65/bin/`.

2. **`X-GSU`** (`/X-GSU`):
   - High-level macro language DSL and fixed-point math library for the SuperFX coprocessor.
   - **Math Routines** (`gsu_maths/`):
     - 16-bit 3D vector arithmetic (`vector3_add`, `vector3_subtract`, `vector3_negate`, `vector3_dot`, `vector3_cross`, `vector3_length`, `normalize`, `vector3_copy`).
     - Fixed-point 3D vertex and matrix transformations (`vector3_transform`, `camera_lookAt`).
     - Fast 32-bit square root (`gsu_sqrt32`), 16-bit reciprocal (`reciprocal`), and sine/cosine lookup tables (`trig`).
   - **Decompression** (`rnc/`):
     - High-performance SuperFX implementation of Rob Northen Compression (RNC / Huffman) decompression.

3. **`IsoEngine`** (`/X-GSU/IsoEngine`):
   - Real-time 3D isometric camera and polygon mesh rendering engine running on the SuperFX.
   - Features dynamic 3D camera orbit/pitch (isometric camera rig), real-time 3D vertex projection, backface culling, 2-pass frame-half rendering, ground grid, and SNES joypad controls.

4. **`SpriteScale`** (`/SpriteScale`):
   - SuperFX polygon rasterization demo and sprite scaling engine.
   - Implements dynamic scanline edge-table rasterization techniques.

5. **`edge-table`** (`/edge-table` and `/docs/edgeTable.txt`):
   - Architecture and specification for dynamic scanline edge-table rendering.
   - Organizes scanlines into 160 row buckets, managing span insertion, front-to-back occlusion clipping, and affine texture stepping.

6. **`X-GSU/tests`** (`/X-GSU/tests`):
   - Comprehensive headless automated unit test suite executed via Mesen CE with Lua verification scripts.

---

## Hardware Target: SuperFX 3 (FX3)

The project targets the **SuperFX 3 (FX3)**, a 21.47 MHz RISC coprocessor revision:

### Register Calling Conventions

| Register | Hardware / Architectural Role | Calling & Framework Conventions |
| :--- | :--- | :--- |
| `R0` | Default source (`Sreg`) & destination (`Dreg`) | Primary input parameter / pointer. Reset as target by arithmetic ops. |
| `R1` – `R3` | General-purpose registers | Secondary input parameters, scratch registers. `R3` holds function return values. |
| `R4` | Hardware `LMULT` lower 16 bits of 32-bit product | Low product output. Do **not** use as destination register in `condensed_lmult`. |
| `R5` | General-purpose register | Scratch register. |
| `R6` | Multiplicand register | Multiplicand for hardware `MULT` and `LMULT`. |
| `R7` – `R9` | General-purpose registers | Math and vertex calculation scratch registers. |
| `R10` | General-purpose register | **Dedicated software stack pointer** (`init_stack`, `gsu_stack_push`, `gsu_stack_pop`). |
| `R11` | Link register | Return address for subroutine calls (`call`, `return`). |
| `R12` | Loop counter register | Hardware `loop` step counter. |
| `R13` | Loop target address register | Hardware `loop` branch target address. |
| `R14` | ROM pointer register | Hardware prefetch buffer pointer (`ROMB`, `GETB`, `GETC`). |
| `R15` | Program Counter (`PC`) | Executing instruction address. |

### Critical Hardware Invariants

- **No Hardware `MERGE` on FX3**: The original SuperFX `ALT2 + MERGE` instruction is not implemented in FX3 hardware. Bit-packing sequences must use `hib`, `lob`, `swap`, and `or` (see the `condensed_lmult` macro in `X-GSU/gsu_maths/gsu_vector.i`).
- **Simultaneous Bus Access**: The FX3 coprocessor supports concurrent bus access, allowing the SNES 65816 CPU and the GSU coprocessor to access memory concurrently without stalling when banks are configured appropriately.
- **8-NOP Pipeline Settling**: SuperFX Work RAM writes are pipelined asynchronously. Insert 8 consecutive `nop` instructions before halting (`stop`) or reading memory in emulator hooks.
- **16-Bit Word Alignment**: All 16-bit word operations (`ldw`/`stw`) must access 16-bit even-aligned memory addresses.
- **Modal Prefix Instruction Scope**: `with`, `to`, and `from` modify registers for the **single immediately following instruction only**. Subsequent arithmetic instructions reset `Sreg` and `Dreg` back to `R0`.

---

## The X-GSU Macro DSL

The `X-GSU/common/` directory provides high-level `ca65` macros that simplify writing structured SuperFX assembly:

### 1. Function Scoping (`function.i`)
```gsu
function calculate_hypotenuse
    ; R0: input X, R1: input Y
    ; Automatically pushes R11 (link register) to the stack
    ...
    return   ; Pops return address into R15 (PC) with nop in delay slot
endfunction
```

Subroutines are invoked using:
```gsu
call calculate_hypotenuse
```

### 2. High-Level Register Variables (`sfx-optimizer` support)
When lowering through `sfx-optimizer`, variables can be declared symbolically and mapped to registers using graph-coloring register allocation:
```gsu
register temp_x, temp_y
register result = r3    ; Pre-colored constraint
```

### 3. Stack Operations (`stack.i` — `R10`)
```gsu
init_stack              ; Sets R10 to gsu_stack_ram (512-byte buffer in GSURAM)
gsu_stack_push r1       ; stw (r10); inc r10; inc r10
gsu_stack_pop  r1       ; dec r10; dec r10; to r1; ldw (r10)
```

### 4. Hardware Loops & Conditionals
```gsu
for 16                  ; Backs up R12/R13 to stack, sets loop counter
    ; Loop body (R12/R13 preserved)
endfor                  ; loop; nop; restoreloop

if_lt r1, #10, bra_label ; Signed comparison branch
```

---

## Interactive Demos

### 1. `IsoEngine` (3D Isometric Scene)
An interactive 3D isometric engine rendering a 3D cube and ground grid in real-time.

```bash
# Build IsoEngine ROM
make -C X-GSU/IsoEngine
```
Produces `X-GSU/IsoEngine/SuperFX.sfc`.

#### Joypad Controls (Player 1)
- **`L` / `R`**: Orbit/rotate isometric camera yaw around the target cell.
- **`D-Pad Up` / `Down`**: Pan the camera target along the vertical screen axis.
- **`D-Pad Left` / `Right`**: Pan the camera target along the horizontal screen axis.

### 2. `SpriteScale` (Polygon & Scanline Demo)
SuperFX polygon rasterizer and scanline edge-table scaling demo.

```bash
# Build SpriteScale ROM
make -C SpriteScale
```
Produces `SpriteScale/SuperFX.sfc`.

---

## Automated Unit Testing

Unit tests run headlessly in **Mesen CE** using Lua breakpoints to validate memory and register outputs.

### Running Tests from Workspace Root
```bash
# Run a specific unit test
./tools/run-sfx-test.sh <test_name> [timeout_seconds]

# Examples:
./tools/run-sfx-test.sh vector3_add 10
./tools/run-sfx-test.sh lookAt 10
./tools/run-sfx-test.sh sqrt 10
./tools/run-sfx-test.sh iso_camera 10
```

### Available Tests (`X-GSU/tests/`)
- **Vector Math**: `vector3_add`, `vector3_subtract`, `vector3_negate`, `vector3_dot`, `vector3_cross`, `vector3_length`, `normalize`, `vector3_copy`
- **Matrix & Camera**: `transform`, `lookAt`, `iso_camera`
- **Arithmetic & Tables**: `sqrt`, `reciprocal`, `trig`
- **Compression**: `buffer_rnc`, `decode_rnc`, `hufftable_rnc`
- **Memory & System**: `rom_to_ram`

---

## Build Prerequisites

1. **GNU Make**: Required for building ROMs and running tests.
2. **Python 3.10+**: Used for symbol map synchronization (`extract_syms.py`).
3. **Mesen CE**: SNES emulator required for running unit tests headlessly (configured on system `PATH` or at `/home/summers/Programs/Mesen`).
4. **Assembler / Linker**: Precompiled `ca65` and `ld65` are included in `libSFX/tools/cc65/bin/`.
5. **Java 26+ (Optional)**: Required if compiling `.sgs` files via `sfx-optimizer`.

---

## References & Acknowledgments

- **libSFX**: SNES development SDK by David Lindecrantz.
- **Randy Linden / DOOM-FX**: [DOOM-FX SuperFX Documentation](https://github.com/RandalLinden/DOOM-FX/tree/master/docs) and [snes-fx3](https://github.com/LimitedRunGames-Tech/snes-fx3).
- **Ultra Star Fox / Sunlitspace542**: FX3 `MERGE` workaround sequence.

[![Demo Video](https://img.youtube.com/vi/H3NiUNPcn8M/0.jpg)](https://youtu.be/H3NiUNPcn8M)  
*Watch the SuperFX demo running on real hardware / emulator: [https://youtu.be/H3NiUNPcn8M](https://youtu.be/H3NiUNPcn8M)*

---

## Architecture & Subprojects

This repository contains several interconnected components for bare-metal SNES and SuperFX development:

```
snes-sfx-demo/
├── libSFX/                  # Bare-metal SNES SDK and runtime
├── X-GSU/                   # High-level SuperFX macro language, 3D math & demos
│   ├── common/              # X-GSU ca65 macros (function, stack, loops, conditionals)
│   ├── gsu_maths/           # 16-bit fixed-point 3D vector, matrix & trig math
│   ├── IsoEngine/           # Interactive 3D isometric camera & mesh rendering engine
│   ├── rnc/                 # Rob Northen Compression (RNC) decompressor
│   └── tests/               # Automated unit test suite run via headless Mesen CE
├── SpriteScale/             # SuperFX polygon rasterization demo & scaling engine
├── edge-table/              # Scanline edge-table specification & span clipping architecture
├── build_tools/             # Tools for GSU Work RAM symbol extraction
└── docs/                    # Hardware references and rasterizer documentation
```

### Subproject Breakdown

1. **`libSFX`** (`/libSFX`):
   - Modular SNES bare-metal SDK and development runtime.
   - Provides runtime bootstrapper, ROM header creation, memory mapping (`Map.cfg`, `libSFX.cfg`), interrupt handlers (NMI/VBLANK), and SMP sound processor runtime.
   - Bundles precompiled `cc65` toolchain binaries: `ca65` (assembler), `ld65` (linker), and `superfamicheck` (ROM validation and checksum repair) in `libSFX/tools/cc65/bin/`.

2. **`X-GSU`** (`/X-GSU`):
   - High-level macro language DSL and fixed-point math library for the SuperFX coprocessor.
   - **Math Routines** (`gsu_maths/`):
     - 16-bit 3D vector arithmetic (`vector3_add`, `vector3_subtract`, `vector3_negate`, `vector3_dot`, `vector3_cross`, `vector3_length`, `normalize`, `vector3_copy`).
     - Fixed-point 3D vertex and matrix transformations (`vector3_transform`, `camera_lookAt`).
     - Fast 32-bit square root (`gsu_sqrt32`), 16-bit reciprocal (`reciprocal`), and sine/cosine lookup tables (`trig`).
   - **Decompression** (`rnc/`):
     - High-performance SuperFX implementation of Rob Northen Compression (RNC / Huffman) decompression.

3. **`IsoEngine`** (`/X-GSU/IsoEngine`):
   - Real-time 3D isometric camera and polygon mesh rendering engine running on the SuperFX.
   - Features dynamic 3D camera orbit/pitch (isometric camera rig), real-time 3D vertex projection, backface culling, 2-pass frame-half rendering, ground grid, and SNES joypad controls.

4. **`SpriteScale`** (`/SpriteScale`):
   - SuperFX polygon rasterization demo and sprite scaling engine.
   - Implements dynamic scanline edge-table rasterization techniques.

5. **`edge-table`** (`/edge-table` and `/docs/edgeTable.txt`):
   - Architecture and specification for dynamic scanline edge-table rendering.
   - Organizes scanlines into 160 row buckets, managing span insertion, front-to-back occlusion clipping, and affine texture stepping.

6. **`X-GSU/tests`** (`/X-GSU/tests`):
   - Comprehensive headless automated unit test suite executed via Mesen CE with Lua verification scripts.

---

## Hardware Target: SuperFX 3 (FX3)

The project targets the **SuperFX 3 (FX3)**, a 21.47*4 MHz RISC coprocessor revision:

### Register Calling Conventions

| Register | Hardware / Architectural Role | Calling & Framework Conventions |
| :--- | :--- | :--- |
| `R0` | Default source (`Sreg`) & destination (`Dreg`) | Primary input parameter / pointer. Reset as target by arithmetic ops. |
| `R1` – `R3` | General-purpose registers | Secondary input parameters, scratch registers. `R3` holds function return values. |
| `R4` | Hardware `LMULT` lower 16 bits of 32-bit product | Low product output. Do **not** use as destination register in `condensed_lmult`. |
| `R5` | General-purpose register | Scratch register. |
| `R6` | Multiplicand register | Multiplicand for hardware `MULT` and `LMULT`. |
| `R7` – `R9` | General-purpose registers | Math and vertex calculation scratch registers. |
| `R10` | General-purpose register | **Dedicated software stack pointer** (`init_stack`, `gsu_stack_push`, `gsu_stack_pop`). |
| `R11` | Link register | Return address for subroutine calls (`call`, `return`). |
| `R12` | Loop counter register | Hardware `loop` step counter. |
| `R13` | Loop target address register | Hardware `loop` branch target address. |
| `R14` | ROM pointer register | Hardware prefetch buffer pointer (`ROMB`, `GETB`, `GETC`). |
| `R15` | Program Counter (`PC`) | Executing instruction address. |

### Critical Hardware Invariants

- **No Hardware `MERGE` on FX3**: The original SuperFX `ALT2 + MERGE` instruction is not implemented in FX3 hardware. Bit-packing sequences must use `hib`, `lob`, `swap`, and `or` (see the `condensed_lmult` macro in `X-GSU/gsu_maths/gsu_vector.i`).
- **Simultaneous Bus Access**: The FX3 coprocessor supports concurrent bus access, allowing the SNES 65816 CPU and the GSU coprocessor to access memory concurrently without stalling when banks are configured appropriately.
- **8-NOP Pipeline Settling**: SuperFX Work RAM writes are pipelined asynchronously. Insert 8 consecutive `nop` instructions before halting (`stop`) or reading memory in emulator hooks.
- **16-Bit Word Alignment**: All 16-bit word operations (`ldw`/`stw`) must access 16-bit even-aligned memory addresses.
- **Modal Prefix Instruction Scope**: `with`, `to`, and `from` modify registers for the **single immediately following instruction only**. Subsequent arithmetic instructions reset `Sreg` and `Dreg` back to `R0`.

---

## The X-GSU Macro DSL

The `X-GSU/common/` directory provides high-level `ca65` macros that simplify writing structured SuperFX assembly:

### 1. Function Scoping (`function.i`)
```gsu
function calculate_hypotenuse
    ; R0: input X, R1: input Y
    ; Automatically pushes R11 (link register) to the stack
    ...
    return   ; Pops return address into R15 (PC) with nop in delay slot
endfunction
```

Subroutines are invoked using:
```gsu
call calculate_hypotenuse
```

### 2. High-Level Register Variables (`sfx-optimizer` support)
When lowering through `sfx-optimizer`, variables can be declared symbolically and mapped to registers using graph-coloring register allocation:
```gsu
register temp_x, temp_y
register result = r3    ; Pre-colored constraint
```

### 3. Stack Operations (`stack.i` — `R10`)
```gsu
init_stack              ; Sets R10 to gsu_stack_ram (512-byte buffer in GSURAM)
gsu_stack_push r1       ; stw (r10); inc r10; inc r10
gsu_stack_pop  r1       ; dec r10; dec r10; to r1; ldw (r10)
```

### 4. Hardware Loops & Conditionals
```gsu
for 16                  ; Backs up R12/R13 to stack, sets loop counter
    ; Loop body (R12/R13 preserved)
endfor                  ; loop; nop; restoreloop

if_lt r1, #10, bra_label ; Signed comparison branch
```

---

## Interactive Demos

### 1. `IsoEngine` (3D Isometric Scene)
An interactive 3D isometric engine rendering a 3D cube and ground grid in real-time.

```bash
# Build IsoEngine ROM
make -C X-GSU/IsoEngine
```
Produces `X-GSU/IsoEngine/SuperFX.sfc`.

#### Joypad Controls (Player 1)
- **`L` / `R`**: Orbit/rotate isometric camera yaw around the target cell.
- **`D-Pad Up` / `Down`**: Pan the camera target along the vertical screen axis.
- **`D-Pad Left` / `Right`**: Pan the camera target along the horizontal screen axis.

### 2. `SpriteScale` (Polygon & Scanline Demo)
SuperFX polygon rasterizer and scanline edge-table scaling demo.

```bash
# Build SpriteScale ROM
make -C SpriteScale
```
Produces `SpriteScale/SuperFX.sfc`.

---

## Automated Unit Testing

Unit tests run headlessly in **Mesen CE** using Lua breakpoints to validate memory and register outputs.

### Running Tests from Workspace Root
```bash
# Run a specific unit test
./tools/run-sfx-test.sh <test_name> [timeout_seconds]

# Examples:
./tools/run-sfx-test.sh vector3_add 10
./tools/run-sfx-test.sh lookAt 10
./tools/run-sfx-test.sh sqrt 10
./tools/run-sfx-test.sh iso_camera 10
```

### Available Tests (`X-GSU/tests/`)
- **Vector Math**: `vector3_add`, `vector3_subtract`, `vector3_negate`, `vector3_dot`, `vector3_cross`, `vector3_length`, `normalize`, `vector3_copy`
- **Matrix & Camera**: `transform`, `lookAt`, `iso_camera`
- **Arithmetic & Tables**: `sqrt`, `reciprocal`, `trig`
- **Compression**: `buffer_rnc`, `decode_rnc`, `hufftable_rnc`
- **Memory & System**: `rom_to_ram`

---

## Build Prerequisites

1. **GNU Make**: Required for building ROMs and running tests.
2. **Python 3.10+**: Used for symbol map synchronization (`extract_syms.py`).
3. **Mesen CE**: SNES emulator required for running unit tests headlessly (configured on system `PATH` or at `/home/summers/Programs/Mesen`).
4. **Assembler / Linker**: Precompiled `ca65` and `ld65` are included in `libSFX/tools/cc65/bin/`.
5. **Java 26+ (Optional)**: Required if compiling `.sgs` files via `sfx-optimizer`.

---

## References & Acknowledgments

- **libSFX**: SNES development SDK by David Lindecrantz.
- **Randy Linden / DOOM-FX**: [DOOM-FX SuperFX Documentation](https://github.com/RandalLinden/DOOM-FX/tree/master/docs) and [snes-fx3](https://github.com/LimitedRunGames-Tech/snes-fx3).
- **Ultra Star Fox / Sunlitspace542**: FX3 `MERGE` workaround sequence.

