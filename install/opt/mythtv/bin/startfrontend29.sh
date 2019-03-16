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
killall firefox
showmenu=N

if [[ "$FE_SCRIPT" == "" ]]; then
    FE_SCRIPT=mythfrontend
fi

xset s off         # don't activate screensaver
xset -dpms         # disable DPMS (Energy Star) features.
xset s noblank     # don't blank the video device

if [[ `arch` == armv* ]] ; then
    sudo $scriptpath/setgovernor.sh high
fi

if [[ "$showmenu" == Y ]] ; then
    if [[ `arch` == armv* ]] ; then
resp=$(zenity --list --column="Pick One" <<EOF
MythTV
ShowMax
Amazon Video
Freeform
AlJazeera
EOF
)
        case $resp in
        MythTV)
            $FE_SCRIPT
            ;;
        ShowMax)
            chromium-browser https://www.showmax.com/eng/
            ;;
        Amazon\ Video)
            chromium-browser https://www.amazon.com/gp/video/watchlist/ref=sv_atv_8
            ;;
        Freeform)
            chromium-browser https://freeform.go.com/
            ;;
        AlJazeera)
            chromium-browser https://www.aljazeera.com/live/
            ;;
        esac
    else
        resp=X
        xrandr -s 640x480
        sleep 1

resp=$(zenity --list --column="Pick One" <<EOF
MythTV
ShowMax
Amazon Video
Freeform
AlJazeera
EOF
)
        xrandr -s 1920x1080
        sleep 1
        case $resp in
        MythTV)
            $FE_SCRIPT
            ;;
        ShowMax)
            firefox https://www.showmax.com/eng/
            ;;
        Amazon\ Video)
            firefox https://www.amazon.com/gp/video/watchlist/ref=sv_atv_8
            ;;
        Freeform)
            firefox https://freeform.go.com/
            ;;
        AlJazeera)
            firefox https://www.aljazeera.com/live/
            ;;
        esac
    fi
else
    $FE_SCRIPT
fi
if [[ `arch` == armv* ]] ; then
    sudo $scriptpath/setgovernor.sh normal
fi

if ! systemctl is-active mythtv-monitor.service \
&& ! systemctl is-active mythtv-backend.service ; then
    s7daysago=`date --date="$REBOOT_DAYS days ago" +%F`
    priorreboot=`cat $DATADIR/reboot_date`
    if [[ "$priorreboot" = "$s7daysago" || "$priorreboot" < "$s7daysago" ]] ; then
        date +%F > $DATADIR/reboot_date
        sudo shutdown -r now
    fi
fi

if [[ `arch` == arm* ]] ; then
    killall lxsession
else
    # One of these should work !
    gnome-session-quit --no-prompt
    xfce4-session-logout --logout
fi
