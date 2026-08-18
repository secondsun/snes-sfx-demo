
.ifndef ::__GSU_TRIG_DEFINED__
::__GSU_TRIG_DEFINED__ = 1   



; for arg = register containing int (0 - 120)  
; each index is approximate to 3 degrees in q1.15 format
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

		iwt dest, #30 ; sin(x) = cos(x-90°)	;the table is in 3 degree incriments.
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

; for arg = register containing int (0 - 120)  
; each index is approximate to 3 degrees in q1.15 format
; arg must not be r14
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
.word $359
.word $6B1
.word $A03
.word $D4E
.word $1090
.word $13C7
.word $16F0
.word $1A08
.word $1D0E
.word $2000
.word $22DB
.word $259E
.word $2847
.word $2AD3
.word $2D41
.word $2F90
.word $31BD
.word $33C7
.word $35AD
.word $376D
.word $C000
.word $3A78
.word $3BC0
.word $3CDE
.word $3DD2
.word $3E9A
.word $3F36
.word $3FA6
.word $3FEA
.word $4000
.word $3FEA
.word $3FA6
.word $3F36
.word $3E9A
.word $3DD2
.word $3CDE
.word $3BC0
.word $3A78
.word $3906
.word $376D
.word $35AD
.word $33C7
.word $31BD
.word $2F90
.word $2D41
.word $2AD3
.word $2847
.word $259E
.word $22DB
.word $2000
.word $1D0E
.word $1A08
.word $16F0
.word $13C7
.word $1090
.word $D4E
.word $A03
.word $6B1
.word $359
.word $0
.word $FCA7
.word $F94F
.word $F5FD
.word $F2B2
.word $EF70
.word $4000
.word $E910
.word $E5F8
.word $E2F2
.word $E000
.word $DD25
.word $DA62
.word $D7B9
.word $D52D
.word $D2BF
.word $D070
.word $CE43
.word $CC39
.word $CA53
.word $C893
.word $C6FA
.word $C588
.word $C440
.word $C322
.word $C22E
.word $C166
.word $C0CA
.word $C05A
.word $C016
.word $C000
.word $C016
.word $C05A
.word $C0CA
.word $C166
.word $C22E
.word $C322
.word $C440
.word $C588
.word $C6FA
.word $C893
.word $CA53
.word $CC39
.word $CE43
.word $D070
.word $D2BF
.word $D52D
.word $D7B9
.word $DA62
.word $DD25
.word $E000
.word $E2F2
.word $E5F8
.word $E910
.word $EC39
.word $EF70
.word $F2B2
.word $F5FD
.word $F94F
.word $FCA7
.word $0

.endif