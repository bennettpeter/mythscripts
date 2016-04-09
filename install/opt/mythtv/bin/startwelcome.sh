#!/bin/bash
# start mythwelcome
# This si started from Gnome startup programs
# To allow login without mythwelcome starting set 
# USE_MYTHWELCOME to N in /etc/opt/mythtv/mythtv.conf

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`

. $scriptpath/getconfig.sh


if [[ "$DISPLAY" != "" ]] ; then
    if [[ "$USE_MYTHWELCOME" == Y  ]] ; then
        mythwelcome &
    else
        $scriptpath/startfrontend.sh &
    fi
fi
