.include "libSFX.i"
.include "pointers.s"
.include "CpuMacros.s"


;This is the main vector of the Super NES code. it runs from cartidge with the 
;SFX off. It copies the Main loop and VBlank code to RAM, and then jumps to the main loop.
Main:
        ;CLEAR SFX ram
       ; memset       $700000, $2000, $0     
        ;Copy SNES code
        memcpy  __MAIN_LOOP_RUN__, __MAIN_LOOP_LOAD__, __MAIN_LOOP_SIZE__
        memcpy  __VBLANK_RUN__, __VBLANK_LOAD__, __VBLANK_SIZE__
        
        ;Copy Palette
        CGRAM_memcpy 0, Palette, sizeof_Palette
        ;Copy SuperFX tileMap
	VRAM_memcpy VRAM_tilemap, Map, Map_end - Map
        
        stz z:pos_y

        
        ;Configure GSU
        ;initGSU_4bpp_obj 
        initGSU_4bpp_160
        
        ;Start running snes cpu from work ram
        jml __MAIN_LOOP_RUN__

.SEGMENT "MAIN_LOOP"
Main2:
        ;Set up screen mode
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
        lda     #bgsc(VRAM_tilemap, SC_SIZE_32X32)	;position of map and tiles for images
        sta     BG1SC
        
        ldx     #bg12nba(VRAM_screen_1, 0)
        stx     BG12NBA
        
        lda     #tm(ON, OFF, OFF, OFF, OFF)	;screen buffer use
        sta     TM

        

        ;initialize screen buffer indexes
        stz z:VRAM_screen_select
        stz z:SFX_buffer_position

        ;Set letterbox irq Interrupt
        ;IRQ_V_set 199, Vblank
        ;IRQ_V_on
        
        ;Turn on screen
        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        

        lda #$0
        sub #$20
        sta BG1VOFS
        sta BG1VOFS
        lda #$0
        sta BG1HOFS
        sta BG1HOFS
        
        ;setup super fx vram buffer positions
        stz z:SFX_buffer_position ;sfx reads from start of work ram
        stz z:VRAM_screen_select ; write to the other screen
        
        VBL_set Vblank
        VBL_on
        gsuOn

;infinite loop
infinite_loop:       
   
   gsuRunning
   beq gsu_is_idle
   bra     infinite_loop

gsu_is_idle:
    ; Code to handle the case where the Super FX is NOT running
    ; (e.g., preparing a new program or waiting for activation)
    ldx #1
    stx FRAME_READY
    
    bra     infinite_loop


Vblank:
        

        RW_forced a8i8
        lda #$80 ;make the databank correct for MMIO
        pha
        plb

        
        ;;Scroll POC
        ;lda $213F       
        ;lda z:pos_y
        ;sub #1
        ;sta z:pos_y        
        ;sta BG1VOFS
        ;stz BG1VOFS


        ;prepare for dma to vram
        ;display off

transfer:
        ;screen off
        lda #inidisp(OFF, DISP_BRIGHTNESS_MAX)
        sta INIDISP


        ;update v offset
        ;lda $213F
        ;sta BG1VOFS
        ;stz BG1VOFS
        lda #$0
        ;sta BG1HOFS
        ;sta BG1HOFS
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
                ldx     #bg12nba(VRAM_screen_2, 0)
                stx     BG12NBA
                stz FRAME_READY
                gsuOn
                endVBlank
        :;copyFromStart:        
                VRAM_memcpy VRAM_screen_2, screenbuffer, screenbuffer_len
                lda #$01;sfx reads from middle of work ram
                sta z:SFX_buffer_position        
                stz FRAME_READY
                gsuOn
                endVBlank
drawScreen1:        
                ;Where do we copy from?
                lda z:SFX_buffer_position
                bne copyFromHalf
                jmp copyFromStart
        copyFromHalf:
                VRAM_memcpy (VRAM_screen_1 + screenbuffer_len), (screenbuffer ), screenbuffer_len
                stz z:SFX_buffer_position ;sfx reads from start of work ram
                lda #$01
                sta z:VRAM_screen_select ; write to the other screen
                ldx #bg12nba(VRAM_screen_1, 0)
                stx BG12NBA
                stz FRAME_READY
                gsuOn
                endVBlank
        copyFromStart:        
                VRAM_memcpy VRAM_screen_1, screenbuffer, screenbuffer_len
                lda #$01 ;sfx reads from middle of work ram
                sta z:SFX_buffer_position
                stz FRAME_READY
                gsuOn
                endVBlank
.segment "RODATA"
.include "backgroundMap.s"


.segment "ZEROPAGE"
pos_y: .res 1

VRAM_screen_select: .res 1    ; which VRAM address should be selected, see SFX_VRAM in todo.pointers
                                ; This is where SFX buffers are copied to.
                                ; 0 = screen 1
                                ; 1 = screen 2
SFX_buffer_position: .res 1   ; Where to begin DMA from in work ram; 
                                ; 0 = $700400
                                ; 1 = $702900

FRAME_READY: .res 1
.segment "RODATA"
   incbin  Palette,        "Data/superfx.palette.bin"
