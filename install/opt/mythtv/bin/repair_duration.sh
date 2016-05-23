#!/bin/bash
# Repair duration of a file
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
#mysqlcmd=cat

# Find the chanid and starttime for the file
set -- `echo "select chanid, starttime from recorded where basename = '$basename';" | \
$mysqlcmd | tail -1`
chanid=$1
starttime="$2 $3"

mythcommflag --rebuild  --chanid "$chanid" --starttime "$starttime" || echo Return Code is $?

# Fix duration
# duration=`mediainfo '--Inform=Video;%Duration%' "$storagedir/$basename"` || echo Return Code is $?
millisecsv=`mediainfo '--Inform=Video;%Duration%' "$storagedir/$basename"`
# 21600000 = 6 hours
if (( millisecsv > 21600000 )) ; then
    echo "Wacky video length of $millisecsv ignored, set to 0"
    # 60000 = 1 minute
    millisecsv=0
fi
# the tab and cut is to select just the first audio stream length
millisecsa=`mediainfo '--Inform=Audio;%Duration%'$'\t' "$storagedir/$basename" | cut -f 1`
# 21600000 = 6 hours
if (( millisecsa > 21600000 )) ; then
    echo "Wacky audio length of $millisecsa ignored, set to 0"
    millisecsa=0
fi
if (( millisecsv > millisecsa )) ; then
    duration=$millisecsv
else
    duration=$millisecsa
fi
if (( duration == 0 )) ; then
    echo "Error no duration found for $storagedir/$basename"
    exit 2
else
    echo "update recordedmarkup set data = '$duration' " \
        "where chanid = '$chanid' and starttime = '$starttime' and type = '33' and mark = '0';" | \
    $mysqlcmd
fi

