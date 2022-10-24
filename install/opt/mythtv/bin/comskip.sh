#!/bin/bash
# Commercial skip
# command line - 
# /opt/mythtv/bin/comskip.sh "%FILE%" %CHANID% %STARTTIMEUTC% "%RECGROUP%" "%TITLE%" "%SUBTITLE%"
# 

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo "------START------"
date

echo $0 $1 $2 $3 $4 $5 $6 $7

filename="$1"
chanid="$2"
starttime="$3"
recgroup="$4"
title="$5"
subtitle="$6"

function errfunc {
    "$scriptpath/notify.py" "commskip failed" "$title"
    exit 2
}
trap errfunc ERR

echo Set IO priority to -c3 idle
ionice -c3 -p$$

if [[ "$recgroup" != "Deleted" && "$recgroup" != "LiveTV" ]] ; then
    # Find the recording file
    fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename" 2>/dev/null`
    echo Found file: $fullfilename .
    output=/tmp
    pgm=${filename%.*}
    rm -fv $output/$pgm.*
    echo running comskip
    set -x
    nice comskip --ini="/etc/opt/mythtv/comskip_comcast.ini" --output="$output"  --output-filename="$pgm" \
        "$fullfilename" "$output" 2> "$output/$pgm.stderr"
    echo Commercial breaks in seconds --
    cat "$output/$pgm.edl"
    set -
    skip=
    while read -r start finish
    do
       if [[ "$start" == FILE ]] ; then continue ; fi
       if [[ "$start" == ---* ]] ; then continue ; fi
       if [[ "$skip" != "" ]] ; then
          skip="$skip,"
       fi
       skip=${skip}${start}-${finish}
    done < "$output/$pgm.txt"
    echo Skiplist "$skip"
    echo running mythutil
    set -x
    mythutil --chanid "$chanid" --starttime "$starttime" --setskiplist "$skip" -q
    set -
    # clean up
    rm -rfv "$output/$pgm".*
fi

date
echo "------END------"
