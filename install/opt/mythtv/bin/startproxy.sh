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
date
# sleep to make sure time has been set.
echo waiting for time sync
count=0
until timedatectl show | grep "NTPSynchronized=yes" ; do
  echo -n .
  sleep 1
  let count=count+1
  # Approx 12 hours
  if (( count > 43200 )) ; then
    date
    echo "Failed for 12 hours to get network time, shutting down now"
    sudo shutdown -P now
    exit 2
  fi
done
date

unset nextshutdown
if [[ -f $DATADIR/nextshutdown ]] ; then
    nextshutdown=`cat $DATADIR/nextshutdown`
fi    
now=`date +%s`
if (( nextshutdown < now )) ; then
  let nextshutdown=now+24*60*60-600
  echo $nextshutdown > $DATADIR/nextshutdown
fi
nextshutdownstr=`date +%H:%M --date=@$nextshutdown`
# Time switch is left on standard time year round.
# In winter it powers on at 2am, in summer at 3am.
# Sanity check in case power is off for 24 hours.
if [[ "$nextshutdownstr" < 01:30 || "$nextshutdownstr" > 03:30 ]] ; then
  echo "Bad shutdown time of $nextshutdownstr, setting it to 01:30"
  nextshutdownstr=01:30
  nextshutdown=`date --date="01:30"`
  if (( nextshutdown < now )) ; then
    nextshutdown=`date --date="tomorrow 01:30"`
  fi
  echo $nextshutdown > $DATADIR/nextshutdown
fi
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
sleep 600
rc=0
ip address show dev eth0 | grep "inet6 2" || rc=$?
if [[ "$rc" != 0 ]] ; then
    "$scriptpath/notify.py" "No IPV6 address" "$ipaddress"
fi

