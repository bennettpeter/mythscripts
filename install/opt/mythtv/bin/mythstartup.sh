#!/bin/bash
# Tasks to run before myth backend starts
# Note this is also run from mythshutdown.sh
# Set up starting channel numbers
# Prevent cable box turning on if not needed.

set -e
date
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

# Get DB password 
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

# Note that I join with cardinput here so that I only get cards that are actually in use.
# echo "select concat(a.videodevice,' ',a.cardtype) from capturecard a, cardinput i \
# where a.cardid = i.cardid and a.hostname = '$LocalHostName' \
# order by a.cardid; " \
#     | $mysqlcmd > $DATADIR/mythstartup_cardlist.txt
# first=
# Checks to see that everything is connected
# (
#     while true ; do
#         read device type || exit 0
#         if [[ "$device" == "" ]] ; then
#             exit
#         fi
#         if [[ "$first" == "" ]] ; then
#             first=Y
#         else
#             case $type in
#             FIREWIRE)
#                 echo "Checking Firewire $device"
#                 if ! plugreport | grep -i $device ; then
#                     "$scriptpath/notify.py" "Startup Problem" "Firewire not connected: $device"
#                     echo "Firewire not connected: $device"
#                 fi
#             ;;
#             DVB)
#                 echo "Checking DVB $device"
#                 if [[ ! -c $device ]] ; then 
#                     "$scriptpath/notify.py" "Startup Problem" "DVB not connected: $device"
#                     echo "DVB not connected: $device"
#                 fi
#             ;;
#             HDHOMERUN)
#                 echo "Checking HD Homerun $device"
#                 hdhr_id="${device%-?}"
#                 tunernum="${device#*-}"
#                 tunerstatus=`hdhomerun_config $hdhr_id get /tuner${tunernum}/status` || true
#                 if [[ "$tunerstatus" != "ch=none lock=none ss=0 snq=0 seq=0 bps=0 pps=0" ]] ; then
#                     "$scriptpath/notify.py" "Startup Problem" "HD Homerun Problem: $device $tunerstatus"
#                     echo "HD Homerun problem: $device $tunerstatus"
#                 fi
#             esac
#         fi
#     done
# ) < $DATADIR/mythstartup_cardlist.txt

if [[ "$USE_CETON" == true ]] ; then
    echo "Checking Ceton $CETON_IP"
    if ! msg=`nc -z -v "$CETON_IP" 80 2>&1` ; then
        "$scriptpath/notify.py" "Startup Problem" "Ceton Problem: $CETON_IP $msg"
        echo "Ceton Problem: $CETON_IP $msg"
    fi
fi

# set live tv start channel to a valid HD channel number
# This avoids the problem of failing to open jump file buffer during live TV
fesetup=
if [[ "$FE_STARTCHANNEL" != "" && "$FE_SOURCENAME" != "" ]] ; then
    fesetup="update settings s,channel c, videosource v 
    set s.data = c.chanid
    where c.channum = '$FE_STARTCHANNEL'
    and c.sourceid = v.sourceid
    and v.name = '$FE_SOURCENAME'
    and s.value = 'DefaultChanid';"
    #    and s.hostname = '$LocalHostName'
fi

$mysqlcmd <<EOF || echo mysql failed
$fesetup
$fwsetup
EOF

echo "mythstartup.sh completed"

