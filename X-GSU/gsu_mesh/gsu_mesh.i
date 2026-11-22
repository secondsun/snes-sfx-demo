; ==============================================================================
; gsu_mesh.i - SuperFX Bank-$71 Hybrid 3D Mesh Importer, Sorter & Renderer
;
; Renders `.msh` scenes staged at `$71:9030` alongside a `256 x 128` hero sheet
; at `$71:0000` (`RAMBR = 1`). Uses exact `ISO_CAM` 30-deg orbital projection,
; 256-bucket ordering table (OT) back-to-front painter's sort, `compile_flat_tri`
; + `draw_flat_trap` for fast solid-colored faces, and `compile_face_traps` +
; `draw_cached_trap_ram` for distinct unlit hero UV regions.
; ==============================================================================

.ifndef __GSU_MESH_ENGINE_DEFINED__
__GSU_MESH_ENGINE_DEFINED__ = 1

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"
.include "../gsu_iso/gsu_iso_map.i"
.include "mesh_layout.i"
.include "draw_flat_trap.i"
.include "compile_flat_tri.i"

.segment "GSUCODE"

; ==============================================================================
; gsu_mesh_import_bank71
; Imports `.tab` (`$71:8000` -> `$70:TEXTURE_TABLE_RAM`) and 16-byte `sfx_mesh_header`
; (`$71:9030` -> `$70:MESH_HDR_CACHE`), configures `ISO_CAM`, and sets `GSU_INIT_FLAG = 1`.
;
; Out:
;   r3 = SFX_IMPORT_OK (0) or SFX_IMPORT_ERR_*; also stored in GSU_IMPORT_ERROR
; Postconditions:
;   - `RAMBR == 0` ($70) and `ROMBR == $04` on all exit paths
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_mesh_import_bank71
    ibt r0, #$04
    romb

    ; 1. Read & validate 8-byte `.tab` header from $71:8000
    ibt r0, #1
    ramb
    iwt r1, #BANK71_TAB_ADDR
    to r2
    ldw (r1)                ; magic
    inc r1
    inc r1
    to r3
    ldw (r1)                ; entry_count
    inc r1
    inc r1
    to r4
    ldw (r1)                ; atlas_width
    inc r1
    inc r1
    to r5
    ldw (r1)                ; stride_shift
    ibt r0, #0
    ramb

    iwt r6, #SFX_TAB_MAGIC
    from r2
    cmp r6
    beq @tab_magic_ok
    nop
    iwt r3, #SFX_IMPORT_ERR_BAD_MAGIC
    sm (GSU_IMPORT_ERROR), r3
    return
@tab_magic_ok:

    from r3
    sub #1
    bge :+
    nop
    bra @bad_tab_count
    nop
:
    iwt r6, #257
    from r3
    cmp r6
    blt @tab_count_ok
    nop
@bad_tab_count:
    iwt r3, #SFX_IMPORT_ERR_BAD_COUNT
    sm (GSU_IMPORT_ERROR), r3
    return
@tab_count_ok:

    sm (gsu_runtime_tab_count), r3
    sm (gsu_runtime_atlas_width), r4
    gsu_stack_push r3
    move r1, r5
    call gsu_iso_set_stride_shift r1
    gsu_stack_pop r3

    ; Copy `entry_count` 8-byte descriptors ($71:8008 -> $70:TEXTURE_TABLE_RAM)
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

    ; 2. Copy 16-byte `sfx_mesh_header` from $71:9030 -> $70:MESH_HDR_CACHE
    iwt r1, #BANK71_MESH_ADDR
    iwt r2, #MESH_HDR_CACHE
    ibt r12, #8
    iwt r13, #@copy_hdr_loop
@copy_hdr_loop:
    ibt r0, #1
    ramb
    ldw (r1)
    inc r1
    inc r1
    move r4, r0
    ibt r0, #0
    ramb
    from r4
    stw (r2)
    inc r2
    inc r2
    loop
    nop

    ; Validate mesh magic == SFX_MESH_MAGIC ($4D53) and 1 <= verts/faces <= 640
    lm r2, (MESH_HDR_CACHE + sfx_mesh_header::magic)
    iwt r6, #SFX_MESH_MAGIC
    from r2
    cmp r6
    beq @mesh_magic_ok
    nop
    iwt r3, #SFX_IMPORT_ERR_BAD_MAGIC
    sm (GSU_IMPORT_ERROR), r3
    return
@mesh_magic_ok:

    lm r3, (MESH_HDR_CACHE + sfx_mesh_header::vertex_count)
    from r3
    sub #1
    bge :+
    nop
    bra @bad_mesh_count
    nop
:
    iwt r6, #(MESH_MAX_VERTS + 1)
    from r3
    cmp r6
    blt :+
    nop
    bra @bad_mesh_count
    nop
:
    lm r3, (MESH_HDR_CACHE + sfx_mesh_header::face_count)
    from r3
    sub #1
    bge :+
    nop
    bra @bad_mesh_count
    nop
:
    from r3
    cmp r6
    blt @mesh_counts_ok
    nop
@bad_mesh_count:
    iwt r3, #SFX_IMPORT_ERR_BAD_COUNT
    sm (GSU_IMPORT_ERROR), r3
    return
@mesh_counts_ok:

    ; 2b. Optional companion tactical floor grid at $71:BANK71_MAP_ADDR ($71:8808)
    ibt r0, #1
    ramb
    iwt r1, #BANK71_MAP_ADDR
    to r2
    ldw (r1)                ; magic
    inc r1
    inc r1
    to r3
    ldw (r1)                ; low byte = cols, high byte = rows
    ibt r0, #0
    ramb

    iwt r6, #SFX_MGRID_MAGIC
    from r2
    cmp r6
    bne @no_mesh_grid
    nop

    ; Validate 1 <= cols <= 16 and 1 <= rows <= 16
    from r3
    lob
    move r4, r0             ; r4 = cols
    from r3
    hib
    move r5, r0             ; r5 = rows
    from r4
    sub #1
    blt @no_mesh_grid
    nop
    from r5
    sub #1
    blt @no_mesh_grid
    nop
    iwt r6, #17
    from r4
    cmp r6
    bge @no_mesh_grid
    nop
    from r5
    cmp r6
    bge @no_mesh_grid
    nop

    ; total_words = 6 (12B header) + cols * rows (Y words)
    from r4
    umult r5                ; r0 = cols * rows (1..256)
    add #6
    move r12, r0
    iwt r1, #BANK71_MAP_ADDR
    iwt r2, #MAP_BUF
    iwt r13, #@copy_mgrid_loop
@copy_mgrid_loop:
    ibt r0, #1
    ramb
    ldw (r1)
    inc r1
    inc r1
    move r4, r0
    ibt r0, #0
    ramb
    from r4
    stw (r2)
    inc r2
    inc r2
    loop
    nop
    ibt r0, #1
    sm (MESH_HAS_GRID), r0
    bra @mgrid_done
    nop

@no_mesh_grid:
    ibt r0, #0
    sm (MESH_HAS_GRID), r0
@mgrid_done:
.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
    ; Initialize tactical highlight palette slots from sfx_mesh_grid::hl_palette_packed
    ; (0 or no grid -> default GSU_HL_COLOR_MOVE/ATTACK/CURSOR)
    lm r0, (MESH_HAS_GRID)
    moves r0, r0
    beq @hl_use_defaults
    nop
    lm r2, (MAP_BUF + sfx_mesh_grid_header::hl_palette_packed)
    moves r2, r2
    beq @hl_use_defaults
    nop
    iwt r6, #$000F
    from r2
    and r6
    sm (MESH_HL_COLOR_MOVE), r0
    from r2
    lsr
    lsr
    lsr
    lsr
    and r6
    sm (MESH_HL_COLOR_ATTACK), r0
    from r2
    hib
    and r6
    sm (MESH_HL_COLOR_CURSOR), r0
    bra @hl_cols_ready
    nop
@hl_use_defaults:
    iwt r0, #GSU_HL_COLOR_MOVE
    sm (MESH_HL_COLOR_MOVE), r0
    iwt r0, #GSU_HL_COLOR_ATTACK
    sm (MESH_HL_COLOR_ATTACK), r0
    iwt r0, #GSU_HL_COLOR_CURSOR
    sm (MESH_HL_COLOR_CURSOR), r0
@hl_cols_ready:
.endif

    ; 3. Initialize ISO_CAM according to GSU_LOAD_MODE
    lm r1, (GSU_LOAD_MODE)
    from r1
    sub #SFX_LOAD_MODE_MAP
    bne @full_cam_init
    nop
    lm r2, (ISO_CAM + 2)
    lm r3, (ISO_CAM + 4)
    from r2
    or r3
    bne @reset_cam_pos
    nop

