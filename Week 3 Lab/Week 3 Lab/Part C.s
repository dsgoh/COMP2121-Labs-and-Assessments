.include "m2560def.inc"

.equ size = 20

.dseg
.org 0x300
CAPS_string: .byte 20
.cseg

rjmp start
Lower_string: .db "hello WORLD", "\0.()"

start:
	ldi ZL, low(Lower_string << 1)
	ldi ZH, high(Lower_string << 1)

	ldi YL, low(CAPS_string)
	ldi YH, high(CAPS_string)

	ldi r19, 0	;initialises the counter 

loop:
	lpm r20, Z+	;Loads the first letter and increments the pointer

	cpi r20, 0x61
	brge great_than_a

housekeeping:
	st Y+, r20
	inc r19
	cpi r19, size
	brlt loop

halt:
	rjmp halt

great_than_a:
	cpi r20, 0x7B
	brlt less_than_bracket
	rjmp housekeeping

less_than_bracket:
	;insert what to do with lower case here
	subi r20, 32
	rjmp housekeeping




	
	


