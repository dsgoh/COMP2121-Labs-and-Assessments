.include "m2560def.inc"

.equ debugging = 0


.macro debug
  .if debugging != 0
    out portc, @0
  .endif
.endmacro


interrupt_vectors:
.org 0x0000                jmp reset
.org 0x0002                jmp up_button_interrupt
.org 0x0004                jmp down_button_interrupt
.org 0x0006                jmp feedback_interrupt
.org 0x002A                jmp timer_interrupt
                           jmp timer_interrupt
                           jmp timer_interrupt

.equ counter0_a =          125                             ; counter reset MAX
.equ i_second =            250                             ; interrupts / second
.equ d_interrupts =        (i_second / 250 )               ; 100, nearly. odd to stagger interrupt service
.equ s_interrupts =        i_second / (2)	               ; screen update every 1/2 sec
.equ m_interrupts =        i_second / (8)                  ; update 8 times a second
.set target_increment =    20
.equ debounce_interval =   5
.set initial_speed =       0

.dseg
f_counter:                 .byte 1
c_speed:                   .byte 1

d_timer:                   .byte 2 
ub_counter:                .byte 1
db_counter:                .byte 1

s_timer:                   .byte 2

m_timer:                   .byte 2
d_speed:                   .byte 1

.cseg .org 0x0080
.include "delay.asm"
.include "lcd.asm"

reset:
	; setup stack
	ldi r16, high(RAMEND)
	out SPH, r16
	ldi r16, low(RAMEND)
	out SPL, r16

	; setup control timer
	ldi r16, 0b00000010
	out	TCCR0A, r16                                                ; set to CTC
	ldi r16, counter0_a
	out OCR0A, r16                                                 ; set resolution
	clr r16
	out TCNT0, r16
	ldi r16, 0b00000111
	sts TIMSK0, r16

	; setup pwm timer
	ldi r16, 0b00100001
	sts TCCR3A, r16						; set timer 3 to 8 bit phase correct, set on inc, enable OC3B
	ldi r16, 0b00000000
	sts TIMSK3, r16						; start the timer

	; set external interrupts
	ldi r16, 0b00000111
	out EIMSK, r16                                                 ; set interrupt mask
	ldi r16, 0b00101010
	sts EICRA, r16                                                 ; set portd to trigger on falling

	; set up pins
	ldi r16, 0x0
	out DDRD, r16				                                   ; set portd to input
	ldi r16, 0b00010000
	out DDRE, r16                                                  ; enable output pin
	.if debugging != 0
	   ldi r16, 0xFF
	   out DDRC, r16
	.endif

; setup lcd
	lcd_setup
	.if debugging != 0
	   lcd_const 's'
	   lcd_const 'e'
	   lcd_const 't'
	.endif

	;start the timers
	ldi r16, 0b00000100
	sts TCCR3B, r16						; set timer 3 to /64 prescaler

	ldi r16, 0b00000101
	out TCCR0B, r16                     ; prescale 1/1024

	ldi r16, initial_speed
	sts d_speed, r16
	sts OCR3BL, r16
	rcall button_int_screen_update

sei

main:
rjmp main


#define do_timer(name, timer_action)          \
   .def TL = r24                              \
   .def TH = r25                              \
   lds TL, name##_timer                       \
   lds TH, name##_timer + 1                   \
   adiw TL, 1                                 \
   ldi r16, high(name##_interrupts)           \
   cpi TL, low(name##_interrupts)             \
   cpc TH, r16                                \
   brne name##_not_ints                       \
	  rcall timer_action                      \
      clr TL                                  \
	  clr TH                                  \
   name##_not_ints:                           \
   sts name##_timer + 1, TH                   \
   sts name##_timer, TL                       \
   .undef TH                                  \
   .undef TL

timer_interrupt:
	push r24
	push r25
	push r16
	   do_timer(d, debounce_time)
	   do_timer(m, motor_time)
	   do_timer(s, update_screen_time)
	pop r16
	pop r25
	pop r24
	reti

#undef do_timer

debounce_time:
	push r19
	push r16
	   .macro dec_debounce_timer
		  .def debounce_counter = r19
		  lds debounce_counter, @0
		  tst debounce_counter
		  in r16, SREG                                          ;     (test SREG for Z flag, macro has no control flow)
		  sbrs r16, SREG_Z                                      ;     if debounce counters > 0
			 dec debounce_counter                               ;        decrement debounce counters
		  sts @0, debounce_counter
		  .undef debounce_counter
	   .endmacro
	   dec_debounce_timer ub_counter
	   dec_debounce_timer db_counter
	pop r16
	pop r19
	ret

update_screen_time:
	push XH
	push XL
	push r16          .def current_speed = r16
	; update screen: current speed
	   ldi XH, high(lcd_line_2_buffer)
	   ldi XL, low(lcd_line_2_buffer)
	   rcall lcd_purge_buffer
	   ldi XH, high(lcd_line_2_buffer)
	   ldi XL, low(lcd_line_2_buffer)
	   lds current_speed, c_speed
	   rcall int_to_string
	   call lcd_write_buffer
	pop r16          .undef current_speed
	pop XL
	pop XH
	ret

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
debug desired_speed
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
debug current_speed
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

.if debugging != 0
	push r16
	   lds r16, d_speed
	   call button_int_screen_update
	pop r16
	.endif

	pop r18          .undef desired_speed
	pop r17          .undef feedback_counter
					 .undef current_speed  
	ret

feedback_interrupt:
push r17         .def feedback_counter = r17
   lds feedback_counter, f_counter
   inc feedback_counter
   sts f_counter, feedback_counter			;  period timer = 0
pop r17          .undef feedback_counter
reti

up_button_interrupt:
push r16         .def desired_speed = r16 
   lds r16, ub_counter
   tst r16
   brne ub_no_int
   ldi r16, debounce_interval
   sts ub_counter, r16
; if no debounce counter is set
;    increases the desired speed by 20 rps, no more than 100 rps
;    start a debounce counter
   lds desired_speed, d_speed
   cpi desired_speed, 100
   breq dont_add_10
      push r17
	  ldi r17, target_increment
	  add desired_speed, r17
	  pop r17
      sts d_speed, desired_speed
   dont_add_10:
   rcall button_int_screen_update
;    update screen: desired speed
   ub_no_int:
pop r16           .undef desired_speed
reti

down_button_interrupt:
; if no debounce counter is set
;    decreases the desired speed by 20 rps, no less than 0 rps
;    start a debounce counter
	push r16         .def desired_speed = r16 
	   lds r16, db_counter
	   tst r16
	   brne db_no_int
		  ldi r16, debounce_interval
		  sts db_counter, r16
		  lds desired_speed, d_speed
		  tst desired_speed
		  breq dont_sub_10
			 push r17
   			 ldi r17, target_increment
			 sub desired_speed, r17              ; subtract target amount
			 pop r17
			 sts d_speed, desired_speed
		  dont_sub_10:
		  rcall button_int_screen_update         ;    update screen: desired speed
	   db_no_int:
	pop r16           .undef desired_speed

	reti

button_int_screen_update:
push XH
push XL
push r16
   ldi XH, high(lcd_line_1_buffer)
   ldi XL, low(lcd_line_1_buffer)
   rcall lcd_purge_buffer
   ldi XH, high(lcd_line_1_buffer)
   ldi XL, low(lcd_line_1_buffer)
   rcall int_to_string
   .if debugging != 0
      adiw X, 5
      lds r16, OCR3BL
      rcall int_to_string
   .endif
   call lcd_write_buffer
pop r16
pop XL
pop XH
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
