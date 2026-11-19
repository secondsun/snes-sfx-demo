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
    ibt r0, #0
    ramb
    lm r11, (MESH_HDR_CACHE + sfx_mesh_header::verts_offset)
    iwt r1, #MESH_PROJ_VERTS
    iwt r2, #MESH_VERT_DEPTH
    lm r12, (MESH_HDR_CACHE + sfx_mesh_header::vertex_count)
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
    iwt r6, #8
    with r9
    add r6
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
    iwt r6, #8
    with r8
    add r6
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

    ; --- 3. Classify, frustum/backface cull, and bucket faces into MESH_OT_HEADS ---
    ibt r0, #0
    sm (MESH_CUR_FACE_IDX), r0
    lm r0, (MESH_HDR_CACHE + sfx_mesh_header::faces_offset)
    sm (MESH_CUR_FACE_PTR), r0
    lm r0, (MESH_HDR_CACHE + sfx_mesh_header::face_count)
    sm (MESH_BLD_FACE_REM), r0

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

    ; Advance MESH_CUR_FACE_PTR by 20 for next iteration
    lm r0, (MESH_CUR_FACE_PTR)
    iwt r1, #20
    add r1
    sm (MESH_CUR_FACE_PTR), r0

    sm (MESH_FACE_FLAGS), r2

    ; Load projected vertex coordinates (x0..x3, y0..y3) into scratch GSURAM & compute bbox
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
    move r12, r0            ; max_y

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
    from r12
    cmp r0
    bge :+
    nop
    move r12, r0
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
    from r12
    cmp r0
    bge :+
    nop
    move r12, r0
:

@bbox_ready:
    ; Frustum cull: max_x < 0 || min_x >= 256 || max_y <= 0 || min_y >= 160
    moves r8, r8
    bpl :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    iwt r11, #256
    from r7
    cmp r11
    blt :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    from r12
    sub #1
    bge :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    iwt r11, #160
    from r9
    cmp r11
    blt :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    ; Span guard: (max_x - min_x) < 120 && (max_y - min_y) < 120
    iwt r11, #120
    from r8
    sub r7
    cmp r11
    blt :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    from r12
    sub r9
    cmp r11
    blt :+
    nop
    iwt r15, #@bld_next_face
    nop
:

    ; Save vertex offsets into MESH_FACE_BASE_X/Y/COLOR temp before lmult clobbers r3..r6
    from r3
    lsr
    move r3, r0             ; d0_off = v0_off >> 1
    from r4
    lsr
    move r4, r0             ; d1_off = v1_off >> 1
    from r5
    lsr
    move r5, r0             ; d2_off = v2_off >> 1
    from r6
    lsr
    sm (MESH_U0_Q88), r0    ; temp hold d3_off
    iwt r1, #MESH_VERT_DEPTH
    from r1
    add r3
    move r11, r0
    ldw (r11)
    move r3, r0
    from r1
    add r4
    move r11, r0
    ldw (r11)
    add r3
    move r3, r0
    from r1
    add r5
    move r11, r0
    ldw (r11)
    add r3
    sm (MESH_V0_Q88), r0    ; sum3 = d0 + d1 + d2

    ; 32-bit CW backface cull on tri0 = (V0, V1, V2):
    ;   (x1 - x0)*(y2 - y0) - (y1 - y0)*(x2 - x0) > 0
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
    to r7
    lmult                   ; r7:r4 = dx1 * dy2
    move r8, r4
    move r6, r3
    from r2
    to r1
    lmult                   ; r1:r4 = dy1 * dx2
    move r2, r4

    from r7
    cmp r1
    bge :+
    nop
    bra @try_quad_tri1
    nop
:
    from r1
    cmp r7
    bge :+
    nop
    bra @face_visible
    nop
:
    from r8
    cmp r2
    bne :+
    nop
    bra @try_quad_tri1
    nop
:
    bcs @face_visible
    nop

@try_quad_tri1:
    lm r0, (MESH_FACE_FLAGS)
    iwt r11, #MESH_FACE_FLAG_QUAD
    and r11
    bne :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    ; Check tri1 = (V0, V2, V3)
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
    to r7
    lmult
    move r8, r4
    move r6, r3
    from r2
    to r1
    lmult
    move r2, r4

    from r7
    cmp r1
    bge :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    from r1
    cmp r7
    bge :+
    nop
    bra @face_visible
    nop
:
    from r8
    cmp r2
    bne :+
    nop
    iwt r15, #@bld_next_face
    nop
:
    bcs @face_visible
    nop
    iwt r15, #@bld_next_face
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
    ; Read MESH_OT_NEXT[face_idx * 2] before anything clobbers r3
    from r3
    add r3
    iwt r1, #MESH_OT_NEXT
    add r1
    move r1, r0
    ldw (r1)
    sm (MESH_CUR_NEXT_FACE), r0

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
    iwt r12, #256
    from r7
    cmp r12
    blt :+
    nop
    iwt r15, #@next_face
    nop
:
    ; base_x = clamp(min_x, 128, 248)
    move r0, r7
    cmp r11
    bge :+
    nop
    move r0, r11
:
    iwt r11, #248
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
    beq @next_face
    nop

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
    beq @next_face
    nop
    lm r1, (MESH_TRAP_PTR)
    iwt r0, #.sizeof(cached_trap)
    with r1
    add r0
    bra @r_tex_trap_loop
    nop

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

.endif ; __GSU_MESH_ENGINE_DEFINED__
