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

echo `$LOGDATE` "Finished recording on tuner $recname"
