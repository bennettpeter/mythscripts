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
logfile=$LOGDIR/${scriptname}_${recname}.log
exec 1>>$logfile
exec 2>&1

# Get a date/time stamp to add to log output
date=`date +%F\ %T\.%N`
date=${date:0:23}

this_pid=$$
echo "$date request to tune channel $channum pid $this_pid"
tunefile=$DATADIR/${recname}_tune.stat

function trapfunc {
    echo "Process killed"
    echo "tunestatus=kill" >> $tunefile
    adb disconnect $ANDROID_DEVICE
    exit 2
}

trap trapfunc 1 2 3 4 5 6 15

rc=99
# Check for two copies of tuning running at the same time for the
# same recorder.
retry_count=0
for (( retry_count = 0; retry_count < 120 ; retry_count++ )) ; do
    ps -ef | grep "hdmirec_tune.*\.sh $recname" | \
    while read user pid parent rest ; do
        # only wait for processes started earlier than this one.
        if (( this_pid > pid )) ; then
            echo "Warning tuner is already running, pid $pid, waiting"
            # This only exits from the while not from the script
            exit 1
        fi
    done
    # This gets the exit code from above if applicable
    rc=$?
    # No other tune script running, leave the check loop
    if (( rc == 0 )) ; then break ; fi
    sleep 1
done
date=`date +%F\ %T\.%N`
date=${date:0:23}
if (( rc != 0 )) ; then
    echo "$date ERROR waited more than 120 seconds for other tuner to end, giving up"
    echo "tunestatus=fail" >> $tunefile
    exit 2
fi


