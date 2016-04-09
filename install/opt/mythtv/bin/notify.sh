#!/bin/bash
# Send an email and / or text message when a recording fails
# Input parameters:
# Subject
# Content
# [mail, nomail] default mail

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
logfile=$LOGDIR/${scriptname}.log

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}

echo "Notify: $1 $2 $3"
echo $DATE: $1 $2 $3 >>$logfile

if [[ "$EMAIL1$EMAIL2" != "" && "$3" != "nomail" ]] ; then
    echo "$DATE: $2" | mail -s "$1" $EMAIL1 $EMAIL2
fi
