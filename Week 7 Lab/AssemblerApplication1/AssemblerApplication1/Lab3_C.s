.include "m2560def.inc"

.def temp = r16
.def pattern = r17
.def count = r18

.def input_flag = r20
.def timer_flag = r19

.def show_leds = r21

.def debounce_flag_1 = r22
.def debounce_flag_2 = r23


//r20 is also taken for a counter

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
	rjmp RESET
.org INT0addr
	jmp EXT_INT0
.org INT1addr
	jmp EXT_INT1
.org OVF0addr
	jmp Timer0OVF         
	jmp DEFAULT      

DEFAULT:  reti       //return the interrupt without doing anything 

RESET:
	ldi temp, high(RAMEND)    //Initialises the stack pointers 
	out SPH, temp 
	ldi temp, low(RAMEND)
	out SPL, temp				//Stack initialised
	
	ser temp					//Writes 1's to port c indicating that we want this as an output 
	out DDRC, temp
		//Writes 1's to all the lights, this 
	ldi pattern, 0x00
	out PORTC, pattern //Explains when the board is reset all the lights turn on

	ldi temp, (2<<ISC00) //set INT0 as falling edge 
	sts EICRA, temp

	in temp, EIMSK
	ori temp, (1<<INT0)
	out EIMSK, temp

	ldi temp, (2<<ISC00) //set INT1 as falling edge 
	sts EICRA, temp

	in temp, EIMSK
	ori temp, (1<<INT1)
	out EIMSK, temp

	sei
	
	rjmp main					//Jumps to the main functions

EXT_INT0:
	push temp
	in temp, SREG
	push temp
	inc count

	//lsl pattern

	ldi debounce_flag_1, 1
	
	pop temp
	out SREG, temp
	pop temp
	reti

EXT_INT1:
	push temp
	in temp, SREG
	push temp

	inc count

	//lsl pattern
	//inc pattern

	ldi debounce_flag_2, 1

	pop temp
	out SREG, temp
	pop temp
	reti

Timer0OVF:				//Interrupt sub routine for the timer
	clr timer_flag
	in temp, SREG		
	push temp		//Prologue starts 
	push YH			//Pushes all the pointers to the stack 
	push YL
	push r25
	push r24		//Prologue ends

	lds r24, TempCounter	//Loads in the value of the temp counter
	lds r25, TempCounter+1
	adiw r25:r24,1 

	cpi r24, low(7812)	//Check if it has reached one second 
	ldi  temp, high(7812)
	cpc r25, temp

	brne  NotSecond

	cpi debounce_flag_1, 1
	breq debounce_flag_1_inst

	dfreturn1:

	cpi debounce_flag_2, 1
	breq debounce_flag_2_inst

	dfreturn2:

	cpi count, 8
	brge DISPLAY

	timer_return:

	clear TempCounter

	lds r24, SecondCounter
	lds r25, SecondCounter+1
	adiw r25:r24, 1	//Increase the second counter by 1

	sts SecondCounter, r24
	sts SecondCounter+1, r25
	rjmp EndIF

DISPLAY:
	out PORTC, pattern 
	jmp timer_return

debounce_flag_1_inst:
	lsl pattern
	clr debounce_flag_1
	jmp dfreturn1

debounce_flag_2_inst:
	lsl pattern
	inc pattern
	clr debounce_flag_2
	jmp dfreturn2

NotSecond:		//Stores the new value of the temp counter
	sts TempCounter, r24
	sts TempCounter+1, r25

EndIF:
	pop r24	//Epilogue 
	pop r25
	pop YL
	pop YH
	pop temp
	out SREG, temp
	reti

main:
		//Loads the pattern into the leds register
	clear TempCounter	//Clears the temp counter
	clear SecondCounter	//Clears the second counter

	ldi temp, 0b00000000	//Write 0's to timer counter 
	out TCCR0A, temp		
	ldi temp, 0b00000010	//Prescaler set to 8
	out TCCR0B, temp	
		
	ldi temp,  1<<TOIE0		// 128 microseconds it counts up
	sts TIMSK0, temp		

	sei						//Enable global interrupt

	clr timer_flag
	clr input_flag
	clr show_leds
	clr count
	clr temp

loop:
	 
	rjmp loop	

