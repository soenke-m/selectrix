/*
 * SFD-V1
 * Signal u. Funktionsdekoder V1
 * 
 * Diese Quelldatei unterliegt der GNU General Public License,
 * die unter http://www.gnu.org/licenses/gpl.txt verfügbar ist.
 * Jede kommerzielle Nutzung, auch von Teilen, ist untersagt.
 *
 * Copyright (c) 2017 S.Marsch
 *
 * Header File project.h
 *
 * Created: 18.03.2017 11:12:44
 * Letzte Änderung 16.09.2019
 *
 *  Author: Sönke Marsch
 */ 


#ifndef PROJECT_H_
#define PROJECT_H_
#include <avr/io.h>

#define MFGID			0xF8		// Meine ID
#define DEVID			0x01		// UniDecoder  max 0x3F bit 6 und 7 werden für subadresse benötigt

// Definition für die DIMM-Engine
// für weitere Informationen siehe "sxtiny.S" Datei

#define PWM_STEPS		60			// Dimmstufen
#define DIMM_VAL_MIN	100			// aktiver Bereich 100-160
#define DIMM_VAL_MAX	161			// 
#define DIMM_UP_SPEED	6			// Auf- und Abdimmgeschwindigkeit = 200mS
#define DIMM_DOWN_SPEED	5			// für Glühlampen-Simulation = 240mS
#define DIMM_UP_DELAY	23			// Aufdimmverzögerung für neue Signalbilder = 460mS
#define BLINK_TIME		25			// = 500ms Blinkdauer Andreaskreuz
#define DEBOUNCE		5			// Tastenentprellung 100ms
#define KEYLOCK			25			// Totzeit nach Tastendruck 500 ms


// SX-Portbits
// PORTD:
#define LED				0			// Output, Status-LED
#define PROGTASTER		1			// Input Pull-Up
#define SXTAKT			2			// SX-T0, muß INT0-Pin sein
#define SXDATA			3			// SX-T1
#define SXOUT_HI		4			// SX-Data High
#define SXOUT_LO		5			// SX-Data Low
#define RESET			6			// Software Reset

// FLAG's
#define Gleisbit		7			// 1 = Gleisspannung ein
#define Prog			6			// 1 = Decoder im Programmiermodus
#define Boot_Ok			5			// 1 = Bootvorgang beendet
#define Change			4			// 1 = Adresse1-Daten geändert
#define Vs_Ok			3			// 1 = Gültiges Hautsignal für Vorsignalsteuerung (nur MultiAdressMode)
#define req				2			// 1 = Schreiben/Lesen anfordern
#define adr_ok			1			// 1 = Adresse komplett, ab jetzt Daten schreiben/lesen
#define base_ok			0			// 1 = Syncronisation und Basisadresse erkannt
 
 // Parameter-Schalter 
 // PSW
#define Mam				0			// Multiadressmodus nur Signal-Mode 9-11
#define Alt				1			// Multibitmodus (2/4 Bit Steuerung der Signale) Mode 8-11
#define Lss				2			// Laststatesave (speichern der letzten Weichenstellung) Mode2-3
#define Lza				3			// Lichtzeichenanlage (Bahnübergang mit Gelb/Rot-Ampel)
#define Sis				4			// Schrankenimpulssteuerung (für ein und aus je ein Impuls)
#define Nel				5			// Neonlampen-Simulation
#define Sim				6			// Simultanansteuerung der Ausgänge
#define Zst				7			// Zufallsteuerung beim Einschalten

#ifdef __ASSEMBLER__
	// Registervorgaben
	#define rzero			r1		// Null-Register wird vom GCC auf 0 gesetzt
	#define	ssave			r2		// Sicherungsregister für Statusport SX-ISR
	#define shiftreg_lo		r3		// Schieberegister für Sync und Basisadresse
	#define shiftreg_hi		r4
	#define bitcounter		r5		// Zähler für Unteradresse
	#define vbuffer			r6		// Schreib/Lesepuffer
	#define vmaske			r7		// Schreibmaske
	#define sisr			r8		// Sicherungsregister für Statusport PWM-ISR
	#define cur_dimm		r9		// akt. Dimmwerte ( 100-160)
	#define myrest			r10		// Zähler für sequenzielles Schalten
	#define seed			r11		// Zufallszähl
	
	
	
	// Portdefinition
	// PORTB = 8bit OutPort
	#define OUTPORT		_SFR_IO_ADDR(PORTB)
	#define INPORT		_SFR_IO_ADDR(PINB)

	// PORTD = SX-Bus
	#define SXPIN		_SFR_IO_ADDR(PIND)
	#define SXPORT		_SFR_IO_ADDR(PORTD)
	#define SXDDR		_SFR_IO_ADDR(DDRD)
	
	// Variablen	
	#define FLAG		_SFR_IO_ADDR(GPIOR0)
	#define SBUFFER		_SFR_IO_ADDR(GPIOR1)
	#define SMASKE		_SFR_IO_ADDR(GPIOR2)
	#define DIMM_DIR	_SFR_IO_ADDR(USIDR)
	#define PSW			_SFR_IO_ADDR(UBRRL)
	
	// EQU'S
	#define _SREG		_SFR_IO_ADDR(SREG) 
	#define _TIMSK		_SFR_IO_ADDR(TIMSK)
	#define _TIFR		_SFR_IO_ADDR(TIFR)
	#define _EEAR		_SFR_IO_ADDR(EEAR)
	#define _EECR		_SFR_IO_ADDR(EECR)
	#define _EEDR		_SFR_IO_ADDR(EEDR)
