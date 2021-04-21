#!/bin/bash

# External Recorder Encoder
# Parameter 1 - recorder name

# In mythtv setup, create a capture card type EXTERNAL.
# Enter command path
# as /opt/mythtv/bin/hdmirecorder.sh hdmirec1
# assuming this is installed in that path and you call the tuner hdmirec1

# This script must write nothing to stdout other than the encoded data.
recname=$1

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
> $DATADIR/${recname}.conf
. $DATADIR/${recname}.conf

echo $date Start ffmpeg >>$logfile

exec ffmpeg -hide_banner -loglevel error -f v4l2 -thread_queue_size 256 -input_format $INPUT_FORMAT \
  -framerate $FRAMERATE -video_size $RESOLUTION \
  -use_wallclock_as_timestamps 1 \
  -i $VIDEO_IN -f pulse -ac 2 -ar 48000 -thread_queue_size 1024 \
  -itsoffset 0.000 -i "$AUDIO_IN" \
  -c:v libx264 -vf format=yuv420p -preset faster -crf 23 -c:a aac \
  -f mpegts - 2>>$logfile
