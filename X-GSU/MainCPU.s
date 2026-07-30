; Main CPU
; Molive <Moliveofscratch@gmail.com>
;
; SNES-NICCC-FX

.include "libSFX.i"
.include "SuperFX.pointers"

.macro correct_databank
	lda #$7e ;make the databank correct for data interpretation
	pha
	plb
.endmacro

Main:
		break
        ;Copy GSU code
        memcpy GSU_SRAM, __GSUCODE_LOAD__, __GSUCODE_SIZE__

		;Copy music data, and start playing on loop
		SMP_playspc SPC_state, SPC_image_lo, SPC_image_hi
		
		;memcpy frame_data, test_data, sizeof_test_data
		
		lda		#$54
		sta		z:variable_mvn
		lda		#$7E
		sta		z:variable_mvn + 1
		lda		#$00
		sta		z:variable_mvn + 2
		lda		#$6B
		sta		z:variable_mvn + 3
		
		lda		#$01
		sta		$70FFFF
		
		HDMA_set_absolute 1, 0, INIDISP, Force_HDMA
		
		;lda #1
		;sta HDMAEN
		
        ;Configure GSU
        lda     #$70
        sta     GSU_PBR
        lda     #$1
        sta     GSU_SCBR
        lda     #%00101101
        sta     GSU_SCMR
        lda     #%10000000
        sta     GSU_CFGR
        lda     #$01
        sta     GSU_CLSR

		stz z:copy_type
		stz z:buffer_pos
		stz z:sfx_pos
		
		;RW a16
		;lda #$c8
		;sta pos_x
		;lda #70
		;sta pos_y
		
		;lda #.loword(frame_data)
		;sta GSU_R10

        ;Start GSU
        break
        ;lda    #.loword(GSU_SRAM)
        ;sta     GSU_R15
		
		RW a8
        ;Turn on screen
        lda #15
:		pha
		CGRAM_setcolor_rgb a, 0, 0, 0
		pla
		dec
		bne :-
		CGRAM_setcolor_rgb a, 0, 0, 0

		jsr show_intro

		RW a16
		lda #0
		sub #10
		RW a8
		sta BG1VOFS
		xba
		sta BG1VOFS
		
		VRAM_memcpy VRAM_MAP_LOC, Map, Map_end - Map
		
		;Set up screen mode
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
		lda     #bgsc(VRAM_MAP_LOC, SC_SIZE_32X32)	;position of map and tiles for images
        sta     BG1SC
        sta     BG2SC
        ldx     #bg12nba(VRAM_buffer_1, VRAM_buffer_2)
        stx     BG12NBA
        lda     #tm(ON, OFF, OFF, OFF, OFF)	;screen buffer use
        sta     TM

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
		VBL_set Vblank
        VBL_on
		
		stz z:databank_base
		stz z:databank_base + 1
		lda #$c2
		sta z:databank_base + 2
		RW_forced a8i16
		ldy #0
frame:	break
		ldx #0
		stz z:do_next_frame
		stz z:buffer_filled
		correct_databank
		
loooop: RW a16
		lda #0
		RW_forced a8i16
		;break
		lda [databank_base],y
		iny
		
		ror a
		pha
		bcc :+
		lda #1
		sta data_buffer, x
		inx
:
		lda #0
		sta data_buffer, x
		inx
		pla
		ror a
		bcc :+
		jsr load_palette
:		ror a
		bcc :+
		jmp depack_indexed
		bra loooop
:		jmp depack_immediate
		bra loooop
		
next_bank:
		ldy #0
		inc z:databank_base + 2

end:
		RW_forced a8i16
		lda #1
		sta z:buffer_filled
		break
:		lda z:do_next_frame
		beq :-
		bra frame
		
finish_stream:
		RW a8
		lda #1
		sta z:buffer_filled
		bra finish_stream
		
		
load_palette:
		;break
		php
        RW_forced a16i16
        pha
        phb
        phd
        phx		
		
		ldx #$ffff
		lda [databank_base],y
		xba
		iny
		iny
