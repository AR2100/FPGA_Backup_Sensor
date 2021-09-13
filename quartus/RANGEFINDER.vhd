-- RANGEFINDER.vhd (a peripheral module for SCOMP)
-- Template for an eventual interface between SCOMP and
-- an ultrasonic rangefinder.

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
USE LPM.LPM_COMPONENTS.ALL;


ENTITY RANGEFINDER IS
	PORT(
		CLK         : IN    STD_LOGIC;
		RESETN      : IN    STD_LOGIC;
		ECHO        : IN    STD_LOGIC;
		CS          : IN    STD_LOGIC;
		IO_WRITE    : IN    STD_LOGIC;
		TRIG        : OUT   STD_LOGIC;
		IO_DATA     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END RANGEFINDER;


ARCHITECTURE a OF RANGEFINDER IS
	SIGNAL count : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL cycle_count : STD_LOGIC_VECTOR(15 downto 0);
   SIGNAL tri_enable : STD_LOGIC; -- enable signal for the tri-state driver
	--SIGNAL store : STD_LOGIC_VECTOR(15 downto 0);      -- Register that will store the last rangefinder value recorded
	SIGNAL output : STD_LOGIC_VECTOR(15 downto 0);		-- Register that will hold the original stored value before modifications
	SIGNAL settings : STD_LOGIC_VECTOR(15 downto 0);	-- Settings vector which will grab the settings is on the bus
   TYPE state_type is (init, trig_pulse, wait_echo, echo_high);
	SIGNAL state : state_type;
	
	
	BEGIN	
	tri_enable <= CS and (not IO_WRITE); -- only drive IO_DATA during IN
	
	-- Use LPM function to create tri-state driver for IO_DATA
	IO_BUS: lpm_bustri
	GENERIC MAP (
		lpm_width => 16
	)
	PORT MAP (
		data     => output,   -- Put the value on IO_DATA during IN.. This should be output and not count Daryl is correct 
		enabledt => tri_enable,
		tridata  => IO_DATA
	);
	-- What needs to happen here is: 
			-- 1.) The rangefinder will calculate the distance as it did in lab8
					-- a.) make sure that the state does not go back to init like it did in lab8 because then the rangefinder will continue to scan
			-- 2.) Then the rangefinder will have to store the data that was calculated into the store register
			-- 3.) Then we wil need to check the settings vector and determine the output register from the settings register
			-- 4.) How does the data that we need (such as the settings vector) come from? --> It comes from the I/O Data Bus.
					-- a.) if the settings vector is 00 then we can return the original measurement in mm
					-- b.) if the settings vector is 01 then we have to return the measurement converted to cm
					-- c.) if the settings vector is 10 then we have to return the measurement converted to inches
			
	PROCESS (RESETN, CLK, settings)
	BEGIN
	
	--Make an elsif case for CS & IO_WRITE that only does settings <= IO_DATA
	
		IF (RESETN = '0') THEN			-- If an OUT instruction is called then read the data off of the I/O data bus and set the settings register
			count <= x"0000";
			cycle_count <= x"0000";
			output <= x"FFFF";			-- Output will be initialized to ffff if there is nothing being read
			state <= init;
		ELSIF RISING_EDGE(CLK) 	THEN
			CASE state IS														-- Now the rangefinder will work like before but now we make sure we stop calculating the distance 
				WHEN init =>
					cycle_count <= cycle_count + 1;
					IF cycle_count = 50000 THEN 
						state <= trig_pulse;
						TRIG <= '1';
					END IF;
				WHEN trig_pulse =>
					state <= wait_echo;
					TRIG <= '0';
				WHEN wait_echo =>
					IF ECHO = '1' THEN
						state <= echo_high;
						count <= x"0000";
					END IF;
				WHEN echo_high =>
							IF ECHO = '1' THEN
						count <= count + 1; -- increment the count
					ELSE
						-- output <= count;
						IF (settings = x"0001") THEN -- units == cm  | conversion = cycles * (0.17 == 11/64)
							output <= CONV_STD_LOGIC_VECTOR(
										 SHR(
												UNSIGNED(count) * CONV_UNSIGNED(11, 16),
												CONV_UNSIGNED(6, 16)
											), 16);
							
						ELSIF (settings = x"0010") THEN -- units == in | conversion = cycles * (0.068 == 35/512)
							output <= CONV_STD_LOGIC_VECTOR(
											SHR(
												UNSIGNED(count) * CONV_UNSIGNED(35, 16),
												CONV_UNSIGNED(9, 16)
											), 16); 
							
						ELSE
							-- units == mm | conversion = cycles * (1.7 == 109/64), allow the settings to be defaulted to 0 meaning mm units.
							output <= CONV_STD_LOGIC_VECTOR(
											SHR(
												UNSIGNED(count) * CONV_UNSIGNED(109, 16),
												CONV_UNSIGNED(6, 16)
											), 16);
						END IF;
						
						state <= init;
						cycle_count <= x"0000";
					END IF;		
			END CASE;				
		END IF;
	END PROCESS;
	
	PROCESS (CS, IO_WRITE)
	BEGIN
		IF ((CS AND IO_WRITE) = '1')	THEN
			settings <= IO_DATA;
		ELSE
			settings <= settings;
		END IF;
	END PROCESS;

END a;

