; ==============================================================================
; IsoEngine Map Grid Format, Painter's Traversal & Dirty Archetype Renderer
; ==============================================================================
.ifndef ::__ISO_MAP_GRID_DEFINED__
::__ISO_MAP_GRID_DEFINED__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"
.include "../common/control.i"
.include "../common/structs.i"
.include "../common/var.i"
.include "../common/util.i"

.include "../gsu_maths/gsu_iso_camera.i"
.include "triangle/cached_trap.i"
.include "triangle/compile_face_traps_def.i"
.include "triangle/compile_face_traps.i"
.include "triangle/draw_cached_trap.i"

; ==============================================================================
; Binary Map Structures (ca65)
; ==============================================================================

.struct map_header
    cols            .byte   ; +0: Grid width in cells (4..12)
    rows            .byte   ; +1: Grid depth in cells (4..12)
    origin_x        .word   ; +2: Screen X anchor for cell (0,0,h=0) (signed 16-bit)
    origin_z        .word   ; +4: Screen Y anchor for cell (0,0,h=0) (signed 16-bit)
    reserved        .word   ; +6: Alignment padding ($0000)
.endstruct

.struct map_cell
    base_height     .byte   ; +0: Lowest opaque floor height (1h = 16 world units = 14px)
    archetype_id    .byte   ; +1: [7:6] rot (0..3), [5:0] shape archetype (0..63)
    top_tex_id      .byte   ; +2: Top/cap surface texture ID
    skirt_tex_id    .byte   ; +3: Skirt/cliff/riser/riverbed texture ID
    panel_tex_id    .byte   ; +4: Edge panel / foliage cutout texture ID
    panel_flags     .byte   ; +5: [3:0] W/S/E/N mask, [4] 2h tall flag, [7:5] reserved
    drop_ns         .byte   ; +6: Baked North/South skirt drop in 1h units
    drop_ew         .byte   ; +7: Baked East/West skirt drop in 1h units
.endstruct

; Helper authoring macro for map_cell
.macro def_cell h, arch, top_tex, skirt_tex, panel_tex, pflags, drop_ns, drop_ew
    .byte h, arch, top_tex, skirt_tex, panel_tex, pflags, drop_ns, drop_ew
.endmacro

; Archetype IDs (bits [5:0] of archetype_id)
PRIM_FLAT           = 0

.ifndef ATLAS_STRIDE_SHIFT
ATLAS_STRIDE_SHIFT  = 6
.endif
PRIM_WEDGE_STRAIGHT = 1
PRIM_WEDGE_OUTER    = 3
PRIM_WEDGE_INNER    = 5
PRIM_STAIRS         = 7
PRIM_LIQUID_SHALLOW = 8
PRIM_LIQUID_DEEP    = 9
PRIM_PILLAR         = 10
PRIM_FOLIAGE_CROSS  = 11

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

; ==============================================================================
; Pre-Compiled Archetype Trapezoid Cache Table
; ==============================================================================
.struct arch_traps_table
    flat_count      .word   ; +0:   Number of cached_traps for PRIM_FLAT (0..4)
    flat_traps      .res 4 * .sizeof(cached_trap) ; +2: 104 bytes
    skirt_ns_count  .word   ; +106: Number of cached_traps for ARCH_SKIRT_NS (0..4)
    skirt_ns_traps  .res 4 * .sizeof(cached_trap) ; +108: 104 bytes
    skirt_ew_count  .word   ; +212: Number of cached_traps for ARCH_SKIRT_EW (0..4)
    skirt_ew_traps  .res 4 * .sizeof(cached_trap) ; +214: 104 bytes
    bbox_xmin       .word   ; +318: Min X offset relative to anchor across corners
    bbox_xmax       .word   ; +320: Max X offset relative to anchor across corners
    bbox_ymin       .word   ; +322: Min Y offset relative to anchor across corners
    bbox_ymax       .word   ; +324: Max Y offset relative to anchor across corners
.endstruct

; ==============================================================================
; Dedicated GSURAM State & Working Frames
; ==============================================================================
.struct map_render_frame
    map_ptr         .word ; +0
    cam_ptr         .word ; +2
    basis_ptr       .word ; +4
    arch_traps_ptr  .word ; +6
    frame_half      .word ; +8
    debug_order_ptr .word ; +10
    debug_count     .word ; +12

    cols            .word ; +14
    rows            .word ; +16
    origin_x        .word ; +18
    origin_z        .word ; +20

    j_start         .word ; +22
    j_step          .word ; +24
    j_count         .word ; +26
    j_cur           .word ; +28
    j_rem           .word ; +30

    i_start         .word ; +32
    i_step          .word ; +34
    i_count         .word ; +36
    i_cur           .word ; +38
    i_rem           .word ; +40

    anchor_x        .word ; +42
    anchor_y        .word ; +44

    base_height     .word ; +46
    archetype_id    .word ; +48
    top_tex_id      .word ; +50
    skirt_tex_id    .word ; +52
    drop_ns         .word ; +54
    drop_ew         .word ; +56

    u_offset        .word ; +58
    v_offset        .word ; +60
    step_y          .word ; +62
.endstruct

.segment "GSURAM"
.align 2
gsu_map_render_frame:   .res .sizeof(map_render_frame)
gsu_map_face_def:       .res .sizeof(face_def)

.segment "GSUCODE"

; ==============================================================================
; map_grid_compile_archetypes
; Compares cam_ptr->yaw with cached_yaw_ptr.
; When unchanged: returns 0 immediately (zero compilation cycles).
; When changed:
;   - Updates cached_yaw_ptr
;   - Updates basis_ptr (Sx, Sz, Sy)
;   - Populates lattice_ptr (LATTICE_V2)
;   - Computes archetype screen bounding box relative to anchor
;   - Compiles PRIM_FLAT, ARCH_SKIRT_NS, and ARCH_SKIRT_EW into arch_traps_ptr
;   - Returns 1 (dirty recompiled)
; ==============================================================================
function map_grid_compile_archetypes cam_ptr, basis_ptr, lattice_ptr, arch_traps_ptr, cached_yaw_ptr : recompiled_flag
    register cam_ptr = r1, basis_ptr = r2, lattice_ptr = r3, arch_traps_ptr = r4, cached_yaw_ptr = r5

    ; 1. Load current yaw from cam_ptr (+0)
    ldw (r1)            ; r0 = cur_yaw
    move r6, r0         ; r6 = cur_yaw

    ; 2. Compare against cached_yaw
    ldw (r5)            ; r0 = cached_yaw
    from r6
    sub r0
    bne @do_recompile
    nop

    ; Not dirty: zero compilation cycles!
    iwt r3, #0
    return

@do_recompile:
    ; Update cached_yaw
    from r6
    stw (r5)

    ; Save inputs in frame
    iwt r7, #gsu_map_render_frame
    from r1
    stw (r7)            ; frame.map_ptr (reused for cam_ptr)
    inc r7
    inc r7
    from r2
    stw (r7)            ; basis_ptr
    inc r7
    inc r7
    from r3
    stw (r7)            ; lattice_ptr
    inc r7
    inc r7
    from r4
    stw (r7)            ; arch_traps_ptr

    ; Compute basis vectors (Sx, Sz, Sy) into basis_ptr
    call iso_compute_basis r6, r2

    ; Populate 28-point canonical lattice into lattice_ptr
    iwt r7, #gsu_map_render_frame
    inc r7
    inc r7
    ldw (r7)            ; r2 = basis_ptr
    move r1, r0
    inc r7
    inc r7
    ldw (r7)            ; r3 = lattice_ptr
    move r2, r0
    call iso_populate_lattice r1, r2

    ; --------------------------------------------------------------------------
    ; 3. Compute Archetype Screen Bounding Box:
    ;    Corners relative to anchor:
    ;      C0 = (0, 0)
    ;      C1 = Sx
    ;      C2 = Sx + Sz
    ;      C3 = Sz
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame
    inc r7
    inc r7
    ldw (r7)            ; r0 = basis_ptr
    move r7, r0

    to r8
    ldw (r7)            ; r8 = Sx.x
    inc r7
    inc r7
    to r9
    ldw (r7)            ; r9 = Sx.y
    inc r7
    inc r7
    to r11
    ldw (r7)            ; r11 = Sz.x
    inc r7
    inc r7
    to r12
    ldw (r7)            ; r12 = Sz.y

    ; C2.x = Sx.x + Sz.x, C2.y = Sx.y + Sz.y
    move r14, r8
    with r14
    add r11             ; r14 = C2.x
    move r6, r9
    with r6
    add r12             ; r6 = C2.y

    ; 1. min_x = min(0, Sx.x, Sz.x, C2.x)
    iwt r1, #0
    from r8
    sub r1
    bge :+
    nop
    move r1, r8
:
    from r11
    sub r1
    bge :+
    nop
    move r1, r11
:
    from r14
    sub r1
    bge :+
    nop
    move r1, r14
:

    ; 2. max_x = max(0, Sx.x, Sz.x, C2.x)
    iwt r2, #0
    from r8
    sub r2
    blt :+
    nop
    move r2, r8
:
    from r11
    sub r2
    blt :+
    nop
    move r2, r11
:
    from r14
    sub r2
    blt :+
    nop
    move r2, r14
:

    ; 3. min_y = min(0, Sx.y, Sz.y, C2.y)
    iwt r3, #0
    from r9
    sub r3
    bge :+
    nop
    move r3, r9
:
    from r12
    sub r3
    bge :+
    nop
    move r3, r12
:
    from r6
    sub r3
    bge :+
    nop
    move r3, r6
