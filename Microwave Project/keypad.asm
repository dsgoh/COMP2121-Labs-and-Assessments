.include "m2560def.inc"
.include "delay.asm"


.def row =			r16 ; current row number
.def col =			r17 ; current column number
.def rmask =		r18 ; mask for current row during scan
.def cmask =		r19 ; mask for current column during scan
.def key_temp =		r20
.def row_temp =		r21

.dseg
debounce:			.byte 1

.cseg
.equ PORTLDIR = 0xF0 ; PD7-4: output, PD3-0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F ; for obtaining input from Port D

; tests the keypad and calls a function on each button press
; the passed function must take an input on r16 corresponding to
;	0x0-0x9 => keypad 0-9
; 	0xA-0xD => letters A-D
;   0xE => *
;	0xF => #
; and have no return value

.macro keypad_setup
	push r16
	clr r16
	ldi r16, PORTLDIR ; PA7:4/PA3:0, out/in
	sts DDRL, r16
	lds r16, debounce
	clr r16
	sts debounce, r16
	pop r16
.endmacro

start_keypad:
	clr row
	clr col
	clr rmask
	clr cmask
	clr key_temp
	clr row_temp
keypad:
	ldi cmask, INITCOLMASK ; initial column mask
	clr col ; initial column

	lds temp, door_stat
	cpi temp, 1
	breq keypad

colloop:
//	cpi debounceflag, 1
	//breq colloop
	cpi col, 4
	breq keypad ; If all keys are scanned, repeat.
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
	//ldi debounceflag, 1
	ldi rmask, INITROWMASK ; Initialize for row check
	clr row ; 

rowloop:
	//cpi debounceflag, 1
	//breq rowloop
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
	// 0 is entry, 1 is paused, 2 is resume, 3 is finished
	//Check if button B was pressed or button A
	//push r16

	push r27
	.def let_temp = r27
	push r28

	lds r28, min_t

	//cpi row, 1 nothing for B

	cpi row, 2
	breq letter_C

	cpi row, 3
	breq letter_D


	jmp letters_final

	letter_C:
	lds let_temp, sec_t
    cpi let_temp, 70
	brge minus_60
	subi let_temp, -30
	sts sec_t, let_temp
	
	rjmp letters_final

	letter_D:
	lds let_temp, sec_t
	cpi let_temp, 30
	brlt add_60
	subi let_temp, 30
	sts sec_t, let_temp
	
	rjmp letters_final

	minus_60:
	cpi r28, 99
	breq letters_final
	
	subi let_temp, 60
	subi let_temp, -30
	sts sec_t, let_temp
	lds let_temp, min_t
	inc let_temp
	sts min_t, let_temp
	rjmp letters_final

	add_60:
	cpi r28, 0
	breq letters_final
	subi let_temp, -60
	subi let_temp, 30
	sts sec_t, let_temp
	lds let_temp, min_t
	dec let_temp
	sts min_t, let_temp

	letters_final:
	pop r28
	pop r27
	.undef let_temp
	rcall wait_refresh
	jmp refresh_display
	//jmp keypad

symbols:
	cpi col, 0 ; Check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	//What to do if hash was pressed
	push r16

	lds r16, mode
	cpi r16, ENTRY_MODE
	breq symbols_reset_nums

	ldi r16, ENTRY_MODE
	sts mode, r16
	jmp symbol_finish

	symbols_reset_nums:
	clr r16
	sts min_t, r16
	sts sec_t, r16

	symbol_finish:
	
	pop r16

	jmp refresh_display
	//jmp keypad

star:	//change mode to resume, if min and sec are empty add one minute and start
	//check if min and sec are empty
	push temp

	lds temp, mode
	cpi temp, RESUME_MODE
	breq star_add_minute

	lds temp, sec_t
	cpi temp, 1
	brge star_finish

	lds temp, min_t
	cpi temp, 1
	brge star_finish

	ldi temp, 1		//otherwise add one minute
	sts min_t, temp
	jmp star_finish

	star_add_minute:
	//lds temp, min_t
	//inc temp
	//sts min_t, temp


	star_finish:		//Start the thing moving
	ldi temp, RESUME_MODE
	sts mode, temp

	pop temp

	jmp refresh_display
	//jmp keypad

zero:
	ldi key_temp, 0 ; Set to zero

convert_end:
	//Shift everything up 
	push r24
	.def r_min = r24
	push r25 
	.def r_sec = r25
	push r26 //DUMMY
	push r27
	.def counter = r27

	lds r_min, min_t
	lds r_sec, sec_t

	//check if tens unit of min is set 
	//overwrite it 
	cpi r_min, 10
	brge remove_top_tens_bit
	convert_continue_as_normal:
 
	ldi r26, 10

	mul r_min, r26 //moves unit minute up
	mov r_min, r0

	cpi r_sec, 10
	brlt convert_sec

	//moves upper second to to lower minute
	convert_loop:
		inc counter
		subi r_sec, 10
		cpi r_sec, 10
	brge convert_loop

	add r_min, counter

	convert_sec:

	//multiply up by 10
	mul r_sec, r26
	mov r_sec, r0

	//inc r_sec //ADD INTEGER HERE

	add r_sec, key_temp

	

	sts min_t, r_min
	sts sec_t, r_sec	

	pop r27
	.undef counter
	pop r26
	pop r25
	.undef r_sec
	pop r24
	.undef r_min

	clr key_temp
	rcall wait_refresh

	jmp refresh_display ; Restart main loop
	//jmp start_keypad

 remove_top_tens_bit:
	
	subi r24, 10
	cpi r24, 10
	brge remove_top_tens_bit

	jmp convert_continue_as_normal
