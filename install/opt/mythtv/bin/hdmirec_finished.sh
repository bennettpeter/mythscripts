#!/bin/bash

# External Recorder Finished Recording
# Parameter 1 - recorder name

recname=$1

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/hdmifuncs.sh

ADB_ENDKEY=
initialize
getparms
lockdir=$DATADIR/lock_$recname
while ! mkdir $lockdir ; do
    echo `$LOGDATE` "Encoder $recname is locked, waiting"
    sleep 5
    continue
 done
LOCKDIR=$lockdir
gettunestatus
# Set this to kill recording in case it has not actually finished
ffmpeg_pid=$tune_ffmpeg_pid
if [[ "$tunestatus" == tuned  ]] ; then
    echo `$LOGDATE` "Ending playback"
    adb connect $ANDROID_DEVICE
    $scriptpath/adb-sendkey.sh BACK
    true > $tunefile
else
    echo `$LOGDATE` "Playback already ended - nothing to do"
fi
