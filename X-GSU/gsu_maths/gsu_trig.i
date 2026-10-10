
.ifndef ::__GSU_TRIG_DEFINED__
::__GSU_TRIG_DEFINED__ = 1   



; Looks up cosine of angle from ROM sin_table in signed Q1.15 format
; In:       arg = register containing angle index (0 - 120, ~3 deg per step), dest = destination register
; Out:      dest = cos(angle) in signed Q1.15 format
; Clobbers: dest, r14, flags
.macro cos_lookup_rom arg, dest

	 .ifblank(arg)
        .error "cos_lookup: argument is required"
    .endif
	
 .ifblank(dest)
        .error "cos_lookup: destination is required"
    .endif

		; cos(x) = sin(x + 90°); with 3° increments, 90° = 30 steps
		iwt dest, #30
		from arg
		add dest
		move dest, r0
		iwt r14, #120
		from dest
		sub r14
		bmi :+
		nop
		move dest, r0
	:

		ibt r14, #$4
		from r14
		romb

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

; Looks up sine of angle from ROM sin_table in signed Q1.15 format
; In:       arg = register containing angle index (0 - 120, ~3 deg per step, arg != r14), dest = destination register
; Out:      dest = sin(angle) in signed Q1.15 format
; Clobbers: dest, r14
.macro sin_lookup_rom arg, dest

	 .ifblank(arg)
        .error "sin_lookup: argument is required"
    .endif
	
 .ifblank(dest)
        .error "sin_lookup: destination is required"
    .endif

	ibt r14, #$4
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


.segment "GSUDATA"
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
.word $3906
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
.word $EC39
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
.export sin_table

.segment "GSUCODE"
.endif