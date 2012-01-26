#!/bin/sh

#  upload-run.sh
#  ArduinoOnXcode
#
#  Created by Jérôme Lebel on 25/01/12.
#  Copyright (c) 2012 Fotonauts. All rights reserved.

APPLICATION_PATH=$1
HEX_PATH=$2
BOARDS_TXT_PATH=$3


/Applications/Arduino.app/Contents/Resources/Java/hardware/tools/avr/bin/avrdude -C/Applications/Arduino.app/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf -patmega2560 -P/dev/tty.usbmodem411 -c stk500v2 -b115200 -D -Uflash:w:/Users/jerome/Library/Developer/Xcode/DerivedData/ArduinoOnXcode-arkyvqhucytijbdxryabqdezjdoi/Build/Products/main.hex:i
