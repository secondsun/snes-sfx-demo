; SuperFX
; Summers Pittman <secondsun@gmail.com>
; 16-bit 0.16-fixed point reciprocol
; reciprocol

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


; In : R0 fixed88 the value to return the reciprocol of
; Out : R3 a fixe88 reciprocol
function reciprocol
    .define dividend r1
	.define divisor r2
	.define remainder r3
	.define quotient r0

	iwt dividend, #$1
	move divisor, r0
	iwt r12, #$10; loop 16 times 
	move remainder, dividend; 
	iwt quotient, #0 ; r0 =  () 
	

	iwt	r13, #divide_loop
	
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
		move r3, r0
	return 
endfunction


.endif