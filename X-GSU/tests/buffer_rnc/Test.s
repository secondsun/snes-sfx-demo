; SuperFX
; David Lindecrantz <optiroc@gmail.com>
;
; For now this merely gets code running on the GSU

.include "libSFX.i"

Main:
        ;Copy GSU code
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
        ;Copy SNES code
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
        jml __MAIN_LOOP_RUN__

.SEGMENT "MAIN_LOOP"
        ;Configure GSU
        lda     #$70
        sta     GSU_PBR
        lda     #$10
        sta     GSU_SCBR
        lda     #%00111101 ;4bpp_obj SuperFX controls ram and rom
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR

        ;Start GSU
        break
        ldx     __GSUCODE_RUN__
        stx     GSU_R15

        ;Turn on screen
        CGRAM_setcolor_rgb 0, 31,7,31

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        VBL_on
loops:
:       wai
        bra :-

.segment "GSUDATA"
badapple:
.export badapple
  incbin Badapple, "badapple.bin"