:		inx
		asl a
		bcc :-
		
		pha
		phx
		lda [databank_base],y
		xba
		iny
		iny
		tax
		and #%00000111
		xba
		.repeat 4
		asl a
		.endrepeat
		sta z:ZPAD
		txa
		and #%01110000
		.repeat 3
		asl a
		.endrepeat
		sta z:ZPAD + 2
		txa
		and #%011100000000
		xba
		.repeat 2
		asl a
		.endrepeat
		ora z:ZPAD
		ora z:ZPAD + 2
		tax
		;break

		pla
		pha
		asl a
		
		RW a16i16
		phx
		tax
		pla
		sta col_buf, x
		lda #0
		;RW a8i16
		
		plx
		pla
		
		cmp #0
		bne :-
		jmp exittt
		
		
exittt:		
        RW a16i16
        plx
        pld
        plb
        pla
        plp
		;break
		rts
		
depack_immediate:
		;break
		RW_forced a8i16
		lda [databank_base],y
		cmp #$ff
		bne :+
		iny
		sta data_buffer, x
		jmp end
:		cmp #$fe
		bne :+
		lda #$ff
		sta data_buffer, x
		jmp next_bank
:		cmp #$fd
		bne :+
		lda #$ff
		sta data_buffer, x
		jmp finish_stream
:		
		iny
		pha
		and #$f0
		lsr a
		lsr a
		lsr a
		lsr a
		sta data_buffer, x
		inx
		
		pla
		and #$0f
		sta data_buffer, x
		inx
		
		phx
		;phy
		
		pha
		lda z:databank_base + 2
		sta z:variable_mvn + 2
		pla
		
		asl a
		pha
		dec a
		RW_forced a16i16
		and #$00FF
		
		phy
		pha
		;RW a16
		txa
		add #.loword(data_buffer)
		tay
		;lda #0
		;RW a8
		pla
		plx
		
		phb
		jsl variable_mvn
		plb
		
		lda #0
		RW a8
		pla
		RW a16
		txy
		plx
		phy
		
		stx z:ZPAD
		add z:ZPAD
		tay
		RW a8
		
		lda data_buffer, x
		phx
		tyx
		sta data_buffer, x
		plx
		inx
		iny
		lda data_buffer, x
		tyx
		sta data_buffer, x
		inx
		
		ply
		RW a16
		and #$00FF
		
		jmp depack_immediate
		
depack_indexed:
		RW_forced a8i16
		
		phx
		lda [databank_base],y
		iny

		pha		
		lda z:databank_base + 2
		sta z:variable_mvn + 2
		pla
		
		tyx
		ldy #.loword(vertex_buffer)
		
		RW a16i16
		and #$00FF		
		asl a
		dec a
		
		phb
		jsl variable_mvn
		plb

		txy
		plx

		;break
		lda #0
		RW a8i16
next_polygon:		
		lda [databank_base],y
		cmp #$ff
		bne :+
		;break
		iny
		sta data_buffer, x
		jmp end
:		cmp #$fe
		bne :+
		lda #$ff
		sta data_buffer, x
		jmp next_bank
:		cmp #$fd
		bne :+
		lda #$ff
		sta data_buffer, x
		jmp finish_stream
:
		
		iny
		pha
		and #$f0
		lsr a
		lsr a
		lsr a
		lsr a
		sta data_buffer, x
		inx
		
		pla
		and #$0f
		sta data_buffer, x
		inx
		
		phx
		pha
		
:		pha
		
		lda [databank_base],y
		iny
		phy
		RW a16
		and #$ff
		asl a
		tay
		RW a8
		lda vertex_buffer,y
		sta data_buffer, x
		iny
		inx
		lda vertex_buffer,y
		sta data_buffer, x
		inx
		ply
		pla
		dea
		bne :-
		
		pla
		plx
		RW a16
		and #$ff
		asl a
		stx z:ZPAD
		add z:ZPAD
		phy
		tay
		RW a8
		
		lda data_buffer, x
		phx
		tyx
		sta data_buffer, x
		plx
		inx
		iny
		lda data_buffer, x
		tyx
		sta data_buffer, x
		inx
		
		ply
		;break
		jmp next_polygon
		
