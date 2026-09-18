;
; struct tm* __fastcall__ localtime (const time_t* timep);
;

        .export         _localtime

        .import         __rp6502_tm_call
        .import         ldeaxi
        .import         _ria_push_long

        .include        "rp6502.inc"

_localtime:
        cpx     #$00
        bne     @notnull
        cmp     #$00
        beq     @null           ; A/X already 0, return NULL
@notnull:
        jsr     ldeaxi          ; A:X:sreg = *timep (32-bit load)
        jsr     _ria_push_long  ; short stack, OS zero-fills to 64 bits
        lda     #RIA_OP_LOCALTIME
        jmp     __rp6502_tm_call
@null:  rts
