/*
 * SFD-V1
 * Signal u. Funktionsdekoder V1
 *
 * Version 1.19
 *
 * Diese Quelldatei unterliegt der GNU General Public License,
 * die unter http://www.gnu.org/licenses/gpl.txt verfügbar ist.
 * Jede kommerzielle Nutzung, auch von Teilen, ist untersagt. 
 *
 * Copyright (c) 2018 S.Marsch
 *
 ****************************************************************************************
 * Die Vorlage der Timing- und Dimmengine entstammt dem Opendecoder-Projek aus OpenDCC	*
 * https://www.opendcc.de/elektronik/opendecoder/opendecoder.html						*
 * Copyright (c) 2006 Kufer																*
 * Die Timing- und Dimmengine wurde um Neonflackern und Zufallsssteuerung erweitert		*
 * und in Assembler realisiert															*
 ****************************************************************************************
 * Assembler File sxtiny.S
 *
 * Created: 12.03.2018 18:00:31sx
 * Letzte Änderung 25.03.2020
 *
 *  Author: Sönke Marsch
 */ 

 #include <avr/io.h>
 #include "project.h"

 #define out_lo		sbi SXPORT,SXOUT_HI $ sbi SXPORT,SXOUT_LO
 #define out_hi		cbi SXPORT,SXOUT_LO $ cbi SXPORT,SXOUT_HI
 #define out_z		cbi SXPORT,SXOUT_LO $ sbi SXPORT,SXOUT_HI

// out_pwm struct offset
rest		=	0					// Zeit bis zum nächsten Wechsel in PWM_PERIOD (18ms)
ontime		=	1					// Einschaltzeit
offtime		=	2					// Ausschaltzeit
dimm_val	=	3					// aktueller Istwert
delta_A		=	4					// aktuelles Increment in Richtung A
delta_B		=	5					// aktuelles Decrement in Richtung B

// Param Offset
DecMode		=	0
ImpTime		=	5
TimeRatio	=	6
RedDelay	=	7
BarDelay	=	8
BarImpTime	=	9
OptSw		=	10


.extern Param
.extern MyDelay
.extern CurMode

.lcomm	out_pwm				48		// strukt-array mit 8 x 6 Einträgen		
.lcomm	cur_adr				1
.lcomm	hauptsignal_state	1
.lcomm	vorsignal_state		1
.lcomm	time_delay			1


rand:
	rcall	lfsr
	rcall	lfsr
	rcall	lfsr

// linear feedback shift register (lfsr)
//
//      |---|    |---|    |---|    |---|    |---|    |---|    |---|    |---|
//    ->| 0 |--->| 1 |--->| 2 |--->| 3 |-o->| 4 |-o->| 5 |-o->| 6 |--->| 7 |--o--->
//   |  |---|    |---|    |---|    |---| |  |---| |  |---| |  |---|    |---|  |
//   |                                   |        |        |                  |
//    <--------------------------------- + <----- + <----- + <----------------
//

lfsr:    
	clr		r25
	sbrc	seed,7
	inc		r25
	sbrc	seed,5
	inc		r25
	sbrc	seed,4
	inc		r25
	sbrc	seed,3
	inc		r25
	ror		r25
	rol		seed
	brne	lfsr1
	mov		seed,shiftreg_hi
lfsr1:
	mov		r25,seed
	ret

.global init_pwm_array
/************************************************************
*	PwmOut-Array mit Parameter vorbelegen					*
*	Je nach Decoder Mode werden verschiedene Werte für:		*
*	Ontime, Offtime, Delta_A und Delta_B eingetragen.		*
*	Im Bootvorgang werden zusätzlich noch der Startwert		*
*	für Dimm_Val und Restzeit gesetzt.						*
************************************************************/
init_pwm_array:
	clr		myrest
	lds		r20,Param + OptSw		// Param-Switch in Port speichern
	lds		r24,CurMode
	cpi		r24,1
	breq	full_option
	andi	r20,~((1<<Nel)|(1<<Sim)|(1<<Zst))
full_option:
	out		PSW,r20					// = kompakterer Code
	sbis	PSW,Nel					// Bei Neonlampenmode kein Zufallssteuerung
	sbis	PSW,Sim
	cbi		PSW,Zst					// Zufallssteuerung nur im Simultanmode

/********************************************************
* out_pwm-Array vorbelegen
********************************************************/
	ldi		zl,lo8(out_pwm)
	ldi		zh,hi8(out_pwm)
	ldi		r20,8					// Portcount
//  Vorbelegung Glühlampensimulation
	clr		r21						// ontime
	clr		r22						// offtime
	ldi		r23,DIMM_VAL_MIN		// dimm_val Startwert
	mov		cur_dimm,r23
	cpi		r24,1					// r24 = Decodermode
	brlo	mo2						// Mode = 0 (8 fach Impuls/Schaltdecoder)
	breq	mo1						// Mode = 1 (8 fach Schaltdecoder gedimmt)
	cpi		r24,3
	brlo	mo2						// Mode = 2 (Weichendecoder)
	breq	mo3						// Mode = 3	(2 Weichen u. 1 Bahnübergang)

