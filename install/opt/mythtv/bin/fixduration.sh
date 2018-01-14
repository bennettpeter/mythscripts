#!/bin/bash
set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

echo "Fix duration of a video in the database"
echo  "Input parameters "
echo "1 video file name"

filename="$1"

# Get DB password from /etc/mythtv/mysql.txt
# . /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

bname=`basename "$filename"`
fullfilename=`find "$VIDEODIR" -name "$bname" 2>/dev/null` || true
if [[ -f "$fullfilename" ]] ; then
    # Find the chanid and starttime for the file
    set -- `echo "select chanid, starttime from recorded where basename = '$bname';" | \
    $mysqlcmd | tail -1`
    if [[ "$1" == "" || "$2" == "" || "$3" == "" ]] ; then
        echo "No match in database for $bname"
        exit 2
    fi
    chanid=$1
    starttime="$2 $3"
    mythutil --clearseektable --chanid "$chanid" --starttime "$starttime"

    set -- `ls -l "$fullfilename"`
    filesize=$5

    echo "update recorded set filesize = $filesize where chanid = '$chanid' and starttime = '$starttime';" | \
    $mysqlcmd
    echo "update recordedfile set filesize = $filesize, video_codec = 'H264' where basename = '$basename';" | \
    $mysqlcmd
else
    echo "No match in filesystem for for $bname"
    exit 2
fi

echo "$bname processed"
