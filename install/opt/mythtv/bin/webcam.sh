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
nextboot=`date -d "tomorrow 3AM" +%s`
now=`date +%s`
let pause=nextboot-now
sleep $pause
# daily 3AM reboot
sudo shutdown -r now