mo1:								// Mode = 1 und Mode > 4 (alle Signaldecoder)
	sbic	PSW,Nel					// Bei Neonlampen großes Delta	
	rjmp	mo2_1	
	ldi		r24,DIMM_UP_SPEED;		// delta_a
	ldi		r25,DIMM_DOWN_SPEED;	// delta_b
	rjmp	pwm_loop						
// Vorbelegung Impuls/Weichendecoder
mo2:
	lds		r21,Param + ImpTime		// ontime = Impulsdauer	
mo2_1:				
	ldi		r24,PWM_STEPS			// delta groß wählen, damit Ausgang gleich schalten
	mov		r25,r24	
	rjmp	pwm_loop

// Vorbelegung 2 Weichen u. 1 Bahnübergang 
mo3:
	ldi		r20,4					// 2 Weichen
	rcall	mo2						
	ldi		r20,3					// die ersten 3 Ports
	ldi		r21,BLINK_TIME			// ontime u. offtime
	mov		r22,r21					// auf blinken
	rcall	mo1						// zuerst alles auf blink
	clr		r21						// ontime u. offtime
	clr		r22						// auf dauer
	sbis	PSW,Lza					// ist das Lichtzeichen-Flag gesetzt ?
	rjmp	mb_end
mb_neu:								// Ja, BÜ mit Lichtzeichen
	ldi		r20,2					// die ersten beiden nochmal. (Dauerlicht)
	sbiw	z,18					// Array-Zeiger auf 1. Port
	rcall	mo1						// jetzt die erste beiden auf dauer
	adiw	z,6						// Array-Zeiger auf 4. Port
mb_end:
	ldi		r20,1					// letzter Port für Relais vorbereiten
	sbic	PSW,Sis					// ist Impulssteuerung aktiv
	lds		r21,Param + BarImpTime	// dann ontime = SchrankeImpulsDauer
	rjmp	mo2_1

pwm_loop:
	// rest und dimm_val-werte nur beim Start und nach
	// wechseln der Betriebsart setzen
	sbrc	FLAG,Boot_Ok			
	rjmp	no_boot					// 
	std		z + rest,rzero			// rest = 0
	std		z + dimm_val,r23		// dimm_val
no_boot:
	std		z + delta_A,r24			// delta_A
	std		z + delta_B,r25			// delta_B
	std		z + ontime,r21			// ontime
	std		z + offtime,r22			// offtime
	adiw	z,6						// ein Port weiter
	dec		r20
	brne	pwm_loop
	ret

 
.global action_out
/***********************************************************************************************
 Betriebsart:										  |------------- Option ---------------|
 Mode		  Decodertyp					Adr	Sub  Bit  Mam  Alt	Lza	 Sis  Lss  Nel  Sim	 Zst
  0: 8 fach Impuls/Schaltdecoder			 1	 N	  8	   N	N	 N	  N	   N	N    N	  N
  1: 8 fach Beleuchtungsdekoder				 1	 N	  8	   N	N	 N	  N	   N	J	 J	  J
  2: 4 fach Weichendecoder Impulsbetrieb	 1	 J	  4	   N	N	 N	  N	   J	N	 N	  N
  3: 2 Weichen u. 1 Bahnübergang			 1	 J	  3	   N	N	 J	  J	   J	N	 N	  N
  4: 4 Signale 2 Begriffig					 1	 J	  4	   N	N	 N	  N	   N	N	 N	  N
  5: 2 Einfahrsignale mit Vorsignal			 2	 J	  2	   N	J	 N	  N	   N	N	 N	  N
  6: 2 Haupt/sperrsignale					 2	 J	  2    N	J	 N	  N	   N	N	 N	  N
  7: 1 Einfahrsig. m. Vorsig. u. 1 VorSig.	 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
  8: 1 Haupt/sperrsignal u. 1 Vorsignal		 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
  9: 1 Haupt/sperrsig. 1 Block HS/VS m. Dt	 2	 J	  2	   J	J	 N	  N	   N	N	 N	  N
 10: Wie Mode7 aber mit Dunkeltastung		 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
 11: Wie Mode8 aber mit Dunkeltastung		 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
 																			
 	Mode2 wird zum 4 fach Wechseler, wenn Parameter 5 (Impulsdauer) = 0 ist	
**********************************************************************************************/
	
/****************************************************
*	Register:	r20 Portmaske						*
*				r21 Geänderte Ports	(ini-wert=0)	*
*				r22	Zu ändernde Ports				*
*				r23	Arbeitsregister					*
*				r24	Stellbefehl						*
*				r25	Arbeitsregister					*
*				 x	Zeiger auf PWM-Array			*
*				 z	Pointerregister					*
****************************************************/
						
action_out:	
	cpi		r20,5					// Mehrbegriffiges Signal
	brlo	switch					// nein, dann gleich switch/case	

	sbis	PSW,Alt					// Alternative Signalsteuerung?
	rjmp	sig_mode				// Nein, dann Signalauswahl
	sbrs	r24,1					
	rjmp	sig_mode				// dibit 11 -> 10
	ldi		r25,1					// dibit 10 -> 11
	eor		r24,r25
sig_mode:
	cpi		r22,0xF0				// 2. Signal? (Port 5..8)
	breq	sig_mode_1
	ldi		r22,0x0F				// 1. Signal, dann Port 1..4 ändern
	brne	switch
sig_mode_1:
	subi	r24,252					// bei 2. Signal = Kommando + 4