Vblank:
		RW_forced a8i8
		lda #$80 ;make the databank correct for MMIO
		pha
		plb
		;lda #1
		;sta HDMAEN
		;CGRAM_setcolor_rgb 0, 15,7,15
		lda GSU_SFR
		and #%00100000
		bne @GSU_running
		lda z:copy_type
		bne :+
		jsr copy_first_frame
		lda #1
		sta z:copy_type
		rtl
:		lda z:buffer_filled
		beq @lag
		jsr copy_second_frame
		stz z:copy_type
		jsr update_ppu
		jsr restart_gsu
		rtl
		
@GSU_running:
		lda z:buffer_pos ;If we're trying to display a frame that isn't finished, declare a lag frame
		cmp z:sfx_pos
		bne @nolag
@lag:
		;CGRAM_setcolor_rgb 0, 15,0,15
		rtl
		
@nolag:	lda     #%00100001 ;Pause the SFX
        sta     GSU_SCMR
		
		lda z:copy_type
		bne :+
		jsr copy_first_frame
		lda #1
		sta z:copy_type
		lda     #%00101001 ;Resume the SFX
        sta     GSU_SCMR
		rtl
:		jsr copy_second_frame
		jsr schedule_restart_gsu
		lda     #%00101001 ;Resume the SFX
        sta     GSU_SCMR
		jsr update_ppu
		stz z:copy_type
		rtl

update_ppu:
		ldx     #bg12nba(VRAM_buffer_2, VRAM_buffer_1)
		lda z:buffer_pos
		eor #1
		sta z:buffer_pos
		beq :+
		ldx     #bg12nba(VRAM_buffer_1, VRAM_buffer_2)
:		stx     BG12NBA
		rts
		
		
copy_first_frame:
		lda #inidisp(OFF, DISP_BRIGHTNESS_MAX)
		sta INIDISP
		lda z:buffer_pos
		bne :+
		VRAM_memcpy VRAM_buffer_1, screenbuffer1, first_copy_len
		lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
		sta INIDISP
		rts
: 		VRAM_memcpy VRAM_buffer_2, screenbuffer2, first_copy_len
		lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
		sta INIDISP
		rts
		
copy_second_frame:
		lda #inidisp(OFF, DISP_BRIGHTNESS_MAX)
		sta INIDISP
		CGRAM_memcpy 0, col_buf, 32
		lda z:buffer_pos
		bne :+
		VRAM_memcpy (VRAM_buffer_1 + first_copy_len), (screenbuffer1 + first_copy_len), second_copy_len
		lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
		sta INIDISP
		rts
: 		VRAM_memcpy (VRAM_buffer_2 + first_copy_len), (screenbuffer2 + first_copy_len), second_copy_len
		lda #inidisp(ON, DISP_BRIGHTNESS_MAX)
		sta INIDISP
		rts
		
schedule_restart_gsu:
		;CGRAM_setcolor_rgb 0, 0,7,15
		;throw NotImplementedException
		rts
		
restart_gsu:
		RW_forced a8i8
		lda z:sfx_pos
		eor #1
		sta z:sfx_pos
		
		;lda SFX_joy1cont
		;bne :+
		;rtl
		;RW a16
		;lda SFX_joy1cont
		;and #%0000000100000000	;check the arrows, and move the screen
		;beq :+
		;lda pos_x
		;add #1
		;sta pos_x
		
;:		;lda SFX_joy1cont
		;and #%0000001000000000
		;beq :+
		;lda pos_x
		;sub #1
		;sta pos_x
		
;:		;lda SFX_joy1cont
		;and #%0000010000000000	
		;beq :+
		;lda pos_y
		;add #1
		;sta pos_y
		
;:		;lda SFX_joy1cont
		;and #%0000100000000000
		;beq :+
		;lda pos_y
		;sub #1
		;sta pos_y
		
;:		RW_forced a8i8
		lda f:data_buffer
		beq :+
		lda z:sfx_pos
		sta f:data_buffer + 1
