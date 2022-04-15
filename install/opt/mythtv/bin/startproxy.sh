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
echo `date` startproxy.sh Starting
# sleep to make sure time has been set.
echo waiting for time sync
count=0
until timedatectl show | grep "NTPSynchronized=yes" ; do
  echo -n .
  sleep 1
  let count=count+1
  # Approx 12 hours
  if (( count > 300 )) ; then
    date
    echo "ERROR: Tried for 5 minutes to get network time - failed"
    "$scriptpath/notify.py" "Failed to get network time" \
        "Tried for 5 minutes to get network time - failed"
  fi
done
date

# Daily restart
if [[ $PROXY_RESTART != "" ]] ; then
    sudo shutdown -r $PROXY_SHUTDOWN
fi

# Check if other DNS server is up
if [[ $PROXY_CHECK != "" ]] ; then
    if ! nc -z -v $PROXY_CHECK 53 ; then
        echo "ERROR: DNS server $PROXY_CHECK is down"
        "$scriptpath/notify.py" "DNS server $PROXY_CHECK is down" \
            "Cannot connect DNS server $PROXY_CHECK port 53."
    fi
fi

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

if [[ "$TRANSMISSION" == Y ]] ; then
    #Start Transmission
    mount /home/storage || echo mount failed
    while ! mountpoint /home/storage ; do
        if [[ "$msgsent" == "" ]] ; then
            "$scriptpath/notify.py" "storage mount failed" "Turn on the disk"
            msgsent=Y
        fi
        sleep 60
        mount /home/storage || echo mount failed
    done
    sudo systemctl start transmission-daemon.service
fi

# Loop to monitor ipv6 address
ipv6addsave=
while true ; do
    ipv6add=`ip address show dev eth0 | grep "inet6 2"` || true
    if [[ "$ipv6add" != "$ipv6addsave" ]] ; then
        echo `date` IPV6 address change:
        echo "$ipv6add"
        ipv6addsave="$ipv6add"
    fi
    sleep 600
done
