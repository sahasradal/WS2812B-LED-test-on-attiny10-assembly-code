;
; atiny10WS2812B.asm
;
; Created: 17/05/2022 19:21:34
; Author : Manama
; data order green red blue
; RHS signal lamp - clockwise - left to rhs sequence , cycle balanced to match lhs signal at the time of hazard operation


;pb0 dataout
;
.def data = r19


.dseg

pad1: .byte 1
pad2: .byte 1



.cseg


reset:
    LDI r16,0xD8		;setting clock divider change enable
	OUT CCP,r16
	LDI r16,0x00		; selecting internal 8MHz oscillator
	OUT CLKMSR, r16
	LDI r16,0xD8		; setting clock divider change enable
	OUT CCP,r16	
	LDI r16,(0<<CLKPS3)+(0<<CLKPS2)+(0<<CLKPS1)+(0<<CLKPS0);
	OUT CLKPSR,r16		; set to 8MHz clock (disable div8)
	LDI r16,0xFF		; overclock (from 4MHz(0x00) to 15 MHz(0xFF))
	OUT OSCCAL,r16
portsetup:
	ldi r16,0b0001		; load r16 with 0x1
	out ddrb,r16		; enable pb0 as output
	ldi r16,0b0000		; load r16 0x00
	out portb,r16		; port b low (0v)
	rcall LED_RESET		;put data line low,positive edge is the main factor
mainloop:
	rcall audi			;routine that lights up each led one by one until all LEDS are lit like a audi car indicator
;	rcall delay1		;761 cycles delay
;	rcall delay2		;251 cycles delay
;	nop					;1 cycle
;	nop					;1 cycle = total cycles till here 7627792 . this 1017 cycles added to synchronise with LHS signal which consumes 7627792 cycles to complete audi loop. will be unsynced in hazard operation.
	push r22			; save r22 to stack
	ldi r22,255			; load 255 for delay routine
	rcall delayms		; gives 331ms delay
	ldi r22,200			; load 255 for delay routine,5
	rcall delayms		; gives 331ms delay
	pop r22				; restore r22
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
	rcall blackout		;proc to kill the light for 331ms
	push r22			;
	ldi r22,255			;
	rcall delayms		;331ms   
	pop r22				;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	rjmp mainloop
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;Transmits 1 byte to the led matrix ,call 3 times for 1 led to transmit g,r,b data
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
bytetx:
	ldi r17,8			; number of bits 8
loop0:
	sbi portb,0			; set pb0 high
	nop					; 417ns = 0
	sbrc data,7			; if bit to be transmitted at position 7 is 0 skip next instruction of calling additional delay
	rcall ten66ns		; 1us = 1 (if bit 7 is 1 this instruction is executed and total delay of 1us for data to stay high)
	lsl data			; shift data out as we transmitted equalent pulse tp LED
	cbi portb,0			; pull pb0 low
	rcall ten66ns		; 1us = off time
	dec r17				; decrease bit counter
	brne loop0			; loop back until counter is 0
	ret					; return to caller


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;10 nano seconds delay
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	
ten66ns:
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;the ws2812 reset procedure
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LED_RESET:					;66us
	cbi portb,0
	ldi r16,255
loop1:
	dec r16
	brne loop1
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;delay routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
delay:
	push r16
	ldi r16,250
	rcall delay1
dd:	dec r16
	brne dd
	pop r16
	ret

delay1:
	push r20
	ldi r20,250
ddd:dec r20
	brne ddd
	pop r20
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 1 milli second delay routine
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
ms1:
	push r16
	ldi r16,10
msloop:
	rcall delay
	dec r16
	brne msloop
	pop r16
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
delayms:
;	ldi r22,16
delaymsloop:
	rcall ms1
	dec r22
	brne delaymsloop
	ret
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;RHS indicator lamp flash routine - leds sequence from lhs to Rhs / clockwise
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

audi:
	ldi r20,24				;load r20 with # of LEDs , tested with 24 led ring
	ldi r21,1				;load r21 with 1 (1st step ,will be increased by audiloop, max out at 24 steps for each led)
audiloop:
	rcall sendorange		;procedure to light up led with orange colour (car signal is yelow/orange)
	inc r22					;r22 is loop counter from 0 -24
	cp r22,r21				;check if r22 has looped the amount stored in r21 (if r21 is 1 ,1 led is lit , if 2 ,2 led lit)
	brne audiloop			;if r22 not equal to no of steps in r21 loop again
	ldi r22,24				;reach here when number of leds specified in r21 has already lit up (the remining leds need to be off)
	sub r22,r21				;subtract r22 with r21 the remaining number is the off leds
	breq alllit				;if r22 = r21 all leds are lit so branch to alllit label
blackloop:
	rcall sendblack			;send off frame to one led
	dec r22					;decrease r22
	brne blackloop			;loop till all remaining leds rae sent 0x00,0x00,0x00 frame
alllit:
	rcall LED_RESET			;send LED_RESET to latch data , 
	push r22				;save r22 for delay
	ldi r22,20		        ;load delay count
	rcall delayms			;20.4ms for value 16 on logic analyzer
	pop r22					;restore r22
	inc r21					;increase to be lighted led count by 1
	dec r20					;decrease led count as each led is lit up (used as condition check, al 24 leds lit up r20 =0)
	brne audiloop			; loop back till r20 = 0	
	ret						; return to caller
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;this procedure sends 24 off frames to each led to switch the entire indicator off , needed on continous power supply only
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
blackout:
	ldi r20,24				;load r20 with # of LEDs , here 24 leds on the ring from aliexpress
boloop:
	rcall sendblack			;call procedure to send 0s to all colours in each led 0x00,0x00,0x00
	dec r20					;decrease led counter
	brne boloop				;loop back till 24 sets are sent
	rcall LED_RESET			;sent led reset at the ned to latch sent data
	ret						;return to caller
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;sends 0x00,0x00,0x00 to led to make it off
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;	
sendblack:
	ldi data,0 ;green
	rcall bytetx
	ldi data,0 ;red
	rcall bytetx
	ldi data,0 ;blue
	rcall bytetx
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;sends colour data to led ,3 bytes , call as many times as many leds
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
sendorange:
	ldi data,50 ;green
	rcall bytetx
	ldi data,255 ;red
	rcall bytetx
	ldi data,0
	rcall bytetx
	ret
/*
delay2:
	push r20
	ldi r20,81
ddd2:dec r20
	brne ddd2
	pop r20
	ret
*/