# Select the [default] section of conf and put it in a file
# to source it
awk '/^\[default\]$/ { def = 1; next }
/^\[/ { def = 0; next }
def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
> $DATADIR/etc_${recname}.conf
. $DATADIR/etc_${recname}.conf
. $DATADIR/${recname}.conf
if ping -c 1 $ANDROID_MAIN ; then
    ANDROID_DEVICE=$ANDROID_MAIN
else
    ANDROID_DEVICE=$ANDROID_FALLBACK
fi
export ANDROID_DEVICE

partialtune=N
tuned=N
if [[ -f $tunefile ]] ; then
    for (( xx=0; xx<6; xx++ )) ; do
    . $tunefile
        if [[ "$tunestatus" == playing ]] ; then
            sleep 0.5
        else
            # Not playing - leave the wait for end play loop
            break
        fi
    done
    date=`date +%F\ %T\.%N`
    date=${date:0:23}
    now=$(date +%s)
    if (( tunetime > now-120 )) ; then
        if [[ "$tunestatus" == playing  && "$tunechan" == "$channum" ]] ; then
            echo "$date Tuner already tuned, all ok"
            exit 0
        fi
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

function getpagename {
    if [[ "$1" == "" ]] ; then
        crop="240x64+62+0"
    else
        crop="$1"
    fi
    rm -f $DATADIR/${recname}_capture.$IMAGES $DATADIR/${recname}_heading.txt
    ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.$IMAGES
    convert $DATADIR/${recname}_capture.$IMAGES -crop "$crop" -negate $DATADIR/${recname}_heading.$IMAGES
    gocr -l $GRAYLEVEL $DATADIR/${recname}_heading.$IMAGES > $DATADIR/${recname}_heading.txt 2>/dev/null
    pagename=$(head -1 $DATADIR/${recname}_heading.txt)
}

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

# Loop to retry entire process up to 5 times in case of temporary failure
for (( xx=0; xx<5; xx++ )) ; do
    if [[ "$tuned" == Y ]] ; then  break; fi
    adb connect $ANDROID_DEVICE
    sleep 0.5

    if [[ "$partialtune" == N ]] ; then
        # This expects xfinity to be the first application in the list
        $scriptpath/adb-sendkey.sh HOME RIGHT RIGHT RIGHT DPAD_CENTER

        # This also starts it but returns to a prior screen, not the start screen
        # So different logic would be needed
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
            echo "Failed to start XFinity For You - found $pagename - see $DATADIR/${recname}_capture.$IMAGES"
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
            echo "Failed to launch XFinity Menu - found $pagename - see $DATADIR/${recname}_capture.$IMAGES"
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
    errorpassed=0
    while (( currchan != channum )) ; do
        for (( x=0; x<5; x++ )) ; do
            error=0
            ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.$IMAGES
            convert $DATADIR/${recname}_capture.$IMAGES -crop 86x600+208+120 -negate $DATADIR/${recname}_channels.$IMAGES
            gocr -C 0-9 -l $GRAYLEVEL $DATADIR/${recname}_channels.$IMAGES > $DATADIR/${recname}_channels.txt 2>/dev/null
            onscreen=$(cat $DATADIR/${recname}_channels.txt)
            channels=($onscreen)
            arrsize=${#channels[@]}
            echo "channels: ${channels[@]}"
            if [[ "${channels[@]}" == *_* ]] ; then
                gocr -C 0-9 -l $GRAYLEVEL2 $DATADIR/${recname}_channels.$IMAGES > $DATADIR/${recname}_channels.txt 2>/dev/null
                onscreen=$(cat $DATADIR/${recname}_channels.txt)
                channels2=($onscreen)
                echo "channels2: ${channels2[@]}"
                channels3=()
                if [[ "${channels2[@]}" == *_* ]] ; then
                    gocr -C 0-9 -l $GRAYLEVEL3 $DATADIR/${recname}_channels.$IMAGES > $DATADIR/${recname}_channels.txt 2>/dev/null
                    onscreen=$(cat $DATADIR/${recname}_channels.txt)
                    channels3=($onscreen)
                    echo "channels3: ${channels3[@]}"
                    if [[ "${channels3[@]}" != *_* ]] ; then
                        channels=(${channels3[@]})
                    fi
                else
                    channels=(${channels2[@]})
                fi
                if [[ "${channels[@]}" == *_* ]] ; then
                    for (( ix=0; ix<arrsize; ix++ )) ; do
                        if [[ "${channels[ix]}" == *_* ]] ; then
                            if [[ "${channels2[ix]}" == *_* ]] ; then
                                channels[ix]="${channels2[ix]}"
                            else
                                channels[ix]="${channels3[ix]}"
                            fi
                        fi
                    done
                fi
                echo "corrected channels: ${channels[@]}"
            fi
            arrsize=${#channels[@]}
            if [[ "${channels[@]}" == *_* ]] ; then
                echo ERROR in channels.
                error=1
            elif (( arrsize != 5 )) ; then
                echo ERROR incorrect number of entries $arrsize, should be 5
                error=1
            else
                # Get each channel on a new line in a file
                echo "${channels[@]}" | sed 's/ /\n/g' > $DATADIR/${recname}_channels.txt
                if ! sort -nc $DATADIR/${recname}_channels.txt ; then
                    echo ERROR channels out of sequence
                    error=1
                fi
            fi

            topchan=${channels[0]}
            if (( error == 0 && topchan > 0 )) ; then
                # Found channels - leave retry loop
                break
            fi
            sleep 0.5
        done
        if (( error )) ; then
            if (( errorpassed || currchan > 0 )) ; then
                echo "ERROR Bad channels - cannot fix"
                continue 2
            fi
            if (( currchan == 0 )) ; then
                echo "Warning bad channels - assume we are at end - go up and try again"
                $scriptpath/adb-sendkey.sh DOWN DOWN DOWN
                currchan=-1
            fi
            $scriptpath/adb-sendkey.sh UP
            continue
        fi
        if  (( currchan == -1 )) ; then
            errorpassed=1
        fi
        prior_currchan=$currchan
        if (( currchan == 0 )) ; then
            $scriptpath/adb-sendkey.sh DOWN DOWN DOWN
        fi
        if (( currchan <= 0 )) ; then
            currchan=${channels[1]}
        else
            currsel=0
            while (( currsel < 10 )) ; do
                if (( currchan == channels[currsel] )) ; then
                    if [[ $direction == DOWN ]] ; then
                        if (( currsel < arrsize-1 )) ; then
                            currchan=${channels[currsel+1]}
                        else
                            currchan=0
                        fi
                    elif [[ $direction == UP ]] ; then
                        if (( currsel > 0 )) ; then
                            currchan=${channels[currsel-1]}
                        else
                            currchan=0
                        fi
                    fi
                    # Found match - leave the loop
                    break;
                else
                    let currsel++
                fi
            done
        fi
        echo "Current channel: $currchan"
        if (( currchan == prior_currchan || currchan == 0 )); then
            echo "ERROR failed to select channel: $channum, using: ${channels[@]}"
            continue 2
        fi
        prior_direction=$direction
        if (( currchan < channum )) ; then
            direction=DOWN
        elif (( currchan > channum )) ; then
            direction=UP
        else
            direction=N
            tuned=Y
            # Selected the correct channel - leave the cursor up/down loop
            break
        fi
        if [[ $prior_direction != N && $prior_direction != $direction ]] ; then
            # Moving up and down indicates channel is not in the list
            echo "ERROR channel: $channum not found in favorites, using: ${channels[@]}"
            continue 2
        fi
        $scriptpath/adb-sendkey.sh $direction
    done
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