@full_cam_init:
    iwt r1, #ISO_CAM
    lm r2, (MESH_HDR_CACHE + sfx_mesh_header::default_yaw)
    call iso_camera_set_yaw r1, r2

@reset_cam_pos:
    iwt r1, #(ISO_CAM + 6)
    iwt r0, #GSU_ISO_CENTER_X
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_HDR_CACHE + sfx_mesh_header::default_center_y)
    stw (r1)
    inc r1
    inc r1
    ibt r0, #0
    stw (r1)                ; cam_x = 0
    inc r1
    inc r1
    stw (r1)                ; cam_z = 0

    iwt r0, #1
    sm (GSU_INIT_FLAG), r0
    iwt r3, #SFX_IMPORT_OK
    sm (GSU_IMPORT_ERROR), r3
    return
endfunction

; ==============================================================================
; gsu_mesh_build_scene
; Pass-0 front-end: projects all mesh vertices via `ISO_CAM`, clears the
; 256-bucket ordering table, frustum/backface-culls visible faces, and links
; them back-to-front by integer depth into `MESH_OT_HEADS` / `MESH_OT_NEXT`.
;
; Postconditions:
;   - `RAMBR == 0` ($70)
; Clobbers:
;   r0, r1, r2, r3, r4, r5, r6, r7, r8, r9, r11, r12, r13, r14
; ==============================================================================
function gsu_mesh_build_scene
    ; --- 1. Project all vertices ($71:verts_offset -> $70:MESH_PROJ_VERTS & MESH_VERT_DEPTH) ---
    ; Execute inside 512B GSU instruction cache (474+ vertices + 256 OT bucket clears)
    ibt r0, #0
    ramb
    lm r11, (MESH_HDR_CACHE + sfx_mesh_header::verts_offset)
    iwt r1, #MESH_PROJ_VERTS
    iwt r2, #MESH_VERT_DEPTH
    lm r12, (MESH_HDR_CACHE + sfx_mesh_header::vertex_count)

    .align 16, $01
@proj_cbr_start:
    cache
    iwt r13, #@proj_vert_loop

@proj_vert_loop:
    ibt r0, #1
    ramb
    to r3
    ldw (r11)               ; r3 = vx (Q10.6)
    inc r11
    inc r11
    to r4
    ldw (r11)               ; r4 = vy (Q10.6)
    inc r11
    inc r11
    to r5
    ldw (r11)               ; r5 = vz (Q10.6)
    inc r11
    inc r11

    ibt r0, #0
    ramb

    lm r6, (ISO_CAM + 2)    ; mul_b = sin_yaw (Q2.14)
    from r3
    to r7
    fmult                   ; r7 = vx * sin
    from r5
    to r8
    fmult                   ; r8 = vz * sin

    lm r6, (ISO_CAM + 4)    ; mul_b = cos_yaw (Q2.14)
    from r3
    to r9
    fmult                   ; r9 = vx * cos
    from r5
    fmult                   ; r0 = vz * cos
    with r7
    add r0                  ; r7 = rz_q4 = vx * sin + vz * cos
    with r9
    sub r8                  ; r9 = rx_q4 = vx * cos - vz * sin

    ; sx = ((rx_q4 + 8) >> 4) + center_x   [using fmult(., $1000) for >> 4]
    with r9
    add #8
    iwt r6, #$1000
    from r9
    fmult
    lm r6, (ISO_CAM + 6)    ; center_x
    add r6
    stw (r1)
    inc r1
    inc r1

    ; sy = ((((rz_q4 >> 1) - fmult(vy, $376D)) + 8) >> 4) + center_y
    iwt r6, #$376D
    from r4
    fmult                   ; r0 = vy * cos(30 deg) in Q12.4
    move r8, r7
    with r8
    asr
    with r8
    sub r0                  ; r8 = ry_q4
    with r8
    add #8
    iwt r6, #$1000
    from r8
    fmult
    lm r6, (ISO_CAM + 8)    ; center_y
    add r6
    stw (r1)
    inc r1
    inc r1

    ; depth = (((rz_q4 - (rz_q4 >> 3)) + fmult(vy, $2000)) >> 6)  [1 OT bucket = 4 depth px]
    move r8, r7
    with r8
    asr
    with r8
    asr
    with r8
    asr
    from r7
    sub r8
    move r8, r0             ; r8 = 7/8 * rz_q4
    iwt r6, #$2000
    from r4
    fmult                   ; r0 = 0.5 * vy in Q12.4
    with r8
    add r0
    iwt r6, #$0400
    from r8
    fmult
    stw (r2)
    inc r2
    loop
    inc r2

    ; --- 2. Clear 256-bucket Ordering Table ($FFFF = empty) ---
    iwt r1, #MESH_OT_HEADS
    iwt r12, #MESH_OT_BUCKETS
    iwt r0, #$FFFF
    move r13, r15
        stw (r1)
        inc r1
        loop
        inc r1
@proj_cbr_end:
    .assert (@proj_cbr_end - @proj_cbr_start) <= 512, error, "gsu_mesh @proj_vert_loop exceeds 512B GSU cache!"

    ; --- 3. Classify, frustum/backface cull, and bucket faces into MESH_OT_HEADS ---
    ibt r0, #0
    sm (MESH_CUR_FACE_IDX), r0
    lm r0, (MESH_HDR_CACHE + sfx_mesh_header::faces_offset)
    sm (MESH_CUR_FACE_PTR), r0
    lm r0, (MESH_HDR_CACHE + sfx_mesh_header::face_count)
    sm (MESH_BLD_FACE_REM), r0

    .align 16, $01
@bld_cbr_start:
    cache

@bld_face_loop:
    lm r1, (MESH_CUR_FACE_PTR)
    ibt r0, #1
    ramb
    to r2
    ldw (r1)                ; r2 = flags_color
    inc r1
    inc r1
    to r3
    ldw (r1)                ; r3 = v0_off
    inc r1
    inc r1
    to r4
    ldw (r1)                ; r4 = v1_off
    inc r1
    inc r1
    to r5
    ldw (r1)                ; r5 = v2_off
    inc r1
    inc r1
    to r6
    ldw (r1)                ; r6 = v3_off
    ibt r0, #0
    ramb

    ; Advance MESH_CUR_FACE_PTR by 20 for next iteration (r1 is already ptr + 8)
    with r1
    add #12
    sm (MESH_CUR_FACE_PTR), r1

    sm (MESH_FACE_FLAGS), r2

    ; Load projected vertex coordinates (x0..x3, y0..y3) into scratch GSURAM & compute bbox
    iwt r1, #MESH_PROJ_VERTS
    from r1
    to r11
    add r3
    ldw (r11)
    sm (MESH_FACE_X0), r0
    move r7, r0             ; min_x
    move r8, r0             ; max_x
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y0), r0
    move r9, r0             ; min_y
    move r12, r0            ; max_y

    from r1
    to r11
    add r4
    ldw (r11)
    sm (MESH_FACE_X1), r0
    cmp r7
    bge :+
    nop
    move r7, r0
:
    from r8
    cmp r0
    bge :+
    nop
    move r8, r0
:
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y1), r0
    cmp r9
    bge :+
    nop
    move r9, r0
:
    from r12
    cmp r0
    bge :+
    nop
    move r12, r0
:

    from r1
    to r11
    add r5
    ldw (r11)
    sm (MESH_FACE_X2), r0
    cmp r7
    bge :+
    nop
    move r7, r0
:
    from r8
    cmp r0
    bge :+
    nop
    move r8, r0
:
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y2), r0
    cmp r9
    bge :+
    nop
    move r9, r0
:
    from r12
    cmp r0
    bge :+
    nop
    move r12, r0
:

    ; V3 (for quads only; tris reuse V2)
    iwt r11, #MESH_FACE_FLAG_QUAD
    from r2
    and r11
    beq @bbox_ready
    nop
    from r1
    to r11
    add r6
    ldw (r11)
    sm (MESH_FACE_X3), r0
    cmp r7
    bge :+
    nop
    move r7, r0
:
    from r8
    cmp r0
    bge :+
    nop
    move r8, r0
:
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y3), r0
    cmp r9
    bge :+
    nop
    move r9, r0
:
    from r12
    cmp r0
    bge :+
    nop
    move r12, r0
:

@bbox_ready:
    ; Frustum cull: max_x < 0 || min_x >= VIEWPORT_W || max_y <= 0 || min_y >= 160
    moves r8, r8
    bmi @bld_cull_tramp
    nop
    iwt r11, #GSU_ISO_VIEWPORT_W
    from r7
    cmp r11
    bge @bld_cull_tramp
    nop
    from r12
    sub #1
    blt @bld_cull_tramp
    nop
    iwt r11, #160
    from r9
    cmp r11
    bge @bld_cull_tramp
    nop
    ; Span guard: (max_x - min_x) < 120 && (max_y - min_y) < 120
    ; Also guarantees |dx|, |dy| <= 119 so |dx*dy| <= 14161 (exact signed 16-bit cross!)
    iwt r11, #120
    from r8
    sub r7
    cmp r11
    bge @bld_cull_tramp
    nop
    from r12
    sub r9
    cmp r11
    blt @span_ok
    nop
