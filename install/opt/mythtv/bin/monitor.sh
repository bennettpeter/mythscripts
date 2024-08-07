#!/bin/bash
# This script monitors the backend log
# restarts backend if a firewire No Input in 700 msec... error occurs
# Sends email if a recording fails

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
set -x
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

while true ; do
    # note sleep 60 is not enough, it can have the same nfs count after 60 seconds.
    sleep 120
    if  $scriptpath/mythshutdown.sh ; then
        if [[ "$WAKEUPTIME" != "" ]] ; then
            # Sets wakeup to the default if one was provided
            sudo $scriptpath/setwakeup.sh 1
        fi
        # laptops must not reboot with lid closed. That causes
        # startup without any screen output, not even text mode.
        parm=
        if [[ $(hostnamectl chassis) == laptop ]] ; then
            parm=NOREBOOT
        fi
        setsid $scriptpath/systemshutdown.sh $parm || true
    fi
    if [[ "$BATTERY_CHECK" != "" ]] ; then
        if acpi -a|grep off-line ; then
            batt=$(acpi -b|grep -o [0-9]*%)
            for bat in $batt ; do
                if [[ "$bat" != "0%" ]] ; then break ; fi
            done
            bat=${bat%\%}
            if (( bat < $BATTERY_CHECK )) ; then
                echo "Battery low ${bat}%"
                rc=0
                x_users=(`who -s|egrep  " tty7 | :0 "|cut -f 1 -d ' '`)
                DISPLAY=:0 sudo -u ${x_users[0]} zenity --warning --no-wrap \
                --icon-name=dialog-warning \
                --width 1000 --height 500 --timeout=15 \
                --text='<span font="64">WARNING - BATTERY LOW.\n'"Battery level = ${bat}%</span>" \
                2>/dev/null >/dev/null || rc=$?
            fi
        fi
    fi
done
