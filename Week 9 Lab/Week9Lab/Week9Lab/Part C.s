; The program gets input from keypad and displays its ascii value on the
; LED bar
.include "m2560def.inc"

//Just for keypad
.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def key_temp = r20
.def row_temp = r21

.equ PORTLDIR = 0xF0 ; PD7-4: output, PD3-0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F ; for obtaining input from Port D

//Just for lcd
.def led_temp = r22

//Reserved for push and pop functions
.def res_push = r24
.def res_pop = r25

//Debouncing and data
.def data_units = r26
.def data_tens = r27
.def data_hunds = r28

//Calculator 
.def accumulator = r29
.def calc_temp = r30
.def data_length = r31

.macro do_lcd_command
	ldi r22, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	mov led_temp, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.cseg
.org 0x0000 
	jmp RESET       //NORMAL JUMP 
	jmp DEFAULT     //Interrupt request bit 0 is set goto default
	jmp DEFAULT     //Interrupt request bit 1 is set goto default 
DEFAULT:  reti       //return the interrupt without doing anything 

RESET:	//KEYPAD
	ldi key_temp, low(RAMEND) ; initialize the stack
	out SPL, key_temp
	ldi key_temp, high(RAMEND)
	out SPH, key_temp
	ldi key_temp, PORTLDIR ; PA7:4/PA3:0, out/in

	sts DDRL, key_temp

	//LCD
	ldi led_temp, low(RAMEND)
	out SPL, led_temp
	ldi led_temp, high(RAMEND)
	out SPH, led_temp

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

	clr data_units
	clr data_tens
	clr data_hunds
	clr data_length
	clr accumulator
	clr key_temp

	// PRINT TO THE DISPLAY AT THE START
	subi accumulator, -'0' ; Add the value of character ‘0’
	subi data_units, -'0'

	do_lcd_command 0b00000001 ; clear display
	rcall sleep_5ms

	//go to start of bar and print accumulator 
	do_lcd_command 0b00000010
	do_lcd_data accumulator

	//go to second line
	do_lcd_command 0b11000000 //Shifts cursor to the bottom line
	do_lcd_data data_units	//print the data

	//Change the numbers to ascii 
	subi accumulator, '0' ; remove the value of character ‘0’
	subi data_units, '0'

	ser key_temp ; PORTC is output

	out DDRC, key_temp	
	out PORTC, key_temp

	jmp main

refresh_display:
	clr key_temp //this isnt currently being used and can be written over 

	cpi data_hunds, 1
	brge display_accumulator
	cpi data_tens, 1
	brge display_accumulator
	cpi data_units, 1
	brge display_accumulator

	do_lcd_command 0b00000001 ; clear display if theres no data on the bottom line

	display_accumulator:

	do_lcd_command 0b00000010 //Go home

	mov calc_temp, accumulator //make copy and put it in calc_temp

	cpi accumulator, 100
	brge hundred
	cpi accumulator, 10
	brge tens
	cpi accumulator, 0
	brge units

	hundred:
	inc key_temp
	sbci accumulator, 100
	cpi accumulator, 100
	brge hundred

	subi key_temp, -'0'
	do_lcd_data key_temp
	clr key_temp

	cpi accumulator, 10
	brlt pre_units

	tens:
	inc key_temp
	sbci accumulator, 10
	cpi accumulator, 10
	brge tens

	pre_units:
	subi key_temp, -'0'
	do_lcd_data key_temp
	clr key_temp

	units:
	inc key_temp
	sbci accumulator, 1
	cpi accumulator, 0
	brge units

	subi key_temp, -'/'
	do_lcd_data key_temp
	clr key_temp

	mov accumulator, calc_temp //restore the accumulator 

	cpi data_length, 4	//if the length of the pressed button is greater than 4
	brge main

	do_lcd_command 0b11000000 //Shifts cursor to the bottom line

	ldi key_temp, ' ' //Ready to write white space

	cpi data_length, 3
	brlt shift_one
	do_lcd_command 0b00010100 //Shift one to the right

	shift_one:
	cpi data_length, 2
	brlt shift_none
	do_lcd_command 0b00010100 //Shift one to the right

	shift_none:
	subi data_units, -'0'
	subi data_tens, -'0'
	subi data_hunds, -'0'
	
	do_lcd_data data_units	//print the data
	
	do_lcd_data key_temp
	do_lcd_data key_temp

	do_lcd_command 0b00010000
	do_lcd_command 0b00010000

	subi data_units, '0'	//Restore to what it once was
	subi data_tens, '0'
	subi data_hunds, '0'

	subi key_temp, 48
	out PORTC, accumulator ; Write value to PORTC
	
	jmp main

