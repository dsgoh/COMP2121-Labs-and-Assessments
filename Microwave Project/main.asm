; The program gets input from keypad and displays its ascii value on the
; LED bar
.include "m2560def.inc"

.set ENTRY_MODE				= 0
.set PAUSE_MODE				= 1
.set RESUME_MODE			= 2
.set FINISH_MODE			= 3

.equ FREQ1					= 95 ; will generate 600 Hz
.equ FREQ2					= 47 ; will generate 1200 Hz
.def temp					= r30

.dseg
power_level:			   .byte 1 
mode:					   .byte 1 // 0 is entry, 1 is paused, 2 is resume, 3 is finished
min_t:      			   .byte 1
sec_t:		        	   .byte 1
turntable_count:		   .byte 1
turntable_direction:	   .byte 1

led:					   .byte 1
SecondCounter:			   .byte 2               
TempCounter:               .byte 2 
door_stat:				   .byte 1
ub_counter:                .byte 1
db_counter:                .byte 1


.cseg
.org 0x0000 
	jmp RESET       //NORMAL JUMP 
.org INT0addr
	jmp open_button
.org INT1addr
	jmp close_button
.org OVF0addr
	jmp timer_interrupt     
	jmp DEFAULT   

DEFAULT:  reti       //return the interrupt without doing anything 

.macro clear	//Clears a word 2 bytes in memory 
	push r16
	ldi YL, low(@0)
	ldi YH, high(@0)     
	ldi r16, 0
	st Y+, r16
	st Y, r16 
	pop r16               
.endmacro

jmp RESET

.include "lcd.s"
.include "delay.asm"
.include "keypad.asm"
.include "turntable.s"
.include "pushbuttons.asm"
//.include "motor.s"

RESET:	
	ldi key_temp, low(RAMEND) ; initialize the stack
	out SPL, key_temp
	ldi key_temp, high(RAMEND)
	out SPH, key_temp

	keypad_setup
	lcd_setup
	//motor_setup

	//buttons	ldi temp, (2<<ISC00) //set INT0 as falling edge 
	sts EICRA, temp

	in temp, EIMSK
	ori temp, (1<<INT0)
	out EIMSK, temp

	ldi temp, (2<<ISC00) //set INT1 as falling edge 
	sts EICRA, temp

	in temp, EIMSK
	ori temp, (1<<INT1)
	out EIMSK, temp

	ser r16 ; PORTC is output

	//out DDRC, r16	
	//out PORTC, r16

	out DDRG, r16	
	//out PORTG, r16

	clear TempCounter	//Clears the temp counter
	clear SecondCounter	//Clears the second counter
	clear turntable_count
	
	
	ldi r16, 0b00000000	//Write 0's to timer counter 
	out TCCR0A, r16		
	ldi r16, 0b00000010	//Prescaler set to 8
	out TCCR0B, r16	
		
	ldi r16,  1<<TOIE0		// 128 microseconds it counts up
	sts TIMSK0, r16
	/*
	//motor
	ldi r16, 0b00001000
	sts DDRL, r16 ; Bit 3 will function as OC5A.
	ldi r16, 0x4A ; the value controls the PWM duty cycle
	sts OCR5AL, r16
	clr r16
	sts OCR5AH, r16
	; Set the Timer5 to Phase Correct PWM mode.
	ldi r16, (1 << CS50)
	sts TCCR5B, r16
	ldi r16, (1<< WGM50)|(1<<COM5A1)
	sts TCCR5A, r16	*/

	//rcall feedback_interrupt
	clr r16
	clr r17
	clr r18
	clr r19
	clr r20
	clr r21
	clr r22
	clr r23
	clr r24
	clr r25
	clr r26
	clr r27
	clr r28
	clr r29
	clr r30
	clr r31
	
	sei

	jmp start_keypad

timer_interrupt:
	in r16, SREG
	push r16		//Prologue starts 
	push YH			//Pushes all the pointers to the stack 
	push YL
	push r25
	push r24		//Prologue ends

	lds r24, TempCounter	//Loads in the value of the temp counter
	lds r25, TempCounter+1
	adiw r25:r24,1 

	cpi r24, low(7812)	//Check if it has reached one second 
	ldi r16, high(7812)
	cpc r25, r16

	brne  NotSecond

	//rcall motor_time

	lds r16, mode
	cpi r16, RESUME_MODE
	breq count_down

	rcall print_mode

	rcall backlight
	

	timer_return:

	clear TempCounter

	lds r24, SecondCounter
	lds r25, SecondCounter+1
	adiw r25:r24, 1	//Increase the second counter by 1

	sts SecondCounter, r24
	sts SecondCounter+1, r25
	rjmp EndIF

