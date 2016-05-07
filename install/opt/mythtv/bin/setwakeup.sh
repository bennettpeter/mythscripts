#!/bin/bash
# Called from backend to set next wakeup time.
# $1 is the first argument to the script. It is the time in seconds since 1970 UTC
# Must be called with sudo
# this is defined in mythtv-setup with the time_t argument
# call with 0 to reset alarm
# Always schedules a wake-up for daily wakeup time
# To get a test time use date --date "2011-07-05 14:55:00" +%s
# To check the time from the time_t use date --date=@1315270500

startuptime=$1
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

logdate=`date "+%Y-%m-%d %H:%M:%S"`
echo $logdate setwakeup \"$1\" 

if [ "$startuptime" = "" ] ; then
    if [ -f $DATADIR/startuptime ] ; then
        startuptime=`cat $DATADIR/startuptime`
        echo $logdate $DATADIR/startuptime \"$startuptime\" 
    fi
else
    rm -f $DATADIR/startuptime
    echo $startuptime > $DATADIR/startuptime
    chmod g+w $DATADIR/startuptime
fi

if [ "$startuptime" = "" ] ; then
    startuptime=0
fi

echo 0 > /sys/class/rtc/rtc0/wakealarm      #this clears your alarm.
if [ "$startuptime" != 0 ] ; then
    # This file tells us if we use UTC for system time.
    if [ -f /etc/default/rcS ] ; then
        . /etc/default/rcS
    fi
    now=`date +%s`
    # If this is run after midnight on Saturday at end of DST it sets wakeup to 4 AM instead of 5 AM
    nextdw=`date --date "today $WAKEUPTIME" +%s`
    if [ $nextdw -lt $now ] ; then
        nextdw=`date --date "tomorrow $WAKEUPTIME" +%s`
    fi
    echo $logdate nextdw \"$nextdw\"
    if [ $startuptime -lt $now -o $startuptime -gt $nextdw ] ; then
        startuptime=$nextdw
    fi
    echo $logdate startuptime \"$startuptime\"
    if [ `ps -p1 -o comm --no-headers` == systemd ] ; then
        UTC=yes
    fi
    if [ "$UTC" = yes ] ; then
        biostime=$startuptime
    else
        displaytime=`date --date @$startuptime "+%Y-%m-%d %H:%M:%S"`
        biostime=`date -u --date "$displaytime" +%s`
    fi
    echo $logdate biostime \"$biostime\"
    if [ `ps -p1 -o comm --no-headers` = systemd ] ; then
        rtcwake -m no -a -t $biostime
    else
        echo $biostime > /sys/class/rtc/rtc0/wakealarm     #this writes your alarm
    fi
fi
