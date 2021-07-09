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
sleep 15
errored=0
lastrescheck=
while true ; do
    if ! locktuner ; then
        echo `$LOGDATE` "Encoder $recname is already locked, waiting"
        sleep $SLEEPTIME
        continue
    fi
    gettunestatus
    # Stopped more than 5 minutes ago and not playing - tweak it
    now=$(date +%s)
    if (( tunetime < now-300 )) && [[ "$tunestatus" == idle ]] ; then
        getparms
        rc=$?
        if (( rc > errored )) ; then
            $scriptpath/notify.py "Fire Stick Problem" \
                "hdmirec_ready: $errormsg on ${recname}" &
            errored=$rc
        fi
        today=$(date +%Y-%m-%d)
        adb connect $ANDROID_DEVICE
        if [[ "$lastrescheck" != "$today" ]] ; then
            errored=0
            capturepage adb
            rc=$?
            if (( rc == 1 )) ; then
                $scriptpath/notify.py "Fire Stick Problem" \
                  "hdmirec_ready: Wrong resolution on ${recname}" &
            fi
            lastrescheck="$today"
        fi
        $scriptpath/adb-sendkey.sh MENU MENU
        getfavorites
        rc=$?
        if (( rc > errored ))  ; then
            $scriptpath/notify.py "Fire Stick Problem" \
              "hdmirec_ready: Failed to get to favorite channels on ${recname}" &
            errored=$rc
        fi
        adb disconnect $ANDROID_DEVICE
    else
        echo `$LOGDATE` "Encoder $recname is tuned, waiting"
    fi
    unlocktuner
    sleep $SLEEPTIME
done
