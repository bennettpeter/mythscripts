#!/bin/bash
# Check to see if we can shut down. Return zero if can and 1 if not.
# Also perform some shut down tasks.
# Turn off cable box
# Parameter 1 - optional - powerbtn to indicate called from power button

reason=$1

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1

if (( `date -r $DATADIR/mythshutdown_rc +%s` + 300 >  `date +%s` )) ; then
    rc=`cat $DATADIR/mythshutdown_rc`
    if [[ "$rc" != 0 ]] ; then
        echo `date` mythshutdown.sh $reason "(too soon) return code $rc"
        exit $rc
    fi
fi
date

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`
rc=0

# . /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh

#if [[ "$LocalHostName" == "" ]]; then
#    LocalHostName=`cat /etc/hostname`
#fi

# These checks only run on the machine that is specified in the mythtv.conf as
# the MAINHOST
if [[ "$MAINHOST" == "$LocalHostName" ]] ; then

    # Notify of any failed recordings
    # No longer needed - now there is a custom job for checking recordings
    # $scriptpath/notifyfailed.sh

    # power off cable box - not here, at end if rc=0
    # $scriptpath/stb_poweroff.sh

    now=`date +%H:%M:%S`

    if [[ "$now" > "$WAKEUPTIME" || "$now" == "$WAKEUPTIME" ]] ; then

        # check for daily run
        prev_dailyrun=
        if [[ -f $DATADIR/dailyrun_date ]]; then
            prev_dailyrun=`cat $DATADIR/dailyrun_date`
        fi
        if [[ "$prev_dailyrun" != "$today" ]] ; then
            nohup $scriptpath/myth_dailyrun.sh >> $LOGDIR/myth_dailyrun.log 2>&1 &
            echo $DATE "Starting dailyrun, don't shut down for 5 min."
            echo $today > $DATADIR/dailyrun_date
            rc=1
        fi

        # Removed lines

    fi

    # Check if dailyrun is running
    if ps -ef|grep myth_dailyrun.sh|grep -v grep ; then
        echo $DATE "myth_dailyrun.sh is running, don't shut down for 5 min."
        rc=1
    fi

    # Removed lines

fi

if [[ "$CAN_TRANSCODE" == Y ]] ; then
    # Do not shut down if hold is set
    mkdir -p  "$TCMOUNTDIR/$TCSUBDIR/"
    if [[ -f "$TCMOUNTDIR/$TCSUBDIR/hostlock" ]] ; then
        otherhost=`cat "$TCMOUNTDIR/$TCSUBDIR/hostlock"` 
        if ping -c 1 $otherhost || ( sleep 5 && ping -c 1 $otherhost ) ; then
            echo $DATE "hostlock set by $otherhost, don't shut down for 5 min."
            rc=1
        else
            echo $DATE "Expired hostlock set by $otherhost, removed."
            rm -f "$TCMOUNTDIR/$TCSUBDIR/hostlock"
        fi
    fi
    # Check if multi_encode.sh script is running
    # if there are other encoders add them here 
    encoders='HandBrakeCLI|mencoder|avconv|ffmpeg|avidemux3_cli'
    if ps -ef|grep 'multi_encode.*\.sh'|grep -v "grep " ; then
        echo $DATE "multi_encode is running, don't shut down for 5 min."
        rc=1
    elif ps -ef|egrep "$encoders"|egrep -v "grep " ; then
        echo $DATE "encoders are running, don't shut down for 5 min."
        rc=1
    elif [[ -f "$TCMOUNTDIR/$TCSUBDIR"/mustrun_tcencode ]] ; then
        nohup "$scriptpath/tcencode.sh" >/dev/null 2>&1 &
        echo $DATE "starting tcencode, don't shut down for 5 min."
        rc=1
    fi
fi
# Check for generic hostlock
for file in "$LOCALSTORE/keepalive"/* $KEEPALIVE_HOSTS ; do
    otherhost=`basename "$file"`
    if [[ "$otherhost" != '*' ]] ; then
        if ping -c 1 $otherhost || ( sleep 5 && ping -c 1 $otherhost ) ; then
            echo $DATE "keepalive set by $otherhost, don't shut down for 5 min."
            rc=1
        else
            echo $DATE "Expired keepalive set by $otherhost, removed."
            rm -f "$file"
        fi
    fi
done

# Find unix id of SOFT_USER
soft_unix_id=`grep ^$SOFT_USER: /etc/passwd|cut -d : -s -f 3`
if [[ "$soft_unix_id" == "" ]] ; then
    soft_unix_id=NONE
fi

# Find unix id of mythtv
mythtv_unix_id=`grep ^mythtv: /etc/passwd|cut -d : -s -f 3`
if [[ "$mythtv_unix_id" == "" ]] ; then
    mythtv_unix_id=NONE
fi

# Number of users logged on via terminal / ssh
# term_users=`w -h -s|grep -v "^$SOFT_USER " | wc -l`
# Number of users logged in via GUI
# x_users=`ck-list-sessions | grep "unix-user = '....'" | grep -v $soft_unix_id | wc -l`

ssh_users=`w -h -s|egrep -v "^$SOFT_USER | :0| tty7 " | wc -l`
x_user=`w -h -s|egrep  " tty7 | :0 "|cut -f 1 -d ' '`
xrdp_users=`pidof Xvnc|wc -w`

if [[ -f $DATADIR/checklogin && "$rc" == 0 ]] ; then
    rm -f $DATADIR/checklogin
    echo $DATE Something going on recently - give another 5 minutes
    rc=1
fi

if [[ "$reason" != powerbtn && "$ssh_users" != 0 ]] ; then
    echo $DATE Somebody is still logged in via ssh, see below, don\'t shut down!
    w -h -s|egrep -v "^$SOFT_USER | :0| tty7 "
    # ck-list-sessions | grep "unix-user = '....'" | grep -v $soft_unix_id 
    echo $DATE > $DATADIR/checklogin
    rc=1
fi

if [[ "$xrdp_users" != 0 ]] ; then
    echo $DATE Somebody is still logged in via xrdp, don\'t shut down!
    echo $DATE > $DATADIR/checklogin
    rc=1
fi


if [[ "$x_user" != "" && "$x_user" != "$SOFT_USER" && "$CAN_SUSPEND" != Y ]] ; then
    echo "$DATE Primary screen x user logged in - $x_user - and cannot suspend - don't shut down"
    echo $DATE > $DATADIR/checklogin
    rc=1
fi

if [[ "$x_user" != "" && "$x_user" != "$SOFT_USER" && "$CAN_SUSPEND" == Y ]] ; then
    idletime=`DISPLAY=:0 XAUTHORITY=/home/$x_user/.Xauthority sudo -u $x_user xprintidle`
    # 15 minutes time out
    if (( idletime < 900000 )) ; then
        echo "$DATE Primary screen x activity going on recently - $idletime - don't shut down"
        echo $DATE > $DATADIR/checklogin
        rc=1
    fi
    unset DISPLAY
fi

if [[ `pidof k3b` != "" ]] ; then
    echo $DATE k3b is running, don\'t shut down!
    rc=1
fi

if [[ `pidof parec` != "" ]] ; then
    echo $DATE parec is running, don\'t shut down!
    rc=1
fi

if [[ `pidof simplescreenrecorder` != "" ]] ; then
    echo $DATE simplescreenrecorder is running, don\'t shut down!
    rc=1
fi

# Check if jampal is running
if [[ "$x_user" != "" ]] ; then
    port=`grep listen-port /home/$x_user/.jampal/jampal_initial.properties | cut -d = -f 2`
    if [[ "$port" != "" ]] ; then
        # This code is no good because it brings jampal to the front
        # cat $scriptpath/jampal_test.bin|nc localhost $port > $DATADIR/jampal_test.out
        # if diff $DATADIR/jampal_test.out $scriptpath/jampal_test_resp.bin >/dev/null ; then
        if nc -z localhost $port ; then
            echo "$DATE Jampal is running, port $port, don't shut down"
            rc=1
        fi
    fi
fi

# Check for access to mythweb - if so do not shut down
access=`find /var/log/apache2 -mmin -10 -name access.log -printf %t` || echo "No Apache Server"
if [[ "$access" != "" && "$reason" != powerbtn ]] ; then
    echo $DATE mythweb access at $access, don\'t shut down
    rc=1
fi

# Check if playing a show over http
if ps -e|grep 'mythweb\.pl' ; then
    echo $DATE "mythweb.pl is running, don't shut down for 10 min."
    echo $DATE > $DATADIR/checklogin
    rc=1
fi

#removed && "$rc" == 0
if [[ "$IS_BACKEND" != true  && "$reason" != powerbtn ]] ; then
    # if front end waiting for backend to start do not shut down
    if ps -e|grep zenity ; then
        echo "$DATE zenity running - frontend is starting - don't shut down"
        rc=1
    fi
    # if front end and backend are both running do not shut down
    # if [[ "$rc" == 0 ]] ; then
        if  ps -e|grep mythfrontend && nc -z -v $MAINHOST $MASTER_BACKEND_PORT; then
            echo "$DATE backend running - frontend running - don't shut down"
            rc=1
        fi
    # fi
fi

# Check if anybody is accessing my drives via smb
if which smbstatus ; then
    while true ; do
        read service pid machine date
        if [[ "$service" == "" ]] ; then break ; fi
        if [[ "$service" == 'IPC$' ]] ; then break ; fi
        echo Samba connection $service $pid $machine $date
        if [[ "$machine" == "$LocalHostName" ]] ; then continue ; fi
        ping -c 1 "$machine"
        if [[ "$?" == 0 ]] ; then
            echo "Connected to $machine, do not shut down"
            rc=1
            break
        fi
     done < <(sudo smbstatus -S | tail -n +4)
fi

# Check if CPU idle
idle=$(mpstat 1 1|grep Average:|sed 's/.* //')
canshut=`echo "$idle > 90"|bc`
if [[ "$canshut" == 0 ]] ; then
    echo $DATE "CPU Busy - idle = $idle %, don't shut down for 10 min"
    echo $DATE > $DATADIR/checklogin
    rc=1
fi

#if [[ "$MAINHOST" == "$LocalHostName" && "$rc" == 0 ]] ; then
#    # power off cable box
#    $scriptpath/stb_poweroff.sh
#fi

if [[ "$rc" == 0 ]] ; then
    # Unmount videos
    $scriptpath/mount_videos.sh umount
fi
echo $rc > $DATADIR/mythshutdown_rc
echo mythshutdown.sh $reason return code $rc
exit $rc

