.include "m2560def.inc"

ldi r16, 0xFF
out DDRC, r16

ldi r16, 0xE5
out PORTC, r16


halt:
	rjmp halt
