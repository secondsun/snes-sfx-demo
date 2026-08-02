
.ifndef ::__GSU_TRIG_DEFINED__
::__GSU_TRIG_DEFINED__ = 1   



; for arg = rester containing int (0 - 90)  
; each index is approximate to 4 degrees in q1.15 format
;clobbers r14, and dest. arg unchanged
.macro cos_lookup_rom arg, dest

	 .ifblank(arg)
        .error "cos_lookup: argument is required"
    .endif
	
 .ifblank(dest)
        .error "cos_lookup: destination is required"
    .endif

	ibt r14,#$3
	from r14
    romb

		iwt dest, #90 ; sin(x) = cos(x-90)	
		from arg
		to dest
		sub dest
		bpl :+ ; if arg >= 90, we need to negate the argument
			nop
			with dest
			not
			with dest
			add #1
		:; dest = 90 - arg = sin(90-arg) = cos(arg)
		

		iwt r14, #sin_table
		with r14
		add dest
		with r14
		add dest
		
		to dest
		getbl
		inc r14
		with dest
		getbh
.endmacro

; for arg = rester containing int (0 - 90)  
; each index is approximate to 4 degrees in q1.15 format
;clobbers r14 and dest. arg unchanged
.macro sin_lookup_rom arg, dest

	 .ifblank(arg)
        .error "sin_lookup: argument is required"
    .endif
	
 .ifblank(dest)
        .error "sin_lookup: destination is required"
    .endif

	ibt r14,#$3
	from r14
    romb

		iwt r14, #sin_table
		with r14
		add arg
		with r14
		add arg
		
		to dest
		getbl
		inc r14
		with dest
		getbh
.endmacro


		
;Q1.15 format
;-1 to 1 range
;1 at 23, -1 at 68		
;90 entries at 4 degrees each
;91st entry is 0 degrees again
sin_table:
.word $0
.word $477
.word $8E8
.word $D4E
.word $11A4
.word $15E4
.word $1A08
.word $1E0C
.word $21EA
.word $259E
.word $2923
.word $2C75
.word $2F90
.word $326F
.word $350F
.word $376D
.word $3986
.word $3B57
.word $3CDE
.word $3E19
.word $3F07
.word $3FA6
.word $3FF6
.word $4000
.word $3FA6
.word $3F07
.word $3E19
.word $3CDE
.word $3B57
.word $3986
.word $376D
.word $350F
.word $326F
.word $2F90
.word $2C75
.word $2923
.word $259E
.word $21EA
.word $1E0C
.word $1A08
.word $15E4
.word $11A4
.word $D4E
.word $8E8
.word $477
.word $0
.word $FB89
.word $F718
.word $F2B2
.word $EE5C
.word $EA1C
.word $E5F8
.word $E1F4
.word $DE16
.word $DA62
.word $D6DD
.word $D38B
.word $D070
.word $CD91
.word $CAF1
.word $C893
.word $C67A
.word $C4A9
.word $C322
.word $C1E7
.word $C0F9
.word $C05A
.word $C00A
.word $C000
.word $C05A
.word $C0F9
.word $C1E7
.word $C322
.word $C4A9
.word $C67A
.word $C893
.word $CAF1
.word $CD91
.word $D070
.word $D38B
.word $D6DD
.word $DA62
.word $DE16
.word $E1F4
.word $E5F8
.word $EA1C
.word $EE5C
.word $F2B2
.word $F718
.word $FB89
.word $0

.endif