@bld_cull_tramp:
    iwt r15, #@bld_next_face
    nop
@span_ok:

    ; Compute 2-bit half-screen overlap mask while r7=min_x, r8=max_x are live:
    ;   bit 0: overlaps Pass 0 [0..127] (min_x < 128)
    ;   bit 1: overlaps Pass 1 [128..viewport_w-1] (max_x >= 128)
    ibt r0, #0
    iwt r11, #128
    from r7
    cmp r11
    bge :+
    nop
    inc r0
:
    from r8
    cmp r11
    blt :+
    nop
    add #2
:
    sm (MESH_FACE_BASE_X), r0 ; temp hold halfmask until @face_visible

    ; Compute sum3 = d0 + d1 + d2 and stash d3_off before lmult clobbers r3..r6
    with r3
    lsr                     ; d0_off = v0_off >> 1
    with r4
    lsr                     ; d1_off = v1_off >> 1
    with r5
    lsr                     ; d2_off = v2_off >> 1
    from r6
    lsr
    sm (MESH_U0_Q88), r0    ; temp hold d3_off
    iwt r1, #MESH_VERT_DEPTH
    from r1
    to r11
    add r3
    to r3
    ldw (r11)
    from r1
    to r11
    add r4
    ldw (r11)
    with r3
    add r0
    from r1
    to r11
    add r5
    ldw (r11)
    add r3
    sm (MESH_V0_Q88), r0    ; sum3 = d0 + d1 + d2

    ; Exact signed 16-bit CW backface cull on tri0 = (V0, V1, V2):
    ;   |dx|,|dy| <= 119 => |dx1*dy2|, |dy1*dx2| <= 14161, diff <= 28322 < 32767
    lm r7, (MESH_FACE_X0)
    lm r8, (MESH_FACE_Y0)
    lm r1, (MESH_FACE_X1)
    with r1
    sub r7                  ; r1 = dx1
    lm r2, (MESH_FACE_Y1)
    with r2
    sub r8                  ; r2 = dy1
    lm r3, (MESH_FACE_X2)
    with r3
    sub r7                  ; r3 = dx2
    lm r5, (MESH_FACE_Y2)
    with r5
    sub r8                  ; r5 = dy2

    move r6, r5
    from r1
    lmult                   ; r4 = signed16(dx1 * dy2)
    move r8, r4
    move r6, r3
    from r2
    lmult                   ; r4 = signed16(dy1 * dx2)
    from r4
    cmp r8                  ; r4 < r8  <=>  dx1*dy2 > dy1*dx2
    blt @face_visible
    nop
    iwt r15, #@try_quad_tri1
    nop

@face_visible:
    ; Compute avg_d: quads = (d0+d1+d2+d3) >> 2, tris = fmult(d0+d1+d2, $5555)
    lm r2, (MESH_V0_Q88)
    lm r0, (MESH_FACE_FLAGS)
    iwt r11, #MESH_FACE_FLAG_QUAD
    and r11
    beq @avg_d_tri
    nop
    lm r0, (MESH_U0_Q88)    ; d3_off
    iwt r1, #MESH_VERT_DEPTH
    add r1
    move r11, r0
    ldw (r11)
    add r2
    asr
    asr
    bra @bucket_calc
    nop
@avg_d_tri:
    iwt r6, #$5555
    from r2
    fmult
@bucket_calc:
    iwt r6, #128
    add r6
    moves r0, r0
    bpl :+
    nop
    ibt r0, #0
:
    iwt r6, #256
    cmp r6
    blt :+
    nop
    iwt r0, #255
:
    ; Prepend MESH_CUR_FACE_IDX onto MESH_OT_HEADS[bucket * 2]
    add r0
    iwt r1, #MESH_OT_HEADS
    add r1
    move r1, r0             ; r1 = &MESH_OT_HEADS[bucket]
    to r2
    ldw (r1)                ; r2 = old_head
    lm r3, (MESH_CUR_FACE_IDX)
    from r3
    stw (r1)                ; MESH_OT_HEADS[bucket] = face_idx

    ; Store MESH_FACE_HALFMASK[face_idx] (1 byte) for O(1) per-pass rejection
    iwt r1, #MESH_FACE_HALFMASK
    from r3
    add r1
    move r1, r0
    lm r0, (MESH_FACE_BASE_X)
    stb (r1)

    from r3
    add r3
    iwt r1, #MESH_OT_NEXT
    add r1
    move r1, r0             ; r1 = &MESH_OT_NEXT[face_idx]
    from r2
    stw (r1)                ; MESH_OT_NEXT[face_idx] = old_head

@bld_next_face:
    lm r0, (MESH_CUR_FACE_IDX)
    inc r0
    sm (MESH_CUR_FACE_IDX), r0
    lm r0, (MESH_BLD_FACE_REM)
    dec r0
    sm (MESH_BLD_FACE_REM), r0
    beq :+
    nop
    iwt r15, #@bld_face_loop
    nop
:
    return
@bld_cbr_end:
    .assert (@bld_cbr_end - @bld_cbr_start) <= 512, error, "gsu_mesh @bld_face_loop exceeds 512B GSU cache!"

; Out-of-line fallback when quad tri0 is backfacing (keeps hot @bld_face_loop <= 512B cache!)
@try_quad_tri1:
    lm r0, (MESH_FACE_FLAGS)
    iwt r11, #MESH_FACE_FLAG_QUAD
    and r11
    bne :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    ; Check tri1 = (V0, V2, V3) using exact signed 16-bit cross-product
    lm r7, (MESH_FACE_X0)
    lm r8, (MESH_FACE_Y0)
    lm r1, (MESH_FACE_X2)
    with r1
    sub r7
    lm r2, (MESH_FACE_Y2)
    with r2
    sub r8
    lm r3, (MESH_FACE_X3)
    with r3
    sub r7
    lm r5, (MESH_FACE_Y3)
    with r5
    sub r8

    move r6, r5
    from r1
    lmult
    move r8, r4
    move r6, r3
    from r2
    lmult
    from r4
    cmp r8
    bge :+
    nop
    iwt r15, #@face_visible
    nop
:
    iwt r15, #@bld_next_face
    nop
endfunction

; ==============================================================================
; gsu_mesh_render_pass
; Walks `MESH_OT_HEADS[0..255]` back-to-front and rasterizes all visible faces
; overlapping `frame_half` (`0` = X in `[0..127]`, `1` = X in `[128..255]`).
;
; In:
;   r1 = frame_half (0 or 1)
; Postconditions:
;   - `RAMBR == 0` ($70) on return
; Clobbers:
;   r0..r14
; ==============================================================================
function gsu_mesh_render_pass
    sm (MESH_CUR_FRAME_HALF), r1
    ibt r0, #0
    sm (MESH_CUR_BUCKET), r0

@bucket_loop:
    lm r0, (MESH_CUR_BUCKET)
    add r0
    iwt r1, #MESH_OT_HEADS
    add r1
    move r1, r0
    ldw (r1)                ; r0 = head face_idx ($FFFF if empty)
    sm (MESH_CUR_FACE_IDX), r0

@chain_loop:
    lm r3, (MESH_CUR_FACE_IDX)
    moves r3, r3
    bpl :+
    nop
    iwt r15, #@next_bucket
    nop
:
    ; Read MESH_OT_NEXT[node * 2] before anything clobbers r3
    from r3
    add r3
    iwt r1, #MESH_OT_NEXT
    add r1
    move r1, r0
    ldw (r1)
    sm (MESH_CUR_NEXT_FACE), r0

.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
    ; Dispatch tagged OT nodes: 0..639 = mesh face, 640..703 = cell highlight, 704..711 = entity mask
    iwt r11, #MESH_OT_HL_BASE
    from r3
    cmp r11
    blt @r_is_mesh_face
    nop
    iwt r11, #MESH_OT_ENT_BASE
    from r3
    cmp r11
    blt @r_dispatch_hl
    nop
    iwt r15, #@r_do_entity_mask
    nop
@r_dispatch_hl:
    iwt r15, #@r_do_highlight
    nop
@r_is_mesh_face:
.endif

    ; O(1) half-screen rejection via MESH_FACE_HALFMASK[face_idx] (skips Bank-$71 read + bbox)
    iwt r1, #MESH_FACE_HALFMASK
    from r3
    add r1
    move r1, r0
    ldb (r1)
    lm r11, (MESH_CUR_FRAME_HALF)
    inc r11                 ; 1 for Pass 0 (bit 0), 2 for Pass 1 (bit 1)
    and r11
    bne :+
    nop
    iwt r15, #@next_face
    nop
