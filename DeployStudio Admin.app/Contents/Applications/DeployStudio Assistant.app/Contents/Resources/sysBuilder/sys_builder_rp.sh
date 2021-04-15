#!/bin/sh

SCRIPT_NAME=`basename "${0}"`
SYSBUILDER_FOLDER=`dirname "${0}"`
VERSION=2.3

########################################################
# Functions
########################################################

print_usage() {
  echo "Usage: ${SCRIPT_NAME} -basesystem <source volume> -type local -volume <volume name> [-erasedisk][-loc <language>][-serverurl <server url>][-serverurl2 <server url 2>][-disableversionsmismatchalerts][-login <login>][-password <password>][-ardlogin <login>][-ardpassword <password>][-displaylogs][-timeout =<duration in seconds>][-displaysleep <duration in minutes>][-enableruby][-enablepython][-enablecustomtcpstacksettings][-disablewirelesssupport][-ntp <network time server>][-customtitle <Runtime mainwindow title>][-custombackground <Runtime custom background image path>][-smb1only]"
  echo "       ${SCRIPT_NAME} -basesystem <source volume> -type netboot -id <ID> -name <name> -dest <destination> [-protocol NFS|HTTP][-loc <language>][-serverurl <server url>][-serverurl2 <server url 2>][-disableversionsmismatchalerts][-login <login>][-password <password>][-ardlogin <login>][-ardpassword <password>][-displaylogs][-timeout <duration in seconds>][-displaysleep <duration in minutes>][-enableruby][-enablepython][-enablecustomtcpstacksettings][-disablewirelesssupport][-ntp <network time server>][-customtitle <Runtime mainwindow title>][-custombackground <Runtime custom background image path>][-smb1only]"
}

add_file_at_path() {
  if [ -e "${TMP_MOUNT_PATH}${2}/${1}" ]
  then
    echo "****** '${1}' exists in '${TMP_MOUNT_PATH}${2}/'" 
  fi
  rsync --archive --links --delete "${BASE_SYSTEM_ROOT_PATH}${2}/${1}" "${TMP_MOUNT_PATH}${2}/" 2>&1
  #ditto --rsrc "${BASE_SYSTEM_ROOT_PATH}${2}/${1}" "${TMP_MOUNT_PATH}${2}/${1}" 2>&1
}

add_files_at_path() {
  for A_FILE in ${1}
  do
    if [ -e "${TMP_MOUNT_PATH}${2}/${A_FILE}${3}" ]
    then
      echo "****** '${A_FILE}${3}' exists in '${TMP_MOUNT_PATH}${2}/'" 
    fi
    rsync --archive --links --delete "${BASE_SYSTEM_ROOT_PATH}${2}/${A_FILE}${3}" "${TMP_MOUNT_PATH}${2}/" 2>&1
    #ditto --rsrc "${BASE_SYSTEM_ROOT_PATH}${2}/${A_FILE}${3}" "${TMP_MOUNT_PATH}${2}/${A_FILE}${3}" 2>&1
  done
}

enable_custom_tcp_stack_settings() {
  echo "# kernel options that should improve tcp performance" > "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "kern.ipc.maxsockbuf=1048576"        >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "kern.ipc.somaxconn=512"             >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.local.stream.recvspace=98304"	>> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.local.stream.sendspace=98304"	>> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.udp.maxdgram=57344"        >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.udp.recvspace=42080"       >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.delayed_ack=0"         >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.mssdflt=1460"          >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.newreno=1"             >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.recvspace=98304"       >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.rfc1323=1"             >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.rfc1644=1"             >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  echo "net.inet.tcp.sendspace=98304"       >> "${TMP_MOUNT_PATH}"/etc/sysctl.conf
  chmod 644 "${TMP_MOUNT_PATH}"/etc/sysctl.conf 2>&1
  chown -R root:wheel "${TMP_MOUNT_PATH}"/etc/sysctl.conf 2>&1
}

get_recovery_volume() {
  if [ -e "/Volumes/Recovery HD/" ]
  then
    RECOVERY_VOLUME="/Volumes/Recovery HD"
  elif [ -e "/Volumes/Recovery/" ]
  then
    RECOVERY_VOLUME="/Volumes/Recovery"
  else
    RECOVERY_VOLUME=""
  fi
}

get_recovery_basesystem() {
  UNMOUNT_RECOVERY_VOLUME="NO"
 
  get_recovery_volume
  if [ -n "${RECOVERY_VOLUME}" ]
  then
    BASESYSTEM_DMG_PATH=`find "${RECOVERY_VOLUME}" -name BaseSystem.dmg | tail -n 1`
  fi
  if [ -z "${BASESYSTEM_DMG_PATH}" ] || [ ! -e "${BASESYSTEM_DMG_PATH}" ]
  then
    BEST_RECOVERY_DEVICE=`"${SYSBUILDER_FOLDER}"/netboot_helpers/ds_best_recovery_device_info.sh "${BASE_SYSTEM}" | awk -F: '{ print $2 }'`
    if [ -n "${BEST_RECOVERY_DEVICE}" ] && [ -e "${BEST_RECOVERY_DEVICE}" ]
    then
      diskutil mount readOnly "${BEST_RECOVERY_DEVICE}"
      if [ ${?} -eq 0 ]
      then
        get_recovery_volume
        if [ -n "${RECOVERY_VOLUME}" ]
        then
          BASESYSTEM_DMG_PATH=`find "${RECOVERY_VOLUME}" -name BaseSystem.dmg | tail -n 1`
        fi 
        UNMOUNT_RECOVERY_VOLUME="YES"
      fi
    fi
  fi
  if [ -n "${BASESYSTEM_DMG_PATH}" ] && [ -e "${BASESYSTEM_DMG_PATH}" ]
  then
    if [ -e "/tmp/dss_basesystem" ]
    then
      rm -rf "/tmp/dss_basesystem"
    fi
    mkdir "/tmp/dss_basesystem"

    if [ "${SYS_BUILDER_TYPE}" == "local" ]
    then 
      ditto --rsrc "${BASESYSTEM_DMG_PATH}" "/tmp/dss_basesystem/BaseSystem.dmg"
    else
      hdiutil convert "${BASESYSTEM_DMG_PATH}" -format UDSP -o "/tmp/dss_basesystem/BaseSystem.sparseimage"
      hdiutil resize -size 10G "/tmp/dss_basesystem/BaseSystem.sparseimage"
    fi

    if [ -e "${RECOVERY_VOLUME}/com.apple.recovery.boot/boot.efi" ]
    then
      BOOT_EFI_PATH="${RECOVERY_VOLUME}/com.apple.recovery.boot/boot.efi"
    else
      BOOT_EFI_PATH=`find "${RECOVERY_VOLUME}" -name boot.efi | tail -n 1`
    fi
    if [ -e "${BOOT_EFI_PATH}" ]
    then
      ditto --rsrc "${BOOT_EFI_PATH}" "/tmp/dss_basesystem/booter"
    fi
	
    if [ -e "${RECOVERY_VOLUME}/com.apple.recovery.boot/prelinkedkernel" ]
    then
      PRELINKED_KERNEL_PATH="${RECOVERY_VOLUME}/com.apple.recovery.boot/prelinkedkernel"
    else
      PRELINKED_KERNEL_PATH=`find "${RECOVERY_VOLUME}" -name prelinkedkernel | tail -n 1`
    fi
    if [ -e "${PRELINKED_KERNEL_PATH}" ]
    then
      ditto --rsrc "${PRELINKED_KERNEL_PATH}" "/tmp/dss_basesystem/kernelcache"
    fi
  fi

  if [ "${UNMOUNT_RECOVERY_VOLUME}" = "YES" ]
  then
    diskutil unmount "${BEST_RECOVERY_DEVICE}"
    if [ ${?} -ne 0 ]
    then
      diskutil unmount force "${BEST_RECOVERY_DEVICE}"
    fi
  fi
}

