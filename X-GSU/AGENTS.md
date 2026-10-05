# X-GSU Agent Reference Manual

This document provides developer and agent guidance for the **`X-GSU`** library within the `snes-sfx-demo` project.

---

## 1. Subproject Architecture & Directory Structure

`X-GSU` contains core SuperFX 3 (FX3) mathematics, vector/matrix operations, camera transformations, and compression libraries.

```
X-GSU/
├── common/
│   ├── control.i        # Control flow macros (if_lt, if_gt, if_eq, for/endfor)
│   ├── function.i       # Function entry/exit macros (function, return, endfunction, call)
│   ├── stack.i          # Software stack implementation using R10 (init_stack, gsu_stack_push, gsu_stack_pop)
│   ├── structs.i        # Vector3, Vector4, Matrix4, Camera, and Huffman data structures
│   ├── util.i           # Utility macros (rom_to_ram, fixed-point helpers)
│   └── var.i            # Global GSURAM variables and buffers
├── gsu_maths/
│   ├── gsu_camera.i     # camera_lookAt (builds 4x4 view matrix from eye, target, up vectors)
│   ├── gsu_recip.i      # reciprocal (16-bit 0.16 fixed-point reciprocal via table + Newton-Raphson)
│   ├── gsu_sqrt.i       # gsu_sqrt32 (32-bit integer square root using iterative subtraction)
│   ├── gsu_trig.i       # Sine/cosine lookup tables and trigonometry helpers
│   └── gsu_vector.i     # 3D vector arithmetic (add, subtract, negate, dot, cross, length, normalize, transform)
├── rnc/
│   └── gsu_decompress.i # Rob Northen Compression (RNC Method 1/2) decompressor
└── tests/               # Automated unit tests running on Mesen CE
```

---

## 2. Mathematical Functions & Calling Conventions

All functions follow the SuperFX calling convention:
- **`R0`**: Primary input address pointer
- **`R1` / `R2` / `R3`**: Secondary input parameters / secondary address pointers
- **`R3`**: Output scalar or pointer to output structure in `GSURAM`
- **`R10`**: Reserved for software stack pointer
- **`R11`**: Return address set by `call`

| Function | Source File | Input Registers | Output | GSURAM Output Symbol | Description |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `gsu_sqrt32` | `gsu_maths/gsu_sqrt.i` | `R0` = Radicand low 16-bit, `R1` = Radicand high 16-bit | `R3` = Integer $\lfloor\sqrt{X}\rfloor$ | Register `R3` | 32-bit square root |
| `reciprocal` | `gsu_maths/gsu_recip.i` | `R0` = Input scalar | `R3` = 0.16 fixed reciprocal | Register `R3` | 16-bit reciprocal ($1/x$) |
| `vector3_add` | `gsu_maths/gsu_vector.i` | `R0` = `&A`, `R1` = `&B` | `R3` = `&VECTOR_ADD_OUT` | `VECTOR_ADD_OUT` | 3D vector addition |
| `vector3_subtract` | `gsu_maths/gsu_vector.i` | `R0` = `&A`, `R3` = `&B` | `R3` = `&VECTOR_SUBTRACT_OUT` | `VECTOR_SUBTRACT_OUT` | 3D vector subtraction ($A - B$) |
| `vector3_negate` | `gsu_maths/gsu_vector.i` | `R0` = `&in` | `R3` = `&VECTOR_NEGATE_OUT` | `VECTOR_NEGATE_OUT` | 3D vector negation ($-A$) |
| `vector3_dot` | `gsu_maths/gsu_vector.i` | `R0` = `&A`, `R1` = `&B` | `R3` = Signed Q8.8 dot product | Register `R3` | 3D vector dot product ($A \cdot B$) |
| `vector3_cross` | `gsu_maths/gsu_vector.i` | `R0` = `&A`, `R1` = `&B` | `R3` = `&VECTOR_CROSS_OUT` | `VECTOR_CROSS_OUT` | 3D vector cross product ($A \times B$) |
| `vector3_length` | `gsu_maths/gsu_vector.i` | `R0` = `&in` | `R3` = Length as unsigned 16-bit | Register `R3` | Euclidean magnitude $\sqrt{x^2+y^2+z^2}$ |
| `vector3_normalize` | `gsu_maths/gsu_vector.i` | `R0` = `&in` | `R3` = `&vector_normalize_out` | `vector_normalize_out` | Normalizes vector to unit length |
| `vector3_copy` | `gsu_maths/gsu_vector.i` | `R0` = `&src`, `R2` = `&dest` | `R3` = `&dest` | Destination buffer | Copies 3 words ($x, y, z$) |
| `vector3_transform` | `gsu_maths/gsu_vector.i` | `R0` = `&matrix4`, `R1` = `&vector3` | `R3` = `&VECTOR_TRANSFORM_OUT` | `VECTOR_TRANSFORM_OUT` | Multiplies 3D vector by 4x4 matrix |
| `camera_lookAt` | `gsu_maths/gsu_camera.i` | `R0` = `&camera` | `R3` = `&LOOKAT_MATRIX` | `LOOKAT_MATRIX` | Generates 4x4 LookAt view matrix |

---

## 3. Critical Architectural Gotchas & Bug Solutions

1. **`condensed_lmult St, D` and `R4`**:
   - SuperFX hardware `lmult` unconditionally deposits the low 16 bits of the 32-bit product into register `R4`.
   - `condensed_lmult` extracts and packs the Q8.8 result by reading `R4`.
   - **Never pass `R4` as the destination register `D`**. Doing so causes `lmult` to overwrite `D`, corrupting the packing operation.
2. **Explicit `with Rn` on Pointer Adjustments**:
   - Arithmetic operations like `add #2` or `sub #4` execute using the currently active source/destination and immediately reset `Sreg`/`Dreg` back to `R0`.
   - Never write a bare `add #2` intended to increment a register other than `R0`. Always prefix with `with Rn` (e.g. `with r0; add #2`).
3. **Loop Stack Invariance**:
   - `for ... endfor` macros push loop registers `r13` and `r12` onto the stack and expect them at the stack top on `endfor`.
   - Never push/pop temporary variables to the stack inside loops without restoring them before `endfor`.
4. **Memory Settling Delay**:
   - SuperFX RAM writes are pipelined. Insert 8 `nop` instructions after calls before halting at `test_stop` to ensure writes are fully committed before Lua inspection.
5. **Linker Word Alignment**:
   - Ensure `Map.cfg` defines `GSURAM: load = SRAM, type = bss, define = yes, align = $2;`.

---

## 4. Test Suite Reference

All functions are verified by automated tests in `tests/`:
```bash
# Run individual test:
./.agents/skills/create-gsu-test/scripts/run_test.sh tests/<test_name> 10

# Run complete test suite:
for t in rom_to_ram sqrt reciprocal length normalize lookAt transform \
         vector3_add vector3_subtract vector3_negate vector3_dot vector3_cross vector3_copy; do
    ./.agents/skills/create-gsu-test/scripts/run_test.sh "tests/$t" 10 || exit 1
done
```

All 13 test suites pass with zero errors in headless Mesen CE runner mode.
