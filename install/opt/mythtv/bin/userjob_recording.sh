#!/bin/bash
# Job to check if a recording was successuly
# command line - 
# /opt/mythtv/bin/userjob_recording.sh "%FILE%" "%PROGSTARTISOUTC%" "%PROGENDISOUTC%" "%RECGROUP%" "%TITLE%" "%SUBTITLE%" 
# filename starttime endtime recgroup
# 9999_999999999.ts YYYY-MM-DDThh:mm:ssZ  YYYY-MM-DDThh:mm:ssZ Default
# 
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

echo $0 $1 $2 $3 $4 $5 $6

filename="$1"
starttime="$2"
endtime="$3"
recgroup="$4"
title="$5"
subtitle="$6"

# Get DB password from config.xml
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

# Get the duplicate flag
set -- `echo "select duplicate, starttime, endtime from recorded where basename = '$filename';" | \
$mysqlcmd | tail -1`
duplicate=$1
db_starttime="$2 $3"
db_endtime="$4 $5"

echo "Filename: $filename   duplicate: $duplicate"

# Check if Mythtv has flagged it as failed
if [[ "$duplicate" != 1 ]] ; then
    "$scriptpath/notify.py" "Recording failed" "$title $subtitle has duplicate = $duplicate, should be 1"
fi

use_mediainfo=N

if [[ "$recgroup" != "Deleted" && "$recgroup" != "LiveTV" ]] ; then
    # Calculate recording time 
    starttimesecs=`date -ud "$starttime" "+%s"`
    endtimesecs=`date -ud "$endtime" "+%s"`
    let expectsecs=endtimesecs-starttimesecs
    db_starttimesecs=`date -ud "$db_starttime" "+%s"`
    db_endtimesecs=`date -ud "$db_endtime" "+%s"`
    let db_expectsecs=db_endtimesecs-db_starttimesecs
    # Find the recording file
    #fullfilename=`find "$VIDEODIR" -name "$filename" 2>/dev/null`
    fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename" 2>/dev/null` || true
    if [[ "$use_mediainfo" == Y ]] ; then
        ## Find length using mediainfo
        millisecsv=`mediainfo '--Inform=Video;%Duration%' "$fullfilename"`
        # on 2015/11/17 This gave answer of 36268563626856 for audio duration
        # file was actually corrupt
        millisecsa=`mediainfo '--Inform=Audio;%Duration%' "$fullfilename"`
        if (( millisecsa > 21600000 )) ; then
            echo "Wacky audio length of $millisecsa ignored, set to 60000"
            millisecsa=60000
        fi
        if (( millisecsv > millisecsa )) ; then
            millisecs=$millisecsv
        else
            millisecs=$millisecsa
        fi
        let actualsecs=millisecs/1000 1
        ## END Find length using mediainfo
    else
        ## Find length using ffprobe
        # on 2015/11/17 This gave answer of "N/A" for duration after a long delay (several minutes)
        # file was actually corrupt
        eval `ffprobe "$fullfilename" -show_format | egrep '^duration='`
        actualsecs=`echo "$duration / 1" | bc`
        ## END Find length using ffprobe
    fi
    extension=${fullfilename/*./}
    if [[ "$extension" == mkv ]] ; then
        type=Transcode
    else
        type=Recording
    fi
    echo "Full file name: $fullfilename"
    echo "Expected leng(secs): $expectsecs"
    echo "DB Expected leng(secs): $db_expectsecs"
    echo "Actual leng(secs): $actualsecs"
    let minsecs=expectsecs
    echo "Minimum leng(secs): $minsecs - 60"
    let shortmins=(expectsecs-actualsecs)/60
    if (( actualsecs < minsecs - 60 )) ; then
        "$scriptpath/notify.py" "$type failed" "$title $subtitle is $shortmins minutes short"
    fi
    if (( actualsecs > 400 )) ; then
        # Examine 1 minute of audio at 5 minutes in
        # Returns "Mean    norm:          0.010537"
        soxstat=($(ffmpeg -i "$fullfilename" \
            -ss 00:05:00 -t 00:01:00.0 -vn -ac 2 -f au - 2>/dev/null \
            | sox -t au - -t au /dev/null  stat |& grep norm:))
        if [[ ${soxstat[2]} != ?.?????? ]] ; then
            "$scriptpath/notify.py" "sox failed" "$title $subtitle - sox said ${soxstat[@]}"
        elif [[ ${soxstat[2]} < 0.001000 ]] ; then
            "$scriptpath/notify.py" "$type failed" "$title $subtitle has audio level ${soxstat[2]}"
        fi
    fi
    let maxsecs=expectsecs
    if (( db_expectsecs > maxsecs )) ; then
        let maxsecs=db_expectsecs
    fi
    echo "Maximum leng(secs): $maxsecs + 60"
    let overmins=(actualsecs-maxsecs)/60
    if (( actualsecs > maxsecs + 60 )) ; then
        "$scriptpath/notify.py" "$type failed" "$title $subtitle shows $overmins minutes over"
    fi

    # Check if it is x264 file and if so rename to tsx extension
    videoformat=`mediainfo '--Inform=Video;%Format%' "$fullfilename"`
    echo "Episode: $fullfilename. Video Format $videoformat"
    if [[ "$videoformat" == "AVC" && "$extension" == "ts" ]] ; then
        # rename file to tsx extension
        mv -v "$fullfilename" "${fullfilename}x"
        sql1="update recorded set basename = '${filename}x' where basename = '$filename';"
        sql2="update recordedfile set basename = '${filename}x' where basename = '$filename';"
        echo "$sql1"
        echo "$sql2"
        (
          echo "$sql1"
          echo "$sql2"
        ) |  $mysqlcmd
    fi
fi


