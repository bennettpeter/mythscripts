#!/bin/bash
# Runs at startup of proxy system to check times, ip addresses and set shutdown time
# Requires system to be on daily power off timer.
# run after time-sync.target
set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo startproxy.sh
# sleep to make sure time has been set.
until timedatectl show | grep "NTPSynchronized=yes" ; do
  echo waiting for time sync ...
  sleep 2
done
date

unset nextshutdown
if [[ -f $DATADIR/nextshutdown ]] ; then
    nextshutdown=`cat $DATADIR/nextshutdown`
fi    
now=`date +%s`
if (( nextshutdown < now )) ; then
  let nextshutdown=now+24*60*60-600
  nextshutdownstr=`date +%H:%M --date=@$nextshutdown`
  echo $nextshutdown > $DATADIR/nextshutdown
fi
nextshutdownstr=`date +%H:%M --date=@$nextshutdown`
sudo shutdown -P $nextshutdownstr

# Daily IP address check
if [[ -f $DATADIR/ipaddress.txt ]] ; then
    oldipaddress=`cat $DATADIR/ipaddress.txt`
fi

rc=999
retries=0
while (( rc != 0 && retries < 10 )) ; do
    sleep 2
    set +e
    ipaddress=`curl -s -S 'https://api.ipify.org'`; rc=$?
    set -e
    let retries=retries+1
done
echo IP Address $ipaddress
if [[ "$ipaddress" != "$oldipaddress" ]] ; then
    "$scriptpath/notify.py" "IP Address Change" "$ipaddress"
    echo "$ipaddress" > $DATADIR/ipaddress.txt
fi

