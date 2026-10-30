.include "libSFX.i"

screenbuffer = $704000
screenbuffer_len = $2800
VRAM_tilemap = $E800
VRAM_screen_1 = $0000

Main:
        ;Copy GSU code
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__
        ;Copy SNES code
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__

        ;Copy Palette
        CGRAM_memcpy 0, Palette, sizeof_Palette

        ;Copy SuperFX tileMap
        VRAM_memcpy VRAM_tilemap, Map, Map_end - Map

        jml __MAIN_LOOP_RUN__

.SEGMENT "MAIN_LOOP"
        ; Set databank to $80 for MMIO access
        lda     #$80
        pha
        plb

        ;Set up screen mode (Mode 1, 4bpp BG1)
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #bgsc(VRAM_tilemap, SC_SIZE_32X32)
        sta     BG1SC
        
        ldx     #bg12nba(VRAM_screen_1, 0)
        stx     BG12NBA
        
        lda     #tm(ON, OFF, OFF, OFF, OFF)
        sta     TM

        stz     BG1VOFS
        stz     BG1VOFS
        stz     BG1HOFS
        stz     BG1HOFS

        ;Configure GSU
        lda     #$70
        sta     GSU_PBR
        lda     #$10
        sta     GSU_SCBR
        lda     #%00011101 ;4bpp_160 SuperFX controls ram and rom
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR

        ;Start GSU
        ldx     __GSUCODE_RUN__
        stx     GSU_R15

loops:
        ; Wait for GSU to stop
:       lda     GSU_SFR
        and     #$20
        bne     :-

        ; Once GSU stops, copy screenbuffer to VRAM so Mesen displays it on screen
        lda     #%00001101 ; Give SNES CPU access to Cartridge RAM
        sta     GSU_SCMR

        lda     #inidisp(OFF, DISP_BRIGHTNESS_MAX)
        sta     INIDISP
        sta     SFX_inidisp

        VRAM_memcpy VRAM_tilemap, Map, Map_end - Map
        VRAM_memcpy VRAM_screen_1, screenbuffer, screenbuffer_len

        RW a16
        lda #0
        RW a8
        sta BG1VOFS
        xba
        sta BG1VOFS

        RW a16
        lda #0
        RW a8
        sta BG1HOFS
        xba
        sta BG1HOFS

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     INIDISP
        sta     z:SFX_inidisp

        VBL_set Vblank
        VBL_on

idle:
        wai
        bra idle

Vblank:
        rtl

.segment "GSUDATA"
textures_binary:
.export textures_binary
    .incbin "../../IsoEngine/Data/TEXTURES_graphics.bin"

.segment "RODATA"
Palette:
    .incbin "../../IsoEngine/Data/TEXTURES_palette.bin"
sizeof_Palette = 32

.include "../../IsoEngine/backgroundMap.s"
