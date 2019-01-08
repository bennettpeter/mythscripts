#!/bin/bash
# Import a recording into mythtv
# command line - 
# 
set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1
# date

filename="$1"
title="$2"
subtitle="$3"
originalairdate="$4"
description="$5"
action="$6"

wkday=`date +%a`
junktoday=junk$wkday

echo "$@"

if [[ "$filename" == "" || "$title" == "" ]] ; then
    echo Usage
    echo "$0 filename title subtitle originalairdate description action(I/U/E)"
    echo "I=insert,U=update,E=either default blank is prompt"
    echo "To match existing recording - title, subtitle and originalairdate must match"
    exit 2
fi
date
# get DB details
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

tmf='+%Y-%m-%d %H:%M:%S'
dtf='+%Y-%m-%d'
originalairdate=`date -u --date="$originalairdate" "$dtf"`

# see if this episode is already there
set -- `echo "select chanid, starttime, basename, originalairdate from recorded 
  where title = \"$title\" and subtitle = \"$subtitle\" and originalairdate = \"$originalairdate\"
  order by starttime asc limit 1;" | \
  $mysqlcmd | tail -1`
chanid=$1
starttime="$2 $3"
basename="$4"
found_originalairdate="$5"

case $action in 
  I)
    if [[ "$chanid" != "" ]] ; then
        echo "Error $title / $subtitle already exists chanid $chanid starttime $starttime originalairdate $found_originalairdate"
        exit 2
    fi
    ;;
  U)
    if [[ "$chanid" == "" ]] ; then
        echo "Error $title / $subtitle not found, cannot update"
        exit 2
    fi
    if [[ "$originalairdate" != "$found_originalairdate" ]] ; then
        echo "Error $title / $subtitle , originalairdate discrepancy $originalairdate found: $found_originalairdate cannot update"
        exit 2
    fi
    ;;
  *)
    if [[ "$chanid" == "" ]] ; then
        echo "$title / $subtitle not found"
        echo "Enter Y to insert"
        read -e ans
        if [[ "$ans" == Y || "$ans" == y ]] ; then
            action=I
        else
            echo "Canceled"
            exit 2
        fi
    else
        echo "$title / $subtitle already exists chanid $chanid starttime $starttime originalairdate $found_originalairdate"
        echo "Enter Y to update"
        read -e ans
        if [[ "$ans" == Y || "$ans" == y ]] ; then
            action=U
        else
            echo "Canceled"
            exit 2
        fi
    fi
    ;;
esac
echo action $action

