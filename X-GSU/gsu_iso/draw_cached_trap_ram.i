; ==============================================================================
; draw_cached_trap_ram.i - Bank-$71 RAM Affine Textured Trapezoid Rasterizer
;
; Thin include wrapper over `draw_cached_trap.i` that instantiates the Bank-$71
; `draw_cached_trap_ram` leaf via `_gsu_define_trap_rasterizer`:
;   - Entire function fits 100% within the 512-byte GSU instruction cache
;     (enforced at build time via `.assert (cbr_end - cbr_anchor) <= 512`)
;   - Reads pre-shifted 8-byte texture descriptors from `TEXTURE_TABLE_RAM` ($70)
;   - Switches `RAMBR = 1` ($71) solely around `@pixel_loop`, fetching 8-bit
;     row-major texels via `ldb (r11); color` from `$71:0000 - $71:7FFF`
;   - Immediately restores `RAMBR = 0` ($70) after `@pixel_loop` so stack frame
;     reads/writes (`r10`) and caller state always see Bank $70
; ==============================================================================

.ifndef __GSU_ISO_DRAW_CACHED_TRAP_RAM__
__GSU_ISO_DRAW_CACHED_TRAP_RAM__ = 1

_GSU_SKIP_ROM_TRAP_INST .set 1
.include "draw_cached_trap.i"
_GSU_SKIP_ROM_TRAP_INST .set 0

.segment "GSUCODE"

; ==============================================================================
; draw_cached_trap_ram
; Rasterizes a pre-compiled scanline trapezoid sampling texels from Bank $71.
;
; In:
;   trap_ptr    = r1: Pointer to cached_trap struct in Bank $70 GSURAM
;   anchor_x    = r3: Screen anchor X coordinate (integer pixels, signed)
;   anchor_y    = r4: Screen anchor Y coordinate (integer pixels, signed)
;   u_offset    = r5: World-space U offset in Q8.8
;   v_offset    = r6: World-space V offset in Q(16 - stride_shift).(stride_shift)
;   frame_half  = r7: Active frame half (0 = Pass 0 [0..127], 1 = Pass 1 [128..255])
;
; Postconditions:
;   - `RAMBR == 0` ($70) on all return paths
;   - Caller flushes dual 8-pixel plot caches via `rpix; rpix` at pass end
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
_gsu_define_trap_rasterizer draw_cached_trap_ram, 1
_gsu_define_trap_batch_rasterizer draw_cached_trap_ram_batch, 1

.endif ; __GSU_ISO_DRAW_CACHED_TRAP_RAM__
