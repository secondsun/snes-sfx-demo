; ==============================================================================
; cpu_asset_loader.i - 65816 Host Asset Loader & GSU Bus Arbitration for Bank $71
;
; Coordinates safe S-CPU <-> GSU bus handoff (`sfx_gsu_load_lock`, forced blank,
; `GSU_SFR` GO polling, `GSU_SCMR` RAN/RON release & restore), resident-atlas
; deduplication (`sfx_resident_atlas_id`), CGRAM palette upload from `$71:9010`,
; and `GSU_INIT_FLAG` / `GSU_LOAD_MODE` signaling in `$70`.
;
; Include exactly one AssetSource implementation (`asset_source_rom.i` or
; `asset_source_msu1.i`) alongside this file.
; ==============================================================================

.ifndef __GSU_ISO_CPU_ASSET_LOADER__
__GSU_ISO_CPU_ASSET_LOADER__ = 1

.include "bank71_layout.i"

.import GSU_INIT_FLAG
.import GSU_LOAD_MODE
.import GSU_FRAME_HALF

; Default GSU_SCMR value for 4bpp, 160-line mode with GSU owning RAM + ROM
SFX_DEFAULT_GSU_SCMR    = %00011101

; ------------------------------------------------------------------------------
; Zero-Page 24-bit Descriptor Pointer & LORAM Loader State
; ------------------------------------------------------------------------------
.segment "ZEROPAGE": zeropage
sfx_def_ptr:            .res 3          ; 24-bit pointer to sfx_level_def or sfx_asset_entry

.segment "LORAM"
sfx_src_lo:             .res 2          ; Parameter to sfx_asset_copy_to_bank71
sfx_src_hi:             .res 2          ; Parameter to sfx_asset_copy_to_bank71
sfx_copy_size:          .res 2          ; Parameter to sfx_asset_copy_to_bank71
sfx_dst_addr:           .res 2          ; Parameter to sfx_asset_copy_to_bank71

sfx_resident_atlas_id:  .res 2          ; Currently staged atlas_id ($FFFF = none)
sfx_atlas_load_count:   .res 2          ; Number of physical atlas transfers performed
sfx_pending_load_mode:  .res 2          ; SFX_LOAD_MODE_LEVEL (1) or SFX_LOAD_MODE_MAP (2)
sfx_gsu_load_lock:      .res 1          ; Non-zero while 65816 owns $70-$71 bus
sfx_saved_scmr:         .res 1          ; GSU_SCMR value restored on bus release
sfx_saved_inidisp:      .res 1          ; SFX_inidisp shadow saved across forced blank

.export sfx_src_lo, sfx_src_hi, sfx_copy_size, sfx_dst_addr
.export sfx_resident_atlas_id, sfx_atlas_load_count, sfx_gsu_load_lock, sfx_saved_scmr

; ------------------------------------------------------------------------------
; Convenience Macros
; ------------------------------------------------------------------------------

; Initializes loader state (call once during Main boot before loading levels).
.macro SFX_LOADER_INIT scmr_val
        RW_push set:a8i16
    .ifblank scmr_val
        lda     #SFX_DEFAULT_GSU_SCMR
    .else
        lda     #(scmr_val)
    .endif
        jsr     sfx_loader_init
        RW_pull
.endmac

; Loads a complete sfx_level_def (atlas + tab + pal if needed, plus map).
.macro SFX_LOAD_LEVEL level_def_sym
        RW_push set:a8i16
        ldx     #.loword(level_def_sym)
        lda     #^level_def_sym
        jsr     sfx_load_level
        RW_pull
.endmac

; Swaps only a .map sfx_asset_entry into $71:8808 (preserving camera yaw).
.macro SFX_LOAD_MAP map_entry_sym
        RW_push set:a8i16
        ldx     #.loword(map_entry_sym)
        lda     #^map_entry_sym
        jsr     sfx_load_map
        RW_pull
.endmac

.segment "CODE"

