; DemoApp.asm

;
; MAIN LOOP
;

ORG 0
		LOAD State_Measure
		STORE State
		LOAD Unit_Millimeters
		STORE Current_Unit
        OUT Timer
		LOADI 0
        STORE cycleStartTime
MainLoop:
        ;CALL  CheckForUserMenuStart
        ;JZERO MenuDone
        ;CALL  LaunchUserMenu
    ;MenuDone:
        ;CALL  Measure
        ;CALL  Alert
        ;JUMP  MainLoop
        IN Timer
        STORE CurrentTime
        
		IN RANGEFINDER
		STORE Rangefinder_Measurement
		
        CALL Alert
        
		; Store previous input
		LOAD KeypadInput
		STORE PrevKeypadInput
		
		; Read Keypad Input
		CALL  ReadKeypadAsync
		STORE KeypadInput 
		
		LOAD State
		SUB State_Measure
		JZERO Handle_State_Measure
		LOAD State
		SUB State_Main_Menu
		JZERO Handle_State_Main_Menu
		LOAD State
		SUB State_Target_Distance_Menu
		JZERO Handle_State_Target_Distance_Menu
		LOAD State
		SUB State_Unit_Menu
		JZERO Handle_State_Unit_Menu
		LOAD State
		SUB State_Keypad_Press
		JZERO Handle_State_Keypad_Press
		
Handle_State_Measure:
		CALL Handle_State_Measure_Display
		CALL Handle_State_Measure_Input
		JUMP MainLoop
		
Handle_State_Main_Menu:
		CALL Handle_State_Main_Menu_Display
		CALL Handle_State_Main_Menu_Input
		JUMP MainLoop
		
Handle_State_Target_Distance_Menu:
		CALL Handle_State_Target_Distance_Menu_Display
        CALL Handle_State_Target_Distance_Menu_Input
		JUMP MainLoop
		
Handle_State_Unit_Menu:
		CALL Handle_State_Unit_Menu_Display
		CALL Handle_State_Unit_Menu_Input
		JUMP MainLoop
		
Handle_State_Keypad_Press:
		CALL Handle_State_Keypad_Press_Display
		CALL Handle_State_Keypad_Press_Input
		JUMP MainLoop
	

; 
;	State_Measure Logic
;	

Handle_State_Measure_Display:
		LOADI &H00
		OUT Hex1
		LOAD Rangefinder_Measurement
		OUT Hex0
		RETURN

Handle_State_Measure_Input:
		LOAD KeypadInput
		SUB KEY_STAR
		JZERO continue6
		RETURN
	continue6:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue7
		CALL Launch_Main_Menu 
	continue7:
		RETURN

;
;	State_Main_Menu Logic 
;

Handle_State_Main_Menu_Display:
		LOADI 	&H01
        OUT   	Hex1
		LOADI 	&H0203
		OUT		Hex0
        RETURN

Handle_State_Main_Menu_Input:
		LOAD KeypadInput
		SUB KEY_1
		JZERO launch1
		JUMP continue1
	launch1:
		CALL Launch_Target_Distance_Menu
		RETURN
	continue1:
		LOAD KeypadInput
		SUB KEY_2
		JZERO launch2
		JUMP continue2
	launch2:
		CALL Launch_Unit_Menu
		RETURN
	continue2:
		LOAD KeypadInput
		SUB KEY_3
		JZERO launch3
		JUMP continue3
	launch3:
		CALL Launch_Keypad_Press_Menu
		RETURN
	continue3:
		LOAD KeypadInput
		SUB KEY_STAR
		JZERO continue4
		RETURN
	continue4:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue5
		CALL Launch_Measure 
	continue5:
		RETURN

;
;	State_Target_Distance_Menu Logic
;

Handle_State_Target_Distance_Menu_Display:
		; print DA for Distance Active
        LOADI 	&HDA
        OUT   	Hex1
        ; print current AlertDistance
		LOAD    AlertDistance
		OUT		Hex0
        RETURN

