; ==============================================================================
; gsu_iso_map.i - Unified SuperFX Isometric Map Grid, Archetype Compiler & Renderer
;
; Supports:
;   - Direct-ROM 32 KB scenes (`GSU_ISO_USE_ROM_TEXTURES = 1` + `gsu_iso_init_rom`
;     + `draw_cached_trap`) and Bank-$71 RAM scenes (`gsu_iso_import_bank71` +
;     `draw_cached_trap_ram`) from one shared codebase with zero traversal `.ifdef`s
;   - Configurable `GSU_ISO_MAX_MAP_BYTES` and `GSU_ISO_MAX_TAB_BYTES` via `.ifndef`
;   - Dynamic runtime `stride_shift` (e.g. 5=32px, 6=64px, 7=128px, 8=256px)
;   - All 12 isometric shape archetypes, 4 rotations, 4-way skirts, 1h/2h panels
; ==============================================================================
.ifndef __GSU_ISO_MAP_DEFINED__
__GSU_ISO_MAP_DEFINED__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"
.include "../common/control.i"
.include "../common/structs.i"
.include "../common/var.i"
.include "../common/util.i"

; Viewport width config (default 256 for IsoEngine/RamMapDemo; 192 for IsoRPGDemo)
.ifndef GSU_ISO_VIEWPORT_W
    GSU_ISO_VIEWPORT_W = 256
.endif
.if GSU_ISO_VIEWPORT_W = 192
    .ifndef GSU_ISO_CENTER_X
        GSU_ISO_CENTER_X = 96
    .endif
.endif
.ifndef GSU_TRAP_PASS1_MAX_X
    GSU_TRAP_PASS1_MAX_X = (GSU_ISO_VIEWPORT_W - 128)
.endif

.include "../gsu_maths/gsu_iso_camera.i"
.include "../IsoEngine/triangle/cached_trap.i"
.include "../IsoEngine/triangle/compile_face_traps_def.i"
.include "../IsoEngine/triangle/compile_face_traps.i"
.include "bank71_layout.i"
.include "scene_descriptor.i"

.ifndef GSU_ISO_SCREEN_H
    GSU_ISO_SCREEN_H = 160
.endif

