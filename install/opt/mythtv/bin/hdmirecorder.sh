#!/bin/bash

# External Recorder Frontend
# Parameter 1 - recorder name

# In mythtv setup, create a capture card type EXTERNAL. Enter command path
# as /opt/mythtv/bin/hdmirecorder.sh hdmirec1
# (fill in correct path and tuner id)
# setup /etc/opt/mythtv/hdmirec1.conf

# This script must write nothing to stdout or stderr, also it must not
# redirect stdout or stderr of mythexternrecorder as these are both
# used by mythbackend for cmmunicating with mythexternrecorder

recname=$1
shift
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
source $scriptpath/hdmifuncs.sh
logfile=$LOGDIR/${scriptname}_${recname}.log
{
    initialize NOREDIRECT
    getparms
    rc=0
    if [[ ! -e $VIDEO_IN ]] ; then
        echo "$date" ERROR $VIDEO_IN does not exist >>$logfile
        rc=2
    fi

    srch=$(echo $AUDIO_IN | sed 's/hw:/card /;s/,/.*device /')
    if ! arecord -l|grep -q "$srch" ; then
        echo "$date" ERROR $AUDIO_IN does not exist >>$logfile
        rc=2
    fi

    if [[ "$rc" != 0 ]] ; then exit $rc ; fi
} &>>$logfile

echo `$LOGDATE` mythexternrecorder  --exec --conf /etc/opt/mythtv/${recname}.conf "${@}" >>$logfile
mythexternrecorder  --exec --conf /etc/opt/mythtv/${recname}.conf "${@}"
rc=$?

echo `$LOGDATE` mythexternrecorder ended rc=$rc >>$logfile
exit $rc
