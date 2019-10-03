 ;### MACROS & defs (.equ)###

.MACRO LOAD_CONST  
 ldi  @0,low(@2)
 ldi  @1,high(@2)
.ENDMACRO 

/*** Display ***/
.equ DigitsPort = PORTB
.equ SegmentsPort  = PORTD
.equ DisplayRefreshPeriod = 20

.MACRO SET_DIGIT  
LDI R16,0x10>>@0
OUT DigitsPort, R16
mov R16,Dig_@0
rcall DigitTo7segCode
OUT SegmentsPort, R16
LDI R16,low(DisplayRefreshPeriod/4)
LDI R17,high(DisplayRefreshPeriod/4)
rcall DealyInMs
.ENDMACRO 

; ### GLOBAL VARIABLES ###

.def PulseEdgeCtrL=R0
.def PulseEdgeCtrH=R1

.def Dig_0=R2
.def Dig_1=R3
.def Dig_2=R4
.def Dig_3=R5

; ### INTERRUPT VECTORS ###
.cseg		     ; segment pamiêci kodu programu 

.org	 0      rjmp	_main	 ; skok do programu g³ównego
.org OC1Aaddr	rjmp _Timer_ISR
.org PCIBaddr   rjmp _ExtInt_ISR ; skok do procedury obs³ugi przerwania zenetrznego 

; ### INTERRUPT SEERVICE ROUTINES ###

_ExtInt_ISR: 	 ; procedura obs³ugi przerwania zewnetrznego

        push R16
	    in R16,SREG
	    push R16
 
		ldi R16,1
		add PulseEdgeCtrL,R16
		clr R16
		adc PulseEdgeCtrH,R16
       
	    pop R16
	    out SREG,R16
        pop R16

		reti   ; powrót z procedury obs³ugi przerwania (reti zamiast ret)      

_Timer_ISR:
        push R16
        push R17
        push R18
        push R19
		in R16,SREG
	    push R16

		mov R16,PulseEdgeCtrL
		mov R17,PulseEdgeCtrH       
		ror R17
		ror R16 
		rcall _NumberToDigits
		mov Dig_0,R16 
		mov Dig_1,R17 
		mov Dig_2,R18 
		mov Dig_3,R19 

		clr PulseEdgeCtrL
		clr PulseEdgeCtrH

		pop R16
	    out SREG,R16
		pop R19
        pop R18
        pop R17
        pop R16

		reti

; ### MAIN PROGAM ###

_main: 

            // *** Ext. ints ***

			ldi R16,(1<<PCIE0) ; enable PCINT7..0
			out GIMSK,R16

			ldi R16,(1<<PCINT0) ; unmask PCINT0
			out PCMSK0,R16

			; *** Timer1 ***
			.equ TimerPeriodConst=31250

			ldi R16, (1<<CS12)|(1<<WGM12) ; prescaler 256 & ctc mode
			out TCCR1B,R16

			ldi R16,high(TimerPeriodConst); 
			out OCR1AH,R16

			ldi R16,low(TimerPeriodConst) 
			out OCR1AL,R16 

			ldi R16,1<<OCIE1A ; interrupt on match
			out TIMSK,R16 
			
			// *** Display ***

			// Ports
			LDI R16,0x02
			OUT DDRB,R16

			LDI R16,0xFF
			OUT DDRD,R16

			// --- globalne odblokowanie przerwañ
            sei

			// 
MainLoop:   

			SET_DIGIT 0
			SET_DIGIT 1
			SET_DIGIT 2
			SET_DIGIT 3

			RJMP MainLoop

; ### SUBROUTINES ###

;*** NumberToDigits ***
;input : Number: R16-17
;output: Digits: R16-19
;internals: X_R,Y_R,Q_R,R_R - see _Divider

; internals

.def Dig0=R22 ; Digits temps
.def Dig1=R23 ; 
.def Dig2=R24 ; 
.def Dig3=R25 ; 

_NumberToDigits:

	push Dig0
	push Dig1
	push Dig2
	push Dig3

	; thousands 
	LOAD_CONST R18,R19,1000 ; divider
	rcall _Divide
	mov Dig3,R18       ; quotient - > digit

	; hundreads 
	LOAD_CONST R18,R19,100
	rcall _Divide
	mov Dig2,R18         

	; tens 
	LOAD_CONST R18,R19,10
	rcall _Divide
	mov Dig1,R18        

	; ones 
	mov Dig0,R16      ;reminder - > digit0

	; otput result
	mov R16,Dig0
	mov R17,Dig1
	mov R18,Dig2
	mov R19,Dig3

	pop Dig3
	pop Dig2
	pop Dig1
	pop Dig0

	ret

;*** Divide ***
; X/Y -> Qotient,Reminder
; Input/Output: R16-19, Internal R24-25

; inputs
.def XL=R16 ; divident  
.def XH=R17 

.def YL=R18 ; divider
.def YH=R19 

; outputs

.def RL=R16 ; reminder 
.def RH=R17 

.def QL=R18 ; quotient
.def QH=R19 

; internal
.def QCtrL=R24
.def QCtrH=R25

_Divide:push R24 ;save internal variables on stack
        push R25
		
		clr QCtrL ;clr QCtr 
		clr QCtrH

divloop:cp	XL,YL ;exit if X<Y
		cpc XH,YH
		brcs exit   

		sub	XL,YL ;X-=Y
		sbc XH,YH

		adiw  QCtrL:QCtrH,1 ; TmpCtr++

		rjmp divloop			

exit:	mov QL,QCtrL; QoutientCtr to Quotient (output)
		mov QH,QCtrH

		pop R25 ; pop internal variables from stack
		pop R24

		ret

// *** DigitTo7segCode ***
// In/Out - R16

Table: .db 0x3f,0x06,0x5B,0x4F,0x66,0x6d,0x7D,0x07,0xff,0x6f

DigitTo7segCode:

push R30
push R31

ldi R30, Low(Table<<1)  // inicjalizacja rejestru Z 
ldi R31, High(Table<<1)

add R30,R16 // Z + offset
clr R16
adc R31,R16

lpm R16, Z  // Odczyt Z

pop R31
pop R30

ret

// *** DelayInMs ***
// In: R16,R17
DealyInMs:  
            push R24
			push R25

            mov  R24,R16 
			mov  R25,R17                  
  L2: 		rcall OneMsLoop
            SBIW  R24:R25,1 
			BRNE  L2

			pop R25
			pop R24

			ret

// *** OneMsLoop ***
OneMsLoop:	
			push R24
			push R25 
			
			LOAD_CONST R24,R25,2000                    

L1:			SBIW R24:R25,1 
			BRNE L1

			pop R25
			pop R24

			ret