:

    ; face_ptr = faces_offset + face_idx * 20  (16-bit safe for face_idx 0..639)
    from r3
    add r3                  ; x2
    add r0                  ; x4
    move r6, r0
    add r0                  ; x8
    add r0                  ; x16
    add r6                  ; x20
    lm r1, (MESH_HDR_CACHE + sfx_mesh_header::faces_offset)
    add r1
    move r1, r0

    ; Read 18 bytes of mesh_face_entry from $71 into registers/GSURAM
    ibt r0, #1
    ramb
    to r2
    ldw (r1)                ; flags_color
    inc r1
    inc r1
    to r3
    ldw (r1)                ; v0_off
    inc r1
    inc r1
    to r4
    ldw (r1)                ; v1_off
    inc r1
    inc r1
    to r5
    ldw (r1)                ; v2_off
    inc r1
    inc r1
    to r6
    ldw (r1)                ; v3_off
    inc r1
    inc r1
    to r7
    ldw (r1)                ; uv0
    inc r1
    inc r1
    to r8
    ldw (r1)                ; uv1
    inc r1
    inc r1
    to r9
    ldw (r1)                ; uv2
    inc r1
    inc r1
    to r11
    ldw (r1)                ; uv3
    ibt r0, #0
    ramb

    sm (MESH_FACE_FLAGS), r2
    sm (MESH_FACE_UV0), r7
    sm (MESH_FACE_UV1), r8
    sm (MESH_FACE_UV2), r9
    sm (MESH_FACE_UV3), r11

    ; Unpack projected (sx, sy) for V0..V3 and compute min_x, max_x, min_y
    iwt r1, #MESH_PROJ_VERTS
    from r1
    add r3
    move r11, r0
    ldw (r11)
    sm (MESH_FACE_X0), r0
    move r7, r0             ; min_x
    move r8, r0             ; max_x
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y0), r0
    move r9, r0             ; min_y

    from r1
    add r4
    move r11, r0
    ldw (r11)
    sm (MESH_FACE_X1), r0
    from r0
    cmp r7
    bge :+
    nop
    move r7, r0
:
    from r8
    cmp r0
    bge :+
    nop
    move r8, r0
:
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y1), r0
    from r0
    cmp r9
    bge :+
    nop
    move r9, r0
:

    from r1
    add r5
    move r11, r0
    ldw (r11)
    sm (MESH_FACE_X2), r0
    from r0
    cmp r7
    bge :+
    nop
    move r7, r0
:
    from r8
    cmp r0
    bge :+
    nop
    move r8, r0
:
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y2), r0
    from r0
    cmp r9
    bge :+
    nop
    move r9, r0
:

    iwt r11, #MESH_FACE_FLAG_QUAD
    from r2
    and r11
    beq @r_bbox_done
    nop
    from r1
    add r6
    move r11, r0
    ldw (r11)
    sm (MESH_FACE_X3), r0
    from r0
    cmp r7
    bge :+
    nop
    move r7, r0
:
    from r8
    cmp r0
    bge :+
    nop
    move r8, r0
:
    inc r11
    inc r11
    ldw (r11)
    sm (MESH_FACE_Y3), r0
    from r0
    cmp r9
    bge :+
    nop
    move r9, r0
:

@r_bbox_done:
    ; Half-screen X rejection & overflow-free relative anchor selection:
    ;   Pass 0: skip if max_x < 0 || min_x >= 128; base_x = clamp(min_x, 0, 120)
    ;   Pass 1: skip if max_x < 128 || min_x >= 256; base_x = clamp(min_x, 128, 248)
    lm r0, (MESH_CUR_FRAME_HALF)
    moves r0, r0
    bne @r_pass1_clip
    nop

    moves r8, r8
    bpl :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r11, #128
    from r7
    cmp r11
    blt :+
    nop
    iwt r15, #@next_face
    nop
:
    ; base_x = clamp(min_x, 0, 120)
    move r0, r7
    moves r0, r0
    bpl :+
    nop
    ibt r0, #0
:
    iwt r11, #120
    cmp r11
    blt :+
    nop
    move r0, r11
:
    bra @r_base_x_set
    nop

@r_pass1_clip:
    iwt r11, #128
    from r8
    cmp r11
    bge :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r12, #GSU_ISO_VIEWPORT_W
    from r7
    cmp r12
    blt :+
    nop
    iwt r15, #@next_face
    nop
:
    ; base_x = clamp(min_x, 128, GSU_ISO_VIEWPORT_W - 8)
    move r0, r7
    cmp r11
    bge :+
    nop
    move r0, r11
:
    iwt r11, #(GSU_ISO_VIEWPORT_W - 8)
    cmp r11
    blt :+
    nop
    move r0, r11
:

@r_base_x_set:
    sm (MESH_FACE_BASE_X), r0

    ; base_y = clamp(min_y, 0, 159)
    move r0, r9
    moves r0, r0
    bpl :+
    nop
    ibt r0, #0
:
    iwt r11, #159
    cmp r11
    blt :+
    nop
    move r0, r11
:
    sm (MESH_FACE_BASE_Y), r0

    ; Dispatch textured vs flat face
    lm r2, (MESH_FACE_FLAGS)
    iwt r11, #MESH_FACE_FLAG_TEX
    from r2
    and r11
    beq @r_do_flat
    nop
    iwt r15, #@r_do_textured
    nop

; ------------------------------------------------------------------------------
; Flat-Shaded Path (Tri0 and optional Tri1 = (V0, V2, V3))
; ------------------------------------------------------------------------------
@r_do_flat:
    iwt r11, #$00FF
    from r2
    and r11
    sm (MESH_CUR_COLOR), r0

    lm r7, (MESH_FACE_BASE_X)
    lm r8, (MESH_FACE_BASE_Y)
    iwt r1, #MESH_TRI_PTS
    lm r0, (MESH_FACE_X0)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y0)
    sub r8
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_X1)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y1)
    sub r8
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_X2)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y2)
    sub r8
    stw (r1)

    iwt r1, #MESH_TRI_PTS
    iwt r2, #MESH_TMP_FLAT_TRAPS
    call compile_flat_tri
    moves r3, r0
    beq @r_flat_tri1
    nop

    iwt r1, #MESH_TMP_FLAT_TRAPS
@r_flat0_trap_loop:
    sm (MESH_TRAP_PTR), r1
    sm (MESH_TRAP_REM), r3
    lm r3, (MESH_FACE_BASE_X)
    lm r4, (MESH_FACE_BASE_Y)
    lm r5, (MESH_CUR_COLOR)
    lm r7, (MESH_CUR_FRAME_HALF)
    call draw_flat_trap
    lm r3, (MESH_TRAP_REM)
    dec r3
    beq @r_flat_tri1
    nop
    lm r1, (MESH_TRAP_PTR)
    ibt r0, #.sizeof(flat_trap)
    with r1
    add r0
    bra @r_flat0_trap_loop
    nop

@r_flat_tri1:
    lm r2, (MESH_FACE_FLAGS)
    iwt r11, #MESH_FACE_FLAG_QUAD
    from r2
    and r11
    bne :+
    nop
    iwt r15, #@next_face
    nop
:
    lm r7, (MESH_FACE_BASE_X)
    lm r8, (MESH_FACE_BASE_Y)
    iwt r1, #(MESH_TRI_PTS + 4) ; keep V0 at +0,+2; overwrite V1 slot with V2, V2 slot with V3
    lm r0, (MESH_FACE_X2)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y2)
    sub r8
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_X3)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y3)
    sub r8
    stw (r1)

    iwt r1, #MESH_TRI_PTS
    iwt r2, #MESH_TMP_FLAT_TRAPS
    call compile_flat_tri
    moves r3, r0
    bne :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r1, #MESH_TMP_FLAT_TRAPS
@r_flat1_trap_loop:
    sm (MESH_TRAP_PTR), r1
    sm (MESH_TRAP_REM), r3
    lm r3, (MESH_FACE_BASE_X)
    lm r4, (MESH_FACE_BASE_Y)
    lm r5, (MESH_CUR_COLOR)
    lm r7, (MESH_CUR_FRAME_HALF)
    call draw_flat_trap
    lm r3, (MESH_TRAP_REM)
    dec r3
    beq @r_flat1_done
    nop
    lm r1, (MESH_TRAP_PTR)
    ibt r0, #.sizeof(flat_trap)
    with r1
    add r0
    bra @r_flat1_trap_loop
    nop
@r_flat1_done:
    iwt r15, #@next_face
    nop