Handle_State_Target_Distance_Menu_Input:
		LOAD KeypadInput
		SUB KEY_STAR ; back
		JZERO continue_td_1
		JUMP continue_td_2
	continue_td_1:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue_td_2
		CALL Launch_Main_Menu 
		RETURN
    continue_td_2:
        LOAD KeypadInput
		SUB KEY_POUND ; start typing
		JZERO continue_td_3
		JUMP td_return
	continue_td_3:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO td_return
    td_mandatory_input_loop_pre:
        LOADI &HD0
        OUT Hex1
        CALL ResetKeypad
        ; init local vars
        LOADI -1
        STORE digit0
        STORE digit1
        STORE digit2
    ; user can enter up to a 3-digit number
	td_mandatory_input_loop:
		IN Keypad
        STORE td_input
        ; if no key press, keep polling
        JNEG td_mandatory_input_loop
        ; else, we need to process the key press
        ; check for special buttons
        LOAD td_input
        SUB KEY_STAR ; back button
        JZERO td_back
        LOAD td_input
        SUB KEY_POUND ; enter button
        JZERO td_input_done
        ; select digit
        LOAD digit2
        JPOS td_saveDigit1
        JZERO td_saveDigit1
        LOAD td_input
        STORE digit2
        OUT Hex0
        CALL ResetKeypad
        LOADI 2
        CALL Delay ; 0.2s delay helps prevent situation with keydown mode where user press and hold is registered as multiple presses
        JUMP td_mandatory_input_loop
    td_saveDigit1:
        LOAD digit1
        JPOS td_saveDigit0
        JZERO td_saveDigit0
        LOAD td_input
        STORE digit1
        LOAD digit2
        SHIFT 4
        ADD digit1
        OUT Hex0
        LOADI 2
        CALL Delay
        CALL ResetKeypad
        JUMP td_mandatory_input_loop
    td_saveDigit0:
        LOAD td_input
        STORE digit0
        JUMP td_input_done
    
    td_back:
        CALL Launch_Main_Menu
        RETURN
        
    ; Compute Target Distances
	td_input_done:
    ; handle invalid digits
        LOAD digit2
        JNEG td_handleZeroDigitNumber
        LOAD digit1
        JNEG td_handleOneDigitNumber
        LOAD digit0
        JNEG td_handleTwoDigitNumber
        JUMP td_convert_digits_to_number
      td_handleZeroDigitNumber:
        LOADI 0
        OUT Hex0
        STORE AlertDistance
        STORE WarningDistance
        STORE CautionDistance
        RETURN
      td_handleOneDigitNumber:
        LOAD digit2
        STORE digit0
        LOADI 0
        STORE digit2
        STORE digit1
        JUMP td_convert_digits_to_number
      td_handleTwoDigitNumber:
        LOAD digit1
        STORE digit0
        LOAD digit2
        STORE digit1
        LOADI 0
        STORE digit2
      td_convert_digits_to_number:
        ; convert the 3 digits into 1 number
        ; digit0 is the 1's place, digit1 is the 16's place, and digit2 is the 256's place
        LOAD digit2
        SHIFT 4
        ADD digit1
        SHIFT 4
        ADD digit0
        ; set distances
        STORE AlertDistance
        OUT Hex0
        ; WarningDistance = AlertDistance * 1.5
        SHIFT -1
        ADD AlertDistance
        STORE WarningDistance
        ; CautionDistance = AlertDistance * 2
        LOAD AlertDistance
        ADD AlertDistance
        STORE CautionDistance
        LOADI &H11
        OUT Hex1
      td_return:
        RETURN

locals:
    td_input:       DW 0
    digit0:         DW -1 ; right-most
    digit1:         DW -1 ; middle
    digit2:         DW -1 ; left-most
		
ResetKeypad:
        IN Keypad
        JNEG reset_complete
        JUMP ResetKeypad
    reset_complete:
        RETURN
		
;
;	State_Unit_Menu Logic
;

Handle_State_Unit_Menu_Display:
		LOAD Current_Unit
		SUB Unit_Millimeters
		JZERO using_mm
		LOAD Current_Unit
		SUB Unit_Centimeters
		JZERO using_cm
		LOAD Current_Unit
		SUB Unit_Inches
		JZERO using_in
		JUMP other_unit
	using_mm:
		LOADI 	&HA6
        OUT   	Hex1
		LOADI 	&H0204
		OUT		Hex0
		RETURN
	using_in:
		LOADI 	&H06
        OUT   	Hex1
		LOADI 	&H02A4
		OUT		Hex0
        RETURN
	using_cm:
		LOADI 	&H06
        OUT   	Hex1
		LOADI 	&H0204
		STORE	unit_menu_temp_var
		LOADI	&HA0
		SHIFT	8
		OR		unit_menu_temp_var
		OUT		Hex0
        RETURN
	other_unit:
		LOADI 	&H06
        OUT   	Hex1
		LOADI 	&H0204
		OUT		Hex0
		RETURN
	unit_menu_temp_var:
		DW &H0
		