; Configurable tactical Cell Highlight BG1 palette indices (Issue #35)
.ifndef GSU_HL_COLOR_MOVE
    GSU_HL_COLOR_MOVE   = 12
.endif
.ifndef GSU_HL_COLOR_ATTACK
    GSU_HL_COLOR_ATTACK = 13
.endif
.ifndef GSU_HL_COLOR_CURSOR
    GSU_HL_COLOR_CURSOR = 14
.endif

.ifndef GSU_ISO_USE_ROM_TEXTURES
_GSU_SKIP_ROM_TRAP_INST .set 1
.endif
.include "draw_cached_trap.i"
_GSU_SKIP_ROM_TRAP_INST .set 0
.ifndef GSU_ISO_USE_ROM_TEXTURES
.include "draw_cached_trap_ram.i"
.endif

; 1-line rasterizer dispatch seam (selects ROM vs Bank-$71 leaf at assemble time
; so 32 KB direct-ROM targets never link unused Bank-$71 code and vice versa)
.macro _gsu_iso_draw_trap
.ifdef GSU_ISO_USE_ROM_TEXTURES
    call draw_cached_trap
.else
    call draw_cached_trap_ram
.endif
.endmacro

GSU_ISO_MAX_COLS        = 16
GSU_ISO_MAX_ROWS        = 16
GSU_ISO_MAX_CELLS       = 256
.ifndef GSU_ISO_MAX_MAP_BYTES
GSU_ISO_MAX_MAP_BYTES   = 2056      ; 8B map_header + 256 * 8B map_cell
.endif
.ifndef GSU_ISO_MAX_TAB_BYTES
GSU_ISO_MAX_TAB_BYTES   = 2048      ; 256 * 8B descriptors in Bank $70
.endif

; ==============================================================================
; Binary Map Structures (ca65)
; ==============================================================================

.ifndef __ISO_MAP_STRUCTS_DEFINED__
__ISO_MAP_STRUCTS_DEFINED__ = 1
.struct map_header
    cols            .byte   ; +0: Grid width in cells (4..16)
    rows            .byte   ; +1: Grid depth in cells (4..16)
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
PRIM_FLAT              = 0
PRIM_WEDGE_STRAIGHT    = 1
PRIM_WEDGE_STRAIGHT_2H = 2
PRIM_WEDGE_OUTER       = 3
PRIM_WEDGE_OUTER_2H    = 4
PRIM_WEDGE_INNER       = 5
PRIM_WEDGE_INNER_2H    = 6
PRIM_STAIRS            = 7
PRIM_LIQUID_SHALLOW    = 8
PRIM_LIQUID_DEEP       = 9
PRIM_PILLAR            = 10
PRIM_FOLIAGE_CROSS     = 11

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
    arch_lut        .res 64 * 2 ; +326: 128 bytes (offsets for (archetype << 2) | rot)
    arch_buf        .res 10240   ; +454: storage buffer for compiled cached_traps
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

    compile_out_ptr .word ; +64: current output pointer in arch_buf
    arch_trap_count .word ; +66: trap count for current shape
    elev_midpoints  .res 32 ; +68..+99: 8 points (MN, ME, MS, MW at +1h and +2h, 4 bytes each)
    v_ptrs          .res 24 ; +100..+123: B0..B3, E1_0..E1_3, E2_0..E2_3 (12 words)
    m_ptrs          .res 16 ; +124..+139: MB_W, MB_E, M1_W, M1_E, M2_W, M2_E (8 words)
    cur_rot         .word ; +140: current rotation (0..3)
    panel_tex_id    .word ; +142: panel/foliage cutout texture ID
    k_bot           .res 4 ; +144: center bottom point (x, y)
    k_top           .res 4 ; +148: center top point (x, y)
    cur_entry_ptr   .word ; +152: entry pointer for current shape
    panel_flags     .word ; +154: cell panel_flags
    back_ns_mask    .word ; +156: PANEL_N or PANEL_S
    back_ns_edge    .word ; +158: 0 or 2
    back_ew_mask    .word ; +160: PANEL_W or PANEL_E
    back_ew_edge    .word ; +162: 3 or 1
    front_ns_mask   .word ; +164: PANEL_S or PANEL_N
    front_ns_edge   .word ; +166: 2 or 0
    front_ew_mask   .word ; +168: PANEL_E or PANEL_W
    front_ew_edge   .word ; +170: 1 or 3
    panel_lut       .res 8 * 2 ; +172..+187: offsets in arch_traps_ptr for the 8 panel templates
    sx_x_q5         .word ; +188
    sx_y_q5         .word ; +190
    sz_x_q5         .word ; +192
    sz_y_q5         .word ; +194
    origin_x_q5     .word ; +196
    origin_z_q5     .word ; +198
    quad_table      .res 64 ; +200..+263: active quadrant cell index sequence
    is_8x8          .word ; +264: 1 if cols==8 and rows==8, else 0
    cell_idx        .word ; +266: current cell index in 8x8 mode (0..63)
.endstruct

.endif ; __ISO_MAP_STRUCTS_DEFINED__

.segment "GSURAM"
.align 2
gsu_iso_render_frame:       .res .sizeof(map_render_frame)
gsu_iso_face_def:           .res .sizeof(face_def)
gsu_iso_active_arch_mask:   .res 2
.export gsu_iso_active_arch_mask
gsu_iso_effective_arch_mask:.res 2
gsu_iso_is_prebaked:        .res 2
gsu_iso_row_anchor_x_q5:    .res 2
gsu_iso_row_anchor_z_q5:    .res 2
gsu_iso_row_cell_offset:    .res 2

; Dynamic runtime atlas stride parameters populated from Bank-$71 `.tab` header
gsu_runtime_stride_shift:   .res 2
.export gsu_runtime_stride_shift
gsu_runtime_atlas_width:    .res 2
.export gsu_runtime_atlas_width
gsu_runtime_tab_count:      .res 2
.export gsu_runtime_tab_count
gsu_v16_shifted:            .res 2  ; 16 << gsu_runtime_stride_shift
.export gsu_v16_shifted
gsu_v32_shifted:            .res 2  ; 32 << gsu_runtime_stride_shift
.export gsu_v32_shifted
gsu_iso_active_desc_ptr:    .res 2  ; Pointer to active gsu_scene_descriptor (0 when unused)
.export gsu_iso_active_desc_ptr
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
gsu_iso_hl_enabled:         .res 2  ; Cached desc->highlights_enabled (0 = skip highlight pass)
gsu_hl_lines_left:          .res 2  ; Scratch: highlight trap scanlines remaining
gsu_hl_xL:                  .res 2  ; Scratch: highlight trap left X in Q8.8
gsu_hl_xR:                  .res 2  ; Scratch: highlight trap right X in Q8.8
gsu_hl_trap_ptr:            .res 2  ; Scratch: highlight trap pointer
gsu_hl_max_x:               .res 2  ; Scratch: active frame half max local X (128 or VIEWPORT_W-128)
gsu_hl_color:               .res 2  ; Scratch: resolved BG1 highlight palette color index
.endif

.ifndef GSU_ISO_NO_DEFAULT_BUFFERS
TEXTURE_TABLE_RAM:          .res GSU_ISO_MAX_TAB_BYTES
.export TEXTURE_TABLE_RAM
MAP_BUF:                    .res GSU_ISO_MAX_MAP_BYTES
.export MAP_BUF
GSU_INIT_FLAG:              .res 2
.export GSU_INIT_FLAG
GSU_LOAD_MODE:              .res 2
.export GSU_LOAD_MODE
GSU_IMPORT_ERROR:           .res 2
.export GSU_IMPORT_ERROR
GSU_FRAME_HALF:             .res 2
.export GSU_FRAME_HALF
GSU_JOYPAD:                 .res 2
.export GSU_JOYPAD
ISO_CAM:                    .tag iso_camera
.export ISO_CAM
ISO_BASIS:                  .tag iso_basis
.export ISO_BASIS
LATTICE_V2:                 .res 28 * .sizeof(vector2)
.export LATTICE_V2
ARCH_TRAPS:                 .tag arch_traps_table
.export ARCH_TRAPS
CACHED_YAW:                 .res 2
.export CACHED_YAW
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
.align 2
GSU_SCENE_DESC:             .tag gsu_scene_descriptor
.export GSU_SCENE_DESC
.endif
.endif

; Helper macro: dst_reg = (r0 * 16) << gsu_runtime_stride_shift
; Uses hardware 8x8 unsigned `umult` against `gsu_v16_shifted >> 8` (12B, 12 cycles;
; supports stride_shift 4..10, including 32px..256px atlases).
; Requires: dst_reg in R1..R15, scratch_reg in R0..R11, r0 in 0..255
; Clobbers: r0, dst_reg, scratch_reg
.macro _gsu_iso_v_offset_16 dst_reg, scratch_reg
    move dst_reg, r0
    iwt scratch_reg, #gsu_v16_shifted
    ldw (scratch_reg)
    hib
    umult dst_reg
    lob
    to dst_reg
    swap
.endmacro

; Helper macro: dst_reg = (r0 * 32) << gsu_runtime_stride_shift
; Uses hardware 8x8 unsigned `umult` against `gsu_v32_shifted >> 8` (12B, 12 cycles;
; supports stride_shift 4..10, including 32px..256px atlases).
; Requires: dst_reg in R1..R15, scratch_reg in R0..R11, r0 in 0..255
; Clobbers: r0, dst_reg, scratch_reg
.macro _gsu_iso_v_offset_32 dst_reg, scratch_reg
    move dst_reg, r0
    iwt scratch_reg, #gsu_v32_shifted
    ldw (scratch_reg)
    hib
    umult dst_reg
    lob
    to dst_reg
    swap
.endmacro

.segment "GSUCODE"

; ==============================================================================
; gsu_iso_set_stride_shift
; Updates `gsu_runtime_stride_shift`, `gsu_v16_shifted` (16 << shift), and
; `gsu_v32_shifted` (32 << shift) in Bank $70 GSURAM.
;
; In:
;   shift_val = r1: log2(atlas_width), e.g. 5 (32px), 6 (64px), 7 (128px), 8 (256px)
; Clobbers:
;   r0, r1, r2, r3
; ==============================================================================
function gsu_iso_set_stride_shift shift_val
    register shift_val = r1
    sm (gsu_runtime_stride_shift), shift_val
    iwt r2, #16
    move r3, shift_val
    moves r3, r3
    beq @shift_done
    nop
@shift_loop:
    with r2
    add r2
    dec r3
    bne @shift_loop
    nop
@shift_done:
    sm (gsu_v16_shifted), r2
    from r2
    add r2
    sm (gsu_v32_shifted), r0
    return
endfunction

.ifndef GSU_ISO_NO_DEFAULT_BUFFERS

; ==============================================================================
; gsu_iso_init_rom
; Direct-ROM boot initializer for 32 KB Bank-$70 isometric scenes (`IsoEngine`,
; `StarshipMap`, and ROM tests). Copies the ROM Texture Table (`TEXTURE_TABLE`)
; into `TEXTURE_TABLE_RAM`, copies the ROM Map Grid (`.map` / `def_cell` table)
; into `MAP_BUF`, sets dynamic `gsu_runtime_stride_shift`, pre-bakes 4-way
; neighbor skirt drops (`$BACE`), initializes `ISO_CAM` (`yaw=1`, `center=(128,80)`,
; `cam=(0,0)`), marks `CACHED_YAW = $FFFF`, and sets `GSU_INIT_FLAG = 1`.
;
; In:
;   map_rom_ptr      = r1: 16-bit ROM offset of map header in Bank $04 (`GSUDATA`)
;   map_byte_size    = r2: Byte length of map header + cells
;   tab_rom_ptr      = r3: 16-bit ROM offset of `TEXTURE_TABLE` in Bank $04 (`GSUDATA`)
;   tab_byte_size    = r4: Byte length of `TEXTURE_TABLE` (`entry_count * 8`)
;   stride_shift_val = r5: log2(atlas_width), e.g. 5 (32px), 6 (64px), 7 (128px), 8 (256px)
; Postconditions:
;   - `RAMBR == 0` ($70) and `ROMBR == $04` on return
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_init_rom map_rom_ptr, map_byte_size, tab_rom_ptr, tab_byte_size, stride_shift_val
    register map_rom_ptr = r1, map_byte_size = r2, tab_rom_ptr = r3, tab_byte_size = r4, stride_shift_val = r5

    ibt r0, #$04
    romb
    ibt r0, #0
    ramb

    gsu_stack_push stride_shift_val
    gsu_stack_push tab_byte_size

    ; 1. Copy ROM TEXTURE_TABLE (r3, r4 bytes) -> Bank-$70 TEXTURE_TABLE_RAM
    move r14, tab_rom_ptr
    move r12, tab_byte_size
    iwt r6, #TEXTURE_TABLE_RAM
    iwt r13, #@copy_tab_rom
@copy_tab_rom:
    getb
    inc r14
    stb (r6)
    nop
    loop
    inc r6

    ; 2. Copy ROM .map (r1, r2 bytes) -> Bank-$70 MAP_BUF
    move r14, map_rom_ptr
    move r12, map_byte_size
    iwt r6, #MAP_BUF
    iwt r13, #@copy_map_rom
@copy_map_rom:
    getb
    inc r14
    stb (r6)
    nop
    loop
    inc r6

    ; 3. Store runtime tab count (tab_byte_size >> 3), stride shift & atlas width
    gsu_stack_pop r0
    lsr
    lsr
    lsr
    sm (gsu_runtime_tab_count), r0

    gsu_stack_pop r1
    call gsu_iso_set_stride_shift r1

    lm r0, (gsu_v16_shifted)
    lsr
    lsr
    lsr
    lsr
    sm (gsu_runtime_atlas_width), r0

    ; 4. Pre-bake 4-way skirt drops & active archetype mask in $70:MAP_BUF
    iwt r1, #MAP_BUF
    call gsu_iso_prebake_map r1

    ; 5. Initialize ISO_CAM: yaw = 1, center = (GSU_ISO_CENTER_X, GSU_ISO_CENTER_Y), cam = (0, 0)
    iwt r1, #ISO_CAM
    iwt r2, #1
    call iso_camera_set_yaw r1, r2

    iwt r1, #(ISO_CAM + 6)
    iwt r0, #GSU_ISO_CENTER_X
    stw (r1)                ; center_x (128 for 256px, 96 for 192px)
    inc r1
    inc r1
    iwt r0, #GSU_ISO_CENTER_Y
    stw (r1)                ; center_y (default 80)
    inc r1
    inc r1
    ibt r0, #0
    stw (r1)                ; cam_x = 0
    inc r1
    inc r1
    stw (r1)                ; cam_z = 0

    ; 6. Force archetype recompilation on first Pass 0 & mark scene initialized
    iwt r0, #$FFFF
    sm (CACHED_YAW), r0
    iwt r0, #1
    sm (GSU_INIT_FLAG), r0
    ibt r0, #0
    sm (GSU_IMPORT_ERROR), r0
    return
endfunction

.ifndef GSU_ISO_USE_ROM_TEXTURES
; ==============================================================================
; gsu_iso_import_bank71
; Imports the active Texture Table (`.tab` at `$71:8000`) and Map Grid (`.map` at
; `$71:8808`) from Game Pak RAM Bank $71 into Bank $70 working buffers
; (`TEXTURE_TABLE_RAM` and `MAP_BUF`), validates headers, computes runtime stride
; shifts, pre-bakes 4-way neighbor skirt drops, applies `GSU_LOAD_MODE` camera
; rules, marks `CACHED_YAW = $FFFF`, and sets `GSU_INIT_FLAG = 1`.
;
; Out:
;   r3 = SFX_IMPORT_OK (0) or SFX_IMPORT_ERR_* (1..3); also written to GSU_IMPORT_ERROR
; Postconditions:
;   - `RAMBR == 0` ($70) and `ROMBR == $04` on all exit paths
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_import_bank71 : status_code
    ; Ensure ROMBR = $04 for trig/reciprocal LUTs in GSUDATA
    ibt r0, #$04
    romb

    ; 1. Read 8-byte .tab header from Bank $71 ($71:8000)
    ibt r0, #1
    ramb
    iwt r1, #BANK71_TAB_ADDR
    to r2
    ldw (r1)                ; r2 = magic (+0)
    inc r1
    inc r1
    to r3
    ldw (r1)                ; r3 = entry_count (+2)
    inc r1
    inc r1
    to r4
    ldw (r1)                ; r4 = atlas_width (+4)
    inc r1
    inc r1
    to r5
    ldw (r1)                ; r5 = stride_shift (+6)
    ibt r0, #0
    ramb

    ; Validate magic == SFX_TAB_MAGIC ($5453)
    iwt r6, #SFX_TAB_MAGIC
    from r2
    cmp r6
    beq @magic_ok
    nop
    iwt r3, #SFX_IMPORT_ERR_BAD_MAGIC
    sm (GSU_IMPORT_ERROR), r3
    return
@magic_ok:

    ; Validate 1 <= entry_count <= 256
    from r3
    sub #1
    bge :+
    nop
    iwt r3, #SFX_IMPORT_ERR_BAD_COUNT
    sm (GSU_IMPORT_ERROR), r3
    return
:
    iwt r6, #257
    from r3
    cmp r6
    blt @count_ok
    nop
    iwt r3, #SFX_IMPORT_ERR_BAD_COUNT
    sm (GSU_IMPORT_ERROR), r3
    return
@count_ok:

    ; Store runtime .tab metadata & compute shifted 16/32 texel heights
    sm (gsu_runtime_tab_count), r3
    sm (gsu_runtime_atlas_width), r4
    gsu_stack_push r3
    move r1, r5
    call gsu_iso_set_stride_shift r1
    gsu_stack_pop r3

    ; 2. Copy `entry_count` 8-byte descriptors from $71:8008 -> $70:TEXTURE_TABLE_RAM
    iwt r1, #(BANK71_TAB_ADDR + SFX_TAB_HEADER_BYTES)
    iwt r2, #TEXTURE_TABLE_RAM
    move r12, r3
    iwt r13, #@copy_tab_loop
@copy_tab_loop:
    ibt r0, #1
    ramb
    to r4
    ldw (r1)
    inc r1
    inc r1
    to r5
    ldw (r1)
    inc r1
    inc r1
    to r6
    ldw (r1)
    inc r1
    inc r1
    to r7
    ldw (r1)
    inc r1
    inc r1

    ibt r0, #0
    ramb
    from r4
    stw (r2)
    inc r2
    inc r2
    from r5
    stw (r2)
    inc r2
    inc r2
    from r6
    stw (r2)
    inc r2
    inc r2
    from r7
    stw (r2)
    inc r2
    loop
    inc r2

    ; 3. Read & validate .map dimensions at $71:8808
    ibt r0, #1
    ramb
    iwt r1, #BANK71_MAP_ADDR
    ldb (r1)
    lob
    move r4, r0             ; r4 = cols
    inc r1
    ldb (r1)
    lob
    move r5, r0             ; r5 = rows
    ibt r0, #0
    ramb

    from r4
    sub #4
    bge :+
    nop
    bra @bad_map_dim
    nop
:
    iwt r6, #17
    from r4
    cmp r6
    blt :+
    nop
    bra @bad_map_dim
    nop
:
    from r5
    sub #4
    bge :+
    nop
    bra @bad_map_dim
    nop
:
    from r5
    cmp r6
    blt @map_dim_ok
    nop
@bad_map_dim:
    iwt r3, #SFX_IMPORT_ERR_BAD_DIM
    sm (GSU_IMPORT_ERROR), r3
    return
@map_dim_ok:

    ; Copy (1 + cols * rows) 8-byte records from $71:8808 -> $70:MAP_BUF
    from r4
    umult r5                ; r0 = cols * rows (16..256)
    inc r0                  ; +1 for 8-byte map_header -> 17..257 chunks
    move r12, r0
    iwt r1, #BANK71_MAP_ADDR
    iwt r2, #MAP_BUF
    iwt r13, #@copy_map_loop
@copy_map_loop:
    ibt r0, #1
    ramb
    to r4
    ldw (r1)
    inc r1
    inc r1
    to r5
    ldw (r1)
    inc r1
    inc r1
    to r6
    ldw (r1)
    inc r1
    inc r1
    to r7
    ldw (r1)
    inc r1
    inc r1

    ibt r0, #0
    ramb
    from r4
    stw (r2)
    inc r2
    inc r2
    from r5
    stw (r2)
    inc r2
    inc r2
    from r6
    stw (r2)
    inc r2
    inc r2
    from r7
    stw (r2)
    inc r2
    loop
    inc r2

    ; 4. Pre-bake 4-way skirt drops & active archetype mask in $70:MAP_BUF
    iwt r1, #MAP_BUF
    call gsu_iso_prebake_map r1

    ; 5. Apply camera initialization policy from GSU_LOAD_MODE:
    ;    SFX_LOAD_MODE_MAP (2) preserves yaw if camera was already initialized;
    ;    otherwise full reset sets yaw = 1. Both reset focus=(128,80), cam=(0,0).
    lm r1, (GSU_LOAD_MODE)
    from r1
    sub #SFX_LOAD_MODE_MAP
    bne @full_cam_init
    nop
    ; Check that ISO_CAM sin_yaw/cos_yaw is non-zero (already initialized)
    lm r2, (ISO_CAM + 2)
    lm r3, (ISO_CAM + 4)
    from r2
    or r3
    beq @full_cam_init
    nop
    bra @reset_cam_translation
    nop

@full_cam_init:
    iwt r1, #ISO_CAM
    iwt r2, #1
    call iso_camera_set_yaw r1, r2

@reset_cam_translation:
    iwt r1, #(ISO_CAM + 6)
    iwt r0, #GSU_ISO_CENTER_X
    stw (r1)                ; center_x
    inc r1
    inc r1
    iwt r0, #GSU_ISO_CENTER_Y
    stw (r1)                ; center_y
    inc r1
    inc r1
    iwt r0, #0
    stw (r1)                ; cam_x = 0
    inc r1
    inc r1
    stw (r1)                ; cam_z = 0

    ; 6. Force archetype recompilation on next Pass 0 & mark scene initialized
    iwt r0, #$FFFF
    sm (CACHED_YAW), r0
    iwt r0, #1
    sm (GSU_INIT_FLAG), r0
    iwt r3, #SFX_IMPORT_OK
    sm (GSU_IMPORT_ERROR), r3
    return
endfunction
.endif ; !GSU_ISO_USE_ROM_TEXTURES

.endif ; !GSU_ISO_NO_DEFAULT_BUFFERS

; ==============================================================================
; gsu_iso_update_origin
; Computes the centered screen-space grid origin (`origin_x`, `origin_z` at
; `map_ptr + 2` and `map_ptr + 4`) so the geometric center `(cols/2, rows/2)`
; lands at `(cam_ptr->center_x, cam_ptr->center_y)`. Supports 4x4..16x16 maps.
;
; In:
;   map_ptr = r1: Pointer to map_header in Bank $70 GSURAM
;   cam_ptr = r2: Pointer to iso_camera in Bank $70 GSURAM
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9
; ==============================================================================
function gsu_iso_update_origin map_ptr, cam_ptr
    register map_ptr = r1, cam_ptr = r2

    move r3, cam_ptr
    inc r3
    inc r3
    to r5
    ldw (r3)                ; r5 = sin_yaw (Q2.14)
    inc r3
    inc r3
    to r7
    ldw (r3)                ; r7 = cos_yaw (Q2.14)

    ; sx_x_q5 = cos_yaw >> 4
    move r8, r7
    with r8
    asr
    with r8
    asr
    with r8
    asr
    with r8
    asr

    ; sx_y_q5 = sin_yaw >> 5
    move r9, r5
    with r9
    asr
    with r9
    asr
    with r9
    asr
    with r9
    asr
    with r9
    asr

    ; cols
    ldb (map_ptr)
    lob
    move r6, r0             ; mul_b = cols

    from r8
    lmult
    move r8, r4             ; r8 = off_x_q5 = cols * sx_x_q5

    from r9
    lmult
    move r9, r4             ; r9 = off_y_q5 = cols * sx_y_q5

    ; sz_x_q5 = -(sin_yaw >> 4)
    move r3, r5
    with r3
    asr
    with r3
    asr
    with r3
    asr
    with r3
    asr
    with r3
    not
    inc r3

    ; sz_y_q5 = cos_yaw >> 5
    with r7
    asr
    with r7
    asr
    with r7
    asr
    with r7
    asr
    with r7
    asr

    ; rows
    move r5, map_ptr
    inc r5
    ldb (r5)
    lob
    move r6, r0             ; mul_b = rows

    from r3
    lmult
    with r8
    add r4                  ; off_x_q5 += rows * sz_x_q5

    from r7
    lmult
    with r9
    add r4                  ; off_y_q5 += rows * sz_y_q5

    ; Divide by 2 for midpoint (cols/2, rows/2) and round (+16, >> 5)
    with r8
    asr
    with r9
    asr

    iwt r0, #16
    with r8
    add r0
    with r8
    asr
    with r8
    asr
    with r8
    asr
    with r8
    asr
    with r8
    asr                     ; r8 = off_x (pixels)

    with r9
    add r0
    with r9
    asr
    with r9
    asr
    with r9
    asr
    with r9
    asr
    with r9
    asr                     ; r9 = off_y (pixels)

    ; Read center_x (+6) and center_y (+8)
    from cam_ptr
    to r3
    add #6
    ldw (r3)                ; r0 = center_x
    sub r8
    move r5, r0             ; r5 = origin_x = center_x - off_x

    inc r3
    inc r3
    ldw (r3)                ; r0 = center_y
    sub r9                  ; r0 = origin_z = center_y - off_y

    ; Store origin_x (+2) and origin_z (+4) into map_ptr
    move r3, map_ptr
    inc r3
    inc r3
    move r6, r0             ; r6 = origin_z
    from r5
    stw (r3)
    inc r3
    inc r3
    from r6
    stw (r3)

    return
endfunction

; ==============================================================================
; gsu_iso_compile_quad_face
; Compiles a quad face into cached_traps at compile_out_ptr (+64).
; In:
;   r1 = v0_ptr
;   r2 = v1_ptr
;   r3 = v2_ptr
;   r4 = v3_ptr
;   r5 = uv_mode
;   r6 = tex_id
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_compile_quad_face v0_p, v1_p, v2_p, v3_p, uv_m, tex_i
    register v0_p = r1, v1_p = r2, v2_p = r3, v3_p = r4, uv_m = r5, tex_i = r6

    iwt r7, #gsu_iso_face_def
    iwt r0, #(FACE_DEF_FLAG_QUAD | FACE_DEF_FLAG_PTRS)
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    from uv_m
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    from tex_i
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    lm r0, (gsu_runtime_stride_shift)
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7

    ; Read cos_yaw and sin_yaw from cam_ptr (gsu_iso_render_frame + 0)
    iwt r8, #gsu_iso_render_frame
    ldw (r8)
    inc r0
    inc r0
    move r8, r0
    ldw (r8)            ; sin_yaw
    move r9, r0
    inc r8
    inc r8
    ldw (r8)            ; cos_yaw
    from r0
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r9
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0
    from v0_p
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

    ; V1
    from v1_p
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

    ; V2
    from v2_p
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
    lm r0, (gsu_v32_shifted)
    stw (r7)            ; v2
    inc r7
    inc r7

    ; V3
    from v3_p
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
    lm r0, (gsu_v32_shifted)
    stw (r7)            ; v3

    ; Call compile_face_traps:
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r2, r0         ; r2 = compile_out_ptr
    iwt r1, #gsu_iso_face_def
    call compile_face_traps r1, r2

    ; If r3 == 0 (culled): return
    with r3
    add #0
    beq @quad_done
    nop

    ; Add r3 to arch_trap_count (+66)
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    with r0
    add r3
    from r0
    stw (r7)

    ; Advance compile_out_ptr by r3 * 26:
    ; 26 = (r3 << 4) + (r3 << 3) + (r3 << 1)
    move r1, r3
    with r1
    add r1              ; r3 * 2
    move r2, r1         ; * 2
    with r1
    add r1              ; * 4
    with r1
    add r1              ; * 8
    move r4, r1         ; * 8
    with r1
    add r1              ; * 16
    with r1
    add r4              ; * 24
    with r1
    add r2              ; * 26
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    with r0
    add r1
    from r0
    stw (r7)            ; compile_out_ptr += r3 * 26

@quad_done:
    return
endfunction

; ==============================================================================
; gsu_iso_compile_panel_quad
; Compiles a vertical edge panel quad face into cached_traps at compile_out_ptr (+64).
; In:
;   r1 = v0_ptr
;   r2 = v1_ptr
;   r3 = v2_ptr
;   r4 = v3_ptr
;   r5 = uv_mode
;   r6 = v_height (16 << gsu_runtime_stride_shift for 1h, 32 << gsu_runtime_stride_shift for 2h)
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_compile_panel_quad v0_p, v1_p, v2_p, v3_p, uv_m, v_ht
    register v0_p = r1, v1_p = r2, v2_p = r3, v3_p = r4, uv_m = r5, v_ht = r6

    iwt r7, #gsu_iso_face_def
    iwt r0, #(FACE_DEF_FLAG_QUAD | FACE_DEF_FLAG_PTRS)
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    from uv_m
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    iwt r0, #2          ; tex_id = 2 (panel_tex_id slot)
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    lm r0, (gsu_runtime_stride_shift)
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7

    ; Read cos_yaw and sin_yaw from cam_ptr (gsu_iso_render_frame + 0)
    iwt r8, #gsu_iso_render_frame
    ldw (r8)
    inc r0
    inc r0
    move r8, r0
    ldw (r8)            ; sin_yaw
    move r9, r0
    inc r8
    inc r8
    ldw (r8)            ; cos_yaw
    from r0
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r9
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0: Top-Left (u0=0, v0=0)
    from v0_p
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

    ; V1: Top-Right (u1=32<<8, v1=0)
    from v1_p
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

    ; V2: Bottom-Right (u2=32<<8, v2=v_ht)
    from v2_p
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
    from v_ht
    stw (r7)            ; v2 = v_ht
    inc r7
    inc r7

    ; V3: Bottom-Left (u3=0, v3=v_ht)
    from v3_p
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
    from v_ht
    stw (r7)            ; v3 = v_ht

    ; Call compile_face_traps:
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r2, r0         ; r2 = compile_out_ptr
    iwt r1, #gsu_iso_face_def
    call compile_face_traps r1, r2

    ; If r3 == 0 (culled): return
    with r3
    add #0
    beq @panel_quad_done
    nop

    ; Add r3 to arch_trap_count (+66)
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    with r0
    add r3
    from r0
    stw (r7)

    ; Advance compile_out_ptr by r3 * 26:
    move r1, r3
    with r1
    add r1              ; r3 * 2
    move r2, r1         ; * 2
    with r1
    add r1              ; * 4
    with r1
    add r1              ; * 8
    move r4, r1         ; * 8
    with r1
    add r1              ; * 16
    with r1
    add r4              ; * 24
    with r1
    add r2              ; * 26
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    with r0
    add r1
    from r0
    stw (r7)            ; compile_out_ptr += r3 * 26

@panel_quad_done:
    return
endfunction

; ==============================================================================
; gsu_iso_compile_fin_quad
; Compiles a 16x32 vertical foliage cutout fin quad face into cached_traps
; at compile_out_ptr (+64).
; In:
;   r1 = v0_ptr
;   r2 = v1_ptr
;   r3 = v2_ptr
;   r4 = v3_ptr
;   r5 = uv_mode
;   r6 = tex_id (2 for panel_tex_id slot)
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_compile_fin_quad v0_p, v1_p, v2_p, v3_p, uv_m, tex_i
    register v0_p = r1, v1_p = r2, v2_p = r3, v3_p = r4, uv_m = r5, tex_i = r6

    iwt r7, #gsu_iso_face_def
    iwt r0, #(FACE_DEF_FLAG_QUAD | FACE_DEF_FLAG_PTRS)
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    from uv_m
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    from tex_i
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    lm r0, (gsu_runtime_stride_shift)
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7

    ; Read cos_yaw and sin_yaw from cam_ptr (gsu_iso_render_frame + 0)
    iwt r8, #gsu_iso_render_frame
    ldw (r8)
    inc r0
    inc r0
    move r8, r0
    ldw (r8)            ; sin_yaw
    move r9, r0
    inc r8
    inc r8
    ldw (r8)            ; cos_yaw
    from r0
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r9
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; Determine if v0_p is K_top (+148)
    iwt r8, #gsu_iso_render_frame + 148
    from v0_p
    cmp r8
    bne @fin_rev_uv
    nop

    ; Normal: K at v0/v3 (u=0), M at v1/v2 (u=16<<8)
    iwt r8, #0
    iwt r9, #$1000
    bra @fin_uv_set
    nop

@fin_rev_uv:
    ; Reversed: M at v0/v3 (u=16<<8), K at v1/v2 (u=0)
    iwt r8, #$1000
    iwt r9, #0

@fin_uv_set:
    ; V0: Top-Left
    from v0_p
    stw (r7)            ; v0.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    from r8
    stw (r7)            ; u0
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v0 = 0
    inc r7
    inc r7

    ; V1: Top-Right
    from v1_p
    stw (r7)            ; v1.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    from r9
    stw (r7)            ; u1
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; v1 = 0
    inc r7
    inc r7

    ; V2: Bottom-Right
    from v2_p
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    from r9
    stw (r7)            ; u2
    inc r7
    inc r7
    lm r0, (gsu_v32_shifted)
    stw (r7)            ; v2
    inc r7
    inc r7

    ; V3: Bottom-Left
    from v3_p
    stw (r7)            ; v3.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    from r8
    stw (r7)            ; u3
    inc r7
    inc r7
    lm r0, (gsu_v32_shifted)
    stw (r7)            ; v3

    ; Call compile_face_traps:
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r2, r0         ; r2 = compile_out_ptr
    iwt r1, #gsu_iso_face_def
    call compile_face_traps r1, r2

    ; If r3 == 0 (culled): return
    with r3
    add #0
    beq @fin_done
    nop

    ; Add r3 to arch_trap_count (+66)
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    with r0
    add r3
    from r0
    stw (r7)

    ; Advance compile_out_ptr by r3 * 26:
    ; 26 = (r3 << 4) + (r3 << 3) + (r3 << 1)
    move r1, r3
    with r1
    add r1              ; r3 * 2
    move r2, r1         ; * 2
    with r1
    add r1              ; * 4
    with r1
    add r1              ; * 8
    move r4, r1         ; * 8
    with r1
    add r1              ; * 16
    with r1
    add r4              ; * 24
    with r1
    add r2              ; * 26
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    with r0
    add r1
    from r0
    stw (r7)            ; compile_out_ptr += r3 * 26

@fin_done:
    return
endfunction

; ==============================================================================
; gsu_iso_compile_tri_face
; Compiles a triangular face into cached_traps at compile_out_ptr (+64).
; In:
;   r1 = v0_ptr
;   r2 = v1_ptr
;   r3 = v2_ptr
;   r4 = uv_mode
;   r5 = tex_id
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_compile_tri_face v0_p, v1_p, v2_p, uv_m, tex_i
    register v0_p = r1, v1_p = r2, v2_p = r3, uv_m = r4, tex_i = r5

    iwt r7, #gsu_iso_face_def
    iwt r0, #FACE_DEF_FLAG_PTRS
    stw (r7)            ; flags (+0)
    inc r7
    inc r7
    from uv_m
    stw (r7)            ; uv_mode (+2)
    inc r7
    inc r7
    from tex_i
    stw (r7)            ; tex_id (+4)
    inc r7
    inc r7
    lm r0, (gsu_runtime_stride_shift)
    stw (r7)            ; stride_shift (+6)
    inc r7
    inc r7
    ; Read cos_yaw and sin_yaw from cam_ptr (gsu_iso_render_frame + 0)
    iwt r8, #gsu_iso_render_frame
    ldw (r8)
    inc r0
    inc r0
    move r8, r0
    ldw (r8)            ; sin_yaw
    move r9, r0
    inc r8
    inc r8
    ldw (r8)            ; cos_yaw
    from r0
    stw (r7)            ; cos_yaw (+8)
    inc r7
    inc r7
    from r9
    stw (r7)            ; sin_yaw (+10)
    inc r7
    inc r7

    ; V0
    from v0_p
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

    ; V1
    from v1_p
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

    ; V2
    from v2_p
    stw (r7)            ; v2.x_or_ptr
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; pad
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; u2 = 0
    inc r7
    inc r7
    lm r0, (gsu_v32_shifted)
    stw (r7)            ; v2

    ; Call compile_face_traps:
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r2, r0         ; r2 = compile_out_ptr
    iwt r1, #gsu_iso_face_def
    call compile_face_traps r1, r2

    ; If r3 == 0 (culled): return
    with r3
    add #0
    beq @tri_done
    nop

    ; Add r3 to arch_trap_count (+66)
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    with r0
    add r3
    from r0
    stw (r7)

    ; Advance compile_out_ptr by r3 * 26:
    move r1, r3
    with r1
    add r1              ; * 2
    move r2, r1
    with r1
    add r1              ; * 4
    with r1
    add r1              ; * 8
    move r4, r1         ; * 8
    with r1
    add r1              ; * 16
    with r1
    add r4              ; * 24
    with r1
    add r2              ; * 26
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    with r0
    add r1
    from r0
    stw (r7)            ; compile_out_ptr += r3 * 26

@tri_done:
    return
endfunction

; ==============================================================================
; Foliage Cutout Fin Helpers (PRIM_FOLIAGE_CROSS)
; Emits single 16x32 vertical fin with camera-facing winding & UV_MODE_WALL_*
; ==============================================================================
function gsu_iso_compile_fin_n
    ; Read sin_yaw from cam_ptr (frame + 0) + 2
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @fin_n_west
    nop

    ; sin_yaw >= 0 (looking from East):
    ; V0 = K_top (+148), V1 = MN_top (+84), V2 = MN_bot (lat + 64), V3 = K_bot (+144)
    iwt r1, #gsu_iso_render_frame + 148
    iwt r2, #gsu_iso_render_frame + 84
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #64
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_iso_render_frame + 144
    bra @fin_n_compile
    nop

@fin_n_west:
    ; sin_yaw < 0 (looking from West):
    ; V0 = MN_top (+84), V1 = K_top (+148), V2 = K_bot (+144), V3 = MN_bot (lat + 64)
    iwt r1, #gsu_iso_render_frame + 84
    iwt r2, #gsu_iso_render_frame + 148
    iwt r3, #gsu_iso_render_frame + 144
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #64
    with r0
    add r6
    move r4, r0

@fin_n_compile:
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #2          ; panel_tex_id
    call gsu_iso_compile_fin_quad r1, r2, r3, r4, r5, r6
    return
endfunction

function gsu_iso_compile_fin_s
    ; Read sin_yaw from cam_ptr (frame + 0) + 2
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @fin_s_west
    nop

    ; sin_yaw >= 0 (looking from East):
    ; V0 = MS_top (+92), V1 = K_top (+148), V2 = K_bot (+144), V3 = MS_bot (lat + 72)
    iwt r1, #gsu_iso_render_frame + 92
    iwt r2, #gsu_iso_render_frame + 148
    iwt r3, #gsu_iso_render_frame + 144
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #72
    with r0
    add r6
    move r4, r0
    bra @fin_s_compile
    nop

@fin_s_west:
    ; sin_yaw < 0 (looking from West):
    ; V0 = K_top (+148), V1 = MS_top (+92), V2 = MS_bot (lat + 72), V3 = K_bot (+144)
    iwt r1, #gsu_iso_render_frame + 148
    iwt r2, #gsu_iso_render_frame + 92
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #72
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_iso_render_frame + 144

@fin_s_compile:
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #2          ; panel_tex_id
    call gsu_iso_compile_fin_quad r1, r2, r3, r4, r5, r6
    return
endfunction

function gsu_iso_compile_fin_e
    ; Read cos_yaw from cam_ptr (frame + 0) + 4
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @fin_e_north
    nop

    ; cos_yaw >= 0 (looking from South):
    ; V0 = K_top (+148), V1 = ME_top (+88), V2 = ME_bot (lat + 68), V3 = K_bot (+144)
    iwt r1, #gsu_iso_render_frame + 148
    iwt r2, #gsu_iso_render_frame + 88
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #68
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_iso_render_frame + 144
    bra @fin_e_compile
    nop

@fin_e_north:
    ; cos_yaw < 0 (looking from North):
    ; V0 = ME_top (+88), V1 = K_top (+148), V2 = K_bot (+144), V3 = ME_bot (lat + 68)
    iwt r1, #gsu_iso_render_frame + 88
    iwt r2, #gsu_iso_render_frame + 148
    iwt r3, #gsu_iso_render_frame + 144
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #68
    with r0
    add r6
    move r4, r0

@fin_e_compile:
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #2          ; panel_tex_id
    call gsu_iso_compile_fin_quad r1, r2, r3, r4, r5, r6
    return
endfunction

function gsu_iso_compile_fin_w
    ; Read cos_yaw from cam_ptr (frame + 0) + 4
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @fin_w_north
    nop

    ; cos_yaw >= 0 (looking from South):
    ; V0 = MW_top (+96), V1 = K_top (+148), V2 = K_bot (+144), V3 = MW_bot (lat + 76)
    iwt r1, #gsu_iso_render_frame + 96
    iwt r2, #gsu_iso_render_frame + 148
    iwt r3, #gsu_iso_render_frame + 144
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #76
    with r0
    add r6
    move r4, r0
    bra @fin_w_compile
    nop

@fin_w_north:
    ; cos_yaw < 0 (looking from North):
    ; V0 = K_top (+148), V1 = MW_top (+96), V2 = MW_bot (lat + 76), V3 = K_bot (+144)
    iwt r1, #gsu_iso_render_frame + 148
    iwt r2, #gsu_iso_render_frame + 96
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #76
    with r0
    add r6
    move r3, r0
    iwt r4, #gsu_iso_render_frame + 144

@fin_w_compile:
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #2          ; panel_tex_id
    call gsu_iso_compile_fin_quad r1, r2, r3, r4, r5, r6
    return
endfunction

; ==============================================================================
; gsu_iso_compile_panel_n
; Compiles North Edge Panel template (1h or 2h).
; In: r1 = is_2h (0 or 1)
; ==============================================================================
function gsu_iso_compile_panel_n is_2h
    register is_2h = r1, lat_ptr = r14

    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move lat_ptr, r0

    ; Reserve word for trap_count
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = cur_entry_ptr
    inc r0
    inc r0
    stw (r7)            ; compile_out_ptr += 2

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    stw (r7)            ; arch_trap_count = 0

    ; entry_offset = cur_entry_ptr - arch_traps_ptr
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; panel_idx = 0 | is_2h
    from is_2h
    to r9
    add is_2h           ; is_2h * 2
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_lut
    with r7
    add r9
    from r2
    stw (r7)

    with is_2h
    add #0
    bne :+
    nop
    iwt r13, #32        ; 1h elev
    lm r6, (gsu_v16_shifted)
    bra :++
    nop
:
    iwt r13, #48        ; 2h elev
    lm r6, (gsu_v32_shifted)
:

    iwt r5, #UV_MODE_WALL_NS
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @north_rev
    nop
    ; cos_yaw >= 0: V0=E0, V1=E1, V2=B1, V3=B0
    move r1, lat_ptr
    with r1
    add r13             ; E0
    move r2, r1
    inc r2
    inc r2
    inc r2
    inc r2              ; E1
    move r3, lat_ptr
    inc r3
    inc r3
    inc r3
    inc r3              ; B1
    move r4, lat_ptr    ; B0
    bra @north_do
    nop
@north_rev:
    ; cos_yaw < 0: V0=E1, V1=E0, V2=B0, V3=B1
    move r2, lat_ptr
    with r2
    add r13             ; E0
    move r1, r2
    inc r1
    inc r1
    inc r1
    inc r1              ; E1
    move r3, lat_ptr    ; B0
    move r4, lat_ptr
    inc r4
    inc r4
    inc r4
    inc r4              ; B1
@north_do:
    gsu_stack_push r8
    call gsu_iso_compile_panel_quad r1, r2, r3, r4, r5, r6
    gsu_stack_pop r8

    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    from r0
    stw (r8)
    return
endfunction

; ==============================================================================
; gsu_iso_compile_panel_e
; Compiles East Edge Panel template (1h or 2h).
; In: r1 = is_2h (0 or 1)
; ==============================================================================
function gsu_iso_compile_panel_e is_2h
    register is_2h = r1, lat_ptr = r14

    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move lat_ptr, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    inc r0
    inc r0
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; panel_idx = 2 | is_2h -> byte offset = 4 + is_2h * 2
    from is_2h
    to r9
    add is_2h
    iwt r0, #4
    with r9
    add r0
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_lut
    with r7
    add r9
    from r2
    stw (r7)

    with is_2h
    add #0
    bne :+
    nop
    iwt r13, #32
    lm r6, (gsu_v16_shifted)
    bra :++
    nop
:
    iwt r13, #48
    lm r6, (gsu_v32_shifted)
:

    iwt r5, #UV_MODE_WALL_EW
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @east_rev
    nop
    ; sin_yaw >= 0: V0=E2, V1=E1, V2=B1, V3=B2
    move r1, lat_ptr
    with r1
    add r13
    iwt r0, #8
    with r1
    add r0              ; E2
    move r2, lat_ptr
    with r2
    add r13
    inc r2
    inc r2
    inc r2
    inc r2              ; E1
    move r3, lat_ptr
    inc r3
    inc r3
    inc r3
    inc r3              ; B1
    move r4, lat_ptr
    iwt r0, #8
    with r4
    add r0              ; B2
    bra @east_do
    nop
@east_rev:
    ; sin_yaw < 0: V0=E1, V1=E2, V2=B2, V3=B1
    move r1, lat_ptr
    with r1
    add r13
    inc r1
    inc r1
    inc r1
    inc r1              ; E1
    move r2, lat_ptr
    with r2
    add r13
    iwt r0, #8
    with r2
    add r0              ; E2
    move r3, lat_ptr
    iwt r0, #8
    with r3
    add r0              ; B2
    move r4, lat_ptr
    inc r4
    inc r4
    inc r4
    inc r4              ; B1
@east_do:
    gsu_stack_push r8
    call gsu_iso_compile_panel_quad r1, r2, r3, r4, r5, r6
    gsu_stack_pop r8

    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    from r0
    stw (r8)
    return
endfunction

; ==============================================================================
; gsu_iso_compile_panel_s
; Compiles South Edge Panel template (1h or 2h).
; In: r1 = is_2h (0 or 1)
; ==============================================================================
function gsu_iso_compile_panel_s is_2h
    register is_2h = r1, lat_ptr = r14

    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move lat_ptr, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    inc r0
    inc r0
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; panel_idx = 4 | is_2h -> byte offset = 8 + is_2h * 2
    from is_2h
    to r9
    add is_2h
    iwt r0, #8
    with r9
    add r0
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_lut
    with r7
    add r9
    from r2
    stw (r7)

    with is_2h
    add #0
    bne :+
    nop
    iwt r13, #32
    lm r6, (gsu_v16_shifted)
    bra :++
    nop
:
    iwt r13, #48
    lm r6, (gsu_v32_shifted)
:

    iwt r5, #UV_MODE_WALL_NS
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @south_rev
    nop
    ; cos_yaw >= 0: V0=E3, V1=E2, V2=B2, V3=B3
    move r1, lat_ptr
    with r1
    add r13
    iwt r0, #12
    with r1
    add r0              ; E3
    move r2, lat_ptr
    with r2
    add r13
    iwt r0, #8
    with r2
    add r0              ; E2
    move r3, lat_ptr
    iwt r0, #8
    with r3
    add r0              ; B2
    move r4, lat_ptr
    iwt r0, #12
    with r4
    add r0              ; B3
    bra @south_do
    nop
@south_rev:
    ; cos_yaw < 0: V0=E2, V1=E3, V2=B3, V3=B2
    move r1, lat_ptr
    with r1
    add r13
    iwt r0, #8
    with r1
    add r0              ; E2
    move r2, lat_ptr
    with r2
    add r13
    iwt r0, #12
    with r2
    add r0              ; E3
    move r3, lat_ptr
    iwt r0, #12
    with r3
    add r0              ; B3
    move r4, lat_ptr
    iwt r0, #8
    with r4
    add r0              ; B2
@south_do:
    gsu_stack_push r8
    call gsu_iso_compile_panel_quad r1, r2, r3, r4, r5, r6
    gsu_stack_pop r8

    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    from r0
    stw (r8)
    return
endfunction

; ==============================================================================
; gsu_iso_compile_panel_w
; Compiles West Edge Panel template (1h or 2h).
; In: r1 = is_2h (0 or 1)
; ==============================================================================
function gsu_iso_compile_panel_w is_2h
    register is_2h = r1, lat_ptr = r14

    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move lat_ptr, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    inc r0
    inc r0
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; panel_idx = 6 | is_2h -> byte offset = 12 + is_2h * 2
    from is_2h
    to r9
    add is_2h
    iwt r0, #12
    with r9
    add r0
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_lut
    with r7
    add r9
    from r2
    stw (r7)

    with is_2h
    add #0
    bne :+
    nop
    iwt r13, #32
    lm r6, (gsu_v16_shifted)
    bra :++
    nop
:
    iwt r13, #48
    lm r6, (gsu_v32_shifted)
:

    iwt r5, #UV_MODE_WALL_EW
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @west_rev
    nop
    ; sin_yaw >= 0: V0=E3, V1=E0, V2=B0, V3=B3
    move r1, lat_ptr
    with r1
    add r13
    iwt r0, #12
    with r1
    add r0              ; E3
    move r2, lat_ptr
    with r2
    add r13             ; E0
    move r3, lat_ptr    ; B0
    move r4, lat_ptr
    iwt r0, #12
    with r4
    add r0              ; B3
    bra @west_do
    nop
@west_rev:
    ; sin_yaw < 0: V0=E0, V1=E3, V2=B3, V3=B0
    move r1, lat_ptr
    with r1
    add r13             ; E0
    move r2, lat_ptr
    with r2
    add r13
    iwt r0, #12
    with r2
    add r0              ; E3
    move r3, lat_ptr
    iwt r0, #12
    with r3
    add r0              ; B3
    move r4, lat_ptr    ; B0
@west_do:
    gsu_stack_push r8
    call gsu_iso_compile_panel_quad r1, r2, r3, r4, r5, r6
    gsu_stack_pop r8

    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    from r0
    stw (r8)
    return
endfunction

; ==============================================================================
; gsu_iso_compile_edge_panels
; Compiles all 8 canonical Edge Panel templates into arch_buf.
; ==============================================================================
function gsu_iso_compile_edge_panels
    iwt r1, #0
    call gsu_iso_compile_panel_n r1
    iwt r1, #1
    call gsu_iso_compile_panel_n r1

    iwt r1, #0
    call gsu_iso_compile_panel_e r1
    iwt r1, #1
    call gsu_iso_compile_panel_e r1

    iwt r1, #0
    call gsu_iso_compile_panel_s r1
    iwt r1, #1
    call gsu_iso_compile_panel_s r1

    iwt r1, #0
    call gsu_iso_compile_panel_w r1
    iwt r1, #1
    call gsu_iso_compile_panel_w r1
    return
endfunction

; ==============================================================================
; mg_cover_round src, kind, neg
; Converts a Q2.14 trig value to a template basis component rounded AWAY from
; zero (ceil of magnitude) and stores it at (r3), then advances r3 by 2.
;   kind = 1: value = src / 2^9  (32 * trig)
;   kind = 2: value = src / 2^10 (16 * trig)
;   neg  = 1: store the negated result
; Clobbers: r0, r4
; ==============================================================================
.macro mg_cover_round src, kind, neg
    from src
    add #0
    bpl :+
    nop
    ; negative: -ceil(-src / 2^k)
    not
    inc r0
    iwt r4, #((1 << (8 + kind)) - 1)
    add r4
    hib
    lsr
  .if kind = 2
    lsr
  .endif
    not
    inc r0
    bra :++
    nop
:
    ; non-negative: ceil(src / 2^k)
    iwt r4, #((1 << (8 + kind)) - 1)
    add r4
    hib
    lsr
  .if kind = 2
    lsr
  .endif
:
  .if neg
    not
    inc r0
  .endif
    stw (r3)
    inc r3
    inc r3
.endmacro

; ==============================================================================
; gsu_iso_compile_archetypes
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
function gsu_iso_compile_archetypes cam_ptr, basis_ptr, lattice_ptr, arch_traps_ptr, cached_yaw_ptr : recompiled_flag
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

    ; Default runtime stride_shift to 6 if uninitialized in standalone unit tests
    lm r0, (gsu_v32_shifted)
    moves r0, r0
    bne @stride_ready
    nop
    iwt r0, #6
    sm (gsu_runtime_stride_shift), r0
    iwt r0, #(16 << 6)
    sm (gsu_v16_shifted), r0
    iwt r0, #(32 << 6)
    sm (gsu_v32_shifted), r0
@stride_ready:

    ; Load active archetype mask. If 0 (uninitialized / standalone test), treat as $FFFF (compile all)
    iwt r7, #gsu_iso_active_arch_mask
    ldw (r7)
    from r0
    sub #0
    bne :+
    nop
    iwt r0, #$FFFF
:
    iwt r7, #gsu_iso_effective_arch_mask
    stw (r7)

    ; Save inputs in frame
    iwt r7, #gsu_iso_render_frame
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

    ; --------------------------------------------------------------------------
    ; Re-round the template basis away from zero (ceil of magnitude).
    ;   gsu_iso_render places cell anchors at round(exact position) (Q11.5), so
    ;   the spacing between neighboring anchors is floor(a) or ceil(a) of the
    ;   exact step a. A template edge of round(a) can be 1px shorter than the
    ;   spacing and leave a crack; ceil(|a|) is never shorter, so neighbors
    ;   overlap by < 1px instead and painter's order resolves the overlap.
    ;     Sx = ( cm(32 cos), cm(16 sin) ),  Sz = ( -cm(32 sin), cm(16 cos) )
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame
    ldw (r7)            ; r0 = cam_ptr
    add #2
    move r8, r0
    to r1
    ldw (r8)            ; r1 = sin_yaw (Q2.14)
    inc r8
    inc r8
    to r2
    ldw (r8)            ; r2 = cos_yaw (Q2.14)
    iwt r7, #gsu_iso_render_frame + 2
    to r3
    ldw (r7)            ; r3 = basis_ptr
    mg_cover_round r2, 1, 0   ; Sx.x = cm(cos >> 9)
    mg_cover_round r1, 2, 0   ; Sx.y = cm(sin >> 10)
    mg_cover_round r1, 1, 1   ; Sz.x = -cm(sin >> 9)
    mg_cover_round r2, 2, 0   ; Sz.y = cm(cos >> 10)

    ; Populate 28-point canonical lattice into lattice_ptr
    iwt r7, #gsu_iso_render_frame
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
    iwt r7, #gsu_iso_render_frame
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
    iwt r7, #gsu_iso_render_frame + 6
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
    iwt r0, #28
    with r3
    sub r0
    from r3
    stw (r7)            ; bbox_ymin (includes up to 2h elevation headroom)
    inc r7
    inc r7
    from r4
    stw (r7)            ; bbox_ymax

    ; --------------------------------------------------------------------------
    ; 4. Compile PRIM_FLAT (Horizontal 32x32 quad at y=0)
    ;    Vertices: C0, C1, C2, C3 (Clockwise)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame
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

    iwt r7, #gsu_iso_render_frame + 4
    to r14
    ldw (r7)            ; r14 = lattice_ptr

    iwt r7, #gsu_iso_face_def

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
    lm r0, (gsu_runtime_stride_shift)
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
    lm r0, (gsu_v32_shifted)
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
    lm r0, (gsu_v32_shifted)
    stw (r7)            ; v3

    ; Compile PRIM_FLAT into arch_traps_ptr + flat_traps (+2)
    iwt r1, #gsu_iso_face_def
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    inc r0
    inc r0
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_iso_render_frame + 6
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
    iwt r7, #gsu_iso_render_frame
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

    iwt r7, #gsu_iso_render_frame + 4
    to r14
    ldw (r7)            ; r14 = lattice_ptr

    iwt r7, #gsu_iso_face_def
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
    iwt r7, #gsu_iso_face_def + 12 ; ptr -> v0
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
    lm r0, (gsu_v16_shifted)            ; 1h = 16 texels
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
    lm r0, (gsu_v16_shifted)
    stw (r7)            ; v3

    ; Compile ARCH_SKIRT_NS into arch_traps_ptr + skirt_ns_traps (+108)
    iwt r1, #gsu_iso_face_def
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r11, #108
    with r0
    add r11
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_iso_render_frame + 6
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
    iwt r7, #gsu_iso_render_frame
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

    iwt r7, #gsu_iso_render_frame + 4
    to r14
    ldw (r7)            ; r14 = lattice_ptr

    iwt r7, #gsu_iso_face_def
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
    iwt r7, #gsu_iso_face_def + 12 ; ptr -> v0
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
    lm r0, (gsu_v16_shifted)
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
    lm r0, (gsu_v16_shifted)
    stw (r7)            ; v3

    ; Compile ARCH_SKIRT_EW into arch_traps_ptr + skirt_ew_traps (+214)
    iwt r1, #gsu_iso_face_def
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)            ; r0 = arch_traps_ptr
    iwt r11, #214
    with r0
    add r11
    move r2, r0
    call compile_face_traps r1, r2

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r11, #212
    with r0
    add r11
    move r7, r0
    from r3
    stw (r7)            ; store skirt_ew_count (+212)

    ; --------------------------------------------------------------------------
    ; 7. Initialize Dynamic Archetype Lookup Table (arch_lut at +326):
    ; --------------------------------------------------------------------------
    ; Offset 0..3: PRIM_FLAT (all rotations point to flat_count at offset 0)
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r1, #326
    with r0
    add r1
    move r7, r0         ; r7 = &arch_lut[0]
    iwt r0, #0
    stw (r7)            ; lut[0] = 0 (PRIM_FLAT rot 0)
    inc r7
    inc r7
    stw (r7)            ; lut[1] = 0 (rot 1)
    inc r7
    inc r7
    stw (r7)            ; lut[2] = 0 (rot 2)
    inc r7
    inc r7
    stw (r7)            ; lut[3] = 0 (rot 3)
    inc r7
    inc r7

    ; Initialize remaining 60 entries (4..63) to 0 (default: 0 traps)
    iwt r12, #60
