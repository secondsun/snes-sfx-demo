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




; Multiplies St by r6 as signed Q8.8 fixed-point numbers and packs result into D
; In:       St = source register (St != r4), r6 = multiplicand, D = destination (D != r6)
; Out:      D = 16-bit Q8.8 fixed-point product
; Clobbers: r4, D, flags
.macro condensed_lmult St, D
  .if .not( .blank({St}))
        from St
    .endif
    .if .not( .blank({D}))
        to	D
    .endif
    lmult ; D = integer portion of S*r6 & r4 = decimal portion of S*r6

    with r4 
    hib
    with D  
    lob
    with D
    swap
    with D
    or r4
.endmacro

; Copies a 3D vector from source address to destination address
; In:       R0 = source vector address, R2 = destination vector address
; Out:      R3 = destination vector address (copied)
; Clobbers: R1, R2, R3
function vector3_copy  
   move r1,r0
   move r3, r2
  
    ldw (r1)
    stw (r2)

    with r2
    add #2
    with r1
    add #2
  
    ldw (r1)
    stw (r2)

    with r2
    add #2
    with r1
    add #2
  
    ldw (r1)
    stw (r2)

    with r2
    add #2
    with r1
    add #2
  
   
   return
endfunction

; Calculates cross product of two 3D vectors (R0 x R1)
; In:       R0 = address of first vector, R1 = address of second vector
; Out:      R3 = address of result vector (VECTOR_CROSS_OUT)
; Clobbers: All
function vector3_cross
  
  ;Adjust R0, R1 to (r0+2),(r1+4)
  add #2
  with r1
  add #4

  ;Begin (r0+2)*(r1+4)
  to r5
  ldw (r0) ; r5 = r0.y
  to r6
  ldw (r1) ; r6 = r1.z
  condensed_lmult r5, r3; r3 = this.y*other.z at fixed 8.8
  ; End (r0+2)*(r1+4)

  ;Adjust (r0+2),(r1+4) to (r0+4),(r1+2)
  add #2
  with r1
  sub #2

  ;Begin (r0+4)*(r1+2)
  to r5
  ldw (r0) ; r5 = r0.z
  to r6
  ldw (r1) ; r6 = r1.y
  condensed_lmult r5, r2; r2 = this.z*other.y at fixed 8.8
  ; End (r0+4)*(r1+2)
  
  ;Begin subtract this.y*other.z - this.z*other.y
  with r3
  sub r2
  ;Write out.x
  sm (VECTOR_CROSS_OUT), r3

  ;Adjust (r0+4),(r1+2) to (r0+4),(r1)
  with r1
  sub #2

  ;Begin (r0+4)*(r1)
  to r5
  ldw (r0) ; r5 = this.z
  to r6
  ldw (r1) ; r6 = other.x
  condensed_lmult r5, r3; r3 = this.z*other.x at fixed 8.8
  ; End (r0+4)*(r1)

  ;Adjust (r0+4),(r1) to (r0),(r1+4)
  sub #4
  with r1
  add #4

  ;Begin (r0)*(r1+4)
  to r5
  ldw (r0) ; r5 = this.x
  to r6
  ldw (r1) ; r6 = other.z
  condensed_lmult r5, r2; r2 = this.x*other.z at fixed 8.8
  ; End (r0)*(r1+4)

  ;Begin subtract this.z*other.x - this.x*other.z
  with r3
  sub r2
  ;Write out.y
  sm (VECTOR_CROSS_OUT+2), r3

  ;Adjust (r0),(r1+4) to (r0)*(r1+2)
  with r1
  sub #2

  ;Begin (r0)*(r1+2)
  to r5
  ldw (r0) ; r5 = this.x
  to r6
  ldw (r1) ; r6 = other.y
  condensed_lmult r5, r3; r3 = this.x*other.y at fixed 8.8
  ; End (r0)*(r1+2)

  ;Adjust (r0)*(r1+2) to (r0+2),(r1)
  add #2
  with r1
  sub #2

  ;Begin (r0+2)*(r1)
  to r5
  ldw (r0) ; r5 = this.y
  to r6
  ldw (r1) ; r6 = other.x
  condensed_lmult r5, r2; r2 = this.y*other.x at fixed 8.8
  ; End (r0+2)*(r1)

  ;Begin subtract this.x*other.y - this.y*other.x
  with r3
  sub r2
  ;Write out.z
  sm (VECTOR_CROSS_OUT+4), r3

  iwt r3, #VECTOR_CROSS_OUT
  return
