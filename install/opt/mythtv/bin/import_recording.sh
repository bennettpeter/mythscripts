#!/bin/bash
# Import a recording into mythtv

set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
# exec 1>>$LOGDIR/${scriptname}.log
# exec 2>&1
# date

filename=
title=
subtitle=
originalairdate=
description=
season=
episode=
action=
cpopt=

while (( "$#" >= 1 )) ; do
    case $1 in
        -i)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -i." ; error=y
            else
                filename="$2"
                shift||rc=$?
            fi
            ;;
        -t)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -t." ; error=y
            else
                title="$2"
                shift||rc=$?
            fi
            ;;
        -s)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -s." ; error=y
            else
                subtitle="$2"
                shift||rc=$?
            fi
            ;;
        -a)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -a." ; error=y
            else
                originalairdate="$2"
                shift||rc=$?
            fi
            ;;
        -d)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -d." ; error=y
            else
                description="$2"
                shift||rc=$?
            fi
            ;;
        -S)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -S." ; error=y
            else
                season="$2"
                shift||rc=$?
            fi
            ;;
        -E)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -E." ; error=y
            else
                episode="$2"
                shift||rc=$?
            fi
            ;;
        -u)
            if [[ "$2" == "" || "$2" == -* ]] ; then echo "ERROR Missing value for -a." ; error=y
            else
                action="$2"
                shift||rc=$?
            fi
            ;;
        -o)
            if [[ "$2" == "" ]] ; then echo "ERROR Missing value for $1." ; error=y
            else
                cpopt="$2"
                shift||rc=$?
            fi
            ;;
        *)
            echo "Invalid option $1"
            error=y
            ;;
    esac
    shift||rc=$?
done

if [[ "$error" == y || "$filename" == "" ]] ; then
    echo "Import video as recording"
    echo "Options"
    echo "-i filename Input file, required."
    echo "-o options cp options, e.g. -l to hard link files."
    echo "-t Title. Default is File directory."
    echo "-s Subtitle. Default is file name excluding leading date and leading SxxExx."
    echo "-a Original Air Date in any format accepted by date command, eg YYYYMMDD YYYY-MM-DD YY-MM-DD."
    echo "-d Description. Optional."
    echo "-S Season. Optional. Default is from filename if it includes S99E99."
    echo "-E Episode. Optional. Default is from filename if it includes S99E99."
    echo "-u Update action."
    echo "   I=insert, U=update, E=update if found otherwise insert. Default blank is prompt"
    echo
    echo "If any field is blank - parse filename in format yymmdd S99E99 subtitle, with title  as"
    echo "  the file directory"
    echo "Update requiers a match on title, subtitle and original air date"
    exit 2
fi


wkday=`date +%a`
junktoday=junk$wkday

echo "$@"

date

# Sample Filename
# Young Sheldon/980430 S03E21 A Secret Letter and a Lowly Disc of Processed Meat.mkv

if [[ "$title" == "" ]] ; then
    canonical=$(readlink -f "$filename")
    dir=$(dirname "$canonical")
    title=$(basename "$dir")
fi
bname=$(basename "$filename")
if [[ "$subtitle" == "" ]] ; then
    subtitle=$(echo "$bname" | sed "s/^[0-9]* //;s/^S[0-9]*E[0-9]* //;s/\.[^.]*$//")
fi
if [[ "$originalairdate" == "" ]] ; then
    originalairdate=$(echo "$bname" | grep -o "^[0-9]* " | sed "s/ //")
    # Correct century?
    if (( originalairdate > 500000 )) ; then
        originalairdate=19$originalairdate
    fi
    originalairdate=$(date -d $originalairdate "+%Y-%m-%d")
fi

if [[ "$season" == "" ]] ; then
    season=$(echo "$bname" | grep -o "S[0-9]*E" | sed "s/S//;s/E//;s/^0*//")
fi
if [[ "$episode" == "" ]] ; then
    episode=$(echo "$bname" | grep -o "E[0-9]* " | sed "s/E//;s/ //;s/^0*//")
fi

# get DB details
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

tmf='+%Y-%m-%d %H:%M:%S'
dtf='+%Y-%m-%d'
fixdate=`date -u --date="$originalairdate" "$dtf"` || echo rc = $rc
if [[ "$fixdate" == "" ]] ; then
    fixdate="$originalairdate"