@init_lut_loop:
    iwt r0, #0
    stw (r7)
    inc r7
    inc r7
    dec r12
    bne @init_lut_loop
    nop

    ; Initialize compile_out_ptr (+64) = arch_traps_ptr + arch_traps_table::arch_buf
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r1, #arch_traps_table::arch_buf
    with r0
    add r1
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 64
    from r1
    stw (r7)

    ; --------------------------------------------------------------------------
    ; 8. Precompute Elevated Midpoints at +1h and +2h in frame (+68):
    ;    MN (64), ME (68), MS (72), MW (76) in lattice_ptr (frame + 4)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r11, r0        ; r11 = lattice_ptr
    iwt r0, #64
    with r11
    add r0              ; r11 = &lattice_ptr[16] (MN)

    iwt r12, #0         ; k = 0..3
@elev_mid_loop:
    ; Read M_k.x
    ldw (r11)
    move r1, r0         ; r1 = x
    inc r11
    inc r11
    ; Read M_k.y
    ldw (r11)
    move r2, r0         ; r2 = y
    inc r11
    inc r11

    ; k * 4:
    move r3, r12
    with r3
    add r3
    with r3
    add r3              ; r3 = k * 4

    ; Store M_k at +1h (x, y - 14) in frame + 68 + k * 4:
    iwt r7, #gsu_iso_render_frame + 68
    with r7
    add r3
    from r1
    stw (r7)            ; x
    inc r7
    inc r7
    move r0, r2
    iwt r6, #14
    with r0
    sub r6              ; y - 14
    from r0
    stw (r7)            ; y - 14

    ; Store M_k at +2h (x, y - 28) in frame + 84 + k * 4:
    iwt r7, #gsu_iso_render_frame + 84
    with r7
    add r3
    from r1
    stw (r7)            ; x
    inc r7
    inc r7
    move r0, r2
    iwt r6, #28
    with r0
    sub r6              ; y - 28
    from r0
    stw (r7)            ; y - 28

    inc r12
    iwt r0, #4
    from r12
    sub r0
    blt @elev_mid_loop
    nop

    ; --------------------------------------------------------------------------
    ; 9. Compile Wedge & Stair Archetypes across Rotations R = 0..3:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #$00FE
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@compile_universal_archetypes
    jmp r13
    nop
