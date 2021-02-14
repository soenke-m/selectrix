 /*
 * SFD-V1
 * Signal u. Funktionsdekoder V1
 * 
 * Diese Quelldatei unterliegt der GNU General Public License,
 * die unter http://www.gnu.org/licenses/gpl.txt verfügbar ist.
 * Jede kommerzielle Nutzung, auch von Teilen, ist untersagt.
 *
 * Copyright (c) 2020 S.Marsch
 *
 * Header File sfd_eeprom.h
 *
 * Created: 26.03.2020 17:50:35
 * 
 *  Author: Sönke Marsch
 */ 


#ifndef SFD_EEPROM_H_
#define SFD_EEPROM_H_
#include <avr/eeprom.h>

//-----------------------------------------------------------------------------
// Daten im EEPROM:
//

uint8_t EEMEM EE_Param [21]		=
{
	2,		// EE_DecMode		Betriebsart (Default Weichendekoder)
	15,		// EE_Adr1			Basisadresse od. Adresse 1. Signal
	0,		// EE_SubAdr1		Auswahl oberes od. unteres Nibble. (Bit0)
	16,		// EE_Adr2			Zusatzadresse 2. Signal im Multiadressmode Masteradresse
	0,		// EE_SubAdr2		Auswahl oberes od. unteres Nibble. (Bit0)
	20,		// EE_ImpTime		Impulsdauer in 20mS-Schritten, nur Bit 0-5 (0-63) Standart 400mS
	20,		// EE_TimeRatio		Streckungsfaktor für Zufallssteuerung bei der Strassenbeleuchtung
	75,		// EE_RedDelay		Verzögerung bis Gelb aus / Rot an bei BÜ mit Lichtzeichenanlage
	//							(1,5 Sek). Nur wenn Lza = Lichtzeichenanlage in	OptSw gesetzt ist.
	125,	// EE_BarDelay		Verzögerung bis Schrankenrelais schaltet (2,5 Sek). Nur BÜ.
	25,		// EE_BarImpTime	Impulsdauer für Schranken auf/zu (0,5 Sek). Nur BÜ, nur OptSw Bit 4 = 1
	0,		// EE_OptSw			Optionsschalter:
	//			Bit 0:Mam		Fahrstraßenanhängige Vorsignalsteuerung (Mode 7 - 11)
	//			Bit 1:Alt		Alternative Signalansteuerung (mode 5 - 11)
	//			Bit 2:Lza		Lichtzeichenanlage bei Bahnübergang (Mode 3)
	//			Bit	3:Sis		Schrankenimpulssteuerung für Schrankenantrieb
	//			Bit 4:Lss		Speichern der letzten Weichenstellung (nur Mode 2 und 3)
	//			Bit 5:Nel		Simuliert das Flackern von Neonleuchten (nur Mode1)
	//			Bit	6:Sim		Simultansteuerung z.B. Strassenbeleuchtung (nun Mode1)
	//			Bit 7:Zst		Zufallsgesteuertes einschalten (nur Mode1, nur wenn Sim=1)
	0,		// EE_MulMask		MulMask:	Nur aktiv wenn Mam = MultiadressMode in OptSw gesetzt ist.
	//			Bit 0:			0 od 1 aktiv  Multiadresse 1
	//			Bit 1:			0 od 1 aktiv  Multiadresse 2
	//			Bit 2:			0 od 1 aktiv  Multiadresse 3
	//			Bit 4:			inaktiv od aktiv  Multiadresse 1
	//			Bit 5:			inaktiv od aktiv  Multiadresse 2
	//			Bit 6:			inaktiv od aktiv  Multiadresse 3
	//			Bit 3 und 7:	nicht verwendet
	//							wenn Multiadresse 3 - 1 (von MSB nach LSB) nicht aktiv, dann
	//							wird die default Adresse = MulAdr0 genommen.
	// Multiadressen:			Nur für 2. Signal, nur (Mode 7 - 11)
	//							____
	17,		// EE_MulAdr0			|
	0,		// EE_MulSubAdr0		|
	18,		// EE_MulAdr1			|
	0,		// EE_MulSubAdr1		|__ Nur aktiv wenn Mam = MultiadressMode
	19,		// EE_MulAdr2			|	in OptSw gesetzt ist.
	0,		// EE_MulSubAdr2		|
	20,		// EE_MulAdr3			|
	0,		// EE_MulSubAdr3	____|
	0		// EE_LastState		letzte Weichenstellung (nur Mode 2 und 3)
};
#define EE_LastState	EE_Param[20]

