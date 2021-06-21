#!/usr/bin/echo This file is not executable
# Common functions used by hdmi record scripts
# This file should not be marked executable

LOGDATE='date +%Y-%m-%d_%H-%M-%S'
OCR_RESOLUTION=1280x720
cleartunestatus=0
ADB_ENDKEY=

function exitfunc {
    rc=$?
    exec 1>&2
    # use &2 here because if ffmpeg was runnning then &1 was redirected
    echo `$LOGDATE` "Exit"
    if [[ "$ADB_ENDKEY" != "" && "$ANDROID_DEVICE" != "" && "$LOCKDIR" != "" ]] ; then
        $scriptpath/adb-sendkey.sh $ADB_ENDKEY
    fi
    if [[ "$ffmpeg_pid" != "" ]] && ps -q $ffmpeg_pid >/dev/null ; then
        kill $ffmpeg_pid
    fi
    if [[ "$tail_pid" != "" ]] && ps -q $tail_pid >/dev/null ; then
        kill $tail_pid
    fi
    if [[ "$LOCKDIR" != "" ]] ; then
        if [[ "$ANDROID_DEVICE" != "" ]] ; then
            adb disconnect $ANDROID_DEVICE
        fi
        rmdir $LOCKDIR
    fi
    if (( cleartunestatus )) ; then
        true > $tunefile
    fi

    # TODO: Check $rc and notify if not zero
}

function initialize {
    if [[ -t 1 ]] ; then
        isterminal=Y
    else
        isterminal=N
    fi
    exec 2>>$LOGDIR/${scriptname}.log
    exec 1>&2
    tail_pid=
    if [[ $isterminal == Y ]] ; then
        tail -f $LOGDIR/${scriptname}.log >/dev/tty &
        tail_pid=$!
    fi
    echo `$LOGDATE` "Start of run ***********************"
    trap exitfunc EXIT
    true > $DATADIR/${recname}_capture_crop.txt
}