endfunction

; Calculates dot product of two 3D vectors
; In:       R0 = address of first vector, R1 = address of second vector
; Out:      R3 = dot product as fixed Q8.8
; Clobbers: All
function vector3_dot
  
  ;r0 = &a.x
  ;r1 = &b.x

  to r6
  ldw (r0)
  to r7 
  ldw (r1)
  condensed_lmult r7, r2; a.x * b.x

  ;r0 = &a.y
  ;r1 = &b.y
  add #2
  with r1
  add #2
  
  to r6
  ldw (r0)
  to r7 
  ldw (r1)
  condensed_lmult r7, r3; a.y * b.y

  ;r0 = &a.z
  ;r1 = &b.z
  add #2
  with r1
  add #2
  
  to r6
  ldw (r0)
  to r7 
  ldw (r1)
  condensed_lmult r7, r5; a.z * b.z

  from r2
  add r5 ; r0 = a.x*b.x + a.z*b.z
  with r3 ; 
  add r0 ; r3 = a.y*b.y + r0

  return
endfunction

; Calculates sum of two 3D vectors (R0 + R1)
; In:       R0 = address of first vector, R1 = address of second vector
; Out:      R3 = address of sum vector (VECTOR_ADD_OUT)
; Clobbers: All
function vector3_add
  move r3, r1
  to r1 
  ldw (r0)
  add #2 ;bump up r0 = in.y
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


; Negates each component of a 3D vector
; In:       R0 = address of vector to negate
; Out:      R3 = address of negated vector (VECTOR_NEGATE_OUT)
; Clobbers: All
function vector3_negate
  
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

; Calculates difference of two 3D vectors (R0 - R3)
; In:       R0 = address of vector to subtract from, R3 = address of vector to subtract
; Out:      R3 = address of result vector (VECTOR_SUBTRACT_OUT)
; Clobbers: All
function vector3_subtract
  to r1 
  ldw (r0)
  add #2 ;bump up r0 = in.y
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

; Normalizes a 3D vector to unit length
; In:       R0 = address of vector to normalize
; Out:      R3 = address of normalized vector (vector_normalize_out)
; Clobbers: All
function vector3_normalize
  ;store referece to in to stack
  sm (_normalize_small_big_reciprocal_temp), r0
  ;get length
  call vector3_length ;R3 = length
  
  ;Check the length and determine if we will 
  ;use a reciprocal that returns 8 or 16 fractional bits
  move r0, r3
  iwt r5, #1 ;r5 = 1 using 8 frac bits
  hib
  cmp r5 ;if r0 > 1 (z=0 and s=0)
  move r0, r3
  beq small
  nop
  bmi small
  nop
big:  ;calculate using 16 fractional bits and no int bit
  call _normalize_big
  return 
small:  ;calculate using 8 fractional bits and 8 int bits
  call _normalize_small
  return  
endfunction

; Normalizes vector using 16 fractional bits (private helper)
; In:       _normalize_small_big_reciprocal_temp = address of vector
; Out:      R3 = address of normalized vector (vector_normalize_out)
; Clobbers: All
function _normalize_big
  call reciprocal016 ;R3 = 1/length
  ;retrieve referece to in from stack
  move r6, r3 ; Beging preparations for multiplies
  ; Get in from stack
  lm r1, (_normalize_small_big_reciprocal_temp) ; R1 = addr of vector to get value of
  iwt r2, #vector_normalize_out

  ;(vector_normalize_out.x) = (R1.x * R6)
  ldw (r1) ;R0 = in.x
  lmult ; r4 = decimal bits
  stw (r2)
  with r1
  add #$2 ; R1 = R1.y
  with r2
  add #$2 ; R2 = memory address to write to

  ldw (r1) ;R0 = in.x
  lmult ; r4 = decimal bits
  stw (r2)
  with r1
  add #$2 ; R1 = R1z
  with r2
  add #$2 ; R2 = memory address to write to

  ldw (r1) ; ;R0 = in.z
  lmult ; r4 = decimal bits
  stw (r2)
  
  iwt r3, #vector_normalize_out
  return
endfunction

