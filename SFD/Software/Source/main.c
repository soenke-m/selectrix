/*
 * SFD-V1
 * Signal u. Funktionsdekoder V1
 *
 * Version 1.15
 *
 * Diese Quelldatei unterliegt der GNU General Public License,
 * die unter http://www.gnu.org/licenses/gpl.txt verfügbar ist.
 * Jede kommerzielle Nutzung, auch von Teilen, ist untersagt. 
 *
 * Copyright (c) 2017 S.Marsch
 *
 * main.c
 *
 * Created: 12.03.2017 17:56:56
 * Letzte Änderung 26.03.2020
 *
 * Author : Sönke Marsch
 *
 *	für Atmel Attiny2313A (ACHTUNG es muß der A-Type sein)
 *
 *	Fuses: Interner Oszillator, Kein Clock-Div, Brown_Out detection 4V3
 *
 *														  |------------- Option ---------------|
 *	Mode		  Decodertyp				Adr	Sub  Bit  ALT  MAM	LSS	 LZA  SIS  NAL  SIM	 ZST
 *	0: 8 fach Impuls/Schaltdecoder			 1	 N	  8	   N	N	 N	  N	   N	N    N	  N
 *	1: 8 fach Beleuchtungsdekoder			 1	 N	  8	   N	N	 N	  N	   N	J	 J	  J
 *	2: 4 fach Weichendecoder Impulsbetrieb	 1	 J	  4	   N	N	 J	  N	   N	N	 N	  N
 *	3: 2 Weichen u. 1 Bahnübergang			 1	 J	  3	   N	N	 J	  J	   J	N	 N	  N
 *	4: 4 Signale 2 Begriffig				 1	 J	  4	   N	N	 N	  N	   N	N	 N	  N
 *	5: 2 Einfahrsignale mit Vorsignal		 2	 J	  2	   J	N	 N	  N	   N	N	 N	  N
 *	6: 2 Haupt/sperrsignale					 2	 J	  2    J	N	 N	  N	   N	N	 N	  N
 *	7: 1 Einfahrsig. m. Vorsig. u. 1 VorSig. 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
 *  8: 1 Haupt/sperrsignal u. 1 Vorsignal	 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
 *  9: 1 Haupt/sperrsig. 1 Block HS/VS m. Dt 2	 J	  2	   J	J	 N	  N	   N	N	 N	  N
 * 10: Wie Mode7 aber mit Dunkeltastung		 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
 * 11: Wie Mode8 aber mit Dunkeltastung		 2	 J	  2    J	J	 N	  N	   N	N	 N	  N
 *																			
 *	Mode2 wird zum 4 fach Wechseler, wenn Parameter 5 (Impulsdauer) = 0 ist	
 *
 */
 
#define F_CPU 8000000L
#include <avr/io.h>
#include <stdbool.h>
#include <avr/interrupt.h>
#include <avr/eeprom.h>
#include "project.h"
#include "sfd_eeprom.h"


static void wait(uint8_t delay)
{
	
	cli();
	MyDelay = delay;
	sei();
	
	while(MyDelay) ;     // warten bis MyDelay auf 0 (Dimm_ISR)
}

static void action(uint8_t pattern, uint8_t valid, uint8_t mode)
{
	cli();
	action_out(pattern, valid, mode);
	sei();
}

static void init_main(void)
{		
	PORTA = (1<<PA0) | (1<<PA1);
	SXPORT = 0
	| (1 << PROGTASTER)		// Pullup - auf 1 setzen
	| (1 << SXTAKT)
	| (1 << SXDATA)
	| (1 << SXOUT_HI);
	
	SXDDR	= 0
	| (1<<SXOUT_LO)			// SXOUT Output
	| (1<<SXOUT_HI);				
		
	OUTDDR  = 0xFF;			// PortB: Alle Bits als Output			
	
	// Init Interrupt 0
	MCUCR = 0x01;			//jede logische Änderung an INT0-Pin erzeugt ein interrupt
	
	GIMSK = 0       
	| (1<<INT0);			// Enable INT0			
	
	 // 3000 Hz 8000000/3000-1
	 OCR1A = 2665;
	 // CTC  Prescaler 1
	 TCCR1B = 0 
	 | (1 << WGM12)
	 | (1 << CS10);
	 // Output Compare Match A Interrupt Enable
	 TIMSK  = 0 
	 | (1 << OCIE1A);
	
	eeprom_read_block(&Param, &EE_Param, sizeof(Param));
	
	CurMode = DecMode;
	init_pwm_array();
	sei();
}
static bool key_pressed(void)			
{	
	if (Prog_Pressed)
	{
		wait(DEBOUNCE);					// Taste entprellen
		if (Prog_Pressed)
		{
			while(Prog_Pressed);		// warten bis Taste losgelassen wird
			return false;
		}	
	}
	return true;	
}