switch:
	clt								// T-Flag vorbereiten für Dunkeltastungs- Modi
	ldi		xl,lo8(out_pwm)			// Zeiger auf PWM-Array
	ldi		xh,hi8(out_pwm)
	ldi		zl,pm_lo8(mode_tbl)		// Adresse der Sprung-
	ldi		zh,pm_hi8(mode_tbl)		// Tabelle laden
	clr		r21
	add		zl,r20					// Einsprungstelle
	adc		zh,r21					// ermitteln
	ijmp
mode_tbl:	// Sprungtabelle
	rjmp	mode0
	rjmp	mode1
	rjmp	mode2
	rjmp	mode3
	rjmp	mode4
	rjmp	mode5
	rjmp	mode6
	rjmp	mode7
	rjmp	mode8
	rjmp	mode9
	rjmp	mode10
	rjmp	mode11

	// Case
mode0:		// 8 fach Impuls/Schaltdecoder			
mode1:		// Mode0 und Mode1 sind gleich Unterschied ungedimmt/gedimmmt
	movw	z,x						// Zeiger auf PWM-Array (std od. ldd geht nur mit y od. z)
	ldi		r20,1					// Bitmaske für Port
	in		r23,PSW
	andi	r23,((1 << Zst) | (1 << Nel))
	// r21 = 0 Register für die Bitmanipulation
mode01_loop:
	lsr		r22						// hat sich was geändert ?
	brcc	mode01_end
	ldi		r25,1					// Restlaufzeit bis zum schalten in 20ms-Schritten
	tst		r23
	breq	mode01_on_off
	rcall	rand					// Zufallswert nur bei Nel od. Zst
	sbic	PSW,Nel
	std		z + ontime,r25			// Flackerwert nur bei Neonlampen
	andi	r25,0x0F
	inc		r25						// Zufallszahl von 1 bis 16
mode01_on_off:
	sbrs	r24,0					// prüfen ob ein od. aus
	clr		r25
	std		z + rest,r25			// mit > 0 wird der Port in Engine-ISR eingeschaltet
	or		r21,r20					// geänderten Port merken
mode01_end:
	adiw	z,6						// Array-Zeiger ein Port weiter
	lsr		r24						// nächster Port
	lsl		r20
	brne	mode01_loop				// alle Ports bearbeitet ?
	rjmp	set_port
			
mode2:		// Weichendecoder mit sequentiellem Schalten 			
	inc		myrest					// muss > 0 sein 
	lds		r25,Param + ImpTime		// Stellimpulsdauer

mode2s:		// Einsprung für 2 Begriffige Signale
	movw	z,x						// Zeiger auf PWM-Array (std od. ldd geht nur mit y od. z)
	ldi		r20,0b00000011			// BitMASK für eine Weiche (zwei Port's)
	//r21 = 0 Register für die Bitmanipulation
turn_loop:
	lsr		r22						// 2. Param = Valid. Gültige Weiche?
	brcc	turn_end				// nein, dann nächste Weiche
	sbrs	r24,0					// 1. Param = Pattern. Gerade(0) od Abzweig(1)
	rjmp	turn_even				// Weiche gerade stellen
turn_odd:							
	st		z,rzero					// rzero ist immer 0
	std		z+6,myrest				// Verzögerung bis zum schalten
	rjmp	turn_out				
turn_even:							
	st		z,myrest
	std		z+6,rzero
turn_out:	
	or		r21,r20					// Weichenmaske in Portmaske übernehmen
	add		myrest,r25				// myrest += pulsdelay (sequenzielles Schalten)
turn_end:
	adiw	z,12					// Offset: 2 Ports weiter
	lsr		r24						// Pattern ein Weiche weiter
	lsl		r20						// Bit-MASK 2 Ports weiter
	lsl		r20						// = nächste Weiche
	brne	turn_loop				// Alle Weichen fertig ?							
	rjmp	set_port

mode3:		// 2 Weichen und 1 Bahnübergang wahlweise mit
			// Andreaskreuzblinker oder Lichtzeichenanlage (Rot / Gelb Ampel)
	bst		r24,2					// Stellbefehl und
	mov		r23,r22					// Gültigkeitsmaske für BÜ sichern
	andi	r22,0x03				// BÜ ausmaskieren		
	rcall	mode2					// Weichen stellen
mode3_bu:
	sbrs	r23,2					// muß BÜ gestellt werden ?
	rjmp	bu_end
	sbiw	z,24					// Zeiger auf Port 5 stellen
	lds		r23,Param + RedDelay	// Verzögerung bis Gelb aus / Rot an
	sbis	PSW,Lza					// Check auf Lichtzeichen
	ldi		r23,BLINK_TIME			// nur Andreaskreuz, dann Verzögerung für 2. Blinklicht = Blinkdauer
	in		r21,DIMM_DIR			// Register für Bitmanipulation
	andi	r21,0b00001111			// erstmal Port 5 bis 8 ausschalten
	brts	bu_on					// Ein oder Ausschalten
bu_off:
	clr		r25
	st		z,r25					// 
	std		z+6 ,r25				// Bei allen Port's Rest auf 0 setzen
	std		z+12,r25				// d.h. keine Änderung des Zustands
	sbis	FLAG,Boot_Ok			// Beim Booten kein Schrankenimpuls
	rjmp	no_imp
	sbic	PSW,Sis					// Schrankenimpuls aktiv, dann
	inc		r25						// Port einschalten. Dauer steht in PWM-Array.ontime
