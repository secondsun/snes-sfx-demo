; ==============================================================================
; TEST_MAP_GRID - SNES Main CPU Harness & GSU ROM Data
; ==============================================================================
.include "libSFX.i"
.import GSU_Code, __GSURAM_LOAD__

Main:
    ; Copy GSU code to SRAM
    memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
    ; Copy SNES code to RAM
    memcpy __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
    memcpy __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
    jml __MAIN_LOOP_RUN__

.segment "MAIN_LOOP"
    ; Clear GSURAM BSS and screen buffer in SRAM ($70:__GSURAM_LOAD__ .. $70:A7FF)
    ldx #.loword(__GSURAM_LOAD__)
    lda #0
:   sta $700000, x
    inx
    cpx #$A800
    bne :-

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
    CGRAM_setcolor_rgb 6,  31,  0, 31  ; Color 6:  Magenta
    CGRAM_setcolor_rgb 7,   0, 31, 31  ; Color 7:  Cyan
    CGRAM_setcolor_rgb 8,  31, 31, 31  ; Color 8:  White
    CGRAM_setcolor_rgb 9,  10, 10, 10  ; Color 9:  Dark Gray
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

; Texture 0: 32x32 Floor (pitch 64, offset 0, rows 0..31). Texel = ((x >> 1) + (y >> 1)) % 7 + 2 (values 2..8)
.repeat 32, row
    .repeat 32, col
        .byte (((col / 2) + (row / 2)) .mod 7) + 2
    .endrepeat
    .repeat 32
        .byte $00
    .endrepeat
.endrepeat

; Texture 1: 32x32 Skirt (pitch 64, offset 2048, rows 0..31). Texel = ((col + row) % 3) + 6 (values 6..8)
.repeat 32, row
    .repeat 32, col
        .byte (((col + row) .mod 3) + 6)
    .endrepeat
    .repeat 32
        .byte $00
    .endrepeat
.endrepeat

; Texture 2: 32x32 2-Band Skirt at pitch 128 (stride_shift = 7):
;   Rows 0..7   (bytes 0..1023):    Color 3 (upper skirt step s=0)
;   Rows 8..15  (bytes 1024..2047): Sentinel Color 9 (catches broken << 10 offset!)
;   Rows 16..31 (bytes 2048..4095): Color 6 (lower skirt step s=1 via 16 << 7 = 2048)
TEST_ATLAS_128_SKIRT:
.repeat 32, row
    .repeat 32, col
        .if row < 8
            .byte $03
        .elseif row < 16
            .byte $09
        .else
            .byte $06
        .endif
    .endrepeat
    .repeat 96
        .byte $00
    .endrepeat
.endrepeat

; Texture 3: 32x64 2-Cell Floor at pitch 128 (stride_shift = 7):
;   Rows 0..15  (bytes 0..2047):    Color 4 (cell j=0 floor)
;   Rows 16..31 (bytes 2048..4095): Sentinel Color 9 (catches broken << 11 offset!)
;   Rows 32..63 (bytes 4096..8191): Color 5 (cell j=1 floor via 32 << 7 = 4096)
TEST_ATLAS_128_FLOOR:
.repeat 64, row
    .repeat 32, col
        .if row < 16
            .byte $04
        .elseif row < 32
            .byte $09
        .else
            .byte $05
        .endif
    .endrepeat
    .repeat 96
        .byte $00
    .endrepeat
.endrepeat

; Texture Table for descriptor lookup
.export TEXTURE_TABLE
TEXTURE_TABLE:
    .word .loword(TEST_ATLAS + 0),          31, (31 << 6), ((31 << 6) | ((1 << 6) - 1)) ; ID 0: 32x32 Floor (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS + 2048),       31, (31 << 6), ((31 << 6) | ((1 << 6) - 1)) ; ID 1: 32x32 Skirt (pitch 64, stride_shift 6)
    .word .loword(TEST_ATLAS_128_SKIRT),    31, (31 << 7), ((31 << 7) | ((1 << 7) - 1)) ; ID 2: 32x32 Skirt (pitch 128, stride_shift 7)
    .word .loword(TEST_ATLAS_128_FLOOR),    31, (63 << 7), ((63 << 7) | ((1 << 7) - 1)) ; ID 3: 32x64 Floor (pitch 128, stride_shift 7)
