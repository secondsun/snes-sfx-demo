; SuperFX
; David Lindecrantz <optiroc@gmail.com>
;
; For now this merely gets code running on the GSU

.include "libSFX.i"

Main:

        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
       

        ;Configure GSU
        lda     #$70
        sta     GSU_PBR
        lda     #$10
        sta     GSU_SCBR
        lda     #%00001000
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR

        ;Start GSU
     jml __MAIN_LOOP_RUN__
.SEGMENT "MAIN_LOOP"
    
        ldx     #.loword(GSU_Code)
        stx     GSU_R15

        ;Turn on screen
        CGRAM_setcolor_rgb 0, 31,7,31

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        VBL_off
loops:
:       wai
        bra :-
