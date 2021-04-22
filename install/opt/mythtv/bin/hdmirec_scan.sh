#!/bin/bash

# Scan External Recorder Tuners and setup devices
# Tuners must be set up with files called /etc/opt/mythtv/hdmirec*.conf
# This will set up files /var/opt/mythtv/hdmirec*.conf
# with VIDEO_IN and AUDIO_IN settings
# 

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

# First set all tuners to HOME
for conffile in /etc/opt/mythtv/hdmirec*.conf ; do
    recname=$(basename $conffile .conf)

    # Select the [default] section of conf and put it in a file
    # to source it
    awk '/^\[default\]$/ { def = 1; next }
    /^\[/ { def = 0; next }
    def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
    > $DATADIR/etc_${recname}.conf
    . $DATADIR/etc_${recname}.conf

    echo "$date Reset recorder: $recname"

    export ANDROID_DEVICE
    adb connect $ANDROID_DEVICE
    $scriptpath/adb-sendkey.sh HOME
    adb disconnect $ANDROID_DEVICE
done

# Invoke app and check where the result is
for conffile in /etc/opt/mythtv/hdmirec*.conf ; do
    recname=$(basename $conffile .conf)
    rm -f $DATADIR/${recname}.conf

    # Select the [default] section of conf and put it in a file
    # to source it
    awk '/^\[default\]$/ { def = 1; next }
    /^\[/ { def = 0; next }
    def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
    > $DATADIR/etc_${recname}.conf
    . $DATADIR/etc_${recname}.conf

    echo "$date Reset recorder: $recname"

    export ANDROID_DEVICE
    adb connect $ANDROID_DEVICE

    # This expects xfinity to be the first application in the list
    $scriptpath/adb-sendkey.sh HOME
    sleep 2
    $scriptpath/adb-sendkey.sh HOME RIGHT RIGHT RIGHT DPAD_CENTER
    sleep 2
    match=N
    for trynum in 1 2 3 4 5; do
        for (( x=0; x<20; x=x+2 )) ; do
            VIDEO_IN=/dev/video${x}
            if [[ ! -e $VIDEO_IN ]] ; then continue ; fi
            ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/video${x}_capture.jpg
            convert $DATADIR/video${x}_capture.jpg -crop 240x64+62+0 -negate $DATADIR/video${x}_heading.jpg
            gocr -l 160 $DATADIR/video${x}_heading.jpg > $DATADIR/video${x}_heading.txt
            if [[ `head -1 $DATADIR/video${x}_heading.txt` == For*You ]] ; then
                match=Y
                break
            fi
        done
        if [[ $match == Y ]] ; then break ; fi
        echo "Failed to read screen on ${recname}, trying again"
        sleep 0.5
    done

    if [[ $match != Y ]] ; then
        echo "Failed to start XFinity on ${recname} - see $DATADIR/video*_capture.jpg"
        $scriptpath/adb-sendkey.sh HOME
        adb disconnect $ANDROID_DEVICE
        continue
    fi
    # We have the video device,now get the audio device
    $scriptpath/adb-sendkey.sh HOME
    adb disconnect $ANDROID_DEVICE

    vid_path=$(udevadm info --query=all --name=$VIDEO_IN|grep "ID_PATH="|sed s/^.*ID_PATH=//)
    len=${#vid_path}
    AUDIO_IN=
    vid_path=${vid_path:0:len-1}
    results=($(pacmd list-sources | egrep "alsa_input|bus_path = \"$vid_path"))
    for (( ix=0; ix < ${#results}; ix++ )) ; do
        if [[ "${results[ix]}" == "device.bus_path" ]] ; then
            AUDIO_IN="${results[ix-1]}"
            break
        fi
    done

    if [[ "$AUDIO_IN" == "" ]] ; then
        echo "Failed to find audio device for $VIDEO_IN"
        continue
    fi
    # remove angle brackets
    AUDIO_IN=${AUDIO_IN#<}
    AUDIO_IN=${AUDIO_IN%>}

    echo "VIDEO_IN=$VIDEO_IN" > $DATADIR/${recname}.conf
    echo "AUDIO_IN=$AUDIO_IN" >> $DATADIR/${recname}.conf
    echo Successfully created parameters in $DATADIR/${recname}.conf.
    
done

