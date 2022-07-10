#!/bin/bash
# Daily runs that happen at the start of day

. /etc/opt/mythtv/mythtv.conf
. /etc/opt/mythtv/private.conf
LEANCAP=/opt/mythtv/leancap
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
date

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`
numdate=`date "+%Y%m%d"`

# Wait for network to be available
sleep 90

# . /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh

# Saturday
if [[ "$today" == Sat* ]]; then
    # check for dbbackup run
    prev_dbbackup=
    if [[ -f $DATADIR/dbbackup_date ]]; then
        prev_dbbackup=`cat $DATADIR/dbbackup_date`
    fi
    if [[ "$prev_dbbackup" != "$today" ]] ; then
        # Reboot the ceton infinitv
        #if [[ "$USE_CETON" == true ]] ; then
        #    echo $DATE "Rebooting Ceton Infinitv"
        #    wget -q -t 1 -T 2 -O - --post-data "cmd=reboot" http://$CETON_IP/command.cgi||echo rc $?
        #fi
        echo $DATE "Running mythtv_db_backup."
        echo $today > $DATADIR/dbbackup_date
        $scriptpath/mythtv_dbbackup.sh >> $LOGDIR/mythtv_dbbackup.log 2>&1
        rc=$?
        if [[ "$rc" != 0 ]] ; then
            "$scriptpath/notify.py" "Database Backup failed" "mythtv_dbbackup.sh"
        fi
        echo Running leancap_chanlist
        $LEANCAP/leancap_chanlist.sh leancap2
        rc=$?
        if [[ "$rc" != 0 ]] ; then
            "$scriptpath/notify.py" "Leancap Chanlist failed" "$LEANCAP/leancap_chanlist.sh leancap2"
        fi
        # Run roamexport to keep portable drive up to date.
        # This must be run here to ensure consistent with DB backup above
        $scriptpath/roamexport.sh
        rc=$?
        if [[ "$rc" != 0 ]] ; then
            "$scriptpath/notify.py" "roamexport failed" "roamexport.sh"
        fi
        # Video cleanup
        $scriptpath/videocleanup.sh >> $LOGDIR/videocleanup.log 2>&1
        if [[ "$rc" != 0 ]] ; then
            "$scriptpath/notify.py" "videocleanup failed" "videocleanup.sh"
        fi
    fi
fi

# Daily mythfilldatabase via script. Do not run it from the backend
prev_mythfilldatabase=
if [[ -f $DATADIR/mythfilldatabase_date ]] ; then
    prev_mythfilldatabase=`cat $DATADIR/mythfilldatabase_date`
fi
if [[ "$prev_mythfilldatabase" != "$today" ]] ; then
    DATE=`date +%F\ %T\.%N`
    DATE=${DATE:0:23}
    echo $DATE "Running mythfilldatabase."
    echo $today > $DATADIR/mythfilldatabase_date
    # run asynchronously - in error cases it can run 2 hours and hold up other stuff.
    (
        $scriptpath/mythfilldatabase.sh  --only-update-guide >/dev/null 2>&1
        rc=$?
        if [[ "$rc" != 0 ]] ; then
            "$scriptpath/notify.py" "mythfilldatabase failed" "mythfilldatabase.sh"
        fi
    ) &

    # Print 1 day's upcoming recordings
    date >> $LOGDIR/mythtv_upcoming_recordings.log
    "$scriptpath/myth_upcoming_recordings.pl" --plain_text --hours 24 --recordings -1 \
        --plain_text --text_format "%Y%m%d %H%i%s %eH%ei%es %T - %S\n" \
        >> $LOGDIR/mythtv_upcoming_recordings.log

    if [[ "$RCONFLICTCHECK" == Y ]] ; then
    # Checks for recordings that will be attempted at 2 am or 3 am and may hit
    # the reboot of the router.
    "$scriptpath/myth_upcoming_recordings.pl" --plain_text --hours -1 --recordings -1 \
        --plain_text --text_format "%Y%m%d %H%i%s %eH%ei%es %T - %S\n" \
        | (
            message=
            read title
            read date start end title
            while [[ "$date" != "" ]] ; do
                # Skip Checking Major Crimes at 1 AM weekly.
                if [[ "$start" == 010000 && "$end" == 020000 \
                        && "$title" == "Major Crimes "* ]] ;  then
                    echo "Skipping Check Of $date $start $end $title"
                elif [[ "$start" < 031000 && "$end" > 015000 ]] ; then
                    message="$message"$'\n'"$date $start $end $title"
                fi
                read date start end title
            done
            if [[ "$message" == "" ]] ; then
                if [[ "$SUPPRESS_CONFLICT" == Y ]] ; then
                    "$scriptpath/notify.py" "No More Conflicts" \
                    "Set timeswitch and unset SUPPRESS_CONFLICT"
                fi
            else
                if [[ "$SUPPRESS_CONFLICT" != Y ]] ; then
                    "$scriptpath/notify.py" "Warning - Recording Reset Conflict"\
                    "Recordings at 2 am or 3 am"$'\n'"$message"
                fi
            fi
          )
    fi
    # Daily IP address check
    if [[ -f $DATADIR/ipaddress.txt ]] ; then
        oldipaddress=`cat $DATADIR/ipaddress.txt`
    fi
    # ipaddress=`wget http://automation.whatismyip.com/n09230945.asp -O - -q`
    # pushd $DATADIR
    # rm -f index.html
    # wget http://wakeonlan.me
    # ipaddress=`grep 'Your IP' index.html | sed 's/.*Your IP *//' | sed 's/,.*//'`
    # New method
    # rm -f ipaddress.json
    # wget -O ipaddress.json http://www.realip.info/api/p/realip.php
    # Note here eval gets rid of the inverted commas around the ip address
    # eval ipaddress=`jq .IP ipaddress.json`
    # popd
    ipaddress=`curl -m 30 'https://api.ipify.org'`
    if [[ "$ipaddress" != "$oldipaddress" ]] ; then
        "$scriptpath/notify.py" "IP Address Change" "$ipaddress"
        echo "$ipaddress" > $DATADIR/ipaddress.txt
    fi
fi
prev_transcode=
if [[ -f $DATADIR/transcode_date ]] ; then
    prev_transcode=`cat $DATADIR/transcode_date`
fi
run_tc=0
if [[ "$prev_transcode" != "$today" ]] ; then
    run_tc=1
    # This will return server name for an NFS mount,
    # the string "UUID" for a local mount, empty for a mismatch
    tcserver=`grep " $TCMOUNTDIR" /etc/fstab|sed 's/:.*//;s/=.*//'`
    if [[ "$tcserver" != UUID ]] ; then
        if ping -c 1 "$tcserver" ; then
            # Avoid running tcdaily if tcserver is up, tcserver
            # may be busy recording.
            echo "postpone tcdaily because $tcserver is running" 
            run_tc=0
        fi
    fi
fi
if (( run_tc )) ; then
    # Start daily transcode run
    echo $today > $DATADIR/transcode_date
    DATE=`date +%F\ %T\.%N`
    DATE=${DATE:0:23}
    echo $DATE "Running tcdaily."
    nice ionice -c3 $scriptpath/tcdaily.sh >/dev/null 2>&1
    rc=$?
    if [[ "$rc" != 0 ]] ; then
        "$scriptpath/notify.py" "Transcode daily run failed" "tcdaily.sh"
    fi
fi

# Check cable box once a day
# $scriptpath/stb_poweron.sh

# wait for mythfilldatabase and any other child process
wait
date
echo myth_dailyrun ended.
