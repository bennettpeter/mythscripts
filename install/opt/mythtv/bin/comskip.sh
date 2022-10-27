#!/bin/bash
# Commercial skip
# command line - 
# /opt/mythtv/bin/comskip.sh "%FILE%" %CHANID% %STARTTIMEUTC% "%RECGROUP%" "%TITLE%" "%SUBTITLE%"
# for a Video, the filename must be a full file name relative to the videos directory and other parameters must be blank
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
    if [[ "$title" == "" ]] ; then
        title="$filename"
    fi
    "$scriptpath/notify.py" "commskip failed" "$title" "$subtitle"
    exit 2
}
trap errfunc ERR

echo Set IO priority to -c3 idle
ionice -c3 -p$$

if [[ "$recgroup" != "Deleted" && "$recgroup" != "LiveTV" ]] ; then
    # Find the recording file
    if [[ "$chanid" == "" ]] ; then
        fullfilename=`ls "$VIDEODIR"/video*/videos/"$filename" 2>/dev/null`
    else
        fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename" 2>/dev/null`
    fi
    echo Found file: $fullfilename .
    output=/tmp
    pgm=$(basename "$filename")
    pgm=${pgm%.*}
    rm -fv "$output/$pgm".*

    # wait until there is no comskip running
    while pidof comskip >/dev/null ; do
        sleep 5
    done

    echo running comskip
    set -x
    nice comskip --ini="/etc/opt/mythtv/comskip_comcast.ini" --output="$output"  --output-filename="$pgm" \
        "$fullfilename" "$output" 2> "$output/$pgm.stderr"
    set -
    echo Commercial breaks in seconds --
    cat "$output/$pgm.edl"
    skip=
    while read -r start finish
    do
       if [[ "$start" == FILE ]] ; then continue ; fi
       if [[ "$start" == ---* ]] ; then continue ; fi
       if (( finish - start < 5 )) ; then continue ; fi
       if [[ "$skip" != "" ]] ; then
          skip="$skip,"
       fi
       skip=${skip}${start}-${finish}
    done < "$output/$pgm.txt"
    echo Skiplist "$skip"
    if [[ "$skip" == "" ]] ; then
        echo Error - empty skip list
        # to cause error and invokde errfunc
        false
    fi
    echo running mythutil
    set -x
    if [[ "$chanid" == "" ]] ; then
        mythutil --video "$filename" --setskiplist "$skip" -q
    else
        mythutil --chanid "$chanid" --starttime "$starttime" --setskiplist "$skip" -q
    fi
    set -
    # clean up
    rm -fv "$output/$pgm".*
fi

date
echo "------END------"