; ------------------------------------------------------------------------------
; sfx_loader_init
; In: A (8-bit) = GSU_SCMR value to restore after loads (e.g. %00011101)
; ------------------------------------------------------------------------------
sfx_loader_init:
        php
        RW_forced a8i16
        pha
        lda     #$80
        pha
        plb
        pla
        sta     a:sfx_saved_scmr
        stz     a:sfx_gsu_load_lock
        ldx     #$FFFF
        stx     a:sfx_resident_atlas_id
        ldx     #$0000
        stx     a:sfx_atlas_load_count
        stx     a:sfx_pending_load_mode
        plp
        rts

; ------------------------------------------------------------------------------
; _sfx_acquire_gsu_bus
; Locks VBlank GSU dispatch, enters forced blank, waits for GSU GO == 0,
; and clears GSU_SCMR (releasing RAN/RON so 65816 owns $70-$71).
; ------------------------------------------------------------------------------
_sfx_acquire_gsu_bus:
        php
        RW_forced a8i16
        lda     #$80
        pha
        plb

        lda     #$01
        sta     a:sfx_gsu_load_lock

        ; Save current SFX_inidisp shadow and force blank immediately
        lda     z:SFX_inidisp
        sta     a:sfx_saved_inidisp
        lda     #inidisp(OFF, DISP_BRIGHTNESS_MAX)
        sta     z:SFX_inidisp
        sta     INIDISP

        ; Wait until GSU finishes any in-flight frame pass (SFR bit 5 GO == 0)
@wait_gsu_idle:
        lda     GSU_SFR
        and     #%00100000
        bne     @wait_gsu_idle

        ; Release GSU RAM/ROM bus ownership so 65816 can write $70-$71 freely
        stz     GSU_SCMR

        plp
        rts

; ------------------------------------------------------------------------------
; _sfx_release_gsu_bus
; Writes GSU_LOAD_MODE, resets GSU_INIT_FLAG = 0 and GSU_FRAME_HALF = 0 in $70,
; restores GSU_SCMR, restores SFX_inidisp, and clears sfx_gsu_load_lock.
; ------------------------------------------------------------------------------
_sfx_release_gsu_bus:
        php
        RW_forced a16i16
        lda     a:sfx_pending_load_mode
        sta     f:GSU_LOAD_MODE
        lda     #$0000
        sta     f:GSU_INIT_FLAG
        sta     f:GSU_FRAME_HALF

        RW a8
        lda     #$80
        pha
        plb

        lda     a:sfx_saved_scmr
        sta     GSU_SCMR

        lda     a:sfx_saved_inidisp
        sta     z:SFX_inidisp

        stz     a:sfx_gsu_load_lock
        plp
        rts

; ------------------------------------------------------------------------------
; _sfx_copy_entry_at_y
; Reads a 6-byte sfx_asset_entry at `[sfx_def_ptr], y` into LORAM request vars,
; sets `a:sfx_dst_addr = X`, and invokes `sfx_asset_copy_to_bank71`.
; In: Y (16-bit) = byte offset from sfx_def_ptr, X (16-bit) = $71 dest addr
; ------------------------------------------------------------------------------
_sfx_copy_entry_at_y:
        php
        RW_forced a16i16
        stx     a:sfx_dst_addr
        lda     [sfx_def_ptr], y
        sta     a:sfx_src_lo
        iny
        iny
        lda     [sfx_def_ptr], y
        sta     a:sfx_src_hi
        iny
        iny
        lda     [sfx_def_ptr], y
        sta     a:sfx_copy_size
        jsr     sfx_asset_copy_to_bank71
        plp
        rts

; ------------------------------------------------------------------------------
; _sfx_stage_atlas_from_def_ptr
; Checks `atlas_id` at `[sfx_def_ptr] + 0`; if `$FFFF` or != `sfx_resident_atlas_id`,
; copies `.bin` -> `$71:0000`, `.tab` -> `$71:8000`, `.pal` -> `$71:9010`, and
; DMAs 32 bytes from `$71:9010` to CGRAM color 0.
; Out: Carry Set if atlas was transferred; Carry Clear if skipped (cache hit).
; ------------------------------------------------------------------------------
_sfx_stage_atlas_from_def_ptr:
        php
        RW_forced a16i16
        ldy     #sfx_level_def::atlas_id
        lda     [sfx_def_ptr], y
        cmp     #$FFFF
        beq     _sfx_stage_do_transfer
        cmp     a:sfx_resident_atlas_id
        beq     _sfx_stage_cache_hit