:

    iwt r7, #gsu_iso_render_frame + 140
    iwt r0, #0
    from r0
    stw (r7)            ; frame::cur_rot = 0

@rot_compile_loop:
    ; Load lattice_ptr from frame + 4
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r14, r0        ; r14 = lattice_ptr

    ; Read R from frame + 140
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    move r12, r0        ; r12 = R (0..3)

    ; Setup corner vertex pointers in frame::v_ptrs (+100..+123):
    ; For corner k in 0..3:
    ;   ik = (k + R) & 3
    ;   B_k  = lattice_ptr + ik * 4
    ;   E1_k = lattice_ptr + (ik + 8) * 4
    ;   E2_k = lattice_ptr + (ik + 12) * 4
    iwt r9, #0          ; k = 0..3
@corner_setup_loop:
    from r9
    add r12
    move r8, r0
    iwt r6, #3
    with r8
    and r6              ; r8 = ik = (k + R) & 3

    ; ik * 4:
    with r8
    add r8
    with r8
    add r8              ; r8 = ik * 4

    ; B_k = lattice_ptr + ik * 4:
    move r1, r14
    with r1
    add r8              ; r1 = &B_k

    ; E1_k = B_k + 32 (8 * 4):
    move r2, r1
    iwt r0, #32
    with r2
    add r0              ; r2 = &E1_k

    ; E2_k = B_k + 48 (12 * 4):
    move r3, r1
    iwt r0, #48
    with r3
    add r0              ; r3 = &E2_k

    ; Store in frame::v_ptrs:
    ; B_k at +100 + k * 2:
    move r6, r9
    with r6
    add r6              ; k * 2
    iwt r7, #gsu_iso_render_frame + 100
    with r7
    add r6
    from r1
    stw (r7)            ; &B_k

    ; E1_k at +108 + k * 2:
    iwt r7, #gsu_iso_render_frame + 108
    with r7
    add r6
    from r2
    stw (r7)            ; &E1_k

    ; E2_k at +116 + k * 2:
    iwt r7, #gsu_iso_render_frame + 116
    with r7
    add r6
    from r3
    stw (r7)            ; &E2_k

    inc r9
    iwt r0, #4
    from r9
    sub r0
    blt @corner_setup_loop
    nop

    ; Setup midpoint pointers for PRIM_STAIRS in frame::m_ptrs (+124..+139):
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    move r12, r0

    ; mW:
    move r0, r12
    iwt r6, #3
    with r0
    add r6
    iwt r6, #3
    with r0
    and r6              ; r0 = mW = (R + 3) & 3
    with r0
    add r0
    with r0
    add r0              ; r0 = mW * 4
    move r8, r0         ; r8 = mW * 4

    ; mE:
    move r0, r12
    inc r0
    iwt r6, #3
    with r0
    and r6              ; r0 = mE = (R + 1) & 3
    with r0
    add r0
    with r0
    add r0              ; r0 = mE * 4
    move r9, r0         ; r9 = mE * 4

    ; MB_W = lattice_ptr + 64 + mW * 4
    move r1, r14
    iwt r0, #64
    with r1
    add r0
    with r1
    add r8
    iwt r7, #gsu_iso_render_frame + 124
    from r1
    stw (r7)            ; MB_W (+124)

    ; MB_E = lattice_ptr + 64 + mE * 4
    move r1, r14
    iwt r0, #64
    with r1
    add r0
    with r1
    add r9
    inc r7
    inc r7
    from r1
    stw (r7)            ; MB_E (+126)

    ; M1_W = frame + 68 + mW * 4
    iwt r1, #gsu_iso_render_frame + 68
    with r1
    add r8
    inc r7
    inc r7
    from r1
    stw (r7)            ; M1_W (+128)

    ; M1_E = frame + 68 + mE * 4
    iwt r1, #gsu_iso_render_frame + 68
    with r1
    add r9
    inc r7
    inc r7
    from r1
    stw (r7)            ; M1_E (+130)

    ; M2_W = frame + 84 + mW * 4
    iwt r1, #gsu_iso_render_frame + 84
    with r1
    add r8
    inc r7
    inc r7
    from r1
    stw (r7)            ; M2_W (+132)

    ; M2_E = frame + 84 + mE * 4
    iwt r1, #gsu_iso_render_frame + 84
    with r1
    add r9
    inc r7
    inc r7
    from r1
    stw (r7)            ; M2_E (+134)

    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_STRAIGHT (1h: arch=1) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_WEDGE_STRAIGHT)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_wedge_straight
    jmp r13
    nop
:
    ; lut index = (1 << 2) | R = 4 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    with r0
    add r0
    move r9, r0         ; r9 = lut byte offset for arch 1

    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = entry_ptr
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)            ; cur_entry_ptr = entry_ptr

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0         ; r2 = entry_offset

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)            ; arch_lut[(1 << 2) | R] = entry_offset

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Face 1: Top sloped quad: E1_0, E1_1, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0         ; E1_0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0         ; E1_1
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0         ; B_2
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; B_3
    iwt r5, #UV_MODE_SLOPE
    iwt r6, #0          ; top_tex
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Face 2: Back quad: E1_1, E1_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 110
    ldw (r7)
    move r1, r0         ; E1_1
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r2, r0         ; E1_0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0         ; B_0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; B_1
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1          ; skirt_tex
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Face 3: Left (west-side) cheek tri: E1_0, B_3, B_0
    ;   Wound like every other vertical face (top-near, bottom-far, bottom-near)
    ;   so it survives backface culling when it faces the camera.
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0         ; E1_0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r2, r0         ; B_3
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0         ; B_0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1          ; skirt_tex
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Face 4: Right (east-side) cheek tri: E1_1, B_1, B_2 (same winding as other walls)
    iwt r7, #gsu_iso_render_frame + 110
    ldw (r7)
    move r1, r0         ; E1_1
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0         ; B_1
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0         ; B_2
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1          ; skirt_tex
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count at (entry_ptr):
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_wedge_straight:
    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_STRAIGHT_2H (2h: arch=2) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_WEDGE_STRAIGHT_2H)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_wedge_straight_2h
    jmp r13
    nop
:
    ; lut index = (2 << 2) | R = 8 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #8
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Top sloped quad: E2_0, E2_1, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_SLOPE
    iwt r6, #0
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back quad: E2_1, E2_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Left (west-side) cheek tri: E2_0, B_3, B_0
    ;   Wound like every other vertical face (top-near, bottom-far, bottom-near)
    ;   so it survives backface culling when it faces the camera.
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0         ; E2_0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r2, r0         ; B_3
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0         ; B_0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Right (east-side) cheek tri: E2_1, B_1, B_2 (same winding as other walls)
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_wedge_straight_2h:
    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_OUTER (1h: arch=3) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_WEDGE_OUTER)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_wedge_outer
    jmp r13
    nop
:
    ; lut index = (3 << 2) | R = 12 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #12
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (sloped): E1_0, B_1, B_3
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (low base): B_1, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 1: E1_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r2, r0
    inc r7
    inc r7
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_NS
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 2: E1_0, B_3, B_0
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_wedge_outer:
    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_OUTER_2H (2h: arch=4) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_WEDGE_OUTER_2H)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_wedge_outer_2h
    jmp r13
    nop
:
    ; lut index = (4 << 2) | R = 16 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #16
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (sloped): E2_0, B_1, B_3
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (low base): B_1, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 1: E2_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r2, r0
    inc r7
    inc r7
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_NS
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Cheek 2: E2_0, B_3, B_0
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_wedge_outer_2h:
    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_INNER (1h: arch=5) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_WEDGE_INNER)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_wedge_inner
    jmp r13
    nop
:
    ; lut index = (5 << 2) | R = 20 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #20
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (high horizontal): E1_0, E1_1, E1_3
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 114
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (sloped down): E1_1, B_2, E1_3
    iwt r7, #gsu_iso_render_frame + 110
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 114
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Back wall 1: E1_1, E1_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 110
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back wall 2: E1_0, E1_3, B_3, B_0
    iwt r7, #gsu_iso_render_frame + 108
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 114
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Low-side cheek (south face, corner 3 high -> corner 2 low): E1_3, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 114
    ldw (r7)
    move r1, r0         ; E1_3
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r2, r0         ; B_2
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0         ; B_3
    iwt r4, #UV_MODE_WALL_NS
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Low-side cheek (east face, corner 1 high -> corner 2 low): E1_1, B_1, B_2
    iwt r7, #gsu_iso_render_frame + 110
    ldw (r7)
    move r1, r0         ; E1_1
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0         ; B_1
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0         ; B_2
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_wedge_inner:
    ; --------------------------------------------------------------------------
    ; Compile PRIM_WEDGE_INNER_2H (2h: arch=6) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_WEDGE_INNER_2H)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_wedge_inner_2h
    jmp r13
    nop
:
    ; lut index = (6 << 2) | R = 24 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #24
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Tri 1 (high horizontal): E2_0, E2_1, E2_3
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 122
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_HORIZONTAL
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Tri 2 (sloped down): E2_1, B_2, E2_3
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 122
    ldw (r7)
    move r3, r0
    iwt r4, #UV_MODE_SLOPE
    iwt r5, #0
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Back wall 1: E2_1, E2_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back wall 2: E2_0, E2_3, B_3, B_0
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 122
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Low-side cheek (south face, corner 3 high -> corner 2 low): E2_3, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 122
    ldw (r7)
    move r1, r0         ; E2_3
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r2, r0         ; B_2
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0         ; B_3
    iwt r4, #UV_MODE_WALL_NS
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Low-side cheek (east face, corner 1 high -> corner 2 low): E2_1, B_1, B_2
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0         ; E2_1
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0         ; B_1
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0         ; B_2
    iwt r4, #UV_MODE_WALL_EW
    iwt r5, #1
    call gsu_iso_compile_tri_face r1, r2, r3, r4, r5

    ; Store trap count
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_wedge_inner_2h:
    ; --------------------------------------------------------------------------
    ; Compile PRIM_STAIRS (arch=7) for rotation R:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_STAIRS)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_stairs
    jmp r13
    nop
:
    ; lut index = (7 << 2) | R = 28 + R
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    iwt r6, #28
    with r0
    add r6
    with r0
    add r0
    move r9, r0

    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #326
    with r0
    add r6
    with r0
    add r9
    move r7, r0
    from r2
    stw (r7)

    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Step 1 Lower Tread (+1h): M1_W, M1_E, E1_2, E1_3
    iwt r7, #gsu_iso_render_frame + 128
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 112
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Riser 1 (0 to +1h): E1_3, E1_2, B_2, B_3
    iwt r7, #gsu_iso_render_frame + 114
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 112
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Step 2 Upper Tread (+2h): E2_0, E2_1, M2_E, M2_W
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 134
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + 132
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Riser 2 (+1h to +2h): M2_W, M2_E, M1_E, M1_W
    iwt r7, #gsu_iso_render_frame + 132
    ldw (r7)
    move r1, r0
    inc r7
    inc r7
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 130
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + 128
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Back Wall (0 to +2h): E2_1, E2_0, B_0, B_1
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r3, r0
    inc r7
    inc r7
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; West Cheek Lower Quad: M1_W, E1_3, B_3, MB_W
    ;   (full rectangle under the lower tread; a triangle left half of it open)
    iwt r7, #gsu_iso_render_frame + 128
    ldw (r7)
    move r1, r0         ; M1_W
    iwt r7, #gsu_iso_render_frame + 114
    ldw (r7)
    move r2, r0         ; E1_3
    iwt r7, #gsu_iso_render_frame + 106
    ldw (r7)
    move r3, r0         ; B_3
    iwt r7, #gsu_iso_render_frame + 124
    ldw (r7)
    move r4, r0         ; MB_W
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; West Cheek Upper Quad: E2_0, M2_W, MB_W, B_0
    iwt r7, #gsu_iso_render_frame + 116
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 132
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 124
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + 100
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; East Cheek Lower Quad: E1_2, M1_E, MB_E, B_2
    iwt r7, #gsu_iso_render_frame + 112
    ldw (r7)
    move r1, r0         ; E1_2
    iwt r7, #gsu_iso_render_frame + 130
    ldw (r7)
    move r2, r0         ; M1_E
    iwt r7, #gsu_iso_render_frame + 126
    ldw (r7)
    move r3, r0         ; MB_E
    iwt r7, #gsu_iso_render_frame + 104
    ldw (r7)
    move r4, r0         ; B_2
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; East Cheek Upper Quad: E2_1, B_1, MB_E, M2_E
    iwt r7, #gsu_iso_render_frame + 118
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 102
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 126
    ldw (r7)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + 134
    ldw (r7)
    move r4, r0
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_STAIRS:
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 152
    ldw (r7)
    move r7, r0
    from r1
    stw (r7)

@skip_stairs:
    ; Next rotation R = R + 1
    iwt r7, #gsu_iso_render_frame + 140
    ldw (r7)
    inc r0
    from r0
    stw (r7)
    iwt r6, #4
    from r0
    sub r6
    blt @rot_loop_cont
    nop
    iwt r13, #@compile_universal_archetypes
    jmp r13
    nop
@rot_loop_cont:
    iwt r13, #@rot_compile_loop
    jmp r13
    nop

@compile_universal_archetypes:

    ; ==========================================================================
    ; 10. Compile PRIM_LIQUID_SHALLOW (arch=8):
    ; ==========================================================================
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_LIQUID_SHALLOW)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_liquid_shallow
    jmp r13
    nop
:
    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = entry_ptr
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)            ; cur_entry_ptr = entry_ptr

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0         ; r2 = entry_offset

    ; Store entry_offset in arch_lut for all 4 rotations (A=8: 8 * 4 * 2 = 64)
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 8 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Submerged Riverbed Quad at y=0 (C0, C1, C2, C3, uv_mode=0, tex_id=1 [skirt_tex_id])
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r1, r0         ; C0 (lattice_ptr + 0)
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; C1 (lattice_ptr + 4)
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; C2 (lattice_ptr + 8)
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; C3 (lattice_ptr + 12)
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #1          ; skirt_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Translucent Water Surface Quad at +1h (ELEV1_C0..C3, uv_mode=0, tex_id=0 [top_tex_id])
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #32         ; LATTICE_ELEV1_C0 = 8 * 4 = 32
    with r0
    add r6
    move r1, r0         ; ELEV1_C0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; ELEV1_C1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; ELEV1_C2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; ELEV1_C3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_LIQUID_SHALLOW:
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0         ; r1 = trap_count
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 8 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0         ; r2 = entry_offset
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)            ; store trap count at entry_ptr

@skip_liquid_shallow:
    ; ==========================================================================
    ; 11. Compile PRIM_LIQUID_DEEP (arch=9):
    ; ==========================================================================
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_LIQUID_DEEP)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_liquid_deep
    jmp r13
    nop
:
    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0         ; r8 = entry_ptr
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)            ; cur_entry_ptr = entry_ptr

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0         ; r2 = entry_offset

    ; Store entry_offset in arch_lut for all 4 rotations (A=9: 9 * 4 * 2 = 72)
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 9 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; Submerged Riverbed Quad at y=0 (C0, C1, C2, C3, uv_mode=0, tex_id=1 [skirt_tex_id])
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r1, r0         ; C0 (lattice_ptr + 0)
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; C1 (lattice_ptr + 4)
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; C2 (lattice_ptr + 8)
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; C3 (lattice_ptr + 12)
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #1          ; skirt_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Translucent Water Surface Quad at +2h (ELEV2_C0..C3, uv_mode=0, tex_id=0 [top_tex_id])
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #48         ; LATTICE_ELEV2_C0 = 12 * 4 = 48
    with r0
    add r6
    move r1, r0         ; ELEV2_C0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; ELEV2_C1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; ELEV2_C2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; ELEV2_C3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_LIQUID_DEEP:
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 9 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)

@skip_liquid_deep:
    ; ==========================================================================
    ; 12. Compile PRIM_PILLAR (arch=10):
    ; ==========================================================================
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_PILLAR)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_pillar
    jmp r13
    nop
:
    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; Store entry_offset in arch_lut for all 4 rotations (A=10: 10 * 4 * 2 = 80)
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 10 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; 2. Camera-Facing NS Column Wall:
    ; P0 = lat + 80 (20*4), P1 = +84, P2 = +88, P3 = +92
    ; T0 = lat + 96 (24*4), T1 = +100, T2 = +104, T3 = +108
    ; Read cos_yaw from cam_ptr (frame + 0) + 4
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; r0 = cos_yaw
    with r0
    add #0
    blt @pillar_wall_north
    nop

    ; South Wall: T3(108), T2(104), P2(88), P3(92)
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #108
    with r0
    add r6
    move r1, r0         ; T3
    move r0, r14
    iwt r6, #104
    with r0
    add r6
    move r2, r0         ; T2
    move r0, r14
    iwt r6, #88
    with r0
    add r6
    move r3, r0         ; P2
    move r0, r14
    iwt r6, #92
    with r0
    add r6
    move r4, r0         ; P3
    bra @pillar_ns_wall_done
    nop

@pillar_wall_north:
    ; North Wall: T1(100), T0(96), P0(80), P1(84)
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #100
    with r0
    add r6
    move r1, r0         ; T1
    move r0, r14
    iwt r6, #96
    with r0
    add r6
    move r2, r0         ; T0
    move r0, r14
    iwt r6, #80
    with r0
    add r6
    move r3, r0         ; P0
    move r0, r14
    iwt r6, #84
    with r0
    add r6
    move r4, r0         ; P1

@pillar_ns_wall_done:
    iwt r5, #UV_MODE_WALL_NS
    iwt r6, #1          ; skirt_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; 3. Camera-Facing EW Column Wall:
    ; Read sin_yaw from cam_ptr (frame + 0) + 2
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; r0 = sin_yaw
    with r0
    add #0
    blt @pillar_wall_west
    nop

    ; East Wall: T2(104), T1(100), P1(84), P2(88)
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #104
    with r0
    add r6
    move r1, r0         ; T2
    move r0, r14
    iwt r6, #100
    with r0
    add r6
    move r2, r0         ; T1
    move r0, r14
    iwt r6, #84
    with r0
    add r6
    move r3, r0         ; P1
    move r0, r14
    iwt r6, #88
    with r0
    add r6
    move r4, r0         ; P2
    bra @pillar_ew_wall_done
    nop

@pillar_wall_west:
    ; West Wall: T0(96), T3(108), P3(92), P0(80)
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    move r14, r0
    iwt r6, #96
    with r0
    add r6
    move r1, r0         ; T0
    move r0, r14
    iwt r6, #108
    with r0
    add r6
    move r2, r0         ; T3
    move r0, r14
    iwt r6, #92
    with r0
    add r6
    move r3, r0         ; P3
    move r0, r14
    iwt r6, #80
    with r0
    add r6
    move r4, r0         ; P0

