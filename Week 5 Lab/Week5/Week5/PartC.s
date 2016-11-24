.include "m2560def.inc"

.def counter = r17
.def next = r18

.def current_h = r19
.def current_l = r20

.def max_int = r21
.def min_int = r22

.set NEXT_INT = 0x0000
.macro defint ; int
	.set T = PC
	.dw NEXT_INT << 1
	.set NEXT_INT = T
	.dw @0, 0	
.endmacro

.cseg 
rjmp main

; elements in the linked list 

defint "1"
defint "10"


main:
	; save the address of the NEXT_STRING REGISTER and increment by 1
	ldi zh, high(NEXT_INT<<1)
	ldi zl, low(NEXT_INT<<1)
	
	clr max_int	;clear the r16 register which stores the current longest length of the string 
	clr min_int
	clr counter	;clear the value in the counter => r17

	rcall search ;Calls the function to find the largest string in the linked list

halt: rjmp halt 

search:

prologue:
	; save the registers that are going to be used in our recursion
	push current_h	;saves the current value addresses
	push current_l

	push counter  ;pushes the counter to the stack 

body:
	; store the current location 
	mov current_h, zh
	mov current_l, zl

	; store the pointer to the next entry in x temporarily
	lpm xl, z+ 
	lpm xh, z+
	clr counter

	; count how long the string is
count_loop:
	lpm next, z+
	cpi next, 0		 ;Check if the current value is 0
	breq check_last  ;Break if the current value is 0
	
rjmp count_loop

	; check if this is the last string in the linked list
check_last:
	cpi xh, 0     ;Checks if the current pointer is at the start of the memory block
	brne not_last
	cpi xl, 0
	brne not_last

	; if this is the last string, make it the longest word
last:
	mov max_int, counter
	mov zh, current_h
	mov zl, current_l
	rjmp epilogue		

not_last:
	;	point z to the next string 
	mov zh, xh	;Moves the tempoary x value into the more permanent z value
	mov zl, xl	
	
	rcall search

	; see if this is the highest int 
	cp counter, max_int ; 
	brlt less_than		;If counter is less than the biggest then check if it is lower than the lowest

highest:
	; if this is highest, lets point to it, and change r16
	mov max_int, counter 
	mov zh, current_h
	mov zl, current_l

lowest:
	

epilogue: 
	pop counter
	pop current_l
	pop current_h
	ret

less_than:
	cp counter, min_int
	brge lowest
	rjmp epilogue


