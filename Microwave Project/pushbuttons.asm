

close_button:			//close door button right button PB0

	in temp, SREG	
    push temp    
	push r16

	ldi r16, 0
	out PORTG, r16
	   

	lds r16, door_stat
	cpi r16, 0
	breq END_INT0

	ldi r16, 0	// set to closed
	sts door_stat, r16

	rcall door_OC	// update door status

	clr temp
	out PORTG, temp				// turn topmost LED off

	
	lds temp, mode
	cpi temp, 1					
	breq END_INT0
	cpi temp, 0					// dont start from door close if in entry mode
	breq END_INT0

	ldi temp, 1
	sts mode, temp				// set mode to running


	rjmp END_INT0

END_INT0:
	pop r16
    pop temp
    out SREG, temp
    reti            // Return from the interrupt.


open_button:		// open door	left button PB1
	in temp, SREG	
    push temp  
	push r16  
	ldi r16, 2
	out PORTG, r16
	ser temp
	out PORTD, temp

	
	lds temp, mode			// if finished, go back to entry mode
	cpi temp, 3
	breq backToEntry

	lds r16, door_stat
	cpi r16, 1				// if its already open do nothing	
	breq END_INT1

//	turn_led_on

	
	ldi r16, 1		// change doorOpenClose variable so that its open
	sts door_stat, r16

	ldi r16, ENTRY_MODE
	sts mode, r16

	rcall door_OC
	lds temp, mode			// check mode
	cpi temp, 1				// if its running jump to pauseMode
	breq changeToPause

	rjmp END_INT1

changeToPause:
	ldi temp, 2
	sts mode, temp
	jmp END_INT1

backToEntry:
	ldi temp, 0
	sts mode, temp
	jmp END_INT1

END_INT1:
	pop r16
    pop temp
    out SREG, temp
    reti            // Return from the interrupt.	