main:
	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column

colloop:
	cpi col, 4
	breq main ; If all keys are scanned, repeat.
	sts PORTL, cmask ; Otherwise, scan a column.
	ldi key_temp, 0xFF ; Slow down the scan operation.

delay: 
	dec key_temp
	brne delay
	lds key_temp, PINL ; Read PORTL
	andi key_temp, ROWMASK ; Get the keypad output value
	cpi key_temp, 0xF ; Check if any row is low
	breq nextcol
	; If yes, find which row is low
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row ; 

rowloop:
	cpi row, 4
	breq nextcol ; the row scan is over.
	mov row_temp, key_temp
	and row_temp, rmask ; check un-masked bit
	breq convert ; if bit is clear, the key is pressed
	inc row ; else move to the next row
	lsl rmask
	jmp rowloop

nextcol: ; if row scan is over
	lsl cmask
	inc col ; increase column value
	jmp colloop ; go to the next column

convert:
	cpi col, 3 ; If the pressed key is in col.3
	breq letters ; we have a letter
	; If the key is not in col.3 and
	cpi row, 3 ; If the key is in row3,
	breq symbols ; we have a symbol or 0
	mov key_temp, row ; Otherwise we have a number in 1-9
	lsl key_temp
	add key_temp, row
	add key_temp, col ; temp1 = row*3 + col
	subi key_temp, -1 ; Add the value of character ‘1’
	jmp convert_end

letters:
	clr calc_temp //Use this for counting 

	//Check if button B was pressed or button A
	cpi row, 1
	breq subtraction

	cpi row, 2
	breq multiply

	cpi row, 3
	breq division

	addition:

	add_units:
	add accumulator, data_units 
	
	mov calc_temp, data_tens
	add_tens:
	dec calc_temp
	sbci accumulator, -10
	cpi calc_temp, 0
	brne add_tens

	mov calc_temp, data_hunds

	add_hundreds:	//Add hundreds to the accumulator 
	dec calc_temp
	sbci accumulator, -100
	cpi calc_temp, 0
	brne add_hundreds

	jmp letters_final

	subtraction:

	sub accumulator, data_units 
	
	mov calc_temp, data_tens
	sub_tens:
	dec calc_temp
	sbci accumulator, 10
	cpi calc_temp, 0
	brne sub_tens

	mov calc_temp, data_hunds
	sub_hundreds:	//Add hundreds to the accumulator 
	dec calc_temp
	sbci accumulator, 100
	cpi calc_temp, 0
	brne sub_hundreds

	jmp letters_final

	multiply:

	jmp letters_final

	division:

	letters_final:
	
	clr data_units
	clr data_tens
	clr data_hunds
	clr data_length

	rcall wait_refresh

	jmp refresh_display

symbols:
	cpi col, 0 ; Check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	//What to do if hash was pressed
	

	jmp refresh_display

star:	//clear the accumulator
	jmp RESET

zero:
	clr key_temp ; Set to zero

convert_end:
	//Shift everything up 
	mov data_hunds, data_tens
	mov data_tens, data_units
	mov data_units, key_temp
	inc data_length
	clr key_temp
	rcall wait_refresh

	jmp refresh_display ; Restart main loop


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

;
; Send a command to the LCD (r16)
;
lcd_command:
	out PORTF, led_temp
	rcall sleep_1ms 
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret
lcd_data:
	out PORTF, led_temp
	lcd_set LCD_RS
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	lcd_clr LCD_RS
	ret
lcd_wait:
	push led_temp
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
	pop led_temp
	ret
.equ F_CPU = 16000000
.equ DELAY_1MS = F_CPU / 4 / 1000 - 4
; 4 cycles per iteration - setup/call-return overhead
sleep_1ms:	//runs enough operations to cover 1ms
	push r24
	push r25
	ldi r25, high(DELAY_1MS)
	ldi r24, low(DELAY_1MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret
sleep_5ms:
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	rcall sleep_1ms
	ret
sleep_20ms:
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	rcall sleep_5ms
	ret
sleep_100ms:
	rcall sleep_20ms
	rcall sleep_20ms
	rcall sleep_20ms
	rcall sleep_20ms
	rcall sleep_20ms
	ret

wait_refresh:
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	rcall sleep_100ms
	reti