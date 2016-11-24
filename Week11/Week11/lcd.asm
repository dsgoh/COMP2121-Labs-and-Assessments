#ifndef LCD_ASM
#define LCD_ASM

.include "m2560def.inc"
.include "delay.asm"

.set LCD_RS = 7
.set LCD_E = 6
.set LCD_RW = 5
.set LCD_BE = 4
.set lcd_control = PortA
.set lcd_data = PortF
.equ set_new_line_1 = 0b10000000
.equ set_new_line_2 = 0b11000000
.equ clear = 0b00000001

.dseg 	lcd_line_buffer:
		lcd_line_1_buffer: .byte 17
		lcd_line_2_buffer: .byte 17

.cseg

.macro do_lcd_data
	ldi r16, @0
	rcall lcd_data
	rcall lcd_wait
.endmacro

.macro lcd_command
	ldi r16, @0
	out lcd_data, r16
	call delay_1ms
	sbi lcd_control, LCD_E
	call delay_1ms
	cbi lcd_control, LCD_E
	call lcd_wait
.endmacro

.macro lcd_char
	out lcd_data, @0
	sbi lcd_control, LCD_RS
	call delay_1ms
	sbi lcd_control, LCD_E
	call delay_1ms
	cbi lcd_control, LCD_E
	cbi lcd_control, LCD_RS
	call lcd_wait
.endmacro

.macro lcd_const
	ldi r16, @0
	lcd_char r16
.endmacro

.macro lcd_setup
   ser r16
   out DDRF, r16
   out DDRA, r16
   clr r16
   out lcd_data, r16
   out lcd_control, r16
   ldi XH, high(lcd_line_1_buffer)
   ldi XL, low(lcd_line_1_buffer)
   rcall lcd_purge_buffer
   ldi XH, high(lcd_line_2_buffer)
   ldi XL, low(lcd_line_2_buffer)
   rcall lcd_purge_buffer
   lcd_command 0b00111000 ; 2x5x7
   rcall delay_1ms
   rcall delay_1ms
   rcall delay_1ms
   rcall delay_1ms
   rcall delay_1ms
   rcall delay_1ms
   lcd_command 0b00111000 ; 2x5x7
   rcall delay_1ms
   rcall delay_1ms
   lcd_command 0b00111000 ; 2x5x7
   lcd_command 0b00111000 ; 2x5x7
   lcd_command 0b00001000 ; display off?
   lcd_command 0b00000001 ; clear display
   lcd_command 0b00000110 ; increment, no display shift
   lcd_command 0b00001100 ; Cursor on, bar, no blink
.endmacro

lcd_purge_buffer: ; purges buffer pointed to X
   push r16				.def counter = r16
   push r17				.def space = r17
   clr r16
   ldi space, ' '
   lcd_purge_loop:
     st X+, space
     inc counter
     cpi counter, 17
   brne lcd_purge_loop
   pop r17				.undef space
   pop r16				.undef counter
ret

lcd_write_buffer:
   push r16
   push ZL
   push ZH
   lcd_command set_new_line_1
   ldi ZH, high(lcd_line_1_buffer)
   ldi ZL, low(lcd_line_1_buffer)
   clr r16
   std Z+16, r16
   rcall write_data_string

   lcd_command set_new_line_2
   ldi ZH, high(lcd_line_2_buffer)
   ldi ZL, low(lcd_line_2_buffer)
   clr r16
   std Z+16, r16
   rcall write_data_string
   pop ZH
   pop ZL
   pop r16
ret

write_code_string:; Z
   push r16
   code_loader:
   lpm r16, Z+
   tst r16
   breq code_breaker
   lcd_char r16
   rcall write_code_string
   code_breaker:
   pop r16
ret

write_data_string:; Z
   push r16
   data_loader:
   ld r16, Z+
   tst r16
   breq data_breaker
;      out portc, r16
	  lcd_char r16
	  rjmp data_loader
   data_breaker:
   pop r16
ret

lcd_wait:
	push r16
	clr r16
	out DDRF, r16
	out lcd_data, r16
	sbi lcd_control, LCD_RW
lcd_wait_loop:
	rcall delay_1ms
	sbi lcd_control, LCD_E
	rcall delay_1ms
	in r16, PINF
	cbi lcd_control, LCD_E
	sbrc r16, 7
	rjmp lcd_wait_loop
	cbi lcd_control, LCD_RW
	ser r16
	out DDRF, r16
	pop r16
ret

#endif
