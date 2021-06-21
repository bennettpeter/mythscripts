#!/bin/bash

# External Recorder New episode on same channel
# Parameter 1 - recorder name
# Paramater 2 - channel number, unused

recname=$1
channum=$2

MINTIME=300

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/hdmifuncs.sh
initialize
getparms

echo `$LOGDATE` "New Episode on chennel $channum "

lockdir=$DATADIR/lock_$recname
if [[ ! -d $lockdir ]] ; then
    echo `$LOGDATE` "Encoder $recname is not locked, exiting"
    exit
fi
gettunestatus

if [[ "$tunestatus" == playing ]] ; then
    now=$(date +%s)
    # 10200 seconds = 2hr 50 mins
    let elapsed=now-tunetime
    if (( elapsed > MINTIME )) ; then
        # A button press to ensure the playback does not stop with
        # "Are you still there"
        adb connect $ANDROID_DEVICE
        sleep 0.5
        # Let Android know we are still here - this displays progress bar briefly
        $scriptpath/adb-sendkey.sh DPAD_CENTER
        echo "tunetime=$(date +%s)" >> $tunefile
        echo `$LOGDATE` "Prodded $recname"
    else
        echo `$LOGDATE` "Too soon to prod $recname"
    fi
else
    echo `$LOGDATE` "Encoder $recname is not playing, exiting"
fi
exit 0
