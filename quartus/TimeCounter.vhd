-- TimeCounter.vhd (a peripheral module for SCOMP)
-- This device increments a count while an input is high,
-- and provides the count to SCOMP when requested.

LIBRARY IEEE;
LIBRARY LPM;

USE IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.all;
use IEEE.STD_LOGIC_UNSIGNED.all;
USE LPM.LPM_COMPONENTS.ALL;

ENTITY TimeCounter IS
	PORT(
		-- At least IO_DATA and a chip select are needed.  Even though
		-- this device will only respond to IN, IO_WRITE is included so
		-- that this device doesn't drive the bus during an OUT.
		BTN         : IN    STD_LOGIC;
		CLK         : IN    STD_LOGIC;
		RESETN      : IN    STD_LOGIC;
		CS          : IN    STD_LOGIC;
		IO_WRITE    : IN    STD_LOGIC;
		IO_DATA     : INOUT STD_LOGIC_VECTOR(15 DOWNTO 0)
	);
END TimeCounter;

ARCHITECTURE a OF TimeCounter IS
	SIGNAL count : STD_LOGIC_VECTOR(15 downto 0);
	SIGNAL tri_enable : STD_LOGIC; -- enable signal for the tri-state driver
	
	TYPE state_type is (Init, BTN_high);
	SIGNAL state : state_type;
	
	BEGIN
	
	tri_enable <= CS and (not IO_WRITE); -- only drive IO_DATA during IN
	
	-- Use LPM function to create tri-state driver for IO_DATA
	IO_BUS: lpm_bustri
	GENERIC MAP (
		lpm_width => 16
	)
	PORT MAP (
		data     => count,   -- Put the value on IO_DATA during IN
		enabledt => tri_enable,
		tridata  => IO_DATA
	);


	
	PROCESS (RESETN, CLK)
	BEGIN
		IF RESETN = '0' THEN
			count <= x"0000";
			state <= init;
		ELSIF RISING_EDGE(CLK) THEN
			CASE state IS
			
				WHEN init =>
					IF BTN = '1' THEN
						state <= BTN_high;
					END IF;
					
				WHEN BTN_high =>
					IF BTN = '1' THEN
						count <= count + 1; -- increment the count
					ELSE
						state <= init;
					END IF;
				
				WHEN OTHERs =>
					
					
			END CASE;
					
		END IF;
	END PROCESS;

END a;

