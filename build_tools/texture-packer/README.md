# SuperFX Texture Atlas Packer

A graphical desktop tool built with **Compose Multiplatform Desktop** and **Kotlin 2.4.20** on **Java 26** for converting, laying out, editing, and packing bitmap graphics for the SuperFX (GSU / FX3) RISC coprocessor and `IsoEngine`.

---

## Features

- **Texture Atlas Generation (`.bin`)**:
  - Independent power-of-two dimensions from $16\times 16$ to $256\times 256$.
  - Unpacked 1-byte-per-texel layout (`$00`–`$0F`) for zero-bit-unpacking `getc; plot` execution in SuperFX ROM/RAM.
- **SNES BGR555 Palette (`.pal`)**:
  - 16-color palette (32 bytes binary, 16 little-endian words).
  - Slot 0 is permanently locked as **Transparent** (`$0000`).
  - Opaque black is clamped to **`$0001`** (`R=1, G=0, B=0`) to prevent ambiguity with transparency.
  - Interactive 5-bit RGB sliders (`0..31`), hex word display, and slot unassignment with automatic remapping prompts.
- **ca65 Assembly Atlas Index (`.i`)**:
  - Exports `ATLAS_WIDTH`, `ATLAS_HEIGHT`, `ATLAS_SIZE_BYTES`, `ATLAS_STRIDE_SHIFT`.
  - Exports per-texture constants (`TEXTURE_<NAME>_ID`, `TEXTURE_<NAME>_OFFSET`, `TEXTURE_<NAME>_U_MASK`, `TEXTURE_<NAME>_V_MASK`, `TEXTURE_<NAME>_WIDTH_SHIFT`).
  - Emits the 4-word `texture_descriptor` struct and `TEXTURE_TABLE` for runtime indexing in `IsoEngine`.
- **Interactive Layout Canvas**:
  - Visual grid snapping (`4px`, `8px`, or `16px`).
  - Drag-and-drop texture placement with boundary clamping and collision detection (border highlights red on overlap, snaps back to previous valid position on invalid drop).
  - "Auto-Fit" and "Auto-Pack" (shelf packing) buttons.
- **Hex Preview Tab**:
  - Formatted hex dump of the Texture Atlas `.bin` and `.pal` binaries.
  - Highlights the byte offsets belonging to the currently selected Source Texture.
- **In-App Source Texture Editor Modal**:
  - Zoomable pixel-art canvas with checkerboard transparency.
  - Pencil, Flood Fill, Eyedropper tools, and Undo/Redo history.
  - Validation for legal ca65 symbol names (`[A-Za-z_][A-Za-z0-9_]*`).
- **Palette Conflict & Reduction Modal**:
  - Multi-texture preview gallery showing all imported textures live.
  - One-click **Auto-Snap to Existing Palette** (nearest Euclidean distance).
  - One-click **Global 15-Color Auto-Quantize** (Median-Cut algorithm across all textures).
  - Manual per-color slot remapping.
- **Project Persistence & State Management (`.sfxproj`)**:
  - Saves a portable JSON manifest embedding indexed pixels and layout coordinates.
  - Companion `.bin`, `.pal`, and `.i` files are automatically written alongside on save.
  - Unsaved changes tracking: window title reflects dirty state (`*`), and attempting to close the window or exit via `Ctrl+Q` prompts to Save & Exit, Discard & Exit, or Cancel.
  - Remembered import directory: the bitmap import file picker remembers the last selected directory across sessions via user preferences (defaults to platform default on first pick).
- **High-DPI & 4K Display Support**:
  - Automatic platform DPI detection (X11 `xrdb` `Xft.dpi`, GNOME/Wayland `monitors.xml`, `gsettings`, KDE `kdeglobals`, `GDK_SCALE`, `QT_SCALE_FACTOR`).
  - Pre-initialization of Java2D `sun.java2d.uiScale` for native, crisp 4K rendering on Linux X11/XWayland.
  - Interactive UI scaling via `View` menu presets (`100%`, `125%`, `150%`, `175%`, `200%`, `250%`) and shortcuts (`Ctrl +`, `Ctrl -`, `Ctrl 0`).
  - Density-aware canvas grid and drag-and-drop coordinate math.

---

## Building and Running

### Build and Test
```bash
mvn clean test
```

### Run Application
```bash
mvn exec:java
```
Or execute the packaged jar:
```bash
java -jar target/texture-packer-1.0-SNAPSHOT.jar
```

---

## Architecture References
- Domain Glossary: [`snes-sfx-demo/GLOSSARY.md`](../../GLOSSARY.md)
- Architecture Decision Record: [`snes-sfx-demo/docs/adr/0001-unpacked-2d-texture-atlas-and-bgr555-black.md`](../../docs/adr/0001-unpacked-2d-texture-atlas-and-bgr555-black.md)

