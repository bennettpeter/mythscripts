#!/bin/bash

# External Recorder New episode on same channel
# Parameter 1 - recorder name
# Paramater 2 - channel number, unused

recname=$1

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
logfile=$LOGDIR/${scriptname}.log
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1

# Get a date/time stamp to add to log output
date=`date +%F\ %T\.%N`
date=${date:0:23}

# Select the [default] section of conf and put it in a file
# to source it
awk '/^\[default\]$/ { def = 1; next }
/^\[/ { def = 0; next }
def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
> $DATADIR/etc_${recname}.conf
. $DATADIR/etc_${recname}.conf
. $DATADIR/${recname}.conf

echo $date New Episode Recording on recorder $recname

tunefile=$DATADIR/${recname}_tune.stat
partialtune=N
if [[ -f $tunefile ]] ; then
    . $tunefile
    if [[ "$tunestatus" == playing ]] ; then
        now=$(date +%s)
        # 10200 seconds = 2hr 50 mins
        if (( tunetime < now-10200 )) ; then
            echo "$date Tuner was recording more than 2 hr 50 min, pause and resume"
            # In case another version of adb is running
            # Some button presses to ensure the playback does not stop with
            # "Are you still there"
            export ANDROID_DEVICE
            adb connect $ANDROID_DEVICE
            sleep 0.5
            # Let Android know we are still here - pause and play
            $scriptpath/adb-sendkey.sh MEDIA_PLAY_PAUSE MEDIA_PLAY_PAUSE
            adb disconnect $ANDROID_DEVICE
            echo "tunetime=$(date +%s)" >> $tunefile
        fi
    fi
fi
exit 0
