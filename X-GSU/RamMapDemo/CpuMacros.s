; Configures GSU registers for 4bpp color depth at 160-pixel screen height.
; GSUCODE executes from ROM Bank $03 ($03:8000), ROM LUTs live in Bank $04,
; and the 10 KB half-screen framebuffer lives at $70:8000 (GSU_SCBR = $20).
.macro initGSU_4bpp_160
        lda     #$03
        sta     GSU_PBR

        lda     #$04
        sta     GSU_ROMBR

        lda     #(.loword(screenbuffer) / $400)
        sta     GSU_SCBR

        lda     #%00011101      ; 4bpp 160-line mode, GSU owns RAM + ROM
        sta     GSU_SCMR

        lda     #%10100000      ; Mask GSU IRQ, High-Speed Multiply enabled
        sta     GSU_CFGR

        lda     #$01            ; 21.47 MHz clock speed
        sta     GSU_CLSR
.endmac

; Starts GSU execution by writing GSU_Code to GSU_R15.
.macro gsuOn
        RW_push set:a16
        lda     #.loword(GSU_Code)
        sta     GSU_R15
        RW_pull
.endmac

; Checks whether the GSU is currently running (Z=1 if idle, Z=0 if running).
.macro gsuRunning
        lda     GSU_SFR
        and     #%00100000
.endmac

; Returns from the VBlank NMI trampoline.
.macro endVBlank
        rtl
.endmac