; Normalizes vector using 8 fractional bits (private helper)
; In:       _normalize_small_big_reciprocal_temp = address of vector
; Out:      R3 = address of normalized vector (vector_normalize_out)
; Clobbers: All
function _normalize_small
  call reciprocal ;R3 = 1/length
  ;retrieve referece to in from stack
  move r6, r3 ; Beging preparations for multiplies
  ; Get in from stack
  lm r1, (_normalize_small_big_reciprocal_temp) ; R1 = addr of vector to get value of
  iwt r2, #vector_normalize_out

  ;(vector_normalize_out.x) = (R1.x * R6)
  ldw (r1) ;R0 = in.x
  condensed_lmult r0, r0; fixed 88 of this.x*1/len
  
  stw (r2)
  with r1
  add #$2 ; R1 = R1.y
  with r2
  add #$2 ; R2 = memory address to write to
  ldw (r1) ;R0 = in.x
  
  condensed_lmult r0, r0; r0  = fixed 88 of this.y*1/len

  stw (r2)
  with r1
  add #$2 ; R1 = R1z
  with r2
  add #$2 ; R2 = memory address to write to

  ldw (r1) ; ;R0 = in.z
  condensed_lmult r0, r0 ; r0  = fixed 88 of this.z*1/len

  stw (r2)
  
  iwt r3, #vector_normalize_out

  return
endfunction

; Calculates Euclidean length of a 3D vector
; In:       R0 = address of vector
; Out:      R3 = length of vector in fixed Q8.8
; Clobbers: All
function vector3_length
	;r0 = (vec.x)
  move r1,r0
	ldw (r1)
	;square vec.x/r0
	move r6, r0
	lmult ; r7 = int bits
  move r3, r0 ; save x^2 int to r3
	move r7, r4 ; save x^2 decimal to r7

	with r1
	add #2 ;r1 = vec.y
	
	;r0 = (vec.y)
	ldw (r1)
	;square vec.y/r0
	move r6, r0
	lmult ; r4 = decimal bits
  move r2, r0 ; save y^2 integer to r2
  move r8, r4 ; save y^2 decimal to r8

	with r1
	add #2 ;r1 = vec.z
	
	;r0 = (vec.z)
	ldw (r1)
	;square vec.z/r0
	move r6, r0
  
	lmult ; r4 = decimal bits
  
	add r2 ; r0 = z^2 + y^2 
	add r3 ; r0 = z^2 + y^2 + x^2

  with r4
  add r8
  adc #0 
  with r4
  add r7
  adc #0
  
  move r1,r4
  call gsu_sqrt32
  return
endfunction

; Transforms a 3D vector by multiplying with a 4x4 matrix (in-place)
; In:       R0 = address of vector to transform, R1 = address of matrix to transform by
; Out:      Vector at R0 overwritten with transformed coordinates
; Clobbers: All
function vector3_transform
  ; r2 = write cursor into VECTOR_TRANSFORM_OUT. Row results must NOT be pushed
  ; to the stack inside the loop: endfor's restoreloop pops r13/r12 off the top.
  iwt r2, #VECTOR_TRANSFORM_OUT

 for 3
    to r6
    ldw (r0) ; r6 = vector.x
    to r3
    ldw (r1) ; r3 = matrix[0][0]

    condensed_lmult r3, r9; r9 = v.x * m[0][0]

    ; setup y* m[0][1]
    add #2
    with r1
    add #2

    to r6
    ldw (r0) ; r6 = vector.x
    to r3
    ldw (r1) ; r3 = matrix[0][0]

    condensed_lmult r3, r5; r5 = v.y * m[0][1]

    ; setup z* m[0][2]
    add #2
    with r1
    add #2

    to r6
    ldw (r0) ; r6 = vector.z
    to r3
    ldw (r1) ; r3 = matrix[0][2]

    condensed_lmult r3, r11; r11 = v.z * m[0][2]
    
    ;quick sum of x*m00,y*m01,z*m02 to r9
    with r9
    add r5
    with r9
    add r11

    with r1
    add #2
    to r5
    ldw(r1) ; 5 = m[0][3]
    with r9 
    add r5

    ; Save x*matrix[0][0] +y*matrix[0][1] +z*matrix[0][2] + matrix[0][3];
    from r9
    stw (r2)
    inc r2
    inc r2

    ;reset variables
    with r1
    add #2 ; r1 = @matrix[1]
    sub #4 ; r0 = @vector
  endfor

  ; copy VECTOR_TRANSFORM_OUT back over the input vector (in-place result)
  move r2, r0
  iwt r0, #VECTOR_TRANSFORM_OUT
  call vector3_copy

return
endfunction



.endif