@pillar_ew_wall_done:
    iwt r5, #UV_MODE_WALL_EW
    iwt r6, #1          ; skirt_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; 4. Column Top Cap (16x16) at +2h: T0(96), T1(100), T2(104), T3(108)
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #96
    with r0
    add r6
    move r1, r0         ; T0
    inc r0
    inc r0
    inc r0
    inc r0
    move r2, r0         ; T1
    inc r0
    inc r0
    inc r0
    inc r0
    move r3, r0         ; T2
    inc r0
    inc r0
    inc r0
    inc r0
    move r4, r0         ; T3
    iwt r5, #UV_MODE_HORIZONTAL
    iwt r6, #0          ; top_tex_id
    call gsu_iso_compile_quad_face r1, r2, r3, r4, r5, r6

    ; Store trap count for PRIM_PILLAR:
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 10 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)

@skip_pillar:
    ; ==========================================================================
    ; 13. Compile PRIM_FOLIAGE_CROSS (arch=11):
    ; ==========================================================================
    iwt r7, #gsu_iso_effective_arch_mask
    ldw (r7)
    iwt r6, #(1 << PRIM_FOLIAGE_CROSS)
    from r0
    and r6
    bne :+
    nop
    iwt r13, #@skip_foliage_cross
    jmp r13
    nop
:
    ; Precompute Center points K_bot and K_top:
    ; K_bot.x = MN.x + MW.x
    ; K_bot.y = MN.y + MW.y
    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #64
    with r0
    add r6
    move r8, r0         ; &MN
    ldw (r8)            ; MN.x
    move r1, r0
    inc r8
    inc r8
    ldw (r8)            ; MN.y
    move r2, r0

    iwt r7, #gsu_iso_render_frame + 4
    ldw (r7)
    iwt r6, #76
    with r0
    add r6
    move r8, r0         ; &MW
    ldw (r8)            ; MW.x
    with r1
    add r0              ; r1 = K_bot.x = MN.x + MW.x
    inc r8
    inc r8
    ldw (r8)            ; MW.y
    with r2
    add r0              ; r2 = K_bot.y = MN.y + MW.y

    ; Store K_bot at frame + 144
    iwt r7, #gsu_iso_render_frame + 144
    from r1
    stw (r7)            ; K_bot.x
    inc r7
    inc r7
    from r2
    stw (r7)            ; K_bot.y

    ; Store K_top at frame + 148: (K_bot.x, K_bot.y - 28)
    inc r7
    inc r7
    from r1
    stw (r7)            ; K_top.x
    inc r7
    inc r7
    move r0, r2
    iwt r6, #28
    with r0
    sub r6
    from r0
    stw (r7)            ; K_top.y

    ; entry_ptr = compile_out_ptr (+64)
    iwt r7, #gsu_iso_render_frame + 64
    ldw (r7)
    move r8, r0
    iwt r7, #gsu_iso_render_frame + 152
    from r8
    stw (r7)

    ; entry_offset = entry_ptr - arch_traps_ptr
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    from r8
    sub r0
    move r2, r0

    ; Store entry_offset in arch_lut for all 4 rotations (A=11: 11 * 4 * 2 = 88)
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 11 * 4 * 2)
    with r0
    add r6
    move r7, r0
    from r2
    stw (r7)            ; rot 0
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 1
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 2
    inc r7
    inc r7
    from r2
    stw (r7)            ; rot 3

    ; Reserve word for trap_count:
    inc r8
    inc r8
    iwt r7, #gsu_iso_render_frame + 64
    from r8
    stw (r7)

    ; Reset arch_trap_count = 0
    iwt r7, #gsu_iso_render_frame + 66
    iwt r0, #0
    from r0
    stw (r7)

    ; 2. Emit 4 fins in Yaw-Quadrant Back-to-Front order:
    ; (The 2 receding fins first, then the 2 camera-facing fins)
    ; Step A: Receding NS fin (Fin_N if cos_yaw >= 0, else Fin_S)
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @foliage_fin_step_a_alt
    nop
    call gsu_iso_compile_fin_n
    bra @foliage_fin_step_a_done
    nop
@foliage_fin_step_a_alt:
    call gsu_iso_compile_fin_s
@foliage_fin_step_a_done:

    ; Step B: Receding EW fin (Fin_W if sin_yaw >= 0, else Fin_E)
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @foliage_fin_step_b_alt
    nop
    call gsu_iso_compile_fin_w
    bra @foliage_fin_step_b_done
    nop
@foliage_fin_step_b_alt:
    call gsu_iso_compile_fin_e
@foliage_fin_step_b_done:

    ; Step C: Camera-facing NS fin (Fin_S if cos_yaw >= 0, else Fin_N)
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    iwt r6, #4
    with r0
    add r6
    move r7, r0
    ldw (r7)            ; cos_yaw
    with r0
    add #0
    blt @foliage_fin_step_c_alt
    nop
    call gsu_iso_compile_fin_s
    bra @foliage_fin_step_c_done
    nop
@foliage_fin_step_c_alt:
    call gsu_iso_compile_fin_n
@foliage_fin_step_c_done:

    ; Step D: Camera-facing EW fin (Fin_E if sin_yaw >= 0, else Fin_W)
    iwt r7, #gsu_iso_render_frame
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @foliage_fin_step_d_alt
    nop
    call gsu_iso_compile_fin_e
    bra @foliage_fin_step_d_done
    nop
@foliage_fin_step_d_alt:
    call gsu_iso_compile_fin_w
@foliage_fin_step_d_done:

    ; Store trap count for PRIM_FOLIAGE_CROSS:
    iwt r7, #gsu_iso_render_frame + 66
    ldw (r7)
    move r1, r0
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    iwt r6, #(arch_traps_table::arch_lut + 11 * 4 * 2)
    with r0
    add r6
    move r7, r0
    ldw (r7)
    move r2, r0
    iwt r7, #gsu_iso_render_frame + 6
    ldw (r7)
    with r0
    add r2
    move r7, r0
    from r1
    stw (r7)

@skip_foliage_cross:
    ; Compile 8 canonical Edge Panel templates into arch_buf:
    call gsu_iso_compile_edge_panels

@rot_compile_done:
    ; Restore ROMBR to bank 4 for texture atlas
    ibt r0, #4
    romb

    ; Return 1 (recompiled)
    iwt r3, #1
    return
endfunction

; ==============================================================================
; gsu_iso_prebake_map
; Pre-computes 4-way static neighbor skirt drops into cell bytes +6 (drop_ns)
; and +7 (drop_ew) for all cells in map_ptr, and records the active archetype
; bitmask into gsu_iso_active_arch_mask. Marks map_header::reserved (+6) as $BACE.
;
; In:
;   map_ptr = r1: Pointer to map struct in GSURAM
;
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_prebake_map map_ptr
    register map_ptr = r1

    ; cols = ldb(map_ptr + 0)
    move r7, map_ptr
    ldb (r7)
    lob
    move r2, r0         ; r2 = cols

    ; rows = ldb(map_ptr + 1)
    inc r7
    ldb (r7)
    lob
    move r3, r0         ; r3 = rows

    ; active_mask = 1 (PRIM_FLAT is always active)
    iwt r4, #1          ; r4 = active_mask

    ; cell_ptr = map_ptr + 8
    move r14, map_ptr
    iwt r0, #8
    with r14
    add r0              ; r14 = current cell_ptr

    ; Outer loop: j = 0..rows-1
    iwt r5, #0          ; r5 = j
@j_loop:
    ; Inner loop: i = 0..cols-1
    iwt r6, #0          ; r6 = i
@i_loop:
    ; Read cell base_height (cell_ptr + 0)
    move r7, r14
    ldb (r7)
    lob
    move r8, r0         ; r8 = base_height

    ; Read cell archetype_id (cell_ptr + 1)
    inc r7
    ldb (r7)
    lob
    iwt r7, #$001F
    with r0
    and r7
    move r7, r0         ; r7 = arch (0..31)

    ; Accumulate into active_mask: active_mask |= (1 << arch)
    iwt r11, #1
    from r7
    sub #0
    beq @shift_done
    nop
    move r0, r7
@shift_loop:
    with r11
    add r11
    dec r0
    bne @shift_loop
    nop
@shift_done:
    with r4
    or r11              ; r4 = active_mask |= (1 << arch)

    ; cell_solid_h: if arch == PRIM_LIQUID_SHALLOW or PRIM_LIQUID_DEEP -> 0, else base_height (r8)
    move r9, r8         ; r9 = cell_solid_h
    iwt r0, #PRIM_LIQUID_SHALLOW
    from r7
    cmp r0
    beq @cell_is_liquid
    nop
    iwt r0, #PRIM_LIQUID_DEEP
    from r7
    cmp r0
    bne @cell_not_liquid
    nop
@cell_is_liquid:
    iwt r9, #0
@cell_not_liquid:

    ; 1. South neighbor (j + 1, i): drop_s
    move r7, r5
    inc r7              ; j_nb = j + 1
    move r8, r6         ; i_nb = i
    iwt r12, #@ret_s
    iwt r11, #@get_nb_height
    jmp r11
    nop
@ret_s:
    from r9
    sub r0              ; cell_solid_h - nb_h
    bpl :+
    nop
    iwt r0, #0
:
    iwt r7, #15
    from r7
    cmp r0
    bge :+
    nop
    move r0, r7
:
    move r13, r0        ; r13 = drop_s (0..15)

    ; 2. North neighbor (j - 1, i): drop_n
    move r7, r5
    dec r7              ; j_nb = j - 1
    move r8, r6         ; i_nb = i
    iwt r12, #@ret_n
    iwt r11, #@get_nb_height
    jmp r11
    nop
@ret_n:
    from r9
    sub r0              ; cell_solid_h - nb_h
    bpl :+
    nop
    iwt r0, #0
:
    iwt r7, #15
    from r7
    cmp r0
    bge :+
    nop
    move r0, r7
:
    ; pack drop_ns = drop_s | (drop_n << 4)
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0              ; drop_n << 4
    with r0
    or r13              ; r0 = drop_s | (drop_n << 4)
    from r14
    to r7
    add #6
    from r0
    stb (r7)            ; cell_ptr + 6 = drop_ns

    ; 3. East neighbor (j, i + 1): drop_e
    move r7, r5         ; j_nb = j
    move r8, r6
    inc r8              ; i_nb = i + 1
    iwt r12, #@ret_e
    iwt r11, #@get_nb_height
    jmp r11
    nop
@ret_e:
    from r9
    sub r0              ; cell_solid_h - nb_h
    bpl :+
    nop
    iwt r0, #0
:
    iwt r7, #15
    from r7
    cmp r0
    bge :+
    nop
    move r0, r7
:
    move r13, r0        ; r13 = drop_e (0..15)

    ; 4. West neighbor (j, i - 1): drop_w
    move r7, r5         ; j_nb = j
    move r8, r6
    dec r8              ; i_nb = i - 1
    iwt r12, #@ret_w
    iwt r11, #@get_nb_height
    jmp r11
    nop
@ret_w:
    from r9
    sub r0              ; cell_solid_h - nb_h
    bpl :+
    nop
    iwt r0, #0
:
    iwt r7, #15
    from r7
    cmp r0
    bge :+
    nop
    move r0, r7
:
    ; pack drop_ew = drop_e | (drop_w << 4)
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0              ; drop_w << 4
    with r0
    or r13              ; r0 = drop_e | (drop_w << 4)
    from r14
    to r7
    add #7
    from r0
    stb (r7)            ; cell_ptr + 7 = drop_ew

    ; Advance cell_ptr += 8
    iwt r0, #8
    with r14
    add r0

    ; Advance i:
    inc r6
    from r6
    cmp r2              ; i < cols?
    bge :+
    nop
    iwt r11, #@i_loop
    jmp r11
    nop
:

    ; Advance j:
    inc r5
    from r5
    cmp r3              ; j < rows?
    bge :+
    nop
    iwt r11, #@j_loop
    jmp r11
    nop
:

    ; Store accumulated active_mask into gsu_iso_active_arch_mask:
    iwt r7, #gsu_iso_active_arch_mask
    from r4
    stw (r7)

    ; Mark map as pre-baked: store $BACE in map_header::reserved (map_ptr + 6)
    from map_ptr
    to r7
    add #6
    iwt r0, #$BACE
    stw (r7)

    return

; Internal helper: reads neighbor surface elevation at (r8=i_nb, r7=j_nb)
; Returns surface height in r0 (0 if OOB). Returns via jmp r12.
@get_nb_height:
    from r7
    add #0
    bmi @nb_oob
    nop
    from r7
    cmp r3              ; j_nb >= rows?
    bge @nb_oob
    nop
    from r8
    add #0
    bmi @nb_oob
    nop
    from r8
    cmp r2              ; i_nb >= cols?
    bge @nb_oob
    nop

    ; in bounds: offset = (j_nb * cols + i_nb) * 8
    from r7
    mult r2             ; r0 = j_nb * cols
    add r8              ; + i_nb
    add r0
    add r0
    add r0              ; * 8
    move r11, map_ptr
    with r11
    add #8              ; skip header
    with r11
    add r0              ; r11 = nb cell_ptr

    ldb (r11)           ; nb base_height
    lob
    move r8, r0         ; r8 = nb base_height
    inc r11
    ldb (r11)           ; nb arch
    lob
    iwt r11, #$001F
    with r0
    and r11             ; r0 = nb arch
    iwt r11, #PRIM_LIQUID_SHALLOW
    from r0
    cmp r11
    bne :+
    nop
    inc r8              ; shallow liquid surface = base_height + 1
    bra @nb_ret
    nop
:
    iwt r11, #PRIM_LIQUID_DEEP
    from r0
    cmp r11
    bne @nb_ret
    nop
    inc r8
    inc r8              ; deep liquid surface = base_height + 2
@nb_ret:
    move r0, r8
    jmp r12
    nop

@nb_oob:
    iwt r0, #0
    jmp r12
    nop
endfunction

; ==============================================================================
; gsu_iso_stamp_edge_panel
; Stamps pre-compiled Edge Panel trapezoids for a given compass edge (0..3).
; In:
;   r1 = edge_idx (0=North, 1=East, 2=South, 3=West)
; Modifies:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r14
; ==============================================================================
function gsu_iso_stamp_edge_panel edge_idx
    register edge_idx = r1

    ; Determine is_2h (0 for 1h, 1 for 2h):
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_flags
    ldw (r7)
    iwt r2, #PANEL_TALL_2H
    with r0
    and r2
    beq :+
    nop
    iwt r2, #1          ; is_2h = 1
    bra :++
    nop
:
    iwt r2, #0          ; is_2h = 0
:

    ; panel_idx = (edge_idx << 1) | is_2h
    from edge_idx
    to r8
    add edge_idx        ; edge_idx << 1
    with r8
    or r2               ; panel_idx (0..7)
    with r8
    add r8              ; byte offset in panel_lut (panel_idx * 2)

    ; Read entry_offset from panel_lut:
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_lut
    with r7
    add r8
    ldw (r7)
    move r2, r0         ; r2 = entry_offset

    ; Read trap_count from arch_traps_ptr + entry_offset:
    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    with r0
    add r2
    move r1, r0         ; r1 = entry_ptr
    ldw (r1)
    move r9, r0         ; r9 = trap_count
    with r9
    add #0
    bne @panel_has_traps
    nop
    return
@panel_has_traps:
    inc r1
    inc r1              ; r1 = pointer to first cached_trap

    ; Determine UV offsets (u_offset, v_offset):
    ; If edge_idx & 1 == 0 (North=0, South=2): u_offset = i_cur << 13
    ; If edge_idx & 1 != 0 (East=1, West=3):   u_offset = j_cur << 13
    from edge_idx
    to r0
    and #1
    bne @panel_ew_uv
    nop

    ; NS UV:
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
    ldw (r7)
    swap
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    move r5, r0         ; r5 = u_offset
    bra @panel_v_uv
    nop

@panel_ew_uv:
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    ldw (r7)
    swap
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    with r0
    add r0
    move r5, r0         ; r5 = u_offset

@panel_v_uv:
    ; v_offset = (base_height * 16) << gsu_runtime_stride_shift:
    iwt r7, #gsu_iso_render_frame + map_render_frame::base_height
    ldw (r7)
    _gsu_iso_v_offset_16 r6, r2

    ; Read panel_tex_id:
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_tex_id
    ldw (r7)
    move r11, r0        ; r11 = panel_tex_id

    move r14, r9        ; r14 = trap counter
@panel_trap_loop:
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
    gsu_stack_push r6
    gsu_stack_push r5

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; anchor_y

    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    _gsu_iso_draw_trap

    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r11
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    beq :+
    nop
    iwt r13, #@panel_trap_loop
    jmp r13
    nop
:
    return
endfunction

.segment "GSUDATA"

; 256-byte quadrant diagonal index tables (each entry is (j << 3) | i)
.export gsu_iso_quadrant_tables
gsu_iso_quadrant_tables:
    ; Q0: cos >= 0, sin >= 0
    .byte $00, $08, $01, $10, $09, $02, $18, $11
    .byte $0A, $03, $20, $19, $12, $0B, $04, $28
    .byte $21, $1A, $13, $0C, $05, $30, $29, $22
    .byte $1B, $14, $0D, $06, $38, $31, $2A, $23
    .byte $1C, $15, $0E, $07, $39, $32, $2B, $24
    .byte $1D, $16, $0F, $3A, $33, $2C, $25, $1E
    .byte $17, $3B, $34, $2D, $26, $1F, $3C, $35
    .byte $2E, $27, $3D, $36, $2F, $3E, $37, $3F
    ; Q1: cos >= 0, sin < 0
    .byte $07, $0F, $06, $17, $0E, $05, $1F, $16
    .byte $0D, $04, $27, $1E, $15, $0C, $03, $2F
    .byte $26, $1D, $14, $0B, $02, $37, $2E, $25
    .byte $1C, $13, $0A, $01, $3F, $36, $2D, $24
    .byte $1B, $12, $09, $00, $3E, $35, $2C, $23
    .byte $1A, $11, $08, $3D, $34, $2B, $22, $19
    .byte $10, $3C, $33, $2A, $21, $18, $3B, $32
    .byte $29, $20, $3A, $31, $28, $39, $30, $38
    ; Q2: cos < 0, sin >= 0
    .byte $38, $30, $39, $28, $31, $3A, $20, $29
    .byte $32, $3B, $18, $21, $2A, $33, $3C, $10
    .byte $19, $22, $2B, $34, $3D, $08, $11, $1A
    .byte $23, $2C, $35, $3E, $00, $09, $12, $1B
    .byte $24, $2D, $36, $3F, $01, $0A, $13, $1C
    .byte $25, $2E, $37, $02, $0B, $14, $1D, $26
    .byte $2F, $03, $0C, $15, $1E, $27, $04, $0D
    .byte $16, $1F, $05, $0E, $17, $06, $0F, $07
    ; Q3: cos < 0, sin < 0
    .byte $3F, $37, $3E, $2F, $36, $3D, $27, $2E
    .byte $35, $3C, $1F, $26, $2D, $34, $3B, $17
    .byte $1E, $25, $2C, $33, $3A, $0F, $16, $1D
    .byte $24, $2B, $32, $39, $07, $0E, $15, $1C
    .byte $23, $2A, $31, $38, $06, $0D, $14, $1B
    .byte $22, $29, $30, $05, $0C, $13, $1A, $21
    .byte $28, $04, $0B, $12, $19, $20, $03, $0A
    .byte $11, $18, $02, $09, $10, $01, $08, $00

.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
.include "sprite_mask.i"

.segment "GSUCODE"

