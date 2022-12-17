;Sets the GSU registers for 4bpp @ 192px

.include "libSFX.i"

GSU_SFR_HI         = $3031 ;Status/Flag Register Hi byte

.macro initGSU_4bpp_160
  lda     #$03
  sta     GSU_PBR
  
  
  lda     #(.loword(screenbuffer)/$400)
  sta     GSU_SCBR
  
  lda     #%00011101 ;4bpp_160 SuperFX controls ram and rom
  sta     GSU_SCMR
  
  lda     #%10000000 ;mask interrupts from GSU
  sta     GSU_CFGR
  
  lda     #$01 ; 21.4 MHZ speed
  sta     GSU_CLSR
.endmac

.macro initGSU_4bpp_obj
  lda     #$03
  sta     GSU_PBR
  
  
  lda     #(.loword(screenbuffer)/$400)
  sta     GSU_SCBR
  
  lda     #%00111101 ;4bpp_obj SuperFX controls ram and rom
  sta     GSU_SCMR
  
  lda     #%10000000 ;mask interrupts from GSU
  sta     GSU_CFGR
  
  lda     #$01 ; 21.4 MHZ speed
  sta     GSU_CLSR
.endmac


.macro gsuOn
  ldx     #.loword(GSU_Code)
  stx     GSU_R15
.endmac

.macro gsuOff
  ldx     #$00
  stx     GSU_SFR
.endmac

;Is the GSU running
; zflag = 1 -> Yes
; zflag = 0 -> No
; Clobbers the Accumulator
.macro gsuRunning
  lda GSU_SFR
	and #%00100000
.endmac

.macro endVBlank
        ;display on
        ;lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
        ;sta SFX_inidisp
        rtl
.endmac

.macro  IRQ_H_set line, addr
        RW_push set:a8i16
.ifnblank addr
        ldx     #.loword(addr)
        lda     #^addr
        stx     SFX_irq_jml+1
        sta     SFX_irq_jml+3
.endif
        ldx     #line
        stx     HTIMEL
        RW_pull
.endmac

/**
  Macro: IRQ_H_on
  Enable horizontal line interrupt
*/
.macro  IRQ_H_on
        RW_push set:a8
        lda     SFX_nmitimen; = 0xF600
        ora     #NMI_H_TIMER_ON; = 0xF610
        sta     SFX_nmitimen
        sta     NMITIMEN
        cli
        RW_pull
.endmac


.macro  IRQ_V_set line, addr
        RW_push set:a8i16
.ifnblank addr
        ldx     #.loword(addr)
        lda     #^addr
        stx     SFX_irq_jml+1
        sta     SFX_irq_jml+3
.endif
        ldx     #line
        stx     VTIMEL
        RW_pull
.endmac

/**
  Macro: IRQ_H_on
  Enable horizontal line interrupt
*/
.macro  IRQ_V_on
        RW_push set:a8
        lda     SFX_nmitimen; = 0xF600
        ora     #NMI_V_TIMER_ON; = 0xF610
        sta     SFX_nmitimen
        sta     NMITIMEN
        cli
        RW_pull
.endmac