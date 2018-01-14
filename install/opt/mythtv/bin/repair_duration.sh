#!/bin/bash
# Repair duration of a file

echo XXX OBSOLETE - use fixduration.sh
echo XXX OBSOLETE - use fixduration.sh
echo XXX OBSOLETE - use fixduration.sh
exit 2

set -e
filename="$1"
if [[ "$filename" == "" ]] ; then
    echo "ERROR - File name not supplied"
    exit 2
fi
echo repairing $filename
storagedir=`dirname "$filename"`
basename=`basename "$filename"`

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# Get DB password from /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh
mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

# Find the chanid and starttime for the file
set -- `echo "select chanid, starttime from recorded where basename = '$basename';" | \
$mysqlcmd | tail -1`
chanid=$1
starttime="$2 $3"

mythutil --clearseektable --chanid "$chanid" --starttime "$starttime"

set -- `ls -l "$filename"`
filesize=$5

echo "update recorded set filesize = $filesize where chanid = '$chanid' and starttime = '$starttime';" | \
$mysqlcmd
echo "update recordedfile set filesize = $filesize, video_codec = 'H264' where basename = '$basename';" | \
$mysqlcmd