ext=${filename/*./}
storagedir="$IMPORTDIR"
mkdir -p $storagedir

if [[ "$action" == I ]] ; then
    # sleep 2 sec to make sure no two files get the same name
    sleep 2
    fntmf='+%Y%m%d%H%M%S'
    time=`date -u +%s`
    chanid=$VODCHAN
    starttime=`date -u --date=@$time "$tmf"`
    durationmilli=`mediainfo '--Inform=Video;%Duration%' "$filename"|cut -d . -f 1`
    if [[ "$durationmilli" == "" ]] ; then
        durationmilli=`mediainfo '--Inform=Audio;%Duration%' "$filename"|cut -d . -f 1`
    fi
    set -- `ls -l "$filename"`
    filesize=$5
    let duration=durationmilli/1000
    let end_time=time+duration
    endtime=`date -u --date=@$end_time "$tmf"`
    fntime=`date -u --date=@$time "$fntmf"`

    basename=${VODCHAN}_${fntime}.$ext
    newbasename=$basename
    sql1="INSERT INTO recorded
    (chanid,starttime,endtime,title,subtitle,description,season,episode,category,hostname,bookmark,
    editing,cutlist,autoexpire,commflagged,recgroup,recordid,seriesid,programid,inetref,lastmodified,
    filesize,stars,previouslyshown,originalairdate,preserve,findid,deletepending,transcoder,timestretch,
    recpriority,basename,progstart,progend,playgroup,profile,duplicate,transcoded,watched,storagegroup,
    bookmarkupdate,
    recgroupid,recordedid,inputname )
    VALUES(
    $chanid,'$starttime','$endtime',\"$title\",\"$subtitle\",\"$description\",0,0,'','$LocalHostName',0,
    0,0,0,0,'Default',0,'','','',CURRENT_TIMESTAMP,
    $filesize,0,0,'$originalairdate',0,0,0,0,1,
    0,'$basename','$starttime','$endtime','Default','Default',1,0,0,'Default',
    null,
    1,0,'Import');"

    sql2="INSERT INTO oldrecorded
    (chanid,starttime,endtime,title,subtitle,description,season,episode,category,
    seriesid,programid,inetref,
    findid,recordid,station,rectype,duplicate,recstatus,reactivate,generic,future
    )
    VALUES(
    $chanid,'$starttime','$endtime',\"$title\",\"$subtitle\",\"$description\",0,0,'',
    '','','',
    0,0,'DOWNLOAD',4,1,-3,0,0,0
    );"

    cp -ivLp "$filename" "$storagedir/$basename"
    # ffmpeg -i "$filename" -acodec copy -vcodec copy -scodec copy \
    #  -f mpeg -bsf:v h264_mp4toannexb "$storagedir/$basename" 

    echo sudo chown mythtv "$storagedir/$basename"
    sudo chown mythtv "$storagedir/$basename"
    echo "$sql1"
    echo "$sql2"
    (
      echo "$sql1"
      echo "$sql2"
    ) |  $mysqlcmd

    # Get the recorded id
    set -- `echo "select recordedid from recorded where basename = '$basename';" | \
    $mysqlcmd | tail -1`
    recordedid=$1

    myuser=`id -u -n`
    echo "General;%FileSize%,'%Format%'," > /tmp/${myuser}_mediainfo.parm
    echo "Video;%Width%,%Height%,%FrameRate%,%Width%/%Height%,'%Format%'," >> /tmp/${myuser}_mediainfo.parm
    echo "Audio;'%Format%'" >> /tmp/${myuser}_mediainfo.parm

    mediainfo "--Inform=file:///tmp/${myuser}_mediainfo.parm" "$storagedir/$basename" > /tmp/${myuser}_mediainfo.out 

    sql3="INSERT INTO recordedfile
    (basename, filesize, container, width, height, fps, aspect, video_codec, audio_codec, audio_sample_rate, audio_channels,  comment, hostname, storagegroup, id, recordedid,  total_bitrate, video_avg_bitrate, video_max_bitrate, audio_avg_bitrate, audio_max_bitrate)
    VALUES( '$basename', "`cat /tmp/${myuser}_mediainfo.out`", 0,0,'','$LocalHostName','Default',0,
    $recordedid,0,0,0,0,0);"

    echo "$sql3" 
    echo "$sql3" | $mysqlcmd
        
fi

if [[ "$action" == U ]] ; then
    durationmilli=`mediainfo '--Inform=Video;%Duration%' "$filename"`
    let duration=durationmilli/1000
    time=`date -u "--date=$starttime" +%s`
    let end_time=time+duration
    endtime=`date -u --date=@$end_time "$tmf"`
    set -- `ls -l "$filename"`
    filesize=$5

    # oldfile=`find "$VIDEODIR" -name $basename ! -path '*/junk*/*' 2>/dev/null` || true
    oldfile=`ls "$VIDEODIR"/video*/recordings/"$basename" 2>/dev/null` || true
    numfound=`echo "$oldfile"|wc -l`
    if (( numfound > 1 )) ; then
        echo "ERROR Multiple files match $basename"
        exit 2
    fi
    if [[ "$oldfile" == "" ]] ; then
        storagedir="$IMPORTDIR"
    else
        storagedir=`dirname "$oldfile"`
    fi        
    newbasename="${basename%.*}".$ext
    sql1="UPDATE recorded set basename = '$newbasename', endtime = '$endtime', filesize = $filesize where chanid = '$chanid' and starttime = '$starttime' ;" 
    # Need to fix other fields on recordedfile
    sql2="update recordedfile set basename = '$newbasename', filesize = $filesize, video_codec = 'H264' where basename = '$basename';"
    mkdir -p "$storagedir/$junktoday/"
    mv -fv "$storagedir/$basename"* "$storagedir/$junktoday/" || true
    cp -ivLp "$filename" "$storagedir/$newbasename"
    # ffmpeg -i "$filename" -acodec copy -vcodec copy -scodec copy \
    #  -f mpeg -bsf:v h264_mp4toannexb "$storagedir/$newbasename" 

    echo sudo chown mythtv:mythtv "$storagedir/$newbasename"
    sudo chown mythtv:mythtv "$storagedir/$newbasename"
    echo "$sql1"
    echo "$sql2"
    (
      echo "$sql1"
      echo "$sql2"
    ) |  $mysqlcmd
fi

mythutil --clearseektable --chanid "$chanid" --starttime "$starttime"
# $scriptpath/repair_duration.sh $storagedir/$newbasename

echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
echo Make sure the program is not busy being transcoded at this time
echo XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX

