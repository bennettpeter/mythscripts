#!/bin/bash
# Daily Export files for transcoding if required

set -e
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

mustecho=
mustdelete=Y
# testing ###
# mustecho=echo
# mustdelete=N

linksrun=N
mounted=N
exportdir="$LINKSDIR"/tcexport/
accumsize=0
accummins=0
files=0
hostname=`cat /etc/hostname`
wkday=`date +%a`
junktoday=junk$wkday

# This will return server name for an NFS mount, 
# the string "UUID" for a local mount, empty for a mismatch
tcserver=`grep " $TCMOUNTDIR" /etc/fstab|sed 's/:.*//;s/=.*//'`

if [[ "$tcserver" == "" ]] ; then
    echo "ERROR, no match found for mount directory $TCMOUNTDIR , aborting"
    exit 2
fi

if [[ "$tcserver" == UUID ]] ; then
    symlinks="-s"
else
    symlinks=
fi

starttime=`date "+%Y-%m-%d_%H:%M:%S"`
schedstart=`date -d "$WAKEUPTIME" "+%Y-%m-%d_%H:%M:%S"`
latestart=`date -d "+2hour $WAKEUPTIME" "+%Y-%m-%d_%H:%M:%S"`
verylatestart=`date -d "+12hour $WAKEUPTIME" "+%Y-%m-%d_%H:%M:%S"`
maxminutes=$TCMAXMINUTES
maxsize=$TCMAXSIZE
if [[ "$starttime" > "$latestart" ]] ; then
    let maxminutes=maxminutes/2
    let maxsize=maxsize/2
fi
if [[ "$starttime" > "$verylatestart" ]] ; then
    maxminutes=60
fi

function wakeup_server {
    if [[ "$tcserver" == UUID ]] ; then
        mounted=Y
        return
    fi
    if [[ "$mounted" == N ]] ; then
        "$scriptpath/wakeup.sh" $tcserver
        for try in 1 2 3 4 5 6 7 8 9 ; do
            mount "$TCMOUNTDIR" || true
            if [[ `echo "$TCMOUNTDIR"/*` != "$TCMOUNTDIR/*" ]] ; then
                break;
            fi
            sleep 10
        done
#        echo "$hostname" > "$TCSTORAGEDIR/keepalive/$hostname"
        mounted=Y
    fi
}

function exitfunc {
    if [[ "$mounted" == Y ]] ; then
#        rm -f "$TCSTORAGEDIR/keepalive/$hostname"
        if [[ "$tcserver" != UUID ]] ; then
            umount "$TCMOUNTDIR" || true
        fi
        mounted=N
    fi
}
trap 'exitfunc' EXIT

if [[ -f "$DATADIR"/mustrun_tcimport ]] ; then
    wakeup_server
    "$scriptpath"/tcimport.sh "" "$mustdelete"
    if [[ $? != 0 ]] ; then echo ERROR ; exit 2 ; fi
    rm -f "$DATADIR"/mustrun_tcimport
