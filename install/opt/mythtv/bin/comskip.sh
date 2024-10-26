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

# These overrides enable running this for mythroam
shortname=$(echo "$MYTHCONFDIR" | grep -o "[a-z]*$")
if [[ -f /etc/opt/mythtv/mythtv-$shortname.conf ]] ; then
    . /etc/opt/mythtv/mythtv-$shortname.conf
fi

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
echo "VERBOSE=$VERBOSE"

filename="$1"
chanid="$2"
starttime="$3"
recgroup="$4"
title="$5"
subtitle="$6"

# Get DB password
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName --batch --column-names=FALSE $DBName"

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
error=0
use_txt=0
use_edl=0
extract_fps=0

if [[ "$recgroup" != "Deleted" && "$recgroup" != "LiveTV" ]] ; then
    if [[ "$starttime" == "" ]] ; then
        # Video File
        fullfilename=`ls "$VIDEODIR"/video*/videos/"$filename"`
        use_txt=1
        extract_fps=1
    else
        # Find the recording file
        fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename"`
        use_txt=1
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
        $extraparm "$fullfilename" "$output" 2> "$output/$pgm.stderr" || echo error=$?
    set -
    touch "$output/$pgm.edl"
    echo "Commercial breaks in seconds --"
    cat "$output/$pgm.edl"
    touch "$output/$pgm.txt"
    skip=
    if (( extract_fps)) ; then
        # First line of file has this -
        # FILE PROCESSING COMPLETE 107324 FRAMES AT  2997
        txthead=$(head -1 "$output/$pgm.txt")
        fps=$(grep -o "[0-9]*$" <<< $txthead)0
        # sanity check
        if (( fps > 10000 )) ; then
            $mysqlcmd << EOF
                delete from filemarkup
                    where filename = '$filename' and type=32;
                insert into filemarkup (filename,mark,type,offset)
                    values ('$filename',1,32,$fps);
EOF
        fi
    fi

    if (( use_txt )) ; then
        # txt file has times in frame numbers
        while read -r start finish
        do
            # First line of file has this -
            # FILE PROCESSING COMPLETE 107324 FRAMES AT  2997
            if [[ "$start" == FILE ]] ; then continue ; fi
            if [[ "$start" == ---* ]] ; then continue ; fi
            if (( finish - start < 5 )) ; then continue ; fi
            if [[ "$skip" != "" ]] ; then
                skip="$skip,"
            fi
           skip=${skip}${start}-${finish}
        done < "$output/$pgm.txt"
    elif (( use_edl )) ; then
        # edl file has times in seconds
        # fps is in milliseconds
        if (( ! fps )) ; then
            echo "Error - cannot find fps"
            skip="1-2"
            error=1
        else
            while read -r secs1 secs2 extra
            do
               if [[ "$skip" != "" ]] ; then
                  skip="$skip,"
               fi
               start=$(bc <<< "scale=0; $secs1*$fps/1000")
               finish=$(bc <<< "scale=0; $secs2*$fps/1000")
               skip=${skip}${start}-${finish}
            done < "$output/$pgm.edl"
        fi
    fi
    echo "Skiplist $skip"
    if [[ "$skip" == "" ]] ; then
        echo "Error - empty skip list"
        skip="1-2"
        error=1
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
    if (( error )) ; then
        # to cause error and invoke errfunc
        false
    fi
    # clean up
    if (( ! VERBOSE )) ; then
        rm -fv "$output/$pgm".*
    fi
fi

date
echo "------END------"