_sfx_stage_do_transfer:
        sta     a:sfx_resident_atlas_id
        inc     a:sfx_atlas_load_count

        ldy     #sfx_level_def::atlas_entry
        ldx     #BANK71_ATLAS_ADDR
        jsr     _sfx_copy_entry_at_y

        ldy     #sfx_level_def::tab_entry
        ldx     #BANK71_TAB_ADDR
        jsr     _sfx_copy_entry_at_y

        ldy     #sfx_level_def::pal_entry
        ldx     #BANK71_PAL_ADDR
        jsr     _sfx_copy_entry_at_y

        ; Upload 32-byte BGR555 palette from $71:9010 to CGRAM color 0
        CGRAM_memcpy 0, BANK71_PAL_LONG, BANK71_PAL_BYTES

        plp
        sec
        rts

_sfx_stage_cache_hit:
        plp
        clc
        rts

; ------------------------------------------------------------------------------
; sfx_load_atlas
; Stages only the atlas/tab/palette of a `sfx_level_def` if not already resident.
; In: A (8-bit) = bank of sfx_level_def, X (16-bit) = offset of sfx_level_def
; ------------------------------------------------------------------------------
sfx_load_atlas:
        php
        RW_forced a8i16
        stx     z:sfx_def_ptr
        sta     z:sfx_def_ptr + 2

        jsr     _sfx_acquire_gsu_bus
        jsr     _sfx_stage_atlas_from_def_ptr
        bcc     @no_reinit

        ldx     #SFX_LOAD_MODE_MAP
        stx     a:sfx_pending_load_mode
        jsr     _sfx_release_gsu_bus
        plp
        rts

@no_reinit:
        ; Restore GSU bus without resetting GSU_INIT_FLAG since nothing changed
        lda     #$80
        pha
        plb
        lda     a:sfx_saved_scmr
        sta     GSU_SCMR
        lda     a:sfx_saved_inidisp
        sta     z:SFX_inidisp
        stz     a:sfx_gsu_load_lock
        plp
        rts

; ------------------------------------------------------------------------------
; sfx_load_map
; Stages a single `.map` `sfx_asset_entry` into `$71:8808` and triggers map-only
; GSU re-import (`SFX_LOAD_MODE_MAP`: resets translation, preserves camera yaw).
; In: A (8-bit) = bank of sfx_asset_entry, X (16-bit) = offset of sfx_asset_entry
; ------------------------------------------------------------------------------
sfx_load_map:
        php
        RW_forced a8i16
        stx     z:sfx_def_ptr
        sta     z:sfx_def_ptr + 2

        jsr     _sfx_acquire_gsu_bus

        ldy     #$0000
        ldx     #BANK71_MAP_ADDR
        jsr     _sfx_copy_entry_at_y

        ldx     #SFX_LOAD_MODE_MAP
        stx     a:sfx_pending_load_mode
        jsr     _sfx_release_gsu_bus

        plp
        rts

; ------------------------------------------------------------------------------
; sfx_load_level
; Stages a complete `sfx_level_def` (deduplicating atlas/tab/pal via `atlas_id`,
; always staging `.map` into `$71:8808`) and triggers full level GSU re-import
; (`SFX_LOAD_MODE_LEVEL`: resets camera yaw=1 and translation).
; In: A (8-bit) = bank of sfx_level_def, X (16-bit) = offset of sfx_level_def
; ------------------------------------------------------------------------------
sfx_load_level:
        php
        RW_forced a8i16
        stx     z:sfx_def_ptr
        sta     z:sfx_def_ptr + 2

        jsr     _sfx_acquire_gsu_bus
        jsr     _sfx_stage_atlas_from_def_ptr

        ldy     #sfx_level_def::map_entry
        ldx     #BANK71_MAP_ADDR
        jsr     _sfx_copy_entry_at_y

        ldx     #SFX_LOAD_MODE_LEVEL
        stx     a:sfx_pending_load_mode
        jsr     _sfx_release_gsu_bus

        plp
        rts

        RW_assume a8i16

.endif ; ::__GSU_ISO_CPU_ASSET_LOADER__
