		AREA	MAIN_CODE, CODE, READONLY
		GET		LPC213x.s
		
DIGIT_0	RN	8
DIGIT_1	RN	9
DIGIT_2	RN	10
DIGIT_3	RN	11

CURR_DIG RN 12
		
		ENTRY
__main
__use_two_region_memory
		EXPORT			__main
		EXPORT			__use_two_region_memory
		
		; ustawienie pinów sterujacych wyswietlaczem na wyjsciowe
		ldr				r1, =IO0DIR
		ldr				r0, =0xF0000
		str				r0, [r1]
		
		ldr				r1, =IO1DIR
		ldr				r0, =0xFF0000
		str				r0, [r1]

		; inicjalizacja licznika dekadowego
		ldr				DIGIT_0, =0
		ldr				DIGIT_1, =0
		ldr				DIGIT_2, =0
		ldr				DIGIT_3, =0
		
		; wyzerowanie licznika cyfr
		eor CURR_DIG,CURR_DIG

main_loop
        
		; wlaczenie cyfry o numerze podanym w CURR_DIG, uzywane rejestry R4 i R5
		ldr				r5, =IO0CLR
		ldr				r4, =0xF0000
		str				r4, [r5]
		
		ldr				r5, =IO0SET
		ldr				r4, =0x80000
		mov             r4,r4,lsr CURR_DIG
		str				r4, [r5]
		
		; R6 <= DIGIT_X gdzie X=CURR_DIG
		cmp             CURR_DIG,#0
		moveq			r6,DIGIT_0
		cmp             CURR_DIG,#1
		moveq			r6,DIGIT_1
		cmp             CURR_DIG,#2
		moveq			r6,DIGIT_2
		cmp             CURR_DIG,#3
		moveq			r6,DIGIT_3
		
		; zamiana numeru cyfry (CURR_DIG) na kod siedmiosegmentowy (R6), inne uzywane rejestry R4 i R5
		adr				r4, SevenSegCodes
        add             r4,r4,r6		
		ldrb			r6, [r4]
		
		; wpisanie kodu siedmiosegmentowego (R6) do segmentów 
		ldr				r5, =IO1CLR
		ldr				r4, =0xFF0000
		str				r4, [r5]

        mov             r6, r6, lsl #16
		ldr				r5, =IO1SET
		str				r6, [r5]
		
		; inkrementacja licznika cyfr (CURR_DIG) modulo 4
		add 			CURR_DIG,CURR_DIG,#1
		cmp     		CURR_DIG, #4
		eoreq			CURR_DIG, CURR_DIG
		
		; inkrementacja licznika dekadowego (DIGIT_0 .. DIGIT_3)
		add				DIGIT_0, DIGIT_0, #1
		cmp				DIGIT_0, #10
		ldreq			DIGIT_0, =0
		addeq			DIGIT_1, DIGIT_1, #1
		cmp				DIGIT_1, #10
		ldreq			DIGIT_1, =0
		addeq			DIGIT_2, DIGIT_2, #1
		cmp				DIGIT_2, #10
		ldreq			DIGIT_2, =0
		addeq			DIGIT_3, DIGIT_3, #1
		cmp				DIGIT_3, #10
		ldreq			DIGIT_3, =0
		
		; opóznienie (okres wyswietlania jedenj cyfry)
		ldr				r0,=5
		bl delay_in_ms
		
		b				main_loop		

; podprogram delay_in_ms, input:r0
delay_in_ms
		ldr				r4, =15000
		mul				r0, r4, r0
loop	subs 			r0, r0, #1
		bne				loop
		bx lr
		
; tablica kodów siedmiosegmentowych				
SevenSegCodes
		DCB 0x3f,0x06,0x5B,0x4F,0x66,0x6d,0x7D,0x07,0x7f,0x6f
		
		END

