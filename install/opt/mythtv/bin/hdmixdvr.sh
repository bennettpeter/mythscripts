#!/bin/bash
# This will take all xfinity cloud recordings
# and record them to local files.

recname=$1

if [[ "$recname" == "" ]] ; then
    recname=hdmirec1
fi
# Maximum time for 1 recording. 6 hours.
MAXTIME=360
let maxduration=MAXTIME*60

. /etc/opt/mythtv/mythtv.conf

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/hdmifuncs.sh
ADB_ENDKEY=HOME
initialize
if ! getparms PRIMARY ; then
    exit 2
fi
ffmpeg_pid=

function getrecordings {
    navigate Recordings "DOWN"
    sleep 3
    capturepage
}

# Tuner kept locked through entire recording
if ! locktuner ; then
    echo `$LOGDATE` "ERROR Encoder $recname is already locked by another process."
    exit 2
fi
gettunestatus

if [[ "$tunestatus" != idle ]] ; then
    echo `$LOGDATE` "ERROR: Tuner in use. Status $tunestatus"
    exit 2
fi

adb connect $ANDROID_DEVICE
if ! adb devices | grep $ANDROID_DEVICE ; then
    echo `$LOGDATE` "ERROR: Unable to connect to $ANDROID_DEVICE"
    exit 2
fi
capturepage adb
rc=$?
if (( rc == 1 )) ; then exit $rc ; fi

# Kill vlc
wmctrl -c vlc
wmctrl -c obs

# Get to recordings list
getrecordings