; ==============================================================================
; gsu_draw_highlight_trap
; Lightweight checkerboard flat-color trapezoid rasterizer for Tactical Cell
; Highlights (Issue #35). Stamps a 50% 1x1 checkerboard (`(x ^ y) & 1 == 0`)
; over a pre-compiled `cached_trap` using `color_idx`, allowing underlying
; terrain texture to show through while conforming pixel-for-pixel to Base
; Elevation, Shape Archetype (Flat/Stairs/Wedge/Liquid), and camera yaw.
;
; In:
;   trap_ptr   = r1: Pointer to `cached_trap` in Bank $70 GSURAM
;   anchor_x   = r2: Cell screen anchor X (signed 16-bit)
;   anchor_y   = r3: Cell screen anchor Y (signed 16-bit)
;   frame_half = r4: Active frame half (0 = Pass 0, non-zero = Pass 1)
;   color_idx  = r5: BG1 palette color index (1..15)
; Postconditions:
;   - `CMODE == 0`, `RAMBR == 0`
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13
; ==============================================================================
function gsu_draw_highlight_trap trap_ptr, anchor_x, anchor_y, frame_half, color_idx
    register trap_ptr = r1, anchor_x = r2, anchor_y = r3, frame_half = r4, color_idx = r5

    ; Set normal opaque color plotting and highlight color
    ibt r0, #0
    cmode
    from color_idx
    color

    ; y = anchor_y + dy_start (+0)
    ldw (trap_ptr)
    with anchor_y
    add r0                      ; r3 = y

    ; line_count (+2)
    from trap_ptr
    to r7
    add #2
    to r8
    ldw (r7)                    ; r8 = line_count

    ; Early exit if line_count <= 0
    from r8
    sub #1
    blt @hl_early_exit
    nop

    ; Vertical bounds check against [0 .. GSU_ISO_SCREEN_H - 1]
    from anchor_y
    add r8
    sub #1
    blt @hl_early_exit
    nop

    iwt r11, #GSU_ISO_SCREEN_H
    from anchor_y
    cmp r11
    bge @hl_early_exit
    nop

    ; Top clipping: if y < 0, skip = -y, y = 0, line_count -= skip
    moves anchor_y, anchor_y
    bpl @hl_no_top_clip
    nop
    ibt r0, #0
    sub anchor_y
    move r9, r0                 ; r9 = skip
    from r9
    cmp r8
    bge @hl_early_exit
    nop
    with r8
    sub r9
    ibt anchor_y, #0
    bra @hl_top_clip_done
    nop
@hl_no_top_clip:
    ibt r9, #0
@hl_top_clip_done:
    ; Bottom clipping: if y + line_count > GSU_ISO_SCREEN_H, clamp
    from anchor_y
    add r8
    from r11
    cmp r0
    bge @hl_bottom_ok
    nop
    from r11
    to r8
    sub anchor_y
@hl_bottom_ok:
    from r8
    sub #1
    bge @hl_bounds_ok
    nop
@hl_early_exit:
    return

@hl_bounds_ok:
    sm (gsu_hl_lines_left), r8
    sm (gsu_hl_trap_ptr), trap_ptr

    ; Compute anchor_x_eff in Q8.8 (matches draw_cached_trap.i) and max_x
    move r11, anchor_x
    moves frame_half, frame_half
    beq @hl_pass0_x
    nop
    ibt r0, #$80
    with r11
    add r0                      ; anchor_x - 128
    iwt r0, #(GSU_ISO_VIEWPORT_W - 128)
    bra @hl_store_max_x
    nop
@hl_pass0_x:
    iwt r0, #128
@hl_store_max_x:
    sm (gsu_hl_max_x), r0
    with r11
    lob
    with r11
    swap                        ; r11 = anchor_x_eff << 8 (Q8.8)

    ; Initialize xL (+4) and xR (+6)
    from trap_ptr
    to r7
    add #4
    ldw (r7)
    add r11
    sm (gsu_hl_xL), r0

    inc r7
    inc r7
    ldw (r7)
    add r11
    sm (gsu_hl_xR), r0

    ; Advance xL, xR by top-clip skip lines if r9 > 0
    moves r9, r9
    beq @hl_skip_done
    nop
    move r12, r9
    from trap_ptr
    to r7
    add #8                      ; r7 = &dxL_dy (+8)
    to r5
    ldw (r7)                    ; r5 = dxL_dy
    inc r7
    inc r7
    to r6
    ldw (r7)                    ; r6 = dxR_dy
    lm r8, (gsu_hl_xL)
    lm r9, (gsu_hl_xR)
    iwt r13, #@hl_skip_loop
@hl_skip_loop:
    with r8
    add r5
    with r9
    add r6
    loop
    nop
    sm (gsu_hl_xL), r8
    sm (gsu_hl_xR), r9
@hl_skip_done:

    ; r2 = PLOT Y coordinate (anchor_y)
    move r2, anchor_y

@hl_scanline_loop:
    lm r3, (gsu_hl_xL)
    lm r4, (gsu_hl_xR)

    ; If both xL and xR have bit 15 set (both < 0 or both >= 128): skip
    from r3
    and r4
    bmi @hl_skip_scanline
    nop

    iwt r11, #$00FF

    ; Extract integer xR in r4 (clamped to 128 if bit 15 set)
    moves r4, r4
    bpl @hl_xR_pos
    nop
    iwt r4, #128
    bra @hl_xR_ready
    nop
@hl_xR_pos:
    with r4
    swap
    with r4
    and r11
@hl_xR_ready:

    ; Extract signed integer xL in r3
    moves r3, r3
    bpl @hl_xL_pos
    nop
    with r3
    swap
    with r3
    sex
    bra @hl_xL_ready
    nop
@hl_xL_pos:
    with r3
    swap
    with r3
    and r11
@hl_xL_ready:

    ; Clamp xR against active half's max_x
    lm r0, (gsu_hl_max_x)
    from r4
    cmp r0
    blt @hl_xR_clamped
    nop
    move r4, r0
@hl_xR_clamped:

    ; Clamp xL against 0
    moves r3, r3
    bpl @hl_xL_clamped
    nop
    ibt r3, #0
@hl_xL_clamped:

    ; Align xL to 1x1 checkerboard parity: plot where (x ^ y) & 1 == 0
    from r3
    xor r2
    and #1
    beq @hl_parity_ok
    nop
    inc r3
@hl_parity_ok:

    ; Skip if xL >= xR
    from r3
    cmp r4
    bge @hl_skip_scanline
    nop

    ; count = ((xR - xL) + 1) >> 1
    from r4
    sub r3
    add #1
    lsr
    move r12, r0
    move r1, r3                 ; PLOT X = xL
    iwt r13, #@hl_px_loop
@hl_px_loop:
    plot                        ; plots color_idx at (r1, r2), r1 += 1
    loop
    inc r1                      ; delay slot: r1 += 1 again -> stride = +2

@hl_skip_scanline:
    ; Advance xL += dxL_dy, xR += dxR_dy
    lm r7, (gsu_hl_trap_ptr)
    with r7
    add #8
    to r5
    ldw (r7)                    ; dxL_dy
    inc r7
    inc r7
    to r6
    ldw (r7)                    ; dxR_dy

    lm r0, (gsu_hl_xL)
    add r5
    sm (gsu_hl_xL), r0

    lm r0, (gsu_hl_xR)
    add r6
    sm (gsu_hl_xR), r0

    inc r2                      ; y++
    lm r0, (gsu_hl_lines_left)
    dec r0
    sm (gsu_hl_lines_left), r0
    moves r0, r0
    beq @hl_scanlines_done
    nop
    iwt r15, #@hl_scanline_loop
    nop
@hl_scanlines_done:

    return
endfunction

; ==============================================================================
; gsu_iso_stamp_cell_highlight
; Stamps a checkerboard highlight across the current cell's projected top face
; (Step 3B, between Step 3 Archetype and Step 4 `@step_4_unit_hook`).
;
; In:
;   hl_code = r1: Tactical highlight code (1=Move, 2=Attack, 3=Cursor)
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_stamp_cell_highlight hl_code
    register hl_code = r1

    ; Map highlight code (1..3) -> BG1 palette color index
    from hl_code
    sub #GSU_HIGHLIGHT_MOVE
    beq @hl_col_move
    nop
    from hl_code
    sub #GSU_HIGHLIGHT_ATTACK
    beq @hl_col_attack
    nop
    from hl_code
    sub #GSU_HIGHLIGHT_CURSOR
    beq @hl_col_cursor
    nop
    return

@hl_col_move:
    iwt r0, #GSU_HL_COLOR_MOVE
    bra @hl_col_ready
    nop
@hl_col_attack:
    iwt r0, #GSU_HL_COLOR_ATTACK
    bra @hl_col_ready
    nop
@hl_col_cursor:
    iwt r0, #GSU_HL_COLOR_CURSOR
@hl_col_ready:
    sm (gsu_hl_color), r0

    ; Inspect cell archetype_id
    iwt r7, #gsu_iso_render_frame + map_render_frame::archetype_id
    ldw (r7)
    move r8, r0                 ; r8 = archetype_id
    iwt r2, #$001F
    from r8
    to r1
    and r2                      ; r1 = base archetype A

    ; PRIM_FLAT (0), PRIM_PILLAR (10), PRIM_FOLIAGE_CROSS (11) highlight flat_traps
    moves r1, r1
    bne @hl_chk_pillar
    nop
    iwt r15, #@hl_use_flat
    nop
@hl_chk_pillar:
    iwt r0, #PRIM_PILLAR
    from r1
    cmp r0
    bne @hl_chk_foliage
    nop
    iwt r15, #@hl_use_flat
    nop
@hl_chk_foliage:
    iwt r0, #PRIM_FOLIAGE_CROSS
    from r1
    cmp r0
    bne @hl_non_flat
    nop
    iwt r15, #@hl_use_flat
    nop
@hl_non_flat:

    ; Non-flat archetype (Wedge, Stairs, Liquid): lookup arch_lut[(A << 2) | R]
    with r1
    add r1
    with r1
    add r1                      ; r1 = A << 2
    move r0, r8
    with r0
    add r0
    with r0
    add r0
    swap
    iwt r2, #3
    with r0
    and r2                      ; r0 = R (0..3)
    with r1
    add r0                      ; (A << 2) | R
    with r1
    add r1                      ; byte offset (* 2)

    iwt r0, #128
    from r1
    cmp r0
    blt @hl_lut_ok
    nop
    return
@hl_lut_ok:

    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    move r6, r0                 ; r6 = arch_traps_ptr
    iwt r2, #326                ; offset of arch_lut
    with r0
    add r2
    with r0
    add r1
    move r7, r0
    ldw (r7)                    ; r0 = entry_offset
    with r0
    add r6
    move r1, r0                 ; r1 = &trap_count
    ldw (r1)
    move r9, r0                 ; r9 = trap_count
    moves r9, r9
    bne @hl_arch_has_traps
    nop
    return
@hl_arch_has_traps:
    inc r1
    inc r1                      ; r1 = first cached_trap

    ; Loop over archetype traps, stamping only top-surface traps (tex_id == 0)
@hl_arch_loop:
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    ldw (r7)                    ; original template surface type (0=top, 1=skirt, 2=panel)
    moves r0, r0
    bne @hl_arch_next
    nop

    gsu_stack_push r9
    gsu_stack_push r1

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    to r2
    ldw (r7)
    inc r7
    inc r7
    to r3
    ldw (r7)
    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    to r4
    ldw (r7)
    lm r5, (gsu_hl_color)
    call gsu_draw_highlight_trap r1, r2, r3, r4, r5

    gsu_stack_pop r1
    gsu_stack_pop r9

@hl_arch_next:
    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r9
    bne @hl_arch_loop
    nop
    return

@hl_use_flat:
    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    move r1, r0
    ldw (r1)
    move r9, r0                 ; r9 = flat_count
    moves r9, r9
    beq @hl_done
    nop
    inc r1
    inc r1                      ; r1 = &flat_traps[0]

@hl_flat_loop:
    gsu_stack_push r9
    gsu_stack_push r1

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    to r2
    ldw (r7)
    inc r7
    inc r7
    to r3
    ldw (r7)
    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    to r4
    ldw (r7)
    lm r5, (gsu_hl_color)
    call gsu_draw_highlight_trap r1, r2, r3, r4, r5

    gsu_stack_pop r1
    gsu_stack_pop r9

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r9
    bne @hl_flat_loop
    nop

@hl_done:
    return
endfunction
.endif ; GSU_ISO_USE_SCENE_DESCRIPTOR

.segment "GSUCODE"

; ==============================================================================
; gsu_iso_render
; Renders the Map Grid in back-to-front yaw-quadrant Painter's order,
; performing per-cell bounding box culling against active Frame Half and screen bounds.
; ==============================================================================
function gsu_iso_render map_ptr, cam_ptr, basis_ptr, arch_traps_ptr, frame_half, debug_order_ptr
    register map_ptr = r1, cam_ptr = r2, basis_ptr = r3, arch_traps_ptr = r4, frame_half = r5, debug_order_ptr = r6

    ; Ensure ROMBR is bank 4 for texture atlas and TEXTURE_TABLE
    ibt r0, #4
    romb

    iwt r7, #gsu_iso_render_frame

    ; Store function arguments in frame
    from map_ptr
    stw (r7)            ; frame.map_ptr (+0)
    inc r7
    inc r7
    from cam_ptr
    stw (r7)            ; frame.cam_ptr (+2)
    inc r7
    inc r7
    from basis_ptr
    stw (r7)            ; frame.basis_ptr (+4)
    inc r7
    inc r7
    from arch_traps_ptr
    stw (r7)            ; frame.arch_traps_ptr (+6)
    inc r7
    inc r7
    from frame_half
    stw (r7)            ; frame.frame_half (+8)
    inc r7
    inc r7
    from debug_order_ptr
    stw (r7)            ; frame.debug_order_ptr (+10)
    inc r7
    inc r7
    iwt r0, #0
    stw (r7)            ; frame.debug_count (+12) = 0

    ; 1. Read header fields: cols (+0), rows (+1), origin_x (+2), origin_z (+4)
    move r7, map_ptr
    ldb (r7)
    lob
    move r8, r0         ; r8 = cols
    inc r7
    ldb (r7)
    lob
    move r9, r0         ; r9 = rows
    inc r7
    ldw (r7)
    move r11, r0        ; r11 = origin_x
    inc r7
    inc r7
    ldw (r7)
    move r12, r0        ; r12 = origin_z
    inc r7
    inc r7
    ldw (r7)            ; r0 = reserved (+6)
    iwt r14, #$BACE
    from r0
    cmp r14
    beq :+
    nop
    iwt r0, #0
:
    move r14, r7
    iwt r7, #gsu_iso_is_prebaked
    stw (r7)
    move r7, r14

    ; Store cols, rows, origin_x, origin_z in frame
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
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

.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
    ; Sync Scene Render Descriptor per-frame hooks (#34 entity LUT + #35 highlights)
    lm r1, (gsu_iso_active_desc_ptr)
    moves r1, r1
    beq @desc_hooks_inactive
    nop
    ; Cache highlights_enabled (+12)
    from r1
    to r7
    add #gsu_scene_descriptor::highlights_enabled
    ldw (r7)
    sm (gsu_iso_hl_enabled), r0
    ; On Pass 0 (frame_half == 0), rebuild O(1) cell_entity_lut and clear entity_out[].visible
    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    ldw (r7)
    moves r0, r0
    bne @desc_hooks_ready
    nop
    move r2, r8                 ; r2 = cols
    call gsu_sprite_mask_build_lut r1, r2
    bra @desc_hooks_ready
    nop
@desc_hooks_inactive:
    ibt r0, #0
    sm (gsu_iso_hl_enabled), r0
    sm (gsu_entity_lut_active), r0
@desc_hooks_ready:
    ; Reload cam_ptr from frame (clobbered if gsu_sprite_mask_build_lut ran)
    iwt r7, #gsu_iso_render_frame + map_render_frame::cam_ptr
    to cam_ptr
    ldw (r7)
.endif

    ; 2. Determine Yaw Quadrant loop directions from cos_yaw (+4) and sin_yaw (+2)
    move r7, cam_ptr         ; cam_ptr
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::rows
    ldw (r7)
    dec r0
    move r8, r0         ; j_start = rows - 1
    iwt r9, #$FFFF      ; j_step = -1
@j_done:
    iwt r7, #gsu_iso_render_frame + map_render_frame::rows
    ldw (r7)
    move r14, r0        ; r14 = j_count = rows

    iwt r7, #gsu_iso_render_frame + map_render_frame::j_start
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)
    dec r0
    move r8, r0         ; i_start = cols - 1
    iwt r9, #$FFFF      ; i_step = -1
@i_done:
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)
    move r11, r0        ; r11 = i_count = cols

    iwt r7, #gsu_iso_render_frame + map_render_frame::i_start
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
    ; 2B. Partition compass edges by camera yaw quadrant:
    ;     Step 2: Back Edge Panels (receding edges)
    ;     Step 5: Front Edge Panels (camera-facing edges)
    ; --------------------------------------------------------------------------
    ; Check cos_yaw (r12)
    with r12
    add #0
    blt @cos_quad_neg
    nop
    ; cos_yaw >= 0:
    ; Back NS: North (PANEL_N = $01, edge = 0)
    ; Front NS: South (PANEL_S = $04, edge = 2)
    iwt r8, #PANEL_N
    iwt r9, #0
    iwt r1, #PANEL_S
    iwt r2, #2
    bra @cos_quad_done
    nop
@cos_quad_neg:
    ; cos_yaw < 0:
    ; Back NS: South (PANEL_S = $04, edge = 2)
    ; Front NS: North (PANEL_N = $01, edge = 0)
    iwt r8, #PANEL_S
    iwt r9, #2
    iwt r1, #PANEL_N
    iwt r2, #0
@cos_quad_done:
    iwt r7, #gsu_iso_render_frame + map_render_frame::back_ns_mask
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)            ; back_ns_edge
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ns_mask
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)            ; front_ns_edge

    ; Check sin_yaw
    iwt r7, #gsu_iso_render_frame + map_render_frame::cam_ptr
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    with r0
    add #0
    blt @sin_quad_neg
    nop
    ; sin_yaw >= 0:
    ; Back EW: West (PANEL_W = $08, edge = 3)
    ; Front EW: East (PANEL_E = $02, edge = 1)
    iwt r8, #PANEL_W
    iwt r9, #3
    iwt r1, #PANEL_E
    iwt r2, #1
    bra @sin_quad_done
    nop
@sin_quad_neg:
    ; sin_yaw < 0:
    ; Back EW: East (PANEL_E = $02, edge = 1)
    ; Front EW: West (PANEL_W = $08, edge = 3)
    iwt r8, #PANEL_E
    iwt r9, #1
    iwt r1, #PANEL_W
    iwt r2, #3
@sin_quad_done:
    iwt r7, #gsu_iso_render_frame + map_render_frame::back_ew_mask
    from r8
    stw (r7)
    inc r7
    inc r7
    from r9
    stw (r7)            ; back_ew_edge
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ew_mask
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)            ; front_ew_edge

    ; --------------------------------------------------------------------------
    ; 2C. Compute Q11.5 basis vectors and screen origins:
    ;     Sx.x_q5 = cos_yaw >> 4,  Sx.y_q5 = sin_yaw >> 5
    ;     Sz.x_q5 = -(sin_yaw >> 4), Sz.y_q5 = cos_yaw >> 5
    ;     origin_x_q5 = origin_x << 5, origin_z_q5 = origin_z << 5
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::cam_ptr
    ldw (r7)
    inc r0
    inc r0
    move r7, r0
    ldw (r7)            ; sin_yaw
    move r11, r0        ; r11 = sin_yaw
    inc r7
    inc r7
    ldw (r7)            ; cos_yaw
    move r12, r0        ; r12 = cos_yaw

    ; Sx.x_q5 = cos_yaw >> 4
    move r1, r12
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    iwt r7, #gsu_iso_render_frame + map_render_frame::sx_x_q5
    from r1
    stw (r7)

    ; Sx.y_q5 = sin_yaw >> 5
    move r1, r11
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    inc r7
    inc r7
    from r1
    stw (r7)

    ; Sz.x_q5 = - (sin_yaw >> 4)
    move r1, r11
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    not
    inc r1
    inc r7
    inc r7
    from r1
    stw (r7)

    ; Sz.y_q5 = cos_yaw >> 5
    move r1, r12
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    inc r7
    inc r7
    from r1
    stw (r7)

    ; origin_x_q5 = origin_x << 5
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_x
    ldw (r7)
    move r1, r0
    with r1
    add r1
    with r1
    add r1
    with r1
    add r1
    with r1
    add r1
    with r1
    add r1
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_x_q5
    from r1
    stw (r7)

    ; origin_z_q5 = origin_z << 5
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_z
    ldw (r7)
    move r1, r0
    with r1
    add r1
    with r1
    add r1
    with r1
    add r1
    with r1
    add r1
    with r1
    add r1
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_z_q5
    from r1
    stw (r7)

    ; Check if map is 8x8:
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)
    with r0
    sub #8
    bne @setup_generic_loops
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::rows
    ldw (r7)
    with r0
    sub #8
    bne @setup_generic_loops
    nop

    ; --- 8x8 Grid Fast Path: Setup 64-byte diagonal quadrant table ---
    iwt r7, #gsu_iso_render_frame + map_render_frame::is_8x8
    iwt r0, #1
    from r0
    stw (r7)

    ; Determine quad_idx = (cos_neg << 1) | sin_neg
    iwt r8, #0          ; r8 = quad_idx
    with r12            ; cos_yaw
    add #0
    bge :+
    nop
    iwt r8, #2          ; bit 1 = 1
