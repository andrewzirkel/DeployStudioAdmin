#!/bin/bash

SCRIPT_NAME=`basename "${0}"`
VERSION=1.0
echo "Running ${SCRIPT_NAME} v${VERSION}"

DMGDIR=`dirname "${1}"`

if [[ "${1}" != *"apfs"* ]]; then
  echo "$SCRIPT_NAME: ${1} is not an apfs image."
  exit 0
fi

if [[ "${1}" = *"container.apfs.dmg" ]]; then
  echo "$SCRIPT_NAME: ${1} is an apfs container, no processing needed."
  exit 0
fi

DMGPREFIX=`basename -s .i386.apfs.dmg "${1}"`

#Convert image to rw
RWDMG="$DMGDIR/.apfshelper.$DMGPREFIX-rw.i386.apfs.dmg"
echo "$SCRIPT_NAME: Convert ${1} to RW Image $RWDMG"
hdiutil convert ${1} -format UDRW -o "$RWDMG"
if [ $? -gt 0 ]; then
  echo "$SCRIPT_NAME: Convert failed"
  exit 1
fi

#get disk id of container
HDIUTILOUT=`hdiutil attach "$RWDMG"`
if [ $? -gt 0 ]; then
  echo "$SCRIPT_NAME: hdiutil attach $RWDMG failed"
  exit 1
fi
#gets the last disk device
OSXPARTITIONDEV=`echo "$HDIUTILOUT" | tail -1 | cut -f 1`
#Get uuid of synthesized apfs volume
DISKUTILOUT=`diskutil info $OSXPARTITIONDEV`
if [ $? -gt 0 ]; then
  echo "$SCRIPT_NAME: diskutil info $OSXPARTITIONDEV failed"
  exit 1
fi
UUID=`echo "$DISKUTILOUT" | grep "Volume UUID" | tr -s " " | cut -d " " -f 4`

#create Preboot and Recovery partitions
DISK=`basename -s s1 $OSXPARTITIONDEV`
diskutil apfs addVolume $DISK apfs Preboot -role B
diskutil apfs addVolume $DISK apfs Recovery -role R

#Preboot
diskutil mount "/dev/${DISK}s2"
tar -xvf "$DMGDIR/$DMGPREFIX.i386.preboot.zip" -C /Volumes/Preboot
OLDUUID=`ls -1 /Volumes/Preboot/`
mv "/Volumes/Preboot/$OLDUUID" "/Volumes/Preboot/$UUID"

#Recovery
diskutil mount "/dev/${DISK}s3"
tar -xvf "$DMGDIR/$DMGPREFIX.i386.recovery.zip" -C /Volumes/Recovery
OLDUUID=`ls -1 /Volumes/Recovery/`
mv "/Volumes/Recovery/$OLDUUID" "/Volumes/Recovery/$UUID"

#unmount container
DISKNUM=`echo $DISK | cut -c5-5`
DISKNUM=$(($DISKNUM - 1))
hdiutil detach "/dev/disk${DISKNUM}"

##Convert back to ro
#Save original image
ORIGDMGSAVE="$DMGDIR/.apfshelper.$DMGPREFIX-orig.i386.apfs.dmg"
mv ${1} $ORIGDMGSAVE
#Convert
hdiutil convert "$RWDMG" -format UDZO -o "${1}"
if [ $? -gt 0 ]; then
  echo "$SCRIPT_NAME: hdiutil convert $RWDMG -format UDZO -o ${1}"
  exit 1
fi

#if we got here then all is well so cleanup
rm "$RWDMG"
rm "$ORIGDMGSAVE"
#hand back to safeimagescan for further processing
exit 0
