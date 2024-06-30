#!/bin/bash

# Setup WOL (wake on lan) on the first ethernet device

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
set -e
arr=($(nmcli c show | grep -w ethernet))
echo device "${arr[0]}"
if nmcli c show "${arr[0]}" | grep 802-3-ethernet.wake-on-lan: | grep magic ; then
	echo WOL is already set
else
	nmcli c modify "${arr[0]}" 802-3-ethernet.wake-on-lan magic
	nmcli c show "${arr[0]}" | grep 802-3-ethernet.wake-on-lan:
fi