:
    with r11            ; sin_yaw
    add #0
    bge :+
    nop
    inc r8              ; bit 0 = 1
:
    ; Table ROM address = gsu_iso_quadrant_tables + (quad_idx << 6)
    move r0, r8
    with r0
    add r0              ; << 1
    with r0
    add r0              ; << 2
    with r0
    add r0              ; << 3
    with r0
    add r0              ; << 4
    with r0
    add r0              ; << 5
    with r0
    add r0              ; << 6
    iwt r14, #gsu_iso_quadrant_tables
    with r14
    add r0              ; r14 = table source in ROM (bank 4)

    iwt r1, #gsu_iso_render_frame + map_render_frame::quad_table
    iwt r12, #64
    cache
    move r13, r15
    getb
    inc r14
    from r0
    stb (r1)
    nop
    loop
    inc r1
    nop

    ; Reset cell_idx = 0
    iwt r7, #gsu_iso_render_frame + map_render_frame::cell_idx
    iwt r0, #0
    from r0
    stw (r7)
    iwt r13, #@loop_8x8_top
    jmp r13
    nop

@setup_generic_loops:
    iwt r7, #gsu_iso_render_frame + map_render_frame::is_8x8
    iwt r0, #0
    from r0
    stw (r7)
    iwt r13, #@generic_loops_start
    jmp r13
    nop

@loop_8x8_top:
    ; Read cell_idx (0..63)
    iwt r7, #gsu_iso_render_frame + map_render_frame::cell_idx
    ldw (r7)
    move r8, r0         ; r8 = cell_idx

    ; Read packed_index from quad_table + cell_idx
    iwt r7, #gsu_iso_render_frame + map_render_frame::quad_table
    with r7
    add r8
    ldb (r7)
    lob
    move r14, r0        ; r14 = packed_index = (j << 3) | i

    ; i_cur = packed_index & 7
    move r12, r14
    with r12
    and #7              ; r12 = i_cur

    ; j_cur = packed_index >> 3
    move r9, r14
    with r9
    asr
    with r9
    asr
    with r9
    asr                 ; r9 = j_cur

    ; Save i_cur and j_cur in frame
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
    from r12
    stw (r7)
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    from r9
    stw (r7)

    ; cell_offset = packed_index << 3
    move r8, r14
    with r8
    add r8
    with r8
    add r8
    with r8
    add r8              ; r8 = packed_index << 3

    ; cell_ptr = map_ptr + 8 + r8
    iwt r7, #gsu_iso_render_frame + map_render_frame::map_ptr
    ldw (r7)
    with r0
    add #8
    with r0
    add r8
    move r7, r0         ; r7 = cell_ptr
    iwt r13, #@read_cell_fields
    jmp r13
    nop

    ; --------------------------------------------------------------------------
    ; 3. Outer J Loop (Rows)
    ; --------------------------------------------------------------------------
@generic_loops_start:
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_start
    ldw (r7)
    move r9, r0         ; r9 = j_cur = j_start
    inc r7
    inc r7
    inc r7
    inc r7
    ldw (r7)
    move r11, r0        ; r11 = j_rem = j_count

@j_loop_top:
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    from r9
    stw (r7)
    inc r7
    inc r7
    from r11
    stw (r7)            ; save j_rem

    ; Load i_start into r12 and i_count into r14 for row initialization:
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_start
    ldw (r7)
    move r12, r0        ; r12 = i_cur = i_start
    inc r7
    inc r7
    inc r7
    inc r7
    ldw (r7)
    move r14, r0        ; r14 = i_rem = i_count

    ; Initialize cur_cell_ptr = map_ptr + 8 + ((j * cols + i_start) << 3)
    move r6, r9         ; mul_b = j_cur
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)            ; r0 = cols
    to r8
    lmult               ; r4 = j * cols
    from r4
    to r8
    add r12             ; r8 = j * cols + i_start
    with r8
    add r8
    with r8
    add r8
    with r8
    add r8              ; r8 = (j * cols + i_start) << 3
    iwt r7, #gsu_iso_render_frame + map_render_frame::map_ptr
    ldw (r7)
    add #8
    add r8              ; r0 = map_ptr + 8 + ((j * cols + i_start) << 3)
    iwt r7, #gsu_iso_row_cell_offset
    stw (r7)

    ; Initialize cur_anchor_x_q5 = origin_x_q5 + j * sz_x_q5 + i_start * sx_x_q5
    move r6, r9
    iwt r7, #gsu_iso_render_frame + map_render_frame::sz_x_q5
    ldw (r7)
    to r8
    lmult
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_x_q5
    ldw (r7)
    to r1
    add r4              ; r1 = origin_x_q5 + j * sz_x_q5
    move r6, r12        ; mul_b = i_start
    iwt r7, #gsu_iso_render_frame + map_render_frame::sx_x_q5
    ldw (r7)
    to r8
    lmult
    from r1
    add r4              ; r0 = origin_x_q5 + j * sz_x_q5 + i_start * sx_x_q5
    iwt r7, #gsu_iso_row_anchor_x_q5
    stw (r7)

    ; Initialize cur_anchor_z_q5 = origin_z_q5 + j * sz_y_q5 + i_start * sx_y_q5
    move r6, r9
    iwt r7, #gsu_iso_render_frame + map_render_frame::sz_y_q5
    ldw (r7)
    to r8
    lmult
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_z_q5
    ldw (r7)
    to r1
    add r4              ; r1 = origin_z_q5 + j * sz_y_q5
    move r6, r12        ; mul_b = i_start
    iwt r7, #gsu_iso_render_frame + map_render_frame::sx_y_q5
    ldw (r7)
    to r8
    lmult
    from r1
    add r4              ; r0 = origin_z_q5 + j * sz_y_q5 + i_start * sx_y_q5
    iwt r7, #gsu_iso_row_anchor_z_q5
    stw (r7)

    ; --------------------------------------------------------------------------
    ; 4. Inner I Loop (Cols)
    ; --------------------------------------------------------------------------
@i_loop_top:
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
    from r12
    stw (r7)
    inc r7
    inc r7
    from r14
    stw (r7)            ; save i_rem

    ; --------------------------------------------------------------------------
    ; 5. Read Map Cell Record from stepped gsu_iso_row_cell_offset
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_row_cell_offset
    to r7
    ldw (r7)            ; r7 = cell_ptr

@read_cell_fields:

    ; Read cell fields:
    ; base_height (+0)
    ldb (r7)
    lob
    iwt r11, #gsu_iso_render_frame + map_render_frame::base_height
    stw (r11)

    ; archetype_id (+1)
    inc r7
    ldb (r7)
    lob
    inc r11
    inc r11
    stw (r11)

    ; top_tex_id (+2)
    inc r7
    ldb (r7)
    lob
    inc r11
    inc r11
    stw (r11)

    ; skirt_tex_id (+3)
    inc r7
    ldb (r7)
    lob
    inc r11
    inc r11
    stw (r11)

    ; panel_tex_id (+4)
    inc r7
    ldb (r7)
    lob
    iwt r8, #gsu_iso_render_frame + map_render_frame::panel_tex_id
    stw (r8)

    ; panel_flags (+5)
    inc r7
    ldb (r7)
    lob
    iwt r8, #gsu_iso_render_frame + map_render_frame::panel_flags
    stw (r8)

    ; --------------------------------------------------------------------------
    ; Derive camera-facing skirt drops from neighbor floor heights.
    ;   Skirt templates (ARCH_SKIRT_NS / ARCH_SKIRT_EW) are compiled for the
    ;   camera-facing face only (S or N, E or W, chosen by yaw quadrant), so the
    ;   drop must be measured against the neighbor on that same face:
    ;     drop = max(0, base_height - neighbor.surface_height)
    ;   If pre-baked drops are present ($BACE), read them directly from cell_ptr + 6
    ;   and cell_ptr + 7 (r7 is currently cell_ptr + 5).
    ; --------------------------------------------------------------------------
    iwt r8, #gsu_iso_is_prebaked
    ldw (r8)
    from r0
    sub #0
    beq @fallback_calc_skirt_drops
    nop

    ; Fast path: read prebaked drop_ns from cell_ptr + 6
    inc r7
    ldb (r7)
    lob
    move r1, r0         ; r1 = drop_ns byte: drop_s | (drop_n << 4)

    ; Read prebaked drop_ew from cell_ptr + 7
    inc r7
    ldb (r7)
    lob
    move r2, r0         ; r2 = drop_ew byte: drop_e | (drop_w << 4)

    ; Determine camera-facing NS drop:
    iwt r8, #gsu_iso_render_frame + map_render_frame::front_ns_edge
    ldw (r8)            ; 2 = South, 0 = North
    from r0
    sub #0
    beq @read_drop_north
    nop
    ; South: byte6 & $0F
    from r1
    and #$0F
    bra @store_drop_ns
    nop
@read_drop_north:
    from r1
    to r0
    lsr
    with r0
    lsr
    with r0
    lsr
    with r0
    lsr
    and #$0F
@store_drop_ns:
    iwt r8, #gsu_iso_render_frame + map_render_frame::drop_ns
    stw (r8)

    ; Determine camera-facing EW drop:
    iwt r8, #gsu_iso_render_frame + map_render_frame::front_ew_edge
    ldw (r8)            ; 1 = East, 3 = West
    sub #1
    bne @read_drop_west
    nop
    ; East: byte7 & $0F
    from r2
    and #$0F
    bra @store_drop_ew
    nop
@read_drop_west:
    from r2
    to r0
    lsr
    with r0
    lsr
    with r0
    lsr
    with r0
    lsr
    and #$0F
@store_drop_ew:
    iwt r8, #gsu_iso_render_frame + map_render_frame::drop_ew
    stw (r8)
    iwt r13, #@skirt_drops_done
    jmp r13
    nop

@fallback_calc_skirt_drops:
    iwt r7, #gsu_iso_render_frame + map_render_frame::base_height
    to r1
    ldw (r7)            ; r1 = h

    ; If current cell is a liquid archetype, liquid has no side walls / skirts (force h=0):
    iwt r7, #gsu_iso_render_frame + map_render_frame::archetype_id
    ldw (r7)
    iwt r8, #$001F
    with r0
    and r8
    iwt r8, #PRIM_LIQUID_SHALLOW
    from r0
    cmp r8
    beq @cell_is_liquid
    nop
    iwt r8, #PRIM_LIQUID_DEEP
    from r0
    cmp r8
    bne :+
    nop
@cell_is_liquid:
    iwt r1, #0          ; liquid cells have 0 solid height for skirts
:

    ; --- NS neighbor: j_nb = j + 1 (front = South) or j - 1 (front = North) ---
    move r2, r9         ; r2 = j_cur
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ns_edge
    ldw (r7)            ; 2 = South, 0 = North
    add #0
    bne :+
    nop
    dec r2
    dec r2
:
    inc r2              ; r2 = j_nb
    iwt r3, #0          ; r3 = neighbor height (0 when out of bounds)
    from r2
    add #0
    bmi @ns_nb_done
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::rows
    ldw (r7)
    from r2
    sub r0              ; j_nb - rows
    bge @ns_nb_done
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)            ; r0 = cols
    mult r2             ; r0 = cols * j_nb
    add r12             ; + i_cur
    add r0
    add r0
    add r0              ; * 8 (sizeof map_cell)
    move r3, r0
    iwt r7, #gsu_iso_render_frame + map_render_frame::map_ptr
    ldw (r7)
    add #8              ; skip map_header
    add r3
    move r7, r0
    ldb (r7)            ; neighbor base_height
    lob
    move r3, r0
    inc r7
    ldb (r7)            ; neighbor archetype_id
    lob
    iwt r8, #$001F
    with r0
    and r8
    iwt r8, #PRIM_LIQUID_SHALLOW
    from r0
    cmp r8
    bne :+
    nop
    inc r3              ; shallow liquid surface is base_height + 1
    bra @ns_nb_done
    nop
:
    iwt r8, #PRIM_LIQUID_DEEP
    from r0
    cmp r8
    bne :+
    nop
    inc r3
    inc r3              ; deep liquid surface is base_height + 2
:
@ns_nb_done:
    from r1
    sub r3              ; h - h_nb
    bpl :+
    nop
    iwt r0, #0
:
    iwt r7, #gsu_iso_render_frame + map_render_frame::drop_ns
    stw (r7)

    ; --- EW neighbor: i_nb = i + 1 (front = East) or i - 1 (front = West) ---
    move r2, r12        ; r2 = i_cur
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ew_edge
    ldw (r7)            ; 1 = East, 3 = West
    sub #1
    beq :+
    nop
    dec r2
    dec r2
:
    inc r2              ; r2 = i_nb
    iwt r3, #0
    from r2
    add #0
    bmi @ew_nb_done
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)
    from r2
    sub r0              ; i_nb - cols
    bge @ew_nb_done
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)            ; r0 = cols
    mult r9             ; r0 = cols * j_cur
    add r2              ; + i_nb
    add r0
    add r0
    add r0              ; * 8
    move r3, r0
    iwt r7, #gsu_iso_render_frame + map_render_frame::map_ptr
    ldw (r7)
    add #8
    add r3
    move r7, r0
    ldb (r7)
    lob
    move r3, r0
    inc r7
    ldb (r7)            ; neighbor archetype_id
    lob
    iwt r8, #$001F
    with r0
    and r8
    iwt r8, #PRIM_LIQUID_SHALLOW
    from r0
    cmp r8
    bne :+
    nop
    inc r3              ; shallow liquid surface is base_height + 1
    bra @ew_nb_done
    nop
:
    iwt r8, #PRIM_LIQUID_DEEP
    from r0
    cmp r8
    bne :+
    nop
    inc r3
    inc r3              ; deep liquid surface is base_height + 2
:
@ew_nb_done:
    from r1
    sub r3
    bpl :+
    nop
    iwt r0, #0
:
    iwt r7, #gsu_iso_render_frame + map_render_frame::drop_ew
    stw (r7)

@skirt_drops_done:

    ; --------------------------------------------------------------------------
    ; 6. Calculate 2D Screen Anchor(i, j, base_height) using Q11.5 fixed point:
    ;    Anchor.x = (origin_x_q5 + i * sx_x_q5 + j * sz_x_q5 + 16) >> 5
    ;    Anchor.y = (origin_z_q5 + i * sx_y_q5 + j * sz_y_q5 + base_height * (-448) + 16) >> 5
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::is_8x8
    ldw (r7)
    from r0
    sub #0
    bne @calc_anchor_8x8
    nop

    ; Generic loop anchor: gsu_row_anchor_x/z_q5 is already stepped across i!
    iwt r7, #gsu_iso_row_anchor_x_q5
    to r1
    ldw (r7)            ; r1 = cur_anchor_x_q5
    inc r7
    inc r7
    to r2
    ldw (r7)            ; r2 = cur_anchor_z_q5
    bra @add_height_to_anchor
    nop

@calc_anchor_8x8:
    iwt r7, #gsu_iso_render_frame + map_render_frame::origin_x_q5
    to r1
    ldw (r7)            ; r1 = anchor_x_q5
    inc r7
    inc r7
    to r2
    ldw (r7)            ; r2 = anchor_y_q5

    ; + i * sx:
    move r6, r12        ; mul_b = i_cur
    iwt r7, #gsu_iso_render_frame + map_render_frame::sx_x_q5
    ldw (r7)            ; sx_x_q5
    to r8
    lmult
    with r1
    add r4

    inc r7
    inc r7
    ldw (r7)            ; sx_y_q5
    to r8
    lmult
    with r2
    add r4

    ; + j * sz:
    move r6, r9         ; mul_b = j_cur
    inc r7
    inc r7
    ldw (r7)            ; sz_x_q5
    to r8
    lmult
    with r1
    add r4

    inc r7
    inc r7
    ldw (r7)            ; sz_y_q5
    to r8
    lmult
    with r2
    add r4

@add_height_to_anchor:
    ; + base_height * (-448) = (h << 6) - (h << 9) without lmult
    iwt r7, #gsu_iso_render_frame + map_render_frame::base_height
    ldw (r7)            ; r0 = base_height
    from r0
    sub #0
    beq @height_offset_done
    nop
    move r6, r0
    with r6
    add r6
    with r6
    add r6
    with r6
    add r6
    with r6
    add r6
    with r6
    add r6
    with r6
    add r6              ; r6 = h << 6
    move r4, r6
    with r4
    add r4
    with r4
    add r4
    with r4
    add r4              ; r4 = h << 9
    from r6
    sub r4              ; r0 = (h << 6) - (h << 9) = -448 * h
    with r2
    add r0
@height_offset_done:

    ; Round to integer screen pixels (+16, asr 5):
    iwt r0, #16
    with r1
    add r0
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr
    with r1
    asr

    with r2
    add r0
    with r2
    asr
    with r2
    asr
    with r2
    asr
    with r2
    asr
    with r2
    asr

    ; Save anchor_x and anchor_y in frame
    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    from r1
    stw (r7)
    inc r7
    inc r7
    from r2
    stw (r7)

    ; --------------------------------------------------------------------------
    ; 7. Per-Cell Bounding-Box Culling:
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
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
    iwt r8, #gsu_iso_render_frame + map_render_frame::drop_ns
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
    ; If ymin >= GSU_ISO_SCREEN_H: cull
    iwt r14, #GSU_ISO_SCREEN_H
    from r5
    sub r14
    blt :+
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
:
    ; --- Horizontal Frame Half Culling ---
    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
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
    ; Pass 1 (Half 1): screen X in [128, GSU_ISO_VIEWPORT_W)
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
    ; If xmin >= GSU_ISO_VIEWPORT_W: cull
    iwt r14, #GSU_ISO_VIEWPORT_W
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::debug_order_ptr
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::debug_order_ptr
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::drop_ns
    ldw (r7)
    with r0
    add #0
    bne @skirt_ns_drop_nonzero
    nop
    iwt r13, #@skirt_ns_done
    jmp r13
    nop
@skirt_ns_drop_nonzero:
    move r8, r0         ; r8 = drop_ns (camera-facing NS face, derived above)

@skirt_ns_drop_ok:

    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #106
    with r0
    add r11             ; skirt_ns_count
    move r7, r0
    ldw (r7)
    with r0
    add #0
    bne @skirt_ns_count_ok
    nop
    iwt r13, #@skirt_ns_done
    jmp r13
    nop
@skirt_ns_count_ok:
    move r9, r0         ; r9 = skirt_ns_count

    ; U offset for NS skirt = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::skirt_tex_id
    to r11
    ldw (r7)            ; r11 = skirt_tex_id

    ; Loop over vertical steps s = 0 .. drop_ns - 1
    iwt r12, #0         ; r12 = s = 0
@ns_step_loop:
    ; step_y = anchor_y + s * 14
    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_y
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

    ; v_offset = (s * 16) << gsu_runtime_stride_shift:
    move r0, r12
    _gsu_iso_v_offset_16 r6, r2

    ; Stamp each cached_trap in skirt_ns_traps:
    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
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

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x

    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    _gsu_iso_draw_trap

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
    bge @skirt_ns_done
    nop
    iwt r13, #@ns_step_loop
    jmp r13
    nop

@skirt_ns_done:

    ; --- 9B: Stamp ARCH_SKIRT_EW (drop_ew steps) ---
    iwt r7, #gsu_iso_render_frame + map_render_frame::drop_ew
    ldw (r7)
    with r0
    add #0
    bne @skirt_ew_drop_nonzero
    nop
    iwt r13, #@skirt_ew_done
    jmp r13
    nop
@skirt_ew_drop_nonzero:
    move r8, r0         ; r8 = drop_ew (camera-facing EW face, derived above)

@skirt_ew_drop_ok:

    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r11, #212
    with r0
    add r11             ; skirt_ew_count
    move r7, r0
    ldw (r7)
    with r0
    add #0
    bne @skirt_ew_count_ok
    nop
    iwt r13, #@skirt_ew_done
    jmp r13
    nop
