LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
use IEEE.numeric_std.all;
USE LPM.LPM_COMPONENTS.ALL;


ENTITY keypad IS
	PORT(
		CLK         : IN    STD_LOGIC;
		RESETN      : IN    STD_LOGIC;
		KEYCOL      : OUT   STD_LOGIC_VECTOR(3 downto 1);
		KEYROW      : IN    STD_LOGIC_VECTOR(4 downto 1);
		IO_WRITE    : IN    STD_LOGIC;
		CS				: IN	  STD_LOGIC;
		IO_DATA     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END keypad;


ARCHITECTURE a OF keypad IS

	-----------------------
	--	 SHARED SIGNALS   --
	-----------------------

	-- inVector: holds the raw column data from the keypad
	SIGNAL inVector : STD_LOGIC_VECTOR(4 downTo 1);
	-- outValue: value placed directly onto IO_DATA
	SIGNAL outValue : STD_LOGIC_VECTOR(15 downto 0);
	-- bufferOut: register that stores the most recent button press
	SIGNAL bufferOut : STD_LOGIC_VECTOR(15 downto 0);
	-- tri_enable: signal for this peripheral's tristate drivers
	SIGNAL tri_enable : STD_LOGIC; -- enable signal for the tri-state driver
	
	-- Two settings:
	--	"On Press" setting: 0x0000
	-- "On Release" setting: 0x0001
	SIGNAL settings : STD_LOGIC_VECTOR(15 downto 0) := x"0000";
	
	-- bufferFlagX: flag that is raised when no buttons are detected when scanning column X 
	SIGNAL bufferFlag1 : STD_LOGIC;
	SIGNAL bufferFlag2 : STD_LOGIC;
	SIGNAL bufferFlag3 : STD_LOGIC;
	-- bufferOutFlag: flag used to select outValue
	SIGNAL bufferOutFlag: STD_LOGIC;
	
	-- anyButtonDown: helper signal, '1' if any button is down, '0' otherwise
	signal anyButtonDown : std_logic;
	-- moreThanOneDown: helper signal, '1' if more than one button is down, '0' otherwise
	signal moreThanOneDown : std_logic;
	-- noButtonsDown: helper signal, '1' if no buttons are down, '0' otherwise
	signal noButtonsDown : std_logic;
	
	-- Type definition for state: defines the legal states
	TYPE state_type is (init, scanCol1, scanCol2, scanCol3, bufferData, registerData);
	-- state: variable that holds the state
	SIGNAL state : state_type;
	
	--------------------------
	--  "On Press" Signals	--
	--------------------------
	
	-- buttonDownFlag: flag for when at least 1 button is pressed
	SIGNAL buttonDownFlag	: std_logic;
	-- undefinedBehavior: when more than 1 button is pressed, 
	--		raise this flag. This prevents the value in bufferOut
	--		from being put into outValue
	SIGNAL undefinedBehavior : STD_LOGIC;
	
	--------------------------
	--	"On Release" Signals	--
	--------------------------
	
	-- cycleCount: used for a timer
	--		After a button is released, the value will be saved for 0.5s before being erased
	SIGNAL cycleCount : STD_LOGIC_VECTOR(15 downto 0);
	

	BEGIN
	
	-----------------
	--		 I/O		--
	-----------------
	
	inVector <= KEYROW;
	
	tri_enable <= CS and (not IO_WRITE); -- only drive IO_DATA during IN
	
	-- Define a tri-state driver for IO_DATA
	IO_BUS: lpm_bustri
	GENERIC MAP (
		lpm_width => 16
	)
	PORT MAP (
		data     => outValue,   -- Put the value on IO_DATA during IN
		enabledt => tri_enable,
		tridata  => IO_DATA
	);
	
	--------------------------
	--		STATE MACHINE		--
	--------------------------
	
	PROCESS (RESETN, CLK)
	BEGIN
		-- On reset or on an OUT instruction,
		--	reset state variables
		IF (RESETN = '0' OR (CS and IO_WRITE) = '1') THEN
		
			-- clear bufferOut
			bufferOut <= x"FFFF";
			
			-- reset state
			state <= scanCol1;
			
			-- clear flags for "on press" setting
			undefinedBehavior <= '0';
			buttonDownFlag <= '0';
			
			if (IO_WRITE = '1'
					and (IO_DATA = x"0000" or IO_DATA = x"0001")) then
				settings <= IO_DATA;
			else
				settings <= x"0000";
			end if;
			
		ELSIF RISING_EDGE(CLK) THEN
			CASE state IS
			
				WHEN scanCol1 =>
					-- Raw button detection
					if (inVector(1) = '0') then 
						bufferOut <= x"0001"; -- 1 in binary
					elsif (inVector(2) = '0') then
						bufferOut <= x"0004"; -- 4 in binary
					elsif (inVector(3) = '0') then
						bufferOut <= x"0007"; -- 7 in binary
					elsif (inVector(4) = '0') then
						bufferOut <= x"000A"; -- 10 in binary corresponds to '*'
					end if;
					
					-- Update bufferFlag1
					-- Used for noButtonsDown signal
					if (anyButtonDown = '1') then
						bufferFlag1 <= '0';
					else
						bufferFlag1 <= '1';
					end if;
					
					-- Settings-specific changes
					if (settings = x"0000") then
						-- "On press" setting
						if ((anyButtonDown = '1' and buttonDownFlag = '1') 
								or moreThanOneDown ='1') then
							-- "On press" setting
							-- (anyButtonDown = '1' and buttonDownFlag = '1'):
							--		checks for 2+ presses across rows
							-- moreThanOneDown ='1':
							--		checks for 2+ presses within the sam row
							undefinedBehavior <= '1';
						elsif (anyButtonDown = '1') then
							-- Marks if exactly 1 button is pressed
							buttonDownFlag <= '1';
						end if;
					else
						-- "On release" setting
						if (anyButtonDown = '1') then
							cycleCount <= x"0000";
						end if;
					end if;
					
					state <= scanCol2;
				
				WHEN scanCol2 =>
					-- Raw button detection
					if (inVector(1) = '0') THEN 
						bufferOut <= x"0002"; -- 2 in binary
					elsif (inVector(2) = '0') then
						bufferOut <= x"0005"; -- 5 in binary
					elsif (inVector(3) = '0') then
						bufferOut <= x"0008"; -- 8 in binary
					elsif (inVector(4) = '0') then
						bufferOut <= x"0000"; -- 11 in binary corresponds to '0' key
					end if;
					
					-- Update bufferFlag2
					-- Used for noButtonsDown signal
					if (anyButtonDown = '1') then
						bufferFlag2 <= '0';
					else
						bufferFlag2 <= '1';
					end if;
					
					-- Settings-specific changes
					if (settings = x"0000") then
						-- "On press" setting
						if ((anyButtonDown = '1' and buttonDownFlag = '1')
								or moreThanOneDown ='1') then
							-- "On press" setting
							-- (anyButtonDown = '1' and buttonDownFlag = '1'):
							--		checks for 2+ presses across rows
							-- moreThanOneDown ='1':
							--		checks for 2+ presses within the sam row
							undefinedBehavior <= '1';
						elsif (anyButtonDown = '1') then
							-- Marks if exactly 1 button is pressed
							buttonDownFlag <= '1';
						end if;
					else
						-- "On release" setting
						if (anyButtonDown = '1') then
							cycleCount <= x"0000";
						end if;
					end if;
					
					state <= scanCol3;

				WHEN scanCol3 =>
					-- Raw button detection
					if (inVector(1) = '0') THEN 
						bufferOut <= x"0003"; -- 3 in binary
					elsif (inVector(2) = '0') then
						bufferOut <= x"0006"; -- 6 in binary
					elsif (inVector(3) = '0') then
						bufferOut <= x"0009"; -- 9 in binary
					elsif (inVector(4) = '0') then
						bufferOut <= x"000C"; -- 12 in binary corresponds to '#' key
					end if;
					
					-- Update bufferFlag3
					-- Used for noButtonsDown signal
					if (anyButtonDown = '1') then
						bufferFlag3 <= '0';
					else
						bufferFlag3 <= '1';
					end if;
					
					-- Settings-specific changes
					if (settings = x"0000") then
						-- "On press" setting
						-- (anyButtonDown = '1' and buttonDownFlag = '1'):
						--		checks for 2+ presses across rows
						-- moreThanOneDown ='1':
						--		checks for 2+ presses within the sam row
						if ((anyButtonDown = '1' and buttonDownFlag = '1')
								or moreThanOneDown ='1') then
							undefinedBehavior <= '1';
						elsif (anyButtonDown = '1') then
							-- Marks if exactly 1 button is pressed
							buttonDownFlag <= '1';
						end if;
					else
						-- "On release" setting
						if (anyButtonDown = '1') then
							cycleCount <= x"0000";
						end if;
					end if;
					
					state <= registerData;

						
				when registerData =>
											 
					-- Settings-specific changes
					if (settings = x"0000") then -- "On Press" setting
					
						-- When no buttons are being pressed,
						-- reset undefined behavior and bufferOut
						if (noButtonsDown = '1') then
							undefinedBehavior <= '0';
							bufferOut <= x"FFFF";
						end if;
						
						-- Since this is a column-specific flag,
						-- it must be cleared every time
						buttonDownFlag <= '0';
					else -- "On Release" setting
					
						-- If no buttons are being pressed and the 0.5s
						-- timer has not expired, keep the old bufferOut value
						-- and increment the timer
						if (noButtonsDown = '1' and cycleCount < 5000) then
							cycleCount <= cycleCount + 1;
						elsif (noButtonsDown = '1') then
						-- The 0.5s timer is up; clear bufferOut
							bufferOut <= x"FFFF";
						end if;
					end if;
					
					state <= scanCol1;

				WHEN OTHERs =>
					state <= scanCol1;
					
					
			END CASE;
					
		END IF;
	END PROCESS;
	
	--------------------------------
	--		SIGNAL ASSIGNMENTS		--
	--------------------------------
	
	-- noButtonsDown: '1' when none of the 3 columns has any button presses,
	--		'0' otherwise
	noButtonsDown <= bufferFlag1 and bufferFlag2 and bufferFlag3;
	
	-- anyButtonDown: '1' when any button IN THE CURRENT COLUMN is pressed, 0 otherwise
	with (inVector(1) and inVector(2) and inVector(3) and inVector(4)) select anyButtonDown <=
		'1' when '0', 
		'0' when others;
	
	-- moreThanOneDown: '1' when more than 1 button IN THE CURRENT COLUMN is pressed, '0' otherwise
	moreThanOneDown <= 
		'1' when (inVector(1) = '0' and inVector(2) = '0') else
		'1' when (inVector(1) = '0' and inVector(3) = '0') else
		'1' when (inVector(1) = '0' and inVector(4) = '0') else
		'1' when (inVector(2) = '0' and inVector(3) = '0') else
		'1' when (inVector(2) = '0' and inVector(4) = '0') else
		'1' when (inVector(3) = '0' and inVector(4) = '0') else
		'0';

	-- Both button settings use bufferOutFlag to select output value
	with settings select bufferOutFlag <=
		-- setting = x"0000" (on press):
		(not undefinedBehavior) when x"0000",
		-- setting = x"0001" (on release):
		noButtonsDown when others;
		
	--------------------
	--		OUTPUTS		--
	--------------------
	
	-- Determine output to put onto the bus	
	-- Uses bufferOutFlag
	with bufferOutFlag select outValue <=
		bufferOut when '1',
		x"FFFF" when others;
	
	
	-- Determine the outputs for driving the columns during key scanning
	with state select KEYCOL(1) <=
		'0' when scanCol1,
		'Z' when others;
		
	with state select KEYCOL(2) <=
		'0' when scanCol2,
		'Z' when others;
		
	with state select KEYCOL(3) <=
		'0' when scanCol3,
		'Z' when others;
	
END a;

