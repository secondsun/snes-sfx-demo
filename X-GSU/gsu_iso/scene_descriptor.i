; ==============================================================================
; scene_descriptor.i - Shared 65816 / SuperFX Scene Render Descriptor Contract
;
; Implements ADR 0006 (`0006-65816-gameplay-owner-and-gsu-pure-renderer.md`):
;   The 65816 host CPU owns all gameplay state, joypad input, camera controls,
;   entity positions, and tactical cell highlights. Each frame, the 65816 writes
;   a word-aligned `gsu_scene_descriptor` in Bank $70 GSURAM (`GSU_SCENE_DESC`),
;   and the SuperFX GSU consumes it as a pure 3D scene renderer.
;
; Safe to `.include` from BOTH 65816 (`.s`) and SuperFX (`.sgs` / `.i`) units:
;   Defines only constants and `.struct` layouts (no `.segment` switches).
;
; Exact Byte Offsets of `gsu_scene_descriptor` (464 bytes total, word-aligned):
;   +0   (2B) cam_yaw            : Camera yaw angle index (1..120, 3 deg/step)
;   +2   (2B) cam_center_x       : Screen X focal center (96 for 192px, 128 for 256px)
;   +4   (2B) cam_center_y       : Screen Y focal center (default 80)
;   +6   (2B) cam_dirty          : Non-zero when 65816 updated camera this frame
;   +8   (2B) viewport_width     : Active BG1 viewport width (192 or 256)
;   +10  (2B) entity_count       : Active entity slot count (0..8)
;   +12  (2B) highlights_enabled : 0 = skip cell highlight pass, non-zero = enable
;   +14  (2B) reserved           : Header alignment padding ($0000)
;   +16  (128B) entities[8]      : 8 x 16-byte `gsu_entity_mask_slot` (65816 -> GSU)
;   +144 (64B)  entity_out[8]    : 8 x 8-byte  `gsu_entity_screen_pos` (GSU Pass 0 -> 65816)
;   +208 (256B) cell_highlights  : 256-byte grid (`j * cols + i`), values 0..3 (65816 -> GSU)
;   Total: 464 bytes ($01D0)
; ==============================================================================

.ifndef __GSU_ISO_SCENE_DESCRIPTOR__
__GSU_ISO_SCENE_DESCRIPTOR__ = 1

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
GSU_SCENE_MAX_ENTITIES      = 8         ; 1 Player + up to 4 NPCs + up to 3 Interactables
GSU_ENTITY_NONE             = $FF       ; Empty cell sentinel for cell_entity_lut

GSU_VIEWPORT_W_192          = 192       ; Narrowed BG1 viewport (64px right Side Menu)
GSU_VIEWPORT_W_256          = 256       ; Full-screen BG1 viewport (IsoEngine / RamMapDemo)

; Entity mask slot flags (gsu_entity_mask_slot::flags)
GSU_ENTITY_FLAG_HFLIP       = (1 << 0)  ; Horizontally mirror 1-bit Sprite Mask

; Per-cell tactical highlight codes (gsu_scene_descriptor::cell_highlights[idx])
GSU_HIGHLIGHT_NONE          = 0         ; No highlight
GSU_HIGHLIGHT_MOVE          = 1         ; Reachable movement cell (blue/cyan)
GSU_HIGHLIGHT_ATTACK        = 2         ; Valid attack target cell (red/orange)
GSU_HIGHLIGHT_CURSOR        = 3         ; Active selection cursor (bright yellow/white)

; ------------------------------------------------------------------------------
; Per-Entity Sprite Mask Input Slot (16 bytes, power-of-2 stride, word-aligned)
; Written by 65816; read-only by GSU (`sprite_mask.i` at `@step_4_unit_hook`).
;
; Exact Byte Offsets:
;   +0  (1B) active          : 0 = inactive, non-zero = active
;   +1  (1B) cell_i          : Map Grid column index (0..15)
;   +2  (1B) cell_j          : Map Grid row index (0..15)
;   +3  (1B) mask_bank       : ROM bank containing 1-bit Sprite Mask data
;   +4  (2B) mask_addr       : 16-bit ROM offset within `mask_bank`
;   +6  (2B) sub_x_offset    : Signed pixel X interpolation offset
;   +8  (2B) sub_y_offset    : Signed pixel Y interpolation offset
;   +10 (2B) anchor_y_offset : Signed vertical anchor offset from cell floor center
;   +12 (1B) mask_w          : Mask width in pixels (default 16)
;   +13 (1B) mask_h          : Mask height in pixels (default 24)
;   +14 (1B) flags           : Bit 0 = HFLIP, bits 7:1 reserved
;   +15 (1B) reserved        : Alignment padding ($00)
; ------------------------------------------------------------------------------
.struct gsu_entity_mask_slot
    active          .byte   ; +0:  0 = inactive, non-zero = active
    cell_i          .byte   ; +1:  Map Grid column (0..15)
    cell_j          .byte   ; +2:  Map Grid row (0..15)
    mask_bank       .byte   ; +3:  ROM bank of 1-bit Sprite Mask sheet
    mask_addr       .word   ; +4:  16-bit ROM offset in mask_bank
    sub_x_offset    .word   ; +6:  Signed 16-bit pixel X interpolation offset
    sub_y_offset    .word   ; +8:  Signed 16-bit pixel Y interpolation offset
    anchor_y_offset .word   ; +10: Signed 16-bit vertical anchor offset
    mask_w          .byte   ; +12: Mask width in pixels (default 16)
    mask_h          .byte   ; +13: Mask height in pixels (default 24)
    flags           .byte   ; +14: GSU_ENTITY_FLAG_* bitmask
    reserved        .byte   ; +15: Pad to 16 bytes
