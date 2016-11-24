
show_turntable:
	push r16
	push r17
	rcall go_home_lcd 
	shift_over 16

	lds r16, turntable_count

	cpi r16, 0
	breq dash
	
	cpi r16, 1
	breq b_slash
	cpi r16, 2
	breq pipe
	cpi r16, 3
	breq f_slash

	dash:
	ldi r16, '-'
	jmp turn_return

	b_slash:
	ldi r16, 0b10100100 
	jmp turn_return

	pipe:
	ldi r16, '|'
	jmp turn_return

	f_slash:
	ldi r16, '/'

	turn_return:

	do_lcd_data r16

	lds r16, turntable_direction
	cpi r16, 1
	//go clockwise, otherwise go counter
	breq show_clockwise

	lds r17, turntable_count
	inc r17
	cpi r17, 4 //gets to 8 then reset
	brne turn_no_reset 
	jmp ccw_reset //otherwise reset

	show_clockwise:
	lds r17, turntable_count
	dec r17
	cpi r17, 0 //gets to 0 then reset
	brne turn_no_reset

	ccw_reset:
	ldi r17, 0 // RESETS THE COUNTER
	jmp turn_no_reset
	cw_reset:
	ldi r17, 3
	turn_no_reset:
	sts turntable_count, r17
	
	pop r17
	pop r16
	ret