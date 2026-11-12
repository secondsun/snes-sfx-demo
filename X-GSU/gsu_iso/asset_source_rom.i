; ==============================================================================
; asset_source_rom.i - 65816 Cartridge ROM AssetSource Backend for Bank $71
;
; Implements `sfx_asset_copy_to_bank71` using libSFX's zero-page `SFX_mvn`
; block-move trampoline so assets may reside in any LoROM bank ($80..$FF).
; Immediately restores Data Bank DB = $80 after `MVN` so MMIO ($21xx/$30xx/$42xx)
; and LORAM accesses remain valid.
;
; Drop-in swappable with `asset_source_msu1.i`.
; ==============================================================================

.ifndef __GSU_ISO_ASSET_SOURCE_IMPL__
__GSU_ISO_ASSET_SOURCE_IMPL__ = 1

.include "bank71_layout.i"

.segment "CODE"

; Copies `sfx_copy_size` bytes (1..$8000) from ROM `(sfx_src_hi[7:0]:sfx_src_lo)`
; to Game Pak RAM `$71:sfx_dst_addr`.
;
; Preconditions:
;   - GSU bus has been released by caller (`GSU_SFR` GO == 0, `GSU_SCMR == 0`).
;   - `sfx_src_lo`, `sfx_src_hi`, `sfx_copy_size`, `sfx_dst_addr` populated in LORAM.
; Postconditions:
;   - Data Bank `DB` restored to `$80`.
;   - Processor register widths preserved via `RW_push` / `RW_pull`.
sfx_asset_copy_to_bank71:
        php
        RW_forced a16i16
        lda     a:sfx_copy_size
        beq     _sfx_rom_copy_done

        RW a8
        lda     a:sfx_src_hi            ; Low byte = source LoROM bank ($80..$FF / $00..$7D)
        sta     z:SFX_mvn_src
        lda     #BANK71_BANK            ; Destination bank = $71
        sta     z:SFX_mvn_dst

        RW a16
        ldx     a:sfx_src_lo            ; X = 16-bit source offset
        ldy     a:sfx_dst_addr          ; Y = 16-bit destination offset in $71
        lda     a:sfx_copy_size
        dec                             ; MVN transfers C + 1 bytes (0 -> 1 byte, $7FFF -> 32768 bytes)
        jsl     SFX_mvn                 ; Clobbers DB -> $71

        RW a8
        lda     #$80                    ; Immediately restore DB = $80 for MMIO & LORAM
        pha
        plb

_sfx_rom_copy_done:
        plp
        rts

        RW_assume a8i16

.endif ; ::__GSU_ISO_ASSET_SOURCE_IMPL__