.endstruct

GSU_ENTITY_SLOT_BYTES       = 16
.assert .sizeof(gsu_entity_mask_slot) = GSU_ENTITY_SLOT_BYTES, error, "gsu_entity_mask_slot must be 16 bytes"

; ------------------------------------------------------------------------------
; Per-Entity Projected Screen Position Output (8 bytes, power-of-2 stride)
; Written by GSU during Pass 0; latched into hardware OAM by 65816 on the exact
; VBlank that flips `BG12NBA` (Pass 1 completion) per ADR 0005.
;
; Exact Byte Offsets:
;   +0  (2B) sx              : Signed 16-bit projected top-left screen X
;   +2  (2B) sy              : Signed 16-bit projected top-left screen Y
;   +4  (2B) visible         : 0 = inactive/culled, 1 = visible in viewport
;   +6  (2B) reserved        : Alignment padding to 8 bytes ($0000)
; ------------------------------------------------------------------------------
.struct gsu_entity_screen_pos
    sx              .word   ; +0: Projected top-left screen X (signed 16-bit)
    sy              .word   ; +2: Projected top-left screen Y (signed 16-bit)
    visible         .word   ; +4: 0 = culled/inactive, 1 = visible
    reserved        .word   ; +6: Pad to 8 bytes
.endstruct

GSU_ENTITY_POS_BYTES        = 8
.assert .sizeof(gsu_entity_screen_pos) = GSU_ENTITY_POS_BYTES, error, "gsu_entity_screen_pos must be 8 bytes"

; ------------------------------------------------------------------------------
; Master Scene Render Descriptor (464 bytes, word-aligned in Bank $70 GSURAM)
; ------------------------------------------------------------------------------
.struct gsu_scene_descriptor
    ; --- Header (16 bytes, +0..+15) ---
    cam_yaw             .word   ; +0:   Camera yaw index (1..120)
    cam_center_x        .word   ; +2:   Camera focus screen X (96 or 128)
    cam_center_y        .word   ; +4:   Camera focus screen Y (default 80)
    cam_dirty           .word   ; +6:   Non-zero when 65816 updated camera
    viewport_width      .word   ; +8:   Active viewport width (192 or 256)
    entity_count        .word   ; +10:  Active entity slot count (0..8)
    highlights_enabled  .word   ; +12:  0 = disabled, non-zero = enabled
    reserved            .word   ; +14:  Header alignment pad ($0000)

    ; --- Entity Mask Input Table (128 bytes, +16..+143) ---
    entities            .res ::GSU_SCENE_MAX_ENTITIES * ::GSU_ENTITY_SLOT_BYTES

    ; --- Projected Entity Output Table (64 bytes, +144..+207) ---
    entity_out          .res ::GSU_SCENE_MAX_ENTITIES * ::GSU_ENTITY_POS_BYTES

    ; --- Per-Cell Tactical Highlight Grid (256 bytes, +208..+463) ---
    cell_highlights     .res 256
.endstruct

GSU_SCENE_DESC_BYTES        = .sizeof(gsu_scene_descriptor)
.assert gsu_scene_descriptor::entities        = 16,  error, "gsu_scene_descriptor::entities offset mismatch"
.assert gsu_scene_descriptor::entity_out      = 144, error, "gsu_scene_descriptor::entity_out offset mismatch"
.assert gsu_scene_descriptor::cell_highlights = 208, error, "gsu_scene_descriptor::cell_highlights offset mismatch"
.assert GSU_SCENE_DESC_BYTES                  = 464, error, "gsu_scene_descriptor must be 464 bytes"

.endif ; __GSU_ISO_SCENE_DESCRIPTOR__