no_imp:
	std		z+18,r25					
	rjmp	bu_set
bu_on:
	ori		r21,0b00010000			// 1. Blinklicht / Gelblicht an
	st		z,r23					// 1. Andreaskreuz Rest = Blinkdauer / Gelblicht Rest = RedDelay
	std		z+6 ,r23				// 2. Andreaskreuz Rest = Blinkdauer / Rotlicht Rest = RedDelay
	lds		r25,Param + BarDelay	// Verzögerung bis Schrankenrelais einschaltet
	std		z+12,r25				// Lockführersignal Rest = BarDelay
	std		z+18,r25				// Relais Rest = BarDelay
bu_set:
	out		DIMM_DIR,r21			// Port's werden im Dimmer geschaltet
bu_end:		
	rjmp	action_end

mode4:		// 4 Zweibegriffige Signale
	ldi		r25,DIMM_UP_DELAY		// erst abdimmen und verzögert aufdimmen
	mov 	myrest,r25
	clr		r25						// kein sequenzielles Schalten
	rjmp	mode2s					// weiter wie Weiche

mode5:		// 2 Dreibegriffige Hauptsignale abhängigen Vorsignal
	ldi		r25,EE_Signal_DB1		// Signalmuster
	rjmp	set_signal

mode6:		// 2 Vierbegriffige Hauptsignale
	ldi		r25,EE_Signal_DB2
	rjmp	set_signal

mode7:		// Dreibegriffiges Hauptsignal mit Vorsignal u. unabhängiges Vorsignal
	ldi		r25,EE_Signal_DB3
	rjmp	set_signal

mode8:		// Vierbegriffiges Haupt- u. Vorsignal getrennt
	ldi		r25,EE_Signal_DB4
	rjmp	set_signal

mode9:
	set								// Flag für 2 begriffiges Vorsignal auf 2. Adresse
	/*cpi		r24,4					// 1. oder 2. Adresse
	brlo	mode9_1					// 1. Adresse: einfach weiter
	mov		r23,r24					// Stellbefehl sichern
	swap	r24						// bit0 (hp0/hp1) nach bit3 schieben
	lsr		r24		
	ldi		r22,0b00001000			// nur Port 7..8 ändern (zweibegriffiges Hauptsignal)
	rcall	mode4					// erst das Hauptsignal stellen
	mov		r24,r23					// Stellbefehl für das Vorsignal am Mast des Ausfahrsinal
	ldi		r22,0b00110000			// Maske für 2. Signal*/
mode9_1:
	ldi		r25,EE_Signal_DB5
	rjmp	signal_kombi

mode10:		// Dreibegriffiges Hauptsignal mit Vorsignal u. unabhängiges Vorsignal
			// am Mast des Einfahrhauptsignal
	ldi		r25,EE_Signal_DB6
	rjmp	signal_kombi
			
mode11:		// Vierbegriffiges Haupt- u. Vorsignal am gleichen Mast
	ldi		r25,EE_Signal_DB7

signal_kombi:	
	mov		r20,r24					// Kommando sichern( r20 wird nicht geändert)
	cpi		r24,4					// Kommando > 3 = Vorsignal
	brsh	vorsignal
	// Hauptsignal
	push	r25
	rcall	set_signal				// Lichtwerte für Hauptsignal setzen
	pop		r25
	lds		r21,hauptsignal_state	// Alter Zustand
	sts		hauptsignal_state,r20	// Zustand für Vorsignalsteurung speichern
	and		r21,r20					// Neuen mit alten Vergleichen
	cpi		r21,1					// Nur Wechsel HP1/HP2,
	breq	action_end				// dann nichts machen.
	sbis	FLAG,Vs_Ok				// Gültiges Vorsignal?
	clr		r20						// nein, dann Vorsignal dunkel
	ldi		r22,0b11110000			// Maske für 2. Signal
	brtc	vs						// zweibegriffiges Vorsignal ?
	ldi		r22,0b00110000			// dann nur Port 5 + 6 ändern
vs:
	ldi		r24,6					// Vorsignalkommando für Dunkeltastung
	sbrc	r20,0					// Hauptsignal HP1 od. HP2 ?
	lds		r24,vorsignal_state		// dann aktuelle Vorsignalstellung
	rjmp	set_signal				// Lichtwerte für Vorsignal setzen
vorsignal:
	// Vorsignal
	cpi		r24,6					// Kommando 6 auf Kommando 4 mappen
	brne	vorsignal_ok
	ldi		r24,4					
vorsignal_ok:
	sts		vorsignal_state,r24		// Aktuelles Vorsignalkommando speichern
	lds		r21,hauptsignal_state	// Stellung des Hauptsignals prüfen
	//sbrs	r21,0					// Hp00 od. Hp0 + Sh1 -> Vorsignal ist dunkel
	//rjmp	action_out_end			// nichts machen
	// Hp/Hp2 = Vorsignal einschalten
	sbrc	r21,0					// Hp1 od. Hp2 ?
	rjmp	set_signal				// dann Signal stellen
	brtc	action_end				// Kein Blocksignal dann Vorsignal dunkel lassen
	//ldi		r22,0b11000000	
	subi	r24,254					// Kommando + 2	= Dunkeltastung Blockvorsignal



