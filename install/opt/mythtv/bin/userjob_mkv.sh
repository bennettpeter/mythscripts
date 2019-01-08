#!/bin/bash
# Convert recording to mkv format for kodi
# command line - 
# /opt/mythtv/bin/userjob_recording.sh "%FILE%" "%PROGSTARTISOUTC%" "%PROGENDISOUTC%" "%RECGROUP%" "%TITLE%" "%SUBTITLE%" %CHANID% 
# filename starttime endtime recgroup
# 9999_999999999.mpg YYYY-MM-DDThh:mm:ssZ  YYYY-MM-DDThh:mm:ssZ Default
# 

# Possible improvements TBD
# prevent overwriting prior junk version on rerun
# option to leave out subtitles, will save 1 minute run time per 30 minutes of recording

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo "------START------"
date

# Override to use downloaded ffmpeg
if ! echo $PATH|grep /opt/ffmpeg/bin: ; then
  PATH="/opt/ffmpeg/bin/:$PATH"
fi

echo $0 $1 $2 $3 $4 $5 $6 $7

filename="$1"
starttimeparm="$2"
endtime="$3"
recgroup="$4"
title="$5"
subtitle="$6"
chanid="$7"

wkday=`date +%a`
junktoday=junk$wkday

function errfunc {
    "$scriptpath/notify.py" "userjob_mkv failed" "$title"
    exit 2
}
trap errfunc ERR

starttime=`date -u -d "$starttimeparm" "+%Y-%m-%d %H:%M:%S"`

# echo Set IO priority to -c2 -n7 best effort lowest
# ionice -c2 -n7 -p$$
echo Set IO proority to -c3 idle
ionice -c3 -p$$

if [[ "$recgroup" != "Deleted" && "$recgroup" != "LiveTV" ]] ; then
    # Find the recording file
    #fullfilename=`find "$VIDEODIR" -name "$filename" 2>/dev/null` || true
    fullfilename=`ls "$VIDEODIR"/video*/recordings/"$filename" 2>/dev/null` || true
    echo Found file: $fullfilename .
    fileformat=`mediainfo '--Inform=General;%Format%' "$fullfilename"`
    if [[ "$fileformat" == Matroska ]] ; then
        echo File $fillfilename is already $fileformat
        false
        exit 2
    fi
    # Extract Closed captions 
    subtfile=/tmp/userjob_mkv$$.srt
    nice ccextractor "$fullfilename" -o $subtfile
    bname="${fullfilename%.*}"
    if [[ ! -f $subtfile ]] ; then
        subtfile=
    fi
    # Convert to mkv
    nice mkvmerge -o "$bname".mkv "$fullfilename" --default-track 0:0 $subtfile || rc=$?
    echo RC = $rc
    #if [[ $? != 0 ]] ; then
    #    "$scriptpath/notify.py" "mkv conversion failed" "$title"
    #    exit 2
    #fi
    storagedir=`dirname "$fullfilename"`
    mkdir -p "$storagedir/$junktoday/"
    mv -v "$fullfilename" "$storagedir/$junktoday/" || true
    mv -fv "$bname".mkv "$fullfilename"
    #if [[ $? != 0 ]] ; then
    #    "$scriptpath/notify.py" "file rename failed" "$title"
    #    exit 2
    #fi
    nice mythcommflag --rebuild  --chanid "$chanid" --starttime "$starttime" || echo Return Code is $?
fi

date
echo "------END------"
