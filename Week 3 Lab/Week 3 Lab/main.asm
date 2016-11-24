.include "m2560def.inc"

.equ size = 7

ldi ZH, high(memory) ; Saves high pointer to ZH
ldi ZL, low(memory)	


.dseg

memory: .byte 7
.cseg

start:
	ldi r16, 7
	ldi r17, 4
	ldi r18, 5
	ldi r19, 1
	ldi r20, 6
	ldi r21, 3
	ldi r22, 2

	ST Z+, r16
	ST Z+, r17
	ST Z+, r18
	ST Z+, r19
	ST Z+, r20
	ST Z+, r21
	ST Z+, r22

	;The end pointer is z+6
	ldi r27, size

outer_loop:
	;Resets the pointers 
	ldi ZH, high(memory) ; Saves high pointer to ZH
	ldi ZL, low(memory)	
	
	ldi YH, high(memory+1)
	ldi YL, low(memory+1)
	;Clear the counter
	ldi r26, 0
	dec r27

	cp r27, r26
	breq halt

inner_loop:
	cp ZH, YH
	;swap if need be 
	brge swap_function
no_swap:
	; book keeping for counters
	;increment the counter 
	inc r26
	
	ld r0, Z+
	ld r0, Y+

	cp r27, r26
	breq outer_loop
	rjmp inner_loop

 
halt:
	rjmp halt

swap_function:
	ld r16, Z
	ld r17, Y
	ST Z, r17
	ST Y , r16
	rjmp no_swap





	
	


