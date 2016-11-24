.include "m2560def.inc" 

start:		

	ldi ZH, high(memory) ; Saves high pointer to ZH
	ldi ZL, low(memory)	; Saves low pointer to ZL

	.dseg 
	.org 0x300	; Address in memory
	memory: .byte 20 ; max number of characters is 20
	.cseg


	word: .db "hello world", "\0" 

	;get length of string word
	;go through each letter recursively 
	;check if letter is lowercase or not
	; make letter lowercase and save to ram at location 300

	ldi r16, 0
loop:
	


halt:
	rjmp halt





	.include "m2560def.inc"

.equ size = 7

ldi ZH, high(memory) ; Saves high pointer to ZH
ldi ZL, low(memory)	

.dseg
.org 0x300
memory: .byte 7
.cseg

rjmp start

start:
	ldi r16, 7
	ldi r17, 4
	ldi r18, 5
	ldi r19, 1
	ldi r20, 6
	ldi r21, 3
	ldi r22, 2

find_biggest:
	cpi r16, r17
	;Find the largest value in the registers r16-r22
	;save it to register r25
	;clear the old register

	;save it to memory 
	;increment the pointer
	ST Z+, r25






halt:
	rjmp halt





	
	