get_installer_basesystem() {
  INSTALLESD_HD="/Volumes/OS X Install ESD"
  BASESYSTEM_DMG_PATH="${INSTALLESD_HD}/BaseSystem.dmg"

  UNMOUNT_INSTALLESD_HD="NO"
 
  if [ ! -e "${BASESYSTEM_DMG_PATH}" ]
  then
    INSTALLESD_DMG_PATH=`find /Applications -name "InstallESD.dmg" -print -quit`
    if [ -n "${INSTALLESD_DMG_PATH}" ] && [ -e "${INSTALLESD_DMG_PATH}" ]
    then
      echo "Found installer ${INSTALLESD_DMG_PATH}..."
      ATTACHED=`hdiutil attach "${INSTALLESD_DMG_PATH}" -owners on -readonly -nobrowse 2>&1`
      INSTALLESD_DEVICE=`echo ${ATTACHED} | awk '{ print $1 }'`
      if [ -e "${INSTALLESD_DEVICE}" ]
      then
        UNMOUNT_INSTALLESD_HD="YES"
      fi
    fi
  fi
  if [ -e "${BASESYSTEM_DMG_PATH}" ]
  then
    if [ -e "/tmp/dss_basesystem" ]
    then
      rm -rf "/tmp/dss_basesystem"
    fi
    mkdir "/tmp/dss_basesystem"

    if [ "${SYS_BUILDER_TYPE}" == "local" ]
    then 
      ditto --rsrc "${BASESYSTEM_DMG_PATH}" "/tmp/dss_basesystem/BaseSystem.dmg"
    else
      hdiutil convert "${BASESYSTEM_DMG_PATH}" -format UDSP -o "/tmp/dss_basesystem/BaseSystem.sparseimage"
      hdiutil resize -size 10G "/tmp/dss_basesystem/BaseSystem.sparseimage"
    fi
  fi

  if [ "${UNMOUNT_INSTALLESD_HD}" = "YES" ]
  then
    hdiutil detach "${INSTALLESD_HD}"
    if [ ${?} -ne 0 ]
    then
      hdiutil detach "${INSTALLESD_HD}" -force
    fi
  fi
}

update_language_preference() {
  if [ "${LANGUAGE_CODE}" == "default" ]
  then
    if [ -e "${HOME}/Library/Preferences/ByHost/.GlobalPreferences.${HOST_UUID}.plist" ]
    then
      HOST_ID=${HOST_UUID}
    else
      HOST_ID=${HOST_MACADDR}
    fi
    if [ -e "${HOME}/Library/Preferences/ByHost/.GlobalPreferences.${HOST_ID}.plist" ]
    then
      LANGUAGE_CODE=`/usr/libexec/PlistBuddy -c "Print AppleLanguages:0" "${HOME}/Library/Preferences/ByHost/.GlobalPreferences.${HOST_ID}.plist"`
    else
      LANGUAGE_CODE=
    fi
    if [ -n "${LANGUAGE_CODE}" ]
    then
      GLOBAL_PREFERENCES_FILE="${HOME}/Library/Preferences/ByHost/.GlobalPreferences.${HOST_ID}.plist"
    elif [ -e "${HOME}/Library/Preferences/.GlobalPreferences.plist" ]
    then
      LANGUAGE_CODE=`/usr/libexec/PlistBuddy -c "Print AppleLanguages:0" "${HOME}/Library/Preferences/.GlobalPreferences.plist"`
    fi
    if [ -n "${LANGUAGE_CODE}" ]
    then
      GLOBAL_PREFERENCES_FILE="${HOME}/Library/Preferences/.GlobalPreferences.plist"
    else
      LANGUAGE_CODE=`/usr/libexec/PlistBuddy -c "Print AppleLanguages:0" "/Library/Preferences/.GlobalPreferences.plist"`
      GLOBAL_PREFERENCES_FILE="/Library/Preferences/.GlobalPreferences.plist"
    fi
    if [ -z "${LANGUAGE_CODE}" ]
    then
      GLOBAL_PREFERENCES_FILE="${SYSBUILDER_FOLDER}/common/en.GlobalPreferences.plist"
      LANGUAGE_CODE="en_US"
    fi

    if [ -e "${HOME}/Library/Preferences/ByHost/com.apple.HIToolbox.${HOST_ID}.plist" ]
    then
      HITOOLBOX_INPUT_SOURCE=`/usr/libexec/PlistBuddy -c "Print AppleSelectedInputSources" "${HOME}/Library/Preferences/ByHost/com.apple.HIToolbox.${HOST_ID}.plist"`
    else
      HITOOLBOX_INPUT_SOURCE=
    fi
    if [ -n "${HITOOLBOX_INPUT_SOURCE}" ]
    then
      HITOOLBOX_FILE="${HOME}/Library/Preferences/ByHost/com.apple.HIToolbox.${HOST_ID}.plist"
    elif [ -e "${HOME}/Library/Preferences/com.apple.HIToolbox.plist" ]
    then
      HITOOLBOX_INPUT_SOURCE=`/usr/libexec/PlistBuddy -c "Print AppleSelectedInputSources" "${HOME}/Library/Preferences/com.apple.HIToolbox.plist"`
    fi
    if [ -n "${HITOOLBOX_INPUT_SOURCE}" ]
    then
      HITOOLBOX_FILE="${HOME}/Library/Preferences/com.apple.HIToolbox.plist"
    else
      HITOOLBOX_FILE="/Library/Preferences/com.apple.HIToolbox.plist"
    fi
    if [ ! -e "${HITOOLBOX_FILE}" ]
    then
      HITOOLBOX_FILE="${SYSBUILDER_FOLDER}/common/en.com.apple.HIToolbox.plist"
      LANGUAGE="English"
      LANGUAGE_CODE="en_US"
    else
      LANGUAGE=${LANGUAGE_CODE:0:2}
    fi
  else
    GLOBAL_PREFERENCES_FILE="${SYSBUILDER_FOLDER}/common/${LANGUAGE_CODE}.GlobalPreferences.plist"
    HITOOLBOX_FILE="${SYSBUILDER_FOLDER}/common/${LANGUAGE_CODE}.com.apple.HIToolbox.plist"
  fi

  ditto "${GLOBAL_PREFERENCES_FILE}" "${TMP_MOUNT_PATH}/Library/Preferences/.GlobalPreferences.plist" 2>&1
  chmod 644 "${TMP_MOUNT_PATH}"/Library/Preferences/.GlobalPreferences.plist 2>&1
  chown root:wheel "${TMP_MOUNT_PATH}"/Library/Preferences/.GlobalPreferences.plist 2>&1

  ditto "${HITOOLBOX_FILE}" "${TMP_MOUNT_PATH}/Library/Preferences/com.apple.HIToolbox.plist" 2>&1
  chmod 644 "${TMP_MOUNT_PATH}"/Library/Preferences/com.apple.HIToolbox.plist 2>&1
  chown root:wheel "${TMP_MOUNT_PATH}"/Library/Preferences/com.apple.HIToolbox.plist 2>&1

  ditto "${GLOBAL_PREFERENCES_FILE}" "${TMP_MOUNT_PATH}/var/root/Library/Preferences/.GlobalPreferences.plist" 2>&1
  chmod 644 "${TMP_MOUNT_PATH}"/var/root/Library/Preferences/.GlobalPreferences.plist 2>&1
  chown root:wheel "${TMP_MOUNT_PATH}"/var/root/Library/Preferences/.GlobalPreferences.plist 2>&1

  ditto "${HITOOLBOX_FILE}" "${TMP_MOUNT_PATH}/var/root/Library/Preferences/com.apple.HIToolbox.plist" 2>&1
  chmod 644 "${TMP_MOUNT_PATH}"/var/root/Library/Preferences/com.apple.HIToolbox.plist 2>&1
  chown root:wheel "${TMP_MOUNT_PATH}"/var/root/Library/Preferences/com.apple.HIToolbox.plist 2>&1
}

