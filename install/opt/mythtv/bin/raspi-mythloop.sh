#!/bin/bash
# loop, starting mythtv when needed

# prevent recursion
xpid=`pidof X`
if [[ "$xpid" != "" ]] ; then 
    echo X already running
    exit
fi

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
hostname=` tr '[a-z]' '[A-Z]' < /etc/hostname`
font=standard

# Bug in Jessie means rpcbind does not start with system restart
# It is needed for NFS

if [[ `ps -p1 -o comm --no-headers` == systemd ]] ; then
    if ! nc -z -v localhost 111 ; then
        sudo systemctl start rpcbind.service
        sleep 1
    fi
    if ! nc -z -v localhost 2049 ; then
        sudo systemctl restart nfs-kernel-server.service
    fi
fi

if (( REBOOT_DAYS < 1 )) ; then
    REBOOT_DAYS=1
fi

if [[ `tty` != /dev/tty1 ]] ; then
    while true ; do
        clear
        echo;echo
        figlet -f $font  "       $hostname"$'\n'"       Please Press"$'\n'"       Enter or OK"
        pwd=
        read -s pwd
        sudo chvt 1
    done
fi

#kodiver=`/usr/bin/kodi --version|head -1|cut -f 1 -d '.'`

while true ; do
    clear
    echo;echo
    figlet -f $font  "       $hostname"$'\n'"       22 - MythTV"$'\n'"       99 - Unplug"
    retry=Y
    pwd=
    while [[ "$retry" == Y ]] ; do
        read -s pwd
        if [[ "$pwd" == 22 ]] ; then
            $scriptpath/wakeup.sh "$MAINHOST"
            sudo $scriptpath/setgovernor.sh high
            xinit $scriptpath/startfrontend.sh
            sudo $scriptpath/setgovernor.sh normal
            break 
        fi
        if [[ "$pwd" == 99 ]] ; then 
            clear
            echo;echo
            figlet -f $font "       Shutting down"
            sleep 3
            sudo shutdown -P now
        fi
    done
    s7daysago=`date --date="$REBOOT_DAYS days ago" +%F`
    priorreboot=`cat $DATADIR/reboot_date`
    if [[ "$priorreboot" = "$s7daysago" || "$priorreboot" < "$s7daysago" ]] ; then
        date +%F > $DATADIR/reboot_date
        clear
        echo;echo
        figlet -f $font "       Restarting"
        sudo shutdown -r now
    fi
done
