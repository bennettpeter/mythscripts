#!/bin/bash
# Shut down or suspend
# Runs under "mythtv" not root
# parm 1 : NOREBOOT to prevent reboot

option="$1"

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
#priorreboot=`cat $DATADIR/reboot_date`
resp=($(who -b))
priorreboot=${resp[2]}
echo "Last reboot was $priorreboot"
vbox=`pidof VirtualBox; pidof VBoxHeadless`
if [[ "$vbox" != "" ]] ; then echo "Virtualbox is active $vbox" ]] ; fi
if [[ "$CAN_SUSPEND" == Y ]] ; then
    if [[ ( "$priorreboot" == "$s7daysago" || "$priorreboot" < "$s7daysago" ) \
        && "$vbox" == "" && "$option" != NOREBOOT ]] ; then
        date +%F > $DATADIR/reboot_date
        echo "Restarting"
        sudo /sbin/shutdown -r now
        userid=$(id -u -n)
        if [[ "$userid" != mythtv && "$userid" != root ]] ; then
            pkill -KILL -u $userid
        fi
    else
        echo "Suspending"
        x_users=(`w -h -s|egrep  " tty7 | :0 "|cut -f 1 -d ' '`)
        x_user="${x_users[0]}"
        if [[ "$X11_DISABLE" != "" && "$x_user" != "" ]] ; then
            for mon in $X11_DISABLE ; do
                DISPLAY=:0 XAUTHORITY=/home/$x_user/.Xauthority sudo -u $x_user \
                    xrandr  --output $mon --off
            done
            sleep 1
        fi
        if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
            sudo systemctl suspend
        else
            sudo /usr/sbin/pm-suspend
        fi
        if [[ "$X11_DISABLE" != ""  && "$x_user" != "" ]] ; then
            sleep 5
            for mon in $X11_DISABLE ; do 
                DISPLAY=:0 XAUTHORITY=/home/$x_user/.Xauthority sudo -u $x_user \
                    xrandr  --output $mon --auto
            done
        elif [[ $X11_RESUME_ENABLE == Y && "$x_user" != "" ]] ; then
            sleep 7
            DISPLAY=:0 XAUTHORITY=/home/$x_user/.Xauthority sudo -u $x_user \
                xrandr --auto
        fi
    fi
else
    if [[ "$vbox" == "" ]] ; then
        sudo shutdown -P now
    else
        echo "No shutdown or suspend is possible"
    fi
fi

