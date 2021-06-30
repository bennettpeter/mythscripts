#!/usr/bin/echo This file is not executable
# Common functions used by hdmi record scripts
# This file should not be marked executable

LOGDATE='date +%Y-%m-%d_%H-%M-%S'
OCR_RESOLUTION=1280x720
updatetunetime=0
ADB_ENDKEY=
LOCKBASEDIR=/var/lock/hdmirec

function exitfunc {
    rc=$?
    echo `$LOGDATE` "Exit" >> $logfile
    if [[ "$ADB_ENDKEY" != "" && "$ANDROID_DEVICE" != "" && istunerlocked ]] ; then
        $scriptpath/adb-sendkey.sh $ADB_ENDKEY >> $logfile
    fi
    if [[ "$ffmpeg_pid" != "" ]] && ps -q $ffmpeg_pid >/dev/null ; then
        kill $ffmpeg_pid
    fi
    if [[ "$tail_pid" != "" ]] && ps -q $tail_pid >/dev/null ; then
        kill $tail_pid
    fi
    if istunerlocked ; then
        if (( updatetunetime )) ; then
            echo "tunetime=$(date +%s)" >> $tunefile
        fi
        if [[ "$ANDROID_DEVICE" != "" ]] ; then
            adb disconnect $ANDROID_DEVICE >> $logfile
        fi
        unlocktuner
    fi
}

# before calling this recname must be set
# Param 1 = number of extra attempts (1 sec each)
# 0 or blank = 1 attempt
function locktuner {
    if [[ "$recname" == "" ]] ; then return 1 ; fi
    attempts=$1
    mkdir -p $LOCKBASEDIR
    if [[ ! -w  $LOCKBASEDIR ]] ; then
        echo `$LOGDATE` "ERROR: $LOCKBASEDIR is not writable"
        exit 2
    fi
    touch $LOCKBASEDIR/$recname.pid
    while (( attempts-- >= 0 )) ; do
        if ln $LOCKBASEDIR/$recname.pid $LOCKBASEDIR/$recname.lock 2>/dev/null ; then
            # We have the lock - store the pid
            echo $$ > $LOCKBASEDIR/$recname.pid
            return 0
        else
            pid=$(cat $LOCKBASEDIR/${recname}.lock)
            # If the lock is already ours then return success
            if [[ "$pid" == $$ ]] ; then return 0 ; fi
            # If lock expired, remove it and try again
            if [[ "$pid" == "" ]] || ! ps -q "$pid" >/dev/null ; then
                rm $LOCKBASEDIR/$recname.lock
                let attempts++
            else
                if (( attempts%5 == 0 )) ; then
                    echo `$LOGDATE` "Waiting for lock on $recname"
                fi
                if (( attempts >= 0 )) ; then
                    sleep 1
                fi
            fi
        fi
    done
    return 1
}

# check if locked by us
function istunerlocked {
    if [[ "$recname" == "" ]] ; then return 1 ; fi
    pid=$(cat $LOCKBASEDIR/${recname}.lock 2>/dev/null)
    # If we locked it ourselves return true
    if [[ "$pid" == $$ ]] ; then return 0 ; fi
    return 1
}

function unlocktuner {
    if [[ "$recname" == "" ]] ; then return 1 ; fi
    pid=$(cat $LOCKBASEDIR/${recname}.lock 2>/dev/null)
    if [[ "$pid" == $$ ]] ; then
        # remove lock
        rm $LOCKBASEDIR/$recname.lock
    fi
}

# param NOREDIRECT to prevent redirection of stdout and stderr
function initialize {
    if [[ -t 1 ]] ; then
        isterminal=Y
    else
        isterminal=N
    fi
    tail_pid=
    REDIRECT=N
    logfile=$LOGDIR/${scriptname}_${recname}.log
    if [[ "$1" != NOREDIRECT ]] ; then
        REDIRECT=Y
        exec 1>>$logfile
        exec 2>&1
        if [[ $isterminal == Y ]] ; then
            tail -f $logfile >/dev/tty &
            tail_pid=$!
        fi
    fi
    echo `$LOGDATE` "Start of run ***********************"
    trap exitfunc EXIT
    true > $DATADIR/${recname}_capture_crop.txt
}

# Parameter 1 - set to PRIMARY to return with code 2 if primary device
# (ethernet) is not available.
# Return code 1 for fallback, 2 for error
function getparms {
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
        return 0
    fi
    errormsg=
    ANDROID_DEVICE=$ANDROID_MAIN
    if ! ping -c 1 $ANDROID_MAIN >/dev/null ; then
        if [[ "$ANDROID_FALLBACK" == "" ]] ; then
            errormsg="Primary network failure and no fallback"
            echo `$LOGDATE` "ERROR: $errormsg"
            return 2
        elif [[ "$1" == "PRIMARY" ]] ; then
            errormsg="Primary network failure"
            echo `$LOGDATE` "ERROR: $errormsg"
            return 2
        else
            errormsg="Using fallback network adapter"
            echo `$LOGDATE` "WARNING: $errormsg"
            ANDROID_DEVICE=$ANDROID_FALLBACK
            return 1
        fi
    fi
    export ANDROID_DEVICE
    return 0
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
#
# If playing the tuner is locked

function gettunestatus {
    if ! locktuner ; then
        echo `$LOGDATE` "ERROR - Cannot lock to get tune status"
        return 1
    fi
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
    return 0
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
        return 3
    fi
    return 0
}
