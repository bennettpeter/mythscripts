#!/bin/bash
# This script monitors the backend log
# restarts backend if a firewire No Input in 700 msec... error occurs
# Sends email if a recording fails

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

if  "$IS_BACKEND"  ; then

    logfile=/var/log/mythtv/mythbackend.log
    # These errors are monitored:
    # 2011-10-19 02:00:01.067 Updating status for Flashpoint:Grounded on cardid 3 (Tuning => Recorder Failed)
    # 2011-10-09 11:00:00.857 Updating status for "Shake It Up!":"Shrink It Up" on cardid 7 (Recording => Recorder Failed)
    # 2011-11-10 10:19:00.575 Updating status for "Hawaii Five-0":"Thu Nov 10 09:04:00 2011" on cardid 7 (Recording => Recorder Failed)
    # 2011-10-09 19:12:34.361 LFireDev(00169204EBAE0000), Warning: No Input in 700 msec...
    # With 0.25 messages look like this
    # Apr 29 12:09:35 panther-ux mythbackend[19049]: W LinuxController linuxfirewiredevice.cpp:646 (run) LFireDev(00169204EBAE0000): No Input in 250 msec...
    # Apr 29 12:09:35 panther-ux mythbackend[19049]: W LinuxController linuxfirewiredevice.cpp:646 (run) LFireDev(00169204EBAE0000): No Input in 300 msec...

    tail -f $logfile -n 0 | (
        while true ; do
            read msg
            if [[ "$msg" == *'Recorder Failed'* ]] ; then
                "$scriptpath/notify.py" "Recorder Failed" "$msg"
            fi
            if [[ "$msg" == *'No space left on the device for file'* ]] ; then
                now=`date "+%s"`
                if (( now - lastspaceerr > 1800 )) ; then
                    "$scriptpath/notify.py" "No Space" "$msg"
                fi
                lastspaceerr=$now
            fi
            if [[ "$msg" == *'Could not find channel'* ]] ; then
                now=`date "+%s"`
                if (( now - lastcherr > 1800 )) ; then
                "$scriptpath/notify.py" "Could not find Channel" "$msg"
                fi
                lastcherr=$now
            fi
            if [[ "$msg" == *' Firewire No Input Error '* ]] ; then
               "$scriptpath/notify.py" "Firewire No Input Error" "$msg"
            fi
            if [[ "$msg" == *'No Input in 700 msec...'* ]] ; then
                echo "$msg"
                now=`date "+%s"`
                if (( now - lastrestart > 1800 )) ; then
                    if (( now - lastnoinput < 4 )) ; then
                        let hits=hits+1
                        if (( hits > 2 )) ; then
                            # echo "Restarting back end because of No Input in 700 msec 3 times"
                            echo set log level to err
                            mythbackend --setloglevel err
                            # sudo restart mythtv-backend || echo "Restart failed"
                            lastrestart=$now
                            "$scriptpath/notify.py" "Firewire Glitch" "$msg"
                            hits=0
                        fi
                    else
                        hits=1
                    fi
                    lastnoinput=$now
                fi
            fi
        done
    )
else
    # For non backend
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
fi
