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
ADB_ENDKEY=
initialize

getparms
#tunefile=$DATADIR/${recname}_tune.stat
# Clear status and locks
#true > $tunefile
#rm -rf $DATADIR/lock_$recname

# tunestatus values
# idle
# tuned
# playing

while true ; do
    lockdir=$DATADIR/lock_$recname
    if ! mkdir $lockdir ; then
        echo `$LOGDATE` "Encoder $recname is locked, waiting"
        sleep $SLEEPTIME
        continue
    fi
    LOCKDIR=$lockdir
    gettunestatus
    if [[ "$tunestatus" == idle ]] ; then
        adb connect $ANDROID_DEVICE
        #~ if (( ! reset_done )) ; then
            # This fails on old version of adb.
            #~ echo force stop
            #~ adb shell am force-stop com.xfinity.cloudtvr.tenfoot
            #~ reset_done=1
        #~ fi
        getfavorites
        adb disconnect $ANDROID_DEVICE
    else
        echo `$LOGDATE` "Encoder $recname is tuned, waiting"
    fi
    rmdir $LOCKDIR
    LOCKDIR=
    sleep $SLEEPTIME
done
