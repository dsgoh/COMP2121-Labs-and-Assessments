.include "m2560def.inc"

.def counter = r17
.def next = r18

.def current_h = r19
.def current_l = r20

.set NEXT_INT = 0x0000
.macro defint ; int
	.set T = PC
	.dw NEXT_INT << 1
	.set NEXT_INT = T
	.dw @0
.endmacro

.cseg 
rjmp main

; elements in the linked list 

defint 0x1110
defint 0x2222
defint 0x3322
defint 0x4432
defint 0x1919
defint 0x2121


main:
	; save the address of the NEXT_STRING REGISTER and increment by 1
	ldi zh, high(NEXT_INT<<1)
	ldi zl, low(NEXT_INT<<1)
	
	clr current_l	;clear the r16 register which stores the current longest length of the string 
	clr current_h
	clr counter	;clear the value in the counter => r17

	rcall search ;Calls the function to find the largest string in the linked list

halt: rjmp halt 

search:

prologue:
	; save the registers that are going to be used in our recursion
	push current_h	;saves the current value addresses
	push current_l

body:
	; store the pointer to the next entry in x temporarily
	lpm xl, z+ 
	lpm xh, z+

	lpm current_l, z+
	lpm current_h, z

	; check if this is the last string in the linked list
check_last:
	cpi xh, 0     ;Checks if the current pointer is at the start of the memory block
	brne not_last
	cpi xl, 0
	brne not_last

	; if this is the last string, make it the longest word
last:
	mov xh, current_h
	mov xl, current_l
	mov yl, current_l
	mov yh, current_h

	rjmp epilogue		

not_last:
	;	point z to the next string 
	mov zh, xh	;Moves the tempoary x value into the more permanent z value
	mov zl, xl	
	
	rcall search

highest:
	; if this is highest, lets point to it, and change r16
	cp current_h, xh
	brlt isLowest
	
	cp current_l, xl
	brlt isLowest 

	;hence is highest
	mov zh, current_h
	mov zl, current_l

	;Just follow program through it wont trigger anything

isLowest:
	cp current_h, yh
	brlt foundLowest

	cp current_l, yl
	brge epilogue
	
foundLowest:
	mov yh, current_h
	mov yl, current_l	

epilogue: 
	pop current_l
	pop current_h
	ret




