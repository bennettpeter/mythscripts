#!/bin/bash
# Options - 1 mount or umount or browse 
# browse = mount and then browse with frontend

REQUEST=$1

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
userid=`id -nu`
logfile=$LOGDIR/${scriptname}_${userid}.log
exec 1>>$logfile
exec 2>&1
date

. $scriptpath/getconfig.sh

if [[ "$VIDEOHOST" == "" ]] ; then
    exit
fi

hostname=`cat /etc/hostname`
textsize=70000
if [[ `arch` == arm* ]] ; then 
    textsize=25000
fi

case $REQUEST in 
mount|browse)
    (
        echo 1
        sleep 1
        counter=1
        for dir in $MOUNTDIR ; do
            for (( ; counter<100; counter+=4 )) ; do
                if [[ $hostname != $VIDEOHOST ]] ; then 
                    $scriptpath/wakeup.sh "$VIDEOHOST" 
                fi
                echo $counter
#                if [[ $hostname != $VIDEOHOST ]] ; then 
                if [[ $hostname == $MAINHOST ]] ; then 
                    mount $dir 1>>$logfile 2>&1 || true
                fi
#                if [[ `echo $dir/*` != "$dir/*" ]] ; then
                if nc -z -v $VIDEOHOST 2049 ; then
                    if [[ $hostname != $MAINHOST  && $VIDEOHOST != $MAINHOST  ]] ; then
                        ssh $MAINHOST "mount $dir" 1>>$logfile 2>&1 || true
                        ssh $MAINHOST "mythutil --scanvideos" 1>>$logfile 2>&1 || true
                    elif [[ $hostname == $MAINHOST ]] ; then
                        mythutil --scanvideos 1>>$logfile 2>&1 || true
                    fi
                    break;
                fi
                sleep 4
            done
        done
        echo 99
        # removed --pulsate 
    ) |  zenity --progress --no-cancel --text="<span size=\"$textsize\">Waiting for Video Mount.</span>" --auto-close --title "Please be patient"
#   for dir in $MOUNTDIR ; do
#       if [[ -d "$dir/keepalive" ]] ; then
#           # For some reason I dont understand, this echo takes one and a half minutes
#           # During that time even listing the keepalive directory hangs for one and a half minutes
#           # hence the while and &
#           (
#               sleep 1
#               if [[ $hostname != $VIDEOHOST ]] ; then 
#                   echo "$hostname" > "$dir/keepalive/$hostname" 
#               fi
#               if [[ $hostname != $MAINHOST && $VIDEOHOST != $MAINHOST ]] ; then
#                   echo "$MAINHOST" > "$dir/keepalive/$MAINHOST" 
#               fi
#           ) & 
#       fi
#   done
    if [[ "$REQUEST" == browse ]] ; then
        # jump points are videobrowser videogallery videolistings videomanager
        set -- `hostname -I`
        ipaddress=$1
        (echo "jump videolistings"| netcat $ipaddress 6546) &  
    fi
    ;;
umount)
    if ping -c 1 $VIDEOHOST ; then
        if [[ "$MOUNTDIR" != "" ]] ; then
            for dir in $MOUNTDIR ; do
#                rm -f "$dir/keepalive/$hostname"
#                if [[ $hostname != $MAINHOST && $VIDEOHOST != $MAINHOST ]] ; then
#                    rm -f "$dir/keepalive/$MAINHOST"
#                fi
#                if [[ $hostname != $VIDEOHOST ]] ; then 
                if [[ $hostname == $MAINHOST ]] ; then 
                    umount -l $dir
                fi
                if [[ $hostname != $MAINHOST && $VIDEOHOST != $MAINHOST ]] ; then
                    ssh $MAINHOST "umount -l $dir"
                fi
            done
        fi
    fi
    ;;
*)
    echo "Invalid mount option $REQUEST"
    exit 2
esac

