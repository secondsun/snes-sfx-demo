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

; ; Copies a 3D vector from source address to destination address
; In:       src = source vector address, dst = destination vector address
; Out:      out = destination vector address (copied)
; Clobbers: r0, allocated registers
function vector3_copy src, dst : out
    move out, dst
  
    ldw (src)
    stw (dst)

    with dst
    add #2
    with src
    add #2
  
    ldw (src)
    stw (dst)

    with dst
    add #2
    with src
    add #2
  
    ldw (src)
    stw (dst)

    with dst
    add #2
    with src
    add #2
   
    return out
endfunction

; Calculates cross product of two 3D vectors (v1 x v2)
; In:       v1 = address of first vector, v2 = address of second vector
; Out:      out = address of result vector (VECTOR_CROSS_OUT)
; Clobbers: All
function vector3_cross v1, v2 : out
  register mul_a, mul_b = r6, prod1, prod2

  ;Adjust v1, v2 to (v1+2),(v2+4)
  with v1
  add #2
  with v2
  add #4

  ;Begin (v1+2)*(v2+4)
  to mul_a
  ldw (v1) ; mul_a = v1.y
  to mul_b
  ldw (v2) ; mul_b = v2.z
  condensed_lmult mul_a, prod1; prod1 = this.y*other.z at fixed 8.8
  ; End (v1+2)*(v2+4)

  ;Adjust (v1+2),(v2+4) to (v1+4),(v2+2)
  with v1
  add #2
  with v2
  sub #2

  ;Begin (v1+4)*(v2+2)
  to mul_a
  ldw (v1) ; mul_a = v1.z
  to mul_b
  ldw (v2) ; mul_b = v2.y
  condensed_lmult mul_a, prod2; prod2 = this.z*other.y at fixed 8.8
  ; End (v1+4)*(v2+2)
  
  ;Begin subtract this.y*other.z - this.z*other.y
  with prod1
  sub prod2
  ;Write out.x
  sm (VECTOR_CROSS_OUT), prod1

  ;Adjust (v1+4),(v2+2) to (v1+4),(v2)
  with v2
  sub #2

  ;Begin (v1+4)*(v2)
  to mul_a
  ldw (v1) ; mul_a = this.z
  to mul_b
  ldw (v2) ; mul_b = other.x
  condensed_lmult mul_a, prod1; prod1 = this.z*other.x at fixed 8.8
  ; End (v1+4)*(v2)

  ;Adjust (v1+4),(v2) to (v1),(v2+4)
  with v1
  sub #4
  with v2
  add #4

  ;Begin (v1)*(v2+4)
  to mul_a
  ldw (v1) ; mul_a = this.x
  to mul_b
  ldw (v2) ; mul_b = other.z
  condensed_lmult mul_a, prod2; prod2 = this.x*other.z at fixed 8.8
  ; End (v1)*(v2+4)

  ;Begin subtract this.z*other.x - this.x*other.z
  with prod1
  sub prod2
  ;Write out.y
  sm (VECTOR_CROSS_OUT+2), prod1

  ;Adjust (v1),(v2+4) to (v1)*(v2+2)
  with v2
  sub #2

  ;Begin (v1)*(v2+2)
  to mul_a
  ldw (v1) ; mul_a = this.x
  to mul_b
  ldw (v2) ; mul_b = other.y
  condensed_lmult mul_a, prod1; prod1 = this.x*other.y at fixed 8.8
  ; End (v1)*(v2+2)

  ;Adjust (v1)*(v2+2) to (v1+2),(v2)
  with v1
  add #2
  with v2
  sub #2

  ;Begin (v1+2)*(v2)
  to mul_a
  ldw (v1) ; mul_a = this.y
  to mul_b
  ldw (v2) ; mul_b = other.x
  condensed_lmult mul_a, prod2; prod2 = this.y*other.x at fixed 8.8
  ; End (v1+2)*(v2)

  ;Begin subtract this.x*other.y - this.y*other.x
  with prod1
  sub prod2
  ;Write out.z
  sm (VECTOR_CROSS_OUT+4), prod1

  iwt out, #VECTOR_CROSS_OUT
  return out