########################################################
# Main
########################################################

echo "Running ${SCRIPT_NAME} v${VERSION} ("`date`")"

# defaults
DISPLAY_SLEEP=10

# parsing arguments
SVAR=
for P in "${@}"
do
  if [ -n "${SVAR}" ]
  then
    if [ ${SVAR} == ARD_PASSWORD ]
    then
      export ${SVAR}=`echo "${P}" | sed "s/^\([\"]\)\(.*\)\1\$/\2/g"`
    else
      export ${SVAR}="${P}"
    fi
    SVAR=
  elif [ "${P}" == "-basesystem" ]
  then
    SVAR=BASE_SYSTEM
  elif [ "${P}" == "-type" ]
  then
    SVAR=SYS_BUILDER_TYPE
  elif [ "${P}" == "-volume" ]
  then
    SVAR=TARGET_VOLUME
  elif [ "${P}" == "-erasedisk" ]
  then
    ERASE_DISK=1
  elif [ "${P}" == "-id" ]
  then
    SVAR=NBI_ID
  elif [ "${P}" == "-dest" ]
  then
    SVAR=DEST_PATH
  elif [ "${P}" == "-name" ]
  then
    SVAR=NBI_NAME
  elif [ "${P}" == "-protocol" ]
  then
    SVAR=NBI_PROTOCOL
  elif [ "${P}" == "-loc" ]
  then
    SVAR=LANGUAGE
  elif [ "${P}" == "-serverurl" ]
  then
    SVAR=SERVER_URL
  elif [ "${P}" == "-serverurl2" ]
  then
    SVAR=SERVER_URL2
  elif [ "${P}" == "-disableversionsmismatchalerts" ]
  then
    DISABLE_VERSIONS_MISMATCH_ALERTS=1
  elif [ "${P}" == "-displaylogs" ]
  then
    SERVER_DISPLAY_LOGS=1
  elif [ "${P}" == "-login" ]
  then
    SVAR=SERVER_LOGIN
  elif [ "${P}" == "-password" ]
  then
    SVAR=SERVER_PASSWORD
  elif [ "${P}" == "-ardlogin" ]
  then
    SVAR=ARD_LOGIN
  elif [ "${P}" == "-ardpassword" ]
  then
    SVAR=ARD_PASSWORD
  elif [ "${P}" == "-timeout" ]
  then
    SVAR=TIMEOUT
  elif [ "${P}" == "-displaysleep" ]
  then
    SVAR=DISPLAY_SLEEP
  elif [ "${P}" == "-enableruby" ]
  then
    ENABLE_RUBY=1
  elif [ "${P}" == "-enablepython" ]
  then
    ENABLE_PYTHON=1
  elif [ "${P}" == "-enablecustomtcpstacksettings" ]
  then
    ENABLE_CUSTOM_TCP_STACK_SETTINGS=1
  elif [ "${P}" == "-disablewirelesssupport" ]
  then
    DISABLE_WIRELESS_SUPPORT=1
  elif [ "${P}" == "-ntp" ]
  then
    SVAR=NTP_SERVER
  elif [ "${P}" == "-customtitle" ]
  then
    SVAR=CUSTOM_RUNTIME_TITLE
  elif [ "${P}" == "-custombackground" ]
  then
    SVAR=CUSTOM_RUNTIME_BACKGROUND
  elif [ "${P}" == "-smb1only" ]
  then
    FORCE_SMB1=1
  else
    SVAR=
  fi
