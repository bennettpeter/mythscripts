#!/bin/bash

# External Recorder Frontend
# Parameter 1 - recorder name

# In mythtv setup, create a capture card type EXTERNAL. Enter command path
# as /opt/mythtv/bin/hdmirecroder.sh hdmirec1
# assuming this is installed in that path and you call the tuner hdmirec1
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
logfile=$LOGDIR/${scriptname}.log

# Get a date/time stamp to add to log output
date=`date +%F\ %T\.%N`
date=${date:0:23}

# Select the [default] section of conf and put it in a file
# to source it
awk '/^\[default\]$/ { def = 1; next }
/^\[/ { def = 0; next }
def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
> /tmp/${recname}_$$.conf

. /tmp/${recname}_$$.conf

rc=0
if [[ ! -e $VIDEO_IN ]] ; then
    echo "$date" ERROR $VIDEO_IN does not exist >>$logfile
    rc=2
fi

if ! pacmd list-sources|grep -q "$AUDIO_IN" ; then
    echo "$date" ERROR $AUDIO_IN does not exist >>$logfile
    rc=2
fi

if [[ "$rc" != 0 ]] ; then exit $rc ; fi

echo "$date" mythexternrecorder  --exec --conf /etc/opt/mythtv/${recname}.conf "${@}" >>$logfile
mythexternrecorder  --exec --conf /etc/opt/mythtv/${recname}.conf "${@}"
rc=$?

date=`date +%F\ %T\.%N`
date=${date:0:23}

echo "$date" mythexternrecorder ended rc=$rc >>$logfile
exit $rc
