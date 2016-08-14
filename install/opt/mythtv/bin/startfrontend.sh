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

. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

#if [[ "$DISPLAY" == "" ]] ; then
#    exit
#fi

hostname=`cat /etc/hostname`

pkill mythfrontend
# $scriptpath/lirc_drivercheck.sh

if [[ -f /etc/opt/mythtv/remote.xmodmap ]] ; then
    xmodmap /etc/opt/mythtv/remote.xmodmap
fi
$scriptpath/setup_user.sh
# xmodmap -e "keycode 174 = Escape NoSymbol Escape"
# xmodmap -e "keycode 172 = p P p P"

textsize=70000
if [[ `arch` == arm* ]] ; then 
    textsize=25000
fi

#if [[ "$DISPLAY" != "" ]] ; then
    start_frontend=true
    while $start_frontend ; do
        rc=0
        if [[ "$AUTO_LOGIN" != Y && "$USE_MYTHWELCOME" != Y ]] ; then
            start_frontend=false
        fi
        if [[ "$MAINHOST" != "$LocalHostName" ]] ; then
            (
                for (( counter=0 ; counter<100; counter+=4 )) ; do
                    echo $counter
                    $scriptpath/wakeup.sh "$MAINHOST"
                    rc=0
                    echo "select 1 from dual;" | $mysqlcmd || rc=$?
                    if [[ "$rc" == 0 ]] ; then break ; fi
                    # nc -z -v $DBHostName 3306 && break
                    # nc -z -v $MAINHOST $MASTER_BACKEND_PORT && break
                    sleep 4
                done
                echo 99
            ) |  zenity --progress --no-cancel --text="<span size=\"$textsize\">Waiting for MythTV Backend.</span>" --auto-close --title "Please be patient"
        fi
        # nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=1'||nvidia-settings failed
        #if [[ `arch` == arm* ]] ; then 
            # To run standalone use QT_QPA_PLATFORM=eglfs
            # To run under startx use QT_QPA_PLATFORM=xcb
            #if [[ "$DISPLAY" == "" ]] ; then
            #    QT_QPA_PLATFORM=eglfs
            #else
            #    QT_QPA_PLATFORM=xcb
            #fi
            #QT_QPA_EGLFS_FORCE888=1 QT_QPA_PLATFORM=$QT_QPA_PLATFORM\
            #    LD_LIBRARY_PATH=$MYTHTVDIR/lib:$MYTHTVDIR/lib/mysql\
            #    QT_PLUGIN_PATH=$MYTHTVDIR/plugins\
            #    QT_QPA_FONTDIR=$MYTHTVDIR/lib/fonts\
            #    MYSQL_UNIX_PORT=/var/run/mysqld/mysqld.sock\
            #    PYTHONPATH=$MYTHTVDIR/lib/python2.7/site-packages\
            #    $MYTHTVDIR/bin/mythfrontend
        #    LD_LIBRARY_PATH=$MYTHTVDIR/lib\
        #         $MYTHTVDIR/bin/mythfrontend
        #else
        #    mythfrontend --service
        #fi
        echo "select 1 from dual;" | $mysqlcmd || rc=$?
        if [[ "$rc" == 0 ]] ; then 
            mythfrontend -O libCECEnabled=0
            rc=$?
            if [[ "$rc" != 0 ]] ; then
                start_frontend=false
            fi
        fi
        # nvidia-settings -a '[gpu:0]/GPUPowerMizerMode=0'||nvidia-settings failed
        # gnome-session-save --logout
        if [[ "$MOUNTDIR" != "" ]] ; then
            $scriptpath/mount_videos.sh umount
        fi
        if [[ "$USE_MYTHWELCOME" != Y ]] ; then
            #This code is to shutdown the frontend - not wanted if you are using suspend
            #if [[ "$IS_BACKEND" != true && "$rc" == 0 ]] ; then 
            #    if $scriptpath/mythshutdown.sh ; then
            #        $scriptpath/systemshutdown.sh
            #    fi
            #fi
            if ! $start_frontend ; then
                # check $DESKTOP_SESSION  $XDG_CURRENT_DESKTOP  $GDMSESSION $COMPIZ_CONFIG_PROFILE
                if [[ `arch` == arm* ]] ; then 
                    killall lxsession
                else
                    # One of these should work !
                    gnome-session-quit --no-prompt
                    xfce4-session-logout --logout
                fi
            fi
        fi
    done
#fi

