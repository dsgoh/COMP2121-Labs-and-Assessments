.set motor_port = DDRE

.set target_increment =    20
.equ debounce_interval =   5
.set initial_speed =       0

.dseg
d_speed:                   .byte 1
f_counter:                 .byte 1
c_speed:                   .byte 1

.cseg

.macro motor_setup
	; setup pwm timer
	/*
	ldi r16, 0b00100001
	sts TCCR3A, r16						; set timer 3 to 8 bit phase correct, set on inc, enable OC3B
	ldi r16, 0b00000000
	sts TIMSK3, r16						; start the timer
	*/
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
	sts TCCR5A, r16
	
	ldi r16, 0b00010000
	out motor_port, r16                                                  ; enable output pin
.endmacro


//Manages the speed of the motor when called 
motor_time:
	push r17         .def feedback_counter = r17
					 .def current_speed = r17
	push r18         .def desired_speed = r18
	lds feedback_counter, f_counter
	lds r18, c_speed
	asr r18
	add current_speed, r18
	;lsl current_speed                     ; speed is sampled at twice the rate, need to double to make up for
	sts c_speed, current_speed
	lds desired_speed, d_speed
	tst desired_speed
	breq set_zero_speed

	cp desired_speed, current_speed
	brlo check_for_faster                 ; if desired speed is slower
     
	 sub desired_speed, current_speed
	 asr desired_speed               ; reduce to minimise hunting
	 asr desired_speed
     lds current_speed, OCR3BL
	 add desired_speed, current_speed
	 cp desired_speed, current_speed
	 brsh save_faster_speed
        lds desired_speed, 0xff
     save_faster_speed:
     mov current_speed, desired_speed
     rjmp save_new_speed

  check_for_faster:
	  cp current_speed, desired_speed
	  brlo dont_change_speed                ; if desired speed is faster

     sub desired_speed, current_speed
     com desired_speed
     asr desired_speed
	 asr desired_speed
     lds current_speed, OCR3BL
	 sub current_speed, desired_speed
     lds desired_speed, OCR3BL
     cp desired_speed, current_speed
     brsh save_slower_speed
        lds current_speed, 0x00
     save_slower_speed:
     ;mov current_speed, desired_speed

     rjmp save_new_speed
set_zero_speed:
     clr current_speed
save_new_speed:
     sts OCR3BL, current_speed
dont_change_speed:
  clr feedback_counter
  sts f_counter, feedback_counter

	pop r18          .undef desired_speed
	pop r17          .undef feedback_counter
					 .undef current_speed  
	ret


//adjusts the speed
feedback_interrupt:
	push r17         .def feedback_counter = r17
	   lds feedback_counter, f_counter
	   inc feedback_counter
	   
	   sts f_counter, feedback_counter			;  period timer = 0
	   ldi r17, 1
	   out PORTC, r17
	pop r17          .undef feedback_counter
	reti