:		
		;DMA the frame data for the next frame.
		RW a8i16
		;break
		lda #.bankbyte(data_buffer)
		ldx #.loword(data_buffer)
		stx WMADDL
		sta WMADDH
		lda #(WMDATA & $00ff)
		sta BBAD7
		lda #.bankbyte(frame_data)
		ldx #.loword(frame_data)
		stx A1T7L
		sta A1B7
		ldx #framedata_len
		stx DAS7L
		lda #%10000000
		sta DMAP7
		sta MDMAEN
		
        lda     #(.loword(screenbuffer1)/$400)
		ldx 	z:sfx_pos
		beq :+
        lda     #(.loword(screenbuffer2)/$400)	
:		sta     GSU_SCBR		
		RW a16
		;break
		lda 	#.loword(frame_data)
		sta 	GSU_R10
		lda     #.loword(GSU_SRAM)
        sta     GSU_R15
		RW a8
		lda #1
		sta z:do_next_frame
		rts

show_intro:
		; list of things we need to do:
		;
		; load the image
		; set up the ppu
		; fade in the image
		; fade out
		; return

		LZ4_decompress intro_tiles, EXRAM, y
		VRAM_memcpy VRAM_buffer_1, EXRAM, y
		LZ4_decompress intro_map, EXRAM, y
		VRAM_memcpy VRAM_MAP_LOC, EXRAM, y
		CGRAM_memcpy 0, intro_palette, sizeof_intro_palette
		
		;Set up screen mode
        lda     #bgmode(BG_MODE_1, BG3_PRIO_NORMAL, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8, BG_SIZE_8X8)
        sta     BGMODE
		lda     #bgsc(VRAM_MAP_LOC, SC_SIZE_32X32)	;position of map and tiles for images
        sta     BG1SC
        ldx     #bg12nba(VRAM_buffer_1, 0)
        stx     BG12NBA
        lda     #tm(ON, OFF, OFF, OFF, OFF)	;screen buffer use
        sta     TM

        lda     #inidisp(ON, DISP_BRIGHTNESS_MAX)
        sta     SFX_inidisp
        VBL_on
		
		WAIT_frames 50*10

		rts
		
