; SuperFX
; Summers Pittman <secondsun@gmail.com>
; Vector utility functions
;
.ifndef ::__GSU_VECTOR_DEFINED__
::__GSU_VECTOR_DEFINED__ = 1   

.include "libSFX.i"
.include "../common/stack.i"
.include "../common/var.i"
.include "../common/function.i"
.include "./gsu_sqrt.i"
.include "./gsu_recip.i"

;Returns the Address to a cross vector of the input vectors
; Input : R0 address to vector to cross from
; Input : VECTOR_CROSS_IN address of second vector to cross
; Output : R3,VECTOR_CROSS_OUT  address to vector  result
; Clobbers All
function vector_cross
  
;Vector3.of(
  ;(r0+2)*(VECTOR_CROSS_IN+4)-(r0+4*(VECTOR_CROSS_IN+2)),
  ;(r0+4)*(VECTOR_CROSS_IN)-(r0*(VECTOR_CROSS_IN+4)),
  ;(r0)*(VECTOR_CROSS_IN+2)-(r0+2*(VECTOR_CROSS_IN))
;)
  ;Initialize
  lm r1, (VECTOR_CROSS_IN)

  ;Adjust  R0, VECTOR_CROSS_IN to (r0+2),(VECTOR_CROSS_IN+4)
  add #2
  with r1
  add #4

  ;Begin (r0+2)*(VECTOR_CROSS_IN+4)
  to r5
  ldw (r0) ; r5 = r0.y
  to r6
  ldw (r1) ; r6 = IN.z
  from r5
  to r7
  lmult; r5.r4 = r5*r6 = this.y*other.z
  move r8,r4
  with r7
  swap
  to r3
  merge ; r3  = this.y*other.z at fixed 8.8
  ; End (r0+2)*(VECTOR_CROSS_IN+4)

  ;Adjust  (r0+2),(VECTOR_CROSS_IN+4) to (r0+4),(VECTOR_CROSS_IN+2)
  add #2
  with r1
  sub #2


  ;Begin (r0+4*(VECTOR_CROSS_IN+2))
  to r5
  ldw (r0) ; r5 = r0.z
  to r6
  ldw (r1) ; r6 = IN.y
  from r5
  to r7
  lmult; r5.r4 = r5*r6 = this.z*other.y
  move r8,r4
  with r7
  swap
  to r4
  merge ; r4  = this.z*other.y at fixed 8.8
  ;End (r0+4*(VECTOR_CROSS_IN+2))
  
  ;Begin subtract this.y*other.z - this.z*other.y
  with r3
  sub r4
  ;End subtract this.y*other.z - this.z*other.y
  ;Write out.x
  sm (VECTOR_CROSS_OUT), r3



  ;Adjust  (r0+4),(VECTOR_CROSS_IN+2) to (r0+4),(VECTOR_CROSS_IN)
  with r1
  sub #2

  ;Begin (r0+4)*(VECTOR_CROSS_IN)
  to r5
  ldw (r0) ; r5 = this.z
  to r6
  ldw (r1) ; r6 = other.x
  from r5
  to r7
  lmult; r5.r4 = r5*r6 = this.z*other.x
  with r7
  swap
  move r8,r4
  to r3
  merge ; r3  = this.z*other.x at fixed 8.8
  ; End (r0+4)*(VECTOR_CROSS_IN)

  ;Adjust  (r0+4),(VECTOR_CROSS_IN) to (r0), (VECTOR_CROSS_IN+4)
  sub #4
  with r1
  add #4


  ;Begin ((r0)*(VECTOR_CROSS_IN+4))
  to r5
  ldw (r0) ; r5 =this.x
  to r6
  ldw (r1) ; r6 = other.z
  from r5
  to r7
  lmult; r5.r4 = r5*r6 = this.x*other.z
  with r7
  swap
  move r8,r4
  to r4
  merge ; r4  = this.x*other.z at fixed 8.8
  ;End ((r0)*(VECTOR_CROSS_IN+4))

  ;Begin subtract this.z*other.x - this.x * other.z, 
  with r3
  sub r4
  ;End subtract this.y*other.z - this.z*other.y
  ;Write out.y
  sm (VECTOR_CROSS_OUT+2), r3



  ;Adjust (r0), (VECTOR_CROSS_IN+4) to (r0)*(VECTOR_CROSS_IN+2)
  with r1
  sub #2

  ;Begin (r0)*(VECTOR_CROSS_IN+2)
  to r5
  ldw (r0) ; r5 = this.x
  to r6
  ldw (r1) ; r6 = other.y
  from r5
  to r7
  lmult; r5.r4 = r5*r6 = this.x*other.y
  with r7
  swap
  move r8,r4
  to r3
  merge ; r3  = this.x*other.y at fixed 8.8
  ; End (r0)*(VECTOR_CROSS_IN+2)

  ;Adjust (r0)*(VECTOR_CROSS_IN+2) to (r0+2),(VECTOR_CROSS_IN)
  add #2
  with r1
  sub #2

  ;Begin (r0+2)*(VECTOR_CROSS_IN)
  to r5
  ldw (r0) ; r5 = this.y
  to r6
  ldw (r1) ; r6 = other.x
  from r5
  to r7
  lmult; r5.r4 = r5*r6 = this.y*other.x
  with r7
  swap
  move r8,r4
  to r4
  merge ;r4  = this.y*other.x at fixed 8.8
  ; End (r0+2)*(VECTOR_CROSS_IN)

  ;Begin subtract this.x*other.y - this.y * other.x,
  with r3
  sub r4
  ;End subtract this.x*other.y - this.y*other.x
  ;Write out.y
  sm (VECTOR_CROSS_OUT+4), r3

  iwt r3, #VECTOR_CROSS_OUT
  return
