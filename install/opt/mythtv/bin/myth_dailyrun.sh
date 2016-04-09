#!/bin/bash
# Daily runs that happen at the start of day

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
date

# Get a date/time stamp to add to log output
DATE=`date +%F\ %T\.%N`
DATE=${DATE:0:23}
today=`date "+%a %Y/%m/%d"`

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
        if [[ "$USE_CETON" == true ]] ; then
            echo $DATE "Rebooting Ceton Infinitv"
            wget -q -t 1 -T 2 -O - --post-data "cmd=reboot" http://$CETON_IP/command.cgi||echo rc $?
        fi
        echo $DATE "Running mythtv_db_backup."
        $scriptpath/mythtv_dbbackup.sh >> $LOGDIR/mythtv_dbbackup.log 2>&1
        rc=$?
        if [[ "$rc" != 0 ]] ; then
            "$scriptpath/notify.py" "Database Backup failed" "mythtv_dbbackup.sh"
        fi
        echo $today > $DATADIR/dbbackup_date
        # Force a reboot after this is done
        true > $DATADIR/reboot_date
    fi
fi
# check for channelscan run
#prev_channelscan=
#if [[ -f $DATADIR/channelscan_date ]]; then
#    prev_channelscan=`cat $DATADIR/channelscan_date`
#fi
#if [[ "$prev_channelscan" != "$today" ]] ; then
#    echo $DATE "Running channelscan."
#    $scriptpath/channelscan.sh >> $LOGDIR/channelscan.log 2>&1
#    echo $today > $DATADIR/channelscan_date
#    size=`cat $DATADIR/scte65scan.out | wc -l`
#    if (( size < 50 )) ; then
#        "$scriptpath/notify.py" "Channelscan failure" \
#            "$DATADIR/scte65scan.out has only $size lines"
#    fi
#fi

# Check for programs set to record on restricted channels
# commented - Concern that access to web interface slows down ceton
# $scriptpath/checkchannels.sh upcoming

# Daily mythfilldatabase via script. Do not run it from the backend
prev_mythrefresh=
if [[ -f $DATADIR/mythrefresh_date ]] ; then
    prev_mythrefresh=`cat $DATADIR/mythrefresh_date`
fi
if [[ "$prev_mythrefresh" != "$today" ]] ; then
    echo $DATE "Running mythfilldatabase."
    $scriptpath/mythfilldatabase.sh >/dev/null 2>&1
    rc=$?
    if [[ "$rc" != 0 ]] ; then
        "$scriptpath/notify.py" "mythfilldatabase failed" "mythfilldatabase.sh"
    fi
    echo $today > $DATADIR/mythrefresh_date
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
    ipaddress=`curl 'https://api.ipify.org'`
    if [[ "$ipaddress" != "$oldipaddress" ]] ; then
        "$scriptpath/notify.py" "IP Address Change" "$ipaddress"
        echo "$ipaddress" > $DATADIR/ipaddress.txt
    fi
fi
prev_transcode=
if [[ -f $DATADIR/transcode_date ]] ; then
    prev_transcode=`cat $DATADIR/transcode_date`
fi
if [[ "$prev_transcode" != "$today" ]] ; then
    # Start daily transcode run
    echo $DATE "Running tcdaily."
    nice ionice -c3 $scriptpath/tcdaily.sh >/dev/null 2>&1
    rc=$?
    if [[ "$rc" != 0 ]] ; then
        "$scriptpath/notify.py" "Transcode daily run failed" "tcdaily.sh"
    fi
    echo $today > $DATADIR/transcode_date
fi

# Check cable box once a day
# $scriptpath/stb_poweron.sh

