; ==============================================================================
; TEST_TEXTURE_REPEAT - SNES Main CPU Harness & GSU ROM Data
; ==============================================================================
.include "libSFX.i"

Main:
    ; Copy GSU code to SRAM
    memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
    ; Copy SNES code to RAM
    memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
    memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
    jml __MAIN_LOOP_RUN__

.segment "MAIN_LOOP"
    ; Clear screen buffer in SRAM at $704000 ($2800 bytes)
    ldx #$4000
    lda #0
:   sta $700000, x
    inx
    cpx #$6800
    bne :-

    ; Configure GSU registers
    lda #$70
    sta GSU_PBR         ; Program Bank = $70
    lda #$10
    sta GSU_SCBR        ; Screen Base Register = $10 ($704000)
    lda #%00011101      ; 4bpp, 160-height, SuperFX controls RAM and ROM
    sta GSU_SCMR
    lda #%10000000      ; 21.47 MHz high speed
    sta GSU_CFGR
    lda #$01
    sta GSU_CLSR
    lda #$04
    sta GSU_ROMBR       ; ROM Bank = $04

    ; Start GSU
    break
    ldx __GSUCODE_RUN__
    stx GSU_R15

    ; Set up SNES Palette in CGRAM
    CGRAM_memcpy 0, Palette, sizeof_Palette

    lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
    sta SFX_inidisp
    VBL_on

loops:
:   wai
    bra :-

; ==============================================================================
; Texture Atlas & TEXTURE_TABLE (ROM Bank $04, GSUDATA)
; ==============================================================================
.segment "GSUDATA"

textures_binary:
.export textures_binary
    .incbin "Data/TEXTURES.bin"

.segment "RODATA"
incbin Palette, "Data/TEXTURES.pal"
