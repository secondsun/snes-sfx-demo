# 65816 Gameplay Owner and GSU Pure Renderer Architecture

Status: accepted

Earlier demos (`IsoEngine`, `RamMapDemo`) had the SuperFX GSU read `GSU_JOYPAD` directly and drive camera state while the 65816 only handled VBlank DMA and Bank `$71` staging. For a full playable tactical RPG with menus, focus switching, exploration/battle state machines, BFS movement range, turn queues, and NPC AI, splitting game logic across both CPUs creates synchronization hazards and wastes GSU instruction cache and cycle budget.

We decided that the **65816 host CPU** owns all gameplay state, joypad input, state machine transitions, pathfinding, NPC AI, combat math, and SNES PPU UI (`BG3` + OAM), while the **SuperFX GSU** operates strictly as a pure 3D scene renderer. Each frame, the 65816 writes a compact **Scene Render Descriptor** into shared GSURAM `$70` (camera yaw/target, entity mask placements, and per-cell tactical highlights) and the GSU renders the `192×160` `BG1` viewport from Bank `$71` staged assets and the Mask ROM bank.

## Consequences

- **Clean testability**: Gameplay rules, BFS, combat math, and AI live in 65816 code decoupled from GSU rasterization, while GSU rendering can be tested independently with synthetic Scene Render Descriptors.
- **Viewport & VRAM savings**: Narrowing `BG1` to `192×160` on the left (`X = 0..191`) with a `64 px` right-hand Side Menu and `64 px` bottom Status/Message bar cuts Pass 1 DMA in half (`64×160`) and frees ~10 KB of VRAM for OAM character sheets and `BG3` UI tiles.
- **Backward compatibility**: Shared `gsu_iso` modules remain compatible with `IsoEngine` and `RamMapDemo` via conditional/opt-in hooks.