@skirt_ew_count_ok:
    move r9, r0         ; r9 = skirt_ew_count

    ; U offset for EW skirt = (j_cur * 32) << 8 = j_cur << 13:
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
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
    iwt r7, #gsu_iso_render_frame + map_render_frame::skirt_tex_id
    to r11
    ldw (r7)            ; r11 = skirt_tex_id

    ; Loop over vertical steps s = 0 .. drop_ew - 1
    iwt r12, #0         ; r12 = s = 0
@ew_step_loop:
    ; step_y = anchor_y + s * 14
    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_y
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

    ; v_offset = (s * 16) << gsu_runtime_stride_shift:
    move r0, r12
    _gsu_iso_v_offset_16 r6, r2

    ; Stamp each cached_trap in skirt_ew_traps:
    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
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

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x

    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    _gsu_iso_draw_trap

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
    bge @skirt_ew_done
    nop
    iwt r13, #@ew_step_loop
    jmp r13
    nop

@skirt_ew_done:

    ; --------------------------------------------------------------------------
    ; Step 1B: Flat Cell Floor (PRIM_FLAT, PRIM_PILLAR, PRIM_FOLIAGE_CROSS)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::archetype_id
    ldw (r7)
    iwt r1, #$001F
    with r0
    and r1              ; r0 = base archetype A
    beq @stamp_step_1b_floor
    nop
    move r8, r0         ; preserve base archetype A in r8 for non-destructive comparisons
    iwt r1, #PRIM_PILLAR
    from r8
    sub r1
    beq @stamp_step_1b_floor
    nop
    iwt r1, #PRIM_FOLIAGE_CROSS
    from r8
    sub r1
    beq @stamp_step_1b_floor
    nop
    iwt r13, #@step_1b_done
    jmp r13
    nop

@stamp_step_1b_floor:
    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    move r2, r0         ; r2 = arch_traps_ptr
    ldw (r2)
    move r9, r0         ; r9 = flat_count
    with r9
    add #0
    bne @flat_count_ok
    nop
    iwt r13, #@step_1b_done
    jmp r13
    nop
@flat_count_ok:

    ; Pointer to first cached_trap in flat_traps:
    inc r2
    inc r2
    move r1, r2         ; r1 = arch_traps_ptr + flat_traps (+2)

    ; u_offset = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
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

    ; v_offset = (j_cur * 32) << gsu_runtime_stride_shift:
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    ldw (r7)
    _gsu_iso_v_offset_32 r6, r2

    ; Load cell top_tex_id:
    iwt r7, #gsu_iso_render_frame + map_render_frame::top_tex_id
    to r11
    ldw (r7)            ; r11 = top_tex_id

    move r14, r9        ; r14 = trap counter
@flat_trap_loop:
    ; Set trap tex_id (+24) to top_tex_id
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r11
    stw (r7)

    gsu_stack_push r14
    gsu_stack_push r1
    gsu_stack_push r11
    gsu_stack_push r6
    gsu_stack_push r5

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; anchor_y

    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    _gsu_iso_draw_trap

    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r11
    gsu_stack_pop r1
    gsu_stack_pop r14

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    bne @flat_trap_loop
    nop

@step_1b_done:

    ; --------------------------------------------------------------------------
    ; Step 2: Back Edge Panels (receding edges in current yaw quadrant)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_flags
    ldw (r7)
    move r8, r0         ; r8 = panel_flags
    iwt r1, #$000F
    with r0
    and r1
    beq @step_2_done
    nop

    ; Check Back NS edge:
    iwt r7, #gsu_iso_render_frame + map_render_frame::back_ns_mask
    ldw (r7)
    with r0
    and r8
    beq @check_back_ew
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::back_ns_edge
    ldw (r7)
    move r1, r0
    call gsu_iso_stamp_edge_panel r1

@check_back_ew:
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_flags
    ldw (r7)
    move r8, r0         ; reload panel_flags (clobbered by gsu_iso_stamp_edge_panel)
    iwt r7, #gsu_iso_render_frame + map_render_frame::back_ew_mask
    ldw (r7)
    with r0
    and r8
    beq @step_2_done
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::back_ew_edge
    ldw (r7)
    move r1, r0
    call gsu_iso_stamp_edge_panel r1

@step_2_done:

    ; --- Step 3: Stamp Archetype (Top Cap & Faces) ---
    iwt r7, #gsu_iso_render_frame + map_render_frame::archetype_id
    ldw (r7)
    move r8, r0         ; r8 = archetype_id

    ; base archetype A = r8 & $1F
    move r1, r8
    iwt r2, #$001F
    with r1
    and r2              ; r1 = A

    ; If PRIM_FLAT (A == 0), skip Step 3 (already stamped in Step 1B before Step 2)
    with r1
    add #0
    bne @step_3_not_flat
    nop
    iwt r13, #@step_3b_cell_highlight
    jmp r13
    nop
@step_3_not_flat:

    with r1
    add r1
    with r1
    add r1              ; r1 = A << 2

    ; rot R = (r8 >> 6) & 3
    move r0, r8
    with r0
    add r0
    with r0
    add r0
    swap
    iwt r2, #3
    with r0
    and r2              ; r0 = R

    with r1
    add r0              ; r1 = lut_index = (A << 2) | R
    with r1
    add r1              ; r1 = lut_byte_offset = lut_index * 2

    ; Check bounds: lut_byte_offset < 128 (64 entries * 2)
    iwt r0, #128
    from r1
    sub r0
    blt @arch_lut_bounds_ok
    nop
    iwt r13, #@cull_cell
    jmp r13
    nop
@arch_lut_bounds_ok:

    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    iwt r2, #326        ; offset of arch_lut
    with r0
    add r2
    with r0
    add r1
    move r7, r0
    ldw (r7)
    move r2, r0         ; r2 = entry_offset from arch_traps_ptr

    iwt r7, #gsu_iso_render_frame + map_render_frame::arch_traps_ptr
    ldw (r7)
    with r0
    add r2
    move r1, r0         ; r1 = &arch_traps_ptr[entry_offset] = ptr to trap_count
    ldw (r1)
    move r9, r0         ; r9 = trap_count
    with r9
    add #0
    bne @arch_trap_count_ok
    nop
    iwt r13, #@step_3b_cell_highlight
    jmp r13
    nop
@arch_trap_count_ok:

    ; Pointer to first cached_trap
    inc r1
    inc r1              ; r1 = &first cached_trap

    ; u_offset = (i_cur * 32) << 8 = i_cur << 13:
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
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

    ; v_offset = (j_cur * 32) << gsu_runtime_stride_shift:
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    ldw (r7)
    _gsu_iso_v_offset_32 r6, r2

    ; Load cell top_tex_id and skirt_tex_id
    iwt r7, #gsu_iso_render_frame + map_render_frame::top_tex_id
    to r11
    ldw (r7)            ; r11 = top_tex_id
    iwt r7, #gsu_iso_render_frame + map_render_frame::skirt_tex_id
    to r12
    ldw (r7)            ; r12 = skirt_tex_id

    move r14, r9
@archetype_trap_loop:
    ; Read compiled surface type (+24) from current cached_trap (r1 + 24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    ldw (r7)
    move r8, r0         ; r8 = original template surface type (0 = top, 1 = skirt, 2 = panel)
    from r8
    add #0
    beq @use_top_tex
    nop
    from r8
    sub #1
    beq @use_skirt_tex
    nop
    ; r8 == 2: substitute panel_tex_id
    iwt r2, #gsu_iso_render_frame + map_render_frame::panel_tex_id
    ldw (r2)
    stw (r7)
    bra @tex_applied
    nop
@use_skirt_tex:
    from r12
    stw (r7)            ; substitute skirt_tex_id
    bra @tex_applied
    nop
@use_top_tex:
    from r11
    stw (r7)            ; substitute top_tex_id
@tex_applied:

    gsu_stack_push r14
    gsu_stack_push r8
    gsu_stack_push r1
    gsu_stack_push r12
    gsu_stack_push r11
    gsu_stack_push r6
    gsu_stack_push r5

    iwt r7, #gsu_iso_render_frame + map_render_frame::anchor_x
    ldw (r7)
    move r3, r0         ; anchor_x
    inc r7
    inc r7
    ldw (r7)
    move r4, r0         ; anchor_y

    iwt r7, #gsu_iso_render_frame + map_render_frame::frame_half
    ldw (r7)
    move r7, r0         ; frame_half

    _gsu_iso_draw_trap

    gsu_stack_pop r5
    gsu_stack_pop r6
    gsu_stack_pop r11
    gsu_stack_pop r12
    gsu_stack_pop r1
    gsu_stack_pop r8
    gsu_stack_pop r14

    ; Restore original template surface type (r8) to trap (+24)
    move r7, r1
    iwt r2, #24
    with r7
    add r2
    from r8
    stw (r7)

    iwt r7, #.sizeof(cached_trap)
    with r1
    add r7
    dec r14
    beq @step_3b_cell_highlight
    nop
    iwt r13, #@archetype_trap_loop
    jmp r13
    nop

@step_3b_cell_highlight:
    ; --------------------------------------------------------------------------
    ; Step 3B: Per-Cell Tactical Highlight Pass (Issue #35)
    ; Runs after Step 3 terrain and BEFORE Step 4 units & Step 5 front panels.
    ; Zero overhead when `GSU_ISO_USE_SCENE_DESCRIPTOR` is undefined or
    ; `desc->highlights_enabled == 0`.
    ; --------------------------------------------------------------------------
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
    lm r0, (gsu_iso_hl_enabled)
    moves r0, r0
    beq @step_4_unit_hook
    nop
    ; Compute cell_idx = j_cur * cols + i_cur
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    to r1
    ldw (r7)
    umult r1                    ; r0 = j_cur * cols
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
    to r1
    ldw (r7)
    add r1                      ; r0 = cell_idx
    ; Read desc->cell_highlights[cell_idx] (+208)
    iwt r1, #gsu_scene_descriptor::cell_highlights
    lm r7, (gsu_iso_active_desc_ptr)
    with r7
    add r1
    with r7
    add r0
    ldb (r7)
    lob
    moves r0, r0
    beq @step_4_unit_hook
    nop
    move r1, r0                 ; r1 = highlight code (1..3)
    call gsu_iso_stamp_cell_highlight r1
.endif

@step_4_unit_hook:
    ; --------------------------------------------------------------------------
    ; Step 4: On-Cell Unit / Sprite Mask Cutout Hook (ADR 0005 / Issue #34)
    ; Runs after terrain & highlights, BEFORE Step 5 front Edge Panels.
    ; O(1) `cell_entity_lut[cell_idx]` check skips empty cells immediately.
    ; --------------------------------------------------------------------------
@unit_hook:
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
    lm r0, (gsu_entity_lut_active)
    moves r0, r0
    beq @step_4_unit_done
    nop
    ; Compute cell_idx = j_cur * cols + i_cur
    iwt r7, #gsu_iso_render_frame + map_render_frame::cols
    ldw (r7)
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    to r1
    ldw (r7)
    umult r1                    ; r0 = j_cur * cols
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
    to r1
    ldw (r7)
    add r1                      ; r0 = cell_idx
    ; O(1) lookup in cell_entity_lut[cell_idx]
    iwt r7, #cell_entity_lut
    with r7
    add r0
    ldb (r7)
    lob
    iwt r1, #GSU_ENTITY_NONE
    cmp r1
    beq @step_4_unit_done
    nop
    move r2, r0                 ; r2 = entity slot index (0..7)
    lm r1, (gsu_iso_active_desc_ptr)
    call gsu_sprite_mask_stamp_cell r1, r2
@step_4_unit_done:
.else
    nop
.endif

    ; --------------------------------------------------------------------------
    ; Step 5: Front Edge Panels (camera-facing edges in current yaw quadrant)
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_flags
    ldw (r7)
    move r8, r0         ; r8 = panel_flags
    iwt r1, #$000F
    with r0
    and r1
    beq @step_5_done
    nop

    ; Check Front NS edge:
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ns_mask
    ldw (r7)
    with r0
    and r8
    beq @check_front_ew
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ns_edge
    ldw (r7)
    move r1, r0
    call gsu_iso_stamp_edge_panel r1

@check_front_ew:
    iwt r7, #gsu_iso_render_frame + map_render_frame::panel_flags
    ldw (r7)
    move r8, r0         ; reload panel_flags (clobbered by gsu_iso_stamp_edge_panel)
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ew_mask
    ldw (r7)
    with r0
    and r8
    beq @step_5_done
    nop
    iwt r7, #gsu_iso_render_frame + map_render_frame::front_ew_edge
    ldw (r7)
    move r1, r0
    call gsu_iso_stamp_edge_panel r1

@step_5_done:
    iwt r13, #@cull_cell
    jmp r13
    nop

@cull_cell:
    iwt r7, #gsu_iso_render_frame + map_render_frame::is_8x8
    ldw (r7)
    with r0
    add #0
    beq @advance_generic_i_loop
    nop

    ; 8x8 Mode: Advance cell_idx
    iwt r7, #gsu_iso_render_frame + map_render_frame::cell_idx
    ldw (r7)
    inc r0
    stw (r7)
    iwt r1, #64
    from r0
    sub r1
    beq @render_done
    nop
    iwt r13, #@loop_8x8_top
    jmp r13
    nop

@advance_generic_i_loop:
    ; --------------------------------------------------------------------------
    ; 10. Advance I Loop
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_rem
    ldw (r7)
    dec r0
    beq @i_loop_done
    nop
    move r14, r0        ; r14 = new i_rem

    ; Advance i_cur += i_step, and step cur_cell_ptr and cur_anchor_x/z_q5
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_cur
    to r12
    ldw (r7)
    iwt r7, #gsu_iso_render_frame + map_render_frame::i_step
    ldw (r7)
    with r12
    add r0
    from r0
    sub #0
    bmi @step_i_neg
    nop

    ; i_step == +1:
    iwt r7, #gsu_iso_row_cell_offset
    ldw (r7)
    add #8
    stw (r7)

    iwt r8, #gsu_iso_render_frame + map_render_frame::sx_x_q5
    to r1
    ldw (r8)
    iwt r7, #gsu_iso_row_anchor_x_q5
    ldw (r7)
    add r1
    stw (r7)

    inc r8
    inc r8
    to r1
    ldw (r8)            ; sx_y_q5
    inc r7
    inc r7
    ldw (r7)
    add r1
    stw (r7)
    bra @step_i_done
    nop

@step_i_neg:
    ; i_step == -1:
    iwt r7, #gsu_iso_row_cell_offset
    ldw (r7)
    sub #8
    stw (r7)

    iwt r8, #gsu_iso_render_frame + map_render_frame::sx_x_q5
    to r1
    ldw (r8)
    iwt r7, #gsu_iso_row_anchor_x_q5
    ldw (r7)
    sub r1
    stw (r7)

    inc r8
    inc r8
    to r1
    ldw (r8)            ; sx_y_q5
    inc r7
    inc r7
    ldw (r7)
    sub r1
    stw (r7)

@step_i_done:
    ; Reload j_cur into r9 for next i_loop_top
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    to r9
    ldw (r7)

    iwt r13, #@i_loop_top
    jmp r13
    nop

@i_loop_done:
    ; --------------------------------------------------------------------------
    ; 11. Advance J Loop
    ; --------------------------------------------------------------------------
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_rem
    ldw (r7)
    dec r0
    beq @render_done
    nop
    move r11, r0        ; r11 = new j_rem

    ; Advance j_cur += j_step
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_cur
    ldw (r7)
    move r9, r0
    iwt r7, #gsu_iso_render_frame + map_render_frame::j_step
    ldw (r7)
    with r9
    add r0

    iwt r13, #@j_loop_top
    jmp r13
    nop

@render_done:
    return
endfunction

.ifndef GSU_ISO_NO_DEFAULT_BUFFERS
; ==============================================================================
; gsu_iso_render_from_descriptor
; Pure-renderer entry point (ADR 0006) driven by a 65816-written
; `gsu_scene_descriptor` in Bank $70 GSURAM. Never polls `GSU_JOYPAD` or calls
; `iso_camera_update_controls`.
;
; Behavior:
;   - Pass 0 (`frame_half == 0`):
;       1. Reads `cam_yaw`, `cam_center_x`, `cam_center_y` from `desc_ptr`.
;       2. Updates `ISO_CAM::center_x` (+6) and `ISO_CAM::center_y` (+8).
;       3. If `cam_yaw != CACHED_YAW`, updates `ISO_CAM` trig via
;          `iso_camera_set_yaw` and recompiles archetypes via
;          `gsu_iso_compile_archetypes`.
;       4. Recomputes grid screen origin via `gsu_iso_update_origin`.
;       5. Calls `gsu_iso_render` for Pass 0 (`X in [0..127]`).
;   - Pass 1 (`frame_half != 0`):
;       Calls `gsu_iso_render` for Pass 1 (`X in [128..GSU_ISO_VIEWPORT_W-1]`)
;       reusing the Pass-0 cached archetypes and grid origin.
;
; In:
;   desc_ptr   = r1: Pointer to `gsu_scene_descriptor` in Bank $70 GSURAM
;   frame_half = r2: Active frame half (0 = Pass 0, 1 = Pass 1)
; Postconditions:
;   - `RAMBR == 0` ($70) and `ROMBR == $04` on return
;   - `gsu_iso_active_desc_ptr` records `desc_ptr` for intra-cell hooks
;   - Caller flushes plot caches (`rpix; rpix`), 8 NOPs, and `stop`
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_iso_render_from_descriptor desc_ptr, frame_half
    register desc_ptr = r1, frame_half = r2

    ; Ensure ROMBR = $04 (trig/reciprocal LUTs) and RAMBR = 0 ($70 working RAM)
    ibt r0, #$04
    romb
    ibt r0, #0
    ramb

    ; Publish active descriptor pointer for intra-cell hooks (#34/#35)
    sm (gsu_iso_active_desc_ptr), desc_ptr

    ; Pass 1 skips camera sync, archetype compilation & origin update
    moves frame_half, frame_half
    bne @desc_pass1
    nop

    ; --- Pass 0: Read camera state from Scene Render Descriptor ---
    ; desc_ptr + 0 = cam_yaw, +2 = cam_center_x, +4 = cam_center_y
    move r7, desc_ptr
    to r3
    ldw (r7)                    ; r3 = desc.cam_yaw
    inc r7
    inc r7
    to r4
    ldw (r7)                    ; r4 = desc.cam_center_x
    inc r7
    inc r7
    to r5
    ldw (r7)                    ; r5 = desc.cam_center_y

    ; Write center_x (+6) and center_y (+8) into ISO_CAM
    iwt r7, #(ISO_CAM + 6)
    from r4
    stw (r7)                    ; ISO_CAM.center_x = cam_center_x
    inc r7
    inc r7
    from r5
    stw (r7)                    ; ISO_CAM.center_y = cam_center_y

    ; Recompile archetypes only when cam_yaw != CACHED_YAW
    lm r6, (CACHED_YAW)
    from r3
    cmp r6
    beq @desc_yaw_clean
    nop

    iwt r1, #ISO_CAM
    move r2, r3                 ; r2 = desc.cam_yaw
    call iso_camera_set_yaw r1, r2

    iwt r1, #ISO_CAM
    iwt r2, #ISO_BASIS
    iwt r3, #LATTICE_V2
    iwt r4, #ARCH_TRAPS
    iwt r5, #CACHED_YAW
    call gsu_iso_compile_archetypes r1, r2, r3, r4, r5

@desc_yaw_clean:
    ; Recompute grid screen origin from ISO_CAM
    iwt r1, #MAP_BUF
    iwt r2, #ISO_CAM
    call gsu_iso_update_origin r1, r2

    ; Render Pass 0 (left half X in [0..127])
    iwt r1, #MAP_BUF
    iwt r2, #ISO_CAM
    iwt r3, #ISO_BASIS
    iwt r4, #ARCH_TRAPS
    iwt r5, #0
    iwt r6, #0
    call gsu_iso_render r1, r2, r3, r4, r5, r6
    return

@desc_pass1:
    ; Render Pass 1 (right half X in [128..GSU_ISO_VIEWPORT_W-1])
    iwt r1, #MAP_BUF
    iwt r2, #ISO_CAM
    iwt r3, #ISO_BASIS
    iwt r4, #ARCH_TRAPS
    iwt r5, #1
    iwt r6, #0
    call gsu_iso_render r1, r2, r3, r4, r5, r6
    return
endfunction
.endif ; !GSU_ISO_NO_DEFAULT_BUFFERS

.endif ; __GSU_ISO_MAP_DEFINED__
