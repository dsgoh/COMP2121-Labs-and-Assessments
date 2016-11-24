.include "m2560def.inc"

.def row = r17 ; current row number
.def col = r18 ; current column number
.def rmask = r19 ; mask for current row during scan
.def cmask = r20 ; mask for current column during scan
.def temp1 = r21
.def temp2 = r22

.def subtract = r23
		//r24 and r25 are used for pushing and popping
.def debounce = r26
.def timer_flag = r27

.equ PORTLDIR = 0xF0 ; PD7-4: output, PD3-0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F ; for obtaining input from Port D

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
	ldi r16, @0
	rcall lcd_command
	rcall lcd_wait
.endmacro
.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro clear	//Clears a word 2 bytes in memory 
	ldi YL, low(@0)
	ldi YH, high(@0)     
	clr temp1
	st Y+, temp1
	st Y, temp1              
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
	jmp DEFAULT      
DEFAULT:  jmp calc       

Timer0OVF:				//Interrupt sub routine for the timer
	clr timer_flag
	in temp1, SREG		
	push temp1		//Prologue starts 
	push YH			//Pushes all the pointers to the stack 
	push YL
	push r25
	push r24		//Prologue ends
	lds r24, TempCounter	//Loads in the value of the temp counter
	lds r25, TempCounter+1
	adiw r25:r24,1 
	cpi r24, low(7812)	//Check if it has reached one second 
	ldi  temp1, high(7812)
	cpc r25, temp1
	brne NotSecond
	cpi debounce, 1
	brne timer_return

	convert_end:
		//Write value to the screen 
		do_lcd_data '1'
		clr debounce
	timer_return:
		clear TempCounter
		lds r24, SecondCounter
		lds r25, SecondCounter+1
		adiw r25:r24, 1	//Increase the second counter by 1
		sts SecondCounter, r24
		sts SecondCounter+1, r25
	rjmp ENDIF
	jmp calc

NotSecond:		//Stores the new value of the temp counter
	sts TempCounter, r24
	sts TempCounter+1, r25
EndIF:
	pop r24	//Epilogue 
	pop r25
	pop YL
	pop YH
	pop temp1
	out SREG, temp1
	reti

RESET:
	ldi temp1, low(RAMEND) ; initialize the stack
	out SPL, temp1
	ldi temp1, high(RAMEND)
	out SPH, temp1
	ldi temp1, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, temp1 //Get input from keypad
	ser temp1 
	ser r16		//r16 is used only for the display functions,
	out DDRF, r16  //reloading r16 from stack pointer allows this to continue 
	out DDRA, r16
	clr r16
	out PORTF, r16
	out PORTA, r16
	ldi temp1, (2<<ISC00) //set INT0 as falling edge 
	sts EICRA, temp1
	in temp1, EIMSK
	ori temp1, (1<<INT0)
	out EIMSK, temp1
	ldi temp1, (2<<ISC00) //set INT1 as falling edge 
	sts EICRA, temp1
	in temp1, EIMSK
	ori temp1, (1<<INT1)
	out EIMSK, temp1
	sei
DISP_CLEAR:
	do_lcd_command 0b00111000 ; //Sets the display for two lines
	rcall sleep_5ms
	do_lcd_command 0b00111000 ; //Sets the display for two lines
	rcall sleep_1ms
	do_lcd_command 0b00111000 ; //Sets the display for two lines
	do_lcd_command 0b00111000 ; //Sets the display for two lines
	do_lcd_command 0b00001000 ; display off?
	//do_lcd_command 0b00000001 ; clear display
	do_lcd_command 0b00000110 ; increment, no display shift
	do_lcd_command 0b00001110 ; Cursor on, bar, no blink
	//do_lcd_command 0b00000001 ; clear display
calc:
	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column
colloop:
	cpi col, 4
	breq calc ; If all keys are scanned, repeat.
	sts PORTL, cmask ; Otherwise, scan a column.
	ldi temp1, 0xFF ; Slow down the scan operation.
delay: 
	dec temp1
	brne delay
	lds temp1, PINL ; Read PORTL
	andi temp1, ROWMASK ; Get the keypad output value
	cpi temp1, 0xF ; Check if any row is low
	breq nextcol
	; If yes, find which row is low
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row ; 
rowloop:
	cpi row, 4
	breq nextcol ; the row scan is over.
	mov temp2, temp1
	and temp2, rmask ; check un-masked bit
	breq convert ; if bit is clear, the key is pressed
	inc row ; else move to the next row
	lsl rmask
	jmp rowloop
nextcol: ; if row scan is over
	lsl cmask
	inc col ; increase column value
	jmp colloop ; go to the next column
letters:
	ldi temp1, 'A'
	add temp1, row ; Get the ASCII value for the key
	jmp convert_end
symbols:
	cpi col, 0 ; Check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi temp1, '#' ; if not we have hash
	jmp convert_end
star:
	ldi temp1, '*' ; Set to star
	jmp convert_end
convert:
	//cpi debounce, 1
	//breq calc //If debouncing is already turned on go to calc
	ldi debounce, 1 //Otherwise turn debouncing on
	cpi col, 3 ; If the pressed key is in col.3
	breq letters ; we have a letter
	; If the key is not in col.3 and
	cpi row, 3 ; If the key is in row3,
	breq symbols ; we have a symbol or 0
	mov temp1, row ; Otherwise we have a number in 1-9
	lsl temp1
	add temp1, row
	add temp1, col ; temp1 = row*3 + col
	subi temp1, -'1' ; Add the value of character ‘1’
	jmp convert_end
zero:
	ldi temp1, '0' ; Set to zero
	rjmp convert_end

;
; Send a command to the LCD (r16)
;

lcd_command:
	out PORTF, r16
	rcall sleep_1ms 
	lcd_set LCD_E
	rcall sleep_1ms
	lcd_clr LCD_E
	rcall sleep_1ms
	ret

lcd_data:
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
	push r16
	clr r16
	out DDRF, r16
	out PORTF, r16
	lcd_set LCD_RW
lcd_wait_loop:
	rcall sleep_1ms
	lcd_set LCD_E
	rcall sleep_1ms
	in r16, PINF
	lcd_clr LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	lcd_clr LCD_RW
	ser r16
	out DDRF, r16
	pop r16
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
