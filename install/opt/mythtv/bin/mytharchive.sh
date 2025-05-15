#!/bin/bash
# Daily recording export
set -e

. /etc/opt/mythtv/mythtv.conf
. /etc/opt/mythtv/private.conf
scriptname=`readlink -e "$0"`
scriptpath=`dirname "$scriptname"`
scriptname=`basename "$scriptname" .sh`
exec 1>>$LOGDIR/${scriptname}.log
exec 2>&1
echo Start of Run
date

# Mount archive directory
# This will return server name for an NFS mount,
# the string "UUID" for a local mount, empty for a mismatch
arcserver=`grep " $ARCMOUNTDIR" /etc/fstab|sed 's/:.*//;s/=.*//'`
backend=localhost
maxarchive=10

if [[ "$arcserver" == "" ]] ; then
    echo "ERROR, no match found for mount directory $ARCMOUNTDIR , aborting"
    exit 2
fi

mounted=N
function wakeup_server {
    if [[ "$arcserver" == UUID ]] ; then
        mounted=Y
        return
    fi
    if [[ "$mounted" == N ]] ; then
        "$scriptpath/wakeup.sh" $arcserver
        for try in 1 2 3 4 5 6 7 8 9 ; do
            mount "$ARCMOUNTDIR" || true
            if mountpoint "$ARCMOUNTDIR" ; then
                break;
            fi
            sleep 10
        done
        if ! mountpoint "$ARCMOUNTDIR" ; then
            echo ERROR cannot mount $ARCMOUNTDIR
            return 4
        fi
        mounted=Y
    fi
}

function exitfunc {
    if [[ "$mounted" == Y ]] ; then
        if [[ "$arcserver" != UUID ]] ; then
            umount -l "$ARCMOUNTDIR" || true
        fi
        mounted=N
    fi
}
trap 'exitfunc' EXIT

auth=
if [[ "$API_USER" != "" && "$API_PASSWD" != "" ]] ; then
    # Login to the API
    auth=$(curl -s -S -X POST -H "Accept: application/json" \
        "http://$API_IPADDRESS:6544/Myth/LoginUser?UserName=$API_USER&Password=$API_PASSWD" \
        | jq -r '.String')
fi

# Get a recording list
curl  -s -S -H "Accept: application/json" \
    -H "Authorization: $auth" \
    "http://$API_IPADDRESS:6544/Dvr/GetRecordedList?IgnoreDeleted=true&Sort=recgroup,title,starttime" \
    > $DATADIR/recorded.json
# Using smiley face 😃 as a delimiter ($'\U1F603')
jq -r '.ProgramList.Programs[] | {a: .Recording.RecGroup, b: .Title,
    c: .Recording.StartTs, d: .Airdate, e: .Season, f: .Episode,
    g: .SubTitle, h: .FileName, i: .Recording.RecordedId, j: .Description} | join("😃")' \
    < $DATADIR/recorded.json > $DATADIR/recorded.txt
# remove reverse quotes and quotes - change to apostrophes, slashes change to dashes
sed -e "s/\`/'/g;s/\"/'/g;s/\//-/g" < $DATADIR/recorded.txt >  $DATADIR/recordedfix.txt

#~ group arcDefault = archive and move to Default
# All recordings with goup arcXX are achived and moved to group XX
# File name will be Title/YYMMDD SxxExx subtitle.mkv
rc=0
count=0
archived=0
# Using smiley face 😃 as a delimiter ($'\U1F603')
while IFS='😃' read group title StartTs airdate season episode subtitle filename recordedid description rest  ;  do
    if [[ "$rest" != "" ]] ; then
        echo ERROR parsing $group $title $StartTs $airdate \
            $season $episode $subtitle $filename $recordedid $description $rest
        rc=2
        continue
    fi
    let count=count+1
    if [[ "$group" == arc* && "$group" != arc ]] ; then
        if (( archived > maxarchive )) ; then
            echo "Maximum archive count of $maxarchive reached, exiting"
            break
        fi
        wakeup_server
        newgroup=${group#arc}
        # airdate format 2021-05-07
        newdir="$ARCDIR/$title"
        air=
        if [[ "$airdate" = ????-??-?? ]] ; then
            air="${airdate:0:4}${airdate:5:2}${airdate:8:2} "
        fi
        sep=
        if (( season > 0 && episode > 0 )) ; then
            sep="$(printf "S%02dE%02d" $season $episode) "
        fi
        if [[ "$subtitle" == "" ]]; then
            subtitle="$title"
        fi
        newfilename="$air$sep$subtitle"
        newfile="$newdir/$newfilename.mkv"
        seqnum=1
        if [[ -f "$newfile" ]] ; then
            if [[ -f "$newdir/$newfilename part 1.mkv" ]] ; then
                echo "ERROR Inconsistent files found for $newfilename"
                rc=2
                continue
            fi
            mv -n "$newfile" "$newdir/$newfilename part 1.mkv"
            seqnum=2
        fi
        while [[ -f "$newdir/$newfilename part $seqnum.mkv" ]] ; do
            let seqnum++
        done
        if (( seqnum > 1 )) ; then
            newfilename="$newfilename part $seqnum"
        fi
        newfile="$newdir/$newfilename.mkv"
        # find recording file
        oldfile=`ls "$VIDEODIR"/video*/recordings/"$filename" 2>/dev/null` || true
        if [[ ! -f "$oldfile" ]] ; then
            echo "ERROR Recording file $filename is not found"
            rc=2
            continue
        fi
        mkdir -p "$newdir"
        mkvmerge -o "$newfile" "$oldfile"
        #~ cp -fv "$oldfile" "$newfile"
        curl  -s -S -H "Accept: application/json" -X  POST \
            -H "Authorization: $auth" \
            -H 'Content-Type: application/json' \
            "http://$backend:6544/Dvr/UpdateRecordedMetadata" \
            --data-raw "{\"RecordedId\":\"$recordedid\", \"RecGroup\":\"$newgroup\", \"Description\":\"$description Archived.\"}" \
            > $DATADIR/update.json
        result=$(jq -r '.bool' < $DATADIR/update.json)
        if [[ "$result" != "true" ]]  ; then
            echo ERROR Update recgroup failed for $group $title $StartTs $airdate \
            $season $episode $subtitle $filename $recordedid $rest
            cat $DATADIR/update.json
            echo
            rc=4
            break
        fi
        echo Archived $newfile
        let archived=archived+1
    fi
done  < $DATADIR/recordedfix.txt

echo "$count recording(s) found"
echo "$archived recording(s) archived"

exit $rc