# Parameter 1 - set to 1 to exit with an error if primary device
# (ethernet) is not available.
function getparms {
    local eth_reqd=$1
    # Select the [default] section of conf and put it in a file
    # to source it
    ANDROID_MAIN=
    ANDROID_DEVICE=
    awk '/^\[default\]$/ { def = 1; next }
    /^\[/ { def = 0; next }
    def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
    > $DATADIR/etc_${recname}.conf
    . $DATADIR/etc_${recname}.conf
    # This sets VIDEO_IN and AUDIO_IN
    . $DATADIR/${recname}.conf
        if [[ "$ANDROID_MAIN" == "" ]] ; then
        echo `$LOGDATE` "WARNING: $recname not set up"
        return
    fi

    if ping -c 1 $ANDROID_MAIN ; then
        ANDROID_DEVICE=$ANDROID_MAIN
    else
        if [[ "$ANDROID_FALLBACK" == "" ]] ; then
            echo `$LOGDATE` "ERROR: Primary network failure and no fallback"
            exit 2
        elif (( eth_reqd )) ; then
            echo `$LOGDATE` "ERROR: Primary network failure"
            exit 2
        else
            ANDROID_DEVICE=$ANDROID_FALLBACK
        fi
    fi
    export ANDROID_DEVICE
}

# Parameter 1 - set to video to only allow capture from /dev/video.
# Set to adb to only allow adb. Blank to try video first then adb
# VIDEO_IN - set to blank will prevent capture from /dev/video
# TESSPARM - set to "-c tessedit_char_whitelist=0123456789" to restrict to numerics
# CROP - crop parameter (default -gravity East -crop 95%x100%)
function capturepage {
    pagename=
    local source_req=$1
    sleep 1
    if [[ "$CROP" == "" ]] ; then
        CROP="-gravity East -crop 95%x100%"
    fi
    #~ if [[ "$TESSPARM" == "" ]] ; then
        #~ TESSPARM="-c tessedit_char_whitelist=0123456789QWERTYUIOPASDFGHJKLZXCVBNMqwertyuiopasdfghjklzxcvbnm "
    #~ fi
    cp -f $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt
    true > $DATADIR/${recname}_capture.png
    true > $DATADIR/${recname}_capture_crop.png
    true > $DATADIR/${recname}_capture_crop.txt
    cap_source=
    if ( [[ "$source_req" == "" || "$source_req" == video  ]] ) \
      && ( [[ "$ffmpeg_pid" == "" ]] || ! ps -q $ffmpeg_pid >/dev/null ) \
      && [[ "$VIDEO_IN" != "" ]] ; then
        ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s $OCR_RESOLUTION -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.png
        cap_source=ffmpeg
    fi
    imagesize=$(stat -c %s $DATADIR/${recname}_capture.png)
    if (( imagesize == 0 )) ; then
        if [[ "$source_req" == "" || "$source_req" == adb  ]] ; then
            adb exec-out screencap -p > $DATADIR/${recname}_capture.png
            cap_source=adb
            imagesize=$(stat -c %s $DATADIR/${recname}_capture.png)
        fi
    fi
    if (( imagesize > 0 )) ; then
        resolution=$(identify -format %wx%h $DATADIR/${recname}_capture.png)
        if [[ "$resolution" != "$OCR_RESOLUTION" ]] ; then
            echo `$LOGDATE` "WARNING Incorrect resolution $resolution"
            convert $DATADIR/${recname}_capture.png -resize "$OCR_RESOLUTION" $DATADIR/${recname}_capturex.png
            cp -f $DATADIR/${recname}_capturex.png $DATADIR/${recname}_capture.png
            imagesize=$(stat -c %s $DATADIR/${recname}_capture.png)
        fi
    fi
    if (( imagesize > 0 )) ; then
        convert $DATADIR/${recname}_capture.png $CROP -negate -brightness-contrast 0x20 $DATADIR/${recname}_capture_crop.png
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
        tesseract -c page_separator="" $DATADIR/${recname}_capture_crop.png  - $TESSPARM 2>/dev/null | sed '/^ *$/d' > $DATADIR/${recname}_capture_crop.txt
        if diff -q $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt >/dev/null ; then
            echo `$LOGDATE` Same Screen Again
        else
            echo "*****" `$LOGDATE` Screen from $cap_source
            cat $DATADIR/${recname}_capture_crop.txt
            echo "*****"
        fi
        pagename=$(head -n 1 $DATADIR/${recname}_capture_crop.txt)
    fi
    TESSPARM=
    CROP=
}

function waitforpage {
    wanted="$1"
    xx=0
    while [[ "$pagename" != "$wanted" ]] && (( xx++ < 90 )) ; do
        capturepage
    done
    if [[ "$pagename" != "$wanted" ]] ; then
        echo `$LOGDATE` "ERROR - Cannot get to $wanted Page"
        exit 2
    fi
    echo `$LOGDATE` "Reached $wanted page"
}

# tunestatus values
# idle (default if blank)
# tuned
# playing
#
# If playing the tuner is locked

function gettunestatus {
    tunefile=$DATADIR/${recname}_tune.stat
    touch $tunefile
    # Default tunestatus
    tunestatus=idle
    tunetime=0
    source $tunefile
    now=$(date +%s)

    # Tuned more than 5 minutes ago and not playing - reset tunestatus
    if (( tunetime < now-300 )) && [[ "$tunestatus" == tuned ]] ; then
        echo `$LOGDATE` Tuner $recname expired, resetting
        tunestatus=idle
        true > $tunefile
    fi
}

# Navigate to the favorite channels
function getfavorites {
    sleep 0.5
    # use MENU MENU to keep awake
    $scriptpath/adb-sendkey.sh MENU MENU
    for (( xx=0 ; xx < 20 ; xx++ )) ; do
        sleep 1
        capturepage
        # If blank the only thing that works is HOME
        if [[ "$pagename" == "" ]] ; then
            $scriptpath/adb-sendkey.sh HOME HOME
        elif [[ "$pagename" == "We can't detect your remote" ]] ; then
            $scriptpath/adb-sendkey.sh DPAD_CENTER
        elif [[ "$pagename" == "For You" ]] ; then
            $scriptpath/adb-sendkey.sh MENU
        elif [[ "$pagename" == "Search" ]] ; then
            $scriptpath/adb-sendkey.sh DOWN DOWN DOWN DOWN DOWN DOWN DPAD_CENTER
        elif [[ "$pagename" == "Favorite Channels" ]] ; then
            break
        else
            # This expects xfinity to be the first application in the list
            $scriptpath/adb-sendkey.sh HOME RIGHT RIGHT RIGHT DPAD_CENTER
        fi
    done
    if [[ "$pagename" != "Favorite Channels" ]] ; then
        echo `$LOGDATE` "ERROR: Unable to reach Favorite Channels: $recname."
    fi
}
