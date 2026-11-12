; ==============================================================================
; TEST_ISO_RAM_IMPORT - SNES Main CPU Harness
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

    lda #$70
    sta GSU_PBR
    lda #$28
    sta GSU_SCBR        ; $70:A000 framebuffer (well above GSUCODE + GSURAM)
    lda #%00011101
    sta GSU_SCMR
    lda #%10000000
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
