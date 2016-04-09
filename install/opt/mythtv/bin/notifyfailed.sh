#!/bin/bash
# Notify of any recent failed recordings
# There must be nothing recording while this runs, so run
# only during mythshutdown process.

set -e
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

datetime=`date +%Y%m%d_%H%M`
debug=0
echo $datetime $0 Run Start

# sqldate time format is '2012-10-06 19:00:00'
date_opt="-u"
sqldatetime=`date $date_opt "+%Y-%m-%d %H:%M:%S"`

# rm -f $DATADIR/scte65scan.out

# Get DB password from /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh

mysqlcmd="mysql -N --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

priorsqldatetime='2012-01-01 15:49:43'
if [[ -f $DATADIR/notifyfailed_datetime.txt ]] ; then
    priorsqldatetime=`cat $DATADIR/notifyfailed_datetime.txt`
fi

# Check for damaged recordings

# echo "select a.title, a.subtitle 
# from recordedprogram a, recorded r
# where a.chanid = r.chanid 
#  and a.starttime = r.starttime
#  and r.recgroup != 'LiveTV'
#  and a.videoprop like \"%DAMAGED%\"
#  and a.starttime > '$priorsqldatetime'
#  and a.starttime <= '$sqldatetime';"  | \
#         $mysqlcmd > $DATADIR/damaged_recordings.txt
damagedcount=0
# damagedcount=`cat $DATADIR/damaged_recordings.txt | wc -c`

# Check for nonstarters

echo "SELECT title, subtitle FROM mythconverg.recorded
where filesize < 1000
and recgroup != 'LiveTV'
 and starttime > '$priorsqldatetime'
 and starttime <= '$sqldatetime';"  | \
        $mysqlcmd > $DATADIR/failed_recordings.txt

failedcount=`cat $DATADIR/failed_recordings.txt | wc -c`

if (( $damagedcount > 0 )) ; then
    msg="`cat $DATADIR/damaged_recordings.txt`"
    "$scriptpath/notify.py" "Damaged Recordings" "$msg"
fi

if (( $failedcount > 0 )) ; then
    msg="`cat $DATADIR/failed_recordings.txt`"
    "$scriptpath/notify.py" "Failed Recordings" "$msg"
fi

echo $sqldatetime > $DATADIR/notifyfailed_datetime.txt

echo $datetime Run Complete

