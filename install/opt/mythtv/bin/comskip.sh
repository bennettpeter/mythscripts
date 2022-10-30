#!/bin/bash
# Commercial skip
# command line - 
# /opt/mythtv/bin/comskip.sh "%FILE%" %CHANID% %STARTTIMEUTC% "%RECGROUP%" "%TITLE%" "%SUBTITLE%"
# or for a video:
# /opt/mythtv/bin/comskip.sh "filename" [profile]
# for a Video, the filename must be a full file name relative to the videos directory
# profile is the name of the ccomskip ini, default is peacock
# For a video parameters after profile must be blank
# set environment VERBOSE=n for debugging where n is verbose level, 0 is non debug.
# Set temporarily in mythtv.conf or on command line

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

if (( VERBOSE )) ; then
    LOGDIR=/var/tmp/comskip_debug
    mkdir -p $LOGDIR
    output=$LOGDIR
    extraparm="--verbose=$VERBOSE"
else
    output=/tmp
    extraparm=
fi

exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo "------START------"
date

echo $0 $1 $2 $3 $4 $5 $6 $7
echo "DEBUG_COMSKIP=$DEBUG_COMSKIP"

filename="$1"
chanid="$2"
starttime="$3"
recgroup="$4"
title="$5"
subtitle="$6"

if [[ "$starttime" == "" ]] ; then
    if [[ "$chanid" == "" ]] ; then
        inifile=peacock
    else
        inifile=$chanid
        chanid=""
    fi
    echo "Video using $inifile"
else
    inifile=comcast
    echo "Recording using $inifile"
fi

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
    if [[ "$starttime" == "" ]] ; then
        fullfilename=`ls "$VIDEODIR"/video*/videos/"$filename" 2>/dev/null`
    else
        fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename" 2>/dev/null`
    fi
    if [[ "$fullfilename" == "" ]] ; then
        echo "ERROR: File $filename not found"
        false
    fi
    echo "Found file: $fullfilename ."
    pgm=$(basename "$filename")
    pgm=${pgm%.*}
    rm -fv "$output/$pgm".*

    # wait until there is no comskip running
    while pidof comskip >/dev/null ; do
        sleep 5
    done

    date
    echo "Running comskip"
    set -x
    nice comskip --ini="/etc/opt/mythtv/comskip_${inifile}.ini" --output="$output"  --output-filename="$pgm" \
        $extraparm "$fullfilename" "$output" 2> "$output/$pgm.stderr"
    set -
    echo "Commercial breaks in seconds --"
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
    echo "Skiplist $skip"
    if [[ "$skip" == "" ]] ; then
        echo "Error - empty skip list"
        # to cause error and invoke errfunc
        false
    fi
    echo "Running mythutil"
    if [[ "$starttime" == "" ]] ; then
    set -x
        mythutil --video "$filename" --setskiplist "$skip" -q
    set -
    else
    set -x
        mythutil --chanid "$chanid" --starttime "$starttime" --setskiplist "$skip" -q
    set -
    fi
    # clean up
    if (( ! VERBOSE )) ; then
        rm -fv "$output/$pgm".*
    fi
fi

date
echo "------END------"
