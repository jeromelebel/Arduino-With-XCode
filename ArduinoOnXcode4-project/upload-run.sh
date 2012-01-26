#!/bin/sh

#  upload-run.sh
#  ArduinoOnXcode
#
#  Created by Jérôme Lebel on 25/01/12.
#  Copyright (c) 2012 Fotonauts. All rights reserved.

ARDUINO_APP_PATH="$1"
HEX_PATH="$2"
BOARDS_TXT_PATH="$3"
BUILD_DIR="$4"
PORT=`ls "$5"`
HARDWARE_NAME="$6"



"${ARDUINO_APP_PATH}/Contents/Resources/Java/hardware/tools/avr/bin/avrdude" "-C${ARDUINO_APP_PATH}/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf" "-p${HARDWARE_NAME}" "-P${PORT}" -c stk500v2 -b115200 -D "-Uflash:w:${BUILD_DIR}main.hex:i"