#else
	// Registervorgaben								____
	register uint8_t ssave			asm("r2");	//		|
	register uint8_t shiftreg_lo	asm("r3");	//		|
	register uint8_t shiftreg_hi	asm("r4");	//		|
	register uint8_t bitcounter		asm("r5");	//		|
	register uint8_t vbuffer		asm("r6");	//		|----->	Registergebundene Variablen 
	register uint8_t vmaske			asm("r7");	//		|		benutzt in "asm" (sxtiny.S)
	register uint8_t sisr			asm("r8");	//		|	
	register uint8_t cur_dimm		asm("r9");	//		|
	register uint8_t myrest			asm("r10");	//		|
	register uint8_t seed			asm("r11");	//	____|
	
	// PORTB = 8bit OutPort
	#define OUTPORT		PORTB
	#define INPORT		PINB
	#define OUTDDR		DDRB
	
	// PORTD = SX-Bus
	#define SXPIN		PIND
	#define SXPORT		PORTD
	#define SXDDR		DDRD
	
	// Variablen
	#define FLAG		GPIOR0
	#define PSW			UBRRL
	
	// Macro's für die Bitmanipulation
	#ifndef cbi
	#define cbi(sfr, bit) (_SFR_BYTE(sfr) &= ~_BV(bit))
	#endif
	#ifndef sbi
	#define sbi(sfr, bit) (_SFR_BYTE(sfr) |= _BV(bit))
	#endif
	#define bitRead(value, bit) (((value) >> (bit)) & 0x01)
	#define bitSet(value, bit) ((value) |= (1UL << (bit)))
	#define bitClear(value, bit) ((value) &= ~(1UL << (bit)))
	#define swapNipple(value) (value = (value<<4) | (value>>4))
	
	#define SaveLastState	bitRead(PSW,Lss)				// Letzte Stellung speicher ja/nein (Mode 2 u. 3)
	#define MultiBitMode	bitRead(PSW,Mbm)				// Steuerung Sh1 abhängig von Fahrstrasse (ab Mode 7)
	#define MultiAdrMode	bitRead(PSW,Mam)				// Fahrstrassenabhängige Vorsignalsteuerung (ab Mode 8)
	#define StateChange		bitRead(FLAG, Change)			// Änderung der letzten Decoder Stellung
	#define StateChange_On	bitSet(FLAG, Change)
	#define StateChange_Off	bitClear(FLAG, Change)
	#define Program_On		bitSet(FLAG, Prog)				// Programmieren einschalten
	#define Program_Off		bitClear(FLAG, Prog)			// Programmieren ausschalten
	#define Programing		bitRead(FLAG, Prog)				// programmieren ein/aus
	#define GleisSpg		bitRead(FLAG, Gleisbit)			// Gleisspannung ein/aus
	#define Prog_Pressed	!bitRead(SXPIN, PROGTASTER)		// Programmiertaster gedrückt = 1
	#define Led_On			bitSet(SXDDR, LED)				// LED einschalten
	#define Led_Off			bitClear(SXDDR, LED)			// LED ausschalten
		
	// Hardwarereset
	static inline void Reset() __attribute__((always_inline));
	void Reset()
	{
		bitSet(SXDDR, RESET);
	}
	
	// Parameter-Array
	uint8_t Param[21];
	// Zugriff über Namen definieren
	#define DecMode		Param[0]
	#define Adr1		Param[1]
	#define SubAdr1		Param[2]
	#define Adr2		Param[3]
	#define SubAdr2		Param[4]
	#define ImpTime		Param[5]
	#define TimeRatio	Param[6]
	#define RedDelay	Param[7]
	#define BarDelay	Param[8]
	#define BarImpTime	Param[9]
	#define OptSw		Param[10]
	#define MulMask		Param[11]
	#define MulAdr0		Param[12]
	#define MulSubAdr0	Param[13]
	#define MulAdr1		Param[14]
	#define MulSubAdr1	Param[15]
	#define MulAdr2		Param[16]
	#define MulSubAdr2	Param[17]
	#define MulAdr3		Param[18]
	#define MulSubAdr3	Param[19]
	#define LastState	Param[20]
	
	
	volatile uint8_t MyDelay;		// wir alle 18mS decremented
	volatile uint8_t CurMode;
	uint8_t Par_Old;
	
	extern uint8_t check_prg_req(uint8_t key, uint8_t adr,uint8_t subadr);
	extern void init_pwm_array(void);
	extern void action_out(uint8_t pattern, uint8_t valid, uint8_t mode);
	extern uint8_t sx_read (uint8_t ch);
	extern void sx_write (uint8_t ch, uint8_t data, uint8_t mask);
	
#endif /* __ASSEMBLER__ */

#endif /* PROJECT_H_ */