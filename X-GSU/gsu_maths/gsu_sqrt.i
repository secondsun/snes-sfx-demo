

; SuperFX
; Summers Pittman <secondsun@gmail.com>
; 16-bit square root0 algorithm ported from http://6502org.wikidot.com/software-math-sqrt
; Sqrt816GS1
.ifndef ::__GSU_SQRT_DEFINED__
::__GSU_SQRT_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"

; In : 16bit int on r0
; Out : Sqrt on R3 of Input in fixed88
function gsu_sqrt
	;square_root0 (n):
	;  dividend0 = n
	;  root0 = 0
	;  LOOP 8 TIMES
	;    dividend0 <<= 2
	;    NOTE: discard the lower 16 bits to produce the partial dividend0
	;    partial_dividend0 = dividend0 >> 16
	;    divisor0 = (4 * root0 + 1) * 1
	;    IF partial_dividend0 >= divisor0 
	;      partial_dividend0 -= divisor0
	;      root0 = root0 * 2 + 1
	;    ELSE
	;      root0 = root0 * 2

	;  remainder0 = partial_dividend0
	;  RETURN (root0, remainder0)
	move r1, r0
	.define dividend0 r1
	.define partial_dividend0 r2
	.define root0 r3
	.define divisor0 r0
	.define remainder0 r5

	
	iwt partial_dividend0, #$0 ; 
	iwt r12, #$F ; loop 12 times 
	iwt root0, #0 ; r3 =  ()  [should end up 238/EE]
	iwt divisor0, #0 ; r0 =  () 
	iwt remainder0, #0 ; () 	[should end up 79/4F]

	iwt	r13, #square_root0_loop

	square_root0_loop:
	;shift dividend0(r1) right 2 and put overflow into partial_dividend0(r2)
		with dividend0
		add dividend0
		with partial_dividend0 
		rol

		with dividend0
		add dividend0
		with partial_dividend0
		rol

	;divisor0 = 4*root0+1
		from root0
		add root0 ; r0 = 2*root0
		add divisor0; r0 = 4*root0
		add #$1 ; divisor0 = $*root0+1
	; cmp divisor0 < partial_dividend0
		cmp partial_dividend0; r0-r2
		bmi sqrtElse;
		nop
		beq sqrtElse;
		nop
	;      root0 = root0 * 2
		with root0
		add root0 ; root0 = 2*root0
		bra lp
		nop
	sqrtElse:
	;      partial_dividend0 -= divisor0
	;      root0 = root0 * 2 + 1
		with partial_dividend0
		sub divisor0
		with root0
		add root0
		with root0
		add #$1 	
		
	lp:
	move remainder0,partial_dividend0
	loop
	nop
	move r3,r0
	return
endfunction

.endif