#!/usr/bin/echo This file is not executable
# Common functions used by hdmi record scripts
# This file should not be marked executable

LOGDATE='date +%Y-%m-%d_%H-%M-%S'

function exitfunc {
    rc=$?
    echo `$LOGDATE` "Exit"
    if [[ "$ADB_ENDKEY" != "" && "$ANDROID_DEVICE" != "" ]] ; then
        $scriptpath/adb-sendkey.sh $ADB_ENDKEY
    fi
    if [[ "$ffmpeg_pid" != "" ]] && ps -q $ffmpeg_pid >/dev/null ; then
        kill $ffmpeg_pid
    fi
    if [[ "$tail_pid" != "" ]] && ps -q $tail_pid >/dev/null ; then
        kill $tail_pid
    fi
    if [[ "$ANDROID_DEVICE" != "" ]] ; then
        adb disconnect $ANDROID_DEVICE
    fi
    # TODO: Check $rc and notify if not zero
}

function initialize {
    if [[ -t 1 ]] ; then
        isterminal=Y
    else
        isterminal=N
    fi
    exec 1>>$LOGDIR/${scriptname}.log
    exec 2>&1
    tail_pid=
    if [[ $isterminal == Y ]] ; then
        tail -f $LOGDIR/${scriptname}.log >/dev/tty &
        tail_pid=$!
    fi
    echo `$LOGDATE` "Start of run"
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

# Parameter 1 - set to 1 to only allow capture from /dev/video, otherwise
# it prefers adb capture.
# VIDEO_IN - set to blank will prevent capture from /dev/video
# TESSPARM - set to "-c tessedit_char_whitelist=0123456789" to restrict to numerics
function capturepage {
    pagename=
    local video_reqd=$1
    sleep 1
    cp -f $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt
    true > $DATADIR/${recname}_capture.png
    true > $DATADIR/${recname}_capture_crop.png
    true > $DATADIR/${recname}_capture_crop.txt
    if (( ! video_reqd )) ; then
        adb exec-out screencap -p > $DATADIR/${recname}_capture.png
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture.png` == 0 && "$VIDEO_IN" != "" ]] ; then
        if [[ "$ffmpeg_pid" == "" ]] || ! ps -q $ffmpeg_pid >/dev/null ; then
            ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s $RESOLUTION -i $VIDEO_IN -frames 1 $DATADIR/${recname}_capture.png
        fi
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture.png` != 0 ]] ; then
        convert $DATADIR/${recname}_capture.png -gravity East -crop 95%x100% -negate -brightness-contrast 0x20 $DATADIR/${recname}_capture_crop.png
    fi
    if [[ `stat -c %s $DATADIR/${recname}_capture_crop.png` != 0 ]] ; then
        tesseract $DATADIR/${recname}_capture_crop.png  - $TESSPARM 2>/dev/null | sed '/^ *$/d' > $DATADIR/${recname}_capture_crop.txt
        if diff -q $DATADIR/${recname}_capture_crop.txt $DATADIR/${recname}_capture_crop_prior.txt >/dev/null ; then
            echo `$LOGDATE` Same Again
        else
            echo "*****" `$LOGDATE`
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
        echo `$LOGDATE` "ERROR - Cannot get to $wanted Page"
        exit 2
    fi
    echo `$LOGDATE` "Reached $wanted page"
}
