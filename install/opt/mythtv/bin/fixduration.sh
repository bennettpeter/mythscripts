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
    # mythcommflag --rebuild  --chanid "$chanid" --starttime "$starttime" || echo Return Code is $?
    # Fix duration
    duration=`mediainfo '--Inform=Video;%Duration%' "$fullfilename"` || echo Return Code is $?
    if [[ "$duration" == "" ]] ; then
        echo "Error no duration found for $bname"
        exit 2
    else
        echo "update recordedmarkup set data = '$duration' " \
            "where chanid = '$chanid' and starttime = '$starttime' and type = '33' and mark = '0';" | \
        $mysqlcmd
    fi
else
    echo "No match in filesystem for for $bname"
    exit 2
fi

echo "$bname processed"
