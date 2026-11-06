# Project AGENTS Guide: `snes-sfx-demo` Workspace

This document provides subproject layout and tooling pointers for `snes-sfx-demo`. For workspace-wide architecture, FX3 hardware invariants, and mandatory MCP tool routing, see root [`../AGENTS.md`](../AGENTS.md) and [`../.agents/rules/sfx-assembly-rules.md`](../.agents/rules/sfx-assembly-rules.md).

---

## 1. Subprojects Architecture

1. **`libSFX`** (`libSFX/`):
   - SNES bare-metal SDK and development framework (bootstrapper, header creation, memory maps, NMI/VBLANK handlers, SMP runtime).
   - Bundles the CC65 toolchain binaries: `ca65`, `ld65`, and `superfamicheck`.

2. **`X-GSU`** (`X-GSU/` — see [`X-GSU/AGENTS.md`](X-GSU/AGENTS.md)):
   - High-level `ca65` macro DSL (`function`, `call`, `return`, `stack`, `control`) and 3D fixed-point math/rasterization libraries (`IsoEngine/`, `gsu_maths/`, `rnc/`, `tests/`).

3. **`SpriteScale`** (`SpriteScale/`):
   - SuperFX polygon rasterization and sprite scaling demo.

4. **`edge-table`** (`edge-table/` and `docs/edgeTable.txt`):
   - Dynamic scanline edge-table architecture (160 row buckets, front-to-back occlusion clipping, and affine texture stepping).

5. **`build_tools/texture-packer`** (`build_tools/texture-packer/`):
   - Kotlin/Compose Desktop graphical texture atlas packer and CLI (`../tools/texture-packer.sh`) backing the `sfx_pack_textures` MCP tool.

---

## 2. SuperFX (FX3) Hardware & Assembly Rules

All SuperFX assembly and macro code in `snes-sfx-demo` is governed by the canonical rules in [`../.agents/rules/sfx-assembly-rules.md`](../.agents/rules/sfx-assembly-rules.md):
- **FX3 Invariants**: No hardware `MERGE` instruction (see `condensed_lmult` in [`X-GSU/gsu_maths/gsu_vector.i`](X-GSU/gsu_maths/gsu_vector.i)), 16-bit word alignment on `ldw`/`stw` (`GSURAM` requires `align = $2` in `Map.cfg`), dual `rpix` pixel cache flush, and 8-NOP pipeline settling before `stop`.
- **Modal Prefixes**: `with`, `to`, `from` apply to the single immediately following instruction only; never place a modal prefix before `move` (`moves`, `moveb`, `movew`).
- **Instruction Cache**: 512-byte on-chip instruction cache (`cache; move r13, r15`); never place `cache` inside loops or helper subroutines.

---

## 3. MCP Tools, Testing & Skills

Always prioritize the workspace MCP servers over raw shell commands or `grep` (see root [`../AGENTS.md`](../AGENTS.md) §4):

### `retro-superfx_mesen` MCP Server (Emulation, Testing & Symbols)
- **`run_sfx_test`**: Compile and headlessly run an `X-GSU` unit test in Mesen CE (automatically syncs `test.lua` symbol addresses and skips `-- @sfx-test status=wip` / `template` tests).
- **`assert_sfx_math`**: Inject input parameters into GSURAM/registers and assert mathematical outputs.
- **`capture_sfx_render`**: Capture headless framebuffer PNGs (`IsoEngine`, `SpriteScale`, unit tests) for visual inspection via `read_file`.
- **`profile_sfx_execution`**: Profile GSU cycle counts, function/label hotspots, cache residency, and VBlank FPS.
- **`sfx_resolve_address`**: Resolve symbol <-> linker address, nearest label deltas, and memory ranges from `.dbg` and `.cpu.sym`.

### `retro-superfx_lsp` MCP Server (Static Analysis, Code Navigation & Atlases)
- **`sfx_audit_diagnostics`**: Validate block structure (`function`/`endfunction`, `for`/`endfor`), FX3 hardware invariants, modal lifetimes, and stack depth (`Δ_SP == 0`).
- **`sfx_lookup_symbol`** / **`sfx_find_references`**: Find symbol definitions, doc comments (In/Out/Clobbers), and usages across `.s`, `.sgs`, `.i`, and `.inc` files.
- **`sfx_expand_macro`** / **`sfx_analyze_registers`**: Inspect expanded X-GSU macro streams and Chaitin-Briggs register allocation.
- **`sfx_pack_textures`**: Pack, update, or validate `.sfxproj` texture atlases and companion `.bin`, `.pal`, `.i`, and `_atlas.png` files.

### Relevant Root Skills (`../.agents/skills/`)
- [`create-gsu-test`](../.agents/skills/create-gsu-test/SKILL.md): Scaffold and verify new unit tests from `X-GSU/tests/test_template`.
- [`run-gsu-test`](../.agents/skills/run-gsu-test/SKILL.md) & [`sfx-test-runner`](../.agents/skills/sfx-test-runner/SKILL.md): Run single tests or the full suite (`../tools/run-sfx-test.sh [all]`).
- [`sfx-macro-language`](../.agents/skills/sfx-macro-language/SKILL.md): Reference for the X-GSU macro DSL.
- [`texture-atlas`](../.agents/skills/texture-atlas/SKILL.md): Author and pack `.sfxproj` texture atlases.

---

## 4. Technical Documentation References

- [FX3 Specifications](../.agents/skills/create-gsu-test/references/fx3_specifications.md): Memory maps, clock speeds, simultaneous bus access, and MERGE workaround.
- [SuperFX Instruction Set](../.agents/skills/create-gsu-test/references/superfx_instruction_set.md): Complete opcode matrix, flag behaviors, prefix registers, and machine cycles.
- [SuperFX Guide](../.agents/skills/create-gsu-test/references/superfx_guide.md): Hardware register map, bus contention, and pipeline settling requirements.
- [Mesen CE Lua API Guide](../.agents/skills/create-gsu-test/references/mesen_lua_api.md): Execution callbacks (`emu.callbackType.exec`), GSU work RAM reads (`emu.readWord`), and exit codes (`emu.stop(0)`).