void finish_program(void)
{	
	LastState = 0;
	eeprom_write_block(&Param,&EE_Param,sizeof(Param));
	
	sx_write(106,0,0xFF);				// programmieren zurücknehmen
	sx_write(105,0,0xFF);
	sx_write(104,0,0xFF);
	
	if (DecMode != CurMode)	Reset();
	Program_Off;
	Led_Off;
}

void start_program(void) 
{
	Led_On;
	Program_On;
	Par_Old = 255;
	
	sx_write(107,0,0xFF);
	sx_write(106,32,0xFF);				// programmieren setzen					 
	sx_write(105,MFGID,0xFF);
	sx_write(104,DEVID,0xFF);
	sx_write(1,0,0xFF);
	
	wait(KEYLOCK);
}

void do_program(void)
{
	uint8_t par;
	uint8_t data;
	bool	store;
	uint8_t pdata;
	
	data = sx_read(2);
	par = sx_read(1);
	
	pdata = par > sizeof(Param) - 2 ? 0 : Param[par];
	store = false;
	switch(par)
	{
		case 0:								// Decodermode
			if (data < 12) store = true;	// nur Mode 0 bis 11
			break;
		case 1:								// Adr1
		case 3:								// Adr2
			if ((data < 104) && (data > 2)) store = true; // nur Adresse 3 bis 103
			break;
		case 2:								// SubAdr1
		case 4:								// SubAdr2
		case 13:							// Multi-SubAdr0
		case 15:							// Multi-SubAdr1
		case 17:							// Multi-SubAdr2
		case 19:							// Multi-SubAdr3
			if (data < 4) store = true;		// Subadresse nur 0 bis 3
			break; 
		case 5:								// ImpTime
			if (data < 64) store = true;	// nur Bit 0-5 (0-63)
			break;
		case 6:								// TimeRatio
		case 7:								// RedDelay
		case 8:								// BarDelay
		case 9:								// BarImpTime
			if (data > 0) store = true;		// Zeitsteuerungsteuerung nur 1-255
			break;
		case 10:							// OptSw
		case 11:							// Multiadressmaske
			store = true;
			break;
		// Ungültige Adresse 104 = Vorignal dunkel
		case 12:							// Multi-Adr0
		case 14:							// Multi-Adr1
		case 16:							// Multi-Adr2
		case 18:							// Multi-Adr3
		if ((data < 105) && (data > 2)) store = true; // nur Adresse 3 bis 104
		break;
		default:
			break;
	}
	if ((store) && (par == Par_Old))
	{
		if (data != pdata)
		{
			Param[par] = data;				// Neuen Parameterwert speichern
			sx_write(0,0,0xFF);				// acknowledge für ProgTool
			init_pwm_array();
		}
	} else
	{
		sx_write(2,pdata,0xFF);				// Aktuellen Parameterwert auf den SX-Bus schreiben
		sx_write(0,0,0xFF);					// acknowledge für ProgTool
		if (par == 255)	finish_program();	// Pseudoparameter beendet Programmieren
	}
	Par_Old = par;
}

