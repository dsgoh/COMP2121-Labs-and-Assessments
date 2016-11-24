.set NEXT_STRING = 0x0000

.macro defstring ; str
	.set T = PC
	.dw NEXT_STRING << 1
	.set NEXT_STRING = T
	.if strlen(@0) & 1 
		.db @0, 0
	.else
		.db @0, 0, 0
	.endif
.endmacro

.cseg
rjmp start

defstring "macros"
defstring "are"
defstring "fun"

start:
	ldi ZL = low(NEXT_STRING << 1)
	ldi ZH = low(NEXT_STRING << 1)

	ldi XL = low(NEXT_STRING)
	ldi XH = high(NEXT_STRING)
	
	ldi r20, 0	; temp counter
	ldi r21, 0	; largest word counter 

length: 
	;start at the end of memory 
	; go to next letter 

	; increment temp counter
	inc r20
	; if letter does not equal 00 go to start 
	; otherwise go to search  
	cp 

search: 
	;if the temp counter is greater than the big word counter 
		;save the size 
		;save the pointer to X
	; if the next node in the list is not NULL
	;increment the Z pointer to the next node in the list
	; call length 


halt:
	rjmp halt