.include "m2560def.inc"

.def temp = r16
.def led = r17

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
.org OVF3addr
	jmp Timer3OVF         

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

Timer3OVF:				//Interrupt sub routine for the timer
	in temp, SREG		
	push temp		//Prologue starts 
	push YH			//Pushes all the pointers to the stack 
	push YL
	push r25
	push r24		

	push timer_high	//Pushes the timers to the stack 
		//Prologue ends

	lds r24, TempCounter	//Loads in the value of the temp counter
	lds r25, TempCounter+1
	adiw r25:r24,1 

	cpi r24, low(7812)	//Check if it has reached one second 
	ldi  temp, high(7812)
	cpc r25, temp

	brne  NotSecond

	sts OCR3BL, led
	lsr led 

	cpi led, 0
	breq resetLED
	timer_return:

	clear TempCounter //Resets the tempoary counter 

	lds r24, SecondCounter
	lds r25, SecondCounter+1
	adiw r25:r24, 1	//Increase the second counter by 1

	sts SecondCounter, r24
	sts SecondCounter+1, r25

	ldi timer_high, high(16)

	cpi r24, low(16)
	cpc r25, timer_high

	rjmp EndIF

resetLED:
	ser led
	jmp timer_return

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
	ser led
	clear TempCounter       ; Initialize the temporary counter to 0
    clear SecondCounter     ; Initialize the second counter to 0

    ; Timer3 initialisation
	ldi temp, 0b00001000
	sts DDRL, temp
	
	ldi temp, 0x4A
	sts OCR3AL, temp
	clr temp
	sts OCR3AH, temp

	ldi temp, (1<<CS50)
	sts TCCR3B, temp
	ldi temp, (1<<WGM30)|(1<<COM3A1)
	sts TCCR3A, temp
	
	ldi temp, 1<<TOIE3	
    sts TIMSK3, temp        ; T/C3 interrupt enable
   	
	; PWM Configuration

	; Configure bit PE2 as output
	ldi temp, 0b00010000
	ser temp
	out DDRE, temp ; Bit 3 will function as OC3B
	ldi temp, 0xFF ; the value controls the PWM duty cycle (store the value in the OCR registers)
	sts OCR3BL, temp
	clr temp
	sts OCR3BH, temp

	ldi temp, (1 << CS00) ; no prescaling
	sts TCCR3B, temp

	; PWM phase correct 8-bit mode (WGM30)
	; Clear when up counting, set when down-counting
	ldi temp, (1<< WGM30)|(1<<COM3B1)
	sts TCCR3A, temp

	sei

loop: rjmp loop	
