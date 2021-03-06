#!/bin/bash

# External Recorder Tuner
# Parameter 1 - recorder name
# Parameter 2 - channel number
# Parameter 3 - LOCK or NOLOCK, default is LOCK

recname=$1
channum=$2
lockreq=$3
if [[ "$lockreq" != NOLOCK ]] ; then
    lockreq=LOCK
fi

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/hdmifuncs.sh

initialize

getparms

echo `$LOGDATE` "Request to tune channel $channum "

# tunestatus values
# idle
# tuned

if [[ "$lockreq" == LOCK ]] ; then
    if ! locktuner 120 ; then
        echo `$LOGDATE` "Encoder $recname is locked, exiting"
        exit 2
    fi
    gettunestatus
    if [[ "$tunestatus" == tuned  ]] ; then
        if [[ "$tunechan" == "$channum" ]] ; then
            echo `$LOGDATE` "Tuner already tuned, all ok"
            exit 0
        else
            echo `$LOGDATE` "WARNING tuner already tuned to $tunechan, will retune"
            capturepage
            if [[ "$pagename" != "Favorite Channels" ]] ; then
                adb connect $ANDROID_DEVICE
                $scriptpath/adb-sendkey.sh BACK
                sleep 3
            fi
        fi
    fi
fi

tuned=N
if (( channum <= 0 )) ; then
    echo `$LOGDATE` "ERROR Invalid channel number: $channum"
    exit 2
fi

tunefile=$DATADIR/${recname}_tune.stat
true > $tunefile

adb connect $ANDROID_DEVICE

hdmichans=($(cat /etc/opt/mythtv/hdmichans.txt))
for (( xx=0; xx<5; xx++ )) ; do
    if [[ "$tuned" == Y ]] ; then  break; fi

    navigate "Favorite Channels" "DOWN DOWN DOWN DOWN DOWN DOWN"
    ##favorites - channel numbers##
    currchan=0
    direction=N
    errorpassed=0
    while (( currchan != channum )) ; do
        # Note this assumes a 1280-x720 resolution
        CROP="-crop 86x600+208+120"
        TESSPARM="-c tessedit_char_whitelist=0123456789"
        capturepage
        onscreen=$(cat $DATADIR/${recname}_capture_crop.txt)
        channels=($onscreen)
        arrsize=${#channels[@]}
        if (( arrsize != 5 )) ; then
            channels=($(gocr -C 0-9 -l 200 $DATADIR/${recname}_capture_crop.png))
            arrsize=${#channels[@]}
        fi
        if (( arrsize != 5 )) ; then
            echo `$LOGDATE` "Wrong number of channels, trying again"
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh MENU
            continue 2
        fi
        echo `$LOGDATE` "channels: ${channels[@]}"

        # Repair OCR errors.
        # This works OK if there are more channels in the hdmichans list than
        # in the xfinity favorites. Not so well if there are extra channels in the
        # favorites. Bad if there are multiple sequential errors.

        echo ${channels[@]} | sed 's/ /\n/g' > $DATADIR/${recname}_channels.txt
        mapfile -t diffs < \
        <(diff -y $DATADIR/${recname}_channels.txt /etc/opt/mythtv/hdmichans.txt)
        diffnum=0
        for diff in "${diffs[@]}" ; do
            split=($diff)
            if [[ "${split[0]}" == ">" ]] ; then
                # Possible missing channel in favorites
                if (( split[1] > channels[0] && split[1] < channels[arrsize-1] )) ; then
                    echo "WARNING channel ${split[1]} missing in favorites"
                fi
            elif [[ "${split[1]}" == "<" ]] ; then
                echo "WARNING channel ${split[0]} missing in hdmichans.txt"
            elif [[ "${split[1]}" == "|" ]] ; then
                if (( diffnum == 0 )) ; then
                    # an error in ocr of the first channel is not handled correctly
                    # by diff - set first channel to the one before second channel
                    # in hdmichans if possible
                    for (( ix=1; ix<${#hdmichans[@]}; ix++ )) ; do
                        if (( hdmichans[ix] == channels[1] )) ; then
                            first=${channels[0]}
                            channels[0]=${hdmichans[ix-1]}
                            echo "INFO Channel $first changed to ${channels[0]}"
                            break
                        fi
                    done
                else
                    fix=$(echo " ${channels[@]} " | sed "s/ ${split[0]} / ${split[2]} /")
                    echo "INFO Channel ${split[0]} changed to ${split[2]}"
                    channels=($fix)
                fi
                echo `$LOGDATE` "Fixed channels ${channels[@]}"
            fi
            let diffnum++
        done

        topchan=${channels[0]}
        prior_currchan=$currchan
        if (( currchan == 0 )) ; then
            $scriptpath/adb-sendkey.sh DOWN DOWN DOWN
            CROP="-crop 86x600+208+120"
            TESSPARM="-c tessedit_char_whitelist=0123456789"
            capturepage
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
        echo `$LOGDATE` "Current channel: $currchan"
        getselection
        selchan=0
        if [[ "$selection" != "" ]] && (( selection >= 0 )) ; then
            selchan=${channels[selection]}
        fi
        echo `$LOGDATE` "Selection: $selection -> $selchan"
        if [[ "$selchan" != "$currchan" ]] ; then
            echo `$LOGDATE` "ERROR: Incorrect channel selection"
        fi
        # Note selection is -1 if a program is selected rather than a channel
        if (( currchan == prior_currchan || currchan == 0 || selection == -1 )); then
            echo `$LOGDATE` "ERROR failed to select channel: $channum, using: ${channels[@]}"
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh MENU
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
            echo `$LOGDATE` "ERROR channel: $channum not found in favorites, using: ${channels[@]}"
            $scriptpath/adb-sendkey.sh MENU
            $scriptpath/adb-sendkey.sh MENU
            continue 2
        fi
        $scriptpath/adb-sendkey.sh $direction
    done
done

if [[ "$tuned" == Y ]] ; then
    echo "tunetime=$(date +%s)" > $tunefile
    echo "tunechan=$channum" >> $tunefile
    echo "tunestatus=tuned" >> $tunefile
    echo `$LOGDATE` "Complete tuning channel: $channum on recorder: $recname"
    # Start playback
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    rc=0
else
    true > $tunefile
    echo `$LOGDATE` "ERROR: Unable to tune channel: $channum on recorder: $recname"
    $scriptpath/notify.py "Unable to Tune" \
        "hdmirec_tune: Unable to tune channel: $channum on recorder: $recname" &
    rc=2
fi
exit $rc
