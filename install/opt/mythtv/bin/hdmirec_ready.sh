#!/bin/bash

# Initialize android device and make it ready for tuning
# Keep the device on favorite channel list.

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

recname="$1"
if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi

source $scriptpath/hdmifuncs.sh

SLEEPTIME=300
initialize

# tunestatus values
# idle
# tuned
errored=0
while true ; do
    if ! locktuner ; then
        echo `$LOGDATE` "Encoder $recname is already locked, waiting"
        sleep $SLEEPTIME
        continue
    fi
    getparms
    rc=$?
    if (( rc > errored )) ; then
        $scriptpath/notify.py "Fire Stick Problem" \
            "hdmirec_ready: $errormsg on ${recname}" &
        errored=rc
    fi
    gettunestatus
    if [[ "$tunestatus" == idle ]] ; then
        adb connect $ANDROID_DEVICE
        getfavorites
        rc=$?
        if (( rc > errored ))  ; then
            $scriptpath/notify.py "Fire Stick Problem" \
              "hdmirec_ready: Failed to get to favorite channels on ${recname}" &
            errored=rc
        fi
        adb disconnect $ANDROID_DEVICE
    else
        echo `$LOGDATE` "Encoder $recname is tuned, waiting"
    fi
    unlocktuner
    sleep $SLEEPTIME
done
