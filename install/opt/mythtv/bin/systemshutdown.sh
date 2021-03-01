#!/bin/bash
# Shut down or suspend
# Runs under "mythtv" not root

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
priorreboot=`cat $DATADIR/reboot_date`
echo "Last reboot was $priorreboot"
vbox=`pidof VirtualBox; pidof VBoxHeadless`
if [[ "$vbox" != "" ]] ; then echo "Virtualbox is active $vbox" ]] ; fi
if [[ "$CAN_SUSPEND" == Y || "$ALWAYS_ON" == Y ]] ; then
    if [[ ( "$priorreboot" == "$s7daysago" || "$priorreboot" < "$s7daysago" ) && "$vbox" == "" ]] ; then
        date +%F > $DATADIR/reboot_date
        echo "Restarting"
        sudo /sbin/shutdown -r now
    elif [[ "$CAN_SUSPEND" == Y ]] ; then
        echo "Suspending"
        if [[ "$X11_DISABLE" != "" ]] ; then
            for mon in $X11_DISABLE ; do 
                xrandr  --output $mon --off
            done
            sleep 1
        fi
        if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
            sudo systemctl suspend
        else
            sudo /usr/sbin/pm-suspend
        fi
        if [[ "$X11_DISABLE" != "" ]] ; then
            sleep 5
            for mon in $X11_DISABLE ; do 
                xrandr  --output $mon --auto
            done
        fi
    fi
else
    if [[ "$vbox" == "" ]] ; then
        sudo shutdown -P now
    else
        echo "No shutdown or suspend is possible"
    fi
fi

