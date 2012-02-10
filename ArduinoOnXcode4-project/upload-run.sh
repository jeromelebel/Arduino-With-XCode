#!/bin/sh

#  upload-run.sh
#  ArduinoOnXcode

echo "$@"
echo "-- "

ARDUINO_APP_PATH="$1"
BOARDS_TXT_PATH="$2"
BUILD_DIR="$3"
PORT=`ls $4`
HARDWARE_NAME="$5"
BOARD_NAME="$6"
HARDWARE_PATH="$7"

UPLOAD_RATE=`grep -e"${BOARD_NAME}.upload.speed=" "${BOARDS_TXT_PATH}" | sed 's/'"${BOARD_NAME}.upload.speed="'//'`
PROTOCOL=`grep -e"${BOARD_NAME}.upload.protocol=" "${BOARDS_TXT_PATH}" | sed 's/'"${BOARD_NAME}.upload.protocol="'//'`
MCU=`grep -e"${BOARD_NAME}.build.mcu=" "${BOARDS_TXT_PATH}" | sed 's/'"${BOARD_NAME}.build.mcu="'//'`

if [ "${PROTOCOL}" = "" ] ; then
  PROTOCOL="stk500"
fi

export TERM="vt100"

"${ARDUINO_APP_PATH}/Contents/Resources/Java/hardware/tools/avr/bin/avrdude" "-C${ARDUINO_APP_PATH}/Contents/Resources/Java/hardware/tools/avr/etc/avrdude.conf" "-p${MCU}" "-P${PORT}" "-c${PROTOCOL}" "-b${UPLOAD_RATE}" -D "-Uflash:w:${BUILD_DIR}/main.hex:i"
echo "#!/bin/sh" /tmp/arduino.command
echo "screen \"${PORT}\" \"${UPLOAD_RATE}\"" > /tmp/arduino.command
chmod 0755 /tmp/arduino.command
open /tmp/arduino.command