endfunction

; Calculates dot product of two 3D vectors
; In:       v1 = address of first vector, v2 = address of second vector
; Out:      dot = dot product as fixed Q8.8
; Clobbers: All
function vector3_dot v1, v2 : dot
  register mul_a = r6, mul_b, prod_x, prod_z

  ;v1 = &a.x
  ;v2 = &b.x

  to mul_a
  ldw (v1)
  to mul_b
  ldw (v2)
  condensed_lmult mul_b, prod_x; a.x * b.x

  ;v1 = &a.y
  ;v2 = &b.y
  with v1
  add #2
  with v2
  add #2
  
  to mul_a
  ldw (v1)
  to mul_b
  ldw (v2)
  condensed_lmult mul_b, dot; a.y * b.y

  ;v1 = &a.z
  ;v2 = &b.z
  with v1
  add #2
  with v2
  add #2
  
  to mul_a
  ldw (v1)
  to mul_b
  ldw (v2)
  condensed_lmult mul_b, prod_z; a.z * b.z

  from prod_x
  add prod_z ; r0 = a.x*b.x + a.z*b.z
  with dot
  add r0 ; dot = a.y*b.y + r0

  return dot
endfunction

; Calculates sum of two 3D vectors (v1 + v2)
; In:       v1 = address of first vector, v2 = address of second vector
; Out:      out = address of sum vector (VECTOR_ADD_OUT)
; Clobbers: All
function vector3_add v1, v2 : out
  register comp1, comp2

  to comp1
  ldw (v1)
  with v1
  add #2 ;bump up v1 = in.y
  to comp2
  ldw (v2)
  with v2
  add #2
  with comp1
  add comp2
  sm (VECTOR_ADD_OUT), comp1

  to comp1
  ldw (v1)
  with v1
  add #2 ;bump up v1 = in.z
  to comp2
  ldw (v2)
  with v2
  add #2
  with comp1
  add comp2
  sm (VECTOR_ADD_OUT+2), comp1

  to comp1
  ldw (v1)
  to comp2
  ldw (v2)
  with comp1
  add comp2
  sm (VECTOR_ADD_OUT + 4), comp1

  iwt out, #VECTOR_ADD_OUT

  return out
endfunction


; Negates each component of a 3D vector
; In:       v1 = address of vector to negate
; Out:      out = address of negated vector (VECTOR_NEGATE_OUT)
; Clobbers: All
function vector3_negate v1 : out
  register val = r0

  ldw (v1) ; val = vector.x
  with v1
  add #2 ; v1 = &vector.y
  not
  add #1 ; val = negated.x
  
  sm (VECTOR_NEGATE_OUT), val ; Write negate.x

  ldw (v1) ; val = vector.y
  with v1
  add #2 ; v1 = &vector.z
  not
  add #1 ; val = negated.y
  
  sm (VECTOR_NEGATE_OUT + 2), val ; Write negate.y


  ldw (v1) ; val = vector.z
  not
  add #1 ; val = negated.z
  
  sm (VECTOR_NEGATE_OUT + 4), val ; Write negate.z
  iwt out, #VECTOR_NEGATE_OUT

  return out

endfunction

; Calculates difference of two 3D vectors (v1 - v2)
; In:       v1 = address of vector to subtract from, v2 = address of vector to subtract
; Out:      out = address of result vector (VECTOR_SUBTRACT_OUT)
; Clobbers: All
function vector3_subtract v1, v2 : out
  register comp1, comp2

  to comp1
  ldw (v1)
  with v1
  add #2 ;bump up v1 = in.y
  to comp2
  ldw (v2)
  with v2
  add #2
  with comp1
  sub comp2
  sm (VECTOR_SUBTRACT_OUT), comp1

  to comp1
  ldw (v1)
  with v1
  add #2 ;bump up v1 = in.z
  to comp2
  ldw (v2)
  with v2
  add #2
  with comp1
  sub comp2
  sm (VECTOR_SUBTRACT_OUT+2), comp1

  to comp1
  ldw (v1)
  to comp2
  ldw (v2)
  with comp1
  sub comp2
  sm (VECTOR_SUBTRACT_OUT + 4), comp1

  iwt out, #VECTOR_SUBTRACT_OUT

  return out