:

    ; 4. max_y = max(0, Sx.y, Sz.y, C2.y)
    iwt r4, #0
    from r9
    sub r4
    blt :+
    nop
    move r4, r9
:
    from r12
    sub r4
    blt :+
    nop
    move r4, r12
:
    from r6
    sub r4
    blt :+
    nop
    move r4, r6
:

    ; Store all 4 bounding box offsets into arch_traps_ptr + bbox_xmin
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r5, #arch_traps_table::bbox_xmin
    with r0
    add r5
    move r7, r0
    from r1
    stw (r7)            ; bbox_xmin
    inc r7
    inc r7
    from r2
    stw (r7)            ; bbox_xmax
    inc r7
    inc r7
    from r3
    stw (r7)            ; bbox_ymin
    inc r7
    inc r7
    from r4
    stw (r7)            ; bbox_ymax

    ; --------------------------------------------------------------------------
    ; 4. Compile PRIM_FLAT (Horizontal 32x32 quad at y=0)
    ;    Vertices: C0, C1, C2, C3 (Clockwise)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame
    ldw (r7)            ; r0 = cam_ptr
    inc r0
    inc r0
    move r8, r0
    to r11
    ldw (r8)            ; r11 = sin_yaw
    inc r8
    inc r8
    to r12
    ldw (r8)            ; r12 = cos_yaw

    iwt r7, #gsu_map_render_frame + 4
    to r14
    ldw (r7)            ; r14 = lattice_ptr

    iwt r7, #gsu_map_face_def

    iwt r0, #(FACE_DEF_FLAG_QUAD | FACE_DEF_FLAG_PTRS)
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    iwt r0, #UV_MODE_HORIZONTAL
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    iwt r0, #ATLAS_STRIDE_SHIFT
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7
    from r12
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r11
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0: pointer to LATTICE_C0 (lattice_ptr + 0), u=0, v=0
    from r14
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    ; V1: pointer to LATTICE_C1 (lattice_ptr + 4), u=32<<8, v=0
    move r0, r14
    iwt r6, #4
    with r0
    add r6
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    ; V2: pointer to LATTICE_C2 (lattice_ptr + 8), u=32<<8, v=32<<6 ($0800)
    move r0, r14
    iwt r6, #8
    with r0
    add r6
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v2
    inc r7
    inc r7

    ; V3: pointer to LATTICE_C3 (lattice_ptr + 12), u=0, v=32<<6 ($0800)
    move r0, r14
    iwt r6, #12
    with r0
    add r6
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(32 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Compile PRIM_FLAT into arch_traps_ptr + flat_traps (+2)
    iwt r1, #gsu_map_face_def
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    inc r0
    inc r0
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    move r7, r0
    from r3
    stw (r7)            ; store flat_count (+0)

    ; --------------------------------------------------------------------------
    ; 5. Compile ARCH_SKIRT_NS (Vertical 1h Skirt)
    ;    uv_mode = UV_MODE_WALL_NS (1)
    ;    If cos_yaw >= 0: South face (C3 -> C2 -> SKIRT_C2 -> SKIRT_C3)
    ;    If cos_yaw < 0:  North face (C1 -> C0 -> SKIRT_C0 -> SKIRT_C1)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_face_def
    inc r7
    inc r7
    iwt r0, #UV_MODE_WALL_NS
    stw (r7)            ; uv_mode (+2)

    with r12
    add #0
    blt @skirt_north
    nop

    ; South Face: V0=C3(12), V1=C2(8), V2=SKIRT_C2(24), V3=SKIRT_C3(28)
    move r1, r14
    iwt r6, #12
    with r1
    add r6              ; C3
    move r2, r14
    iwt r6, #8
    with r2
    add r6              ; C2
    move r4, r14
    iwt r6, #24
    with r4
    add r6              ; SKIRT_C2
    move r5, r14
    iwt r6, #28
    with r5
    add r6              ; SKIRT_C3
    bra @skirt_ns_setup
    nop

@skirt_north:
    ; North Face: V0=C1(4), V1=C0(0), V2=SKIRT_C0(16), V3=SKIRT_C1(20)
    move r1, r14
    iwt r6, #4
    with r1
    add r6              ; C1
    move r2, r14        ; C0
    move r4, r14
    iwt r6, #16
    with r4
    add r6              ; SKIRT_C0
    move r5, r14
    iwt r6, #20
    with r5
    add r6              ; SKIRT_C1

@skirt_ns_setup:
    iwt r7, #gsu_map_face_def + 12 ; ptr -> v0
    from r1
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    from r2
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    from r4
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT) ; 1h = 16 texels
    stw (r7)            ; v2
    inc r7
    inc r7

    from r5
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Compile ARCH_SKIRT_NS into arch_traps_ptr + skirt_ns_traps (+108)
    iwt r1, #gsu_map_face_def
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r11, #108
    with r0
    add r11
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r11, #106
    with r0
    add r11
    move r7, r0
    from r3
    stw (r7)            ; store skirt_ns_count (+106)

    ; --------------------------------------------------------------------------
    ; 6. Compile ARCH_SKIRT_EW (Vertical 1h Skirt)
    ;    uv_mode = UV_MODE_WALL_EW (2)
    ;    If sin_yaw >= 0: East face (C2 -> C1 -> SKIRT_C1 -> SKIRT_C2)
    ;    If sin_yaw < 0:  West face (C0 -> C3 -> SKIRT_C3 -> SKIRT_C0)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_face_def
    inc r7
    inc r7
    iwt r0, #UV_MODE_WALL_EW
    stw (r7)            ; uv_mode (+2)

    with r11
    add #0
    blt @skirt_west
    nop

    ; East Face: V0=C2(8), V1=C1(4), V2=SKIRT_C1(20), V3=SKIRT_C2(24)
    move r1, r14
    iwt r6, #8
    with r1
    add r6              ; C2
    move r2, r14
    iwt r6, #4
    with r2
    add r6              ; C1
    move r4, r14
    iwt r6, #20
    with r4
    add r6              ; SKIRT_C1
    move r5, r14
    iwt r6, #24
    with r5
    add r6              ; SKIRT_C2
    bra @skirt_ew_setup
    nop

