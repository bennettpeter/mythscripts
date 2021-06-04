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

echo `date "+%Y-%m-%d_%H-%M-%S"` Start scans

if ! ls /etc/opt/mythtv/hdmirec*.conf ; then
    echo No HDMI recorders, exiting
    exit 2
fi

reqname="$1"
if [[ "$reqname" == "" ]] ; then
    reqname=hdmirec*
fi

# In case another version of adb is running
adb kill-server
sleep 0.5

export ANDROID_DEVICE
# First renoot and set all tuners to HOME
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    echo $conffile
    if [[ "$conffile" == "/etc/opt/mythtv/hdmirec*.conf" ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Warning - No hdmi recorder found"
        exit
    fi
    recname=$(basename $conffile .conf)
    ANDROID_MAIN=
    # Select the [default] section of conf and put it in a file
    # to source it
    awk '/^\[default\]$/ { def = 1; next }
    /^\[/ { def = 0; next }
    def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
    > $DATADIR/etc_${recname}.conf
    . $DATADIR/etc_${recname}.conf
    if [[ "$ANDROID_MAIN" == "" ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "WARNING: $recname not set up - skipping"
        continue
    fi
    if ping -c 1 $ANDROID_MAIN ; then
        ANDROID_DEVICE=$ANDROID_MAIN
    else
        echo `date "+%Y-%m-%d_%H-%M-%S"` "WARNING: Ethernet failure on $recname - using wifi"
        ANDROID_DEVICE=$ANDROID_FALLBACK
    fi
    adb connect $ANDROID_DEVICE
    sleep 0.5
    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "WARNING: Device offline: $recname, skipping"
        adb disconnect $ANDROID_DEVICE
        continue
    fi
    echo `date "+%Y-%m-%d_%H-%M-%S"` "reboot: $recname"
    adb -s $ANDROID_DEVICE shell reboot
    status=
    while [[ "$status" != device ]] ; do
        sleep 5
        res=(`adb devices|grep $ANDROID_DEVICE`)
        status=${res[1]}
        echo `date "+%Y-%m-%d_%H-%M-%S"` "status: $status"
    done
    $scriptpath/adb-sendkey.sh HOME
    sleep 75
    # Get rid of message that remote is not detected
    echo `date "+%Y-%m-%d_%H-%M-%S"` "Dismiss stupid message"
    $scriptpath/adb-sendkey.sh DPAD_CENTER
    adb disconnect $ANDROID_DEVICE
done

# Invoke app and check where the result is
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    recname=$(basename $conffile .conf)
    rm -f $DATADIR/${recname}.conf
    ANDROID_MAIN=
    # Select the [default] section of conf and put it in a file
    # to source it
    awk '/^\[default\]$/ { def = 1; next }
    /^\[/ { def = 0; next }
    def == 1 { print $0 } ' /etc/opt/mythtv/$recname.conf \
    > $DATADIR/etc_${recname}.conf
    . $DATADIR/etc_${recname}.conf
    if [[ "$ANDROID_MAIN" == "" ]] ; then continue ; fi
    if ping -c 1 $ANDROID_MAIN ; then
        ANDROID_DEVICE=$ANDROID_MAIN
    else
        echo `date "+%Y-%m-%d_%H-%M-%S"` "WARNING: Ethernet failure on $recname - using wifi"
        ANDROID_DEVICE=$ANDROID_FALLBACK
    fi

    adb connect $ANDROID_DEVICE
    sleep 0.5

    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "WARNING: Device offline: $recname, skipping"
        adb disconnect $ANDROID_DEVICE
        continue
    fi

    echo `date "+%Y-%m-%d_%H-%M-%S"` "Reset recorder: $recname"

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
            rm -f $DATADIR/video${x}_capture.$IMAGES
            ffmpeg -hide_banner -loglevel error  -y -f v4l2 -s 1280x720 -i $VIDEO_IN -frames 1 $DATADIR/video${x}_capture.$IMAGES
            convert $DATADIR/video${x}_capture.$IMAGES -crop 240x64+62+0 -negate $DATADIR/video${x}_heading.$IMAGES
            gocr -l $GRAYLEVEL $DATADIR/video${x}_heading.$IMAGES > $DATADIR/video${x}_heading.txt 2>/dev/null
            if [[ `head -1 $DATADIR/video${x}_heading.txt` == For*You ]] ; then
                match=Y
                break
            fi
        done
        if [[ $match == Y ]] ; then break ; fi
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Failed to read screen on ${recname}, trying again"
        sleep 1
    done

    if [[ $match != Y ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "Failed to start XFinity on ${recname} - see $DATADIR/video*_capture.$IMAGES"
        $scriptpath/adb-sendkey.sh HOME
        adb disconnect $ANDROID_DEVICE
        continue
    fi
    # We have the video device,now get the audio device
    $scriptpath/adb-sendkey.sh HOME
    adb disconnect $ANDROID_DEVICE

    # vid_path is a string like pci-0000:00:14.0-usb-0:2.2:1.0
    vid_path=$(udevadm info --query=all --name=$VIDEO_IN|grep "ID_PATH="|sed s/^.*ID_PATH=//)
    len=${#vid_path}
    AUDIO_IN=
    vid_path=${vid_path:0:len-1}
    audiodev=$(readlink /dev/snd/by-path/${vid_path}?)
    if [[ "$audiodev" != ../controlC* ]] ; then
        echo `date "+%Y-%m-%d_%H-%M-%S"` "ERROR Failed to find audio device for $VIDEO_IN"
        continue
    fi
    AUDIO_IN="hw:"${audiodev#../controlC},0

    echo "VIDEO_IN=$VIDEO_IN" > $DATADIR/${recname}.conf
    echo "AUDIO_IN=$AUDIO_IN" >> $DATADIR/${recname}.conf
    echo `date "+%Y-%m-%d_%H-%M-%S"` Successfully created parameters in $DATADIR/${recname}.conf.
    
done

