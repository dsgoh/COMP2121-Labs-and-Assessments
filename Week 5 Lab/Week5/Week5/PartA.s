.include "m2560def.inc"

.equ size = 4

.dseg
return_string: .byte 4

.cseg
rjmp start; 

input_string: .db "abc",0

start:
	ldi ZL, low(input_string << 1)
	ldi ZH, high(input_string << 1)
	
	ldi YL, low(return_string)
	ldi YH, high(return_string)

	ldi XL, low(RAMEND)
	ldi XH, high(RAMEND)

	out spl, XL
	out sph, XH
	
	ldi r19, 0 ; counter 
		
	ldi r20, 0 ; temp
	push r20

push_to_stack:
	lpm r20, Z+		
	push r20 			
	inc r19			
	cpi r19, size-1
	breq clear_counter	
	rjmp push_to_stack	
	
clear_counter:
	clr r19				

push_to_data:
	pop r20				
	st Y+, r20				
	inc r19				
	cpi r19, size		
	breq halt				
	rjmp push_to_data	

halt:
	rjmp halt