Handle_State_Unit_Menu_Input:	
		LOAD KeypadInput
		SUB KEY_STAR
		JZERO continue8
		JUMP continue9
	continue8:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue9
		CALL Launch_Main_Menu 
		RETURN
	continue9:
		LOAD KeypadInput
		SUB KEY_6
		JZERO continue10
		JUMP continue11
	continue10:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue11

		LOAD Unit_Millimeters
		STORE Current_Unit
		LOAD Unit_Millimeters
		OUT RANGEFINDER
		RETURN
	continue11:
		LOAD KeypadInput
		SUB KEY_2
		JZERO continue12
		JUMP continue13
	continue12:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue13

		LOAD Unit_Centimeters
		STORE Current_Unit
		LOAD Unit_Centimeters
		OUT RANGEFINDER
		RETURN
	continue13:
		LOAD KeypadInput
		SUB KEY_4
		JZERO continue14
		JUMP continue15
	continue14:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue15

		LOAD Unit_Inches
		STORE Current_Unit
		LOAD Unit_Inches
		OUT RANGEFINDER
		RETURN
	continue15:
		RETURN
;
;	Handle_State_Keypad_Press Logic
;

; Current_Keypress_Mode:	DW 0

; Mode_Keydown:	DW 0
; Mode_Keyup:		DW 1

Handle_State_Keypad_Press_Display:
		LOAD Current_Keypress_Mode
		SUB Mode_Keydown
		JZERO mode_down
		LOAD Current_Keypress_Mode
		SUB Mode_Keyup
		JZERO mode_up
		JUMP default
	mode_down:
		LOADI &H08
		OUT Hex1
		LOADI &H0A3
		OUT Hex0
		RETURN
	mode_up:
		LOADI 	&HA8
        OUT   	Hex1
		LOADI 	&H0003
		OUT		Hex0
        RETURN
	default:
		LOADI 	&H08
        OUT   	Hex1
		LOADI 	&H0003
		OUT		Hex0
        RETURN

; Current_Keypress_Mode:	DW 0

; Mode_Keydown:	DW 0
; Mode_Keyup:		DW 1

Handle_State_Keypad_Press_Input:
		LOAD KeypadInput
		SUB KEY_STAR
		JZERO continue_kp_1
		JUMP continue_kp_2
	continue_kp_1:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue_kp_2
		CALL Launch_Main_Menu 
		RETURN
	continue_kp_2:
		LOAD KeypadInput
		SUB KEY_3
		JZERO continue_kp_3
		JUMP continue_kp_4
	continue_kp_3:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue_kp_4
		
		LOAD Mode_Keydown
		STORE Current_Keypress_Mode
		LOAD Mode_Keydown
		OUT KEYPAD
		RETURN
	continue_kp_4:
		LOAD KeypadInput
		SUB KEY_8
		JZERO continue_kp_5
		JUMP continue_kp_6
	continue_kp_5:
		LOAD KeypadInput
		SUB PrevKeypadInput
		JZERO continue_kp_6
		
		LOAD Mode_Keyup
		STORE Current_Keypress_Mode
		LOAD Mode_Keyup
		OUT KEYPAD
		RETURN
	continue_kp_6:
		RETURN



;
;	Common Functions
;

Launch_Measure:
		LOAD State_Measure
		STORE State
		RETURN

Launch_Main_Menu:
		LOAD State_Main_Menu
		STORE State
		RETURN

Launch_Target_Distance_Menu:
		LOAD State_Target_Distance_Menu
		STORE State
		RETURN

Launch_Unit_Menu:
		LOAD State_Unit_Menu
		STORE State
		RETURN

Launch_Keypad_Press_Menu:
		LOAD State_Keypad_Press
		STORE State
		RETURN


;
;  LOGIC
;

; Returns 1 when user presses star, else 0
CheckForUserMenuStart:
        LOAD KeypadInput
        SUB   KEY_STAR
        JZERO menustart_true
    menustart_false:
        LOADI 0
        RETURN
    menustart_true:
        LOADI 1
        RETURN



; Eventually this will be where the bulk of the menuing logic lives
; for now this is just a simple print to demonstrate CheckForUserMenuStart
LaunchUserMenu:
        LOADI 	&H01
        OUT   	Hex1
		LOADI 	&H0203
		OUT		Hex0
        LOADI 10
        CALL  Delay
        RETURN



; Eventually this will perform the rangefinder measurement
Measure:
        CALL  ReadKeypadAsync
        OUT   Hex1
        RETURN



