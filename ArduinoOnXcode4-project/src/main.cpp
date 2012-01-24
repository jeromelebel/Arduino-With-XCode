

#include <Arduino.h>
#include "ArduinoProgram.h"

int main(void)
{
	init();
	ArduinoProgram arduino;
	arduino.setup();
	for (;;)
		arduino.loop();
	return 0;
}

