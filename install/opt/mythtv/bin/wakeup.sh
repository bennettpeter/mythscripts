#!/bin/bash

scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

machine="$1"
opt="$2"
set -- `grep "^$machine "  /etc/opt/mythtv/wakeup_macs.txt`
MAC="$2"

if [[ "$machine" == "" || "$MAC" == "" ]] ; then
    echo Usage: $0 machine-name
    exit 2
fi 

wakeonlan $MAC

# Code for when it was not working in ubuntu 24.04

#~ hostname=`cat /etc/hostname`
#~ if [[ "$hostname" == viper || "$hostname" == proxy || "$opt" == "-o" ]] ; then
    #~ wakeonlan $MAC
#~ else
    #~ ssh -i $HOME/.ssh/id_viper_rsa peter@viper wakeonlan $MAC
#~ fi
