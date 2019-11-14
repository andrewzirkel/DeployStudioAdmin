#!/bin/sh

SCRIPT_NAME=`basename "${0}"`
VERSION=1.0
SYS_VERS=`sw_vers -productVersion | awk -F. '{ print $2 }'`

if [ -z "${1}" ]
then
  echo "Usage: ${SCRIPT_NAME} <volume name>" >>/dev/stderr
  echo "Example: ${SCRIPT_NAME} 'Macintosh HD'" >>/dev/stderr
  exit 1
fi

if [ ! -e "${1}" ] && [ ! -e "/Volumes/${1}" ] && [ ! -e "/dev/${1}" ]
then
  echo "Error: volume '${1}' not found!" >>/dev/stderr
  exit 1
fi

if [ -e "${1}" ]
then
  VOL="${1}"
elif [ -e "/Volumes/${1}" ]
then
  VOL="/Volumes/${1}"
else
  VOL="/dev/${1}"
fi

if [ ${SYS_VERS} -ge 13 ]
then
  PHYSICAL_DEVICE_ID=`diskutil list "${VOL}" | grep "Physical Store" | awk '{ print $NF }'`
fi

if [ -n "${PHYSICAL_DEVICE_ID}" ]
then
  echo "PHYSICAL_DEVICE="`basename "${PHYSICAL_DEVICE_ID}"`
fi

exit 0
