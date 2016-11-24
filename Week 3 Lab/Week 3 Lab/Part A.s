;
; Week 3 Lab.asm
;
; Created: 10/08/2016 1:42:59 PM
; Author : tomnlittle
;

.include "m2560def.inc" 
; Add two 16 bit numbers, 40960 and 2730 
partA:
	ldi r16, low(640) //640 needs more than 8 bits to store, store lower 
					  // 8 bits in r16 and higher 8 bits in r17
	ldi r17, high(640)

	ldi r18, low(511)
	ldi r19, high(511)

	clr r20		//Clears any values in r20, and clears SREG
	clr r21

	add r20, r16 //Adds r16 to r20, toggles overflow in SREG
	adc r20, r18 //ADC accounts for overflow 

	adc r21, r17
	adc r21, r19

halt:
	rjmp halt
