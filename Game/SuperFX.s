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
        RW a8
        lda #$70
        pha
        plb
        lda #$5;three sprite
        sta a:spritelist::count

;texture .word ; address
;  xLoc .byte
;  yLoc .byte
;  scale .word ; 8.8 fixed point
; setup sprite list



        ldx #.loword(tree)
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::texture
        ldx #$20
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::xLoc
        ldx #$0
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale


        ldx #.loword(tree)
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::texture
        ldx #$00
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::xLoc
        ldx #$10
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale

        ldx #.loword(tree)
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::texture
        ldx #$30
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::xLoc
        ldx #$40
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale

        
        ldx #.loword(banner1)
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::texture
        ldx #$60
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::xLoc
        ldx #$40
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale

        
        ldx #.loword(tree)
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::texture
        ldx #$70
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::xLoc
        ldx #$30
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale

        

        stx z:Scale_index_counter

        plb
        jml __MAIN_LOOP_RUN__

.SEGMENT "MAIN_LOOP"
Main2:
        ;Start GSU
        ;gsuOn

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

                phb
                lda #$70
                pha
                plb
                RW_push set:a16i16
                ;update and store counter
                lda z:Scale_index_counter
                dec
                and #$1F
                sta z:Scale_index_counter
                
                asl a ; shift A left
                asl a ; shift A left
                tax ; move a (offset) to X
                lda f:Scale, X
                sta a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale
                sta a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale
                sta a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale
                sta a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale
                lda f:Scale+2, X
               sta a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale_r
                
                RW_pull
                plb
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

                phb
                lda #$70
                pha
                plb
                RW_push set:a16i16
                ;update and store counter
                lda z:Scale_index_counter
                dec
                and #$1F
                sta z:Scale_index_counter
                
                asl a ; shift A left
                asl a ; shift A left
                tax ; move a (offset) to X
                lda f:Scale, X
                sta a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale
                sta a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale
                sta a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale
                sta a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale
                lda f:Scale+2, X
                sta a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale_r
                
                RW_pull
                plb

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
Scale_index_counter: .res 1 ; scale index counter

.segment "RODATA"
   incbin  Palette,        "Data/superfx.palette.bin"
   incbin  Scale,          "Data/scale.bin"
                                    