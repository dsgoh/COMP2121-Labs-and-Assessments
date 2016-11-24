#ifndef KEYPAD_ASM
#define KEYPAD_ASM

.include "m2560def.inc"
.include "function.asm"

.dseg
keypad_Xn: .byte	16
keypad_Bn: .byte	16

.cseg
keypad_Pn:	;		0			1			2			3	
			.db 0b11101011,	0b01110111, 0b01111011, 0b01111101
			;		4			5			6			7	
			.db 0b10110111, 0b10111011, 0b10111101, 0b11010111
			;		8			9			a			b	
			.db 0b11011011, 0b11011101, 0b01111110, 0b10111110
			;		c			d			*			#
			.db 0b11011110, 0b11101110, 0b11100111, 0b11101101

.cseg
.equ keypad_port = PortL
.equ keypad_DDR = DDRL
.equ keypad_pin = PinL
.equ keypad_timeout = 10

; tests the keypad and calls a function on each button press
; the passed function must take an input on r16 corresponding to
;	0x0-0x9 => keypad 0-9
; 	0xA-0xD => letters A-D
;   0xE => *
;	0xF => #
; and have no return value

.macro keypad_setup
  ldi r16, 0xF0
  sts keypad_DDR, r16
  clr r16
  clr r17
  ldi XH, high(keypad_Xn)
  ldi XL, low(keypad_Xn)
  ldi YH, high(keypad_Bn)
  ldi YL, low(keypad_Bn)
  clearer:
    st X+, r16
    st y+, r16
    inc r17
    cpi r17, 16
    brne clearer
.endmacro

keypad_action: fn_def 0, 2						;
  push XL
  push XH
  ldi XL, low(keypad_Xn)
  ldi XH, high(keypad_Xn)				; Xmem
  #define Xmem X
  push r17								; Xn
  .def Xn = r17
  push YL
  push YH
  ldi YL, low(keypad_Bn)
  ldi YH, high(keypad_Bn)				; Bmem
  #define Bmem Y
  push r18								; Bn
  .def Bn = r18
  push ZL
  push ZH
  ldi ZL, low(keypad_Pn<<1)
  ldi ZH, high(keypad_Pn<<1)			; Pmem
  #define Pmem Z
  push r19								; Pn
  .def Pn = r19
  push r20
  clr r20								; n
  .def n_counter = r20
  push r21								; current
  .def current = r21

keypad_loop:
    ld Xn, Xmem
	ld Bn, Bmem
	lpm Pn, Pmem
	ori Pn, 0x0f						; set port mask
	sts keypad_port, Pn					; set up port ready to read
	nop	nop nop nop								; let the port settle
	lds current, keypad_pin				; read port
	lpm Pn, Pmem
	or current, Pn						; mask read

    tst Xn
    breq Xn_0
    cpi Xn, 1
    breq Xn_1							; if Xn > 1 {
        dec Xn
        st Xmem, Xn						;   Xn = Xn - 1
        rjmp Xn_0
    Xn_1:
    tst Bn
    breq Xn_0
    cp Pn, current
    breq Xn_0							; } else if Xn = 1 and Bn and !Pn {
        clr Xn
        st Xmem, Xn						;   Xn = 0
        clr Bn
        st Bmem, Bn						;   Bn = 0
    Xn_0:								; }

if_Pn:
    cp Pn, current
    brne not_Pn							; if Pn {
        ldi Xn, keypad_timeout
        st Xmem, Xn						;   Xn = keypad_timeout
        tst Bn
        brne not_Bn						;   if !Bn {
            push YH
            push YL
            push ZH
            push ZL
            mov YH, FPH
            mov YL, FPL
			ld ZL, Y+
			ld ZH, Y
			mov r16, n_counter
			icall 						;     call indirect
			pop ZL
			pop ZH
			pop YL
			pop YH
			inc Bn
			st Bmem, Bn					;     Bn = 1
		not_Bn:							;   }
	not_Pn:								; }

    adiw X, 1
    adiw Y, 1
	adiw Z, 1
	inc n_counter
	cpi n_counter, 16
	brne keypad_loop
  .undef current
  pop r21
  .undef n_counter
  pop r20
  .undef Pn
  #undef Pmem
  pop r19
  pop ZH
  pop ZL
  .undef Bn
  #undef Bmem
  pop YH
  pop YL
  pop r18
  .undef Xn
  #undef Xmem
  pop ZH
  pop ZL
  pop r17
fn_ret

#endif
