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
        CGRAM_memcpy sizeof_Palette, Road_Palette, sizeof_Road_Palette
        ;Copy SuperFX tileMap
	VRAM_memcpy VRAM_tilemap, Map, Map_end - Map
        ;Copy Road tileMap
        VRAM_memcpy VRAM_road_tilemap, Road_TileMap, sizeof_Road_TileMap
        ;Copy Road Tiles
        VRAM_memcpy VRAM_road_tiles, Road_Tiles, sizeof_Road_Tiles

        ; .out (.sprintf("%d",__HDMA_RUN__))
        HDMA_set_absolute 2, 2, $D, HDMA
        HDMA_set_absolute 3, 2, $E, HDMA2

        RW a8
        lda #$3F
        sta $210F
        sta $210F
        
        lda #$70
        sta $210F
        sta $210F

        ;Configure GSU
        initGSU_4bpp_obj 
        phb
        RW a8
        lda #$70
        pha
        plb
        lda #$4;three sprite
        sta a:spritelist::count

;texture .word ; address
;  xLoc .byte
;  yLoc .byte
;  scale .word ; 8.8 fixed point
; setup sprite list



        ldx #.loword(tree)
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::texture
        ldx #$40
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::xLoc
        ldx #$40
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale


        ldx #.loword(tree)
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::texture
        ldx #$40
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::xLoc
        ldx #$60
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale

        ldx #.loword(tree)
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::texture
        ldx #$00
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::xLoc
        ldx #$20
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale

        
        ldx #.loword(tree)
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::texture
        ldx #$40
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::xLoc
        ldx #00
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale

        
        ldx #.loword(tree)
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::texture
        ldx #$00
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::xLoc
        ldx #$00
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::yLoc
        ldx #$0100
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale_r
        ldx #$0100
        stx a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale

        

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
        lda     #bgsc(VRAM_road_tilemap, SC_SIZE_64X32)        ;position of map and tiles for images
        sta     BG2SC
        ldx     #bg12nba(VRAM_screen_1, VRAM_road_tiles)
        stx     BG12NBA
        lda     #tm(ON, ON, OFF, OFF, OFF)	;screen buffer use
        sta     TM

        ;intialize road palette
        

        ;initialize screen buffer indexes
        stz z:VRAM_screen_select
        stz z:SFX_buffer_position

        ;Set letterbox irq Interrupt
        ;IRQ_V_set 199, Vblank
        ;IRQ_V_on
        
        ;Turn on screen
        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp

        ;Setup HDMA for sfx mosaic compression
        lda #$0
        sta $210E
        lda #$0
        sta $210D
        lda #$11
        sta $2106
        
        VBL_set Vblank
        VBL_on
        

;infinite loop
:       wai
      
      
        gsuRunning
        bne :+  
        gsuOn

:        bra     :--

Vblank:
        ;if vblank NMI just skip, we're waiting on the IR
        stz HDMAEN ; disable HDMA
        lda #$0
        sta $210E
        lda #$0
        sta $210D
        lda #$11
        sta $2106
        lda #$0C
        sta HDMAEN
        

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
                ldx     #bg12nba(VRAM_screen_2, VRAM_road_tiles)
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
                sta a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale
                lda f:Scale+2, X
               sta a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale_r
                RW_pull
                plb
               ; gsuOn
                endVBlank
        :;copyFromStart:        
                VRAM_memcpy VRAM_screen_2, screenbuffer, screenbuffer_len
                lda #$01;sfx reads from middle of work ram
                sta z:SFX_buffer_position        
                ;gsuOn
                endVBlank
drawScreen1:        
                ;Where do we copy from?
                lda z:SFX_buffer_position
                bne copyFromHalf
                jmp copyFromStart
        copyFromHalf:
                VRAM_memcpy (VRAM_screen_1 + screenbuffer_len), (screenbuffer ), screenbuffer_len
                lda #$00
                sta z:SFX_buffer_position ;sfx reads from start of work ram
                lda #$01
                sta z:VRAM_screen_select ; write to the other screen
                ldx #bg12nba(VRAM_screen_1, VRAM_road_tiles)
                stx BG12NBA

                phb
                lda #$70
                pha
                plb
                RW_push set:a16i16
                ;update and store counter
                lda z:Scale_index_counter
               ;dec
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
                sta a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale
                lda f:Scale+2, X
               sta a:spritelist::sprites + 0 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 1 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 2 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 3 * .sizeof(sprite) + sprite::scale_r
                sta a:spritelist::sprites + 4 * .sizeof(sprite) + sprite::scale_r
                
                RW_pull
                plb

                ;gsuOn
                endVBlank
        copyFromStart:        
                VRAM_memcpy VRAM_screen_1, screenbuffer, screenbuffer_len
                lda #$01 ;sfx reads from middle of work ram
                sta z:SFX_buffer_position
                ;gsuOn
                endVBlank
.include "Data/hdma.s"                
.segment "RODATA"
.include "objFXMap.s"
incbin  Road_TileMap,   "Data/road.png.map"
incbin  Road_Tiles,   "Data/road.png.tile"


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
   incbin  Road_Palette,   "Data/road.png.pal"
   incbin  Scale,          "Data/scale.bin"
                                    