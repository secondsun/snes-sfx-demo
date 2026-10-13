

; SuperFX
; Summers Pittman <secondsun@gmail.com>
; 16-bit square root0 algorithm ported from https://github.com/chmike/fpsqrt/blob/master/fpsqrt.c
; Sqrt816GS1
.ifndef ::__GSU_SQRT_DEFINED__
::__GSU_SQRT_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/function.i"

; In :  dividendhi = int part
; In :  dividendlo = decimals
; Out : root = Sqrt of Input in q8.8
; Clobbers : r0, r12, r13, allocated registers
function gsu_sqrt32 dividendhi, dividendlo : root
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
	
	register partial_dividend
	register divisor = r0

	iwt partial_dividend, #$0 ; 
	iwt r12, #$10 ; loop 16 times; 
	iwt root, #0 ; [should end up 238/EE]
	iwt divisor, #0 ; r0 = () 
	

	iwt	r13, #square_root_loop
	with dividendlo
	square_root_loop:
	;shift dividend0 right 2 and put overflow into partial_dividend0
		
		rol 
		with dividendhi
		rol

		with partial_dividend
		rol

		with dividendlo
		rol 
		with dividendhi
		rol
		with partial_dividend
		rol

	;divisor0 = 4*root0+1
		from root
		add root ; r0 = 2*root0
		add divisor; r0 = 4*root0
		add #$1 ; divisor0 = 4*root0+1
	; cmp divisor0 < partial_dividend0
		cmp partial_dividend; r0 - partial_dividend
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
	with dividendlo

	
	return root
endfunction

.endif