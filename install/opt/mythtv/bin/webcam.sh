#!/bin/bash
# webcam into home directory - runs under catch22

date
if [[ ! -e /dev/video0 ]] ; then exit ; fi

# make today and tomorrow directories
today=`date +%F`
tomorrow=`date -d "tomorrow" +%F`
mkdir -p ~/webcam/"$today"
mkdir -p ~/webcam/"$tomorrow"

if ps -ea|grep fswebcam ; then exit ; fi 
fswebcam -r 640x480 -l 30 --jpeg 80 -b ~/webcam/%F/cam_%F_%T.jpg 

while true ; do
    # make today and tomorrow directories
    today=`date +%F`
    tomorrow=`date -d "tomorrow" +%F`
    mkdir -p ~/webcam/"$today"
    mkdir -p ~/webcam/"$tomorrow"
    # delete files 7 days old
    oldest=`date -d "4 days ago" "+%F"`
    cd ~/webcam/
    for dir in * ; do
        if [[ -d "$dir" && "$dir" > "2015-01-01" && "$dir" < "$oldest" ]] ; then
            rm -rf "$dir"
        fi
    done 
    sleep 1d
    # weekly reboot
    if [[ `date +%a` == Sat ]] ; then
        sudo shutdown -r now
    fi
done