count_down:
	push r17
	lds r17, sec_t
	cpi r17, 0
	breq deduct_minute

	subi r17, 1
	sts sec_t, r17

	jmp count_down_return

	deduct_minute:
	lds r17, min_t
	cpi r17, 0
	breq count_down_finished

	subi r17, 1
	sts min_t, r17
	//set seconds to 59
	ldi r17, 59
	sts sec_t, r17
	jmp count_down_return

	count_down_finished:
	lds r17, FINISH_MODE
	sts mode, r17	

	count_down_return:
	rcall show_time
	rcall show_turntable
	pop r17
	jmp timer_return
	

NotSecond:		//Stores the new value of the temp counter
	sts TempCounter, r24
	sts TempCounter+1, r25

EndIF:
	pop r24	//Epilogue 
	pop r25
	pop YL
	pop YH
	pop r16
	out SREG, r16
	reti

refresh_display:
	rcall clear_screen
	rcall print_mode
	jmp keypad

print_mode: // 0 is entry, 1 is paused, 2 is resume, 3 is finished
	push r16
	push r17
	.def r_mode = r17

	lds r_mode, mode
	
	cpi r_mode, ENTRY_MODE
	breq print_entry_mode

	cpi r_mode, PAUSE_MODE
	breq print_pause_mode

	cpi r_mode, RESUME_MODE
	breq print_resume_mode

	//otherwise go to finished mode

	rcall print_finish

	jmp print_ret

	print_resume_mode:
	//WRITE WHAT TO PRINT HERE WHEN IN RESUME MODE
	rcall show_time
	
	rcall write_second_line
	ldi r16, 'r'
	do_lcd_data r16

	jmp print_ret

	print_pause_mode:

	rcall write_second_line
	ldi r16, 'p'
	do_lcd_data r16

	//WRITE WHAT TO PRINT WHEN IN PAUSE
	jmp print_ret

	print_entry_mode:
	rcall show_time

	rcall write_second_line
	ldi r16, 'D'
	do_lcd_data r16
	ldi r16, '6'
	do_lcd_data r16

	/*
	lds r16, turntable_direction
	//flip rotation direction 
	cpi r16, 1
	breq flip_bit 

	ldi r16, 1
	sts turntable_direction, r16
	jmp print_ret

	flip_bit:
	ldi r16, 0
	sts turntable_direction, r16
	*/
	print_ret:
	rcall door_OC
	pop r17
	.undef r_mode
	pop r16
	ret

print_finish:
	rcall clear_screen
	ldi r16, 'D'
	do_lcd_data r16
	ldi r16, 'o'
	do_lcd_data r16
	ldi r16, 'n'
	do_lcd_data r16
	ldi r16, 'e'
	do_lcd_data r16

	rcall write_second_line

	ldi r16, 'R'
	do_lcd_data r16
	ldi r16, 'e'
	do_lcd_data r16
	ldi r16, 'm'
	do_lcd_data r16
	ldi r16, 'o'
	do_lcd_data r16
	ldi r16, 'v'
	do_lcd_data r16
	ldi r16, 'e'
	do_lcd_data r16
	ldi r16, ' '
	do_lcd_data r16
	ldi r16, 'f'
	do_lcd_data r16
	ldi r16, 'o'
	do_lcd_data r16
	ldi r16, 'o'
	do_lcd_data r16
	ldi r16, 'd'
	do_lcd_data r16

	ret
show_time:
	push r16
	.def curr_val = r16
	push r17
	.def num_temp = r17
	push r18
	.def seconds_printed = r18 //checks if seconds has been printed
	
	clr num_temp
	clr seconds_printed

	rcall go_home_lcd //set the cursor to the start of the lcd

	//load minutes 
	lds curr_val, min_t
	show_time_loop:
	cpi curr_val, 10
	brge show_tens

	jmp print_tens

	show_tens:
	inc num_temp
	subi curr_val, 10
	cpi curr_val, 10
	brge show_tens

	print_tens:
	subi num_temp, -'0'
	do_lcd_data num_temp
	clr num_temp

	print_units:
	subi curr_val, -'0'
	do_lcd_data curr_val
	clr num_temp

	cpi seconds_printed, 1
	breq show_time_final

	ldi num_temp, ':'
	do_lcd_data num_temp

	//Now load the seconds in and repeat
	lds curr_val, sec_t
	inc seconds_printed
	clr num_temp
	jmp show_time_loop

	show_time_final:
	pop r18
	.undef seconds_printed
	pop r17
	.undef num_temp
	pop r16
	.undef curr_val
	ret