endfunction

; Normalizes a 3D vector to unit length
; In:       v1 = address of vector to normalize
; Out:      out = address of normalized vector (vector_normalize_out)
; Clobbers: All
function vector3_normalize v1 : out
  register len, one, len_hi = r0
  ;store reference to in
  sm (_normalize_small_big_reciprocal_temp), v1
  ;get length
  call vector3_length v1 : len
  
  ;Check the length and determine if we will 
  ;use a reciprocal that returns 8 or 16 fractional bits
  move len_hi, len
  iwt one, #1 ;one = 1 using 8 frac bits
  hib
  cmp one ;if r0 > 1 (z=0 and s=0)
  beq small
  nop
  bmi small
  nop
big:  ;calculate using 16 fractional bits and no int bit
  call _normalize_big len : out
  return out
small:  ;calculate using 8 fractional bits and 8 int bits
  call _normalize_small len : out
  return out
endfunction

; Normalizes vector using 16 fractional bits (private helper)
; In:       len = length of vector, _normalize_small_big_reciprocal_temp = address of vector
; Out:      out = address of normalized vector (vector_normalize_out)
; Clobbers: All
function _normalize_big len : out
  register inv_len = r6, in_ptr, out_ptr
  call reciprocal016 len : inv_len
  ; Get in from temp
  lm in_ptr, (_normalize_small_big_reciprocal_temp) ; addr of vector to get value of
  iwt out_ptr, #vector_normalize_out

  ;(vector_normalize_out.x) = (in_ptr.x * inv_len)
  ldw (in_ptr) ;r0 = in.x
  lmult ; r4 = decimal bits
  stw (out_ptr)
  with in_ptr
  add #$2 ; in_ptr = in_ptr.y
  with out_ptr
  add #$2 ; out_ptr = memory address to write to

  ldw (in_ptr) ;r0 = in.y
  lmult ; r4 = decimal bits
  stw (out_ptr)
  with in_ptr
  add #$2 ; in_ptr = in_ptr.z
  with out_ptr
  add #$2 ; out_ptr = memory address to write to

  ldw (in_ptr) ;r0 = in.z
  lmult ; r4 = decimal bits
  stw (out_ptr)
  
  iwt out, #vector_normalize_out
  return out
endfunction

; Normalizes vector using 8 fractional bits (private helper)
; In:       len = length of vector, _normalize_small_big_reciprocal_temp = address of vector
; Out:      out = address of normalized vector (vector_normalize_out)
; Clobbers: All
function _normalize_small len : out
  register inv_len = r6, in_ptr, out_ptr, comp = r0
  call reciprocal len : inv_len
  ; Get in from temp
  lm in_ptr, (_normalize_small_big_reciprocal_temp) ; addr of vector to get value of
  iwt out_ptr, #vector_normalize_out

  ;(vector_normalize_out.x) = (in_ptr.x * inv_len)
  ldw (in_ptr) ;comp = in.x
  condensed_lmult comp, comp; fixed 88 of this.x*1/len
  
  stw (out_ptr)
  with in_ptr
  add #$2 ; in_ptr = in_ptr.y
  with out_ptr
  add #$2 ; out_ptr = memory address to write to
  ldw (in_ptr) ;comp = in.y
  
  condensed_lmult comp, comp; comp = fixed 88 of this.y*1/len

  stw (out_ptr)
  with in_ptr
  add #$2 ; in_ptr = in_ptr.z
  with out_ptr
  add #$2 ; out_ptr = memory address to write to

  ldw (in_ptr) ;comp = in.z
  condensed_lmult comp, comp ; comp = fixed 88 of this.z*1/len

  stw (out_ptr)
  
  iwt out, #vector_normalize_out

  return out