@skirt_west:
    ; West Face: V0=C0(0), V1=C3(12), V2=SKIRT_C3(28), V3=SKIRT_C0(16)
    move r1, r14        ; C0
    move r2, r14
    iwt r6, #12
    with r2
    add r6              ; C3
    move r4, r14
    iwt r6, #28
    with r4
    add r6              ; SKIRT_C3
    move r5, r14
    iwt r6, #16
    with r5
    add r6              ; SKIRT_C0

@skirt_ew_setup:
    iwt r7, #gsu_map_face_def + 12 ; ptr -> v0
    from r1
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u0 = 0
    inc r7
    inc r7
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    from r2
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    from r4
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #$2000      ; 32 << 8
    stw (r7)            ; u2
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v2
    inc r7
    inc r7

    from r5
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    stw (r7)            ; u3 = 0
    inc r7
    inc r7
    iwt r0, #(16 << ATLAS_STRIDE_SHIFT)
    stw (r7)            ; v3

    ; Compile ARCH_SKIRT_EW into arch_traps_ptr + skirt_ew_traps (+214)
    iwt r1, #gsu_map_face_def
    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r11, #214
    with r0
    add r11
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_map_render_frame + 6
    ldw (r7)
    iwt r11, #212
    with r0
    add r11
    move r7, r0
    from r3
    stw (r7)            ; store skirt_ew_count (+212)

    ; Return 1 (recompiled)
    iwt r3, #1
    return
endfunction

; ==============================================================================
; map_grid_render
; Renders the Map Grid in back-to-front yaw-quadrant Painter's order,
; performing per-cell bounding box culling against active Frame Half and screen bounds.
; ==============================================================================
function map_grid_render map_ptr, cam_ptr, basis_ptr, arch_traps_ptr, frame_half, debug_order_ptr
    register map_ptr = r1, cam_ptr = r2, basis_ptr = r3, arch_traps_ptr = r4, frame_half = r5, debug_order_ptr = r6

    iwt r7, #gsu_map_render_frame

    ; Store function arguments in frame
    from r1
    stw (r7)            ; frame.map_ptr (+0)
    inc r7
    inc r7
    from r2
    stw (r7)            ; frame.cam_ptr (+2)
    inc r7
    inc r7
    from r3
    stw (r7)            ; frame.basis_ptr (+4)
    inc r7
    inc r7
    from r4
    stw (r7)            ; frame.arch_traps_ptr (+6)
    inc r7
    inc r7
    from r5
    stw (r7)            ; frame.frame_half (+8)
    inc r7
    inc r7
    from r6
    stw (r7)            ; frame.debug_order_ptr (+10)
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; frame.debug_count (+12) = 0

    ; 1. Read header fields: cols (+0), rows (+1), origin_x (+2), origin_z (+4)
    move r7, r1
    to r8
    ldb (r7)            ; r8 = cols
    inc r7
    to r9
    ldb (r7)            ; r9 = rows
    inc r7
    to r11
    ldw (r7)            ; r11 = origin_x
    inc r7
    inc r7
    to r12
    ldw (r7)            ; r12 = origin_z

    ; Store cols, rows, origin_x, origin_z in frame
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)
    inc r7
    inc r7
    from r12
    stw (r7)

    ; 2. Determine Yaw Quadrant loop directions from cos_yaw (+4) and sin_yaw (+2)
    move r7, r2         ; cam_ptr
    inc r7
    inc r7
    to r11
    ldw (r7)            ; r11 = sin_yaw
    inc r7
    inc r7
    to r12
    ldw (r7)            ; r12 = cos_yaw

    ; Determine j loop parameters (North/South depth axis):
    ; If cos_yaw >= 0: j goes 0 .. rows-1 (start=0, step=1)
    ; If cos_yaw < 0:  j goes rows-1 .. 0 (start=rows-1, step=-1)
    with r12
    add #0
    blt @j_decreasing
    nop
    iwt r8, #0          ; j_start = 0
    iwt r9, #1          ; j_step = 1
    bra @j_done
    nop
