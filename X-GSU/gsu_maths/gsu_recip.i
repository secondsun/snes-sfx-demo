; SuperFX
; Summers Pittman <secondsun@gmail.com>
; 16-bit 0.16-fixed point reciprocal
; reciprocal

	; pseudocode
	;   int dividend = 1;
    ;    int quotient = 0;
    ;    int remainder = dividend;
    ;    for (int x = 0; x < 8; x++) {
    ;        remainder = (remainder << 1);
    ;        if (divisor <= remainder) {
    ;            quotient =  (quotient<<1);
    ;            quotient++;
    ;            remainder -=divisor;
    ;        } else {
    ;            quotient =  (quotient<<1);
    ;        }
    ;    }

.ifndef ::__GSU_RECIP_DEFINED__
::__GSU_RECIP_DEFINED__ = 1   


.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"


; In : R0 fixed88 the value to return the reciprocal of
; Out : R3 a fixed016 reciprocal
function reciprocal016
    register dividend = r1
	register divisor  = r2
	register remainder = r3
	register quotient  = r0

	
	iwt dividend, #$1
	move divisor, r0
	move remainder, dividend; 
	iwt quotient, #0 ; r0 =  () 
	
	iwt r12, #$18; loop 24 times 
	iwt	r13, #divide_loop
	
	gsu_stack_push divisor
	with divisor
	add #$0
	bpl divide_loop
		nop
		with divisor 
		not
		with divisor 
		add #$1

	divide_loop:
		with remainder
		add remainder
		
		from remainder 
		cmp divisor
		bmi lp
		add quotient
		add 1 ;quotient++
		with remainder
		sub divisor
	lp: 	
		loop
		nop
		gsu_stack_pop divisor
		with divisor
		add #0
		bmi negate
		    nop
			move r3, r0
			return
		negate:
			not
			add #$1
			move r3, r0
			return 
endfunction


; In : R0 fixed88 the value to return the reciprocal of
; Out : R3 a fixed88 reciprocal
function reciprocal
    register dividend = r1
	register divisor  = r2
	register remainder = r3
	register quotient  = r0

	
	iwt dividend, #$1
	move divisor, r0
	move remainder, dividend; 
	iwt quotient, #0 ; r0 =  () 
	
	iwt r12, #$10; loop 16 times 
	iwt	r13, #divide_loop
	
	gsu_stack_push divisor
	with divisor
	add #$0
	bpl divide_loop
		nop
		with divisor 
		not
		with divisor 
		add #$1

	divide_loop:
		with remainder
		add remainder
		
		from remainder 
		cmp divisor
		bmi lp
		add quotient
		add 1 ;quotient++
		with remainder
		sub divisor
	lp: 	
		loop
		nop
		gsu_stack_pop divisor
		with divisor
		add #0
		bmi negate
		    nop
			move r3, r0
			return
		negate:
			not
			add #$1
			move r3, r0
			return 
endfunction

; for arg = rester containing int (0 - 255) store 1/arg in q0.16 
; format in register dest
; dest may equal arg, they will not clash
;clobbers r14 and dest. arg unchanged
.macro reciprocal_lookup_rom arg, dest

	 .ifblank(arg)
        .error "reciprocal_lookup: argument is required"
    .endif
	
 .ifblank(dest)
        .error "reciprocal_lookup: destination is required"
    .endif

	ibt r14,#$3
	from r14
    romb

		iwt r14, #reciprocal_table
		with r14
		add arg
		with r14
		add arg
		
		to dest
		getbl
		with r14
		add #1
		with dest
		getbh
.endmacro

; Reciprocal Lookup Table (0-255)
; Format: Unsigned Q0.16 fixed-point
; Result = round(65536 / x)

