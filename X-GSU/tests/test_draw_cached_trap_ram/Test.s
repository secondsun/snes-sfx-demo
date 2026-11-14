; ==============================================================================
; TEST_DRAW_TRAP_RAM - SNES Main CPU Harness
; ==============================================================================
.include "libSFX.i"
.import GSU_Code

Main:
    memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
    memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
    memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
    jml __MAIN_LOOP_RUN__

.segment "MAIN_LOOP"
    ; Clear screen buffer in SRAM at $70:A000 ($2800 bytes)
    ldx #$A000
    lda #0
:   sta $700000, x
    inx
    cpx #$C800
    bne :-

    ; Configure GSU registers
    lda #$70
    sta GSU_PBR         ; Program Bank = $70
    lda #$28
    sta GSU_SCBR        ; Screen Base Register = $28 ($70:A000)
    lda #%00011101      ; 4bpp, 160-height, GSU owns RAM + ROM
    sta GSU_SCMR
    lda #%10000000      ; 21.47 MHz
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
; Deterministic Non-Uniform 16x16 Pattern Texture in ROM Bank $04 (GSUDATA)
; Includes color 0 transparent cutouts and non-symmetric U/V gradients so any
; UV drift in @skip_loop or @clip_u_loop produces an immediate pixel mismatch.
; ==============================================================================
.segment "GSUDATA"
.export PARITY_ROM_TEX
PARITY_ROM_TEX:
.repeat 16, row
    .repeat 16, col
        .byte (((col * 3) + (row * 5)) .mod 15)
    .endrepeat
    .repeat 48
        .byte $00
    .endrepeat
.endrepeat