endfunction

;Returns the Address to a sum vector of the input vectors
; Input : R0 address to vector to add from
; Input : VECTOR_ADD_IN address of second vector to add
; Output : R3,VECTOR_ADD_OUT  address to vector 
; Clobbers All
function vector_add
  to r1 
  ldw (r0)
  add #2 ;bump up r0 = in.y
  lm r3, (VECTOR_ADD_IN)
  to r2
  ldw (r3)
  with r3
  add #2
  with r1 
  add r2
  sm (VECTOR_ADD_OUT), r1

  to r1 
  ldw (r0)
  add #2 ;bump up r0 = in.z
  to r2
  ldw (r3)
  with r3
  add #2
  with r1 
  add r2
  sm (VECTOR_ADD_OUT+2), r1

  to r1 
  ldw (r0)
  to r2
  ldw (r3)
  with r1 
  add r2
  sm (VECTOR_ADD_OUT + 4), r1

  iwt r3, #VECTOR_ADD_OUT

  return
endfunction


;Returns the Address to a negated vector of the input vector
; Input : R0 address to vector to negate
; Output : R3,VECTOR_NEGATE_OUT  address to negated vector 
; Clobbers All
function vector_negate
  
  ;r1 = address of vector.x
  move r1,r0
  ldw (r1) ; r0 = vector.x
  with r1 
  add #2 ; r1 = &vector.y
  not
  add #1 ; r0 = negated.x
  
  sm (VECTOR_NEGATE_OUT), R0 ; Write negate.x

  ldw (r1) ; r0 = vector.y
  with r1 
  add #2 ; r1 = &vector.z
  not
  add #1 ; r0 = negated.y
  
  sm (VECTOR_NEGATE_OUT + 2), R0 ; Write negate.y


  ldw (r1) ; r0 = vector.z
  not
  add #1 ; r0 = negated.z
  
  sm (VECTOR_NEGATE_OUT + 4), R0 ; Write negate.z
  iwt R3, #VECTOR_NEGATE_OUT

  return

endfunction