//Defaultwerte
uint8_t EEMEM EE_Default [21]	= {2,15,0,16,0,20,20,75,125,25,0,0,17,0,18,0,19,0,20,0,0};

/*==============================================================================
// Bitmuster für verschieden Signale
//
// Mode5  zwei unabhängige Einfahrsignale mit Vorsignal (a/b) (2 Adressen)
//																 _______
// Anschluß:													/		\
//			 bbbbaaaa											| 	  2	|
// Klemme:	 87654321     HS1		VS1		Diode				| 	    |
//					|---- Rot  1	Gelb1 1 -|<- Gelb2 3		|	  	|
//				   |----- Grün 2	Grün1 2						| 1	  3	|
//				  |------ Gelb 3			-|<- Gelb2 3		|_______|
//				 |-----------------	Grün2 4						    |
//																   ______
//						  HS2		VS2		Diode				 / 1  2	/
//			  	|-------- Rot  1	Gelb1 1 -|<- Gelb2 3		/	   /
//			   |--------- Grün 2	Grün1 2					   / 3  4 /
//			  |---------- Gelb 3			-|<- Gelb2 3	  /______/
//			 |--------------------- Grün2 4						  |
*/

unsigned char EE_Signal_DB1[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0 vr0
	0b00001010,     // hp1 vr1
	0b00000001,     // hp0 vr0
	0b00000110,     // hp2 vr2
	0b00010000,     // hp0 vr0
	0b10100000,     // hp1 vr1
	0b00010000,     // hp0 vr0
	0b01100000	    // hp2 vr2
	
};

/*

// Mode6  zwei unabhängige Ausfahrsignale (a/b)  (2 Adressen)
//															 _______
// Anschluß:				Anschluß von Rot2 über Dioden	/		\
//			 bbbbaaaa										| 2		|
// Klemme:	 87654321	   HS1	  Diode						| x	  1 |
//					|---- Rot1  1 -|<- Rot2 (Anschluß x)	|	  4	|
//				   |----- Grün	2							| 4		|
//				  |------ Gelb	3							|		|
//				 |------- Weiß  4 -|<- Rot2 (Anschluß x)	| 3		|
//															|_______|
//						   HS2								    |
//				|-------- Rot1	1 -|<- Rot2 (Anschluß x)
//			   |--------- Grün	2
//			  |---------- Gelb	3
//			 |----------- Weiß	4 -|<- Rot2 (Anschluß x)
*/

unsigned char EE_Signal_DB2[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0
	0b00000010,     // hp1
	0b00001000,     // sh1
	0b00000110,     // hp2
	0b00010000,     // hp0
	0b00100000,     // hp1
	0b10000000,		// sh1
	0b01100000	    // hp2
};

/* Mode7   1. Adr. Einfahrthauptsignal mit abhängigen Vorsignal	(1..4)
//		   2. Adr. unabhängiges mehrbegriffiges Vorsignal  (5..8)
//																 _______
// Anschluß:													/		\
//			 bbbbaaaa											|	  2	|
// Klemme:	87654321      HS		VS		Diode				| 	    |
//					|---- Rot  1	Gelb1 1 -|<- Gelb2 3		|	  	|
//				   |----- Grün 2	Grün1 2						| 1	  3	|
//				  |------ Gelb 3			-|<- Gelb2 3		|_______|
//				 |-----------------	Grün2 4						    |
//																  _______
//																 / 1  2	/
//																/	   /
//															   / 3  4 /
//															  /______/
//																  |
//						   VS2									  _______
//				|-------- Gelb 1	5							 / 5  7	/
//			   |--------- Gelb 2	6							/	   /
//			  |---------- Grün 1	7						   / 6  8 /
//			 |----------- Grün 2	8						  /______/
//																  |

*/

unsigned char EE_Signal_DB3[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0
	0b00001010,     // hp1
	0b00000001,     // hp0
	0b00000110,     // hp2
	0b00110000,     // vr0
	0b11000000,     // vr1
	0b00110000,     // vr0
	0b01100000      // vr2
};

