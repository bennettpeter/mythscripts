#!/bin/bash

# Setup WOL (wake on lan) on the first ethernet device

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e
arr=($(nmcli c show | grep -w ethernet | head -1))
len=${#arr[@]}
let words=len-3
device=${arr[@]:0:$words}
echo device "$device"
if nmcli c show "$device" | grep 802-3-ethernet.wake-on-lan: | grep magic ; then
    echo WOL is already set
else
    nmcli c modify "$device" 802-3-ethernet.wake-on-lan magic
    nmcli c show "$device" | grep 802-3-ethernet.wake-on-lan:
fi