done

if [ -n "${TARGET_VOLUME}" ] && [ ! -e "/Volumes/${TARGET_VOLUME}" ]
then
  TARGET_VOLUME=
fi

if [ "${SYS_BUILDER_TYPE}" != "local" ] && [ "${SYS_BUILDER_TYPE}" != "netboot" ]
then
  print_usage
  echo "RuntimeAbortScript"
  exit 1
fi

if [ "${SYS_BUILDER_TYPE}" == "local" ] && [ ${#TARGET_VOLUME} -eq 0 ]
then
  print_usage
  echo "RuntimeAbortScript"
  exit 1
fi
if [ "${SYS_BUILDER_TYPE}" == "netboot" ] && [ `expr ${#NBI_ID} \* ${#NBI_NAME} \* ${#DEST_PATH}` -eq 0 ]
then
  print_usage
  echo "RuntimeAbortScript"
  exit 1
fi

# check DeployStudio Admin is installed
if [ ! -e "/Applications/Utilities/DeployStudio Admin.app" ] && [ ! -e "${SYSBUILDER_FOLDER}/../../../../Applications/Utilities/DeployStudio Admin.app" ]
then
    echo "DeployStudio Admin.app not found. Please reinstall DeployStudio on this computer."
	echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
    echo "RuntimeAbortScript"
    exit 1
fi

# preparing media
if [ "${SYS_BUILDER_TYPE}" == "local" ]
then
  TESTED_VOLUME="/Volumes/${TARGET_VOLUME}"
else
  TESTED_VOLUME="${DEST_PATH}"
fi
  
VOLUME_SIZE=`df -m "${TESTED_VOLUME}" | tail -n 1 | awk '{ print $2 }'`
if [ ${VOLUME_SIZE} -lt 1750 ]
then
    echo "Volume \"${TESTED_VOLUME}\" is to too small."
	echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
    echo "RuntimeAbortScript"
    exit 1
fi

if [ "${LANGUAGE}" == "default" ]
then
    LANGUAGE_CODE=default
elif [ "${LANGUAGE}" == "French" ]
then
    LANGUAGE_CODE=fr
elif [ "${LANGUAGE}" == "German" ]
then
    LANGUAGE_CODE=de
elif [ "${LANGUAGE}" == "Canadian French" ]
then
    LANGUAGE_CODE=fr_CA
else
    LANGUAGE="English"
    LANGUAGE_CODE=en
fi

if [ "${BASE_SYSTEM}" = "/" ] || [ ! -e "/Volumes/${BASE_SYSTEM}" ]
then
  BASE_SYSTEM_ROOT_PATH=""
else
  BASE_SYSTEM_ROOT_PATH="/Volumes/${BASE_SYSTEM}"
fi

HOST_UUID=`ioreg -rd1 -c IOPlatformExpertDevice | awk -F= '/(UUID)/ { gsub("[ \"]", ""); print $2 }'`
HOST_MACADDR=`/sbin/ifconfig en0 | grep -w ether | awk '{ gsub(":", ""); print $2 }'`
SYS_MIN_VERS=`defaults read "${BASE_SYSTEM_ROOT_PATH}"/System/Library/CoreServices/SystemVersion ProductVersion | awk -F. '{ print $2 }'`
SYS_VERS=10.${SYS_MIN_VERS}
SYS_VERS_FOLDER=${SYSBUILDER_FOLDER}/${SYS_VERS}

if [ -e "${SYS_VERS_FOLDER}" ]
then
  ARCH=i386
else
  echo "Unsupported system version (${SYS_VERS})!"
  echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
  echo "RuntimeAbortScript"
  exit 1
fi

echo "User:"${UID} 2>&1
echo "System version:"${SYS_VERS} 2>&1
echo "Architecture:"${ARCH} 2>&1

VOL_NAME=DeployStudioRuntime

#get_installer_basesystem
get_recovery_basesystem

if [ ! -e "/tmp/dss_basesystem/BaseSystem.sparseimage" ] && [ ! -e "/tmp/dss_basesystem/BaseSystem.dmg" ]
then
  if [ -e "/tmp/dss_basesystem" ]
  then
    rm -rf "/tmp/dss_basesystem"
  fi
  echo "Cannot find an appropriate base system!"
  echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
  echo "RuntimeAbortScript"
  exit 1
fi

if [ "${SYS_BUILDER_TYPE}" == "local" ]
then 
  VOL_NAME="${VOL_NAME}HD"
  if [ -n "${ERASE_DISK}" ]
  then
    DEVICE=/dev/disk`diskutil list | grep "${TARGET_VOLUME}" | awk '{ print $(NF) }' | sed s/disk// | awk -Fs '{ print $1 }' | tail -n1`
    if [ ! -e ${DEVICE} ]
    then
      echo "An error occured while resolving the device for volume \"${TARGET_VOLUME}\"."
	  echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
	  echo "RuntimeAbortScript"
      exit 1
    fi

    diskutil eraseDisk "Journaled HFS+" "${VOL_NAME}" GPTFormat "${DEVICE}" 2>&1
    if [ ${?} -ne 0 ]
    then
      echo "An error occured while formating the \"${DEVICE}\" device."
	  echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
      echo "RuntimeAbortScript"
      exit 1
    fi
  else
    diskutil eraseVolume "Journaled HFS+" "${VOL_NAME}" "/Volumes/${TARGET_VOLUME}" 2>&1
    if [ ${?} -ne 0 ]
    then
      echo "An error occured while erasing the \"/Volumes/${TARGET_VOLUME}\" volume."
	  echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
      echo "RuntimeAbortScript"
      exit 1
    fi
  fi

  DEVICE=/dev/`diskutil list | grep "${VOL_NAME}" | awk '{ print $(NF) }' | tail -n1`

  vsdbutil -a "/Volumes/${VOL_NAME}" 2>&1
  if [ ${?} -ne 0 ]
  then
    echo "An error occured while modifying the \"${DEVICE}\" device."
    echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
    echo "RuntimeAbortScript"
    exit 1
  fi

  TMP_MOUNT_PATH="/Volumes/${VOL_NAME}"
  if [ ! -e "${TMP_MOUNT_PATH}" ]
  then
    echo "An error occured while accessing to the \"${TMP_MOUNT_PATH}\" volume."
    echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
    echo "RuntimeAbortScript"
    exit 1
  fi

  asr restore --source "/tmp/dss_basesystem/BaseSystem.dmg" --target "${TMP_MOUNT_PATH}" --erase --noprompt --noverify
  if [ ${?} -ne 0 ]
  then
    echo "An error occured while restoring the base system to the \"${DEVICE}\" device."
    echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
    echo "RuntimeAbortScript"
    exit 1
  fi 
  diskutil renameVolume "${DEVICE}" "${VOL_NAME}"
else
  NBI_FOLDER=${DEST_PATH}/`echo "${NBI_NAME}" | tr ' ' '-'`.nbi
  SYSTEM_IMAGE_FILE=${NBI_FOLDER}/NetInstall.sparseimage
  SYSTEM_IMAGE_LINK=${NBI_FOLDER}/NetInstall.dmg
  TMP_MOUNT_PATH="/Volumes/${VOL_NAME}"

  if [ ! -e "${DEST_PATH}" ]
  then
    mkdir -p "${DEST_PATH}" 2>&1 
  fi

  ditto --rsrc -k -x "${SYSBUILDER_FOLDER}/common/nbi_folder.zip" "${DEST_PATH}" 2>&1

  if [ -e "${NBI_FOLDER}" ]
  then
    rm -rf "${NBI_FOLDER}" 2>&1
  fi
  mv "${DEST_PATH}/nbi_folder" "${NBI_FOLDER}" 2>&1

  chmod 777 "${NBI_FOLDER}" 2>&1

  mv "/tmp/dss_basesystem/BaseSystem.sparseimage"  "${SYSTEM_IMAGE_FILE}" 2>&1
  if [ ${?} -ne 0 ]
  then
    echo "An error occured while creating the \"${SYSTEM_IMAGE_FILE}\"."
    rm -rf "${NBI_FOLDER}" 2>&1
    echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
    echo "RuntimeAbortScript"
    exit 1
  fi

  chmod 777 "${SYSTEM_IMAGE_FILE}" 2>&1

  ATTACHED=`hdiutil attach "${SYSTEM_IMAGE_FILE}" -owners on -nobrowse 2>&1`

  DEVICE=`echo ${ATTACHED} | awk '{ print $1 }'`
  if [ -e "${DEVICE}" ]
  then
    diskutil renameVolume "${DEVICE}s1" "${VOL_NAME}"
  fi
fi

# disable spotlight indexing
mdutil -i off "${TMP_MOUNT_PATH}"
mdutil -E "${TMP_MOUNT_PATH}"
defaults write "${TMP_MOUNT_PATH}"/.Spotlight-V100/_IndexPolicy Policy -int 3

# fill media
source "${SYS_VERS_FOLDER}"/fill_Volume.sh

# fix language preference
update_language_preference

# fix timezone
rm -f "${TMP_MOUNT_PATH}"/etc/localtime
cp -a /etc/localtime "${TMP_MOUNT_PATH}"/etc/

# disable Wireless support
if [ -n "${DISABLE_WIRELESS_SUPPORT}" ]
then
  rm -rf "${TMP_MOUNT_PATH}"/System/Library/Extensions/IO80211Family.kext
fi

# remove nsmb.conf if not needed
if [ -z "${FORCE_SMB1}" ]
then
  rm -f "${TMP_MOUNT_PATH}"/etc/nsmb.conf 2>/dev/null
fi

# remove broken links
if [ -e "${TMP_MOUNT_PATH}"/System/Installation/Packages ]
then
  rm -f "${TMP_MOUNT_PATH}"/System/Installation/Packages
fi 

# add PlatformSupport.plist file if missing
if [ ! -e "${TMP_MOUNT_PATH}"/System/Library/CoreServices/PlatformSupport.plist ] && [ -e "${BASE_SYSTEM_ROOT_PATH}"/System/Library/CoreServices/PlatformSupport.plist ]
then
  ditto "${BASE_SYSTEM_ROOT_PATH}"/System/Library/CoreServices/PlatformSupport.plist "${TMP_MOUNT_PATH}"/System/Library/CoreServices/PlatformSupport.plist
fi

# remove extra languages resources
find "${TMP_MOUNT_PATH}" ! -name "Base.lproj" ! -name "English.lproj" ! -name "en.lproj" -name "*.lproj" -exec rm -r -- {} \; -prune

# closing media
if [ "${SYS_BUILDER_TYPE}" == "local" ]
then
  # save sys_builder version
  defaults write "${TMP_MOUNT_PATH}/etc/DeployStudioAssistantInfo" SysBuilderVersion "${VERSION}"
  defaults write "${TMP_MOUNT_PATH}/etc/DeployStudioAssistantInfo" FillVolumeVersion "${FILL_VOLUME_VERSION}"
  plutil -convert xml1 "${TMP_MOUNT_PATH}/etc/DeployStudioAssistantInfo.plist"
  chmod 664 "${TMP_MOUNT_PATH}/etc/DeployStudioAssistantInfo.plist" 2>&1
  chown root:admin "${TMP_MOUNT_PATH}/etc/DeployStudioAssistantInfo.plist" 2>&1

  if [ -e "/tmp/dss_basesystem/booter" ]
  then
    cp "/tmp/dss_basesystem/booter" "${TMP_MOUNT_PATH}/usr/standalone/i386/boot.efi" 2>&1
  fi

  if [ -e "/tmp/dss_basesystem/kernelcache" ]
  then
    ditto --norsrc "/tmp/dss_basesystem/kernelcache" "${TMP_MOUNT_PATH}/System/Library/PrelinkedKernels/prelinkedkernel"
  fi

  bless --folder "${TMP_MOUNT_PATH}"/System/Library/CoreServices --label "${VOL_NAME}" --verbose
else
  ditto --rsrc "${SYS_VERS_FOLDER}/NBImageInfo.plist" "${NBI_FOLDER}/NBImageInfo.plist"
  defaults write "${NBI_FOLDER}/NBImageInfo" Architectures -array ${ARCH}
  defaults write "${NBI_FOLDER}/NBImageInfo" DisabledSystemIdentifiers -array
  defaults write "${NBI_FOLDER}/NBImageInfo" EnabledSystemIdentifiers -array
  defaults write "${NBI_FOLDER}/NBImageInfo" Index -int ${NBI_ID}
  defaults write "${NBI_FOLDER}/NBImageInfo" Name "${NBI_NAME}"
  defaults write "${NBI_FOLDER}/NBImageInfo" Description "${NBI_NAME}"
  if [ -n "${NBI_PROTOCOL}" ]
  then
    defaults write "${NBI_FOLDER}/NBImageInfo" Type "${NBI_PROTOCOL}"
  fi
  defaults write "${NBI_FOLDER}/NBImageInfo" Language "${LANGUAGE}"
  defaults write "${NBI_FOLDER}/NBImageInfo" LanguageCode "${LANGUAGE_CODE}"
  defaults write "${NBI_FOLDER}/NBImageInfo" osVersion "${SYS_VERS}"
  plutil -convert xml1 "${NBI_FOLDER}/NBImageInfo.plist"

  # save sys_builder version
  defaults write "${NBI_FOLDER}/DeployStudioAssistantInfo" SysBuilderVersion "${VERSION}"
  defaults write "${NBI_FOLDER}/DeployStudioAssistantInfo" FillVolumeVersion "${FILL_VOLUME_VERSION}"
  plutil -convert xml1 "${NBI_FOLDER}/DeployStudioAssistantInfo.plist"

  # add kernel and kext cache
  mkdir -p "${NBI_FOLDER}/i386/x86_64" 2>&1
  chmod -R 777 "${NBI_FOLDER}/i386" 2>&1
  cp "${TMP_MOUNT_PATH}"/System/Library/CoreServices/PlatformSupport.plist "${NBI_FOLDER}"/i386/PlatformSupport.plist

  if [ -e "/tmp/dss_basesystem/booter" ]
  then
    cp "/tmp/dss_basesystem/booter" "${TMP_MOUNT_PATH}/usr/standalone/i386/boot.efi" 2>&1
    cp "/tmp/dss_basesystem/booter" "${NBI_FOLDER}/${ARCH}/booter" 2>&1
  fi

  if [ -e "/tmp/dss_basesystem/kernelcache" ]
  then
    ditto --norsrc "/tmp/dss_basesystem/kernelcache" "${TMP_MOUNT_PATH}/System/Library/PrelinkedKernels/prelinkedkernel"
    ditto --norsrc "/tmp/dss_basesystem/kernelcache" "${NBI_FOLDER}/i386/x86_64/kernelcache"
    chmod 644 "${NBI_FOLDER}/i386/x86_64/kernelcache"
  fi

  TRIES=2

  hdiutil detach "${TMP_MOUNT_PATH}" 2>&1

  while [ ${?} -ne 0 ];
  do
    TRIES=`expr ${TRIES} + 1` 
    if [ ${TRIES} -gt 5 ]
    then
      echo "An error occured while umount \"${TMP_MOUNT_PATH}\"."
	  echo "Aborting ${SCRIPT_NAME} v${VERSION} ("`date`")"
	  echo "RuntimeAbortScript"
      exit 1
    fi
    sleep 20
    hdiutil detach -force "${TMP_MOUNT_PATH}" 2>&1
  done

  chmod -R 664 "${NBI_FOLDER}" 2>&1
  chmod 775 "${NBI_FOLDER}" 2>&1

  chmod 775 "${NBI_FOLDER}/i386" "${NBI_FOLDER}/i386/x86_64" 2>&1

  ln -s `basename "${SYSTEM_IMAGE_FILE}"` "${SYSTEM_IMAGE_LINK}"

  chown -R root:admin "${NBI_FOLDER}" 2>&1
fi

rm /tmp/DSCustomDefaultDesktop.jpg 2>/dev/null

if [ -e "/tmp/dss_basesystem" ]
then
  rm -rf "/tmp/dss_basesystem"
fi

echo "Exiting ${SCRIPT_NAME} v${VERSION} ("`date`")"
echo "Printing ENV"
echo `env`
exit 0