; Eventually this will control the LED flashing based on measurement
; (if the backup sensor idea is the one we go with)
; measurement passed in AC
Alert:
  ; CheckAlert:
            LOAD Rangefinder_Measurement
            SUB   AlertDistance
            JPOS  CheckWarning
            LOADI alertPeriod
            STORE period
            JUMP  blink
    CheckWarning:
            LOAD  Rangefinder_Measurement
            SUB   WarningDistance
            JPOS  CheckCaution
            LOADI warningPeriod
            STORE period
            JUMP  blink
    CheckCaution:
            LOAD  Rangefinder_Measurement
            SUB   CautionDistance
            JPOS  NoAlert ; no object within alertDistance * 2
            LOADI cautionPeriod
            STORE period
    Blink:
            LOAD CurrentTime
            SUB cycleStartTime
            SUB period
            JNEG do_the_LEDs
    switch_cycle:
            LOAD cycle
            JPOS switch_to_0
  ; switch_to_1
            LOADI 1
            STORE cycle
            JUMP finish_switch
    switch_to_0:
            LOADI 0
            STORE cycle
    finish_switch:
            LOAD CurrentTime
            STORE cycleStartTime
    do_the_LEDs:
            LOAD  cycle ; alternate each iteration between LED up and LED down
            JPOS  LED_Up
  ; LED_Down:
            LOADI 0
            OUT   LEDs
            RETURN
    LED_Up:
            LOADI -1
            OUT   LEDs
            RETURN
    NoAlert:
            LOADI 0
            OUT LEDs
            RETURN
; locals:
cycle:          DW 1   ; 1 = blink, 0 = delay
cycleStartTime: DW 0
period:         DW 0
alertPeriod:    EQU 1  ; 5 blinks / sec (cyles of 0.1s up 0.1s down)
warningPeriod:  EQU 2  ; 2.5 blinks / sec (cycles of 0.2s up 0.2s down)
cautionPeriod:  EQU 5  ; 1 blink / sec (cycles of 0.5s up 0.5s down


;
; UTILITY FUNCTIONS
;

; Attempts to read a single key, but will not wait for user
; basically, if any keypad input has been registered since the last
; IN call, this will return the value, else it will return -1
ReadKeypadAsync:
        ;LOAD  KeypadSettingsVector
        ;OUT   KEYPAD
        IN    KEYPAD ; -1 will eventually mean no press, for now 0
        JPOS  AsyncReadDone
    Fail:
        LOADI -1
    AsyncReadDone:
        RETURN



; Waits for user to enter a string of keys
ReadKeypadSync:
        RETURN



; Performs a sleep for N ticks at 10Hz
; N passed in AC
Delay:
        STORE  ticks
        LOAD CurrentTime
        STORE delayStartTime
    WaitingLoop:
        IN     Timer
        SUB    delayStartTime
        SUB    ticks
        JNEG   WaitingLoop  ; wait until the timer records
                            ; N clock ticks @ 10 Hz
        RETURN
; locals:
ticks: DW 0
delayStartTime: DW 0

;
; DATA
;


KeypadInput:	DW &HFFFF
PrevKeypadInput:	DW &HFFFF

State:	DW 0

State_Measure:	DW 0
State_Main_Menu:	DW 1
State_Target_Distance_Menu:		DW 2
State_Unit_Menu:	DW 3
State_Keypad_Press:		DW 4

Rangefinder_Measurement: DW 0

Current_Unit: DW 0

Unit_Millimeters:	DW &H0000
Unit_Centimeters:	DW &H0001
Unit_Inches:		DW &H0010


Current_Keypress_Mode:	DW 0

Mode_Keydown:	DW &H0000
Mode_Keyup:		DW &H0001



; Globals
CurrentTime:               DW 0
KeypadSettingsVector:      DW 0
RangefinderSettingsVector: DW 0
AlertDistance:             DW 0
WarningDistance:           DW 0 ; AlertDistance * 1.5
CautionDistance:           DW 0 ; AlertDistance * 2

; Keypad constants
KEY_0:     DW &H0
KEY_1:     DW &H1
KEY_2:     DW &H2
KEY_3:     DW &H3
KEY_4:     DW &H4
KEY_5:     DW &H5
KEY_6:     DW &H6
KEY_7:     DW &H7
KEY_8:     DW &H8
KEY_9:     DW &H9
KEY_STAR:  DW &HA
KEY_POUND: DW &HC

; IO address constants
Switches:    EQU &H000
LEDs:        EQU &H001
Timer:       EQU &H002
Hex0:        EQU &H004
Hex1:        EQU &H005
RANGEFINDER: EQU &H0F0
KEYPAD:      EQU &H0F1
