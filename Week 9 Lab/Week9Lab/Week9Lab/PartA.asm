; The program gets input from keypad and displays its ascii value on the
; LED bar
.include "m2560def.inc"

.def row = r16 ; current row number
.def col = r17 ; current column number
.def rmask = r18 ; mask for current row during scan
.def cmask = r19 ; mask for current column during scan
.def key_temp = r20
.def row_temp = r21

.def subtract = r22

.equ PORTLDIR = 0xF0 ; PD7-4: output, PD3-0, input
.equ INITCOLMASK = 0xEF ; scan from the rightmost column,
.equ INITROWMASK = 0x01 ; scan from the top row
.equ ROWMASK = 0x0F ; for obtaining input from Port D

RESET:
	ldi key_temp, low(RAMEND) ; initialize the stack
	out SPL, key_temp
	ldi key_temp, high(RAMEND)
	out SPH, key_temp
	ldi key_temp, PORTLDIR ; PA7:4/PA3:0, out/in

	sts DDRL, key_temp
	ser key_temp ; PORTC is output

	out DDRC, key_temp	
	out PORTC, key_temp

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
	subi key_temp, -'1' ; Add the value of character ‘1’
	jmp convert_end

letters:
	ldi key_temp, 'A'
	add key_temp, row ; Get the ASCII value for the key
	jmp convert_end

symbols:
	cpi col, 0 ; Check if we have a star
	breq star
	cpi col, 1 ; or if we have zero
	breq zero
	ldi key_temp, '#' ; if not we have hash
	jmp convert_end

star:
	ldi key_temp, '*' ; Set to star
	jmp convert_end

zero:
	ldi key_temp, '0' ; Set to zero

convert_end:
	ldi subtract, 48
	sub key_temp, subtract
	out PORTC, key_temp ; Write value to PORTC
	jmp main ; Restart main loop