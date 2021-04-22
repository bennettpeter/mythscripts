#!/bin/bash

# External Recorder Tuner
# Parameter 1 - recorder name
# Parameter 2 - channel number

recname=$1
channum=$2

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
logfile=$LOGDIR/${scriptname}.log
##UNCOMMENT
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1

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

echo "$date Start tuning channel: $channum on recorder: $recname"

if (( channum <= 0 )) ; then
    echo "ERROR Invalid channel number: $channum"
    exit 2
fi

export ANDROID_DEVICE
adb connect $ANDROID_DEVICE

# This expects xfinity to be the first application in the list
$scriptpath/adb-sendkey.sh HOME HOME RIGHT RIGHT RIGHT DPAD_CENTER

# This also starts it but returns to a prior screen, not the start screen
# So different logic will be needed
# $scriptpath/adb-sendkey.sh HOME
# adb shell monkey -p com.xfinity.cloudtvr.tenfoot -c android.intent.category.LAUNCHER 1

match=N
for (( x=0; x<20; x++ )) ; do
    ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.jpg
    convert $DATADIR/${recname}_capture.jpg -crop 240x64+62+0 -negate $DATADIR/${recname}_heading.jpg
    gocr -l 160 $DATADIR/${recname}_heading.jpg > $DATADIR/${recname}_heading.txt
    if [[ `head -1 $DATADIR/${recname}_heading.txt` == For*You ]] ; then
        match=Y
        break
    fi
    sleep 0.5
done
if [[ $match != Y ]] ; then
    echo "Failed to start XFinity - see $DATADIR/${recname}_capture.jpg"
    adb disconnect $ANDROID_DEVICE
    exit 2
fi
$scriptpath/adb-sendkey.sh MENU DOWN DOWN DOWN DOWN DOWN DOWN DPAD_CENTER
match=N
for (( x=0; x<20; x++ )) ; do
    ffmpeg -hide_banner -loglevel error -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.jpg
    convert $DATADIR/${recname}_capture.jpg -crop 240x64+62+0 -negate $DATADIR/${recname}_heading.jpg
    gocr -l 160 $DATADIR/${recname}_heading.jpg > $DATADIR/${recname}_heading.txt
    if [[ `head -1 $DATADIR/${recname}_heading.txt` == Favorite*Channels ]] ; then
        match=Y
        break
    fi
    sleep 0.5
done
if [[ $match != Y ]] ; then
    echo "Failed to find XFinity Favorite Channels - see $DATADIR/${recname}_capture.jpg"
    adb disconnect $ANDROID_DEVICE
    exit 2
fi

##favorites - channel numbers##
currchan=0
direction=N
while (( currchan != channum )) ; do
    for (( x=0; x<20; x++ )) ; do
        ffmpeg -hide_banner -loglevel error -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.jpg
        convert $DATADIR/${recname}_capture.jpg -crop 86x600+208+120 -negate $DATADIR/${recname}_channels.jpg
        gocr -C 0-9 -l 160 $DATADIR/${recname}_channels.jpg > $DATADIR/${recname}_channels.txt
        onscreen=($(sed s/_//g $DATADIR/${recname}_channels.txt))
        echo "Found ${onscreen[@]}"
        arrsize=${#onscreen[@]}

        ## Find channel separated by 2 newlines
        ## This applies only if using tesseract
        #currchan=$(awk '{ num++; if ($1 != "" && num > 2) { if (chan == "") chan = $1
        #  else { print chan; exit 0; } }
        #  if ($1 != "") num = 0 }' $DATADIR/${recname}_channels.txt)

        topchan=${onscreen[0]}
        if (( topchan > 0 )) ; then
            break
        fi
        sleep 0.5
    done
    prior_currchan=$currchan
    if (( currchan == 0 )) ; then
        $scriptpath/adb-sendkey.sh DOWN DOWN DOWN
        currchan=${onscreen[1]}
    else
        currsel=0
        while (( currsel < 10 )) ; do
            if (( currchan == onscreen[currsel] )) ; then
                if [[ $direction == DOWN ]] ; then
                    if (( currsel < arrsize-1 )) ; then
                        currchan=${onscreen[currsel+1]}
                    else
                        currchan=0
                    fi
                elif [[ $direction == UP ]] ; then
                    if (( currsel > 0 )) ; then
                        currchan=${onscreen[currsel-1]}
                    else
                        currchan=0
                    fi
                fi
                break;
            else
                let currsel++
            fi
        done
    fi
    echo "Current channel: $currchan"
    if (( currchan == prior_currchan || currchan == 0 )); then
        echo "ERROR failed to select channel: $channum, using: ${onscreen[@]}"
        adb disconnect $ANDROID_DEVICE
        exit 2
    fi
    prior_direction=$direction
    if (( currchan < channum )) ; then
        direction=DOWN
    elif (( currchan > channum )) ; then
        direction=UP
    else
        direction=N
        break;
    fi
    if [[ $prior_direction != N && $prior_direction != $direction ]] ; then
        # Moving up and down indicates channel is not in the list
        echo "ERROR channel: $channum not found in favorites, using: ${onscreen[@]}"
        adb disconnect $ANDROID_DEVICE
        exit 2
    fi
    $scriptpath/adb-sendkey.sh $direction
done

# Channel is now selected - start playback
##UNCOMMENT
# $scriptpath/adb-sendkey.sh DPAD_CENTER
adb disconnect $ANDROID_DEVICE

date=`date +%F\ %T\.%N`
date=${date:0:23}

echo "$date Complete tuning channel: $channum on recorder: $recname"
