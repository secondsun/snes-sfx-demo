; ==============================================================================
; bank71_layout.i - Bank-$71 Asset Staging Layout & Shared 65816/GSU Contracts
;
; Defines the fixed Game Pak RAM Bank $71 ($71:0000 - $71:FFFF) memory map,
; relocatable Texture Table (.tab) header/entry structures, load mode constants,
; and 65816 AssetSource / LevelDef descriptors (shared by Cartridge ROM and MSU-1).
;
; Requires ROM_EXPRAMSIZE = $07 (128 KB Game Pak RAM across $70 - $71) in libSFX.cfg.
; ==============================================================================

.ifndef __GSU_ISO_BANK71_LAYOUT__
__GSU_ISO_BANK71_LAYOUT__ = 1

; ------------------------------------------------------------------------------
; Bank $71 Memory Map ($71:0000 - $71:FFFF, 64 KB)
; ------------------------------------------------------------------------------
BANK71_BANK             = $71
BANK71_BASE_LONG        = $710000

BANK71_ATLAS_ADDR       = $0000     ; $71:0000 - $71:7FFF (32,768 B max .bin)
BANK71_ATLAS_MAX        = $8000

BANK71_TAB_ADDR         = $8000     ; $71:8000 - $71:8807 (2,056 B max .tab)
BANK71_TAB_MAX          = 2056

BANK71_MAP_ADDR         = $8808     ; $71:8808 - $71:900F (2,056 B max .map: 8B + 256*8B)
BANK71_MAP_MAX          = 2056

BANK71_PAL_ADDR         = $9010     ; $71:9010 - $71:902F (32 B BGR555 .pal mirror)
BANK71_PAL_LONG         = (BANK71_BASE_LONG | BANK71_PAL_ADDR)
BANK71_PAL_BYTES        = 32

BANK71_FREE_ADDR        = $9030     ; $71:9030 - $71:FFFF (28,624 B reserved free)

; ------------------------------------------------------------------------------
; Relocatable Texture Table (.tab) Binary Contract
; ------------------------------------------------------------------------------
SFX_TAB_MAGIC           = $5453     ; Little-endian 'S','T' ($53, $54)
SFX_TAB_HEADER_BYTES    = 8
SFX_TAB_MAX_ENTRIES     = 256

.struct sfx_tab_header
    magic           .word   ; +0: SFX_TAB_MAGIC ($5453 = "ST")
    entry_count     .word   ; +2: Number of 8-byte descriptors (1..256)
    atlas_width     .word   ; +4: Packed atlas row pitch in bytes (e.g. 64, 128, 256)
    stride_shift    .word   ; +6: log2(atlas_width) (e.g. 6, 7, 8)
.endstruct

.struct sfx_tab_entry
    atlas_offset    .word   ; +0: 0-based byte offset in $71:0000..$71:7FFF
    u_mask          .word   ; +2: width - 1
    v_mask_shift    .word   ; +4: (height - 1) << stride_shift
    v_offset_mask   .word   ; +6: ((height - 1) << stride_shift) | ((1 << stride_shift) - 1)
.endstruct

; ------------------------------------------------------------------------------
; Host-to-GSU Load Modes & Import Status Codes
; ------------------------------------------------------------------------------
SFX_LOAD_MODE_LEVEL     = 1         ; Full level load: reset translation AND yaw=1
SFX_LOAD_MODE_MAP       = 2         ; Map-only swap: reset translation, preserve yaw

SFX_IMPORT_OK               = 0
SFX_IMPORT_ERR_BAD_MAGIC    = 1
SFX_IMPORT_ERR_BAD_COUNT    = 2
SFX_IMPORT_ERR_BAD_DIM      = 3

; ------------------------------------------------------------------------------
; 65816 AssetSource & LevelDef Descriptors (8B per entry, 34B per level)
; ------------------------------------------------------------------------------
.struct sfx_asset_entry
    offset_lo       .word   ; +0: ROM 16-bit addr OR MSU-1 byte offset [15:0]
    offset_hi       .word   ; +2: ROM bank (low byte) OR MSU-1 byte offset [31:16]
    byte_size       .word   ; +4: Transfer byte count (1..$8000)
    flags           .word   ; +6: Asset flags ($0000 = raw uncompressed)
.endstruct

.struct sfx_level_def
    atlas_id        .word                   ; +0:  Resident atlas cache tag ($FFFF = uncached)
    atlas_entry     .tag sfx_asset_entry    ; +2:  .bin -> $71:0000
    tab_entry       .tag sfx_asset_entry    ; +10: .tab -> $71:8000
    pal_entry       .tag sfx_asset_entry    ; +18: .pal -> $71:9010 + CGRAM 0
    map_entry       .tag sfx_asset_entry    ; +26: .map -> $71:8808
.endstruct

; Emits an 8-byte sfx_asset_entry backed by a Cartridge ROM symbol + size (+ optional flags)
.macro def_rom_asset sym, size, asset_flags
    .ifblank asset_flags
        .word .loword(sym), ^sym, (size), $0000
    .else
        .word .loword(sym), ^sym, (size), (asset_flags)
    .endif
.endmac

; Emits an 8-byte sfx_asset_entry backed by a 32-bit MSU-1 pack byte offset + size (+ optional flags)
.macro def_msu_asset offset32, size, asset_flags
    .ifblank asset_flags
        .word ((offset32) & $FFFF), (((offset32) >> 16) & $FFFF), (size), $0000
    .else
        .word ((offset32) & $FFFF), (((offset32) >> 16) & $FFFF), (size), (asset_flags)
    .endif
.endmac

.endif ; ::__GSU_ISO_BANK71_LAYOUT__