reciprocal_table:
.word $0000 ; (1/0)
.word $FFFF ; (1/1)
.word $8000 ; (1/2)
.word $5555 ; (1/3)
.word $4000 ; (1/4)
.word $3333 ; (1/5)
.word $2AAB ; (1/6)
.word $2492 ; (1/7)
.word $2000 ; (1/8)
.word $1C72 ; (1/9)
.word $199A ; (1/10)
.word $1746 ; (1/11)
.word $1555 ; (1/12)
.word $13B1 ; (1/13)
.word $1249 ; (1/14)
.word $1111 ; (1/15)
.word $1000 ; (1/16)
.word $0F0F ; (1/17)
.word $0E39 ; (1/18)
.word $0D79 ; (1/19)
.word $0CCD ; (1/20)
.word $0C31 ; (1/21)
.word $0BA3 ; (1/22)
.word $0B21 ; (1/23)
.word $0AAB ; (1/24)
.word $0A3D ; (1/25)
.word $09D9 ; (1/26)
.word $097B ; (1/27)
.word $0925 ; (1/28)
.word $08D4 ; (1/29)
.word $0889 ; (1/30)
.word $0842 ; (1/31)
.word $0800 ; (1/32)
.word $07C2 ; (1/33)
.word $0788 ; (1/34)
.word $0750 ; (1/35)
.word $071C ; (1/36)
.word $06EB ; (1/37)
.word $06BD ; (1/38)
.word $0690 ; (1/39)
.word $0666 ; (1/40)
.word $063E ; (1/41)
.word $0618 ; (1/42)
.word $05F4 ; (1/43)
.word $05D1 ; (1/44)
.word $05B0 ; (1/45)
.word $0591 ; (1/46)
.word $0572 ; (1/47)
.word $0555 ; (1/48)
.word $0539 ; (1/49)
.word $051F ; (1/50)
.word $0505 ; (1/51)
.word $04EC ; (1/52)
.word $04D5 ; (1/53)
.word $04BE ; (1/54)
.word $04A8 ; (1/55)
.word $0492 ; (1/56)
.word $047E ; (1/57)
.word $046A ; (1/58)
.word $0457 ; (1/59)
.word $0444 ; (1/60)
.word $0432 ; (1/61)
.word $0421 ; (1/62)
.word $0410 ; (1/63)
.word $0400 ; (1/64)
.word $03F0 ; (1/65)
.word $03E1 ; (1/66)
.word $03D2 ; (1/67)
.word $03C4 ; (1/68)
.word $03B6 ; (1/69)
.word $03A8 ; (1/70)
.word $039B ; (1/71)
.word $038E ; (1/72)
.word $0382 ; (1/73)
.word $0376 ; (1/74)
.word $036A ; (1/75)
.word $035E ; (1/76)
.word $0353 ; (1/77)
.word $0348 ; (1/78)
.word $033E ; (1/79)
.word $0333 ; (1/80)
.word $0329 ; (1/81)
.word $031F ; (1/82)
.word $0316 ; (1/83)
.word $030C ; (1/84)
.word $0303 ; (1/85)
.word $02FA ; (1/86)
.word $02F1 ; (1/87)
.word $02E9 ; (1/88)
.word $02E0 ; (1/89)
.word $02D8 ; (1/90)
.word $02D0 ; (1/91)
.word $02C8 ; (1/92)
.word $02C1 ; (1/93)
.word $02B9 ; (1/94)
.word $02B2 ; (1/95)
.word $02AB ; (1/96)
.word $02A4 ; (1/97)
.word $029D ; (1/98)
.word $0296 ; (1/99)
.word $028F ; (1/100)
.word $0289 ; (1/101)
.word $0283 ; (1/102)
.word $027C ; (1/103)
.word $0276 ; (1/104)
.word $0270 ; (1/105)
.word $026A ; (1/106)
.word $0264 ; (1/107)
.word $025F ; (1/108)
.word $0259 ; (1/109)
.word $0254 ; (1/110)
.word $024E ; (1/111)
.word $0249 ; (1/112)
.word $0244 ; (1/113)
.word $023F ; (1/114)
.word $023A ; (1/115)
.word $0235 ; (1/116)
.word $0230 ; (1/117)
.word $022B ; (1/118)
.word $0227 ; (1/119)
.word $0222 ; (1/120)
.word $021E ; (1/121)
.word $0219 ; (1/122)
.word $0215 ; (1/123)
.word $0211 ; (1/124)
.word $020C ; (1/125)
.word $0208 ; (1/126)
.word $0204 ; (1/127)
.word $0200 ; (1/128)
.word $01FC ; (1/129)
.word $01F8 ; (1/130)
.word $01F4 ; (1/131)
.word $01F0 ; (1/132)
.word $01ED ; (1/133)
.word $01E9 ; (1/134)
.word $01E5 ; (1/135)
.word $01E2 ; (1/136)
.word $01DE ; (1/137)
.word $01DB ; (1/138)
.word $01D7 ; (1/139)
.word $01D4 ; (1/140)
.word $01D1 ; (1/141)
.word $01CE ; (1/142)
.word $01CA ; (1/143)
.word $01C7 ; (1/144)
.word $01C4 ; (1/145)
.word $01C1 ; (1/146)
.word $01BE ; (1/147)
.word $01BB ; (1/148)
.word $01B8 ; (1/149)
.word $01B5 ; (1/150)
.word $01B2 ; (1/151)
.word $01AF ; (1/152)
.word $01AC ; (1/153)
.word $01AA ; (1/154)
.word $01A7 ; (1/155)
.word $01A4 ; (1/156)
.word $01A1 ; (1/157)
.word $019F ; (1/158)
.word $019C ; (1/159)
.word $019A ; (1/160)
.word $0197 ; (1/161)
.word $0195 ; (1/162)
.word $0192 ; (1/163)
.word $0190 ; (1/164)
.word $018D ; (1/165)
.word $018B ; (1/166)
.word $0188 ; (1/167)
.word $0186 ; (1/168)
.word $0184 ; (1/169)
.word $0182 ; (1/170)
.word $017F ; (1/171)
.word $017D ; (1/172)
.word $017B ; (1/173)
.word $0179 ; (1/174)
.word $0176 ; (1/175)
.word $0174 ; (1/176)
.word $0172 ; (1/177)
.word $0170 ; (1/178)
.word $016E ; (1/179)
.word $016C ; (1/180)
.word $016A ; (1/181)
.word $0168 ; (1/182)
.word $0166 ; (1/183)
.word $0164 ; (1/184)
.word $0162 ; (1/185)
.word $0160 ; (1/186)
.word $015E ; (1/187)
.word $015D ; (1/188)
.word $015B ; (1/189)
.word $0159 ; (1/190)
.word $0157 ; (1/191)
.word $0155 ; (1/192)
.word $0154 ; (1/193)
.word $0152 ; (1/194)
.word $0150 ; (1/195)
.word $014E ; (1/196)
.word $014D ; (1/197)
.word $014B ; (1/198)
.word $0149 ; (1/199)
.word $0148 ; (1/200)
.word $0146 ; (1/201)
.word $0144 ; (1/202)
.word $0143 ; (1/203)
.word $0141 ; (1/204)
.word $0140 ; (1/205)
.word $013E ; (1/206)
.word $013D ; (1/207)
.word $013B ; (1/208)
.word $013A ; (1/209)
.word $0138 ; (1/210)
.word $0137 ; (1/211)
.word $0135 ; (1/212)
.word $0134 ; (1/213)
.word $0132 ; (1/214)
.word $0131 ; (1/215)
.word $012F ; (1/216)
.word $012E ; (1/217)
.word $012D ; (1/218)
.word $012B ; (1/219)
.word $012A ; (1/220)
.word $0129 ; (1/221)
.word $0127 ; (1/222)
.word $0126 ; (1/223)
.word $0125 ; (1/224)
.word $0123 ; (1/225)
.word $0122 ; (1/226)
.word $0121 ; (1/227)
.word $011F ; (1/228)
.word $011E ; (1/229)
.word $011D ; (1/230)
.word $011C ; (1/231)
.word $011A ; (1/232)
.word $0119 ; (1/233)
.word $0118 ; (1/234)
.word $0117 ; (1/235)
.word $0116 ; (1/236)
.word $0115 ; (1/237)
.word $0113 ; (1/238)
.word $0112 ; (1/239)
.word $0111 ; (1/240)
.word $0110 ; (1/241)
.word $010F ; (1/242)
.word $010E ; (1/243)
.word $010D ; (1/244)
.word $010B ; (1/245)
.word $010A ; (1/246)
.word $0109 ; (1/247)
.word $0108 ; (1/248)
.word $0107 ; (1/249)
.word $0106 ; (1/250)
.word $0105 ; (1/251)
.word $0104 ; (1/252)
.word $0103 ; (1/253)
.word $0102 ; (1/254)
.word $0101 ; (1/255)
		


.endif