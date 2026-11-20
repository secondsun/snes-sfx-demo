; ==============================================================================
; SPRITE_MASK - SNES Main CPU Harness & 1-Bit Sprite Mask ROM Fixtures
; ==============================================================================
.include "libSFX.i"
.import GSU_Code

Main:
    memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
    memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
    memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
    jml __MAIN_LOOP_RUN__

.segment "MAIN_LOOP"
    ; Clear 4bpp framebuffer at $70:C000..$70:E7FF ($2800 bytes)
    ldx #$C000
    lda #0
:   sta $700000, x
    inx
    cpx #$E800
    bne :-

    ; Configure SuperFX (GSU)
    lda #$70
    sta GSU_PBR             ; Program Bank = $70
    lda #$30
    sta GSU_SCBR            ; Screen Base Register = $30 ($70:C000)
    lda #%00011101          ; 4bpp, 160-height, GSU owns RAM + ROM
    sta GSU_SCMR
    lda #%10000000          ; 21.47 MHz
    sta GSU_CFGR
    lda #$01
    sta GSU_CLSR
    lda #$04
    sta GSU_ROMBR

    ldx #.loword(GSU_Code)
    stx GSU_R15

    lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
    sta SFX_inidisp
    VBL_on

:   wai
    bra :-

; ==============================================================================
; 1-Bit MSB-First Sprite Mask Fixtures in ROM Bank $04 (GSUDATA)
; ==============================================================================
.segment "GSUDATA"

; 16x4 Asymmetric Test Mask (2 bytes/row x 4 rows = 8 bytes)
;   Row 0: 10000000 00000001  (col 0 and col 15 set)
;   Row 1: 11111111 00000000  (cols 0..7 set, cols 8..15 clear)
;   Row 2: 00000000 11111111  (cols 0..7 clear, cols 8..15 set)
;   Row 3: 10101010 01010101  (alternating bits)
.export MASK_PATTERN_16x4
MASK_PATTERN_16x4:
    .byte $80, $01
    .byte $FF, $00
    .byte $00, $FF
    .byte $AA, $55

; 16x8 Solid Mask (2 bytes/row x 8 rows = 16 bytes, all bits = 1)
.export MASK_SOLID_16x8
MASK_SOLID_16x8:
    .repeat 8
        .byte $FF, $FF
    .endrepeat
