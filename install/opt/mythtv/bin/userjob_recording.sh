#!/bin/bash
# Job to check if a recording was successuly
# command line - 
# /opt/mythtv/bin/userjob_recording.sh "%FILE%" "%PROGSTARTISOUTC%" "%PROGENDISOUTC%" "%RECGROUP%" "%TITLE%" "%SUBTITLE%" 
# filename starttime endtime recgroup
# 9999_999999999.mpg YYYY-MM-DDThh:mm:ssZ  YYYY-MM-DDThh:mm:ssZ Default
# 
. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
date

# Override to use downloaded ffmpeg
if ! echo $PATH|grep /opt/ffmpeg/bin: ; then
  PATH="/opt/ffmpeg/bin/:$PATH"
fi

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
set -- `echo "select duplicate from recorded where basename = '$filename';" | \
$mysqlcmd | tail -1`
duplicate=$1

echo "Filename: $filename   duplicate: $duplicate"

# Check if Mythtv has flagged it as failed
if [[ "$duplicate" != 1 ]] ; then
    "$scriptpath/notify.py" "Recording failed" "$title $subtitle has duplicate = $duplicate, should be 1"
fi

use_mediainfo=N

if [[ "$recgroup" != "Deleted" && "$recgroup" != "LiveTV" ]] ; then
    # Calculate recording time 
    starttimesecs=`date -d "$starttime" "+%s"`
    endtimesecs=`date -d "$endtime" "+%s"`
    let expectsecs=endtimesecs-starttimesecs
    # Find the recording file
    fullfilename=`find "$VIDEODIR" -name "$filename" 2>/dev/null`
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
    echo "Full file name: $fullfilename"
    echo "Expected leng(secs): $expectsecs"
    echo "Actual leng(secs): $actualsecs"
    let minsecs=expectsecs-60
    echo "Minimum leng(secs): $minsecs"
    let shortmins=(expectsecs-actualsecs)/60
    if (( actualsecs < minsecs )) ; then
        "$scriptpath/notify.py" "Recording failed" "$title $subtitle is $shortmins minutes short"
    fi
fi

    

