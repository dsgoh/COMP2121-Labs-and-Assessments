#ifndef DELAY_ASM
#define DELAY_ASM

.equ F_CPU = 16000000
.equ DELAY_A_MS = F_CPU / 4 / 1000 - 4

sleep_1ms:
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

sleep_5ms:
	rcall delay_1ms
	rcall delay_1ms
	rcall delay_1ms
	rcall delay_1ms
	rcall delay_1ms
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
#endif
