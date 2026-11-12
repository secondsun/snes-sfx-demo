; ==============================================================================
; asset_source_msu1.i - 65816 MSU-1 Storage AssetSource Backend for Bank $71
;
; Reference specification: https://helmet.kafuka.org/msu1.htm
;
; Implements:
;   - `sfx_msu1_detect`: Checks 6-byte `"S-MSU1"` signature at `$2002 - $2007`.
;   - `sfx_asset_copy_to_bank71`: Seeks 32-bit byte offset via `$2000 - $2003`
;     (`MSU_SEEK`), polls `MSU_STATUS` (`$2000` bit 7 `DATA_BUSY`) until ready,
;     and executes a 2-step hardware DMA transfer via `EXRAM` (`$7F:0000` /
;     `WMDATA` `$2180`):
;       Step 1: Fixed A-bus `$00:2001` (`MSU_READ`) -> B-bus `$2180` (`$7F:0000`)
;       Step 2: B-bus `$2180` (`$7F:0000`) -> Incrementing A-bus `$71:sfx_dst_addr`
;
; Drop-in swappable with `asset_source_rom.i`.
; ==============================================================================

.ifndef __GSU_ISO_ASSET_SOURCE_IMPL__
__GSU_ISO_ASSET_SOURCE_IMPL__ = 1

.include "bank71_layout.i"

MSU_STATUS_DATA_BUSY    = $80

.segment "CODE"

; Checks whether an MSU-1 peripheral is present by verifying `"S-MSU1"` at `$2002..$2007`.
; Out:
;   Carry Set (`SEC`) if MSU-1 is detected;
;   Carry Clear (`CLC`) if absent.
;   Preserves `DB` and caller `M`/`X` register widths.
sfx_msu1_detect:
        php
        RW_forced a8i16
        phb
        lda     #$80
        pha
        plb

        ldx     MSU_ID                  ; $2002..$2003 == "S-" ($2D53)
        cpx     #$2D53
        bne     @absent
        ldx     MSU_ID + 2              ; $2004..$2005 == "MS" ($534D)
        cpx     #$534D
        bne     @absent
        ldx     MSU_ID + 4              ; $2006..$2007 == "U1" ($3155)
        cpx     #$3155
        bne     @absent

        plb
        plp
        sec
        rts

@absent:
        plb
        plp
        clc
        rts

; Streams `sfx_copy_size` bytes (1..$8000) from MSU-1 data pack offset
; `(sfx_src_hi:sfx_src_lo)` into Game Pak RAM `$71:sfx_dst_addr`.
;
; Preconditions:
;   - GSU bus has been released by caller (`GSU_SFR` GO == 0, `GSU_SCMR == 0`).
;   - `sfx_src_lo`, `sfx_src_hi`, `sfx_copy_size`, `sfx_dst_addr` populated in LORAM.
; Postconditions:
;   - Data Bank `DB` restored to `$80`.
sfx_asset_copy_to_bank71:
        php
        RW_forced a8i16
        lda     #$80
        pha
        plb

        ldx     a:sfx_copy_size
        beq     _sfx_msu_copy_done

        ; 1. Issue 32-bit byte seek to MSU_SEEK ($2000..$2003); writing $2003 triggers seek
        ldx     a:sfx_src_lo
        stx     MSU_SEEK                ; $2000..$2001 (bits 0..15)
        ldx     a:sfx_src_hi
        stx     MSU_SEEK + 2            ; $2002..$2003 (bits 16..31, latches seek)

        ; 2. Wait for MSU_STATUS ($2000) bit 7 (DATA_BUSY) to clear
_sfx_msu_wait_ready:
        bit     MSU_STATUS
        bmi     _sfx_msu_wait_ready

        ; 3. Step 1 DMA: Fixed A-bus $00:2001 (MSU_READ) -> B-bus $2180 (WMDATA @ $7F:0000)
        stz     WMADDL
        stz     WMADDM
        lda     #$01                    ; Bank $7F (EXRAM)
        sta     WMADDH

        lda     #(DMA_DIR_MEM_TO_PPU | DMA_FIXED | DMA_TRANS_1)
        sta     DMAP7
        lda     #<WMDATA
        sta     BBAD7
        ldx     #MSU_READ               ; $2001
        stx     A1T7L
        stz     A1B7                    ; Bank $00
        ldx     a:sfx_copy_size
        stx     DAS7L
        lda     #DMA7_ON
        sta     MDMAEN

        ; 4. Step 2 DMA: B-bus $2180 (WMDATA @ $7F:0000) -> Incrementing A-bus $71:sfx_dst_addr
        stz     WMADDL
        stz     WMADDM
        lda     #$01                    ; Rewind WRAM port to $7F:0000
        sta     WMADDH

        lda     #(DMA_DIR_PPU_TO_MEM | DMA_INCREMENT | DMA_TRANS_1)
        sta     DMAP7
        lda     #<WMDATA
        sta     BBAD7
        ldx     a:sfx_dst_addr
        stx     A1T7L
        lda     #BANK71_BANK            ; Bank $71
        sta     A1B7
        ldx     a:sfx_copy_size
        stx     DAS7L
        lda     #DMA7_ON
        sta     MDMAEN

_sfx_msu_copy_done:
        plp
        rts

        RW_assume a8i16

.endif ; ::__GSU_ISO_ASSET_SOURCE_IMPL__
