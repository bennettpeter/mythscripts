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
    fi
    if [[ "$fullfilename" == "" ]] ; then
        echo "ERROR: File $filename not found"
        false
    fi
    echo "Found file: $fullfilename ."
    pgm=$(basename "$filename")
    pgm=${pgm%.*}
    rm -fv "$output/$pgm".*

    # wait until there is no mythcommflag running
    while pidof mythcommflag >/dev/null ; do
        sleep 5
    done

    date
    echo "Running mythcommflag"
    set -x
    if [[ "$starttime" == "" ]] ; then
        # Video file
        nice mythcommflag -f "$fullfilename"  --outputmethod essentials \
            --outputfile "$output/$pgm.txt" --skipdb -q --noprogress || echo error=$?
    else
        nice mythcommflag --chanid $chanid --starttime "$starttime"  \
            --outputmethod essentials --outputfile "$output/$pgm.txt" -q --noprogress || echo error=$?
    fi
    set +x
    echo "Commercial breaks in seconds --"
    touch "$output/$pgm.txt"
    cat "$output/$pgm.txt"
    if (( extract_fps)) ; then
        framerate=`mediainfo '--Inform=Video;%FrameRate%' "$fullfilename"`
        fps=$(bc <<< "$framerate*1000/1")
        # Alternate method of calculating framerate
        if (( fps < 20000 )) ; then
            # Second line of file has this -
            # totalframecount: 108251
            fcline=$(grep "totalframecount:" "$output/$pgm.txt")
            framecount=$(grep -o "[0-9]*$" <<< $fcline)
            durationmilli=`mediainfo '--Inform=Video;%Duration%' "$fullfilename"`
            durationmilli=${durationmilli%.*}
            let fps=${framecount}000000/${durationmilli}
            # sanity check
            fps_values="23976 24000 25000 29970 30000 48000 50000 59940 60000"
            prior=0
            for rate in $fps_values ; do
                if (( fps == rate )) ; then break; fi
                if (( fps < rate )) ; then
                    let pdiff=fps-prior
                    let cdiff=rate-fps
                    if (( cdiff < pdiff )) ; then
                        fps=$rate
                    else
                        fps=$prior
                    fi
                    break
                fi
                prior=$rate
            done
        fi
        # sanity check
        if (( fps > 20000 )) ; then
            sqlfn=$(sed "s/'/''/g"<<<$filename)
            $mysqlcmd << EOF
                delete from filemarkup
                    where filename = '$sqlfn' and type=32;
                insert into filemarkup (filename,mark,type,offset)
                    values ('$sqlfn',1,32,$fps);
EOF
        fi
    fi

    if (( use_txt )) ; then
        skip=
        # txt file has lines like this
        # framenum: 16747	marktype: 4
        # framenum: 22147	marktype: 5
        start=
        finish=
        while read -r tag1 value tag2 type
        do
            if [[ $tag1 == 'framenum:' && $tag2 == 'marktype:' ]] ; then
                if [[ $type == 4 ]] ; then
                    start=$value
                elif [[ $type == 5 ]] ; then
                    finish=$value
                fi
            fi
            if [[ $start != '' && $finish != '' ]] ; then
                if (( finish - start > 5 )) ; then
                    if [[ "$skip" != "" ]] ; then
                        skip="$skip,"
                    fi
                    skip=${skip}${start}-${finish}
                    start=
                    finish=
                fi
            fi
        done < "$output/$pgm.txt"

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
            set +x
        else
            set -x
            mythutil --chanid "$chanid" --starttime "$starttime" --setskiplist "$skip" -q
            set +x
        fi
        if (( error )) ; then
            # to cause error and invoke errfunc
            false
        fi
    else
        if [[ "$starttime" != "" ]] ; then
            test=$(mythutil --getskiplist --chanid $chanid --starttime "$starttime" -q)
            if ! echo "$test" | grep - ; then
                echo $test
                echo "Error - empty skip list"
                skip="1-2"
                set -x
                mythutil --chanid "$chanid" --starttime "$starttime" --setskiplist "$skip" -q
                set +x
                false
             fi
         fi
    fi
    # clean up
    if (( ! VERBOSE )) ; then
        rm -fv "$output/$pgm".*
    fi
fi

date
echo "------END------"
