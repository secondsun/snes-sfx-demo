; ==============================================================================
; TEST_EDGE_PANELS - SNES Main CPU Harness & GSU ROM Data
; ==============================================================================
.include "libSFX.i"
.import GSU_Code

Main:
    ; Copy GSU code to SRAM
    memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
    ; Copy SNES code to RAM
    memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
    memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
    jml __MAIN_LOOP_RUN__

.segment "MAIN_LOOP"
    ; Clear screen buffer in SRAM at $708000 ($2800 bytes)
    ; ldx #$8000
    ; lda #0
; :   sta $700000, x
    ; inx
    ; cpx #$A800
    ; bne :-

    ; Configure GSU registers
    lda #$70
    sta GSU_PBR         ; Program Bank = $70
    lda #$20
    sta GSU_SCBR        ; Screen Base Register = $20 ($708000)
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
    ldx #.loword(GSU_Code)
    stx GSU_R15

    ; Set up SNES Palette in CGRAM
    CGRAM_setcolor_rgb 0,   0,  0,  0  ; Color 0:  Transparent ($0000)
    CGRAM_setcolor_rgb 1,   1,  0,  0  ; Color 1:  Opaque Black ($0001)
    CGRAM_setcolor_rgb 2,  31,  0,  0  ; Color 2:  Red
    CGRAM_setcolor_rgb 3,   0, 31,  0  ; Color 3:  Green
    CGRAM_setcolor_rgb 4,   0,  0, 31  ; Color 4:  Blue
    CGRAM_setcolor_rgb 5,  31, 31,  0  ; Color 5:  Yellow
    CGRAM_setcolor_rgb 6,  31,  0, 31  ; Color 6:  Magenta (Floor)
    CGRAM_setcolor_rgb 7,   0, 31, 31  ; Color 7:  Cyan (Back Panel)
    CGRAM_setcolor_rgb 8,  31, 31, 31  ; Color 8:  White
    CGRAM_setcolor_rgb 9,  10, 10, 10  ; Color 9:  Dark Gray (Front Panel)
    CGRAM_setcolor_rgb 10, 20, 20, 20  ; Color 10: Med Gray

    lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
    sta SFX_inidisp
    VBL_on

loops:
:   wai
    bra :-

; ==============================================================================
; Test Texture Atlas & TEXTURE_TABLE (ROM Bank $04, GSUDATA)
; ==============================================================================
.segment "GSUDATA"

.export TEST_ATLAS
TEST_ATLAS:

; Texture 0: 32x32 Floor (pitch 64, offset 0, rows 0..31)
; Solid color 6 (Magenta)
.repeat 32, row
    .repeat 32, col
        .byte $06
    .endrepeat
    .repeat 32
        .byte $00
    .endrepeat
.endrepeat

; Texture 1: 32x32 Back Panel (pitch 64, offset 2048, rows 0..31)
; Solid color 7 (Cyan)
.repeat 32, row
    .repeat 32, col
        .byte $07
    .endrepeat
    .repeat 32
        .byte $00
    .endrepeat
.endrepeat

; Texture 2: 32x32 Front Parapet Cutout Panel (pitch 64, offset 4096, rows 0..31)
; Crenellated battlement: top half has alternating color 0 (cutout) and color 9 (stone),
; bottom half is solid color 9.
.repeat 32, row
    .repeat 32, col
        .if row < 16
            .if ((col / 8) .mod 2) = 0
                .byte $00 ; transparent cutout embrasure
            .else
                .byte $09 ; opaque stone merlon
            .endif
        .else
            .byte $09 ; solid lower parapet wall
        .endif
    .endrepeat
    .repeat 32
        .byte $00
    .endrepeat
.endrepeat

; Texture Table for descriptor lookup
.export TEXTURE_TABLE
TEXTURE_TABLE:
    .word .loword(TEST_ATLAS + 0),     31, 31, 6 ; ID 0: Floor (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS + 2048),  31, 31, 6 ; ID 1: Back Panel (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS + 4096),  31, 31, 6 ; ID 2: Front Parapet Cutout (pitch 64, stride_shift 6)