@j_decreasing:
    iwt r7, #gsu_map_render_frame + map_render_frame::rows
    ldw (r7)
    dec r0
    move r8, r0         ; j_start = rows - 1
    iwt r9, #$FFFF      ; j_step = -1
@j_done:
    iwt r7, #gsu_map_render_frame + map_render_frame::rows
    to r14
    ldw (r7)            ; r14 = j_count = rows

    iwt r7, #gsu_map_render_frame + map_render_frame::j_start
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)
    inc r7
    inc r7
    from r14
    stw (r7)           ; j_count = rows

    ; Determine i loop parameters (East/West width axis):
    ; If sin_yaw >= 0: i goes 0 .. cols-1 (start=0, step=1)
    ; If sin_yaw < 0:  i goes cols-1 .. 0 (start=cols-1, step=-1)
    with r11
    add #0
    blt @i_decreasing
    nop
    iwt r8, #0          ; i_start = 0
    iwt r9, #1          ; i_step = 1
    bra @i_done
    nop
@i_decreasing:
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    ldw (r7)
    dec r0
    move r8, r0         ; i_start = cols - 1
    iwt r9, #$FFFF      ; i_step = -1
@i_done:
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    to r11
    ldw (r7)            ; r11 = i_count = cols

    iwt r7, #gsu_map_render_frame + map_render_frame::i_start
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)           ; i_count = cols

    ; --------------------------------------------------------------------------
    ; 3. Outer J Loop (Rows)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::j_start
    to r9
    ldw (r7)            ; r9 = j_cur = j_start
    inc r7
    inc r7
    inc r7
    inc r7
    to r11
    ldw (r7)            ; r11 = j_rem = j_count

@j_loop_top:
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)            ; save j_rem

    ; --------------------------------------------------------------------------
    ; 4. Inner I Loop (Cols)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::i_start
    to r12
    ldw (r7)            ; r12 = i_cur = i_start
    inc r7
    inc r7
    inc r7
    inc r7
    to r14
    ldw (r7)            ; r14 = i_rem = i_count

@i_loop_top:
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    from r12
    stw (r7)
    inc r7
    inc r7
    from r14
    stw (r7)            ; save i_rem

    ; --------------------------------------------------------------------------
    ; 5. Read Map Cell Record at (j * cols + i) << 3
    ; --------------------------------------------------------------------------
    move r6, r9         ; mul_b = j_cur
    iwt r7, #gsu_map_render_frame + map_render_frame::cols
    ldw (r7)            ; r0 = cols
    to r8
    lmult               ; r4_reg = j * cols
    from r12            ; add i_cur
    to r8
    add r4
    ; index << 3:
    with r8
    add r8
    with r8
    add r8
    with r8
    add r8              ; r8 = (j * cols + i) << 3

    ; cell_ptr = map_ptr + 8 + r8
    iwt r7, #gsu_map_render_frame + map_render_frame::map_ptr
    ldw (r7)
    with r0
    add #8
    with r0
    add r8
    move r7, r0         ; r7 = cell_ptr

    ; Read cell fields:
    ; base_height (+0)
    ldb (r7)
    iwt r11, #gsu_map_render_frame + map_render_frame::base_height
    stw (r11)

    ; archetype_id (+1)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; top_tex_id (+2)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; skirt_tex_id (+3)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; panel_tex_id (+4) & panel_flags (+5) [skip to +6]
    inc r7
    inc r7
    inc r7

    ; drop_ns (+6)
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; drop_ew (+7)
    inc r7
    ldb (r7)
    inc r11
    inc r11
    stw (r11)

    ; --------------------------------------------------------------------------
    ; 6. Calculate 2D Screen Anchor(i, j, base_height):
    ;    Anchor.x = origin_x + i * Sx.x + j * Sz.x
    ;    Anchor.y = origin_z + i * Sx.y + j * Sz.y + base_height * (-14)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::origin_x
    to r1
    ldw (r7)            ; r1 = anchor_x
    inc r7
    inc r7
    to r2
    ldw (r7)            ; r2 = anchor_y

    iwt r7, #gsu_map_render_frame + map_render_frame::basis_ptr
    ldw (r7)
    move r7, r0         ; r7 = basis_ptr

    ; + i * Sx:
    move r6, r12        ; mul_b = i_cur
    ldw (r7)            ; r0 = Sx.x
    to r8
    lmult
    with r1
    add r4
    inc r7
    inc r7
    ldw (r7)            ; r0 = Sx.y
    to r8
    lmult
    with r2
    add r4

    ; + j * Sz:
    inc r7
    inc r7
    move r6, r9         ; mul_b = j_cur
    ldw (r7)            ; r0 = Sz.x
    to r8
    lmult
    with r1
    add r4
    inc r7
    inc r7
    ldw (r7)            ; r0 = Sz.y
    to r8
    lmult
    with r2
    add r4

    ; + base_height * (-14):
    iwt r7, #gsu_map_render_frame + map_render_frame::base_height
    ldw (r7)
    move r6, r0         ; mul_b = base_height
    iwt r0, #$FFF2      ; -14 ($FFF2)
    to r8
    lmult
    with r2
    add r4

    ; Save anchor_x and anchor_y in frame
    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)

    ; --------------------------------------------------------------------------
    ; 7. Per-Cell Bounding-Box Culling:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #318
    with r0
    add r11
    move r7, r0         ; r7 = arch_traps_ptr + bbox_xmin

    ; cell_xmin = anchor_x + bbox_xmin (+318)
    ldw (r7)            ; r0 = bbox_xmin
    with r0
    add r1              ; r0 = bbox_xmin + anchor_x
    move r3, r0         ; r3 = xmin

    ; cell_xmax = anchor_x + bbox_xmax (+320)
    inc r7
    inc r7
    ldw (r7)            ; r0 = bbox_xmax
    with r0
    add r1              ; r0 = bbox_xmax + anchor_x
    move r4, r0         ; r4 = xmax

    ; cell_ymin = anchor_y + bbox_ymin (+322)
    inc r7
    inc r7
    ldw (r7)            ; r0 = bbox_ymin
    with r0
    add r2              ; r0 = bbox_ymin + anchor_y
    move r5, r0         ; r5 = ymin

    ; max_drop = max(drop_ns, drop_ew)
    iwt r8, #gsu_map_render_frame + map_render_frame::drop_ns
    to r6
    ldw (r8)            ; r6 = max_drop
    inc r8
    inc r8
    to r14
    ldw (r8)            ; r14 = drop_ew
    from r14
    sub r6
    blt @skip_max_drop
    nop
    move r6, r14