int main(void)
{
	uint8_t state;
	uint8_t mode;
	uint8_t adr;
	uint8_t sub;
	uint8_t maske;
	uint8_t laststate1;
	uint8_t laststate2;
	
	init_main();
	mode = CurMode;
	adr = Adr1;
	if (LastState & 0x80)
	{	// Letzte Weichenstellung auf SX-Bus schreiben 
		// nur wenn LS_OK-Flag (Bit7 = 1) gesetzt ist
		state = LastState & 0x0F; 
		laststate1 = state;
		maske = 0x0F;
		if (mode == 3) maske = 0x03;
		if bitRead(SubAdr1,0)
		{
			swapNipple(laststate1);
			swapNipple(maske);
		}
		sx_write(adr,laststate1,maske);
	} else
	{	// Adresse x 2 = Wartezeit,damit nicht alle Dekoder auf einmal schalten
		wait(adr << 1);
		state = 0;						//Signale HP0 / Weichen alle gerade
		
		// Ports in Grundstellung bringen
		(mode < 2) ? action(state,0xFF,mode) : action(state,0x0F,mode); 
		if (mode > 4) action(state,0xF0,mode | 0x80);	// 2. Signal extra
	}
	laststate1 = state;
	laststate2 = 0;
	bitSet(FLAG,Boot_Ok);				// Booten beendet
	seed = shiftreg_lo;					// Zufallszahl initialisieren
    while (1)
	{
		adr = Adr1;
		sub = 0;
		state = sx_read(adr);
		// bei Mode1 und Simultansteuerung schalten Werte > 0 alle Ports ein
		if ((bitRead(PSW,Sim)) && (state) && (mode == 1)) state = 0xFF;
		if (mode > 1)
		{
			sub = SubAdr1;
			if bitRead(sub,0) swapNipple(state);
			state &= 0x0F;
			if (mode == 3) state &= 0x07;
			if (mode > 4)
			{
				if bitRead(sub,1) state >>= 2;
				state &= 0x03;
			}
		}
		if (state != laststate1)
		{
			StateChange_On;					// Änderung merken
			action(state, state ^ laststate1, mode);
			laststate1 = state;
		}
		if (GleisSpg)
		{
			if (Programing) finish_program();
		} else
		{	// nur bei GleisSpg AUS programmieren oder letzte Stellung speichern
			if (check_prg_req(key_pressed(), adr, sub) == 0)
			{
				(Programing) ? finish_program() : start_program();
			}
			if (StateChange)				// nur wenn sich was geändert hat speichern
			{
				StateChange_Off;			// Änderung zurücknehmen
				// Nur Mode2 u. 3 Letzte Weichenstellung speichen mit gesetzten LS_OK-Flag (Bit7 = 1)
				if ((SaveLastState) && ((mode == 2) || (mode == 3))) eeprom_write_byte(&EE_LastState,state | 0x80);	
			}
		}
		if (Programing) do_program();
		if (mode > 4)					// 2. Adresse
		{
			adr = Adr2;
			sub = SubAdr2;
			if ((MultiAdrMode) && (mode > 6))
			{
				adr = sx_read(adr);			// Masteradresse lesen
				maske = MulMask;
				if (sub) swapNipple(adr);	
				adr ^= ~maske;				// Low od. High-Aktiv prüfen
				swapNipple(maske);		
				adr &= maske;				// nur die Aktiven ausfiltern
				if (adr & 0x07)				// nur die unteren 3 Bit
				{
					// Die zur Fahrstrasse/Weichenstellung passende
					// Hauptsignaladresse auswählen
					if bitRead(adr,2)		
					{
						adr = MulAdr3;
						sub = MulSubAdr3;
					} else if bitRead(adr,1)
					{
						adr = MulAdr2;
						sub = MulSubAdr2;	
					} else 
					{
						adr = MulAdr1;
						sub = MulSubAdr1;
					} // endif BitRead
				} else
				{
					// Keine aktiv, dann Defaultadresse
					adr = MulAdr0;
					sub = MulSubAdr0;
				} // endif adr
			} // endif MultiAdrMode
			// Kein gültiges Haupsignal im Fahrweg?
			if (adr == 104) {
				bitClear(FLAG,Vs_Ok);
				state = 0;
			}
			else {
				bitSet(FLAG,Vs_Ok);
				state = sx_read(adr);
			}
			if bitRead(sub,0) swapNipple(state);
			if bitRead(sub,1) state >>= 2;
			state &= 0x03;
			if (mode == 9) state &= 0x01;
			if (state != laststate2)
			{
				// Bit 7 im mode gesetzt = 2. Signal
				action(state, 0xF0, mode | 0x80);
				laststate2 = state;
			}	
		} // endif Mode > 8
    } // end While
}

