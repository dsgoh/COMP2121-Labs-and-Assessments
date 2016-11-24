.include "m2560def.inc"

.equ PATTERN = 0b1010101010101011
.def temp = r16
.def leds = r17

.def pattern_high = r18
.def pattern_low = r17

.def timer_high = r21

.macro clear	//Clears a word 2 bytes in memory 
	ldi YL, low(@0)
	ldi YH, high(@0)     
	clr temp
	st Y+, temp
	st Y, temp                
.endmacro

.dseg
SecondCounter:
	.byte 2               
TempCounter: 
	.byte 2               

.cseg
.org 0x0000 
	jmp RESET       //NORMAL JUMP 
	jmp DEFAULT     //Interrupt request bit 0 is set goto default
	jmp DEFAULT     //Interrupt request bit 1 is set goto default 
.org OVF0addr
	jmp Timer0OVF         

	...
	jmp DEFAULT      

DEFAULT:  reti       //return the interrupt without doing anything 

RESET:
	ldi temp, high(RAMEND)    //Initialises the stack pointers 
	out SPH, temp 
	ldi temp, low(RAMEND)
	out SPL, temp				//Stack initialised
	
	ser temp					//Writes 1's to port c indicating that we want this as an output 
	out DDRC, temp
	
	rjmp main					//Jumps to the main functions

Timer0OVF:				//Interrupt sub routine for the timer
	in temp, SREG		
	push temp		//Prologue starts 
	push YH			//Pushes all the pointers to the stack 
	push YL
	push r25
	push r24		

	push timer_high	//Pushes the timers to the stack 
		//Prologue ends

	timer_continue_1:

		lds r24, TempCounter	//Loads in the value of the temp counter
		lds r25, TempCounter+1
		adiw r25:r24,1 

		cpi r24, low(7812)	//Check if it has reached one second 
		ldi  temp, high(7812)
		cpc r25, temp

		brne  NotSecond

		//If no second has passed, 
		//write the highest part to Port C

		out PORTC, pattern_high

		//Shift the pattern 
		lsr pattern_high	//Effectively divides by two => hence shifts right 
		ror pattern_low		//Rotate Right through carry

		brcs when_carry_is_set

	timer_continue_2:
		clear TempCounter //Resets the tempoary counter 

		lds r24, SecondCounter
		lds r25, SecondCounter+1
		adiw r25:r24, 1	//Increase the second counter by 1

		sts SecondCounter, r24
		sts SecondCounter+1, r25

		ldi timer_high, high(16)

		cpi r24, low(16)
		cpc r25, timer_high

		brne timer_continue_1
		
		breq RESET

		rjmp redraw_leds

	rjmp EndIF

redraw_leds:
	ldi pattern_high, high(PATTERN)
	ldi pattern_low, low(PATTERN)
	clear SecondCounter
	rjmp timer_continue_1

when_carry_is_set:
	ldi r23, 0b10000000
	or pattern_high, r23
	rjmp timer_continue_2

NotSecond:		//Stores the new value of the temp counter
	sts TempCounter, r24
	sts TempCounter+1, r25

EndIF:
	pop timer_high

	pop r24	//Epilogue 
	pop r25
	pop YL
	pop YH
	pop temp
	out SREG, temp
	reti

main:
	ldi leds, 0xFF	//Writes 1's to all the lights, this 
	out PORTC, leds //Explains when the board is reset all the lights turn on

	ldi pattern_high, high(PATTERN) //Sets high and low bits of pattern
	ldi pattern_low, low(PATTERN) 

	clear TempCounter	//Clears the temp counter
	clear SecondCounter	//Clears the second counter

	ldi temp, 0b00000000	//Write 0's to timer counter 
	out TCCR0A, temp		
	ldi temp, 0b00000010	//Prescaler set to 8
	out TCCR0B, temp		
	ldi temp,  1<<TOIE0		// 128 microseconds it counts up
	sts TIMSK0, temp		//Enable the T/C0 Interrupt
	sei						//Enable global interrupt

loop: rjmp loop	