set_signal:
	add		r25,r24					// Offset für Signalmuster
e_loop: 
	sbic 	_EECR,EEPE				// läuft noch ein Schreibvorgang ?
    rjmp    e_loop 					// ja, nochmal prüfen
	out 	_EEAR,r25				// Adresse Signalmuster ins EEPROM Adressregister
	sbi 	_EECR,EERE				// Lesebit im EEPROM-Controlregister setzen
	in 		r24,_EEDR				// Byte kann jetzt aus dem Datenregister gelesen werden
	// prüfen ob Signalbild sich geängert hat
	// vermeidet aus und wiedereinschalten von Hp0 bei dreibegriffigen Signalen
	in		r25,DIMM_DIR
	and		r25,r22					// Signalbits ausmaskieren
	cpse	r25,r24					// mit AktuellemBild vergleichen
	rjmp	set_signal_val			// neues Signalbild stellen
	rjmp	action_end				// Nichts geändert, dann nichts machen

set_signal_val:	
	// x = Zeiger auf PWM-Array
	movw	z,x
	mov		r21,r22					// MASK
	ldi		r23,DIMM_UP_DELAY		// erst abdimmen und verzögert aufdimmen

lightloop:
	lsr		r22						// 2. Param = Valid. Gültiger Port?				
	brcc	light_next				// nein, dann nächster Port
	clr		r25						// Restzeit = 0
	sbrc	r24,0					// 1. Param = Signalbild. Port Aus(0) od Ein(1)
	mov		r25,r23					// abdimmen danach wieder aufdimmen
	st		z,r25					// Restzeit 0ms od. dimm_up_delay speichern
light_next:
	adiw	z,6						// Offset für nächsten Port
	lsr		r24						// Nächster Port
	tst		r22
	brne	lightloop				// Alle Ports bearbeitet?
set_port:
	com		r21						// Alle relevanten Ports ausschalten:
	in		r25,DIMM_DIR			// Signale sind dann aus oder werden 
	and		r25,r21					// nach der Dunkelphase (dimm_up_delay) wieder
	out		DIMM_DIR,r25			// aufgedimmt
action_end:	
	ret

.global check_prg_req
/********************************************************
* Prüfen ob Programmieranforderung per Tastendruck      *
* oder per Software.									*
* Eingabe:	r24 = Prog-Taste							*
*			r22 = Decoderadresse						*
*			r20 = Subadresse Bit0=1:oberes Nipple		*
*				  ab Mode5:	 Bit1=1:Oberes Dibit		*
* Rückgabe:	r24 = im Erfolgsfall = 0					*			
********************************************************/

check_prg_req:
	sbic	FLAG,Prog				// Decoder im Programmiermode ?
	rjmp	prg_end					// Dann einfach Tastencode zurückgeben
	cpse	r24,rzero				// Taste gedrück (0)?
	rjmp	prgtst
	ldi		r24,106					// Programmiert schon ein Anderer ?
	rcall	sx_read					// Wert von Kanal 106 zurückgeben
	rjmp	prg_end					// Wenn schon einer programmiert, dann r24 <> 0
prgtst:								// prüfen ob Programmieranforderung über SX-Bus
	sbrc	r20,0					// Unteres Nibble oder ganzes Byte ?
	ori		r22, 0x80				// nein, dann Bit 7 in Adresse setzen
	ldi		r24,107					// Anforderungsadr. in SX-Kanal 107
	rcall	sx_read					// Adresse holen
	sub		r24,r22					// stimmt die Adr ?
	brne	prg_end					// -> raus Rückgabe <> 0
	ldi		r24,106					// Kanal 106 = Anforderungskanal
	rcall	sx_read
	subi	r24,0xA8				// Bit 3, 5 und 7 gesetzt ?
	brne	prg_end					// Keine Prog.-Anforderung -> raus Rückg.<>0
	ldi		r24,105					// MfgID holen und vergleichen
	rcall	sx_read
	subi	r24,MFGID
	brne	prg_end					// Nicht meine ID Rückg. <> 0
	ldi		r24,104					// DevID holen und vergleichen
	rcall	sx_read					// Passt sie zu diesem Dekoder ?
	subi	r24,DEVID				// Ja = 0 , Nein <> 0
	sbrc	r20,1					// oberes DiBit ?
	subi	r24,0x80				// Ja. Flag ist Bit7 in DevID Kanal104 codiert
prg_end:
	ret
	
.global sx_write
/********************************************************************
*	Daten-Byte auf SX-Bus schreiben. Adresse wird in r24,			*
*	Schreibdaten in r22 und Schreibmaske in r20 übergeben.			*
*	Über die Schreibmaske ist Bitweises Schreiben möglich.			*
*	D.h. dort wo das Bit in der Maske gesetzt ist, wird das			*
*	korrespondiernde Datenbit geschrieben.Es wird gewartet bis		*
*	Adresse gültig	ist und die Daten geschrieben sind.				*
*	Schreibmaske und Schreibdaten sind "double buffered", damit im 	*
*   Fehlerfall keine faschen Daten geschrieben werden.				*
********************************************************************/
sx_write:
	out		SMASKE,r20				// Schreibmaske
	out		SBUFFER,r22				// Schreibdaten