endfunction

; Calculates Euclidean length of a 3D vector
; In:       v1 = address of vector
; Out:      len = length of vector in fixed Q8.8
; Clobbers: All
function vector3_length v1 : len
  register val = r0, mul_reg = r6, mult_lo = r4
  register x2_int, x2_dec, y2_int, y2_dec

	;val = (vec.x)
	ldw (v1)
	;square vec.x/val
	move mul_reg, val
	lmult ; val = int bits, mult_lo = decimal bits
  move x2_int, val ; save x^2 int
	move x2_dec, mult_lo ; save x^2 decimal

	with v1
	add #2 ;v1 = vec.y
	
	;val = (vec.y)
	ldw (v1)
	;square vec.y/val
	move mul_reg, val
	lmult ; mult_lo = decimal bits
  move y2_int, val ; save y^2 integer
  move y2_dec, mult_lo ; save y^2 decimal

	with v1
	add #2 ;v1 = vec.z
	
	;val = (vec.z)
	ldw (v1)
	;square vec.z/val
	move mul_reg, val
  
	lmult ; mult_lo = decimal bits
  
	add y2_int ; val = z^2 + y^2 
	add x2_int ; val = z^2 + y^2 + x^2

  with mult_lo
  add y2_dec
  adc #0 
  with mult_lo
  add x2_dec
  adc #0
  
  call gsu_sqrt32 val, mult_lo : len
  return len
endfunction

; Transforms a 3D vector by multiplying with a 4x4 matrix (in-place)
; In:       v1 = address of vector to transform, mat = address of matrix to transform by
; Out:      Vector at v1 overwritten with transformed coordinates
; Clobbers: All
function vector3_transform v1, mat
  register out_ptr, mul_vec = r6, mul_mat, sum, prod_y, prod_z, tmp_ptr
  ; out_ptr = write cursor into VECTOR_TRANSFORM_OUT. Row results must NOT be pushed
  ; to the stack inside the loop: endfor's restoreloop pops r13/r12 off the top.
  iwt out_ptr, #VECTOR_TRANSFORM_OUT

 for 3
    to mul_vec
    ldw (v1) ; mul_vec = vector.x
    to mul_mat
    ldw (mat) ; mul_mat = matrix[0][0]

    condensed_lmult mul_mat, sum; sum = v.x * m[0][0]

    ; setup y* m[0][1]
    with v1
    add #2
    with mat
    add #2

    to mul_vec
    ldw (v1) ; mul_vec = vector.y
    to mul_mat
    ldw (mat) ; mul_mat = matrix[0][1]

    condensed_lmult mul_mat, prod_y; prod_y = v.y * m[0][1]

    ; setup z* m[0][2]
    with v1
    add #2
    with mat
    add #2

    to mul_vec
    ldw (v1) ; mul_vec = vector.z
    to mul_mat
    ldw (mat) ; mul_mat = matrix[0][2]

    condensed_lmult mul_mat, prod_z; prod_z = v.z * m[0][2]
    
    ;quick sum of x*m00,y*m01,z*m02 to sum
    with sum
    add prod_y
    with sum
    add prod_z

    with mat
    add #2
    to prod_y
    ldw (mat) ; prod_y = m[0][3]
    with sum
    add prod_y

    ; Save x*matrix[0][0] +y*matrix[0][1] +z*matrix[0][2] + matrix[0][3];
    from sum
    stw (out_ptr)
    inc out_ptr
    inc out_ptr

    ;reset variables
    with mat
    add #2 ; mat = @matrix[1]
    with v1
    sub #4 ; v1 = @vector
  endfor

  ; copy VECTOR_TRANSFORM_OUT back over the input vector (in-place result)
  iwt tmp_ptr, #VECTOR_TRANSFORM_OUT
  call vector3_copy tmp_ptr, v1

return
endfunction



.endif