/* Mode8   1. Adr. mehrbegriffiges Hauptsignal (1..4)
//		   2. Adr. unabhängiges mehrbegriffiges Vorsignal  (5..8)
//															 _______
// Anschluß:				Anschluß von Rot2 über Dioden	/		\
//			 bbbbaaaa										| 2		|
// Klemme:	 87654321	   HS	  Diode						| x	  1 |
//					|---- Rot1  1 -|<- Rot2 (Anschluß x)	|	  4	|
//				   |----- Grün	2							| 4		|
//				  |------ Gelb	3							|		|
//				 |------- Weiß  4 -|<- Rot2 (Anschluß x)	| 3		|
//															|_______|
//																|
//						   VS								  _______
//				|-------- Gelb 1	5						 / 5  7	/
//			   |--------- Gelb 2	6						/	   /
//			  |---------- Grün 1	7					   / 6  8 /
//			 |----------- Grün 2	8					  /______/
//															  |
*/

unsigned char EE_Signal_DB4[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0
	0b00000010,     // hp1
	0b00001000,     // sh1
	0b00000110,     // hp2
	0b00110000,     // vr0
	0b11000000,     // vr1
	0b00110000,	    // vr0
	0b01100000      // vr2
};

/* Mode9   1. Adr. Ausfahrhauptsignall (1..4)
//		   2. Adr. Blockhauptsignal mit abhängigen Vorsignal am Mast des
//					Ausfahrsignal mit Dunkeltastung (5..8)
//																 _______
// Anschluß:				Anschluß von Rot2 über Dioden		/		\
//			 bbbbaaaa											| 2		|
// Klemme:	 87654321	   HS	  Diode							| x	  1 |
//					|---- Rot1  1 -|<- Rot2 (Anschluß x)		|	  4	|
//				   |----- Grün	2								| 4		|
//				  |------ Gelb	3								|		|
//				 |------- Weiß  4 -|<- Rot2 (Anschluß x)		| 3		|
//																|_______|
//							Blockvorsignal						   _|_____
//				|--------------- Gelb 	5					      / 5  6 /
//			   |---------------- Grün 	6					     /	    /
//															    / 5  6 /
//														       /______/
//							Blockhauptsignal					    |
//			  |---------- Rot	7								 _______
//			 |----------- Grün	8								/		\
//																|	  	|
//																| 	    |
//																|	  	|
//																| 7	  8	|
//																|_______|
//																	|
*/

unsigned char EE_Signal_DB5[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0
	0b00000010,     // hp1
	0b00001000,     // sh1
	0b00000110,     // hp2
	0b01010000,     // hp0/vr0
	0b10100000,     // hp1/vr1
	0b01000000,		// hp0/vr Dunkeltastung
	0b10000000      // hp1/vr Dunkeltastung
};


/* Mode10  1. Adr. Einfahrhauptsignal mit abhängigen Vorsignal	(1..4)
//		   2. Adr. Ausfahrvorsignal am Mast des Einfahrsignal mit Dunkeltastung (5..8)
//																 _______
// Anschluß:													/		\
//			 bbbbaaaa											|	  2	|
// Klemme:	 87654321     Einfahrhauptsignal					|		|
//					|---- Rot  1								|	  	|
//				   |----- Grün 2								| 1	  3	|
//				  |------ Gelb 3								|_______|
//						  Ausfahrvorsignal						  __|____
//				|--------------- Gelb 1	5					     / 5  7 /
//			   |---------------- Gelb 2	6					    /	   /
//			  |----------------- Grün 1	7					   / 6  8 /
//			 |------------------ Grün 2	8				      /______/
//						  Einfahrvorsignal						    |
//					|-----------  Gelb1 1 -|<- Gelb2 3			  _______
//				   |------------  Grün1 2						 / 1  2	/
//			   	  |-------------		  -|<- Gelb2 3			/	   /
//			  	 |--------------  Grün2 4					   / 3  4 /
//			 												  /______/
//																  |
*/

unsigned char EE_Signal_DB6[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0
	0b00001010,     // hp1
	0b00000001,     // hp0
	0b00000110,     // hp2
	0b00110000,     // vr0
	0b11000000,     // vr1
	0b00000000,		// Dunkeltastung
	0b01100000      // vr2
};

/* Mode11  1. Adr. mehrbegriffiges Hauptsignal (1..4)
//		   2. Adr. unabhängiges mehrbegriffiges Vorsignal (5..8)
//					am gleichen Mast mit Dunkeltastung
//
// Anschluß wie Mode 8
*/

unsigned char EE_Signal_DB7[8] EEMEM =
{
	//Bitmuster
	0b00000001,     // hp0
	0b00000010,     // hp1
	0b00001000,     // sh1
	0b00000110,     // hp2
	0b00110000,     // vr0
	0b11000000,     // vr1
	0b00000000,		// Dunkeltastung
	0b01100000      // vr2
};
//--------------------------------------------------------------------------------------

#endif /* SFD_EEPROM_H_ */