# See if there are any recordings
retries=0
while  true ; do
    # Select First Recording
    title=$(head -3 $DATADIR/${recname}_capture_crop.txt  | tail -1)
    if [[ "$title" == "Deleted Recordings" ]] ; then
        break;
    elif [[ "$title" == "You have no completed recordings"* ]] ; then
        status=$(grep -m 1 "% Full [0-9]* Recordings" $DATADIR/${recname}_capture_crop.txt)
        if [[ "$status" != "0% Full 0 Recordings" ]] ; then
            if (( retries > 2 )) ; then
                echo `$LOGDATE` "ERROR: Inconsistent recordings page"
                exit 2
            fi
            echo `$LOGDATE` Force stop xfinity
            # This fails on old version of adb.
            adb -s $ANDROID_DEVICE shell am force-stop com.xfinity.cloudtvr.tenfoot
            let retries++
            sleep 2
            getrecordings
            continue
        else
            break
        fi
    elif [[ "$title" == "" ]] ; then
        break
    fi
    retries=0
    # Possible forms of title
    # Two and a Half Men (13) © Recording Now 12:00 - 12:30p
    # Two and a Half Men (13)
    # Two and a Half Men
    # Two and a Half Men © Recording Now 12:00 - 12:30p
    numepisodes=1
    title=${title% ? Recording Now *}
    if [[ "$title" =~ ^.*\([0-9]*\) ]] ; then
        numepisodes=$(echo "$title" | grep -o "([0-9]*)")
        let numepisodes=numepisodes
        title="${title%(*}"
        title=${title% *}
        echo `$LOGDATE` "There are $numepisodes episodes of $title."
    fi
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    waitforpage "$title"
    if (( numepisodes > 1 )) ; then
        for (( xx=0; xx<numepisodes; xx++ )) ; do
            $scriptpath/adb-sendkey.sh DOWN
        done
        $scriptpath/adb-sendkey.sh RIGHT
        $scriptpath/adb-sendkey.sh DPAD_CENTER
    fi
    sleep 1
    capturepage
    season_episode=`grep "^[S$][^ ]* *| *Ep[^ ]*$" $DATADIR/${recname}_capture_crop.txt | tail -1`
    season_episode=$(echo $season_episode | sed "s/| / /;s/ |/ /;s/ *Ep/E/;s/\\$/S/")
    # Lowercase l should be 1 and other fixes
    season_episode=$(echo $season_episode | sed "s/[liI|]/1/g;s/St/S11/;s/Et/E1/;s/s/8/g")
    if [[ "$season_episode" == "" ]] ; then
        season_episode=`date "+%Y%m%d_%H%M%S"`
        echo `$LOGDATE` "Bad episode number, using $season_episode instead."
    fi
    mkdir -p "$VID_RECDIR/$title"
    recfile="$VID_RECDIR/$title/$season_episode.mkv"
    convert $DATADIR/${recname}_capture.png -gravity East -crop 25%x100% -negate -brightness-contrast 0x20 $DATADIR/${recname}_capture_details.png
    tesseract $DATADIR/${recname}_capture_details.png  - 2>/dev/null | sed '/^ *$/d' > $DATADIR/${recname}_details.txt
    echo `$LOGDATE` "Episode Details:"
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
        echo `$LOGDATE` "Duration: $duration"
    else
        duration=0
        echo `$LOGDATE` "Warning: Cannot determine duration."
    fi
    xx=
    while [[ -f "$recfile" ]] ; do
        let xx++
        recfile="$VID_RECDIR/$title/${season_episode}_$xx.mkv"
        echo `$LOGDATE` "Duplicate recording file, appending _$xx"
    done
    
    echo `$LOGDATE` "Starting recording of $title/$season_episode"

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

    sizelog=$VID_RECDIR/$($LOGDATE)_size.log
    ffmpeg_pid=$!
    starttime=`date +%s`
    sleep 10
    capturepage adb
    # Get past resume prompt and start over
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
        if  grep "^Start Over" $DATADIR/${recname}_capture_crop.txt ; then
            echo `$LOGDATE` "Selecting Start Over from Resume Prompt"
            $scriptpath/adb-sendkey.sh DOWN
            $scriptpath/adb-sendkey.sh DPAD_CENTER
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
            echo `$LOGDATE` "Recording for too long, kill it"
            exit 2
        fi
        if ! ps -q $ffmpeg_pid >/dev/null ; then
            echo `$LOGDATE` "ffmpeg is gone, exit"
            exit 2
        fi
        if (( lowcount > 0 && now > endtime )) || (( lowcount > 2 )) ; then
            kill $ffmpeg_pid
            sleep 2
            capturepage
            # Handle "Delete Recording" at end
            if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
                if grep "Delete Recording" $DATADIR/${recname}_capture_crop.txt ; then
                    echo `$LOGDATE` "End of Recording - Delete"
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                    sleep 1
                    capturepage
                    xx=0
                    while ! grep "Delete Now"  $DATADIR/${recname}_capture_crop.txt ; do
                        if (( ++xx > 30 )) ; then
                            echo `$LOGDATE` "ERROR Cannot get to Delete Now page"
                            exit 2
                        fi
                        sleep 1
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
                    # Repair subtitle
                    subtitle=$(echo $subtitle|sed "s/ *?$//;s/- /-/;s/|/ I /g;s/  / /g")
                    # Confirm delete
                    echo `$LOGDATE` "Confirm Delete"
                    $scriptpath/adb-sendkey.sh RIGHT
                    $scriptpath/adb-sendkey.sh DPAD_CENTER
                    if [[ "$subtitle" != "" ]] ; then
                        echo `$LOGDATE` "Rename recording file with subtitle"
                        newrecfile="$VID_RECDIR/$title/$season_episode $subtitle.mkv"
                        while [[ -f "$newrecfile" ]] ; do
                            let xx++
                            newrecfile="$VID_RECDIR/$title/${season_episode}  ${subtitle}_$xx.mkv"
                            echo `$LOGDATE` "Duplicate recording file, appending _$xx"
                        done
                        mv -n "$recfile" "$newrecfile"
                    fi
                    echo `$LOGDATE` "Recording Complete of $title/$season_episode $subtitle"
                    break
                else
                    echo `$LOGDATE` "ERROR: Playback seems to be stuck, exiting"
                    exit 2
                fi
            else
                echo `$LOGDATE` "ERROR: Cannot capture screen at end of playback, exiting"
                exit 2
            fi
        fi
        sleep 60
        newsize=`stat -c %s "$recfile"`
        let diff=newsize-filesize
        filesize=$newsize
        echo `$LOGDATE` "size: $filesize  Incr: $diff" >> "$sizelog"
        if (( diff < 5000000 )) ; then
            let lowcount++
            echo "*** Less than 5 MB *** lowcount=$lowcount" >> "$sizelog"
            echo `$LOGDATE` "Less than 5 MB, lowcount=$lowcount"
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
echo `$LOGDATE` "Complete - No more Recordings"