.global sx_read
/********************************************************************
*	Daten-Byte vom SX-Bus lesen. Adresse wird in r24 übergeben		*
*	Rückgabe der Daten in r24. Es wird gewartet bis Adresse gültig	*
*	ist und die Daten gelesen sind.									*
*	Schreiben und lesen teilen sich das gleiche Unterprogramm.		*
********************************************************************/
sx_read:
	sts		cur_adr,r24
	sbi		FLAG,req				// Adresse anfordern
wait_ready:
	sbic	FLAG,req				// Warten bis fertig geschrieben
	rjmp	wait_ready
	out		SMASKE,rzero			// Schreiben zurücknehmen
	mov		r24,vbuffer				// Return vbuffer
	ret


.global TIMER1_COMPA_vect
/********************************************************************************
* Timing/Dimmengine wird alle 20mS vom PWM-ISR aufgerufen						*
*																				*
* 1. Timing Engine:																*
*    Es wird folgendes geprüft:													*
*    a) Wenn out_pwm[port].rest gleich 0: dann bleibt dieser Port unverändert.	*
*    b) out_pwm[port].rest wird decrementiert, wenn es dabei 0 wird, dann		*
*       wird ein Dimmvorgang in die andere Richtung eingeleitet.				*
*																				*
* 2. Dimm Engine:																*
*    Je nach aktueller Richtung des Dimmvorgang (DIMM_DIR) wird der aktuelle	*
*    Dimmwert erhöht oder erniedrigt.											*
*    Die Dimmrampe ist unabhängig von den Zeiten, die bei ontime bzw. offtime	*
*    vorgegeben werden.															*
*    Wenn ein Ausgang schalten soll, dann muß sein Delta sehr groß gewählt		*
*    werden!																	*
*********************************************************************************/
TIMER1_COMPA_vect:
	// PWM-ISR
	
	in		sisr,_SREG				
	out		_TIMSK,rzero			// Timerinterupt sperren
	push	r20						// PortMaske
	push	r21						// Temp
	push	r24						// Temp
	push	r25						// Temp
	push	r30						// Pointer auf PWM-Array
	push	r31
	sei								// SX-Interupt erlauben
// Dimmer	
ISR_PWM:	
	ldi		r21,DIMM_VAL_MAX
	inc		cur_dimm				// Index für das light_val-Array
	cp		cur_dimm,r21			// maximum erreicht ?
	brlo	do_dimm
	ldi		r21,DIMM_VAL_MIN
	mov		cur_dimm,r21			// dann von vorne

do_dimm:
	ldi		zl,lo8(out_pwm + dimm_val)
	ldi		zh,hi8(out_pwm + dimm_val)
	ldi		r20,1					// Portmaske
	in		r24,OUTPORT				// isr_ticker für temp-port missbrauchen
	
loop:
	ld		r25,z					// Port-dimm_val aus PWM-Array holen
	cp		cur_dimm,r25			// mit akt. Dimmwert vergleichen
	brsh	lp_off
lp_on:
	or		r24,r20					// dimm_val > Dimmwert, dann Port einschalten
	rjmp	lp_out
lp_off:
	com		r20
	and		r24,r20					// dimm_val <= Dimmwert, Port ausschalten
	com		r20
lp_out:
	adiw	z,6						// Zeiger auf nächsten Port stellen
	lsl		r20						// weiter bis alle Ports bearbeitet (8x)
	brne	loop
	out		OUTPORT,r24				// Temp-Port zurückschreiben
	cpse	cur_dimm,r21			// Durchlauf komplett, dann Time/Dimmengine ausführen
	rjmp	engine_end					
// Timing und Dimmengine
	lds		r20,Param + TimeRatio	// Dehnungsfaktor für TimeEngine
	lds		r21,time_delay			// aktueller Dehnungszähler
	inc		r21
	cp		r21,r20					// Zeit erreicht?
	brlo	tr1
	clr		r21						// dann von vorn
	rcall	lfsr					// neuen Zufallswert generieren
tr1:
	sts		time_delay,r21			
	lds		r25,MyDelay
	tst		r25
	breq	dm1
	dec		r25
	sts		MyDelay,r25
dm1:
	tst		myrest					// Sequenzelles Schalten der Weichen
	breq	engine_start	
	dec		myrest
engine_start:
	ldi		zl,lo8(out_pwm)			// Zeiger auf PWM-Array
	ldi		zh,hi8(out_pwm)
	ldi		r20,1					// PortMaske auf 1. Port
engine_loop:
	in		r25,DIMM_DIR			// Dimmrichtung laden
	sbic	PSW,Sim					// Zeitdehnung nur wenn Simultanmode
	sbis	PSW,Zst					// und Zufallssteuerung ein
	rjmp	time_engine
	tst		r21						// r21 = Zeitdehnungszähler
	brne	dimm_engine
time_engine:
	ldd		r24,z + rest
	tst		r24						// wenn rest = 0 dann Richtung beibehalten
	breq	dimm_engine
	dec		r24
	brne	save_time
	// wenn jetzt rest = 0 dann Richtung umdrehen
	sbis	PSW,Nel					// Keine Neonlampen?
	rjmp	no_flicker				// Dann normal weiter
