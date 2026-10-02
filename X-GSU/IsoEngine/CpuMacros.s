; Configures GSU registers for 4bpp color depth at 160 pixel screen height
; In:       None
; Out:      GSU_PBR, GSU_SCBR, GSU_SCMR, GSU_CFGR, GSU_CLSR initialized
; Clobbers: A (8-bit)
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

; Configures GSU registers for 4bpp color depth in OBJ/Sprite mode
; In:       None
; Out:      GSU_PBR, GSU_SCBR, GSU_SCMR, GSU_CFGR, GSU_CLSR initialized
; Clobbers: A (8-bit)
.macro initGSU_4bpp_obj
  lda     #$03
  sta     GSU_PBR
  
  
  lda     #(.loword(screenbuffer)/$400)
  sta     GSU_SCBR
  
  lda     #%00111101 ;4bpp_obj SuperFX controls ram and rom
  sta     GSU_SCMR
  
  lda     #%10100000			; GSU IRQs DISABLED, HighSpeed Multiply
  sta     GSU_CFGR
  
  lda     #$01 ; 21.4 MHZ speed
  sta     GSU_CLSR
.endmac

; Starts GSU execution by setting GSU program counter (R15) to GSU_Code
; In:       None
; Out:      GSU_R15 = .loword(GSU_Code)
; Clobbers: None (registers preserved via RW_push/RW_pull)
.macro gsuOn
  RW_push set:a16
  lda     #.loword(GSU_Code)
  sta    GSU_R15
  RW_pull  
.endmac

; Forces GSU to stop by clearing the Status/Flag Register (SFR)
; In:       None
; Out:      GSU_SFR = 0
; Clobbers: None (registers preserved via RW_push/RW_pull)
.macro gsuOff
  RW_push set:a16
  lda     #$00
  sta     GSU_SFR
  RW_pull
.endmac

; Checks if the GSU is currently running (Z flag = 1 if idle, 0 if running)
; In:       None
; Out:      Z flag set if GSU is idle (R15 == 0), clear if running
; Clobbers: Flags (registers preserved via RW_push/RW_pull)
.macro gsuRunning
  RW_push set:a16
  lda GSU_R15
  RW_pull
.endmac

; Exits the VBlank interrupt handler via RTL
; In:       None
; Out:      Returns from interrupt subroutine
; Clobbers: None
.macro endVBlank
        rtl
.endmac

; Sets up horizontal scanline IRQ timer and jump target vector
; In:       line = scanline trigger position, addr = optional IRQ handler label
; Out:      HTIMEL set to line, SFX_irq_jml initialized
; Clobbers: None (registers preserved via RW_push/RW_pull)
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

; Enables horizontal scanline IRQ timer interrupt
; In:       None
; Out:      NMITIMEN updated with NMI_H_TIMER_ON, CLI executed
; Clobbers: None (registers preserved via RW_push/RW_pull)
.macro  IRQ_H_on
        RW_push set:a8
        lda     SFX_nmitimen; = 0xF600
        ora     #NMI_H_TIMER_ON; = 0xF610
        sta     SFX_nmitimen
        sta     NMITIMEN
        cli
        RW_pull
.endmac

; Sets up vertical scanline IRQ timer and jump target vector
; In:       line = scanline trigger position, addr = optional IRQ handler label
; Out:      VTIMEL set to line, SFX_irq_jml initialized
; Clobbers: None (registers preserved via RW_push/RW_pull)
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

; Enables vertical scanline IRQ timer interrupt
; In:       None
; Out:      NMITIMEN updated with NMI_V_TIMER_ON, CLI executed
; Clobbers: None (registers preserved via RW_push/RW_pull)
.macro  IRQ_V_on
        RW_push set:a8
        lda     SFX_nmitimen; = 0xF600
        ora     #NMI_V_TIMER_ON; = 0xF610
        sta     SFX_nmitimen
        sta     NMITIMEN
        cli
        RW_pull
.endmac