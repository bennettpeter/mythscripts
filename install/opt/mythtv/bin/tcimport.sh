#!/bin/bash
# Import files from transcoding
# if the mount directory is local, then files that are links will be 
# moved not copied.

# Format of options file
# ENCODER_OPTIONS[0]="-l 480 -E lame"
## ENCODER_OPTIONS defaults to empty.
## For entries 1 - 9, encode will only be done if ENCODER_OPTIONS is not empty
# SAVE_TRANSCODE[0]=Y
## SAVE_TRANSCODE defaults to N
# IMPORT_TRANSCODE[0]=N
## IMPORT_TRANSCODE defaults to Y
# Above repeated for 1 - 9 as required
# NEW_RECGROUP=Default
## NEW_RECGROUP is not subscripted and applies to any transcode
## NEW_RECGROUP defaults to nothing. 
## If all SAVE_TRANSCODE are N, NEW_RECGROUP is set to Default

set -e

. /etc/opt/mythtv/mythtv.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`

# Override to use downloaded ffmpeg
if ! echo $PATH|grep /opt/ffmpeg/bin: ; then
  PATH="/opt/ffmpeg/bin/:$PATH"
fi

wkday=`date +%a`
junktoday=junk$wkday

echo "Import files after transcoding"
echo  "Input parameters "
echo "1 Override mount directory (optional). Default is $TCMOUNTDIR"
echo "2 Delete files from prior run at start Y or N, default will prompt at end"

mountdir="$TCMOUNTDIR"

if [[ "$1" != "" ]] ; then
    mountdir="$1"
fi

mustdelete=$2

mount "$mountdir" || true

# This will return server name for an NFS mount, 
# the string "UUID" for a local mount, empty for a mismatch
tcserver=`grep " $mountdir" /etc/fstab|sed 's/:.*//;s/=.*//'`

if [[ "$tcserver" == "" ]] ; then
    echo "ERROR, no match found for mount directory $mountdir , aborting"
    exit 2
fi

# Get DB password from /etc/mythtv/mysql.txt
# . /etc/mythtv/mysql.txt
. $scriptpath/getconfig.sh

mysqlcmd="mysql --user=$DBUserName --password=$DBPassword --host=$DBHostName $DBName"

mythver=`mythutil --version|grep "MythTV Version"|sed -e "s/MythTV Version : v//"`

if [[ "$mustdelete" == Y || "$mustdelete" == y ]] ; then
    echo "Deleting prior run junk files from $VIDEODIR and $mountdir"
    rm -fv "$VIDEODIR"/*/recordings/$junktoday/*
    rm -fv "$mountdir/$TCSUBDIR/$junktoday"*/*
fi

if [[ `echo "$mountdir/$TCSUBDIR"/*.@(mkv|mpg|mp4|ts|tsx)` != \
         "$mountdir/$TCSUBDIR/*.@(mkv|mpg|mp4|ts|tsx)" \
   || -f "$mountdir/$TCSUBDIR/mustrun_tcencode" ]] ; then
    echo "WARNING: Cannot process tcimport, tcencode is not complete"
    "$scriptpath/notify.py" "tcimport failed" "Cannot process tcimport, tcencode is not complete"
    exit 99
fi

for (( counter=0 ; counter<10 ; counter++ )) ; do
    if (( counter == 0 )) ; then
        encodedir=encode
        junkdir=$junktoday
    else
        encodedir=encode$counter
        junkdir=$junktoday$counter
    fi
    
    if [[ ! -d "$mountdir/$TCSUBDIR/$encodedir" ]] ; then
        continue
    fi
    cd "$mountdir/$TCSUBDIR/$encodedir"
    mkdir -p "$mountdir/$TCSUBDIR/$junkdir"

    if  ls *.@(mkv|mp4) >/dev/null 2>/dev/null ; then 
        maindir="$PWD"
        for file in *.@(mkv|mp4) ; do
            if [[ -L "$file" && "$tcserver" == UUID ]] ; then
                realfilepath=`readlink -e "$file"`
                realfile=`basename "$realfilepath"`
                realdir=`dirname "$realfilepath"`
                followlinks=Y
            else
                realfile="$file"
                realdir="$maindir"
                followlinks=N
            fi
            basename="${realfile%.*}"
            # settings will set these variables: RECGROUP, FULLNAME
            . "../$basename.settings"
            IMPORT_TRANSCODE[$counter]=Y
            SAVE_TRANSCODE[$counter]=N
            unset NEW_RECGROUP
            . "../$basename.options" || true
            for xyz in "${IMPORT_TRANSCODE[@]}"; do
                if [[ "$xyz" == Y ]] ; then
                    break;
                fi
            done            
            if [[ "$xyz" != Y  && "$NEW_RECGROUP" == "" ]] ; then
                NEW_RECGROUP=Default
            fi
            if [[ "${SAVE_TRANSCODE[counter]}" = Y ]] ; then
                # example FULLNAME
                # FULLNAME="x4a/Father Brown/150919-1800 150108 SE The Sign of the Broken Sword.mpg"
                savedir=`dirname "$FULLNAME"`
                mkdir -p "$mountdir/$TCSUBDIR/save$counter/$savedir"
                # savewild is full name without extension
                savewild="${FULLNAME%.*}"
                for xyz in "$realdir/$basename".* ; do
                    saveext=${xyz/*./}
                    if [[ "$saveext" == log || "$saveext" == tmp ]] ; then
                        continue
                    fi
                    # Remove recording date & time from front of name.
                    newname=`echo "$savewild" | sed 's!/[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9] !/!'`
                    # Remove SE if there is no episode info
                    newname=`echo "$newname" | sed 's!/\([0-9][0-9][0-9][0-9][0-9][0-9]\) SE !/\1 !'`
                    # In case there are duplicates of the same name (e.g. recording was split in 2), keep full name.
                    if [[ -f "$mountdir/$TCSUBDIR/save$counter/$newname.$saveext" ]] ; then
                        mv -v --backup=numbered "$mountdir/$TCSUBDIR/save$counter/$newname.$saveext" \
                              "$mountdir/$TCSUBDIR/save$counter/$newname Part 1.$saveext"
                    fi
                    if [[ -f "$mountdir/$TCSUBDIR/save$counter/$newname Part 1.$saveext" ]] ; then
                        lastnum=`echo "$mountdir/$TCSUBDIR/save$counter/$newname Part "?."$saveext" \
                          | sed "s/.* //;s/\..*//"`
                        if [[ "$lastnum" == "?" ]] ; then
                            lastnum=0
                        fi
                        if (( lastnum > 0 )) ; then
                            let lastnum=lastnum+1
                            newname="$newname Part $lastnum"
                        fi
                    fi
                    ln -v --backup=numbered "$xyz" "$mountdir/$TCSUBDIR/save$counter/$newname.$saveext"
                done
            fi
            if [[ "${IMPORT_TRANSCODE[counter]}" == Y ]] ; then
                cd "$realdir"
                oldfile=`find "$VIDEODIR" -name $realfile 2>/dev/null` || true
                if [[ "$oldfile" == "" ]] ; then
                    oldfile=`find "$VIDEODIR" -name $basename.mpg -o -name $basename.ts \
                       -o -name $basename.tsx 2>/dev/null` || true
                fi
                if [[ -f "$oldfile" ]] ; then
                    duration=0
                    eval `ffprobe "$realfile" -show_format | egrep '^duration='`
                    if [[ `echo "$duration < 300" | bc` == 1 ]] ; then
                        echo "ERROR: duration less than 5 minutes for $realfile"
                        "$scriptpath/notify.py" "tcimport warning error" "ERROR: duration less than 5 minutes for $realfile $FULLNAME"
                        origtcfile=`echo ../"$basename".@(mkv_done|mpg_done|mp4_done|ts_done)`
                        neworigtcname=${origtcfile%_done}_failed_reported
                        # Rename source file from ../3707_20151118020000.mpg_done to ../3707_20151118020000.mpg_failed_reported 
                        mv -fv "$origtcfile" "$neworigtcname" || echo Return Code is $?
                        # Also rename encoded file
                        mv -fv $realfile ${realfile}_failed_reported
                        continue
                    fi
                    storagedir=`dirname "$oldfile"`
                    oldbname=`basename "$oldfile"`
                    mkdir -p "$storagedir/$junktoday/"
                    if [[ "$realfile" == "$oldbname" ]] ; then
                        mv -n "$oldfile" "${oldfile}_0"
                        oldfile="${oldfile}_0"
                    fi
                    if [[ "$followlinks" == Y ]] ; then
                        mv -fv "$realfile" "$storagedir/"
                    else
                        cp -fvL "$realfile" "$storagedir/"
                    fi
                    # This may fail on an imported file
                    chmod +r "$storagedir/$realfile"
                    chmod g+w "$storagedir/$realfile"
                    chgrp mythtv "$storagedir/$realfile"
                    # Find the chanid and starttime for the file
                    set -- `echo "select chanid, starttime from recorded where basename like '$basename.%';" | \
                    $mysqlcmd | tail -1`
                    chanid=$1
                    starttime="$2 $3"
                    echo "update recorded set basename = '$realfile', transcoded = 1 where basename like '$basename.%';" | \
                    $mysqlcmd
                    if [[ "$mythver" != 0.27* ]] ; then
                        echo "update recordedfile set basename = '$realfile' where basename like '$basename.%';" | \
                        $mysqlcmd
                    fi
                    mythcommflag --rebuild  --chanid "$chanid" --starttime "$starttime" || echo Return Code is $?
                    # Fix duration
                    # duration=`mediainfo '--Inform=Video;%Duration%' "$storagedir/$realfile"` || echo Return Code is $?
                    millisecsv=`mediainfo '--Inform=Video;%Duration%' "$storagedir/$realfile"`
                    # 21600000 = 6 hours
                    if (( millisecsv > 21600000 )) ; then
                        echo "Wacky video length of $millisecsv ignored, set to 0"
                        # 60000 = 1 minute
                        millisecsv=0
                    fi
                    # the tab and cut is to select just the first audio stream length
                    millisecsa=`mediainfo '--Inform=Audio;%Duration%'$'\t' "$storagedir/$realfile" | cut -f 1`
                    # 21600000 = 6 hours
                    if (( millisecsa > 21600000 )) ; then
                        echo "Wacky audio length of $millisecsa ignored, set to 0"
                        millisecsa=0
                    fi
                    if (( millisecsv > millisecsa )) ; then
                        duration=$millisecsv
                    else
                        duration=$millisecsa
                    fi
                    if (( duration == 0 )) ; then
                        echo "Error no duration found for $file"
                    else
                        ## Add 5 minutes
                        ## - not needed     let duration=duration+300000
                        echo "update recordedmarkup set data = '$duration' " \
                            "where chanid = '$chanid' and starttime = '$starttime' and type = '33' and mark = '0';" | \
                        $mysqlcmd
                    fi
                    mv -fv "$oldfile"* "$storagedir/$junktoday/" || true
                else
                    echo "No match for $file"
                    cd "$maindir"
                    continue
                fi
            fi
            cd "$maindir"
            mv -fv "$file" "$file"_encdone
            mv -fv "$basename"* "$mountdir/$TCSUBDIR/$junkdir/"
            if [[ "$NEW_RECGROUP" != "" ]] ; then
                if [[ "$NEW_RECGROUP" == Deleted ]] ; then
                    sql_extra=", autoexpire = 9999 "
                else
                    sql_extra=
                fi
                set -- `echo "select recgroupid from recgroups where recgroup = '$NEW_RECGROUP';" | \
                    $mysqlcmd | tail -1`
                recgroupid=$1
                echo "update recorded set recgroup = '$NEW_RECGROUP', 
                      recgroupid = $recgroupid $sql_extra 
                      where basename like '$basename.%';" | \
                    $mysqlcmd
            fi
        done
    fi
done
if ls "$mountdir/$TCSUBDIR/"*_done ; then
    for file in "$mountdir/$TCSUBDIR/"*_done ; do
        bname="${file%.*}"
        mv -fv "$bname".* "$mountdir/$TCSUBDIR/$junktoday/" 
    done
fi
echo "Files ready to delete"
cd "$VIDEODIR"
ls -l  "$mountdir/$TCSUBDIR/$junktoday"*/* || true
if [[ "$mustdelete" == "" ]] ; then
    echo "Delete? (y/n)"
    read -e deletenow
fi
if [[ "$deletenow" == Y || "$deletenow" == y ]] ; then
    rm -fv "$mountdir/$TCSUBDIR/$junktoday"/*
fi