// Neonlampen-Simulation
flicker:
	ldd		r24,z + ontime			// ontime = Zufallswert für flackern
	lsr		r24
	std		z + ontime,r24
	breq	turn_it_on				// flackern beendet, dann immer an
	sbrs	r24,0
	rjmp	flicker_off
flicker_on:
	ldi		r24,1					// nur kurz aufblitzen
	rjmp	turn_it_on
flicker_off:
	andi	r24,0x07				// neuer Zufallswert für Flackerpause
	subi	r24,246					// +10
	rjmp	turn_it_off
// Keine Neonlampen
no_flicker:
	mov		r24,r25
	and		r24,r20					// Port ausmaskieren
	breq	turn_on
turn_off:
	ldd		r24,z + offtime			// Neue Restzeit für Aus oder 0
turn_it_off:
	com		r20
	and		r25,r20					// Port ausschalten
	com		r20
	rjmp	save_dir
turn_on:
	ldd		r24,z + ontime			// Neue Restzeit für Ein oder 0
turn_it_on:	
	or		r25,r20					// Port einschalten
save_dir:
	out		DIMM_DIR,r25			// Neue Dimmrichtung speichern
save_time:
	std		z + rest,r24			// Neue Restzeit speichern
dimm_engine:
	ldd		r24,z + dimm_val
	and		r25,r20					// Dimmrichtung bestimmen
	breq	dimm_down	
dimm_up:
	cpi		r24,DIMM_VAL_MAX		// Noch nicht Max erreicht
	brsh	dimm_end
dimm_it_up:
	ldd		r25,z + delta_A			// dann aufdimmen
	add		r24,r25
	rjmp	dimm_end
dimm_down:
	cpi		r24,DIMM_VAL_MIN + 1	// Noch nicht Min
	brlo	dimm_end
dimm_it_down:
	ldd		r25,z + delta_B			// dann abdimmen	
	sub		r24,r25
dimm_end:
	std		z + dimm_val,r24
	adiw	z,6						// Offset für nächsten Port
	lsl		r20						// ein Port weiter
	brne	engine_loop				// Alle Ports bearbeitet?
engine_end:
	cli
	pop		r31
	pop		r30
	pop		r25
	pop		r24
	pop		r21
	ldi		r20,(1<<OCIE1A)
	out		_TIMSK,r20				// Timerinterupt ein
	out		_TIFR,r20				// clear pending interupt
	pop		r20
	out		_SREG,sisr
	reti


.global INT0_vect
/********************************************************************
*	Pinchange-Interupt am T0-Takteingang des SX-Bus					*				
*	Der Wert vom der T1-Datenleitung des SX-Bus wir in ein			*
*	16-Bit Shiftregister (r3 und r4) eingeschoben					*
*	Dieses ermöglicht die Abfrage der Syncronbit's und der			*
*	Basisadresse in einem Durchlauf									*
********************************************************************/
INT0_vect:
	// SX-ISR

	out_z							// Schreibausgang deaktivieren	

// ** Auswahl ob Hi oder Lo
// ** Software Störunterdrückung: einige Takte muss Hi-Signal bleiben	**
	sbis	SXPIN,SXTAKT			// PD2 ist INT0-Eingang, Pin 6
	rjmp	isr_ex					// Bei Lo nichts machen (Schreibausgang ist bereits hochohmig)
	sbis	SXPIN,SXTAKT
	rjmp	isr_ex
	sbis	SXPIN,SXTAKT
	rjmp	isr_ex
						
	in		ssave,_SREG				// ab jetzt werden die Flag's verändert
	push	r30
	push	r31	

// **  Schieberegister für Synch-Block + Basisadresse	**
	lsl		shiftreg_lo				// Schieberegister für Sync-Block
									// Bit 0 -> 0, Bit 7 -> Carry, Carry -> Bit 0
	rol		shiftreg_hi				//  Schieberegister für Basisadresse
	 
// **	Datenleitung übernehmen												**

	sbic	SXPIN,SXDATA			// Skip wenn Datenleitung LO
	inc		shiftreg_lo				// LSB setzen, weil Datenleitung HI

	sbic	FLAG, adr_ok			// Adresse komplett?
	rjmp	process					// dann weitermachen
	
	sbis	FLAG, base_ok			// Basisadresse gültig ?
	rjmp	synctest				// nein weiterscannen

//	**  Warten bis Unteradresse	gültig								**	
			
	dec		bitcounter				// countdown und prüfen ob fertig
	brmi	start_process			// wenn < 0 dann lesen/schreiben vorbereiten
	rjmp 	check_int				// nicht fertig, dann weiter warten

start_process:
	// bitcounter ist jetzt bitcount, am Anfang ist wert 255
	sbi		FLAG, adr_ok			// do_action-FLAG setzen
	cbi		FLAG, base_ok			// Base-FLAG zurücknehmen
	in		vbuffer,SBUFFER			// Schreibdaten
	in		vmaske,SMASKE			// Schreibmaske
process:
	inc		bitcounter				// Bit's auszählen
	mov		r30,bitcounter
	cpi		r30,2
	breq	trennbit
	cpi		r30,5
	breq	trennbit
	cpi		r30,8
	breq	trennbit
	cpi		r30,11
	brsh	end_process			// das 4. Trennbit wird nicht mehr ausgewertet