@skip_max_drop:
    ; drop_px = max_drop * 14 = (max_drop << 4) - (max_drop << 1)
    move r8, r6
    with r8
    add r8              ; r8 = max_drop * 2
    move r14, r8
    with r8
    add r8              ; * 4
    with r8
    add r8              ; * 8
    with r8
    add r8              ; * 16
    with r8
    sub r14             ; * 14

    ; cell_ymax = anchor_y + bbox_ymax (+324) + drop_px
    inc r7
    inc r7
    ldw (r7)            ; r0 = bbox_ymax
    with r0
    add r2
    with r0
    add r8
    move r6, r0         ; r6 = ymax

    ; --- Vertical Screen Culling [0, 160) ---
    ; If ymax < 0: cull
    with r6
    add #0
    blt :+
    nop
    bra @vert_y_ok
    nop
:
    iwt r13, #@cull_cell
    jmp r13
    nop

@vert_y_ok:
    ; If ymin >= 160: cull
    iwt r14, #160
    from r5
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    ; --- Horizontal Frame Half Culling ---
    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    with r0
    add #0
    bmi @cell_visible
    nop
    bne @check_half_1
    nop

    ; Pass 0 (Half 0): screen X in [0, 128)
    ; If xmax < 0: cull
    with r4
    add #0
    blt :+
    nop
    bra @pass0_xmax_ok
    nop
:
    iwt r13, #@cull_cell
    jmp r13
    nop

@pass0_xmax_ok:
    ; If xmin >= 128: cull
    iwt r14, #128
    from r3
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    iwt r13, #@cell_visible
    jmp r13
    nop

@check_half_1:
    ; Pass 1 (Half 1): screen X in [128, 256)
    ; If xmax < 128: cull
    iwt r14, #128
    from r4
    sub r14
    bge :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    ; If xmin >= 256: cull
    iwt r14, #256
    from r3
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:

@cell_visible:
    ; --------------------------------------------------------------------------
    ; 8. Optional Trace Recording for Traversal & Culling Verification
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::debug_order_ptr
    ldw (r7)
    with r0
    add #0
    beq @do_stamping
    nop
    move r11, r0        ; r11 = debug_order_ptr

    ; Write (i_cur << 8) | j_cur to debug_order_ptr
    from r12
    to r14
    swap
    iwt r7, #$00FF
    from r9
    to r8
    and r7
    with r14
    or r8
    from r14
    stw (r11)
    inc r11
    inc r11
    iwt r7, #gsu_map_render_frame + map_render_frame::debug_order_ptr
    from r11
    stw (r7)           ; update debug_order_ptr in frame

    ; Increment debug_count (+12)
    inc r7
    inc r7
    ldw (r7)
    inc r0
    stw (r7)

    ; When debug_order_ptr is non-zero, skip trapezoid stamping for pure traversal tests
    iwt r13, #@cull_cell
    jmp r13
    nop

