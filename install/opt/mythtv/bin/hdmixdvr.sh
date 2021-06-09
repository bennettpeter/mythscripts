#!/bin/bash

recname=$1

#DATADIR=/var/opt/mythtv
if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi
VID_RECDIR=/home/storage/Video/recordings
# Maximum time for 1 recording.
MAXTIME=100
let maxduration=MAXTIME*60
#LOGDIR=/var/log/mythtv_scripts

. /etc/opt/mythtv/mythtv.conf

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
if [[ -t 1 ]] ; then
    isterminal=Y
else
    isterminal=N
fi
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
#scriptpath=/opt/mythtv/bin
tail_pid=
if [[ $isterminal == Y ]] ; then
    tail -f $LOGDIR/${scriptname}.log >/dev/tty &
    tail_pid=$!
fi
logdate=`date "+%Y-%m-%d_%H-%M-%S"`
echo `date "+%Y-%m-%d_%H-%M-%S"` "Start of run"

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
    exit 2
    ANDROID_DEVICE=$ANDROID_FALLBACK
fi
export ANDROID_DEVICE

ffmpeg_pid=

function capturepage {
    pagename=
    sleep 1
    cp -f $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt
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

function waitforpage {
    wanted="$1"
    xx=0
    while [[ "$pagename" != "$wanted" ]] && (( xx++ < 90 )) ; do
        capturepage
    done
    if [[ "$pagename" != "$wanted" ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "ERROR - Cannot get to $wanted Page"
        exit 2
    fi
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Reached $wanted page"
}

function trapfunc {
    rc=$?
    $scriptpath/adb-sendkey.sh HOME
    if [[ "$ffmpeg_pid" != "" ]] && ps -q $ffmpeg_pid >/dev/null ; then
        kill $ffmpeg_pid
    fi
    if [[ "$tail_pid" != "" ]] && ps -q $tail_pid >/dev/null ; then
        kill $tail_pid
    fi
    adb disconnect $ANDROID_DEVICE
    # Check $rc and notify if not zero
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Exit"
}

trap trapfunc EXIT

# Kill vlc
wmctrl -c vlc
wmctrl -c obs

# Get to recordings list

adb connect $ANDROID_DEVICE
pagename=
xx=0
while [[ "$pagename" != Recordings ]] && (( xx++ < 5 )) ; do
    sleep 0.5
    $scriptpath/adb-sendkey.sh HOME RIGHT RIGHT RIGHT DPAD_CENTER
    waitforpage "For You"
    $scriptpath/adb-sendkey.sh MENU
    waitforpage "Search"
    $scriptpath/adb-sendkey.sh DOWN DPAD_CENTER
    sleep 0.5
    capturepage
done
if [[ "$pagename" == Recordings ]] ; then
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Reached Recordings Page"
else
    echo `date "+%Y-%m-%d_%H-%M-%S"` "ERROR - Cannot get to Recordings Page"
    exit 2
fi
sleep 5
capturepage
# See if there are any recordings
while  true ; do
    # Select First Recording
    title=$(head -3 $DATADIR/${recname}_capture_crop.txt  | tail -1)
    if [[ "$title" == "Deleted Recordings" ]] ; then
        break;
    elif [[ "$title" == "You have no completed recordings"* ]] ; then
        break;
    fi
    # Possible forms of title
    # Two and a Half Men (13) © Recording Now 12:00 - 12:30p
    # Two and a Half Men (13)
    # Two and a Half Men
    # Two and a Half Men © Recording Now 12:00 - 12:30p
    numepisodes=1
    title=${title% ? Recording Now *}
    if [[ "$title" =~ ^.*\([0-9]*\) ]] ; then
#        numepisodes=$(echo "$title" | sed "s/^.*(\([0-9]*\))$/\\1/")
        numepisodes=$(echo "$title" | grep -o "([0-9]*)")
        let numepisodes=numepisodes
        title="${title%(*}"
        title=${title% *}
        echo `date "+%Y-%m-%d_%H-%M-%S"` "There are $numepisodes episodes of $title."
    fi
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    waitforpage "$title"
    if (( numepisodes > 1 )) ; then
        for (( xx=0; xx<numepisodes; xx++ )) ; do
            $scriptpath/adb-sendkey.sh DOWN
        done
        $scriptpath/adb-sendkey.sh RIGHT DPAD_CENTER
    fi
    capturepage
    season_episode=`grep "^[S$][^ ]* *| *Ep[^ ]*$" $DATADIR/${recname}_capture_crop.txt | tail -1`
    season_episode=$(echo $season_episode | sed "s/|//;s/ *Ep/E/;s/\\$/S/")
    # Lowercase l should be 1
    season_episode=$(echo $season_episode | sed "s/l/1/g;s/St/S11/;s/Et/E1/;s/s/8/g")
    if [[ "$season_episode" == "" ]] ; then
        season_episode=`date "+%Y%m%d_%H%M%S"`
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Bad episode number, using $season_episode instead."
    fi
    mkdir -p "$VID_RECDIR/$title"
    recfile="$VID_RECDIR/$title/$season_episode.mkv"
    convert $DATADIR/${recname}_capture.png -gravity East -crop 25%x100% -negate -brightness-contrast 0x20 $DATADIR/${recname}_capture_details.png
    tesseract $DATADIR/${recname}_capture_details.png  - 2>/dev/null | sed '/^ *$/d' > $DATADIR/${recname}_details.txt
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Episode Details:"
    echo "*****"
    cat $DATADIR/${recname}_details.txt
    echo "*****"
    lno=`grep -n -m 1 "^Details$" $DATADIR/${recname}_details.txt`
    lno=${lno%:*}
    let lno=lno+2
    duration=`head -$lno $DATADIR/${recname}_details.txt | tail -1`
    if [[ "$duration" =~ ^[0-9]*min$ ]] ; then
        duration=${duration%min}
        let duration=duration*60
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Duration: $duration"
    else
        duration=0
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Warning: Cannot determine duration."
    fi
    xx=
    while [[ -f "$recfile" ]] ; do
        let xx++
        recfile="$VID_RECDIR/$title/${season_episode}_$xx.mkv"
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Duplicate recording file, appending _$xx"
    done
    
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Starting recording of $title/$season_episode"

    # Start Recording
   
    $scriptpath/adb-sendkey.sh DPAD_CENTER

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
    "$recfile" &

    ffmpeg_pid=$!
    starttime=`date +%s`
    sleep 10
    capturepage
    # Get past resume prompt and start over
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
        if  grep "^Start Over" $DATADIR/${recname}_capture_crop.txt ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` "Selecting Start Over from Resume Prompt"
            $scriptpath/adb-sendkey.sh DOWN DPAD_CENTER
            starttime=`date +%s`
        fi
    fi
    
    let maxendtime=starttime+maxduration
    if (( duration == 0 )) ; then
        duration=maxduration
    fi
    let endtime=starttime+duration

    filesize=0
    lowcount=0
    while true ; do
        now=`date +%s`
        if (( now > maxendtime )) ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` "Recording for too long, kill it"
            exit 2
        fi
        if ! ps -q $ffmpeg_pid >/dev/null ; then
            echo `date "+%Y-%m-%d_%H-%M-%S"` "ffmpeg is gone, exit"
            exit 2
        fi
        if (( lowcount > 0 && now > endtime )) || (( lowcount > 2 )) ; then
            kill $ffmpeg_pid
            sleep 2
            capturepage
            # Handle "Delete Recording" at end
            if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
                if grep "Delete Recording" $DATADIR/${recname}_capture_crop.txt ; then
                    echo `date "+%Y-%m-%d_%H-%M-%S"` "End of Recording - Delete"
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                    capturepage
                    xx=0
                    while ! grep "Delete Now"  $DATADIR/${recname}_capture_crop.txt ; do
                        if (( ++xx > 30 )) ; then
                            echo `date "+%Y-%m-%d_%H-%M-%S"` "ERROR Cannot get to Delete Now page"
                            exit 2
                        fi
                        capturepage
                    done
                    ques=$(grep -n "Are you sure you want to delete " $DATADIR/${recname}_capture_crop.txt)
                    lno=${ques%:*}
                    subtitle=${ques#*:Are you sure you want to delete }
                    let lno++
                    subtitle2=$(head -n $lno $DATADIR/${recname}_capture_crop.txt | tail -1)
                    if [[ "$subtitle2" =~ \?$ ]] ; then
                        subtitle=`echo $subtitle $subtitle2`
                    fi
                    subtitle=$(echo $subtitle|sed "s/ *?$//;s/- /-/;s/|/ I /g;s/  / /g")
                    # Confirm delete
                    echo `date "+%Y-%m-%d_%H-%M-%S"` "Confirm Delete"
                    $scriptpath/adb-sendkey.sh RIGHT DPAD_CENTER
                    if [[ "$subtitle" != "" ]] ; then
                        echo `date "+%Y-%m-%d_%H-%M-%S"` "Rename recording file with subtitle"
                        newrecfile="$VID_RECDIR/$title/$season_episode $subtitle.mkv"
                        while [[ -f "$newrecfile" ]] ; do
                            let xx++
                            newrecfile="$VID_RECDIR/$title/${season_episode}  ${subtitle}_$xx.mkv"
                            echo `date "+%Y-%m-%d_%H-%M-%S"` "Duplicate recording file, appending _$xx"
                        done
                        mv -n "$recfile" "$newrecfile"
                    fi
                    echo `date "+%Y-%m-%d_%H-%M-%S"` "Recording Complete of $title/$season_episode $subtitle"
                    break
                else
                    echo `date "+%Y-%m-%d_%H-%M-%S"` "Playback seems to be stuck, exiting"
                    exit 2
                fi
            else
                echo `date "+%Y-%m-%d_%H-%M-%S"` "Cannot capture screen at end of playback, exiting"
                exit 2
            fi
        fi
        sleep 60
        newsize=`stat -c %s "$recfile"`
        let diff=newsize-filesize
        filesize=$newsize
        echo `date "+%Y-%m-%d_%H-%M-%S"` "size: $filesize  Incr: $diff" >> $VID_RECDIR/${logdate}_size.log
        if (( diff < 5000000 )) ; then
            let lowcount++
            echo "*** Less than 5 MB *** lowcount=$lowcount" >> $VID_RECDIR/${logdate}_size.log
            echo `date "+%Y-%m-%d_%H-%M-%S"` "Less than 5 MB, lowcount=$lowcount"
        else
            lowcount=0
        fi
    done
    sleep 5
    capturepage
    if [[ "$pagename" != "Recordings" ]] ; then
        $scriptpath/adb-sendkey.sh BACK
    fi
    waitforpage "Recordings"
    sleep 5
    capturepage
done
echo `date "+%Y-%m-%d_%H-%M-%S"` "Complete - No more Recordings"

