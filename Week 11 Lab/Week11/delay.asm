#ifndef DELAY_ASM
#define DELAY_ASM


.equ F_CPU = 16000000
.equ DELAY_A_MS = F_CPU / 4 / 1000 - 4

delay_1ms:
	push r24
	push r25
	ldi r25, high(DELAY_A_MS)
	ldi r24, low(DELAY_A_MS)
delayloop_1ms:
	sbiw r25:r24, 1
	brne delayloop_1ms
	pop r25
	pop r24
	ret

#endif
