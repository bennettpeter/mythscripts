#!/bin/bash
# start frontend
# This is run from mythwelcome if USE_MYTHWELCOME is Y
# Otherwise runs from autostart after login
# Mounts required drive, checks lirc is running and starts frontend
# After frontend exits, logs off if not using MYTHWELCOME

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
userid=`id -nu`
exec 1>>$LOGDIR/${scriptname}_${userid}.log
exec 2>&1
date

killall mythfrontend

if [[ "$CEC_ENABLED" != 1 ]] ; then
    CEC_ENABLED=0
fi
xset s off         # don't activate screensaver
xset -dpms         # disable DPMS (Energy Star) features.
xset s noblank     # don't blank the video device

if [[ `arch` == armv* ]] ; then
    sudo $scriptpath/setgovernor.sh high
fi

mythfrontend -O libCECEnabled=$CEC_ENABLED

if [[ `arch` == armv* ]] ; then
    sudo $scriptpath/setgovernor.sh normal
fi

if [[ `arch` == arm* ]] ; then
    killall lxsession
else
    # One of these should work !
    gnome-session-quit --no-prompt
    xfce4-session-logout --logout
fi