@do_stamping:
    ; --------------------------------------------------------------------------
    ; 9. Intra-Cell Stamping:
    ;    Step 1: Exposed Cell Skirts (drop_ns and drop_ew)
    ;    Step 3: Shape Archetype (PRIM_FLAT)
    ; --------------------------------------------------------------------------

    ; --- 9A: Stamp ARCH_SKIRT_NS (drop_ns steps) ---
    iwt r7, #gsu_map_render_frame + map_render_frame::drop_ns
    ldw (r7)
    with r0
    add #0
    bne :+
    nop
    iwt r13, #@skirt_ns_done
    jmp r13
    nop
:
    move r8, r0         ; r8 = drop_ns

    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #106
    with r0
    add r11             ; skirt_ns_count
    move r7, r0
    ldw (r7)
    with r0
    add #0
    bne :+
    nop
    iwt r13, #@skirt_ns_done
    jmp r13
    nop
:
    move r9, r0         ; r9 = skirt_ns_count

    ; U offset for NS skirt = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    ldw (r7)
    swap                ; r0 = i_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    with r0
    add r0              ; << 12
    with r0
    add r0              ; << 13
    move r5, r0         ; r5 = u_offset in Q8.8

    ; Skirt texture ID
    iwt r7, #gsu_map_render_frame + map_render_frame::skirt_tex_id
    to r11
    ldw (r7)            ; r11 = skirt_tex_id

    ; Loop over vertical steps s = 0 .. drop_ns - 1
    iwt r12, #0         ; r12 = s = 0
@ns_step_loop:
    ; step_y = anchor_y + s * 14
    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_y
    ldw (r7)
    move r4, r0         ; r4 = anchor_y
    from r12
    to r14
    add r12             ; s * 2
    move r7, r14
    with r14
    add r14
    with r14
    add r14
    with r14
    add r14             ; s * 16
    with r14
    sub r7              ; s * 14
    with r4
    add r14             ; r4 = anchor_y + s * 14

    ; v_offset = (s * 16) << ATLAS_STRIDE_SHIFT = s << 10:
    move r0, r12
    swap                ; s << 8
    with r0
    add r0              ; s << 9
    with r0
    add r0              ; s << 10
    move r6, r0         ; r6 = v_offset

    ; Stamp each cached_trap in skirt_ns_traps:
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r2, #108
    with r0
    add r2
    move r1, r0         ; r1 = skirt_ns_traps

    move r14, r9        ; r14 = trap counter
