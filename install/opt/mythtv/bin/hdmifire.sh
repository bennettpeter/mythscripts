#!/bin/bash
# Record from fire stick

# Set to 1 to allow wifi fallback
ALLOW_WIFI=0
VID_RECDIR=/home/storage/Video/recordings

responses="$1"
minutes="$2"
recname="$3"
if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi

echo "*** $0 ***"
echo "Input parameters:"
echo "Number of responses (default 0)"
echo "Maximum Number of minutes [default 300*(responses+1)]"
echo "Recorder id (default hdmirec1)"

function capturepage {
    pagename=
    sleep 1
    true > $DATADIR/${recname}_capture_crop.png
    true > $DATADIR/${recname}_capture_crop.txt
    adb exec-out screencap -p > $DATADIR/${recname}_capture.png
    if [[ `stat -c %s $DATADIR/${recname}_capture.png` == 0 ]] ; then
        if [[ "$ffmpeg_pid" == "" ]] || ! ps -q $ffmpeg_pid >/dev/null ; then
            ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s $RESOLUTION -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.png
        fi
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture.png` != 0 ]] ; then
        convert $DATADIR/${recname}_capture.png -gravity East -crop 95%x100% -negate -brightness-contrast 0x20 $DATADIR/${recname}_capture_crop.png
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
        cp -f $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt
        tesseract $DATADIR/${recname}_capture_crop.png  - 2>/dev/null | sed '/^ *$/d' > $DATADIR/${recname}_capture_crop.txt
        if diff -q $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt >/dev/null ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` Same Again
        else
            echo "*****" `date "+%Y-%m-%d_%H-%M-%S"`
            cat $DATADIR/${recname}_capture_crop.txt
            echo "*****"
        fi
        pagename=$(head -n 1 $DATADIR/${recname}_capture_crop.txt)
    fi
}

function trapfunc {
    # Note in the trap function all signals are ignored, only kill -KILL works
    rc=$?
    echo "Exiting..."
    sleep 2
    if [[ "$ffmpeg_pid" != "" ]] && ps -q $ffmpeg_pid >/dev/null ; then
        kill $ffmpeg_pid
    fi
    capturepage
    if (( isrecording )) ; then
        $scriptpath/adb-sendkey.sh HOME
    fi
    adb disconnect $ANDROID_DEVICE
    # TODO Check $rc and notify if not zero
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Exit"
    if [[ "$tail_pid" != "" ]] && ps -q $tail_pid >/dev/null ; then
        kill $tail_pid
    fi
}

isrecording=0
trap trapfunc EXIT

. /etc/opt/mythtv/mythtv.conf

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
if [[ -t 1 ]] ; then
    isterminal=Y
else
    isterminal=N
fi

# Select the [default] section of conf and put it in a file
# to source it
awk '/^\[default\]$/ { def = 1; next }
/^\[/ { def = 0; next }
def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
> $DATADIR/etc_${recname}.conf
. $DATADIR/etc_${recname}.conf
# This sets VIDEO_IN and AUDIO_IN
. $DATADIR/${recname}.conf
if ping -c 1 $ANDROID_MAIN ; then
    ANDROID_DEVICE=$ANDROID_MAIN
else
    echo `date "+%Y-%m-%d_%H-%M-%S"` "ERROR: Ethernet failure"
    # Remove this exit if you want to be able to use the
    # fallback wifi device
    if (( ! ALLOW_WIFI )) ; then
        exit 2
    fi
    ANDROID_DEVICE=$ANDROID_FALLBACK
fi
export ANDROID_DEVICE

ffmpeg_pid=

let responses=responses
let minutes=minutes
# Default to 300 minutes - 5 hours
if (( $minutes == 0 )) ; then
    let minutes=300*\(responses+1\)
fi
echo
let seconds=minutes*60
echo Record for $minutes minutes and respond $responses times.
echo This script will press the DPAD_CENTER to start. Do not press it.
echo Type Y to start
read -e resp
if [[ "$resp" != Y ]] ; then exit 2 ; fi

exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
tail_pid=
if [[ $isterminal == Y ]] ; then
    tail -f $LOGDIR/${scriptname}.log >/dev/tty &
    tail_pid=$!
fi
echo `date "+%Y-%m-%d_%H-%M-%S"` "Start of run"
echo "echo Record for $minutes minutes and respond $responses times."

adb disconnect $ANDROID_DEVICE 2>/dev/null || true
adb connect $ANDROID_DEVICE
if ! adb devices | grep $ANDROID_DEVICE ; then
    echo "ERROR: Unable to connect to $ANDROID_DEVICE"
    exit 2
fi

# Kill vlc
wmctrl -c vlc
wmctrl -c obs
sleep 2

capturepage
logdate=`date "+%Y-%m-%d_%H-%M-%S"`
echo `date "+%Y-%m-%d_%H-%M-%S"` "Starting recording of ${logdate}"
isrecording=1
adb-sendkey.sh DPAD_CENTER

ffmpeg -hide_banner -loglevel error \
-f v4l2 \
-thread_queue_size 256 \
-input_format $INPUT_FORMAT \
-framerate $FRAMERATE \
-video_size $RESOLUTION \
-use_wallclock_as_timestamps 1 \
-i $VIDEO_IN \
-f alsa \
-ac 2 \
-ar 48000 \
-thread_queue_size 1024 \
-itsoffset $AUDIO_OFFSET \
-i $AUDIO_IN \
-c:v libx264 \
-vf format=yuv420p \
-preset faster \
-crf 23 \
-c:a aac \
$VID_RECDIR/${logdate}.mkv &

# Removed
# -f pulse \
# -i "alsa_input.usb-MACROSILICON_2109-02.analog-stereo" \

ffmpeg_pid=$!
#echo "#!/bin/bash" > $VID_RECDIR/${logdate}_kill.sh
#echo "kill $ffmpeg_pid" >> $VID_RECDIR/${logdate}_kill.sh
#echo "echo Wait 1 minute" >> $VID_RECDIR/${logdate}_kill.sh
#sleep 0.5
#chmod +x $VID_RECDIR/${logdate}_kill.sh
starttime=`date +%s`
let endtime=starttime+seconds
filesize=0
let loops=responses+1
for (( xx = 0 ; xx < loops ; xx++ )) ; do
    lowcount=0
    while true ; do
        sleep 60
        now=`date +%s`
        if (( now > endtime )) ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` "Time Limit reached"
            break 2
        fi
        if ! ps -q $ffmpeg_pid >/dev/null ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` "ffmpeg terminated"
            break 2
        fi
        if (( lowcount > 2 )) ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` "Playback paused"
            if (( xx < responses )) ; then break ; fi
            break 2
        fi
        nowdate=`date "+%Y-%m-%d_%H-%M-%S"`
        newsize=`stat -c %s $VID_RECDIR/${logdate}.mkv`
        let diff=newsize-filesize
        filesize=$newsize
        echo "$nowdate size: $filesize  Incr: $diff" >> $VID_RECDIR/${logdate}_size.log
        if (( diff < 5000000 )) ; then 
            let lowcount=lowcount+1
            echo "*** Less than 5 MB *** lowcount=$lowcount" >> $VID_RECDIR/${logdate}_size.log
        else
            lowcount=0
        fi
    done
    sleep 1
    capturepage
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Sending enter to start next episode"
    sleep 1
    adb-sendkey.sh DPAD_CENTER
    sleep 1
done
echo `date "+%Y-%m-%d_%H-%M-%S"` "Playback finished"
