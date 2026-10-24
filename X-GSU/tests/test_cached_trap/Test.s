; ==============================================================================
; CACHED_TRAP_TEST - SNES Main CPU Harness & GSU ROM Data
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
    CGRAM_setcolor_rgb 0,   0,  0,  0  ; Color 0:  Transparent ($0000)
    CGRAM_setcolor_rgb 1,   1,  0,  0  ; Color 1:  Opaque Black ($0001)
    CGRAM_setcolor_rgb 2,  31,  0,  0  ; Color 2:  Red
    CGRAM_setcolor_rgb 3,   0, 31,  0  ; Color 3:  Green
    CGRAM_setcolor_rgb 4,   0,  0, 31  ; Color 4:  Blue
    CGRAM_setcolor_rgb 5,  31, 31,  0  ; Color 5:  Yellow
    CGRAM_setcolor_rgb 6,  31,  0, 31  ; Color 6:  Magenta
    CGRAM_setcolor_rgb 7,   0, 31, 31  ; Color 7:  Cyan
    CGRAM_setcolor_rgb 8,  31, 31, 31  ; Color 8:  White
    CGRAM_setcolor_rgb 14, 15, 15, 15  ; Color 14: Background Gray

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

; Texture 0: 16x16 (pitch 64, rows 0..15). Texel = ((x + y) & 7) + 1 (values 1..8)
.repeat 16, row
    .repeat 16, col
        .byte ((col + row) .mod 8) + 1
    .endrepeat
    .repeat 48
        .byte $00
    .endrepeat
.endrepeat

; Texture 1: 32x32 (pitch 64, offset 1024, rows 0..31). Texel = ((x >> 1) & 7) + 1
.repeat 32, row
    .repeat 32, col
        .byte (((col / 2) + (row / 2)) .mod 8) + 1
    .endrepeat
    .repeat 32
        .byte $00
    .endrepeat
.endrepeat

; Texture 2: 64x64 (pitch 64, offset 3072, rows 0..63). Texel = ((col / 4 + row / 4) % 8) + 1
.repeat 64, row
    .repeat 64, col
        .byte (((col / 4) + (row / 4)) .mod 8) + 1
    .endrepeat
.endrepeat

; Texture 3: 16x16 Checkerboard (pitch 64, offset 7168, rows 0..15).
; (col + row) % 2 == 0 -> Color $00 (transparent), == 1 -> Color $01 (opaque black)
.repeat 16, row
    .repeat 16, col
        .if ((col + row) .mod 2) = 0
            .byte $00
        .else
            .byte $01
        .endif
    .endrepeat
    .repeat 48
        .byte $00
    .endrepeat
.endrepeat

; Texture 4: 128x128 (pitch 128, offset 8192, 64 rows of 128 bytes = 8192 bytes)
.repeat 64, row
    .repeat 128, col
        .byte (((col / 8) + (row / 8)) .mod 8) + 1
    .endrepeat
.endrepeat

; Texture Table for descriptor lookup
.export TEXTURE_TABLE
TEXTURE_TABLE:
    .word .loword(TEST_ATLAS + 0),     15,  15, 6 ; ID 0: 16x16 (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS + 1024),  31,  31, 6 ; ID 1: 32x32 (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS + 3072),  63,  63, 6 ; ID 2: 64x64 (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS + 7168),  15,  15, 6 ; ID 3: 16x16 checkerboard ($00 / $01)
    .word .loword(TEST_ATLAS + 8192), 127, 127, 7 ; ID 4: 128x128 (pitch 128, stride_shift 7)
