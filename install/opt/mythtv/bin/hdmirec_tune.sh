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
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1

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
export ANDROID_DEVICE

# In case another version of adb is running
adb kill-server
sleep 0.5

tunefile=$DATADIR/${recname}_tune.stat
partialtune=N
if [[ -f $tunefile ]] ; then
    for (( xx=0; xx<6; xx++ )) ; do
    . $tunefile
        if [[ "$tunestatus" == playing ]] ; then
            sleep 0.5
        else
            break
        fi
    done
    if [[ "$tunestatus" == playing ]] ; then
        echo "$date Tuner still playing, should have stopped"
    fi
    if [[ "$tunestatus" == stopped ]] ; then
        now=$(date +%s)
        if (( tunetime > now-600 )) ; then
            echo "$date Tuner was recording recently, status $tunestatus, try partial tune"
            partialtune=Y
        fi
    fi
fi

echo "tunetime=$(date +%s)" > $tunefile
echo "tunechan=$channum" >> $tunefile
if (( channum == 1 )); then
    echo "tunestatus=dummy" >> $tunefile
    echo "$date request to tune channel $channum , ignored"
    exit 0
fi
echo "tunestatus=start" >> $tunefile
tunestatus=start

function trapfunc {
    echo "Process killed"
    echo "tunestatus=kill" >> $tunefile
    adb disconnect $ANDROID_DEVICE
    exit 2
}

trap trapfunc 1 2 3 4 5 6 15

function getpagename {
    if [[ "$1" == "" ]] ; then
        crop="240x64+62+0"
    else
        crop="$1"
    fi
    rm -f $DATADIR/${recname}_capture.jpg $DATADIR/${recname}_heading.txt
    ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.jpg
    convert $DATADIR/${recname}_capture.jpg -crop "$crop" -negate $DATADIR/${recname}_heading.jpg
    gocr -l 160 $DATADIR/${recname}_heading.jpg > $DATADIR/${recname}_heading.txt
    pagename=$(head -1 $DATADIR/${recname}_heading.txt)
}

echo "$date Start tuning channel: $channum on recorder: $recname"

if (( channum <= 0 )) ; then
    echo "ERROR Invalid channel number: $channum"
    exit 2
fi

# Partially tuned from prior recording?
if [[ "$partialtune" == Y ]] ; then
    match=N
    for (( x=0; x<6; x++ )) ; do
        getpagename
        if [[ "$pagename" == Favorite*Channels ]] ; then
            match=Y
            break
        fi
        sleep 0.5
    done
    if [[ "$match" == N ]] ; then
        partialtune=N
    fi
fi

tuned=N

for (( xx=0; xx<5; xx++ )) ; do
    adb connect $ANDROID_DEVICE
    sleep 0.5

    if [[ "$partialtune" == N ]] ; then
        # This expects xfinity to be the first application in the list
        $scriptpath/adb-sendkey.sh HOME RIGHT RIGHT RIGHT DPAD_CENTER

        # This also starts it but returns to a prior screen, not the start screen
        # So different logic will be needed
        # $scriptpath/adb-sendkey.sh HOME
        # adb shell monkey -p com.xfinity.cloudtvr.tenfoot -c android.intent.category.LAUNCHER 1

        match=N
        pagename=
        for (( x=0; x<20; x++ )) ; do
            getpagename
            if [[ "$pagename" == For*You ]] ; then
                match=Y
                break
            fi
            sleep 0.5
        done
        if [[ $match != Y ]] ; then
            echo "Failed to start XFinity For You - found $pagename - see $DATADIR/${recname}_capture.jpg"
            continue
        fi

        $scriptpath/adb-sendkey.sh MENU
        match=N
        for (( x=0; x<20; x++ )) ; do
            getpagename "240x64+62+10"
            if [[ "$pagename" == Search ]] ; then
                match=Y
                break
            fi
            sleep 0.5
        done
        if [[ $match != Y ]] ; then
            echo "Failed to launch XFinity Menu - found $pagename - see $DATADIR/${recname}_capture.jpg"
            continue
        fi

        $scriptpath/adb-sendkey.sh DOWN DOWN DOWN DOWN DOWN DOWN DPAD_CENTER
        match=N
        for (( x=0; x<20; x++ )) ; do
            getpagename
            if [[ "$pagename" == Favorite*Channels ]] ; then
                match=Y
                break
            fi
            sleep 0.5
        done
        if [[ $match != Y ]] ; then
            echo "Expected Favorite Channels but got $pagename - try again"
            continue
        fi
    fi

    # Reset partialtune for next round in case this fails
    partialtune=N

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
            continue 2
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
            break 2
        fi
        $scriptpath/adb-sendkey.sh $direction
    done
    tuned=Y
    break
done

date=`date +%F\ %T\.%N`
date=${date:0:23}
if [[ "$tuned" == Y ]] ; then
    # Start playback of channel
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    echo "tunetime=$(date +%s)" >> $tunefile
    echo "tunestatus=playing" >> $tunefile
    echo "$date Complete tuning channel: $channum on recorder: $recname"
    rc=0
else
    echo "tunestatus=fail" >> $tunefile
    echo "$date Unable to tune channel: $channum on recorder: $recname"
    rc=2
fi
adb disconnect $ANDROID_DEVICE
exit $rc
