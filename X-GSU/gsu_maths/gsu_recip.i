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
    register  dividend1 = r1
	register  divisor1 = r2
	register  remainder1 = r3
	register  quotient1 = r0

	iwt dividend1, #$1
	move divisor1, r0
	iwt r12, #$18; loop 24 times 
	move remainder1, dividend1;0
	iwt quotient1, #0 ; r0 =  () 
	

	iwt	r13, #divide_loop1
	
	divide_loop1:
		with remainder1
		add remainder1
		
		from remainder1
		cmp divisor1
		bmi lp1
		add quotient1
		add 1 ;quotient++
		with remainder1
		sub divisor1
	lp1: 	
		loop
		nop
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


.endif