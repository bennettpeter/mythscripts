#!/bin/bash

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

machine="$1"
set -- `grep "^$machine "  /etc/opt/mythtv/wakeup_macs.txt`
MAC="$2"

if [[ "$machine" == "" || "$MAC" == "" ]] ; then
    echo Usage: $0 machine-name
    exit 2
fi 

wakeonlan $MAC