; ------------------------------------------------------------------------------
; Textured Hero Path (compile_face_traps Mode 3 + draw_cached_trap_ram)
; ------------------------------------------------------------------------------
@r_do_textured:
    iwt r1, #MESH_TMP_FACEDEF
    ; +0: flags (QUAD ? 1 : 0)
    lm r2, (MESH_FACE_FLAGS)
    iwt r11, #MESH_FACE_FLAG_QUAD
    from r2
    and r11
    beq :+
    nop
    ibt r0, #FACE_DEF_FLAG_QUAD
    bra :++
    nop
:
    ibt r0, #FACE_DEF_FLAG_TRI
:
    stw (r1)
    inc r1
    inc r1
    ibt r0, #UV_MODE_SLOPE
    stw (r1)                ; +2: uv_mode = 3
    inc r1
    inc r1
    ibt r0, #0
    stw (r1)                ; +4: tex_id = 0
    inc r1
    inc r1
    ibt r0, #8
    stw (r1)                ; +6: stride_shift = 8 (256-wide hero sheet)
    inc r1
    inc r1
    ibt r0, #0
    stw (r1)                ; +8: cos_yaw
    inc r1
    inc r1
    stw (r1)                ; +10: sin_yaw
    inc r1
    inc r1

    ; Compute base UV0 (u0, v0) and save (u0 << 8, v0 << 8)
    iwt r11, #$00FF
    iwt r12, #$007F
    lm r3, (MESH_FACE_UV0)
    from r3
    and r11
    move r5, r0             ; r5 = u0 (0..255)
    swap
    sm (MESH_U0_Q88), r0
    from r3
    hib
    and r12
    move r6, r0             ; r6 = v0 (0..127)
    swap
    sm (MESH_V0_Q88), r0

    lm r7, (MESH_FACE_BASE_X)
    lm r8, (MESH_FACE_BASE_Y)

    ; V0 (rel coords, uv = 0,0)
    lm r0, (MESH_FACE_X0)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y0)
    sub r8
    stw (r1)
    inc r1
    inc r1
    ibt r0, #0
    stw (r1)
    inc r1
    inc r1
    stw (r1)
    inc r1
    inc r1

    ; V1
    lm r0, (MESH_FACE_X1)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y1)
    sub r8
    stw (r1)
    inc r1
    inc r1
    lm r3, (MESH_FACE_UV1)
    from r3
    and r11
    sub r5
    swap                    ; du1 << 8
    stw (r1)
    inc r1
    inc r1
    from r3
    hib
    and r12
    sub r6
    swap                    ; dv1 << 8
    stw (r1)
    inc r1
    inc r1

    ; V2
    lm r0, (MESH_FACE_X2)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y2)
    sub r8
    stw (r1)
    inc r1
    inc r1
    lm r3, (MESH_FACE_UV2)
    from r3
    and r11
    sub r5
    swap                    ; du2 << 8
    stw (r1)
    inc r1
    inc r1
    from r3
    hib
    and r12
    sub r6
    swap                    ; dv2 << 8
    stw (r1)
    inc r1
    inc r1

    ; V3 (always populate cleanly)
    lm r0, (MESH_FACE_X3)
    sub r7
    stw (r1)
    inc r1
    inc r1
    lm r0, (MESH_FACE_Y3)
    sub r8
    stw (r1)
    inc r1
    inc r1
    lm r3, (MESH_FACE_UV3)
    from r3
    and r11
    sub r5
    swap                    ; du3 << 8
    stw (r1)
    inc r1
    inc r1
    from r3
    hib
    and r12
    sub r6
    swap                    ; dv3 << 8
    stw (r1)

    iwt r1, #MESH_TMP_FACEDEF
    iwt r2, #MESH_TMP_TEX_TRAPS
    call compile_face_traps r1, r2
    moves r3, r0
    bne :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r1, #MESH_TMP_TEX_TRAPS
@r_tex_trap_loop:
    sm (MESH_TRAP_PTR), r1
    sm (MESH_TRAP_REM), r3
    lm r3, (MESH_FACE_BASE_X)
    lm r4, (MESH_FACE_BASE_Y)
    lm r5, (MESH_U0_Q88)
    lm r6, (MESH_V0_Q88)
    lm r7, (MESH_CUR_FRAME_HALF)
    call draw_cached_trap_ram
    lm r3, (MESH_TRAP_REM)
    dec r3
    bne :+
    nop
    iwt r15, #@next_face
    nop
:
    lm r1, (MESH_TRAP_PTR)
    iwt r0, #.sizeof(cached_trap)
    with r1
    add r0
    bra @r_tex_trap_loop
    nop

.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
; ------------------------------------------------------------------------------
; Interleaved OT Node: Tactical Cell Highlight (`MESH_OT_HL_BASE + k`, k=0..63)
; ------------------------------------------------------------------------------
@r_do_highlight:
    iwt r11, #MESH_OT_HL_BASE
    from r3
    sub r11                 ; r0 = k (0..63)
    add r0                  ; 2*k
    move r6, r0
    add r0                  ; 4*k
    add r6                  ; 6*k
    iwt r11, #MESH_HL_POOL
    add r11
    move r1, r0             ; r1 = &MESH_HL_POOL[k]
    to r7
    ldw (r1)                ; r7 = floor_cx
    inc r1
    inc r1
    to r8
    ldw (r1)                ; r8 = floor_cy
    inc r1
    inc r1
    to r9
    ldw (r1)                ; r9 = color_idx

    ; Half-screen X reject to prevent Q8.8 wrap in gsu_draw_highlight_trap
    lm r6, (MESH_HL_HALF_SPAN_X)
    lm r0, (MESH_CUR_FRAME_HALF)
    moves r0, r0
    bne @r_hl_pass1_chk
    nop
    from r7
    add r6                  ; max_x = cx + half_span
    moves r0, r0
    bpl :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r11, #128
    from r7
    sub r6                  ; min_x = cx - half_span
    cmp r11
    blt @r_hl_draw
    nop
    iwt r15, #@next_face
    nop

@r_hl_pass1_chk:
    iwt r11, #128
    from r7
    add r6                  ; max_x = cx + half_span
    cmp r11
    bge :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r11, #GSU_ISO_VIEWPORT_W
    from r7
    sub r6                  ; min_x = cx - half_span
    cmp r11
    blt @r_hl_draw
    nop
    iwt r15, #@next_face
    nop

@r_hl_draw:
    sm (MESH_FACE_BASE_X), r7
    sm (MESH_FACE_BASE_Y), r8
    sm (MESH_CUR_COLOR), r9
    lm r3, (MESH_HL_TRAP_COUNT)
    moves r3, r3
    bne :+
    nop
    iwt r15, #@next_face
    nop
:
    iwt r1, #MESH_HL_TRAPS
@r_hl_trap_loop:
    sm (MESH_TRAP_PTR), r1
    sm (MESH_TRAP_REM), r3
    lm r2, (MESH_FACE_BASE_X)
    lm r3, (MESH_FACE_BASE_Y)
    lm r4, (MESH_CUR_FRAME_HALF)
    lm r5, (MESH_CUR_COLOR)
    call gsu_draw_highlight_trap r1, r2, r3, r4, r5
    lm r3, (MESH_TRAP_REM)
    dec r3
    beq @r_hl_done
    nop
    lm r1, (MESH_TRAP_PTR)
    ibt r0, #.sizeof(flat_trap)
    with r1
    add r0
    bra @r_hl_trap_loop
    nop
@r_hl_done:
    iwt r15, #@next_face
    nop

; ------------------------------------------------------------------------------
; Interleaved OT Node: Entity 1-Bit Sprite Mask Cutout (`MESH_OT_ENT_BASE + slot`)
; ------------------------------------------------------------------------------
@r_do_entity_mask:
    iwt r11, #MESH_OT_ENT_BASE
    from r3
    sub r11                 ; r0 = slot (0..7)
    add r0                  ; r0 = slot * 2
    move r6, r0

    iwt r11, #MESH_ENT_SLOT_PTR
    from r11
    add r6
    move r11, r0
    to r1
    ldw (r11)               ; r1 = slot_ptr

    iwt r11, #MESH_ENT_SX
    from r11
    add r6
    move r11, r0
    to r2
    ldw (r11)               ; r2 = sx

    iwt r11, #MESH_ENT_SY
    from r11
    add r6
    move r11, r0
    to r3
    ldw (r11)               ; r3 = sy

    lm r4, (MESH_CUR_FRAME_HALF)
    call gsu_punch_sprite_mask r1, r2, r3, r4
    iwt r15, #@next_face
    nop
.endif

@next_face:
    lm r0, (MESH_CUR_NEXT_FACE)
    sm (MESH_CUR_FACE_IDX), r0
    iwt r15, #@chain_loop
    nop

