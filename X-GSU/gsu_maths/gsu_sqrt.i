

; SuperFX
; Summers Pittman <secondsun@gmail.com>
; 16-bit square root0 algorithm ported from http://6502org.wikidot.com/software-math-sqrt
; Sqrt816GS1
.ifndef ::__GSU_SQRT_DEFINED__
::__GSU_SQRT_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"

; In :  int part on r0
; In :  decimals on r1
; Out : Sqrt on R3 of Input in fixed88
function gsu_sqrt32
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
	
	.define dividend0 r1
	.define dividendhi r5
	.define partial_dividend0 r4
	.define root0 r3
	.define divisor0 r0

	move dividendhi, r0

	iwt partial_dividend0, #$0 ; 
	iwt r12, #$F ; loop 16 times 
	iwt root0, #0 ; r3 =  ()  [should end up 238/EE]
	iwt divisor0, #0 ; r0 =  () 
	

	iwt	r13, #square_root0_loop
	with dividend0
	square_root0_loop:
	;shift dividend0(r1) right 2 and put overflow into partial_dividend0(r2)
		
		add dividend0
		with	dividendhi
		rol
		with partial_dividend0 
		rol

		with dividend0
		add dividend0
		with	dividendhi
		rol
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
	loop
	with dividend0
	from r0
	to r3
	sub #1
	return
endfunction

; In : 16 bitint on r0
; Out : Sqrt on R3 of Input in fixed88
function gsu_sqrt_int_in
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
	.define dividend2 r1
	.define partial_dividend2 r2
	.define root2 r3
	.define divisor2 r0
	.define remainder2 r5

	
	iwt partial_dividend2, #$0 ; 
	iwt r12, #$F ; loop $13 times
	iwt root2, #0 ; r3 =  () 
	iwt divisor2, #0 ; r0 =  () 
	iwt remainder2, #0 ; () 

	iwt	r13, #square_root2_loop

	square_root2_loop:
	;shift dividend0(r1) right 2 and put overflow into partial_dividend0(r2)
		with dividend2
		add dividend2
		with partial_dividend2
		rol

		with dividend2
		add dividend2
		with partial_dividend2
		rol

	;divisor0 = 4*root0+1
		from root2
		add root2 ; r0 = 2*root0
		add divisor2; r0 = 4*root0
		add #$1 ; divisor0 = $*root0+1
	; cmp divisor0 < partial_dividend0
		cmp partial_dividend2; r0-r2
		bmi sqrtElse;
		nop
		beq sqrtElse;
		nop
	;      root0 = root0 * 2
		with root2
		add root2 ; root0 = 2*root0
		bra lp
		nop
	sqrtElse:
	;      partial_dividend0 -= divisor0
	;      root0 = root0 * 2 + 1
		with partial_dividend2
		sub divisor2
		with root2
		add root2
		with root2
		add #$1 	
		
	lp:
	move remainder2,partial_dividend2
	loop
	nop
	move r3,r0
	return
endfunction

.endif