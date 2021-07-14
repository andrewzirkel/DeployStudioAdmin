#!/bin/sh

SCRIPT_NAME=`basename "${0}"`
VERSION=1.0

if [ ${#} -lt 2 ]
then
  echo "Usage: ${SCRIPT_NAME} Container disk<ID> <image file path> [<scratch disk> [--compress]]"
  echo "Example: ${SCRIPT_NAME} disk0s3 /Volumes/Sharepoint/myimage /Volumes/Scratch --compress"
  echo "RuntimeAbortScript"
  exit 1
fi

echo "Running ${SCRIPT_NAME} v${VERSION}"

DISK_ID=`basename "${1}" | sed s/disk// | awk -Fs '{ print $1 }'`
PARTITION_ID=`basename "${1}" | sed s/disk// | awk -Fs '{ print $2 }'`

DEVICE=/dev/disk${DISK_ID}
if [ ! -e "${DEVICE}" ]
then
  echo "Unknown device ${DEVICE}, script aborted."
  echo "RuntimeAbortScript"
  exit 1
fi

# checking target image path
TARGET_FILE_PATH="${2}"
IMAGE_NAME=`basename "${TARGET_FILE_PATH}"`
TARGET_FOLDER=`dirname "${TARGET_FILE_PATH}"`
if [ ! -e "${TARGET_FOLDER}" ]
then
  echo "Destination path ${TARGET_FOLDER} not found, script aborted."
  echo "RuntimeAbortScript"
  exit 1
fi
rm "${TARGET_FILE_PATH}"

# checking optional scratch disk 
SCRATCH_DISK="${3}"
if [ -n "${SCRATCH_DISK}" ]
then
  
  if [ ! -e "${SCRATCH_DISK}" ]
  then
    echo "Scratch disk ${SCRATCH_DISK} not found, script aborted."
    echo "RuntimeAbortScript"
    exit 1
  fi
  IMAGE_FILE_PATH="${SCRATCH_DISK}/${IMAGE_NAME}"
  remove_existing_image "${IMAGE_FILE_PATH}"
else
  IMAGE_FILE_PATH="${TARGET_FILE_PATH}"
fi

diskutil list ${DEVICE} | grep "0:      APFS Container Scheme" 2>/dev/null
if [ $? -gt 0 ]; then
  echo "${DEVICE} is not an apfs container, script aborted."
  echo "RuntimeAbortScript"
  exit 1
fi

PHYSICAL_STORE="/dev/`diskutil info ${DEVICE} | grep "APFS Physical Store" | tr -d ' ' | cut -d ':' -f 2`"
echo "Resizing Container Partition ${PHYSICAL_STORE}"
CONTAINTER_MINIMUM_SIZE=`diskutil apfs resizeContainer ${PHYSICAL_STORE} limits | grep "Recommended minimum" | tr -s ' ' | cut -d ':' -f 2 | cut -d ' ' -f 2,3 | tr -d ' '`

diskutil apfs resizeContainer ${PHYSICAL_STORE} "${CONTAINTER_MINIMUM_SIZE}"
if [ $? -gt 0 ]; then
  echo "Shrink failed!."
fi

echo "Unmounting Container ${DEVICE}"
diskutil unmountDisk ${DEVICE} 
if [ $? -gt 0 ]; then
  echo "${DEVICE} was not unmounted, script aborted."
  echo "RuntimeAbortScript"
  exit 1
fi

echo "Taking image of ${DEVICE} to ${TARGET_FILE_PATH}"
hdiutil create -srcdevice ${DEVICE} -format UDZO "${TARGET_FILE_PATH}" -puppetstrings
if [ $? -gt 0 ]; then
  echo "hdiutil failed to create image!."
  echo "RuntimeAbortScript"
fi

echo "remount ${DEVICE} and grow partition"
diskutil mountDisk ${DEVICE} 
if [ $? -gt 0 ]; then
  echo "${DEVICE} was not mounted, script aborted."
  echo "RuntimeAbortScript"
  exit 1
fi

diskutil apfs resizeContainer ${PHYSICAL_STORE} 0
if [ $? -gt 0 ]; then
  echo "Grow of ${PHYSICAL_STORE} failed!."
fi

touch "${TARGET_FOLDER}/.dss.scan.${IMAGE_NAME}"

exit 0