@next_bucket:
    lm r0, (MESH_CUR_BUCKET)
    inc r0
    sm (MESH_CUR_BUCKET), r0
    iwt r11, #MESH_OT_BUCKETS
    cmp r11
    beq :+
    nop
    iwt r15, #@bucket_loop
    nop
:
    ibt r0, #0
    ramb
    return
endfunction

.ifdef GSU_ISO_USE_SCENE_DESCRIPTOR
; ==============================================================================
; _gsu_mesh_project_pt
; Projects one Q10.6 world point `(r3, r4, r5)` using `ISO_CAM` with the exact
; same fixed-point formula as `gsu_mesh_build_scene`.
;
; In:
;   r3 = vx (Q10.6), r4 = vy (Q10.6), r5 = vz (Q10.6)
; Out:
;   MESH_PROJ_OUT_SX     = screen X (signed 16-bit)
;   MESH_PROJ_OUT_SY     = screen Y (signed 16-bit)
;   MESH_PROJ_OUT_BUCKET = OT bucket index (0..255)
; Clobbers:
;   r0, r6, r7, r8, r9
; ==============================================================================
function _gsu_mesh_project_pt
    register vx = r3, vy = r4, vz = r5, mul_b = r6
    register rz_q4, tmp, rx_q4

    lm mul_b, (ISO_CAM + 2) ; sin_yaw (Q2.14)
    from vx
    to rz_q4
    fmult                   ; rz_q4 = vx * sin
    from vz
    to tmp
    fmult                   ; tmp = vz * sin

    lm mul_b, (ISO_CAM + 4) ; cos_yaw (Q2.14)
    from vx
    to rx_q4
    fmult                   ; rx_q4 = vx * cos
    from vz
    fmult                   ; r0 = vz * cos
    with rz_q4
    add r0                  ; rz_q4 = vx * sin + vz * cos
    with rx_q4
    sub tmp                 ; rx_q4 = vx * cos - vz * sin

    ; sx = ((rx_q4 + 8) >> 4) + center_x
    with rx_q4
    add #8
    iwt mul_b, #$1000
    from rx_q4
    fmult
    lm mul_b, (ISO_CAM + 6)
    add mul_b
    sm (MESH_PROJ_OUT_SX), r0

    ; sy = ((((rz_q4 >> 1) - fmult(vy, $376D)) + 8) >> 4) + center_y
    iwt mul_b, #$376D
    from vy
    fmult
    move tmp, rz_q4
    with tmp
    asr
    with tmp
    sub r0
    with tmp
    add #8
    iwt mul_b, #$1000
    from tmp
    fmult
    lm mul_b, (ISO_CAM + 8)
    add mul_b
    sm (MESH_PROJ_OUT_SY), r0

    ; bucket = clamp((((7/8)*rz_q4 + 0.5*vy) >> 6) + 128, 0, 255)
    move tmp, rz_q4
    with tmp
    asr
    with tmp
    asr
    with tmp
    asr
    from rz_q4
    sub tmp
    move tmp, r0
    iwt mul_b, #$2000
    from vy
    fmult
    with tmp
    add r0
    iwt mul_b, #$0400
    from tmp
    fmult
    iwt mul_b, #128
    add mul_b
    moves r0, r0
    bpl :+
    nop
    ibt r0, #0
:
    iwt mul_b, #256
    cmp mul_b
    blt :+
    nop
    iwt r0, #255
:
    sm (MESH_PROJ_OUT_BUCKET), r0
    return
endfunction

; ==============================================================================
; gsu_mesh_insert_descriptor_items
; Pass-0 descriptor bridge: projects active `desc->entities[]` and non-zero
; `desc->cell_highlights[]` against `sfx_mesh_grid` in `MAP_BUF`, writes
; `(sx, sy, visible)` to `desc->entity_out[]`, pre-compiles the frame's flat
; highlight diamond trapezoids, and links both into the 256-bucket OT so
; 3D mesh geometry naturally occludes both highlights and under-BG1 OAM cutouts.
;
; In:
;   desc_ptr = r1: Pointer to `gsu_scene_descriptor` in Bank $70 GSURAM
; Clobbers:
;   r0..r14
; ==============================================================================
function gsu_mesh_insert_descriptor_items desc_ptr
    register desc_ptr = r1

    sm (MESH_ACTIVE_DESC_PTR), desc_ptr

    ; 1. Always clear desc->entity_out[0..7].visible = 0 and reset highlight counts
    iwt r0, #(gsu_scene_descriptor::entity_out + gsu_entity_screen_pos::visible)
    from desc_ptr
    to r7
    add r0
    ibt r0, #0
    ibt r12, #GSU_SCENE_MAX_ENTITIES
    iwt r13, #@clr_ent_out
@clr_ent_out:
    stw (r7)
    with r7
    add #GSU_ENTITY_POS_BYTES
    loop
    nop

    ibt r0, #0
    sm (MESH_HL_COUNT), r0
    sm (MESH_HL_TRAP_COUNT), r0

    ; Abort cleanly if no companion sfx_mesh_grid was staged
    lm r0, (MESH_HAS_GRID)
    moves r0, r0
    bne :+
    nop
    return
:
    ; 2. Read sfx_mesh_grid_header from Bank-$70 MAP_BUF
    iwt r7, #(MAP_BUF + sfx_mesh_grid_header::cols)
    ldb (r7)
    lob
    sm (MESH_INS_COLS), r0
    inc r7
    ldb (r7)
    lob
    sm (MESH_INS_ROWS), r0
    inc r7
    ldw (r7)
    sm (MESH_INS_OX), r0
    inc r7
    inc r7
    ldw (r7)
    sm (MESH_INS_OZ), r0
    inc r7
    inc r7
    ldw (r7)
    sm (MESH_INS_STEP), r0
    asr
    sm (MESH_INS_HALF_STEP), r0

    ; 3. Project and OT-insert active entities (0..min(entity_count, 8)-1)
    lm r7, (MESH_ACTIVE_DESC_PTR)
    with r7
    add #gsu_scene_descriptor::entity_count
    ldw (r7)
    from r0
    sub #1
    bge :+
    nop
    iwt r15, #@ins_highlights_stage
    nop
:
    iwt r6, #GSU_SCENE_MAX_ENTITIES
    cmp r6
    blt :+
    nop
    ibt r0, #GSU_SCENE_MAX_ENTITIES
:
    sm (MESH_INS_CNT), r0

    ibt r0, #0
    sm (MESH_INS_IDX), r0
    lm r7, (MESH_ACTIVE_DESC_PTR)
    iwt r0, #gsu_scene_descriptor::entities
    add r7
    sm (MESH_INS_PTR), r0

@ins_ent_loop:
    lm r1, (MESH_INS_PTR)       ; r1 = slot_ptr
    ldb (r1)
    lob
    moves r0, r0
    bne :+
    nop
    iwt r15, #@ins_ent_next
    nop
:
    ; Read cell_i (+1) -> r2, cell_j (+2) -> r3
    from r1
    to r7
    add #1
    to r2
    ldb (r7)
    with r2
    lob
    inc r7
    to r3
    ldb (r7)
    with r3
    lob

    ; Bounds check: 0 <= cell_i < cols && 0 <= cell_j < rows
    lm r6, (MESH_INS_COLS)
    from r2
    cmp r6
    blt :+
    nop
    iwt r15, #@ins_ent_next
    nop
:
    lm r7, (MESH_INS_ROWS)
    from r3
    cmp r7
    blt :+
    nop
    iwt r15, #@ins_ent_next
    nop
:
    ; Lookup y_q106 = MAP_BUF[12 + (cell_j * cols + cell_i) * 2]
    from r3
    umult r6                    ; r0 = cell_j * cols
    add r2                      ; r0 = cell_idx
    add r0                      ; * 2
    iwt r7, #(MAP_BUF + .sizeof(sfx_mesh_grid_header))
    add r7
    move r7, r0
    to r4
    ldw (r7)                    ; r4 = y_q106
    iwt r6, #SFX_MGRID_VOID_Y
    from r4
    cmp r6
    bne :+
    nop
    iwt r15, #@ins_ent_next
    nop
:
    ; Compute cell center world X/Z in Q10.6:
    ;   cx = origin_x + (cell_i * step) + half_step
    ;   cz = origin_z + (cell_j * step) + half_step
    ; (lmult places exact low 16 bits of small unsigned product in r4; preserve y_q106 on stack)
    gsu_stack_push r4
    lm r6, (MESH_INS_STEP)
    from r2
    lmult                       ; r4 = cell_i * step
    lm r7, (MESH_INS_OX)
    lm r8, (MESH_INS_HALF_STEP)
    from r4
    add r7
    add r8
    move r9, r0                 ; r9 = cx_q106

    from r3
    lmult                       ; r4 = cell_j * step
    lm r7, (MESH_INS_OZ)
    from r4
    add r7
    add r8
    move r5, r0                 ; r5 = cz_q106
    move r3, r9                 ; r3 = cx_q106
    gsu_stack_pop r4            ; r4 = y_q106

    call _gsu_mesh_project_pt

    ; Read mask_w (+12), mask_h (+13) with defaults 16, 24
    lm r1, (MESH_INS_PTR)
    from r1
    to r7
    add #gsu_entity_mask_slot::mask_w
    ldb (r7)
    lob
    moves r0, r0
    bne :+
    nop
    iwt r0, #16
