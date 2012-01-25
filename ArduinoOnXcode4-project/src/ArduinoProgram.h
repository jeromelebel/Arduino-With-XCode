#ifndef _ARDUINO_PROGRAM_H
#define _ARDUINO_PROGRAM_H

#if ARDUINO_VERSION == 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

/********************************************
 LIBRARIES
 
 To add your own libraries see the README file
 
 *********************************************/


#include "TestThing.h"
#include "Servo.h"

class ArduinoProgram {
public:
	
	
	// FUNCTIONS
	void setup();
	void loop();
	
	// VARIABLES
	int counter;
	
	// a class in our src/ folder
	TestThing* thing;
    
    // class in standard Arduino libraries
    Servo * servo;
    
};

#endif