@ns_trap_loop:
    ; Set trap tex_id (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r11
    stw (r7)

    gsu_stack_push r14
    gsu_stack_push r1
    gsu_stack_push r12
    gsu_stack_push r11
    gsu_stack_push r9
    gsu_stack_push r8
    gsu_stack_push r6
    gsu_stack_push r5
    gsu_stack_push r4

    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x

    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    call draw_cached_trap r1, r3, r4, r5, r6, r7

    gsu_stack_pop r4
    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r8
    gsu_stack_pop r9
    gsu_stack_pop r11
    gsu_stack_pop r12
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    bne @ns_trap_loop
    nop

    inc r12
    from r12
    sub r8
    bge :+
    nop
    iwt r13, #@ns_step_loop
    jmp r13
    nop
:

@skirt_ns_done:

    ; --- 9B: Stamp ARCH_SKIRT_EW (drop_ew steps) ---
    iwt r7, #gsu_map_render_frame + map_render_frame::drop_ew
    ldw (r7)
    with r0
    add #0
    bne :+
    nop
    iwt r13, #@skirt_ew_done
    jmp r13
    nop
:
    move r8, r0         ; r8 = drop_ew

    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #212
    with r0
    add r11             ; skirt_ew_count
    move r7, r0
    ldw (r7)
    with r0
    add #0
    bne :+
    nop
    iwt r13, #@skirt_ew_done
    jmp r13
    nop
:
    move r9, r0         ; r9 = skirt_ew_count

    ; U offset for EW skirt = (j_cur * 32) << 8 = j_cur << 13:
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    swap                ; r0 = j_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    with r0
    add r0              ; << 12
    with r0
    add r0              ; << 13
    move r5, r0         ; r5 = u_offset in Q8.8

    ; Skirt texture ID
    iwt r7, #gsu_map_render_frame + map_render_frame::skirt_tex_id
    to r11
    ldw (r7)            ; r11 = skirt_tex_id

    ; Loop over vertical steps s = 0 .. drop_ew - 1
    iwt r12, #0         ; r12 = s = 0
@ew_step_loop:
    ; step_y = anchor_y + s * 14
    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_y
    ldw (r7)
    move r4, r0         ; r4 = anchor_y
    from r12
    to r14
    add r12             ; s * 2
    move r7, r14
    with r14
    add r14
    with r14
    add r14
    with r14
    add r14             ; s * 16
    with r14
    sub r7              ; s * 14
    with r4
    add r14             ; r4 = anchor_y + s * 14

    ; v_offset = (s * 16) << ATLAS_STRIDE_SHIFT = s << 10:
    move r0, r12
    swap                ; s << 8
    with r0
    add r0              ; s << 9
    with r0
    add r0              ; s << 10
    move r6, r0         ; r6 = v_offset

    ; Stamp each cached_trap in skirt_ew_traps:
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r2, #214
    with r0
    add r2
    move r1, r0         ; r1 = skirt_ew_traps

    move r14, r9
@ew_trap_loop:
    ; Set trap tex_id (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r11
    stw (r7)

    gsu_stack_push r14
    gsu_stack_push r1
    gsu_stack_push r12
    gsu_stack_push r11
    gsu_stack_push r9
    gsu_stack_push r8
    gsu_stack_push r6
    gsu_stack_push r5
    gsu_stack_push r4

    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x

    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    call draw_cached_trap r1, r3, r4, r5, r6, r7

    gsu_stack_pop r4
    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r8
    gsu_stack_pop r9
    gsu_stack_pop r11
    gsu_stack_pop r12
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    bne @ew_trap_loop
    nop

    inc r12
    from r12
    sub r8
    bge :+
    nop
    iwt r13, #@ew_step_loop
    jmp r13
    nop
:

@skirt_ew_done:

    ; --- 9C: Stamp PRIM_FLAT (Top Cap) ---
    iwt r7, #gsu_map_render_frame + map_render_frame::archetype_id
    ldw (r7)
    move r8, r0
    iwt r14, #$003F
    with r8
    and r14             ; r8 = base archetype (bits 0..5)
    with r8
    add #0
    beq :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    move r7, r0         ; r7 = arch_traps_ptr
    ldw (r7)            ; flat_count (+0)
    with r0
    add #0
    bne :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    move r9, r0         ; r9 = flat_count

    ; u_offset = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    ldw (r7)
    swap                ; r0 = i_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    with r0
    add r0              ; << 12
    with r0
    add r0              ; << 13
    move r5, r0         ; r5 = u_offset in Q8.8

    ; v_offset = (j_cur * 32) << ATLAS_STRIDE_SHIFT = j_cur << 11:
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    swap                ; r0 = j_cur << 8
    with r0
    add r0              ; << 9
    with r0
    add r0              ; << 10
    with r0
    add r0              ; << 11
    move r6, r0         ; r6 = v_offset

    ; Top texture ID
    iwt r7, #gsu_map_render_frame + map_render_frame::top_tex_id
    to r11
    ldw (r7)            ; r11 = top_tex_id

    ; cell_ptr = arch_traps_ptr + flat_traps (+2)
    iwt r7, #gsu_map_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    inc r0
    inc r0
    move r1, r0

    move r14, r9
@flat_trap_loop:
    ; Set trap tex_id (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r11
    stw (r7)

    gsu_stack_push r14
    gsu_stack_push r1
    gsu_stack_push r11
    gsu_stack_push r9
    gsu_stack_push r6
    gsu_stack_push r5

    iwt r7, #gsu_map_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; anchor_y

    iwt r7, #gsu_map_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    call draw_cached_trap r1, r3, r4, r5, r6, r7

    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r9
    gsu_stack_pop r11
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    bne @flat_trap_loop
    nop

@cull_cell:
    ; --------------------------------------------------------------------------
    ; 10. Advance I Loop
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::i_cur
    ldw (r7)
    move r12, r0        ; r12 = i_cur
    iwt r7, #gsu_map_render_frame + map_render_frame::i_step
    ldw (r7)
    with r12
    add r0              ; i_cur += i_step

    iwt r7, #gsu_map_render_frame + map_render_frame::i_rem
    ldw (r7)
    dec r0
    move r14, r0        ; r14 = i_rem
    beq @i_loop_done
    nop

    ; Reload j_cur into r9 for next i_loop_top
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    move r9, r0

    iwt r13, #@i_loop_top
    jmp r13
    nop

@i_loop_done:
    ; --------------------------------------------------------------------------
    ; 11. Advance J Loop
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_map_render_frame + map_render_frame::j_cur
    ldw (r7)
    move r9, r0         ; r9 = j_cur
    iwt r7, #gsu_map_render_frame + map_render_frame::j_step
    ldw (r7)
    with r9
    add r0              ; j_cur += j_step

    iwt r7, #gsu_map_render_frame + map_render_frame::j_rem
    ldw (r7)
    dec r0
    move r11, r0        ; r11 = j_rem
    beq @render_done
    nop

    iwt r13, #@j_loop_top
    jmp r13
    nop

@render_done:
    return
endfunction

.endif ; ::__ISO_MAP_GRID_DEFINED__
