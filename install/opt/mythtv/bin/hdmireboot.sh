#!/bin/bash

# Reboot device and dismiss stupid message
# Imput param: recorder id hdmirec1, defaults to hdmirec1

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/hdmifuncs.sh

initialize

recname="$1"
if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi

getparms
adb connect $ANDROID_DEVICE
sleep 0.5
res=(`adb devices|grep $ANDROID_DEVICE`)
status=${res[1]}
if [[ "$status" != device ]] ; then
    echo `$LOGDATE` "ERROR: Device offline: $recname"
    exit 2
fi
echo `$LOGDATE` "reboot: $recname"
adb -s $ANDROID_DEVICE shell reboot
status=
found=0
for (( count=0 ; count < 20 && found < 3 ; count++ )) ; do
    sleep 5
    adb connect $ANDROID_DEVICE
    sleep 0.5
    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    echo `$LOGDATE` "status: $status"
    if [[ "$status" == device ]] ; then let found++ ; fi
done
if (( found < 2 )) ; then
    echo `$LOGDATE` "ERROR Lost contact with $ANDROID_DEVICE"
    exit 2
fi
$scriptpath/adb-sendkey.sh HOME
echo `$LOGDATE` "Sleep for 75 seconds to wait for stupid message..."
sleep 75
VIDEO_IN=
capturepage
# Get rid of message that remote is not detected
echo `$LOGDATE` "Dismiss stupid message"
$scriptpath/adb-sendkey.sh DPAD_CENTER
