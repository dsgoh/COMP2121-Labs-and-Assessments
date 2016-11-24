.include "m2560def.inc"

interrupt_vectors:
.org 0x0000                jmp reset
.org 0x0002                jmp PB0_interrupt
.org 0x0004                jmp PB1_interrupt
.org 0x0006                jmp feedback_interrupt
.org 0x002A                jmp timer_interrupt
                           jmp timer_interrupt
                           jmp timer_interrupt

.equ counter0_a =          125                              ; counter reset MAX
.equ i_second =            250                            ; interrupts / second
.equ counter0_sc =         0b00000101                          ; prescaler / 1024
.equ d_interrupts =        20 * (i_second / 100 )               ; 100, nearly. odd to stagger interrupt service
.equ s_interrupts =        i_second / 2	                       ; screen update every 1/2 sec
.equ m_interrupts =        i_second / 4                       ; 11 is arbitrary, update motor 11 times a second

.dseg
f_counter:                 .byte 1
c_speed:                   .byte 1

d_timer:                   .byte 2 
PB0_counter:               .byte 1
PB1_counter:               .byte 1

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

; set up pins
ldi r16, 0x0
out DDRD, r16				                                   ; set portd to input
ldi r16, 0xFF
out DDRC, r16

; setup timer
ldi r16, 0b00000010
out	TCCR0A, r16                                                ; set to CTC
ldi r16, counter0_sc
out TCCR0B, r16                                                ; prescale 1/1024
ldi r16, counter0_a
out OCR0A, r16                                                 ; set resolution
clr r16
out TCNT0, r16

; set external interrupts
ldi r16, 0b00000111
out EIMSK, r16                                                 ; set interrupt mask
ldi r16, 0b00101010
sts EICRA, r16                                                 ; set portd to trigger on falling

; setup lcd
lcd_setup

;start the timer
ldi r16, 0b00000111
sts TIMSK0, r16

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
   do_timer(s, update_screen_time)
   do_timer(m, motor_time)
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
      sbrs r16, 1                                           ;     if debounce counters > 0
         dec debounce_counter                               ;        decrement debounce counters
      sts @0, debounce_counter
      .undef debounce_counter
   .endmacro
   dec_debounce_timer PB0_counter
   dec_debounce_timer PB1_counter
pop r16
pop r19
ret

update_screen_time:
push XH
push XL
push r16          .def current_speed = r16
; update screen: current speed
   ldi XH, high(lcd_line_1_buffer)
   ldi XL, low(lcd_line_1_buffer)
   rcall lcd_purge_buffer
   ldi XH, high(lcd_line_1_buffer)
   ldi XL, low(lcd_line_1_buffer)
   lds current_speed, c_speed
   rcall int_to_string
   call lcd_write_buffer
pop r16          .undef current_speed
pop XL
pop XH
ret

motor_time:
push r17         .def feedback_counter = r17
  lds r17, f_counter
  sts c_speed, r17
; if current speed < desired speed
;    increase motor power
; if desired speed < current speed
;    decrease motor power
  clr r17
  sts f_counter, r17
pop r17          .undef feedback_counter
ret

feedback_interrupt:
push r17         .def feedback_counter = r17
   lds feedback_counter, f_counter
   inc feedback_counter
   sts f_counter, feedback_counter			;  period timer = 0
pop r17          .undef feedback_counter
reti

PB1_interrupt: 
; if no debounce counter is set
;    increases the desired speed by 20 rps, no more than 100 rps
;    start a debounce counter
;    update screen: desired speed
reti

PB0_interrupt:
; if no debounce counter is set
;    decreases the desired speed by 20 rps, no less than 0 rps
;    start a debounce counter
;    update screen: desired speed
reti

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
