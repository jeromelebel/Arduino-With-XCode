#ifndef _TEST_THING_
#define _TEST_THING_

#if ARDUINO_VERSION == 100
#include <Arduino.h>
#else
#include <WProgram.h>
#endif

class TestThing{
public:
	void setup();
    void doSomething();
    void anotherMethod( int i);
};


#endif