Map:
.word $0000, $0001, $0002, $0003, $0004, $0005, $0006, $0007, $0008, $0009, $000a, $000b, $000c, $000d, $000e, $000f, $0100, $0101, $0102, $0103, $0104, $0105, $0106, $0107, $0108, $0109, $010a, $010b, $010c, $010d, $010e, $010f 
.word $0010, $0011, $0012, $0013, $0014, $0015, $0016, $0017, $0018, $0019, $001a, $001b, $001c, $001d, $001e, $001f, $0110, $0111, $0112, $0113, $0114, $0115, $0116, $0117, $0118, $0119, $011a, $011b, $011c, $011d, $011e, $011f 
.word $0020, $0021, $0022, $0023, $0024, $0025, $0026, $0027, $0028, $0029, $002a, $002b, $002c, $002d, $002e, $002f, $0120, $0121, $0122, $0123, $0124, $0125, $0126, $0127, $0128, $0129, $012a, $012b, $012c, $012d, $012e, $012f 
.word $0030, $0031, $0032, $0033, $0034, $0035, $0036, $0037, $0038, $0039, $003a, $003b, $003c, $003d, $003e, $003f, $0130, $0131, $0132, $0133, $0134, $0135, $0136, $0137, $0138, $0139, $013a, $013b, $013c, $013d, $013e, $013f 
.word $0040, $0041, $0042, $0043, $0044, $0045, $0046, $0047, $0048, $0049, $004a, $004b, $004c, $004d, $004e, $004f, $0140, $0141, $0142, $0143, $0144, $0145, $0146, $0147, $0148, $0149, $014a, $014b, $014c, $014d, $014e, $014f 
.word $0050, $0051, $0052, $0053, $0054, $0055, $0056, $0057, $0058, $0059, $005a, $005b, $005c, $005d, $005e, $005f, $0150, $0151, $0152, $0153, $0154, $0155, $0156, $0157, $0158, $0159, $015a, $015b, $015c, $015d, $015e, $015f 
.word $0060, $0061, $0062, $0063, $0064, $0065, $0066, $0067, $0068, $0069, $006a, $006b, $006c, $006d, $006e, $006f, $0160, $0161, $0162, $0163, $0164, $0165, $0166, $0167, $0168, $0169, $016a, $016b, $016c, $016d, $016e, $016f 
.word $0070, $0071, $0072, $0073, $0074, $0075, $0076, $0077, $0078, $0079, $007a, $007b, $007c, $007d, $007e, $007f, $0170, $0171, $0172, $0173, $0174, $0175, $0176, $0177, $0178, $0179, $017a, $017b, $017c, $017d, $017e, $017f 
.word $0080, $0081, $0082, $0083, $0084, $0085, $0086, $0087, $0088, $0089, $008a, $008b, $008c, $008d, $008e, $008f, $0180, $0181, $0182, $0183, $0184, $0185, $0186, $0187, $0188, $0189, $018a, $018b, $018c, $018d, $018e, $018f 
.word $0090, $0091, $0092, $0093, $0094, $0095, $0096, $0097, $0098, $0099, $009a, $009b, $009c, $009d, $009e, $009f, $0190, $0191, $0192, $0193, $0194, $0195, $0196, $0197, $0198, $0199, $019a, $019b, $019c, $019d, $019e, $019f 
.word $00a0, $00a1, $00a2, $00a3, $00a4, $00a5, $00a6, $00a7, $00a8, $00a9, $00aa, $00ab, $00ac, $00ad, $00ae, $00af, $01a0, $01a1, $01a2, $01a3, $01a4, $01a5, $01a6, $01a7, $01a8, $01a9, $01aa, $01ab, $01ac, $01ad, $01ae, $01af 
.word $00b0, $00b1, $00b2, $00b3, $00b4, $00b5, $00b6, $00b7, $00b8, $00b9, $00ba, $00bb, $00bc, $00bd, $00be, $00bf, $01b0, $01b1, $01b2, $01b3, $01b4, $01b5, $01b6, $01b7, $01b8, $01b9, $01ba, $01bb, $01bc, $01bd, $01be, $01bf 
.word $00c0, $00c1, $00c2, $00c3, $00c4, $00c5, $00c6, $00c7, $00c8, $00c9, $00ca, $00cb, $00cc, $00cd, $00ce, $00cf, $01c0, $01c1, $01c2, $01c3, $01c4, $01c5, $01c6, $01c7, $01c8, $01c9, $01ca, $01cb, $01cc, $01cd, $01ce, $01cf 
.word $00d0, $00d1, $00d2, $00d3, $00d4, $00d5, $00d6, $00d7, $00d8, $00d9, $00da, $00db, $00dc, $00dd, $00de, $00df, $01d0, $01d1, $01d2, $01d3, $01d4, $01d5, $01d6, $01d7, $01d8, $01d9, $01da, $01db, $01dc, $01dd, $01de, $01df 
.word $00e0, $00e1, $00e2, $00e3, $00e4, $00e5, $00e6, $00e7, $00e8, $00e9, $00ea, $00eb, $00ec, $00ed, $00ee, $00ef, $01e0, $01e1, $01e2, $01e3, $01e4, $01e5, $01e6, $01e7, $01e8, $01e9, $01ea, $01eb, $01ec, $01ed, $01ee, $01ef 
.word $00f0, $00f1, $00f2, $00f3, $00f4, $00f5, $00f6, $00f7, $00f8, $00f9, $00fa, $00fb, $00fc, $00fd, $00fe, $00ff, $01f0, $01f1, $01f2, $01f3, $01f4, $01f5, $01f6, $01f7, $01f8, $01f9, $01fa, $01fb, $01fc, $01fd, $01fe, $01ff 
.word $0200, $0201, $0202, $0203, $0204, $0205, $0206, $0207, $0208, $0209, $020a, $020b, $020c, $020d, $020e, $020f, $0300, $0301, $0302, $0303, $0304, $0305, $0306, $0307, $0308, $0309, $030a, $030b, $030c, $030d, $030e, $030f 
.word $0210, $0211, $0212, $0213, $0214, $0215, $0216, $0217, $0218, $0219, $021a, $021b, $021c, $021d, $021e, $021f, $0310, $0311, $0312, $0313, $0314, $0315, $0316, $0317, $0318, $0319, $031a, $031b, $031c, $031d, $031e, $031f 
.word $0220, $0221, $0222, $0223, $0224, $0225, $0226, $0227, $0228, $0229, $022a, $022b, $022c, $022d, $022e, $022f, $0320, $0321, $0322, $0323, $0324, $0325, $0326, $0327, $0328, $0329, $032a, $032b, $032c, $032d, $032e, $032f 
.word $0230, $0231, $0232, $0233, $0234, $0235, $0236, $0237, $0238, $0239, $023a, $023b, $023c, $023d, $023e, $023f, $0330, $0331, $0332, $0333, $0334, $0335, $0336, $0337, $0338, $0339, $033a, $033b, $033c, $033d, $033e, $033f 
.word $0240, $0241, $0242, $0243, $0244, $0245, $0246, $0247, $0248, $0249, $024a, $024b, $024c, $024d, $024e, $024f, $0340, $0341, $0342, $0343, $0344, $0345, $0346, $0347, $0348, $0349, $034a, $034b, $034c, $034d, $034e, $034f 
.word $0250, $0251, $0252, $0253, $0254, $0255, $0256, $0257, $0258, $0259, $025a, $025b, $025c, $025d, $025e, $025f, $0350, $0351, $0352, $0353, $0354, $0355, $0356, $0357, $0358, $0359, $035a, $035b, $035c, $035d, $035e, $035f 
.word $0260, $0261, $0262, $0263, $0264, $0265, $0266, $0267, $0268, $0269, $026a, $026b, $026c, $026d, $026e, $026f, $0360, $0361, $0362, $0363, $0364, $0365, $0366, $0367, $0368, $0369, $036a, $036b, $036c, $036d, $036e, $036f 
.word $0270, $0271, $0272, $0273, $0274, $0275, $0276, $0277, $0278, $0279, $027a, $027b, $027c, $027d, $027e, $027f, $0370, $0371, $0372, $0373, $0374, $0375, $0376, $0377, $0378, $0379, $037a, $037b, $037c, $037d, $037e, $037f 
.word $0280, $0281, $0282, $0283, $0284, $0285, $0286, $0287, $0288, $0289, $028a, $028b, $028c, $028d, $028e, $028f, $0380, $0381, $0382, $0383, $0384, $0385, $0386, $0387, $0388, $0389, $038a, $038b, $038c, $038d, $038e, $038f
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
.word $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390, $0390
Map_end:

