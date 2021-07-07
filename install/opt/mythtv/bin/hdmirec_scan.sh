#!/bin/bash

# Scan External Recorder Tuners and setup devices
# Tuners must be set up with files called /etc/opt/mythtv/hdmirec*.conf
# This will create files /var/opt/mythtv/hdmirec*.conf
# with VIDEO_IN and AUDIO_IN settings
# 

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

source $scriptpath/hdmifuncs.sh

initialize

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

# First set all tuners to HOME
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    echo $conffile found
    if [[ "$conffile" == "/etc/opt/mythtv/hdmirec*.conf" ]] ; then
        echo `$LOGDATE` "Warning - No hdmi recorder found"
        exit
    fi
    recname=$(basename $conffile .conf)

    if ! locktuner 60 ; then
        echo `$LOGDATE` "ERROR Encoder $recname is already locked - abort."
        exit 2
    fi

    tunefile=$DATADIR/${recname}_tune.stat
    # Clear status and locks
    true > $tunefile

    getparms
    rc=$?
    if [[ "$ANDROID_DEVICE" == "" ]] ; then
        continue
    fi
    if (( rc == 1 )) ; then
        $scriptpath/notify.py "Fire Stick Problem" \
          "hdmirec_scan: Primary network adapter for $recname failed" &
    fi
    adb connect $ANDROID_DEVICE
    sleep 0.5
    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `$LOGDATE` "WARNING: Device offline: $recname, skipping"
        $scriptpath/notify.py "Fire Stick Problem" \
          "hdmirec_scan: Device offline: $recname" &
        adb disconnect $ANDROID_DEVICE
        continue
    fi
    $scriptpath/adb-sendkey.sh HOME
    adb disconnect $ANDROID_DEVICE
done

# Invoke app and check where the result is
for conffile in /etc/opt/mythtv/$reqname.conf ; do
    recname=$(basename $conffile .conf)
    true > $DATADIR/${recname}.conf
    getparms
    if [[ "$ANDROID_DEVICE" == "" ]] ; then
        continue
    fi
    adb connect $ANDROID_DEVICE
    sleep 0.5

    res=(`adb devices|grep $ANDROID_DEVICE`)
    status=${res[1]}
    if [[ "$status" != device ]] ; then
        echo `$LOGDATE` "WARNING: Device offline: $recname, skipping"
        adb disconnect $ANDROID_DEVICE
        continue
    fi

    echo `$LOGDATE` "Reset recorder: $recname"
    launchXfinity
    sleep 2
    match=N
    for trynum in 1 2 3 4 5; do
        for (( x=0; x<20; x=x+2 )) ; do
            VIDEO_IN=/dev/video${x}
            if [[ ! -e $VIDEO_IN ]] ; then continue ; fi
            echo `$LOGDATE` "Trying: $VIDEO_IN"
            capturepage video
            if [[ "$pagename" == "For You" ]] ; then
                match=Y
                break
            fi
            sleep 1
        done
        if [[ $match == Y ]] ; then break ; fi
        echo `$LOGDATE` "Failed to read screen on ${recname}, trying again"
        sleep 1
    done

    if [[ $match != Y ]] ; then
        echo `$LOGDATE` "Failed to start XFinity on ${recname} - see $DATADIR/${recname}_capture.png"
        $scriptpath/notify.py "Fire Stick Problem" \
          "hdmirec_scan: Failed to start XFinity on ${recname}" &
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
        echo `$LOGDATE` "ERROR Failed to find audio device for $VIDEO_IN"
        continue
    fi
    AUDIO_IN="hw:"${audiodev#../controlC},0

    echo "VIDEO_IN=$VIDEO_IN" > $DATADIR/${recname}.conf
    echo "AUDIO_IN=$AUDIO_IN" >> $DATADIR/${recname}.conf
    echo `$LOGDATE` Successfully created parameters in $DATADIR/${recname}.conf.
    
done

