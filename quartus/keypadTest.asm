

ORG 0
Start:
	CALL	Delay
	CALL   	Display
	Jump Start


  	

Display:
	LOAD 	Zero
	OUT 	Hex1
	IN     	KEYPAD
	OUT		Hex1
	Return

Delay:
		OUT 	Timer
WaitingLoop:
		IN		Timer
		JZERO	WaitingLoop
		RETURN

Initial:  DW 0

; Useful values

Zero:      DW &B0000000000
NegOne:    DW -1
One:
Bit0:      DW &B0000000001
Bit1:      DW &B0000000010
Bit2:      DW &B0000000100
Bit3:      DW &B0000001000
Bit4:      DW &B0000010000
Bit5:      DW &B0000100000
Bit6:      DW &B0001000000
Bit7:      DW &B0010000000
Bit8:      DW &B0100000000
Bit9:      DW &B1000000000
LoByte:    DW &H00FF
HiByte:    DW &HFF00
hexPos1:   DW &B0000001111
hexPos2:   DW &B0011110000


; IO address constants
Switches:  EQU &H000
LEDs:      EQU &H001
Timer:     EQU &H002
Hex0:      EQU &H004
Hex1:      EQU &H005
RANGEFINDER: EQU &H0F0
KEYPAD: EQU &H0F1