elif ls "$VIDEODIR"/*/recordings/$junktoday/* ; then
    echo "Deleting prior run junk files from $VIDEODIR"
    rm -fv "$VIDEODIR"/*/recordings/$junktoday/*
fi

# Get percentage utilization of the video file systems
# This asumes that nothing other than video directories is under VIDEODIR
set -- `df -k --total  $VIDEODIR/*/recordings|grep total`
percentused=${5%\%}
echo "Video percentage used: $percentused"
set -- `du -k --total "$VIDEODIR"/*/recordings/junk*/ | tail -1`
junkKB=$1
if (( junkKB > 10240 && percentused > 2 )) ; then
    let percentused-=2
    echo "Adjusted Video percentage used: $percentused (junk = ${junkKB}KB)"
fi
for (( stage=0 ; stage<10 ; stage=stage+1 )) ; do
    if [[ "${TCPERCENT[stage]}" == "" ]] ; then
        break;
    fi
    if (( percentused > TCPERCENT[stage] )) ; then
        delay=${TCDELAY[stage]}
        # lastdate=`date --date=${TCDELAY[stage]}' days ago' '+%y%m%d'`
        lastdate=`date --date=$delay' days ago' '+%y%m%d'`
        if [[ "$linksrun" == N ]] ; then
            "$scriptpath/mythlinks.sh" airdate
            linksrun=Y
        fi        
        rm -rf "$exportdir"
        mkdir -p "$exportdir"/done
        cd "$LINKSDIR"/airdate
        # Move selected episodes to LINKSDIR/tcexport/ ($exportdir)
        for group in * ; do
            if  echo "${TCGROUP[stage]}" | grep '|'"$group"'|'  ; then
                for episode in "$group"/*/* ; do
                    # Example of episode - 'x264/Dallas/140301-1100 140301 The name.mpg'
                    # remove reverse quotes and quotes - change to apostrophes
                    fixepisode=$(echo "$episode" | sed -e "s/\`/'/g;s/\"/'/g")
                    if [[ "$episode" != "$fixepisode" ]] ; then 
                        mv "$episode" "$fixepisode"
                        episode="$fixepisode"
                    fi
                    epdate=`echo "$episode"|sed 's~.*/.*/~~;s~ .*$~~'`
                    # Example of epdate - '20140301-1100'
                    newname="$epdate "`echo "$episode"|sed "s~/~ - ~g;s~$epdate~~"`
                    # Example of newname - '20140301-1100 x264 - Dallas - 140403 The name.mpg'
                    # Suggest change to mv 11/1/2015 
                    cp -nd "$episode" "$exportdir/$newname"
                    # mv -n "$episode" "$exportdir/$newname"
                    epbname=`basename "${newname%.*}"`
                    # echo $group > "$exportdir/$epbname.group" 
                    echo "RECGROUP=$group" > "$exportdir/$epbname.settings" 
                    echo "FULLNAME=\"$episode\"" >> "$exportdir/$epbname.settings" 
                done
            fi
        done
        cd "$exportdir"
        counter=0
        for episode in * ; do
            # Example of episode - '20140301-1100 x264 - Dallas - 140403 The name.mpg'
            if [[ "$episode" == ${TCMATCH[stage]} && "$episode" != *.settings ]] ; then
                if [[ "$episode" < "$lastdate" ]] ; then
                    if [[ "$mounted" == N ]] ; then
                        wakeup_server
                        if  ls "$TCSTORAGEDIR/$TCSUBDIR"/*.@(mpg|ts|tsx|mkv|mp4) 2>/dev/null ; then
                            echo "ERROR There are prior transcode files already in $TCSTORAGEDIR/$TCSUBDIR , aborting"
                            "$scriptpath/notify.py" "tcdaily failed" "There are prior transcode files already in $TCSTORAGEDIR/$TCSUBDIR"
                            exit 2
                        fi
                        echo "Deleting prior run junk files"
                        rm -fv "$TCSTORAGEDIR/$TCSUBDIR/$junktoday"/*
                    fi
                    set -- `ls -lL "$episode"`
                    filesize="$5"
                    millisecsv=`mediainfo '--Inform=Video;%Duration%' "$episode"`
                    # Remove decimal part if present
                    millisecsv=`echo $millisecsv|sed 's/\..*//'`
                    # 21600000 = 6 hours
                    if (( millisecsv > 21600000 )) ; then
                        echo "Wacky video length of $millisecsv ignored, set to 60000"
                        # 60000 = 1 minute
                        millisecsv=60000
                    fi
                    #on 2015/11/17 This gave answer of 36268563626856 for audio duration
                    # stupid - that was because there are 2 audio streams 3626856 and 3626856
                    # the tab and cut is to select just the first audio stream length
                    millisecsa=`mediainfo '--Inform=Audio;%Duration%'$'\t' "$episode" | cut -f 1`
                    # Remove decimal part if present
                    millisecsa=`echo $millisecsa|sed 's/\..*//'`
                    # 21600000 = 6 hours
                    if (( millisecsa > 21600000 )) ; then
                        echo "Wacky audio length of $millisecsa ignored, set to 60000"
                        # 60000 = 1 minute
                        millisecsa=60000
                    fi
                    if (( millisecsv > millisecsa )) ; then
                        millisecs=$millisecsv
                    else
                        millisecs=$millisecsa
                    fi
                    let minutes=millisecs/60000 1
                    #on 2015/11/17 This gave answer of "N/A" for duration after a long delay (several minutes)
                    #duration=0
                    #eval `ffprobe "$episode" -show_format | egrep '^duration='`
                    #minutes=`echo "$duration / 60" | bc`
                    echo "Episode $episode is $minutes minutes long, file size is $filesize."
                    if (( minutes < 5 )) ; then
                        echo "Episode $episode is less than 5 minutes, skipping."
                        continue
                    fi
                    if (( accumsize+filesize > maxsize )) ; then
                        if [[ "$files" == 0 ]] ; then
                            "$scriptpath/notify.py" "tcdaily warning"  "Episode $episode file size is too large, $filesize, skipping."
                            continue
                        fi
                        echo "Maximum data size reached."
                        break 2;
                    fi
                    if (( accummins+minutes > maxminutes )) ; then
                        if [[ "$files" == 0 ]] ; then
                            "$scriptpath/notify.py" "tcdaily warning" "Episode $episode duration is too large, $minutes minutes, force copy."
                        else
                            echo "Maximum number of minutes reached."
                            break 2;
                        fi 
                    fi
                    videoformat=`mediainfo '--Inform=Video;%Format%' "$episode"`
                    extension=${episode/*./}
                    echo "Episode: $episode. Video Format $videoformat"
                    if [[ "$videoformat" != "MPEG Video" && "$extension" == "ts" ]] ; then
                        "$scriptpath/notify.py" "tcdaily warning" \
                            "Episode $episode wrong extension. Format is $videoformat. Continuing anyway."
                    fi
                    filename=`readlink "$episode"`
                    bname=`basename "$filename"`
                    if [[ "$TCSKIPCHAN" != "" && "$bname" == ${TCSKIPCHAN}_* ]] ; then
                        echo "$episode - $bname is recorded from VOD, skip"
                    elif [[ -f "$TCSTORAGEDIR/$TCSUBDIR"/${bname}_failed ]] ; then
                        "$scriptpath/notify.py" "Transcode failed" "$episode - $bname"
                        mv -f "$TCSTORAGEDIR/$TCSUBDIR"/${bname}_failed "$TCSTORAGEDIR/$TCSUBDIR"/${bname}_failed_reported
                    elif [[ -f "$TCSTORAGEDIR/$TCSUBDIR"/${bname}_failed_reported ]] ; then
                        echo "Already reported failed $episode - $bname , skip"
                    elif [[ -f "$TCSTORAGEDIR/$TCSUBDIR"/${bname} ]] ; then
                        echo "Already copied $episode - $bname , skip"
                    elif [[ -f "$TCSTORAGEDIR/$TCSUBDIR"/${bname}_done ]] ; then
                        echo "Already transcoded $episode - $bname , skip"
                    else
                        epbname=`basename "${episode%.*}"`
                        . "$epbname.settings"
                        $mustecho cp -f -v $symlinks "$filename" "$TCSTORAGEDIR/$TCSUBDIR/"
                        bname="${bname%.*}"
                        optname=$RECGROUP
                        if [[ ! -f "/etc/opt/mythtv/$optname.options" ]] ; then
                            optname=Default
                        fi
                        $mustecho ln -s -f -v "/etc/opt/mythtv/$optname.options" \
                            "$TCSTORAGEDIR/$TCSUBDIR/$bname.options"
                        $mustecho cp -f "$epbname.settings" "$TCSTORAGEDIR/$TCSUBDIR/$bname.settings"
                        let files=files+1 1
                        let accumsize=accumsize+filesize 1
                        let accummins=accummins+minutes 1
                    fi
                    $mustecho mv -f "$episode" done/
                fi
            fi
        done
    fi
done

if (( files > 0 )) ; then
    echo "run" > "$TCSTORAGEDIR/$TCSUBDIR"/mustrun_tcencode
    echo "run" > "$DATADIR"/mustrun_tcimport
fi

echo $files files, size $accumsize bytes, length $accummins minutes copied to "$TCSTORAGEDIR/$TCSUBDIR/"

