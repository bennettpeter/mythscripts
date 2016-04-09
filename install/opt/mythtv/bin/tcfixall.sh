#!/bin/bash
# Fix durations on existing transcoded recordings

set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`


# Get DB password from /etc/mythtv/mysql.txt
# . /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

for dir in "$VIDEODIR"/video?/recordings/ ; do
    cd "$dir"
    for file in *.mkv ; do
        basename="${file%.mkv}"
        duration=`mediainfo '--Inform=Video;%Duration%' "$file"`
        if [[ "$duration" == "" ]] ; then
            echo "Error no duration found for $file"
        else
            chanid=${basename%_*}
            starttime=${basename#*_}
            echo "update recordedmarkup set data = '$duration' " \
                "where chanid = '$chanid' and starttime = '$starttime' and type = '33' and mark = '0';" | \
            $mysqlcmd
        fi
    done
done

