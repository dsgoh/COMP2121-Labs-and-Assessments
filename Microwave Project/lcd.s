.include "delay.asm"

.equ LCD_RS = 7
.equ LCD_E = 6
.equ LCD_RW = 5
.equ LCD_BE = 4

.macro lcd_set
	sbi PORTA, @0
.endmacro
.macro lcd_clr
	cbi PORTA, @0
.endmacro

.macro do_lcd_command
	push r16
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
	pop r16
.endmacro

.macro do_lcd_data
	push r16
	.def led_temp = r16
	mov led_temp, @0
	rcall lcd_data
	rcall lcd_wait
	pop r16
	.undef led_temp
.endmacro

.macro shift_over
	push r17
	ldi r17, @0
	shift_function:
		do_lcd_command 0b0000010100
		dec r17
		cpi r17, 1
	brne shift_function
	pop r17
.endmacro

.macro lcd_setup
	push r16
	.def led_temp = r16
	ser led_temp
	out DDRF, led_temp
	out DDRA, led_temp
	clr led_temp
	out PORTF, led_temp
	out PORTA, led_temp

	do_lcd_command 0b00111000 ; //Sets the display for two lines
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; //Sets the display for two lines
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; //Sets the display for two lines
	do_lcd_command 0b00111000 ; //Sets the display for two lines

	do_lcd_command 0b00001000 ; display off?
	do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink

	pop r16
	.undef led_temp

.endmacro

lcd_command: //takes whatever is in r16 as a command
	out PORTF, r16
	rcall sleep_1ms 
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data: //takes whatever is in r16 and writes it 
	out PORTF, r16
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret

lcd_wait:
	//push r16
	.def led_temp = r16
	clr led_temp
	out DDRF, led_temp
	out PORTF, led_temp
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in led_temp, PINF
	lcd_clr LCD_E
	sbrc led_temp, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser led_temp
	out DDRF, led_temp
	//pop r16
	.undef led_temp
	ret

write_second_line:
	do_lcd_command 0b11000000
	ret

clear_screen:
	do_lcd_command 0b00000001
	ret

go_home_lcd:
	do_lcd_command 0b0000000010
	ret


; int to string, puts 
int_to_string: 				  ; ( str addr in x, number in r16 )						; restore x
  push XH
  push XL
  push r24
  push r23
  test_numbers:
  clr r24 
  clr r23
  test_100:
    cpi r16, 100
    brlo less_than_100
      subi r16, 100
      inc r24
      rjmp test_100
  less_than_100:
	tst r24
	breq test_10
	  adiw r24, '0'
      st X+, r24
	  ldi r23, 1
      clr r24
  test_10:
    cpi r16, 10
    brlo less_than_10
      subi r16, 10
      inc r24
      rjmp test_10
  less_than_10:
    tst r23
	brne add_tens
    tst r24
    breq add_units
  add_tens:
	  adiw r24, '0'
      st X+, r24
  add_units:
    mov r24, r16
    adiw r24, '0'
    st X, r24
	pop r23
  pop r24
  pop XL
  pop XH
ret

door_OC:
	push r16
	push r17
	rcall go_home_lcd
	rcall write_second_line
	shift_over 16		
	lds r17, door_stat
	cpi r17, 0
	breq doorClose
	cpi r17, 1
	breq doorOpen
	ret
	
	doorOpen:
		ldi r16, 'O'
		do_lcd_data r16
		rcall go_home_lcd
		jmp door_OC_FIN

	doorClose:
		ldi r16, 'C'
		do_lcd_data r16
		rcall go_home_lcd
	door_OC_FIN:
	pop r17
	pop r16
	ret

backlight:
	push r16
	ser r16
	sts OCR3BL, r16	; update the brightness
	pop r16
	ret