:
    move r8, r0                 ; r8 = mask_w
    inc r7
    ldb (r7)
    lob
    moves r0, r0
    bne :+
    nop
    iwt r0, #24
:
    move r9, r0                 ; r9 = mask_h

    ; sx = floor_cx - (mask_w >> 1) + sub_x_offset (+6)
    lm r5, (MESH_PROJ_OUT_SX)
    from r8
    lsr
    with r5
    sub r0
    from r1
    to r7
    add #gsu_entity_mask_slot::sub_x_offset
    ldw (r7)
    with r5
    add r0                      ; r5 = sx

    ; sy = floor_cy - mask_h + sub_y_offset (+8) + anchor_y_offset (+10)
    lm r6, (MESH_PROJ_OUT_SY)
    with r6
    sub r9
    inc r7
    inc r7
    ldw (r7)
    with r6
    add r0
    inc r7
    inc r7
    ldw (r7)
    with r6
    add r0                      ; r6 = sy

    ; Viewport visibility test: (sx + mask_w > 0) && (sx < VIEWPORT_W) && (sy + mask_h > 0) && (sy < SCREEN_H)
    ibt r11, #0
    from r5
    add r8
    sub #1
    blt @ins_ent_write_out
    nop
    iwt r0, #GSU_ISO_VIEWPORT_W
    from r5
    cmp r0
    bge @ins_ent_write_out
    nop
    from r6
    add r9
    sub #1
    blt @ins_ent_write_out
    nop
    iwt r0, #GSU_ISO_SCREEN_H
    from r6
    cmp r0
    bge @ins_ent_write_out
    nop
    ibt r11, #1

@ins_ent_write_out:
    ; Write desc->entity_out[slot] = (sx, sy, visible)
    lm r3, (MESH_INS_IDX)
    move r2, r3
    with r2
    add r2
    with r2
    add r2
    with r2
    add r2                      ; r2 = slot * 8
    lm r7, (MESH_ACTIVE_DESC_PTR)
    iwt r0, #gsu_scene_descriptor::entity_out
    add r7
    add r2
    move r7, r0
    from r5
    stw (r7)                    ; +0: sx
    inc r7
    inc r7
    from r6
    stw (r7)                    ; +2: sy
    inc r7
    inc r7
    from r11
    stw (r7)                    ; +4: visible

    ; Skip OT link if off-screen
    moves r11, r11
    beq @ins_ent_next
    nop

    ; Save (sx, sy, slot_ptr) in MESH_ENT_*[slot * 2]
    from r3
    add r3
    move r2, r0                 ; r2 = slot * 2
    iwt r7, #MESH_ENT_SX
    with r7
    add r2
    from r5
    stw (r7)
    iwt r7, #MESH_ENT_SY
    with r7
    add r2
    from r6
    stw (r7)
    iwt r7, #MESH_ENT_SLOT_PTR
    with r7
    add r2
    from r1
    stw (r7)

    ; Link node (MESH_OT_ENT_BASE + slot) into OT bucket min(255, bucket + 6)
    ; (+6 buckets = 24 depth px: clears multi-tile bridge/viaduct slabs and adjacent
    ;  same-level floor highlights while nearer walls/towers still cleanly occlude)
    lm r0, (MESH_PROJ_OUT_BUCKET)
    add #6
    iwt r6, #256
    cmp r6
    blt :+
    nop
    iwt r0, #255
:
    add r0                      ; bucket * 2
    iwt r7, #MESH_OT_HEADS
    add r7
    move r7, r0                 ; r7 = &MESH_OT_HEADS[bucket]
    to r2
    ldw (r7)                    ; r2 = old_head
    iwt r0, #MESH_OT_ENT_BASE
    add r3                      ; r0 = node_id
    move r4, r0
    from r4
    stw (r7)                    ; MESH_OT_HEADS[bucket] = node_id
    from r4
    add r4
    iwt r7, #MESH_OT_NEXT
    add r7
    move r7, r0
    from r2
    stw (r7)                    ; MESH_OT_NEXT[node_id] = old_head

@ins_ent_next:
    lm r0, (MESH_INS_PTR)
    iwt r6, #GSU_ENTITY_SLOT_BYTES
    add r6
    sm (MESH_INS_PTR), r0
    lm r0, (MESH_INS_IDX)
    inc r0
    sm (MESH_INS_IDX), r0
    lm r6, (MESH_INS_CNT)
    cmp r6
    bge :+
    nop
    iwt r15, #@ins_ent_loop
    nop
:

; ------------------------------------------------------------------------------
; 4. Pre-compile flat cell highlight diamond & OT-insert highlighted cells
; ------------------------------------------------------------------------------
@ins_highlights_stage:
    lm r7, (MESH_ACTIVE_DESC_PTR)
    with r7
    add #gsu_scene_descriptor::highlights_enabled
    ldw (r7)
    moves r0, r0
    bne :+
    nop
    return
:
    ; Compute half-cell basis pixel vectors (Hx_x, Hx_y) and (Hz_x, Hz_y) from half_step
    ;   Hx_x = ((fmult(half_step, cos_yaw) + 8) >> 4)
    ;   Hx_y = (((fmult(half_step, sin_yaw) >> 1) + 8) >> 4)
    ;   Hz_x = (((-fmult(half_step, sin_yaw)) + 8) >> 4)
    ;   Hz_y = (((fmult(half_step, cos_yaw) >> 1) + 8) >> 4)
    lm r3, (MESH_INS_HALF_STEP)
    lm r6, (ISO_CAM + 4)        ; cos_yaw
    from r3
    to r7
    fmult                       ; r7 = half_step * cos_yaw (Q12.4)
    lm r6, (ISO_CAM + 2)        ; sin_yaw
    from r3
    to r8
    fmult                       ; r8 = half_step * sin_yaw (Q12.4)

    ; Hx_x in r1
    iwt r6, #8
    from r7
    add r6
    iwt r6, #$1000
    to r1
    fmult
    ; Hx_y in r2
    move r0, r8
    asr
    iwt r6, #8
    add r6
    iwt r6, #$1000
    to r2
    fmult
    ; Hz_x in r3
    ibt r0, #0
    sub r8
    iwt r6, #8
    add r6
    iwt r6, #$1000
    to r3
    fmult
    ; Hz_y in r4
    move r0, r7
    asr
    iwt r6, #8
    add r6
    iwt r6, #$1000
    to r4
    fmult

    ; MESH_HL_HALF_SPAN_X = |Hx_x| + |Hz_x| + 2
    move r5, r1
    moves r5, r5
    bpl :+
    nop
    ibt r0, #0
    sub r5
    move r5, r0
:
    move r6, r3
    moves r6, r6
    bpl :+
    nop
    ibt r0, #0
    sub r6
    move r6, r0
:
    from r5
    add r6
    add #2
    sm (MESH_HL_HALF_SPAN_X), r0

    ; Build 4 CW diamond corners relative to (0,0) in MESH_FACE_X0..Y3:
    ;   V0 = (-Hx - Hz), V1 = (+Hx - Hz), V2 = (+Hx + Hz), V3 = (-Hx + Hz)
    ibt r0, #0
    sub r1
    sub r3
    sm (MESH_FACE_X0), r0
    ibt r0, #0
    sub r2
    sub r4
    sm (MESH_FACE_Y0), r0

    from r1
    sub r3
    sm (MESH_FACE_X1), r0
    from r2
    sub r4
    sm (MESH_FACE_Y1), r0

    from r1
    add r3
    sm (MESH_FACE_X2), r0
    from r2
    add r4
    sm (MESH_FACE_Y2), r0

    from r3
    sub r1
    sm (MESH_FACE_X3), r0
    from r4
    sub r2
    sm (MESH_FACE_Y3), r0

    ; Compile Tri0 = (V0, V1, V2) -> MESH_HL_TRAPS[0..]
    iwt r7, #MESH_TRI_PTS
    lm r0, (MESH_FACE_X0)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_Y0)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_X1)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_Y1)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_X2)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_Y2)
    stw (r7)

    iwt r1, #MESH_TRI_PTS
    iwt r2, #MESH_HL_TRAPS
    call compile_flat_tri
    sm (MESH_HL_TRAP_COUNT), r0

    ; Compile Tri1 = (V0, V2, V3) -> MESH_HL_TRAPS[count..]
    iwt r7, #(MESH_TRI_PTS + 4)
    lm r0, (MESH_FACE_X2)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_Y2)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_X3)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_FACE_Y3)
    stw (r7)

    ; dst = MESH_HL_TRAPS + count * 12
    lm r3, (MESH_HL_TRAP_COUNT)
    from r3
    add r3                      ; 2*c
    add r0                      ; 4*c
    move r6, r0
    add r0                      ; 8*c
    add r6                      ; 12*c
    iwt r2, #MESH_HL_TRAPS
    with r2
    add r0
    iwt r1, #MESH_TRI_PTS
    call compile_flat_tri
    lm r3, (MESH_HL_TRAP_COUNT)
    add r3
    sm (MESH_HL_TRAP_COUNT), r0

    ; Scan cell_highlights[0 .. rows*cols - 1]
    lm r7, (MESH_ACTIVE_DESC_PTR)
    iwt r0, #gsu_scene_descriptor::cell_highlights
    add r7
    sm (MESH_INS_HL_PTR), r0
    iwt r0, #(MAP_BUF + .sizeof(sfx_mesh_grid_header))
    sm (MESH_INS_GRID_PTR), r0
    ibt r0, #0
    sm (MESH_INS_ROW), r0

