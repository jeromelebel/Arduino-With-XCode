#include "ArduinoProgram.h"


void ArduinoProgram::setup(){
	counter = 0;
	Serial.begin(9600); 

	Serial.println("-----------------------------");
	Serial.println("   saying hi from XCode4     ");
    Serial.println("   ... again and AGAIN   ");
	Serial.println("-----------------------------");
	
	//our class from our src/ folder
	thing = new TestThing();
	thing -> setup();
	
	
}


void ArduinoProgram::loop(){
	counter ++;
	Serial.print("loop nr. ");
	Serial.println(counter, DEC);
	delay(100);	
}

