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
source $scriptpath/hdmifuncs.sh
ffmpeg_pid=
logfile=$LOGDIR/${scriptname}_${recname}.log
{
    initialize NOREDIRECT
    getparms
    lockdir=$DATADIR/lock_$recname
    while ! mkdir $lockdir ; do
        echo `$LOGDATE` "Encoder $recname is locked, waiting"
        sleep 5
        continue
     done
    LOCKDIR=$lockdir
    gettunestatus

    # tunestatus values
    # idle
    # tuned
    # playing

    if [[ "$tunestatus" == tuned  ]] ; then
        echo `$LOGDATE` "Tuned to channel $tunechan"
    #~ elif [[ "$tunestatus" == playing ]] ; then
        #~ echo `$LOGDATE` "ERROR: Already playing"
        #~ exit 2
    else
        echo `$LOGDATE` "ERROR: Not tuned, status $tunestatus, cannot record"
        exit 2
    fi

    adb connect $ANDROID_DEVICE
    if ! adb devices | grep $ANDROID_DEVICE ; then
        echo `$LOGDATE` "ERROR: Unable to connect to $ANDROID_DEVICE"
        exit 2
    fi
    #~ ADB_ENDKEY=BACK

    if [[ "$AUDIO_OFFSET" == "" ]] ; then
        AUDIO_OFFSET=0.000
    fi
    #~ echo `$LOGDATE` "Starting recording"
    #~ ADB_ENDKEY=BACK
    #~ $scriptpath/adb-sendkey.sh DPAD_CENTER

    # Indicator to clear tunestatus at end
    #~ cleartunestatus=1
    #~ echo "tunestatus=playing" >> $tunefile
} &>> $logfile

ffmpeg -hide_banner -loglevel error -f v4l2 -thread_queue_size 256 -input_format $INPUT_FORMAT \
  -framerate $FRAMERATE -video_size $RESOLUTION \
  -use_wallclock_as_timestamps 1 \
  -i $VIDEO_IN -f alsa -ac 2 -ar 48000 -thread_queue_size 1024 \
  -itsoffset $AUDIO_OFFSET -i $AUDIO_IN \
  -c:v libx264 -vf format=yuv420p -preset faster -crf 23 -c:a aac \
  -f mpegts - &

ffmpeg_pid=$!
echo tune_ffmpeg_pid=$ffmpeg_pid >> $tunefile

wait $ffmpeg_pid
