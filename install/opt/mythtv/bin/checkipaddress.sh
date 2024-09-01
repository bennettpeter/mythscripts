#!/bin/bash
# Check for changed ip address

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if [[ -f $DATADIR/ipaddress.txt ]] ; then
    source $DATADIR/ipaddress.txt
fi

rc=999
retries=0
while (( rc != 0 && retries < 10 )) ; do
    sleep 2
    set +e
    ipaddress=`curl -s -S  -m 30 'https://api.ipify.org'`; rc=$?
    set -e
    let retries=retries+1
done
echo IP Address $ipaddress
ipv6=($(ip address | grep 'inet6 2.*/128' | sed 's!/128.*!!'))
echo IPV6 Address ${ipv6[1]}
if [[ "$ipaddress" != "$IPV4ADDRESS" || "${ipv6[1]}" != "$IPV6ADDRESS" ]] ; then
    "$scriptpath/notify.py" "IP Address Change" \
    "
$IPV4ADDRESS -> $ipaddress 
$IPV6ADDRESS -> ${ipv6[1]}"
fi
echo "IPV4ADDRESS=$ipaddress" > $DATADIR/ipaddress.txt
echo "IPV6ADDRESS=${ipv6[1]}" >> $DATADIR/ipaddress.txt
