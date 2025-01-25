#!/bin/bash
# Check to see if we can shut down. Return zero if can and 1 if not.
# Also perform some shut down tasks.
# Turn off cable box
# Parameter 1 - optional
# - powerbtn to indicate called from power button
# - monitor to indicate called from monitor.sh

reason=$1
# Frequency of checks in minutes
# note 1 is not enough, it can have the same nfs count after 60 seconds.
CHECK_MINUTES=2
X_IDLE_MINUTES=10
FS_REPORT_PERCENTAGE=91

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1

let check_seconds=CHECK_MINUTES*60
let check_milliseconds=check_seconds*1000
let x_idle_milliseconds=X_IDLE_MINUTES*60000

if (( `date -r $DATADIR/mythshutdown_rc +%s` + $check_seconds - 5 >  `date +%s` )) ; then
    rc=`cat $DATADIR/mythshutdown_rc`
    if [[ "$rc" != 0 ]] ; then
        echo `date` mythshutdown.sh $reason "(too soon) return code $rc"
        exit $rc
    fi
fi
date
userid=`id -un`

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`
rc=0

. $scriptpath/getconfig.sh

# Check for full file systems
prev_fscheck=
if [[ -f $DATADIR/fscheck_date ]]; then
    fscheck_date=`cat $DATADIR/fscheck_date`
fi
if [[ "$fscheck_date" != "$today" ]] ; then
    df --output=pcent,target | \
    (
        while true ; do
            read perc path
            if [[ "$perc" == "" ]] ; then break; fi
            usage=${perc%\%}
            if (( usage > FS_REPORT_PERCENTAGE )) ; then
                "$scriptpath/notify.py" "$LocalHostName Disk $perc full" \
                    "File system at $path is $perc full."
            fi
        done
    )
    echo $today > $DATADIR/fscheck_date
fi

# These checks only run on the machine that is specified in the mythtv.conf as
# the MAINHOST
if [[ "$MAINHOST" == "$LocalHostName" ]] ; then
    now=`date +%H:%M:%S`
    # Check if dailyrun is running
    if ps -ef|grep myth_dailyrun.sh|grep -v grep ; then
        echo $DATE "myth_dailyrun.sh is running, don't shut down for $CHECK_MINUTES min."
        rc=1
    elif [[ "$now" > "$WAKEUPTIME" || "$now" == "$WAKEUPTIME" ]] ; then
        # check for daily run
        prev_dailyrun=
        if [[ -f $DATADIR/dailyrun_date ]]; then
            prev_dailyrun=`cat $DATADIR/dailyrun_date`
        fi
        if [[ "$prev_dailyrun" != "$today" ]] ; then
            $scriptpath/myth_dailyrun.sh >> $LOGDIR/myth_dailyrun.log 2>&1 &
            echo $DATE "Starting dailyrun, don't shut down for $CHECK_MINUTES min."
            echo $today > $DATADIR/dailyrun_date
            rc=1
        else
            prev_archive=
            if [[ -f $DATADIR/archive_date ]] ; then
                prev_archive=`cat $DATADIR/archive_date`
            fi
            if [[ "$prev_archive" != "$today" ]] ; then
                # Only start dailyrun if tcserver is down, i.e. not busy
                tcserver=`grep " $TCMOUNTDIR" /etc/fstab|sed 's/:.*//;s/=.*//'`
                if [[ "$tcserver" != UUID ]] ; then
                    if ! ping -c 1 "$tcserver" ; then
                        $scriptpath/myth_dailyrun.sh >> $LOGDIR/myth_dailyrun.log 2>&1 &
                        echo $DATE "Starting dailyrun, don't shut down for $CHECK_MINUTES min."
                        rc=1
                    fi
                fi
            fi
        fi
    fi
fi

# if there are other encoders add them here
encoders='HandBrakeCLI ffmpeg feh vlc'
encoderscripts='leanxdvr\.sh|leanxvod\.sh|multi_encode\.sh|leanpplus\.sh'
encoderunning=0
if pidof $encoders ; then
    echo $DATE "One of: $encoders Is running, don't shut down."
    rc=1
    encoderunning=1
    echo $DATE > $DATADIR/checklogin
elif ps -ef|egrep "$encoderscripts"|egrep -v "grep " ; then
    echo $DATE "One of $encoderscripts is running, don't shut down."
    rc=1
    encoderunning=1
    echo $DATE > $DATADIR/checklogin
fi
if [[ "$CAN_TRANSCODE" == Y && "$encoderunning" == 0 ]] ; then
    if [[ -f "$TCSTORAGEDIR/$TCSUBDIR"/mustrun_tcencode ]] ; then
        nohup "$scriptpath/tcencode.sh" >/dev/null 2>&1 &
        echo $DATE "starting tcencode, don't shut down."
        rc=1
    fi
    # Experimental command for checking if HandBrake is in a loop
#    ps -C HandBrakeCLI -o pid=,comm=,%cpu=,etimes=
fi

# On backend, if ffmpeg is running for a long time when mythshutdown is called
# it indicates a bug with hanging mythbackend. In this case reboot.
# This will check for 10 minutes before rebooting.

if [[ "$IS_BACKEND" == true ]] ; then
    pids=$(pidof ffmpeg)
    if [[ "$pids" != "" ]] ; then
        touch $DATADIR/ffmpeg_pids
        ffmpeg_pids="$(cat $DATADIR/ffmpeg_pids)"
        if [[ "$pids" == "$ffmpeg_pids" ]] ;then
            touch $DATADIR/ffmpeg_count
            ffmpeg_count="$(cat $DATADIR/ffmpeg_count)"
            let ffmpeg_count++
            if (( ffmpeg_count == 5 )) ; then
                "$scriptpath/notify.py" "$LocalHostName extern recorder hang" \
                "rebooting now"
                # Shutdown after 1 minute, to allow dump to be taken
                #~ if [[ ! -f /run/systemd/shutdown/scheduled ]] ; then
                    #~ sudo /sbin/shutdown -r +1
                    #~ # kill with a dump - does not work
                    #~ # killall -s SIGQUIT mythbackend
                #~ fi
                bepid=$(pidof mythbackend)
                if [[ "$bepid" != "" ]] ; then
                    logdate=$(date +%Y-%m-%d_%H-%M-%S)
                    sudo gcore -o "/home/peter/${logdate}_core_${bepid}" $bepid
                fi
                rc=1
            fi
            echo "$ffmpeg_count" > $DATADIR/ffmpeg_count
        else
            echo "$pids" > $DATADIR/ffmpeg_pids
            rm -f $DATADIR/ffmpeg_count
        fi
    fi
fi

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

ssh_users=`who -s|egrep -v "^$SOFT_USER | :0| tty7 " | wc -l`
x_user=`who -s|egrep  " tty7 | :0 "|cut -f 1 -d ' '`
# sometimes there are duplicate entries (e.g. peter peter)
# this fixes it to just take the first
set -- $x_user
x_user="$1"
xvnc_users=`pidof Xvnc|wc -w`
xrdp_users=`pidof xrdp|wc -w`
if (( xrdp_users > 0 )) ; then
    let xrdp_users=xrdp_users-1
fi
let xrdp_users=xrdp_users+xvnc_users

if [[ -f $DATADIR/checklogin && "$rc" == 0 ]] ; then
    rm -f $DATADIR/checklogin
    echo $DATE Something going on recently - give another $CHECK_MINUTES minutes
    rc=1
fi

if [[ "$reason" != powerbtn && "$ssh_users" != 0 ]] ; then
    echo $DATE Somebody is still logged in via ssh, see below, don\'t shut down!
    who -s|egrep -v "^$SOFT_USER | :0| tty7 "
    echo $DATE > $DATADIR/checklogin
    rc=1
fi

if (( xrdp_users > 0 )) ; then
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
    echo "idletime: $idletime"
    # 15 minutes time out
    if [[ -f /tmp/${userid}_mythshutdown_prior_idletime ]] ; then
        prior_idletime=`cat /tmp/${userid}_mythshutdown_prior_idletime`
    else
        prior_idletime=0
    fi
    let prior_idletime=prior_idletime+check_milliseconds
    if (( idletime > prior_idletime)) ; then
        idletime=$prior_idletime
    fi
    if (( idletime < x_idle_milliseconds )) ; then
        echo "$DATE Primary screen x activity going on recently - $idletime ms - don't shut down"
        rc=1
    fi
    echo $idletime > /tmp/${userid}_mythshutdown_prior_idletime
    unset DISPLAY
fi

#if [[ `pidof parec` != "" ]] ; then
#    echo $DATE parec is running, don\'t shut down!
#    rc=1
#fi

#if [[ `pidof simplescreenrecorder` != "" ]] ; then
#    echo $DATE simplescreenrecorder is running, don\'t shut down!
#    rc=1
#fi

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
#access=`find /var/log/apache2 -mmin -10 -name access.log -printf %t` || echo "No Apache Server"
#if [[ "$access" != "" && "$reason" != powerbtn ]] ; then
#    echo $DATE mythweb access at $access, don\'t shut down
#    rc=1
#fi

# Check if roamexport is running
if ps -ef|grep roamexport.sh|grep -v grep ; then
    echo $DATE "roamexport.sh is running, don't shut down for $CHECK_MINUTES min."
    rc=1
fi

# xfburn
if pidof xfburn k3b ; then
    echo $DATE "cd or dvd burning is running, don't shut down."
    rc=1
fi

if pidof feh ; then
    echo $DATE "slide show is running, don't shut down."
    rc=1
fi

# Check if anybody is accessing my drives via nfs
if [[ -f /usr/sbin/nfsstat && -f /proc/net/rpc/nfsd ]] ; then
    touch /tmp/${userid}_mythshutdown_nfs_count
    prior_nfs_count=`cat /tmp/${userid}_mythshutdown_nfs_count`
    if [[ "$prior_nfs_count" == "" ]] ; then
        prior_nfs_count=0
    fi
    nfs_count=`/usr/sbin/nfsstat -s -3 -r|tail -2|cut -f1 -d' '`
    if [[ "$prior_nfs_count" != "$nfs_count" ]] ; then
        echo "NFS Activity - $nfs_count - don't shut down"
        rc=1
    fi
    echo $nfs_count > /tmp/${userid}_mythshutdown_nfs_count
fi

# Check if anybody is accessing my drives via smb
#if which smbstatus ; then
#    while true ; do
#        read service pid machine date
#        if [[ "$service" == "" ]] ; then break ; fi
#        if [[ "$service" == 'IPC$' ]] ; then break ; fi
#        echo Samba connection $service $pid $machine $date
#        if [[ "$machine" == "$LocalHostName" ]] ; then continue ; fi
#        ping -c 1 "$machine"
#        if [[ "$?" == 0 ]] ; then
#            echo "Connected to $machine, do not shut down"
#            rc=1
#            break
#        fi
#     done < <(sudo smbstatus -S | tail -n +4)
#fi

# Check if CPU idle
idle=$(mpstat 1 1|grep Average:|sed 's/.* //')
canshut=`echo "$idle > 90"|bc`
if [[ "$canshut" == 0 ]] ; then
    echo $DATE "CPU Busy - idle = $idle %, don't shut down"
    echo $DATE > $DATADIR/checklogin
    rc=1
fi

if [[ "$reason" == monitor ]] ; then
    # If backend running then this is a test or roam system
    # In that case do not shut down.
    if  pidof mythbackend ; then
        echo "$DATE mythbackend running - don't shut down"
        rc=1
    fi
    # If frontend running and not in standby, do not shut down
    if  pidof mythfrontend ; then
        fstate=`( sleep 1 ; echo query location ; sleep 1 ; echo quit ) \
                | nc localhost 6546 | grep "#" | head -1 | sed  "s/# //" \
                | dos2unix`
        if [[ "$fstate" != standbymode ]] ; then
            echo "$DATE frontend running - $fstate - don't shut down"
            echo $DATE > $DATADIR/checklogin
            rc=1
        fi
    fi
fi


#~ if [[ "$MAINHOST" == "$LocalHostName" && "$rc" == 0 ]] ; then
    #~ # Reboot the ceton infinitv
    #~ if [[ "$USE_CETON" == true ]] ; then
        #~ find "$VIDEODIR"/video*/recordings -newer $DATADIR/last_ceton_reboot \
          #~ \( -name '*.ts' -o -name '*.tsx' \) 2>/dev/null | tee /tmp/find$$
        #~ count=`cat /tmp/find$$ | wc -l`
        #~ if (( count > 0 )) ; then
            #~ echo $DATE 'Rebooting Ceton Infinitv (last reboot was '`cat $DATADIR/last_ceton_reboot`')'
            #~ wget -q -t 1 -T 2 -O - --post-data "cmd=reboot" http://$CETON_IP/command.cgi||echo rc $?
            #~ date > $DATADIR/last_ceton_reboot
        #~ fi
    #~ fi
#~ fi

# Only run leanxdvr if all other tests say shutdown is OK
if [[ "$rc" == 0 && "$RUN_LEANXDVR" == Y ]] ; then
    prev_leanxdvr=0
    now=`date +%s`
    prev_wakeup=`date -d "$WAKEUPTIME" +%s`
    if (( prev_wakeup > now )) ; then
        prev_wakeup=`date -d " yesterday $WAKEUPTIME" +%s`
    fi
    if [[ -f $DATADIR/leanxdvr_time ]]; then
        prev_leanxdvr=`cat $DATADIR/leanxdvr_time`
    fi
    # If we are within 6 hours of the wakeup time and more than 18 hours
    # since the last leanxdvr start, we can start it.
    # 21600 sec = 6 hours, 64800 sec = 18 hours
    if (( now - prev_wakeup < 21600 && now - prev_leanxdvr > 64800 )) ; then
        default_maxtime="4 hours"
        xdvr_endtime="$default_maxtime"
        # If a mythtv encoder name is supplied, check for upcoming recordings
        if [[ $LEANXDVR_ENC != "" ]] ; then
            curl "http://localhost:6544/Dvr/GetUpcomingList" > $DATADIR/GetUpcomingList.xml
            xmllint $DATADIR/GetUpcomingList.xml \
              --xpath "//ProgramList/Programs/Program/Recording/EncoderName/text()" \
              > $DATADIR/encoders.txt
            xmllint $DATADIR/GetUpcomingList.xml \
              --xpath "//ProgramList/Programs/Program/Recording/StartTs/text()" \
              > $DATADIR/times.txt
            lineno=$(grep -n  $LEANXDVR_ENC $DATADIR/encoders.txt | head -n 1 | sed "s/:.*//")
            if [[ $lineno != "" ]] ; then
                startts=$(head -n $DATADIR/$lineno times.txt | tail -n 1)
                # Stop recording 5 min before that encoder will be needed by MythTV
                xdvr_endtime="$startts - 5 min"
                if (( $(date -d "$xdvr_endtime" +%s) > $(date -d "$default_maxtime" +%s) )) ; then
                    xdvr_endtime="$default_maxtime"
                fi
            fi
        fi
        /opt/mythtv/leancap/leanxdvr.sh -n $LEANXDVR_RECNAME -e "$xdvr_endtime" --origdate &
        echo $DATE "Starting leanxdvr, don't shut down for $CHECK_MINUTES min."
        echo $now > $DATADIR/leanxdvr_time
        rc=1
    fi
fi

if [[ "$ALWAYS_ON" == Y ]] ; then
    echo "$DATE ALWAYS_ON is set - don't shut down"
    rc=1
fi

echo $rc > $DATADIR/mythshutdown_rc
echo mythshutdown.sh $reason return code $rc
exit $rc

