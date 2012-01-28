#!/bin/sh

#  upload-run.sh
#  ArduinoOnXcode

echo "$@"
echo " "

ARDUINO_APP_PATH="$1"
BOARDS_TXT_PATH="$2"
BUILD_DIR="$3"
PORT=`ls "$4"`
HARDWARE_NAME="$5"
BOARD_NAME="$6"

UPLOAD_RATE=`grep -e"${BOARD_NAME}.upload.speed=" "${BOARDS_TXT_PATH}" | sed 's/'"${BOARD_NAME}.upload.speed="'//'`

"${ARDUINO_APP_PATH}/Contents/Resources/Java/hardware/tools/avr/bin/avrdude" "-C${ARDUINO_APP_PATH}/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf" "-p${HARDWARE_NAME}" "-P${PORT}" -c stk500v2 "-b${UPLOAD_RATE}" -D "-Uflash:w:${BUILD_DIR}main.hex:i"