;Returns the Address to a normalize vector of the input vector
; Input : R0 address to vector to subtract from
; Input : VECTOR_SUBTRACT_IN address of vector to subtract
; Output : R3,VECTOR_SUBTRACT_OUT  address to vector 
; Clobbers All
function vector_subtract
  to r1 
  ldw (r0)
  add #2 ;bump up r0 = in.y
  lm r3, (VECTOR_SUBTRACT_IN)
  to r2
  ldw (r3)
  with r3
  add #2
  with r1 
  sub r2
  sm (VECTOR_SUBTRACT_OUT), r1

  to r1 
  ldw (r0)
  add #2 ;bump up r0 = in.z
  to r2
  ldw (r3)
  with r3
  add #2
  with r1 
  sub r2
  sm (VECTOR_SUBTRACT_OUT+2), r1

  to r1 
  ldw (r0)
  to r2
  ldw (r3)
  with r1 
  sub r2
  sm (VECTOR_SUBTRACT_OUT + 4), r1

  iwt r3, #VECTOR_SUBTRACT_OUT

  return
endfunction

;Returns the Address to a normalize vector of the input vector
; Input : R0 address to vector to normalize
; Output : R3 address to vector (normalized)
; Clobbers All
function vector_normalize
  ;store referece to in to stack
  gsu_stack_push
  ;get length
  call vector_length ;R3 = length
  move r0, r3
  call reciprocol ;R3 = 1/length
  ;retrieve referece to in from stack
  move r6, r3 ; Beging preparations for multiplies
  ; Get in from stack
  gsu_stack_pop r1 ; R1 = addr of vector to get value of
  iwt r2, #vector_normalize_out

  ;(vector_normalize_out.x) = (R1.x * R6)
  ldw (r1) ;R0 = in.x
  to r7
  lmult ; r4 = decimal bits
  with r7
  swap
  move r8,r4
  merge ; r0 = fixed88 normalized length
  stw (r2)
  with r1
  add #$2 ; R1 = R1.y
  with r2
  add #$2 ; R2 = memory address to write to

  ldw (r1) ;R0 = in.x
  to r7
  lmult ; r4 = decimal bits
  with r7
  swap
  move r8,r4
  merge ; r0 = fixed88 normalized length
  stw (r2)
  with r1
  add #$2 ; R1 = R1z
  with r2
  add #$2 ; R2 = memory address to write to

  ldw (r1) ; ;R0 = in.z
  to r7
  lmult ; r4 = decimal bits
  with r7
  swap
  move r8,r4
  merge ; r0 = fixed88 normalized length
  stw (r2)
  
  iwt r3, #vector_normalize_out

  ;MOVE #(vector_normalize_out +2), (R1.y * R6)
  ;MOVE #(vector_normalize_out +4), (R1.z * R6)


  return 
endfunction

;Vector.length function put in r1 the memory address of the vector to get the length of
;note this isn't going to be accurate, I drop decimals after the square operations. This isn't a
;problem for "long vectors" but is a problem for short ones.
; Clobbers All
; Input : Address of vector to get length of at r0
; Output : length of vector on r3

function vector_length
	;r0 = (vec.x)
  move r1,r0
	ldw (r1)
	;square vec.x/r0
	move r6, r0
	fmult 
	move r3, r0 ; save x^2 to r3
	
	with r1
	add #2 ;r1 = vec.y
	
	;r0 = (vec.y)
	ldw (r1)
	;square vec.y/r0
	move r6, r0
	fmult 
	move r2, r0 ; save y^2 to r2
	with r1
	add #2 ;r1 = vec.z
	
	;r0 = (vec.z)
	ldw (r1)
	;square vec.z/r0
	move r6, r0
	fmult  ; r0 = z^2
	
	add r2 ; r0 = z^2 + y^2 
	add r3 ; r0 = z^2 + y^2 + x^2

	call gsu_sqrt
	return

	;load 


endfunction
.endif