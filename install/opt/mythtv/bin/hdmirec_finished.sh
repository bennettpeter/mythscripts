#!/bin/bash

# External Recorder Finished Recording
# Parameter 1 - recorder name

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

echo $date Finished Recording on recorder $recname

export ANDROID_DEVICE
adb connect $ANDROID_DEVICE

# Exit from application
$scriptpath/adb-sendkey.sh HOME
adb disconnect $ANDROID_DEVICE