fi

# see if this episode is already there
set -- `echo "set sql_mode = ''; select chanid, starttime, basename, originalairdate from recorded
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
        echo "$title / $subtitle already exists chanid $chanid starttime $starttime originalairdate $found_originalairdate"
        echo "Will insert another copy"
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
  E)
    if [[ "$chanid" != ""  &&  "$originalairdate" == "$found_originalairdate" ]] ; then
        action=U
    else
        action=I
    fi
    ;;
  '')
    if [[ "$chanid" == "" ]] ; then
        echo "title:$title subtitle:$subtitle originalairdate:$originalairdate season:$season episode:$episode"
        echo "Not Found. Enter I to insert"
        read -e ans
        if [[ "$ans" == I || "$ans" == i ]] ; then
            action=I
        else
            echo "Canceled"
            exit 2
        fi
    else
        echo "$title / $subtitle already exists chanid $chanid starttime $starttime originalairdate $found_originalairdate"
        echo "Enter U to update, I to insert"
        read -e ans
        if [[ "$ans" == U || "$ans" == u ]] ; then
            action=U
        elif [[ "$ans" == I || "$ans" == i ]] ; then
            action=I
        else
            echo "Canceled"
            exit 2
        fi
    fi
    ;;
  *)
    echo "ERROR Invalid Action $action"
    exit 2
    ;;
esac
echo action $action

ext=${filename/*./}
storagedir="$IMPORTDIR"
mkdir -p $storagedir

if [[ "$action" == I ]] ; then
    if [[ "$season" == "" ]] ; then
        season=0
    fi
    if [[ "$episode" == "" ]] ; then
        episode=0
    fi
    # sleep 2 sec to make sure no two files get the same name
    sleep 2
    fntmf='+%Y%m%d%H%M%S'
    time=`date -u -d "2 hours ago" +%s`
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
    sql1="set sql_mode = '';
    INSERT INTO recorded
    (chanid,starttime,endtime,title,subtitle,description,season,episode,category,hostname,bookmark,
    editing,cutlist,autoexpire,commflagged,recgroup,recordid,seriesid,programid,inetref,lastmodified,
    filesize,stars,previouslyshown,originalairdate,preserve,findid,deletepending,transcoder,timestretch,
    recpriority,basename,progstart,progend,playgroup,profile,duplicate,transcoded,watched,storagegroup,
    bookmarkupdate,
    recgroupid,recordedid,inputname )
    VALUES(
    $chanid,'$starttime','$endtime',\"$title\",\"$subtitle\",\"$description\",$season,$episode,'','$LocalHostName',0,
    0,0,0,0,'Default',0,'','','',CURRENT_TIMESTAMP,
    $filesize,0,0,'$originalairdate',0,0,0,0,1,
    0,'$basename','$starttime','$endtime','Default','Default',1,0,0,'Default',
    '0000-00-00 00:00:00',
    1,0,'Import');"

    sql2="INSERT INTO oldrecorded
    (chanid,starttime,endtime,title,subtitle,description,season,episode,category,
    seriesid,programid,inetref,
    findid,recordid,station,rectype,duplicate,recstatus,reactivate,generic,future
    )
    VALUES(
    $chanid,'$starttime','$endtime',\"$title\",\"$subtitle\",\"$description\",$season,$episode,'',
    '','','',
    0,0,'DOWNLOAD',4,1,-3,0,0,0
    );"

    if [[ -f "$storagedir/$basename" ]] ; then
        echo ERROR "$storagedir/$basename" already exists.
        exit 2
    fi

    cp -nvL $cpopt "$filename" "$storagedir/$basename"

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
    # Remove part after decimal
    durationmilli="${durationmilli%.*}"
    let duration=durationmilli/1000
    time=`date -u "--date=$starttime" +%s`
    let end_time=time+duration
    endtime=`date -u --date=@$end_time "$tmf"`
    set -- `ls -l "$filename"`
    filesize=$5

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

    if [[ -f "$storagedir/$basename" ]] ; then
        echo ERROR "$storagedir/$basename" already exists.
        exit 2
    fi

    cp -nvL $cpopt "$filename" "$storagedir/$newbasename"

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

