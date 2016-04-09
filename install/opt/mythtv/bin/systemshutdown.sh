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
if [[ "$CAN_SUSPEND" == Y ]] ; then
    if [[ ( "$priorreboot" == "$s7daysago" || "$priorreboot" < "$s7daysago" ) && "$vbox" == "" ]] ; then
        date +%F > $DATADIR/reboot_date
        echo "Restarting"
        sudo /sbin/shutdown -r now
    else
#        if [[ "$REBOOT_BEFORE_SUSPEND" == Y ]] ; then
#            who -b
#            set -- `who -b`
#            lastboot="$3 $4"
#            if [[ "$lastboot" < `date --date="15 minutes ago" "+%F %H:%M"` ]] ; then
#                echo "Booted more than 15 minutes ago - Restart now"
#                sudo /sbin/shutdown -r now
#                exit
#            fi
#        fi
        echo "Suspending"
        if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
            sudo systemctl suspend
        else
            sudo /usr/sbin/pm-suspend
        fi
    fi
else
    if [[ "$vbox" == "" ]] ; then
        sudo shutdown -P now
    else
        echo "No shutdown or suspend is possible"
    fi
fi

