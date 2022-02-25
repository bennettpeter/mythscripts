#!/bin/bash
# Script to run when requesting suspend from the GUI.

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

if (( REBOOT_DAYS < 1 )) ; then
    REBOOT_DAYS=1
fi

s7daysago=`date --date="$REBOOT_DAYS days ago" +%F`
# priorreboot=`cat $DATADIR/reboot_date`
resp=($(who -b))
priorreboot=${resp[2]}
echo "Last reboot was $priorreboot"
vbox=`pidof VirtualBox; pidof VBoxHeadless`
if [[ "$vbox" != "" ]] ; then echo "Virtualbox is active $vbox" ]] ; fi

if pidof FreeFileSync_x86_64 ; then
    zenity --error --no-wrap --text="ERROR FreefileSync is running."
    exit 2
fi
if pidof kmymoney ; then
    zenity --error --no-wrap --text="ERROR KMyMoney is running."
    exit 2
fi

shutparm=
if [[ "$CAN_SUSPEND" == Y ]] ; then
    if [[ ( "$priorreboot" == "$s7daysago" || "$priorreboot" < "$s7daysago" ) && "$vbox" == "" ]] ; then
        zenity --question --no-wrap --timeout=15 --icon-name=dialog-warning \
         --width 1000 --height 500 \
         --text='<span font="64">WARNING - Reboot time.\n'\
'After 15 seconds this message will vanish\nand the system will stay awake.\n'\
'Select Reboot or Sleep below</span>' \
         --ok-label='Reboot' --cancel-label="Sleep"
        rc=$?
        if [[ $rc == 0 ]] ; then
            shutparm=
        elif [[ $rc == 1 ]] ; then
            shutparm=NOREBOOT
        else
            exit 2
        fi
    fi
fi

# dm-tool switch-to-greeter

# Move mouse to middle of screen
xdotool mousemove --polar 0 0
sleep 0.1

# This makes the suspend do a weekly shutdown
/opt/mythtv/bin/systemshutdown.sh $shutparm
#xrandr  --output HDMI-0 --off
#xrandr  --output eDP-1-1 --off
# sudo chvt 1
#sleep 1
#sudo systemctl suspend
#sleep 5
# sudo chvt 7
#xrandr  --output HDMI-0 --auto
#xrandr  --output eDP-1-1 --auto