@hl_row_loop:
    ibt r0, #0
    sm (MESH_INS_COL), r0
@hl_col_loop:
    ; Read cell_highlights byte
    lm r7, (MESH_INS_HL_PTR)
    ldb (r7)
    lob
    inc r7
    sm (MESH_INS_HL_PTR), r7
    move r9, r0                 ; r9 = hl_code (0..3)

    ; Read y_q106 word (always advance grid pointer)
    lm r7, (MESH_INS_GRID_PTR)
    to r4
    ldw (r7)
    inc r7
    inc r7
    sm (MESH_INS_GRID_PTR), r7

    moves r9, r9
    bne :+
    nop
    iwt r15, #@hl_col_next
    nop
:
    iwt r6, #SFX_MGRID_VOID_Y
    from r4
    cmp r6
    bne :+
    nop
    iwt r15, #@hl_col_next
    nop
:
    ; Check pool capacity (< MESH_MAX_HIGHLIGHTS)
    lm r0, (MESH_HL_COUNT)
    iwt r6, #MESH_MAX_HIGHLIGHTS
    cmp r6
    blt :+
    nop
    return
:
    ; Map hl_code (1..3) -> BG1 palette slot
    from r9
    sub #GSU_HIGHLIGHT_MOVE
    beq @hl_use_move
    nop
    from r9
    sub #GSU_HIGHLIGHT_ATTACK
    beq @hl_use_atk
    nop
    from r9
    sub #GSU_HIGHLIGHT_CURSOR
    beq @hl_use_cur
    nop
    iwt r15, #@hl_col_next
    nop
@hl_use_move:
    lm r0, (MESH_HL_COLOR_MOVE)
    bra @hl_color_set
    nop
@hl_use_atk:
    lm r0, (MESH_HL_COLOR_ATTACK)
    bra @hl_color_set
    nop
@hl_use_cur:
    lm r0, (MESH_HL_COLOR_CURSOR)
@hl_color_set:
    sm (MESH_CUR_COLOR), r0

    ; Project cell center (cx_q106, y_q106, cz_q106)
    gsu_stack_push r4
    lm r2, (MESH_INS_COL)
    lm r3, (MESH_INS_ROW)
    lm r6, (MESH_INS_STEP)
    from r2
    lmult                       ; r4 = col * step
    lm r7, (MESH_INS_OX)
    lm r8, (MESH_INS_HALF_STEP)
    from r4
    add r7
    add r8
    move r9, r0                 ; cx_q106

    from r3
    lmult                       ; r4 = row * step
    lm r7, (MESH_INS_OZ)
    from r4
    add r7
    add r8
    move r5, r0                 ; cz_q106
    move r3, r9                 ; cx_q106
    gsu_stack_pop r4            ; y_q106

    call _gsu_mesh_project_pt

    ; Store (cx, cy, color) in MESH_HL_POOL[k * 6]
    lm r3, (MESH_HL_COUNT)
    from r3
    add r3                      ; 2*k
    move r6, r0
    add r0                      ; 4*k
    add r6                      ; 6*k
    iwt r7, #MESH_HL_POOL
    add r7
    move r7, r0
    lm r0, (MESH_PROJ_OUT_SX)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_PROJ_OUT_SY)
    stw (r7)
    inc r7
    inc r7
    lm r0, (MESH_CUR_COLOR)
    stw (r7)

    ; Link node (MESH_OT_HL_BASE + k) into OT bucket min(255, bucket + 1)
    lm r0, (MESH_PROJ_OUT_BUCKET)
    inc r0
    iwt r6, #256
    cmp r6
    blt :+
    nop
    iwt r0, #255
:
    add r0
    iwt r7, #MESH_OT_HEADS
    add r7
    move r7, r0
    to r2
    ldw (r7)                    ; old_head
    iwt r0, #MESH_OT_HL_BASE
    add r3                      ; node_id
    move r4, r0
    from r4
    stw (r7)
    from r4
    add r4
    iwt r7, #MESH_OT_NEXT
    add r7
    move r7, r0
    from r2
    stw (r7)

    ; Increment MESH_HL_COUNT
    from r3
    add #1
    sm (MESH_HL_COUNT), r0

@hl_col_next:
    lm r0, (MESH_INS_COL)
    inc r0
    sm (MESH_INS_COL), r0
    lm r6, (MESH_INS_COLS)
    cmp r6
    bge :+
    nop
    iwt r15, #@hl_col_loop
    nop
:
    lm r0, (MESH_INS_ROW)
    inc r0
    sm (MESH_INS_ROW), r0
    lm r6, (MESH_INS_ROWS)
    cmp r6
    bge :+
    nop
    iwt r15, #@hl_row_loop
    nop
:
    return
endfunction

; ==============================================================================
; gsu_mesh_render_from_descriptor
; Pure-renderer entry point (ADR 0006) for Bank-$71 Hybrid 3D Meshes, driven
; strictly by a 65816-written `gsu_scene_descriptor` in Bank $70 GSURAM.
;
; Behavior:
;   - Pass 0 (`frame_half == 0`):
;       1. Syncs `ISO_CAM` yaw, `center_x`, and `center_y` from `desc_ptr`.
;       2. Projects mesh vertices & builds 256-bucket OT (`gsu_mesh_build_scene`).
;       3. Projects entities -> `desc->entity_out[]` and interleaves Sprite Mask
;          cutouts + tactical cell highlights into the OT.
;       4. Rasterizes Pass 0 (`X in [0..127]`).
;   - Pass 1 (`frame_half != 0`):
;       Rasterizes Pass 1 (`X in [128..GSU_ISO_VIEWPORT_W-1]`) reusing Pass 0 OT.
;
; In:
;   desc_ptr   = r1: Pointer to `gsu_scene_descriptor` in Bank $70 GSURAM
;   frame_half = r2: Active frame half (0 = Pass 0, 1 = Pass 1)
; Postconditions:
;   - `RAMBR == 0` ($70) and `ROMBR == $04` on return
; Clobbers:
;   r0..r14
; ==============================================================================
function gsu_mesh_render_from_descriptor desc_ptr, frame_half
    register desc_ptr = r1, frame_half = r2

    ibt r0, #$04
    romb
    ibt r0, #0
    ramb

    sm (MESH_ACTIVE_DESC_PTR), desc_ptr

    moves frame_half, frame_half
    bne @mesh_desc_pass1
    nop

    ; Pass 0: sync ISO_CAM from descriptor (+0=yaw, +2=center_x, +4=center_y)
    move r7, desc_ptr
    to r3
    ldw (r7)                    ; cam_yaw
    inc r7
    inc r7
    to r4
    ldw (r7)                    ; cam_center_x
    inc r7
    inc r7
    to r5
    ldw (r7)                    ; cam_center_y

    iwt r7, #(ISO_CAM + 6)
    from r4
    stw (r7)
    inc r7
    inc r7
    from r5
    stw (r7)

    iwt r1, #ISO_CAM
    move r2, r3
    call iso_camera_set_yaw r1, r2

    call gsu_mesh_build_scene

    lm r1, (MESH_ACTIVE_DESC_PTR)
    call gsu_mesh_insert_descriptor_items r1

    iwt r1, #0
    call gsu_mesh_render_pass
    return

@mesh_desc_pass1:
    iwt r1, #1
    call gsu_mesh_render_pass
    return
endfunction
.endif ; GSU_ISO_USE_SCENE_DESCRIPTOR

.endif ; __GSU_MESH_ENGINE_DEFINED__
