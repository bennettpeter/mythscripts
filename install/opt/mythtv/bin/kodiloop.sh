#!/bin/bash
# loop, starting kodi when needed

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
hostname=` tr '[a-z]' '[A-Z]' < /etc/hostname`
font=standard

# Bug in Jessie means rpcbind does not start with system restart
# It is needed for NFS
if ! nc -z -v localhost 111 ; then
    sudo service rpcbind start
    sleep 1
    sudo service nfs-kernel-server restart
fi

if (( REBOOT_DAYS < 1 )) ; then
    REBOOT_DAYS=1
fi

if [[ `tty` != /dev/tty1 ]] ; then
    while true ; do
        clear
        figlet -f $font  "   $hostname"$'\n'"   Please Press"$'\n'"   Enter or OK"
        pwd=
        read -s pwd
        sudo chvt 1
    done
fi

kodiver=`/usr/bin/kodi --version|head -1|cut -f 1 -d '.'`

while true ; do
    clear
    figlet -f $font  "   $hostname - $kodiver"$'\n'"   22 - TV"$'\n'"   33 - Videos"$'\n'"   99 - Disconnect"
    retry=Y
    pwd=
    while [[ "$retry" == Y ]] ; do
        read -s pwd
        if [[ "$pwd" == 22 ]] ; then
            $scriptpath/wakeup.sh "$MAINHOST"
            cp -f ~/.kodi/peter$kodiver/guisettings_pvrenabled.xml ~/.kodi/userdata/guisettings.xml
            break 
        fi
        if [[ "$pwd" == 33 ]] ; then
            cp -f ~/.kodi/peter$kodiver/guisettings_pvrdisabled.xml ~/.kodi/userdata/guisettings.xml
            break 
        fi
        if [[ "$pwd" == 99 ]] ; then 
            clear
            figlet -f $font "   Shutting down"
            sleep 3
            sudo shutdown -h now
        fi
    done
    clear
    echo;echo;echo;echo;echo
    # figlet -f $font "   Starting Kodi."
    LOG_FILE=$HOME/.kodi/temp/kodi.log
    rm -f $LOG_FILE.1
    mv -f $LOG_FILE $LOG_FILE.1
    rm -f $LOG_FILE 
    /usr/lib/kodi/kodi.bin --standalone &
    while [[ ! -f $LOG_FILE ]] ; do
    sleep 1s
    done
    while read line ; do
    if [[ ${line} =~ "application stopped" ]] ; then
    echo "Killing kodi"
    break
    fi
    done < <(tail --pid=`pidof -s /usr/lib/kodi/kodi.bin` -f -n0 $LOG_FILE)
    killall kodi.bin
    fbset -depth 8 && fbset -depth 16
    s7daysago=`date --date="$REBOOT_DAYS days ago" +%F`
    priorreboot=`cat $DATADIR/reboot_date`
    if [[ "$priorreboot" = "$s7daysago" || "$priorreboot" < "$s7daysago" ]] ; then
        date +%F > $DATADIR/reboot_date
        clear
        figlet -f $font "   Restarting"
        sudo shutdown -r now
    fi
done
