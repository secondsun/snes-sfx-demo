

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
	
	 register dividend =r1
	 register dividendhi= r5
	 register partial_dividend =r4
	 register root =r3
	 register divisor =r0

	move dividendhi, r0

	iwt partial_dividend, #$0 ; 
	iwt r12, #$F ; loop 16 times 
	iwt root, #0 ; r3 =  ()  [should end up 238/EE]
	iwt divisor, #0 ; r0 =  () 
	

	iwt	r13, #square_root_loop
	with dividend
	square_root_loop:
	;shift dividend0(r1) right 2 and put overflow into partial_dividend0(r2)
		
		add dividend
		with	dividendhi
		rol
		with partial_dividend
		rol

		with dividend
		add dividend
		with	dividendhi
		rol
		with partial_dividend
		rol

	;divisor0 = 4*root0+1
		from root
		add root ; r0 = 2*root0
		add divisor; r0 = 4*root0
		add #$1 ; divisor0 = $*root0+1
	; cmp divisor0 < partial_dividend0
		cmp partial_dividend; r0-r2
		bmi sqrtElse;
		nop
		beq sqrtElse;
		nop
	;      root0 = root0 * 2
		with root
		add root ; root0 = 2*root0
		bra lp
		nop
	sqrtElse:
	;      partial_dividend0 -= divisor0
	;      root0 = root0 * 2 + 1
		with partial_dividend
		sub divisor
		with root
		add root
		with root
		add #$1 	
		
	lp:
	loop
	with dividend
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
	 dividend = r1
	 partial_dividend = r2
	 root = r3
	 divisor = r0
	 remainder = r5

	
	iwt partial_dividend, #$0 ; 
	iwt r12, #$F ; loop $13 times
	iwt root, #0 ; r3 =  () 
	iwt divisor, #0 ; r0 =  () 
	iwt remainder, #0 ; () 

	iwt	r13, #square_root_loop

	square_root_loop:
	;shift dividend0(r1) right 2 and put overflow into partial_dividend0(r2)
		with dividend
		add dividend
		with partial_dividend
		rol

		with dividend
		add dividend
		with partial_dividend
		rol

	;divisor0 = 4*root0+1
		from root
		add root ; r0 = 2*root0
		add divisor; r0 = 4*root0
		add #$1 ; divisor0 = $*root0+1
	; cmp divisor0 < partial_dividend0
		cmp partial_dividend; r0-r2
		bmi sqrtElse;
		nop
		beq sqrtElse;
		nop
	;      root0 = root0 * 2
		with root
		add root ; root0 = 2*root0
		bra lp
		nop
	sqrtElse:
	;      partial_dividend0 -= divisor0
	;      root0 = root0 * 2 + 1
		with partial_dividend
		sub divisor
		with root
		add root
		with root
		add #$1 	
		
	lp:
	move remainder,partial_dividend
	loop
	nop
	move r3,r0
	return
endfunction

.endif