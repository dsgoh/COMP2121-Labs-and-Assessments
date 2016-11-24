.include "m2560def.inc" 

start:

	ldi ZH, high(memory) ; Saves high pointer to ZH
	ldi ZL, low(memory)	


.dseg 
.org 0x300	; Address in memory
	memory: .byte 5
.cseg

	ldi r16, 1
	ldi r17, 2
	ldi r18, 3
	ldi r19, 4
	ldi r20, 5

	;Second Array
	ldi r21, 5
	ldi r22, 4
	ldi r23, 3
	ldi r24, 2
	ldi r25, 1

	;Add together into registers
	add r21, r16
	add r22, r17
	add r23, r18
	add r24, r19
	add r25, r20

	;X/Z/Y is a pointer 
	ST Z+, r21
	ST Z+, r22
	ST Z+, r23
	ST Z+, r24
	ST Z+, r25

halt:
	rjmp halt