// ***********************************************************************
// **	Zum Schreiben der Datenbits wird das Bit 0 im BUFFER abgefragt	** 
// **	Der Logikpegel wird auf den Schreibausgang übernommen.			**
// **   Zum Lesen wird der SX-Datenport ausgewertet, und entsprechent	**
// **	Bit 7 im Puffer gesetzt. Vorher wird der Puffer	um ein Stelle	**
// **	nach rechts verschoben und damit Bit 7 gelöscht					**
// **	Nach 8 mal schieben stehen alle Bit's an der 					**
// **	richtigen Stelle und die Schreibdaten sind ausgegeben			**	
// ***********************************************************************
	bst		vbuffer,0			// Schreibbit ins T-Flag
	lsr		shiftreg_lo			// Datenleitung ins Carry
	ror		vbuffer				// Datenleitung aus Carry in MSB
	lsr		vmaske				// Schreiben ?
	brcc	check_int			// Nein, dann fertig
	brtc	out_low				// SX-Leitung wie T-Flag setzen
out_high:
	out_hi
	rjmp	check_int
out_low:
	out_lo
	rjmp	check_int
	
trennbit:
	sbrc	shiftreg_lo,0		// Trennbit muß hi sein
	rjmp	check_int
error:
	cbi		FLAG,adr_ok			// sonst Error -> Abbruch
	rjmp	check_int

end_process:
	cbi		FLAG,adr_ok			// do_action-FLAG zurücknehmen
	cbi		FLAG,req			// Lesen / Schreiben beendet. Datenbit OK
	rjmp 	check_int

// ************************************************************************
// *	Wenn kein "adr_ok-Flag" und kein "base_ok-Flag" gesetzt ist,
// *	wird geprüft ob die 3 Synchronbits da sind.
// *	Nach SX-Codierung 0-0-0-1-x-1-B3-B2-1-B1-B0-1 in den ob. 12 Bit
// *	g ist das Gleisspannungsbit. B0 bis B3 ist die Basisadresse
// ************************************************************************

// *	x x x t s s s t		g t a3 a2 t a1 a0 t 
// *	7 6 5 4 3 2 1 0		7 6 5  4  3 2  1  0
// * r4---------------
// *					 r3-------------------

synctest:

	// r31 = Synchronbits 
	// Bit 4 = Trennbit vorheriger Frame, Bit 3-1 = Sync, Bit 0 = 1.Trennbit
	mov		r31,shiftreg_hi
	andi	r31,0b00011111			// die unteren  5 Bit gelten,
	cpi		r31,0b00010001			// 0-0-0-1-0-0-0-1 = Sync
	brne	check_int				// Rücksprung Keine Synchronbits

// **************************************************************************
// * Wenn die Synchronbits komplett sind kann das Gleisbit gelesen			*
// * und die Basisadresse geprüft werden.									*
// **************************************************************************

	// prüfen ob alle trennbits ok
	mov		r31,shiftreg_lo
	andi	r31,0b01001001
	cpi		r31,0b01001001
	brne	check_int				// nicht vollständig -> Störung
					
	mov		r30,shiftreg_lo			// Adressbyte g t a3 a2 t a1 a0 t	
	cbi		FLAG,Gleisbit			// GleisSpg-Flag löschen
	sbrc	r30,7					// ist das Gleisbit gesetzt ?
	sbi		FLAG,Gleisbit			// dann GleisSpg-Flag setzen
	sbis	FLAG,req				// wenn keine Anforderung dann nur 
	rjmp	check_int				// GleisSpg-Flag bedienen
	lsr		r30						// 0  g  t a3 a2  t a1 a0						
	mov		r31,r30
	andi	r30,0b00000011			// 0  0  0  0  0  0 a1 a0
	andi	r31,0b00011000			// 0  0  0 a3 a2  0  0  0
	lsr		r31						// 0  0  0  0 a3 a2  0  0
	or		r30,r31					// 0  0  0  0 a3 a2 a1 a0
	com		r30						// Basisadresse wird invertiert gesendet	
	lds		r31,cur_adr				// Aktuelle schreib / lese Adresse
	eor		r30,r31					// Basisadresse mit akt. Adresse vergleichen
	andi	r30,0b00001111			// Basisaresse isolieren
	brne	check_int				// KEINE GÜLTIGE BASISADRESSE !
	
// *        Adresse gültig, Wartezähler berechnen		*******************
 
	swap	r31						// Aktuelle Unteradresse ist im oberen Nibble
	andi	r31,0b00000111			// nur die unteren 3 Bit

//  Ini-Wert für UA-Wartezähler berechnen

	ldi		r30,6
	sub		r30,r31					// ACHTUNG die Unteradr. ist invertiert 6 = ua0, 5 = ua1 ...
	ldi		r31,12					// UA x 12 = Wartezähler
	clr		bitcounter
adr_loop:							// Multiplikationsschleife ohne Übertrag
	sbrc	r30,0
	add		bitcounter,r31
	lsl		r31						// Wert für nächstes Bit verdoppeln
	lsr		r30						// Nächstes Bit
	brne	adr_loop

// Sync-Triggerbit auf 1, wird wieder 0, wenn Wartezähler = 0
	sbi		FLAG, base_ok			// Base FLAG setzen	
								
check_int:

	
no_int:	
	pop		r31
	pop		r30
	out		_SREG,ssave

isr_ex:		
	reti

.end