
#include <Arduino.h>

#include "ArduinoProgram.h"

int zob(void);
int zob(void)
{
    return 0;
}

#ifdef __cplusplus
extern "C"{
#endif

void setup(void);
void loop(void);

void setup(void)
{
}

void loop(void)
{
    delay(10);
    digitalWrite(3, HIGH);
    
}
    
#ifdef __cplusplus
}
#endif
