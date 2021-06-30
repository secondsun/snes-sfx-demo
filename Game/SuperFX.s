.include "libSFX.i"
.include "pointers.s"
.include "CpuMacros.s"
.include "edgeEntry.i"

Main:

        ;Copy SNES code
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
        
        ;Copy Palette
        CGRAM_memcpy 0, Palette, sizeof_Palette

        ;Copy SuperFX tileMap
	VRAM_memcpy VRAM_tilemap, Map, Map_end - Map

        
        ;Configure GSU
        initGSU_4bpp_160 
        phb

        lda #$70
        pha
        plb
        lda #$1;one sprite
        
        

        sta $0

        plb
        jml __MAIN_LOOP_RUN__

.SEGMENT "MAIN_LOOP"
Main2:
        ;Start GSU
        gsuOn

        RW a16
        lda #0
        sub #10
        RW a8
        sta BG1VOFS
        xba
        sta BG1VOFS
        
        ;Set up screen mode
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #bgsc(VRAM_tilemap, SC_SIZE_32X32)	;position of map and tiles for images
        sta     BG1SC
        sta     BG2SC
        ldx     #bg12nba(VRAM_screen_1, VRAM_screen_2)
        stx     BG12NBA
        lda     #tm(ON, OFF, OFF, OFF, OFF)	;screen buffer use
        sta     TM

        ;initialize screen buffer indexes
        stz z:VRAM_screen_select
        stz z:SFX_buffer_position

        ;Set letterbox irq Interrupt
        IRQ_V_set 199, Vblank
        IRQ_V_on
        
        ;Turn on screen
        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        ;VBL_set Vblank
        VBL_on
        

;infinite loop
:       wai
        bra     :-

Vblank:
        ;if vblank NMI just skip, we're waiting on the IRQ
        bne transfer
        endVBlank

        ;RW_forced a8i8
        ;prepare for dma to vram
        ;display off

transfer:
        lda #inidisp(OFF, DISP_BRIGHTNESS_MAX)
        sta INIDISP
        ;if frame finished?
        
        gsuRunning
        beq :+
        endVBlank
        ;Which VRAM bank do we draw to
:       lda z:VRAM_screen_select
        bne drawScreen2
        jmp drawScreen1
        
drawScreen2:
                ;Where do we copy from?
                lda z:SFX_buffer_position
                beq :+
        ;copyFromHalf:
                VRAM_memcpy (VRAM_screen_2 + screenbuffer_len), (screenbuffer ), screenbuffer_len
                stz z:SFX_buffer_position ;sfx reads from start of work ram
                stz z:VRAM_screen_select ; write to the other screen
                ldx     #bg12nba(VRAM_screen_2, VRAM_screen_1)
                stx     BG12NBA
                gsuOn
                endVBlank
        :;copyFromStart:        
                VRAM_memcpy VRAM_screen_2, screenbuffer, screenbuffer_len
                lda #$01;sfx reads from middle of work ram
                sta z:SFX_buffer_position        
                gsuOn
                endVBlank
drawScreen1:        
                ;Where do we copy from?
                lda z:SFX_buffer_position
                beq :+
        ;copyFromHalf:
                VRAM_memcpy (VRAM_screen_1 + screenbuffer_len), (screenbuffer ), screenbuffer_len
                lda #$00
                sta z:SFX_buffer_position ;sfx reads from start of work ram
                lda #$01
                sta z:VRAM_screen_select ; write to the other screen
                ldx #bg12nba(VRAM_screen_1, VRAM_screen_2)
                stx BG12NBA
                gsuOn
                endVBlank
        : ;copyFromStart:        
                VRAM_memcpy VRAM_screen_1, screenbuffer, screenbuffer_len
                lda #$01 ;sfx reads from middle of work ram
                sta z:SFX_buffer_position
                gsuOn
                endVBlank
.segment "RODATA"
.include "backgroundMap.s"

.segment "ZEROPAGE"
   VRAM_screen_select: .res 1    ; which VRAM address should be selected, see SFX_VRAM in todo.pointers
                                ; This is where SFX buffers are copied to.
                                ; 0 = screen 1
                                ; 1 = screen 2
   SFX_buffer_position: .res 1   ; Where to begin DMA from in work ram; 
                                ; 0 = $700400
                                ; 1 = $702900
.segment "RODATA"
   incbin  Palette,        "Data/superfx.palette.bin"
                                    