incbin test_data, "test_data.bin" ;This technically no longer works, because I had to change how the SFX handles rotation of polys. :p

Force_HDMA: ;not used

.byte 10
.byte inidisp(OFF, DISP_BRIGHTNESS_MAX)

.byte 127
.byte inidisp(ON, DISP_BRIGHTNESS_MAX)

.byte 200-127
.byte inidisp(ON, DISP_BRIGHTNESS_MAX)

.byte 01
.byte inidisp(OFF, DISP_BRIGHTNESS_MAX)

.byte 00

.segment "RODATA"
	incbin intro_tiles, "data/intro.png.tiles.lz4"
	incbin intro_map, "data/intro.png.map.lz4"
	incbin intro_palette, "data/intro.png.palette"

.segment "ZEROPAGE"
;	pos_x: .res 2
;	pos_y: .res 2
	copy_type: .res 1 ; 0 for first frame, 1 for second
	buffer_pos: .res 1 ; vram side buffer select
	sfx_pos: .res 1 ; sfx side buffer select
	databank_base: .res 3
	do_next_frame: .res 1
	buffer_filled: .res 1
	
	variable_mvn:
	;mvn #$7e, X
	;rtl
	.res 4

.define spc_file "data/music.spc"
.segment "RODATA"
SPC_state: SPC_incbin_state spc_file
.segment "ROM1_1"
SPC_image_lo: SPC_incbin_lo spc_file
.segment "ROM1_2"
SPC_image_hi: SPC_incbin_hi spc_file
	
.segment "ROM2to12"
	incbin frames, "data/scene1.bin"
	
.segment "LORAM"
	vertex_buffer: .res 512
	col_buf: .res 32

.segment "HIRAM"
	data_buffer: